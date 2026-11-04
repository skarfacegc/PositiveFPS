#!/usr/bin/env python3
"""Line and function coverage for the PositiveFPS game scripts, plus the test report.

Usage:
    python tools/coverage.py                  # run the tests, write coverage/
    python tools/coverage.py --check-baseline # also fail (exit 3) if coverage dropped versus coverage_baseline.json
    python tools/coverage.py --update-baseline                    # record the numbers (only if the tests pass)
    python tools/coverage.py --update-baseline --allow-decrease   # also accept lower numbers
    python tools/coverage.py --check-determinism   # run twice, fail (exit 3) if any covered line differs
                                                  # (the two runs go at once; a saved run of the same code is reused)

What it does:
  1. Copies the project to <root>/.coverage_build (addons and tests are copied, not instrumented).
  2. Instruments scripts/*.gd in the copy. Before every executable statement inside a function body it puts
     CovProbe.hit("scripts/x.gd:<original line>"). See is_executable_line() for the rules.
  3. Adds an autoload (only in the copy) that writes the hit counts to coverage_hits.json when Godot exits.
  4. Runs the gdUnit4 suite headless through tools/run_tests.py, against the copy.
  5. Writes <root>/coverage/index.html (summary, per-file table), coverage/files/*.html (annotated source),
     summary.txt and coverage.json.

Line coverage is the headline number. Function coverage (a function counts as hit when its first statement ran)
is kept as a secondary column.

Exit codes: 0 ok; 1 a test failed; 2 the run could not complete; 3 the coverage ratchet failed or refused.
Only the Python standard library is used.
"""
import argparse
import datetime
import gzip
import html
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import time

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import run_tests  # noqa: E402
import gate  # noqa: E402  (the gate's code fingerprint, shared with the result cache)

ROOT = os.path.dirname(TOOLS)
BUILD = os.path.join(ROOT, ".coverage_build")
# The two determinism passes run in their own copies inside BUILD (ignored by git, skipped by the copy).
DET_BUILDS = (os.path.join(BUILD, "det1"), os.path.join(BUILD, "det2"))
COVERAGE_DIR = os.path.join(ROOT, "coverage")
FILES_DIR = os.path.join(COVERAGE_DIR, "files")
REPORTS_DIR = os.path.join(ROOT, "reports")
BASELINE = os.path.join(ROOT, "coverage_baseline.json")
HITS_DIR = os.path.join(BUILD, "cov_hits")
# design/ (mock-ups, a nested Godot project) and .scratch/ are not part of the game or its tests.
COPY_EXCLUDE = {".git", ".godot", ".coverage_build", "coverage", "reports", "design", ".scratch"}

RATCHET_TOLERANCE = 0.5  # points: an existing file or the total may drop by at most this much
NEW_FILE_MIN = 60.0  # points: a new file must reach at least this line coverage

FUNC_RE = re.compile(r"^(\t*)(static\s+)?func\s+(\w+)\s*\(")
MATCH_HEADER_RE = re.compile(r"^match\b.*:$")
CONTINUATION_KEYWORDS_RE = re.compile(r"^(elif|else)\b")

# Each instrumented script gets its own static counter array (see COV_TAIL) and probes are inline statements
# (`_cov_h[LINE] += 1`): about 11 times cheaper than a call into a shared dictionary, which made the instrumented
# run 6x slower than the plain one. CovProbe only keeps the registry so the dump can find every script's array.
COV_PROBE_GD = '''class_name CovProbe
extends RefCounted
static var regs := {}
static func register(rel: String, arr: PackedInt32Array) -> void:
\tregs[rel] = arr
static func to_hits() -> Dictionary:
\tvar out := {}
\tfor rel: String in regs:
\t\tvar arr: PackedInt32Array = regs[rel]
\t\tfor line in arr.size():
\t\t\tif arr[line] > 0:
\t\t\t\tout["%s:%d" % [rel, line]] = arr[line]
\treturn out
'''

# Appended to every instrumented script. Appending keeps the original line numbers.
COV_TAIL = '''

static var @NAME@: PackedInt32Array = @MAKE@()


static func @MAKE@() -> PackedInt32Array:
\tvar a := PackedInt32Array()
\ta.resize(%d)
\tCovProbe.register("%s", a)
\treturn a
'''

COV_DUMP_GD = '''extends Node

# Written into the coverage build only. Saves CovProbe hits when Godot quits.


func _exit_tree() -> void:
\t# Each parallel test process writes its own file (tools/run_tests.py sets POSITIVEFPS_COV_OUT); coverage.py sums them.
\tvar path := OS.get_environment("POSITIVEFPS_COV_OUT")
\tif path == "":
\t\tpath = ProjectSettings.globalize_path("res://coverage_hits.json")
\tvar f := FileAccess.open(path, FileAccess.WRITE)
\tif f != null:
\t\tf.store_string(JSON.stringify(CovProbe.to_hits(), "  "))
\t\tf.close()
'''


# ---------------------------------------------------------------------------
# GDScript scanning
# ---------------------------------------------------------------------------

def _mask(line, triple):
    """Blanks the contents of strings and the comment of one line.

    Returns (masked, triple) where masked has the same length as line, and triple is the closing delimiter
    of a triple-quoted string still open at the end of the line (or None). Brackets inside strings and
    comments disappear from the masked text, so bracket counting on it is safe.
    """
    out = []
    i = 0
    n = len(line)
    while i < n:
        if triple:
            end = line.find(triple, i)
            if end == -1:
                out.append(" " * (n - i))
                break
            out.append(" " * (end + 3 - i))
            i = end + 3
            triple = None
            continue
        if line.startswith('"""', i) or line.startswith("'''", i):
            triple = line[i:i + 3]
            out.append(triple)
            i += 3
            continue
        ch = line[i]
        if ch in "\"'":
            j = i + 1
            while j < n and line[j] != ch:
                j += 2 if line[j] == "\\" else 1
            if j >= n:  # unterminated on this line: blank the rest
                out.append(ch + " " * (n - i - 1))
                break
            out.append(ch + " " * (j - i - 1) + ch)
            i = j + 1
            continue
        if ch == "#":
            out.append(" " * (n - i))
            break
        out.append(ch)
        i += 1
    return "".join(out), triple


def scan_lines(raw_lines):
    """Per line: the masked code and whether the line is a continuation of the previous one.

    A continuation line starts inside an open bracket, inside a triple-quoted string, or after a backslash.
    """
    info = []
    depth = 0
    triple = None
    prev_backslash = False
    for raw in raw_lines:
        cont = depth > 0 or triple is not None or prev_backslash
        code, triple = _mask(raw, triple)
        for ch in code:
            if ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
        depth = max(depth, 0)
        prev_backslash = code.rstrip().endswith("\\")
        info.append({"raw": raw, "code": code, "cont": cont})
    return info


