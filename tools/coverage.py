#!/usr/bin/env python3
"""Function-level coverage for the PositiveFPS game scripts, plus the test report.

Usage:
    python tools/coverage.py

What it does:
  1. Copies the project to <root>/.coverage_build (addons and tests are copied, not instrumented).
  2. Instruments every function in scripts/*.gd: a line CovProbe.hit("scripts/x.gd:func") is put at the top of
     the body. Functions whose body is on the signature line cannot be instrumented; they are listed as
     "uninstrumentable" and left out of the percentages.
  3. Adds an autoload (only in the copy) that writes the hit counts to coverage_hits.json when Godot exits.
  4. Runs the gdUnit4 suite headless through tools/run_tests.py, against the copy.
  5. Writes <root>/coverage/index.html, summary.txt and coverage.json.

Exit code: 0 if every test passed, 1 if any test failed, 2 if the run itself could not complete.
Only the Python standard library is used.
"""
import datetime
import html
import json
import os
import re
import shutil
import subprocess
import sys

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import run_tests  # noqa: E402

ROOT = os.path.dirname(TOOLS)
BUILD = os.path.join(ROOT, ".coverage_build")
COVERAGE_DIR = os.path.join(ROOT, "coverage")
REPORTS_DIR = os.path.join(ROOT, "reports")
COPY_EXCLUDE = {".git", ".godot", ".coverage_build", "coverage", "reports"}

FUNC_RE = re.compile(r"^(\t*)(static\s+)?func\s+(\w+)\s*\(")

COV_PROBE_GD = '''class_name CovProbe
extends RefCounted
static var hits := {}
static func hit(key: String) -> void:
\thits[key] = hits.get(key, 0) + 1
'''

COV_DUMP_GD = '''extends Node

# Written into the coverage build only. Saves CovProbe hits when Godot quits.


func _exit_tree() -> void:
\tvar path := ProjectSettings.globalize_path("res://coverage_hits.json")
\tvar f := FileAccess.open(path, FileAccess.WRITE)
\tif f != null:
\t\tf.store_string(JSON.stringify(CovProbe.hits, "  "))
\t\tf.close()
'''


def strip_comment(line):
    """Returns the line without a trailing # comment (ignores # inside simple string literals)."""
    in_str = None
    for i, ch in enumerate(line):
        if in_str:
            if ch == in_str and line[i - 1] != "\\":
                in_str = None
        elif ch in "\"'":
            in_str = ch
        elif ch == "#":
            return line[:i]
    return line


def find_functions(rel_path, text):
    """Returns (instrumentable, uninstrumentable) lists of dicts for one script.

    Each entry: {file, func, line} for the signature line (1-based). Instrumentable entries also carry
    'insert_at' (0-based index of the body's first line) and 'indent' (its leading tabs).
    """
    lines = text.split("\n")
    ok, bad = [], []
    for i, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if not m:
            continue
        name = m.group(3)
        indent = m.group(1)
        # Walk the signature (possibly over several lines) until the parenthesis opened on the
        # signature line closes, then look at what follows on that line.
        depth = 0
        opened = False
        end_line = None
        rest = ""
        for j in range(i, len(lines)):
            code = strip_comment(lines[j])
            start = 0
            if j == i:
                start = m.end() - 1  # the "(" after the name
            for k in range(start, len(code)):
                ch = code[k]
                if ch == "(":
                    depth += 1
                    opened = True
                elif ch == ")":
                    depth -= 1
                    if opened and depth == 0:
                        end_line = j
                        rest = code[k + 1:]
                        break
            if end_line is not None:
                break
        if end_line is None:
            bad.append({"file": rel_path, "func": name, "line": i + 1, "reason": "signature not parsed"})
            continue
        colon_pos = rest.rfind(":")
        if colon_pos == -1:
            # Return type or colon on a later line: look for the line that ends with ':'.
            k = end_line + 1
            while k < len(lines) and strip_comment(lines[k]).strip() == "":
                k += 1
            if k >= len(lines) or not strip_comment(lines[k]).rstrip().endswith(":"):
                bad.append({"file": rel_path, "func": name, "line": i + 1, "reason": "colon not found"})
                continue
            end_line = k
            rest = strip_comment(lines[k])
            colon_pos = rest.rfind(":")
        after_colon = rest[colon_pos + 1:].strip()
        if after_colon:
            bad.append({"file": rel_path, "func": name, "line": i + 1,
                        "reason": "body on the signature line"})
            continue
        # Body: the first following line that has code (blank and comment-only lines are skipped).
        k = end_line + 1
        while k < len(lines) and strip_comment(lines[k]).strip() == "":
            k += 1
        if k >= len(lines):
            bad.append({"file": rel_path, "func": name, "line": i + 1, "reason": "no body"})
            continue
        body_line = lines[k]
        body_indent = re.match(r"^(\t*)", body_line).group(1)
        if len(body_indent) <= len(indent):
            bad.append({"file": rel_path, "func": name, "line": i + 1, "reason": "no indented body"})
            continue
        ok.append({"file": rel_path, "func": name, "line": i + 1, "insert_at": k, "indent": body_indent})
    return ok, bad