def indent_of(raw):
    return re.match(r"\t*", raw).group(0)


def analyze_script(rel, raw_lines):
    """Finds the executable lines and functions of one script.

    Executable lines are the statement lines inside a function body, excluding:
      - blank and comment-only lines,
      - continuation lines (inside brackets, after a backslash, inside a triple-quoted string),
      - elif / else lines and match branch patterns (their bodies are counted instead),
      - annotations (lines starting with @).
    Block headers (if, for, while, match) are executable: their probe records the condition being evaluated.
    A one-line function (body on the signature line) is split: the body becomes its own executable line,
    keeping its original line number.
    """
    info = scan_lines(raw_lines)
    n = len(raw_lines)
    exec_map = {}  # 0-based index -> {"func": name, "indent": tabs}
    oneliners = {}  # 0-based index -> (header text, body text, body indent)
    funcs = []  # {"func", "line", "first"} (1-based)
    uninstr = []
    i = 0
    while i < n:
        inf = info[i]
        m = None if inf["cont"] else FUNC_RE.match(inf["code"])
        if m is None:
            i += 1
            continue
        func_indent = m.group(1)
        fname = m.group(3)
        # Find the colon that ends the signature: first ":" at bracket depth 0 after the parameter list.
        depth = 0
        seen = False
        sig = None
        for j in range(i, n):
            code = info[j]["code"]
            start = m.end() - 1 if j == i else 0
            for k in range(start, len(code)):
                ch = code[k]
                if ch == "(":
                    depth += 1
                    seen = True
                elif ch == ")":
                    depth -= 1
                elif ch == ":" and seen and depth == 0:
                    sig = (j, k)
                    break
            if sig:
                break
        if sig is None:
            uninstr.append({"file": rel, "func": fname, "line": i + 1, "reason": "signature not parsed"})
            i += 1
            continue
        j, k = sig
        if info[j]["code"][k + 1:].strip():
            # One-line function: header on its own line, body on the next line.
            raw_j = raw_lines[j]
            oneliners[j] = (raw_j[:k + 1], raw_j[k + 1:].strip(), func_indent + "\t")
            exec_map[j] = {"func": fname, "indent": func_indent + "\t"}
            funcs.append({"func": fname, "line": i + 1, "first": j + 1})
            i = j + 1
            continue

        body = []
        match_stack = []
        k2 = j + 1
        while k2 < n:
            ii = info[k2]
            code = ii["code"]
            if ii["cont"] or not code.strip():
                k2 += 1
                continue
            ind = len(indent_of(ii["raw"]))
            if ind <= len(func_indent):
                break
            while match_stack and ind <= match_stack[-1]:
                match_stack.pop()
            if match_stack and ind == match_stack[-1] + 1:
                k2 += 1  # a match branch pattern: not counted, its body is
                continue
            stripped = code.strip()
            if stripped.startswith("@") or CONTINUATION_KEYWORDS_RE.match(stripped):
                k2 += 1
                continue
            body.append(k2)
            if MATCH_HEADER_RE.match(stripped):
                match_stack.append(ind)
            k2 += 1
        if body:
            funcs.append({"func": fname, "line": i + 1, "first": body[0] + 1})
            for idx in body:
                exec_map[idx] = {"func": fname, "indent": indent_of(info[idx]["raw"])}
        else:
            uninstr.append({"file": rel, "func": fname, "line": i + 1, "reason": "no executable lines"})
        i = k2
    return {
        "exec": sorted(exec_map.keys()),
        "exec_map": exec_map,
        "oneliners": oneliners,
        "funcs": funcs,
        "uninstr": uninstr,
    }


def cov_name(rel):
    """A counter name unique to the script (a script and the script it extends must not share a static name)."""
    return "_cov_h_" + re.sub(r"\W", "_", rel)


def instrument_lines(rel, raw_lines, result):
    """Returns the instrumented source text. Probe keys use the original 1-based line numbers."""
    out = []
    for idx, raw in enumerate(raw_lines):
        probe = "%s[%d] += 1" % (cov_name(rel), idx + 1)
        if idx in result["oneliners"]:
            header, body, body_indent = result["oneliners"][idx]
            out.append(header)
            out.append(body_indent + probe)
            out.append(body_indent + body)
        elif idx in result["exec_map"]:
            out.append(indent_of(raw) + probe)
            out.append(raw)
        else:
            out.append(raw)
    name = cov_name(rel)
    tail = COV_TAIL.replace("@NAME@", name).replace("@MAKE@", name + "_make")
    return chr(10).join(out) + tail % (len(raw_lines) + 2, rel)


# ---------------------------------------------------------------------------
# Build and run
# ---------------------------------------------------------------------------

def copy_project(build=BUILD):
    if os.path.isdir(build):
        shutil.rmtree(build, onerror=_clear_readonly)
    os.makedirs(build)
    for entry in os.listdir(ROOT):
        skip = entry in COPY_EXCLUDE or entry.startswith(".coverage_build")
        if skip or entry in ("test_results.json", "coverage_hits.json"):
            continue
        src = os.path.join(ROOT, entry)
        dst = os.path.join(build, entry)
        if os.path.isdir(src):
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*COPY_EXCLUDE))
        else:
            shutil.copy2(src, dst)
    # Start from the repo's import cache, so the import step in the copy has little left to do (about 1.5 s saved).
    godot_cache = os.path.join(ROOT, ".godot")
    if os.path.isdir(godot_cache):
        shutil.copytree(godot_cache, os.path.join(build, ".godot"))


def _clear_readonly(func, path, _exc):
    os.chmod(path, 0o666)
    func(path)


def instrument_build(build=BUILD):
    """Instruments scripts/*.gd in the build copy.

    Returns (files, uninstrumentable): files maps the script path to {"exec", "funcs", "src", "result"}.
    """
    files = {}
    uninstr = []
    scripts_dir = os.path.join(build, "scripts")
    for dirpath, _dirs, names in os.walk(scripts_dir):
        for name in sorted(names):
            if not name.endswith(".gd"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, build).replace("\\", "/")
            with open(full, encoding="utf-8", newline="") as fh:
                text = fh.read().replace("\r\n", "\n")
            raw_lines = text.split("\n")
            result = analyze_script(rel, raw_lines)
            with open(full, "w", encoding="utf-8", newline="\n") as fh:
                fh.write(instrument_lines(rel, raw_lines, result))
            files[rel] = {
                "exec": [i + 1 for i in result["exec"]],
                "funcs": result["funcs"],
                "src": raw_lines,
            }
            uninstr.extend(result["uninstr"])
    return files, uninstr