def instrument_text(rel_path, text, funcs):
    lines = text.split("\n")
    # Insert from the bottom up so earlier indexes stay valid.
    for f in sorted(funcs, key=lambda d: d["insert_at"], reverse=True):
        probe = '%sCovProbe.hit("%s:%s")' % (f["indent"], rel_path, f["func"])
        lines.insert(f["insert_at"], probe)
    return "\n".join(lines)


def copy_project():
    if os.path.isdir(BUILD):
        shutil.rmtree(BUILD, onerror=_clear_readonly)
    os.makedirs(BUILD)
    for entry in os.listdir(ROOT):
        if entry in COPY_EXCLUDE or entry == "test_results.json" or entry == "coverage_hits.json":
            continue
        src = os.path.join(ROOT, entry)
        dst = os.path.join(BUILD, entry)
        if os.path.isdir(src):
            shutil.copytree(src, dst, ignore=shutil.ignore_patterns(*COPY_EXCLUDE))
        else:
            shutil.copy2(src, dst)


def _clear_readonly(func, path, _exc):
    os.chmod(path, 0o666)
    func(path)


def instrument_build():
    """Instruments scripts/*.gd in the build copy. Returns (manifest, uninstrumentable list)."""
    manifest, bad = [], []
    scripts_dir = os.path.join(BUILD, "scripts")
    for dirpath, _dirs, files in os.walk(scripts_dir):
        for name in sorted(files):
            if not name.endswith(".gd"):
                continue
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, BUILD).replace("\\", "/")
            with open(full, encoding="utf-8", newline="") as fh:
                text = fh.read()
            ok, nope = find_functions(rel, text)
            if ok:
                with open(full, "w", encoding="utf-8", newline="") as fh:
                    fh.write(instrument_text(rel, text, ok))
            manifest.extend({"file": d["file"], "func": d["func"], "line": d["line"]} for d in ok)
            bad.extend(nope)
    return manifest, bad