def write_probe_files(build=BUILD):
    tests_dir = os.path.join(build, "tests")
    os.makedirs(tests_dir, exist_ok=True)
    with open(os.path.join(tests_dir, "cov.gd"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(COV_PROBE_GD)
    with open(os.path.join(tests_dir, "cov_dump.gd"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(COV_DUMP_GD)
    project_file = os.path.join(build, "project.godot")
    with open(project_file, encoding="utf-8") as fh:
        text = fh.read()
    text = text.rstrip("\n") + '\n\n[autoload]\n\nCovDump="*res://tests/cov_dump.gd"\n'
    with open(project_file, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)


def git_info():
    try:
        short = subprocess.run(["git", "-C", ROOT, "rev-parse", "--short", "HEAD"],
                               capture_output=True, text=True, check=True).stdout.strip()
        dirty = subprocess.run(["git", "-C", ROOT, "status", "--porcelain"],
                               capture_output=True, text=True, check=True).stdout.strip() != ""
        return short + (" + uncommitted changes" if dirty else "")
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def merge_hits(hits_dir):
    """Sums the hit counts of every hits_*.json (one per test process). Returns None if there is none."""
    merged = None
    for name in sorted(os.listdir(hits_dir)) if os.path.isdir(hits_dir) else []:
        if not name.endswith(".json"):
            continue
        with open(os.path.join(hits_dir, name), encoding="utf-8") as fh:
            part = json.load(fh)
        merged = merged if merged is not None else {}
        for key, count in part.items():
            merged[key] = merged.get(key, 0) + count
    return merged


def pct(hit, total):
    return 100.0 * hit / total if total else 100.0


def build_stats(files, hits, results):
    """Line and function coverage per file and overall, plus the test totals."""
    per_file = {}
    for rel, info in files.items():
        lines_total = len(info["exec"])
        lines_hit = sum(1 for ln in info["exec"] if hits.get("%s:%d" % (rel, ln), 0) > 0)
        funcs = []
        for fn in info["funcs"]:
            count = hits.get("%s:%d" % (rel, fn["first"]), 0)
            funcs.append({"func": fn["func"], "line": fn["line"], "count": count})
        per_file[rel] = {
            "lines_total": lines_total,
            "lines_hit": lines_hit,
            "funcs": funcs,
            "funcs_total": len(funcs),
            "funcs_hit": sum(1 for f in funcs if f["count"] > 0),
        }
    lt = sum(f["lines_total"] for f in per_file.values())
    lh = sum(f["lines_hit"] for f in per_file.values())
    ft = sum(f["funcs_total"] for f in per_file.values())
    fh = sum(f["funcs_hit"] for f in per_file.values())
    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    return {
        "files": per_file,
        "line_overall": round(pct(lh, lt), 1),
        "lines_total": lt,
        "lines_hit": lh,
        "line_files": {n: round(pct(f["lines_hit"], f["lines_total"]), 1) for n, f in per_file.items()},
        "func_overall": round(pct(fh, ft), 1),
        "functions_total": ft,
        "functions_hit": fh,
        "func_files": {n: round(pct(f["funcs_hit"], f["funcs_total"]), 1) for n, f in per_file.items()},
        "tests_total": len(results),
        "tests_passed": passed,
        "tests_failed": failed,
    }


# ---------------------------------------------------------------------------
# Baseline ratchet
# ---------------------------------------------------------------------------

def compare_to_baseline(stats, base):
    """Compares the run with the baseline. Returns (rows, failures, decreases).

    rows: (name, old, new) with None for missing values. failures: reasons the --check-baseline gate fails.
    decreases: names whose number went down at all (refused by --update-baseline without --allow-decrease).
    """
    rows = [("TOTAL (lines)", base.get("line_overall"), stats["line_overall"])]
    failures = []
    decreases = []
    old_total = base.get("line_overall")
    if old_total is not None:
        if old_total - stats["line_overall"] > RATCHET_TOLERANCE:
            failures.append("total line coverage dropped from %.1f%% to %.1f%%"
                            % (old_total, stats["line_overall"]))
        if stats["line_overall"] < old_total - 1e-9:
            decreases.append("TOTAL")
    base_files = base.get("line_files", {})
    cur_files = stats["line_files"]
    for name in sorted(set(cur_files) | set(base_files)):
        old = base_files.get(name)
        new = cur_files.get(name)
        rows.append((name, old, new))
        if old is None:
            if new < NEW_FILE_MIN:
                failures.append("new file %s has %.1f%% line coverage (minimum %.0f%%)"
                                % (name, new, NEW_FILE_MIN))
        elif new is None:
            continue  # removed file: noted in the table, not a failure
        else:
            if old - new > RATCHET_TOLERANCE:
                failures.append("%s dropped from %.1f%% to %.1f%%" % (name, old, new))
            if new < old - 1e-9:
                decreases.append(name)
    return rows, failures, decreases


def print_comparison(rows):
    print("%-44s %10s %10s %9s" % ("File", "baseline", "now", "change"))
    for name, old, new in rows:
        old_s = "-" if old is None else "%.1f%%" % old
        new_s = "-" if new is None else "%.1f%%" % new
        change = "-" if old is None or new is None else "%+.1f" % (new - old)
        print("%-44s %10s %10s %9s" % (name, old_s, new_s, change))


# ---------------------------------------------------------------------------
# Reports
# ---------------------------------------------------------------------------

CSS = """
:root { --bg:#f6f7f9; --fg:#1d2330; --muted:#667085; --card:#ffffff; --line:#d9dee7;
  --good:#1f9d55; --bad:#d64545; --bar:#4f7cff; --barbg:#e5e9f1; --goodbg:#e3f6ea; --badbg:#fbe4e4; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg:#15181f; --fg:#e7eaf0; --muted:#9aa4b5; --card:#1e232d;
    --line:#2f3644; --good:#4cc38a; --bad:#ff6b6b; --bar:#7d9dff; --barbg:#2a3140;
    --goodbg:#16352a; --badbg:#3a1f23; } }
:root[data-theme="dark"] { --bg:#15181f; --fg:#e7eaf0; --muted:#9aa4b5; --card:#1e232d;
  --line:#2f3644; --good:#4cc38a; --bad:#ff6b6b; --bar:#7d9dff; --barbg:#2a3140;
  --goodbg:#16352a; --badbg:#3a1f23; }
body { margin:0; padding:24px; background:var(--bg); color:var(--fg);
  font:15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
a { color:var(--bar); }
h1 { font-size:24px; margin:0 0 4px; } h2 { font-size:18px; margin:28px 0 8px; }
.meta { color:var(--muted); margin-bottom:18px; }
.cards { display:flex; flex-wrap:wrap; gap:12px; margin:16px 0; }
.card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px 18px; min-width:170px; }
.card b { display:block; font-size:26px; }
.card span { color:var(--muted); font-size:13px; }
table { width:100%; border-collapse:collapse; background:var(--card); border:1px solid var(--line); border-radius:10px; overflow:hidden; }
th, td { text-align:left; padding:6px 10px; border-bottom:1px solid var(--line); vertical-align:middle; }
th { color:var(--muted); font-weight:600; font-size:13px; }
.bar { background:var(--barbg); border-radius:6px; height:12px; width:200px; overflow:hidden; }
.bar > div { height:100%; background:var(--bar); }
.good { color:var(--good); } .bad { color:var(--bad); font-weight:600; }
.failed { background:var(--card); border:1px solid var(--bad); border-radius:10px; padding:12px 16px; }
.failed li { color:var(--bad); margin:6px 0; }
.failed code { color:var(--fg); white-space:pre-wrap; }
.fn { font-family: ui-monospace, Consolas, monospace; font-size:13px; }
details { background:var(--card); border:1px solid var(--line); border-radius:10px; margin:8px 0; padding:6px 12px; }
summary { cursor:pointer; font-weight:600; padding:6px 0; }
.src { font-family: ui-monospace, Consolas, monospace; font-size:13px; }
.src td { padding:0 8px; border-bottom:none; white-space:pre; }
.src .n { color:var(--muted); text-align:right; width:1%; user-select:none; }
.src .c { text-align:right; width:1%; color:var(--muted); }
.src tr.hit { background:var(--goodbg); } .src tr.miss { background:var(--badbg); }
.legend span { display:inline-block; padding:2px 8px; border-radius:6px; margin-right:8px; }
.legend .lh { background:var(--goodbg); } .legend .lm { background:var(--badbg); }
"""


def esc(s):
    return html.escape(str(s))


def page(title, body_html, stamp, git):
    return ("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
            "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
            "<title>%s</title><style>%s</style></head><body>%s"
            "<div class=\"meta\">Generated %s &middot; git %s</div></body></html>"
            % (esc(title), CSS, body_html, esc(stamp), esc(git)))


def source_page(rel, info, hits):
    """An annotated copy of one script: executable lines are green (hit) or red (never hit), with counts."""
    exec_set = set(info["exec"])
    rows = []
    for idx, raw in enumerate(info["src"]):
        ln = idx + 1
        if ln in exec_set:
            count = hits.get("%s:%d" % (rel, ln), 0)
            cls = "hit" if count > 0 else "miss"
            cnt = str(count)
        else:
            cls = ""
            cnt = ""
        rows.append("<tr class=\"%s\"><td class=\"n\">%d</td><td class=\"c\">%s</td><td>%s</td></tr>"
                    % (cls, ln, cnt, esc(raw)))
    body = ("<p><a href=\"../index.html\">&larr; back to the report</a></p><h1 class=\"fn\">%s</h1>"
            "<p class=\"legend\"><span class=\"lh\">executed (hit count shown)</span>"
            "<span class=\"lm\">executable, never run</span> Other lines are not executable.</p>"
            "<table class=\"src\"><tr><th>Line</th><th>Hits</th><th>Code</th></tr>%s</table>"
            % (esc(rel), "".join(rows)))
    return body


def file_page_name(rel):
    return rel.replace("/", "_") + ".html"


def render_index(stats, results, uninstr, git, stamp):
    out = []
    w = out.append
    failed = [r for r in results if not r["ok"]]
    w("<h1>PositiveFPS &mdash; test &amp; coverage report</h1>")
    w("<div class=\"cards\">")
    w("<div class=\"card\"><b class=\"%s\">%d passed</b><span>tests</span></div>"
      % ("good" if not failed else "bad", stats["tests_passed"]))
    w("<div class=\"card\"><b class=\"%s\">%d failed</b><span>tests</span></div>"
      % ("good" if not failed else "bad", stats["tests_failed"]))
    w("<div class=\"card\"><b>%.1f%%</b><span>line coverage (%d of %d lines hit)</span></div>"
      % (stats["line_overall"], stats["lines_hit"], stats["lines_total"]))
    w("<div class=\"card\"><b>%.1f%%</b><span>function coverage (%d of %d hit)</span></div>"
      % (stats["func_overall"], stats["functions_hit"], stats["functions_total"]))
    w("</div>")

    if failed:
        w("<h2>Failed tests</h2><div class=\"failed\"><ul>")
        for r in failed:
            w("<li><span class=\"fn\">%s::%s</span>" % (esc(r["file"]), esc(r["name"])))
            for m in r["messages"]:
                w("<br><code>%s</code>" % esc(m))
            w("</li>")
        w("</ul></div>")

    w("<h2>Line coverage by file</h2><p class=\"meta\">Lowest first. Click a file to see every line.</p>")
    w("<table><tr><th>File</th><th>Lines hit / total</th><th>Line %</th><th>Coverage</th>"
      "<th>Functions</th><th>Func %</th></tr>")
    for name, f in sorted(stats["files"].items(), key=lambda kv: pct(kv[1]["lines_hit"], kv[1]["lines_total"])):
        p = pct(f["lines_hit"], f["lines_total"])
        w("<tr><td class=\"fn\"><a href=\"files/%s\">%s</a></td><td>%d / %d</td><td>%.1f%%</td>"
          "<td><div class=\"bar\"><div style=\"width:%.1f%%\"></div></div></td>"
          "<td>%d / %d</td><td>%.1f%%</td></tr>"
          % (esc(file_page_name(name)), esc(name), f["lines_hit"], f["lines_total"], p, p,
             f["funcs_hit"], f["funcs_total"], pct(f["funcs_hit"], f["funcs_total"])))
    w("</table>")

    w("<h2>Functions</h2>")
    for name, f in sorted(stats["files"].items()):
        w("<details><summary>%s &mdash; %d / %d functions hit</summary><table>"
          % (esc(name), f["funcs_hit"], f["funcs_total"]))
        w("<tr><th>Function</th><th>Line</th><th>Hits (first statement)</th><th>Status</th></tr>")
        for fn in f["funcs"]:
            ok = fn["count"] > 0
            w("<tr><td class=\"fn\">%s</td><td>%d</td><td>%d</td><td class=\"%s\">%s</td></tr>"
              % (esc(fn["func"]), fn["line"], fn["count"], "good" if ok else "bad", "hit" if ok else "missed"))
        w("</table></details>")

    if uninstr:
        w("<h2>Not measurable</h2><p class=\"meta\">These functions have no executable lines, so they are "
          "not in the percentages.</p><ul>")
        for u in uninstr:
            w("<li class=\"fn\">%s:%d %s (%s)</li>" % (esc(u["file"]), u["line"], esc(u["func"]), esc(u["reason"])))
        w("</ul>")
    return page("PositiveFPS test and coverage report", "\n".join(out), stamp, git)


def render_summary(stats, git, stamp):
    lines = [
        "PositiveFPS test & coverage summary",
        "Generated: %s   git: %s" % (stamp, git),
        "Tests: %d passed, %d failed" % (stats["tests_passed"], stats["tests_failed"]),
        "Line coverage: %.1f%% (%d of %d lines)" % (stats["line_overall"], stats["lines_hit"], stats["lines_total"]),
        "Function coverage: %.1f%% (%d of %d)" % (stats["func_overall"], stats["functions_hit"],
                                                 stats["functions_total"]),
        "",
        "Line coverage per file (lowest first):",
    ]
    for name, f in sorted(stats["files"].items(), key=lambda kv: pct(kv[1]["lines_hit"], kv[1]["lines_total"])):
        lines.append("  %-32s %5.1f%%  (%d/%d lines)  functions %d/%d" % (
            name, pct(f["lines_hit"], f["lines_total"]), f["lines_hit"], f["lines_total"],
            f["funcs_hit"], f["funcs_total"]))
    return "\n".join(lines) + "\n"


def write_reports(stats, results, uninstr, files, hits, git, stamp):
    os.makedirs(FILES_DIR, exist_ok=True)
    for name, info in files.items():
        with open(os.path.join(FILES_DIR, file_page_name(name)), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(page("PositiveFPS coverage: " + name, source_page(name, info, hits), stamp, git))
    with open(os.path.join(COVERAGE_DIR, "index.html"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render_index(stats, results, uninstr, git, stamp))
    with open(os.path.join(COVERAGE_DIR, "summary.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render_summary(stats, git, stamp))
    payload = {
        "overall": stats["line_overall"],
        "line_overall": stats["line_overall"],
        "line_files": stats["line_files"],
        "func_overall": stats["func_overall"],
        "func_files": stats["func_files"],
        "tests": {"total": stats["tests_total"], "passed": stats["tests_passed"],
                  "failed": stats["tests_failed"]},
    }
    with open(os.path.join(COVERAGE_DIR, "coverage.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump(payload, fh, indent=2)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def measure_once(workers, build=BUILD, report_root=REPORTS_DIR):
    """Copies, instruments and runs the suite once in `build`. Returns (code, results, stats, hits), or None on a
    setup error (no results or no hits)."""
    copy_project(build)
    files, _uninstr = instrument_build(build)
    write_probe_files(build)
    hits_dir = os.path.join(build, "cov_hits")
    os.makedirs(hits_dir, exist_ok=True)
    code, results, _report_dir = run_tests.run_suite(build, report_root=report_root, workers=workers,
                                                     cov_dir=hits_dir)
    hits = merge_hits(hits_dir)
    if results is None or hits is None:
        return None
    return code, results, build_stats(files, hits, results), hits


def det_run_file():
    """The saved run of the code (see save_clean_run). It lives in .git, next to the gate's result cache."""
    return os.path.join(os.path.dirname(gate.cache_path()), "positivefps-determinism-run.json")


def code_fingerprint():
    """The gate's fingerprint of the working tree, or None if it cannot be computed (then nothing is saved or reused)."""
    try:
        return gate.fingerprint()
    except (OSError, subprocess.CalledProcessError):
        return None


def load_saved_run(fp):
    """The saved run, but only when it was made from exactly this code (same fingerprint). Otherwise None."""
    if fp is None:
        return None
    try:
        with open(det_run_file(), encoding="utf-8") as fh:
            saved = json.load(fh)
    except (OSError, ValueError, subprocess.CalledProcessError):
        return None
    if not isinstance(saved, dict) or saved.get("fingerprint") != fp:
        return None
    saved["units"] = None
    try:
        with gzip.open(det_units_file(), "rt", encoding="utf-8") as fh:
            extra = json.load(fh)
        if extra.get("fingerprint") == fp:
            saved["units"] = extra.get("units")
    except (OSError, ValueError, subprocess.CalledProcessError):
        pass
    return saved


# Round 23: the hit-count rule. Line hit COUNTS (not only which lines were hit) are compared per test unit (one Godot
# process each, hits_NN.json). A unit whose counts differ in more than DIFF_LINES_ALLOWED lines is not repeatable.
# Why per unit: the counts of the whole run are the sum of all units, and one racy unit moves ~1000 lines of them.
DIFF_LINES_ALLOWED = 10  # the session-folder name race in scripts/recorder.gd moves 2 lines when two sessions start
# within one wall-clock second; anything under this is that kind of noise
# Known races, each with its cause (a suite name from tools/run_tests.py plan_units, or "suite (rest)"):
# Empty since round 24: the looks suites' wobble was wall-clock use in the looks (fixed, see COVERAGE_TOOL_NOTES.md).
KNOWN_REAL_TIME_UNITS: dict = {}


def det_units_file():
    """The per-unit hits of the saved run (gzip), next to the saved run in .git."""
    return os.path.join(os.path.dirname(gate.cache_path()), "positivefps-determinism-units.json.gz")


def unit_hits(hits_dir):
    """{hits file name: {line key: count}} with only the lines that were hit, or None when there are no hits files."""
    if not os.path.isdir(hits_dir):
        return None
    units = {}
    for name in sorted(os.listdir(hits_dir)):
        if name.endswith(".json"):
            with open(os.path.join(hits_dir, name), encoding="utf-8") as fh:
                units[name] = {k: v for k, v in json.load(fh).items() if v > 0}
    return units or None


def unit_names(build):
    """{hits file name: unit name} as run_tests.run_parallel numbers them. Empty when the plan cannot be rebuilt."""
    try:
        plan = run_tests.plan_units(run_tests.discover_tests(build), run_tests.load_weights(), with_perf=True)
    except (OSError, ValueError, KeyError):
        return {}
    return {"hits_%02d.json" % i: unit["name"] for i, unit in enumerate(plan)}


def unit_count_differences(units_a, units_b):
    """{hits file name: number of lines whose hit count differs} for the units present in both, differing ones only."""
    out = {}
    for name in sorted(set(units_a) & set(units_b)):
        a, b = units_a[name], units_b[name]
        n = sum(1 for key in set(a) | set(b) if a.get(key, 0) != b.get(key, 0))
        if n:
            out[name] = n
    return out


def unit_rule_problems(differences, names):
    """(problems, notes): a unit that differs in more than DIFF_LINES_ALLOWED lines is a problem unless it is a known
    race, which is only noted."""
    problems, notes = [], []
    for unit, n in differences.items():
        label = names.get(unit, unit)
        base = label.split("::")[0].replace(" (rest)", "")
        if n <= DIFF_LINES_ALLOWED:
            continue
        if base in KNOWN_REAL_TIME_UNITS:
            notes.append("%s: %d lines differ in hit count (known: %s)" % (label, n, KNOWN_REAL_TIME_UNITS[base]))
        else:
            problems.append("%s: %d lines differ in hit count between the two runs. Something in this suite depends on "
                            "wall-clock time (Time.get_ticks_*, a real timer) or thread timing; use the fixed-step "
                            "delta or a frame counter instead (see COVERAGE_TOOL_NOTES.md, round 24)" % (label, n))
    return problems, notes


def save_clean_run(fp, code, results, stats, hits, units=None):
    """Keeps a run in which every test passed, so a later --check-determinism can use it as its first pass.

    Called by every instrumented run (the ratchet run, the baseline run and the determinism check). A run that
    failed is never kept.
    """
    if fp is None or code != 0 or not results or any(not r["ok"] for r in results):
        return
    payload = {"fingerprint": fp, "when": datetime.datetime.now().isoformat(timespec="seconds"), "code": code,
               "results": results, "line_overall": stats["line_overall"], "line_files": stats["line_files"],
               "hits": hits}
    try:
        with open(det_run_file(), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(payload, fh)
        if units is not None:
            with gzip.open(det_units_file(), "wt", encoding="utf-8") as fh:
                json.dump({"fingerprint": fp, "units": units}, fh)
    except (OSError, subprocess.CalledProcessError) as err:
        print("note: the run could not be saved for reuse (%s)" % err)


def _determinism_pass(n, build, workers, outcomes):
    """One fresh determinism pass (run on its own thread). Stores ("ok", run) or ("error", text) in outcomes[n]."""
    try:
        run = measure_once(workers, build, os.path.join(REPORTS_DIR, "determinism-%d" % n))
    except (RuntimeError, OSError) as err:
        outcomes[n] = ("error", str(err))
        return
    if run is None:
        outcomes[n] = ("error", "determinism pass %d wrote no results or hits." % n)
    else:
        outcomes[n] = ("ok", run)
        outcomes[("units", n)] = unit_hits(os.path.join(build, "cov_hits"))


def diff_hit_counts(hits_a, hits_b):
    """Lines hit in both runs but a different number of times: a list of (key, count a, count b), sorted by key."""
    return sorted((k, hits_a[k], hits_b[k]) for k in hits_a.keys() & hits_b.keys()
                  if hits_a[k] > 0 and hits_b[k] > 0 and hits_a[k] != hits_b[k])


def describe_count_diffs(diffs, limit=8):
    """Printable lines about differing hit counts: how many per file, and the biggest relative differences."""
    per_file = {}
    for key, _a, _b in diffs:
        per_file[key.rsplit(":", 1)[0]] = per_file.get(key.rsplit(":", 1)[0], 0) + 1
    lines = ["  hit-count differences by file: " + ", ".join("%s %d" % (f, n) for f, n in
                                                           sorted(per_file.items(), key=lambda kv: -kv[1])[:limit])]
    worst = sorted(diffs, key=lambda d: -abs(d[1] - d[2]) / max(d[1], d[2]))[:limit]
    for key, a, b in worst:
        lines.append("  %s: %d vs %d" % (key, a, b))
    return lines


def check_determinism(workers, fresh=False):
    """Runs the instrumented suite twice and compares the per-file line coverage and the exact set of lines hit.

    The two passes are independent: each has its own copy of the project (det1, det2 under .coverage_build) and its own
    report folder, and they run at the same time, each with the usual number of workers. If a clean run of this exact
    code is saved (from an earlier --check-determinism or from the ratchet run), it stands in for pass 1 and only
    one fresh run is made. Use it once at the end of a round, before `--update-baseline`.
    """
    started = time.time()
    fp = code_fingerprint()
    saved = None if fresh else load_saved_run(fp)
    outcomes = {}
    if saved is not None:
        print("== Determinism pass 1 of 2: the clean run of this exact code from %s (saved, not run again)"
              % saved.get("when", "earlier"))
        outcomes[1] = ("ok", (saved["code"], saved["results"],
                              {"line_overall": saved["line_overall"], "line_files": saved["line_files"]},
                              saved["hits"]))
        outcomes[("units", 1)] = saved.get("units")
        print("== Determinism pass 2 of 2: a fresh run")
        _determinism_pass(2, DET_BUILDS[1], workers, outcomes)
    else:
        print("== Determinism passes 1 and 2 of 2: two fresh runs, at the same time")
        threads = [threading.Thread(target=_determinism_pass, args=(n, DET_BUILDS[n - 1], workers, outcomes))
                   for n in (1, 2)]
        for thread in threads:
            thread.start()
        for thread in threads:
            thread.join()
    errors = [outcomes[n][1] for n in (1, 2) if outcomes[n][0] == "error"]
    if errors:
        for text in errors:
            print("ERROR: " + text, file=sys.stderr)
        return 2
    (code_a, res_a, stats_a, hits_a), (code_b, res_b, stats_b, hits_b) = outcomes[1][1], outcomes[2][1]
    problems = []
    if code_a != 0 or code_b != 0 or any(not r["ok"] for r in res_a + res_b):
        problems.append("a test failed in one of the runs")
    if [(r["file"], r["name"], r["ok"]) for r in res_a] != [(r["file"], r["name"], r["ok"]) for r in res_b]:
        problems.append("the two runs ran or passed different tests")
    for rel in sorted(set(stats_a["line_files"]) | set(stats_b["line_files"])):
        a, b = stats_a["line_files"].get(rel), stats_b["line_files"].get(rel)
        if a != b:
            problems.append("%s: line coverage %s vs %s" % (rel, a, b))
    lines_a = {k for k, v in hits_a.items() if v > 0}
    lines_b = {k for k, v in hits_b.items() if v > 0}
    for key in sorted(lines_a ^ lines_b)[:20]:
        problems.append("line %s was hit in only one run" % key)
    diffs = diff_hit_counts(hits_a, hits_b)
    count_diffs = len(diffs)
    units_a, units_b = outcomes.get(("units", 1)), outcomes.get(("units", 2))
    unit_notes = []
    if problems:
        unit_notes.append("the per-unit hit-count rule was skipped: a failed test changes the counts of its own unit")
    elif units_a and units_b:
        more, unit_notes = unit_rule_problems(unit_count_differences(units_a, units_b), unit_names(DET_BUILDS[1]))
        problems += more
        if set(units_a) != set(units_b):
            unit_notes.append("the two runs had different test units; the per-unit hit-count rule compared the common "
                              "ones only")
    else:
        unit_notes.append("no per-unit hits for pass 1 (an older saved run): the per-unit hit-count rule was not "
                          "applied this time")
    print("")
    print("Determinism: %d tests, line coverage %.1f%% and %.1f%%, %d lines hit; %d lines differ in hit count"
          " (informational)" % (len(res_a), stats_a["line_overall"], stats_b["line_overall"], len(lines_a),
                                count_diffs))
    if diffs:
        print("\n".join(describe_count_diffs(diffs)))
    for note in unit_notes:
        print("  note: " + note)
    if problems:
        print("DETERMINISM CHECK FAILED:")
        for line in problems:
            print("  - " + line)
        return 3
    save_clean_run(fp, code_b, res_b, stats_b, hits_b, units_b)
    print("Determinism OK: both runs hit exactly the same lines (%.0f s)." % (time.time() - started))
    return 0


# ---------------------------------------------------------------------------
# Round 23: a quick per-file check for part agents (--check-files)
# ---------------------------------------------------------------------------

FILES_BUILD = os.path.join(BUILD, "files")


def normalise_scripts(paths, known):
    """Script arguments as keys of `known` ("scripts/x.gd"). Accepts x.gd, scripts/x.gd and backslashes."""
    out = []
    for raw in paths:
        rel = raw.replace("\\", "/")
        rel = rel[2:] if rel.startswith("./") else rel
        rel = rel if rel.startswith("scripts/") else "scripts/" + rel
        if rel not in known:
            raise ValueError("%s is not a script under scripts/ (known scripts: %d)" % (raw, len(known)))
        if rel not in out:
            out.append(rel)
    return out


def suites_for_scripts(rels, project=ROOT):
    """The test suites (tests/*_test.gd, names without .gd) that name a script: its class_name or its res:// path, plus
    the suite called <script>_test. A guess that is right for most scripts; pass --suites to choose by hand."""
    tests_dir = os.path.join(project, "tests")
    texts = {}
    for name in sorted(os.listdir(tests_dir)):
        if name.endswith("_test.gd"):
            with open(os.path.join(tests_dir, name), encoding="utf-8") as fh:
                texts[name[:-3]] = fh.read()
    chosen = set()
    for rel in rels:
        stem = os.path.splitext(os.path.basename(rel))[0]
        patterns = [re.escape("res://" + rel)]
        with open(os.path.join(project, rel), encoding="utf-8") as fh:
            found = re.search(r"^class_name\s+(\w+)", fh.read(), re.M)
        if found:
            patterns.append(r"\b%s\b" % re.escape(found.group(1)))
        regex = re.compile("|".join(patterns))
        if stem + "_test" in texts:
            chosen.add(stem + "_test")
        chosen.update(suite for suite, text in texts.items() if regex.search(text))
    return sorted(chosen)


def line_ranges(numbers):
    """[41, 42, 43, 88] -> "41-43, 88"."""
    out, start, prev = [], None, None
    for n in sorted(numbers):
        if start is None:
            start = prev = n
        elif n == prev + 1:
            prev = n
        else:
            out.append((start, prev))
            start = prev = n
    if start is not None:
        out.append((start, prev))
    return ", ".join(str(a) if a == b else "%d-%d" % (a, b) for a, b in out)


def file_check_rows(rels, files, hits, base):
    """One dict per script: lines hit and total, the lines not hit, the baseline value and the verdict.

    The verdict follows the ratchet (RATCHET_TOLERANCE below the baseline, NEW_FILE_MIN for a file with no baseline)."""
    base_files = (base or {}).get("line_files", {})
    rows = []
    for rel in rels:
        info = files[rel]
        missed = [ln for ln in info["exec"] if hits.get("%s:%d" % (rel, ln), 0) <= 0]
        total = len(info["exec"])
        now = round(pct(total - len(missed), total), 1)
        old = base_files.get(rel)
        if old is None:
            ok = now >= NEW_FILE_MIN
        else:
            ok = old - now <= RATCHET_TOLERANCE
        rows.append({"file": rel, "total": total, "hit": total - len(missed), "now": now, "baseline": old,
                     "missed": missed, "ok": ok})
    return rows


def check_files(paths, suites, workers):
    """Runs only the test suites that cover the given scripts, instrumented, and reports each script's line coverage
    against coverage_baseline.json with the lines not hit. Exit 0 fine, 1 a test failed, 2 setup error, 3 below baseline.

    The numbers count only the suites that ran, so they are a floor: the full run may hit more lines from other suites.
    A script below its baseline here is a reason to add a test or to widen --suites, not proof of a ratchet failure.
    """
    build = FILES_BUILD
    print("== Copying project to %s" % build)
    copy_project(build)
    files, _uninstr = instrument_build(build)
    try:
        rels = normalise_scripts(paths, files)
        suites = list(suites) if suites else suites_for_scripts(rels)
    except (ValueError, OSError) as err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 2
    if not suites:
        print("ERROR: no test suite names these scripts; pass --suites <name> ...", file=sys.stderr)
        return 2
    write_probe_files(build)
    hits_dir = os.path.join(build, "cov_hits")
    os.makedirs(hits_dir, exist_ok=True)
    print("== Running %d suite(s) instrumented: %s" % (len(suites), " ".join(suites)))
    problems = []
    try:
        code, results, _report_dir = run_tests.run_suite(build, report_root=os.path.join(REPORTS_DIR, "files"),
                                                         workers=workers, cov_dir=hits_dir, problems=problems,
                                                         suites=suites)
    except (RuntimeError, OSError) as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    hits = merge_hits(hits_dir)
    if results is None or hits is None:
        print("ERROR: the targeted run wrote no results or hits; see the Godot output above.", file=sys.stderr)
        return 2
    rows = file_check_rows(rels, files, hits, _load_baseline())
    print("")
    print("Per-file line coverage from these %d suite(s) only (a floor; the full run may hit more):" % len(suites))
    for r in rows:
        base = "no baseline" if r["baseline"] is None else "baseline %.1f%%" % r["baseline"]
        print("  %-36s %5.1f%% (%d of %d lines), %s: %s" % (r["file"], r["now"], r["hit"], r["total"], base,
                                                          "ok" if r["ok"] else "BELOW"))
        if r["missed"]:
            print("      lines not hit: %s" % line_ranges(r["missed"]))
    failed = [t for t in results if not t["ok"]]
    for t in failed:
        print("FAIL %s::%s  %s" % (t["file"], t["name"], " | ".join(t["messages"])[:400]))
    for problem in problems:
        print("BROKEN " + problem)
    if failed or problems or code != 0:
        return 1
    if any(not r["ok"] for r in rows):
        print("Below the baseline from these suites: add a test for the lines above, or widen --suites if other suites "
              "cover them. The full ratchet runs at the round end.")
        return 3
    return 0


def main():
    parser = argparse.ArgumentParser(description="Line and function coverage for the PositiveFPS scripts.")
    gate = parser.add_mutually_exclusive_group()
    gate.add_argument("--check-baseline", action="store_true",
                      help="fail (exit 3) if coverage dropped versus coverage_baseline.json")
    gate.add_argument("--update-baseline", action="store_true",
                      help="write the current numbers to coverage_baseline.json (only if the tests pass)")
    parser.add_argument("--check-determinism", action="store_true",
                        help="run the instrumented suite twice and fail (exit 3) if the covered lines differ")
    parser.add_argument("--check-files", nargs="+", metavar="SCRIPT",
                        help="quick check for a part agent: run only the suites that cover these scripts, instrumented, "
                             "and report each script's line coverage against the baseline with the lines not hit")
    parser.add_argument("--suites", nargs="+", metavar="SUITE",
                        help="with --check-files: the test suites to run (default: the ones that name the scripts)")
    parser.add_argument("--fresh", action="store_true",
                        help="with --check-determinism: ignore the saved run and make two fresh runs")
    parser.add_argument("--allow-decrease", action="store_true",
                        help="with --update-baseline: accept numbers lower than the baseline")
    parser.add_argument("--workers", type=int, default=None,
                        help="test processes to run at once (default: tools/run_tests.py WORKERS_DEFAULT)")
    args = parser.parse_args()
    if args.allow_decrease and not args.update_baseline:
        parser.error("--allow-decrease only applies with --update-baseline")

    if args.suites and not args.check_files:
        parser.error("--suites only applies with --check-files")
    if args.check_files:
        if args.check_baseline or args.update_baseline or args.check_determinism:
            parser.error("--check-files cannot be combined with the baseline or determinism options")
        return check_files(args.check_files, args.suites, args.workers)

    if args.check_determinism:
        if args.check_baseline or args.update_baseline:
            parser.error("--check-determinism cannot be combined with the baseline options")
        return check_determinism(args.workers, fresh=args.fresh)

    fp = code_fingerprint()  # the code this run measures; a clean run is saved against it (save_clean_run)
    print("== Copying project to %s" % BUILD)
    copy_project()
    print("== Instrumenting scripts/*.gd (line probes)")
    files, uninstr = instrument_build()
    write_probe_files()
    total_lines = sum(len(f["exec"]) for f in files.values())
    print("   %d executable lines in %d files, %d functions not measurable"
          % (total_lines, len(files), len(uninstr)))

    os.makedirs(HITS_DIR, exist_ok=True)
    print("== Running the test suite (headless) against the instrumented copy")
    problems = []  # broken scripts and skipped suites (run_tests.integrity_problems), listed again at the end
    try:
        code, results, _report_dir = run_tests.run_suite(BUILD, report_root=REPORTS_DIR, workers=args.workers,
                                                         cov_dir=HITS_DIR, problems=problems)
    except (RuntimeError, OSError) as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    if results is None:
        for p in problems:
            print("BROKEN " + p, file=sys.stderr)
        print("ERROR: no test results were written; see the Godot output above.", file=sys.stderr)
        return 2

    hits = merge_hits(HITS_DIR)
    if hits is None:
        print("ERROR: no hits file was written by the coverage autoload.", file=sys.stderr)
        return 2

    stats = build_stats(files, hits, results)
    git = git_info()
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    write_reports(stats, results, uninstr, files, hits, git, stamp)

    print("")
    print(render_summary(stats, git, stamp))
    print("Report: %s" % os.path.join(COVERAGE_DIR, "index.html"))
    failed = [r for r in results if not r["ok"]]
    for r in failed:
        print("FAIL %s::%s  %s" % (r["file"], r["name"], " | ".join(r["messages"])[:400]))
    for p in problems:
        print("BROKEN " + p)
    tests_ok = not failed and not problems and code == 0
    save_clean_run(fp, code, results, stats, hits, unit_hits(HITS_DIR))

    if args.update_baseline:
        if not tests_ok:
            print("Baseline NOT updated: the tests did not all pass.")
            return 1
        base = _load_baseline()
        if base is not None:
            rows, _failures, decreases = compare_to_baseline(stats, base)
            print_comparison(rows)
            if decreases and not args.allow_decrease:
                print("Baseline NOT updated: these numbers went down: %s. Re-run with --allow-decrease "
                      "if that is intended." % ", ".join(decreases))
                return 3
        with open(BASELINE, "w", encoding="utf-8", newline="\n") as fh:
            json.dump({"line_overall": stats["line_overall"], "line_files": stats["line_files"]},
                      fh, indent=2, sort_keys=True)
            fh.write("\n")
        print("Baseline updated: %s" % BASELINE)
        return 0

    if args.check_baseline:
        base = _load_baseline()
        if base is None:
            print("ERROR: no %s. Create it with: python tools/coverage.py --update-baseline" % BASELINE,
                  file=sys.stderr)
            return 2
        rows, failures, _decreases = compare_to_baseline(stats, base)
        print("")
        print("Coverage against baseline:")
        print_comparison(rows)
        if not tests_ok:
            return 1
        if failures:
            print("")
            print("COVERAGE CHECK FAILED:")
            for reason in failures:
                print("  - " + reason)
            print("Add tests, or if the drop is intended run: python tools/coverage.py --update-baseline "
                  "--allow-decrease")
            return 3
        print("Baseline OK.")
    return 1 if not tests_ok else 0


def _load_baseline():
    if not os.path.exists(BASELINE):
        return None
    with open(BASELINE, encoding="utf-8-sig") as fh:  # tolerates a BOM from some editors
        return json.load(fh)


if __name__ == "__main__":
    sys.exit(main())