def write_probe_files():
    tests_dir = os.path.join(BUILD, "tests")
    os.makedirs(tests_dir, exist_ok=True)
    with open(os.path.join(tests_dir, "cov.gd"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(COV_PROBE_GD)
    with open(os.path.join(tests_dir, "cov_dump.gd"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(COV_DUMP_GD)
    project_file = os.path.join(BUILD, "project.godot")
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


def pct(hit, total):
    return 100.0 * hit / total if total else 100.0


def build_stats(manifest, hits, results):
    """Per-file and overall function coverage, plus the test totals."""
    files = {}
    for entry in manifest:
        f = files.setdefault(entry["file"], {"total": 0, "hit": 0, "funcs": []})
        count = hits.get("%s:%s" % (entry["file"], entry["func"]), 0)
        f["total"] += 1
        if count > 0:
            f["hit"] += 1
        f["funcs"].append({"func": entry["func"], "line": entry["line"], "count": count})
    for f in files.values():
        f["funcs"].sort(key=lambda d: d["line"])
    total = sum(f["total"] for f in files.values())
    hit = sum(f["hit"] for f in files.values())
    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    return {
        "files": files,
        "functions_total": total,
        "functions_hit": hit,
        "overall": round(pct(hit, total), 1),
        "tests_total": len(results),
        "tests_passed": passed,
        "tests_failed": failed,
    }


CSS = """
:root { --bg:#f6f7f9; --fg:#1d2330; --muted:#667085; --card:#ffffff; --line:#d9dee7;
  --good:#1f9d55; --bad:#d64545; --bar:#4f7cff; --barbg:#e5e9f1; }
@media (prefers-color-scheme: dark) {
  :root:not([data-theme="light"]) { --bg:#15181f; --fg:#e7eaf0; --muted:#9aa4b5; --card:#1e232d;
    --line:#2f3644; --good:#4cc38a; --bad:#ff6b6b; --bar:#7d9dff; --barbg:#2a3140; } }
:root[data-theme="dark"] { --bg:#15181f; --fg:#e7eaf0; --muted:#9aa4b5; --card:#1e232d;
  --line:#2f3644; --good:#4cc38a; --bad:#ff6b6b; --bar:#7d9dff; --barbg:#2a3140; }
body { margin:0; padding:24px; background:var(--bg); color:var(--fg);
  font:15px/1.45 system-ui, -apple-system, "Segoe UI", sans-serif; }
h1 { font-size:24px; margin:0 0 4px; } h2 { font-size:18px; margin:28px 0 8px; }
.meta { color:var(--muted); margin-bottom:18px; }
.cards { display:flex; flex-wrap:wrap; gap:12px; margin:16px 0; }
.card { background:var(--card); border:1px solid var(--line); border-radius:10px; padding:14px 18px; min-width:170px; }
.card b { display:block; font-size:26px; }
.card span { color:var(--muted); font-size:13px; }
table { width:100%; border-collapse:collapse; background:var(--card); border:1px solid var(--line); border-radius:10px; overflow:hidden; }
th, td { text-align:left; padding:8px 10px; border-bottom:1px solid var(--line); vertical-align:middle; }
th { color:var(--muted); font-weight:600; font-size:13px; }
.bar { background:var(--barbg); border-radius:6px; height:12px; width:220px; overflow:hidden; }
.bar > div { height:100%; background:var(--bar); }
.good { color:var(--good); } .bad { color:var(--bad); font-weight:600; }
.failed { background:var(--card); border:1px solid var(--bad); border-radius:10px; padding:12px 16px; }
.failed li { color:var(--bad); margin:6px 0; }
.failed code { color:var(--fg); white-space:pre-wrap; }
.fn { font-family: ui-monospace, Consolas, monospace; font-size:13px; }
details { background:var(--card); border:1px solid var(--line); border-radius:10px; margin:8px 0; padding:6px 12px; }
summary { cursor:pointer; font-weight:600; padding:6px 0; }
"""


def esc(s):
    return html.escape(str(s))


def render_html(stats, results, uninstr, git, stamp):
    out = []
    w = out.append
    w("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">")
    w("<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
    w("<title>PositiveFPS — test &amp; coverage report</title><style>%s</style></head><body>" % CSS)
    w("<h1>PositiveFPS — test &amp; coverage report</h1>")
    w("<div class=\"meta\">Generated %s &middot; git %s</div>" % (esc(stamp), esc(git)))

    w("<div class=\"cards\">")
    w("<div class=\"card\"><b class=\"%s\">%d passed</b><span>tests</span></div>"
      % ("good" if stats["tests_failed"] == 0 else "bad", stats["tests_passed"]))
    w("<div class=\"card\"><b class=\"%s\">%d failed</b><span>tests</span></div>"
      % ("good" if stats["tests_failed"] == 0 else "bad", stats["tests_failed"]))
    w("<div class=\"card\"><b>%.1f%%</b><span>function coverage (%d of %d hit)</span></div>"
      % (stats["overall"], stats["functions_hit"], stats["functions_total"]))
    w("</div>")

    failed = [r for r in results if not r["ok"]]
    if failed:
        w("<h2>Failed tests</h2><div class=\"failed\"><ul>")
        for r in failed:
            w("<li><span class=\"fn\">%s::%s</span>" % (esc(r["file"]), esc(r["name"])))
            for m in r["messages"]:
                w("<br><code>%s</code>" % esc(m))
            w("</li>")
        w("</ul></div>")

    w("<h2>Coverage by file</h2><table><tr><th>File</th><th>Hit / total</th><th>%</th><th>Coverage</th></tr>")
    for name, f in sorted(stats["files"].items(), key=lambda kv: pct(kv[1]["hit"], kv[1]["total"])):
        p = pct(f["hit"], f["total"])
        w("<tr><td class=\"fn\">%s</td><td>%d / %d</td><td>%.1f%%</td>"
          "<td><div class=\"bar\"><div style=\"width:%.1f%%\"></div></div></td></tr>"
          % (esc(name), f["hit"], f["total"], p, p))
    w("</table>")

    w("<h2>Functions</h2>")
    for name, f in sorted(stats["files"].items()):
        p = pct(f["hit"], f["total"])
        w("<details><summary>%s &mdash; %d / %d (%.1f%%)</summary><table>"
          % (esc(name), f["hit"], f["total"], p))
        w("<tr><th>Function</th><th>Line</th><th>Hits</th><th>Status</th></tr>")
        for fn in f["funcs"]:
            ok = fn["count"] > 0
            w("<tr><td class=\"fn\">%s</td><td>%d</td><td>%d</td><td class=\"%s\">%s</td></tr>"
              % (esc(fn["func"]), fn["line"], fn["count"], "good" if ok else "bad",
                 "hit" if ok else "missed"))
        w("</table></details>")

    if uninstr:
        w("<h2>Not measurable</h2><p class=\"meta\">These functions have their body on the signature line, "
          "so they cannot be instrumented. They are not in the percentages.</p><ul>")
        for u in uninstr:
            w("<li class=\"fn\">%s:%d %s (%s)</li>" % (esc(u["file"]), u["line"], esc(u["func"]), esc(u["reason"])))
        w("</ul>")
    w("</body></html>")
    return "\n".join(out)


def render_summary(stats, git, stamp):
    lines = [
        "PositiveFPS test & coverage summary",
        "Generated: %s   git: %s" % (stamp, git),
        "Tests: %d passed, %d failed" % (stats["tests_passed"], stats["tests_failed"]),
        "Function coverage: %.1f%% (%d of %d)" % (stats["overall"], stats["functions_hit"], stats["functions_total"]),
        "",
        "Per file (lowest first):",
    ]
    for name, f in sorted(stats["files"].items(), key=lambda kv: pct(kv[1]["hit"], kv[1]["total"])):
        lines.append("  %-32s %5.1f%%  (%d/%d)" % (name, pct(f["hit"], f["total"]), f["hit"], f["total"]))
    return "\n".join(lines) + "\n"


def main():
    print("== Copying project to %s" % BUILD)
    copy_project()
    print("== Instrumenting scripts/*.gd")
    manifest, uninstr = instrument_build()
    write_probe_files()
    print("   %d functions instrumented, %d not measurable" % (len(manifest), len(uninstr)))

    print("== Running the test suite (headless) against the instrumented copy")
    try:
        code, results, report_dir = run_tests.run_suite(BUILD, report_root=REPORTS_DIR)
    except (RuntimeError, OSError) as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    if results is None:
        print("ERROR: no test results were written; see the Godot output above.", file=sys.stderr)
        return 2

    hits_path = os.path.join(BUILD, "coverage_hits.json")
    if not os.path.exists(hits_path):
        print("ERROR: coverage_hits.json was not written by the coverage autoload.", file=sys.stderr)
        return 2
    with open(hits_path, encoding="utf-8") as fh:
        hits = json.load(fh)

    stats = build_stats(manifest, hits, results)
    git = git_info()
    stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    os.makedirs(COVERAGE_DIR, exist_ok=True)
    with open(os.path.join(COVERAGE_DIR, "index.html"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render_html(stats, results, uninstr, git, stamp))
    with open(os.path.join(COVERAGE_DIR, "summary.txt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render_summary(stats, git, stamp))
    with open(os.path.join(COVERAGE_DIR, "coverage.json"), "w", encoding="utf-8", newline="\n") as fh:
        json.dump({"overall": stats["overall"],
                   "files": {n: round(pct(f["hit"], f["total"]), 1) for n, f in stats["files"].items()}},
                  fh, indent=2)

    print("")
    print(render_summary(stats, git, stamp))
    print("Report: %s" % os.path.join(COVERAGE_DIR, "index.html"))
    failed = [r for r in results if not r["ok"]]
    for r in failed:
        print("FAIL %s::%s  %s" % (r["file"], r["name"], " | ".join(r["messages"])[:400]))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
