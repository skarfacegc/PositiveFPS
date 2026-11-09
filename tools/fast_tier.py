#!/usr/bin/env python3
"""Change-based test selection for the pre-commit hook (`python tools/run_tests.py --tier fast`).

The fast tier runs every test whose recorded duration is under FAST_TIER_SECONDS, plus the slower tests that the change
can reach:
  * a changed tests/*_test.gd runs all of its suite;
  * a changed function (or a changed line outside any function) in a scripts/*.gd file runs the slow tests whose
    coverage includes that function (or that file). The coverage comes from the saved clean instrumented run
    (tools/coverage.py save_clean_run: per-unit line hits, which tests each unit ran, and the text of every script as it
    was when the run was made).
Anything this cannot map falls back to running everything, with the reason printed: no or old coverage map, a deleted
script, scripts/config.gd and the scripts/*_config.gd files (every test reads them), scenes, resources, project.godot, addons, the test
helper, the test tooling itself. Docs, other tools and the hook scripts cannot change a Godot test result and are ignored.

The changed lines are the diff against a base (HEAD by default; a merge base for a branch). The saved map may be older
than the base, so changed lines are translated into the map's line numbers by diffing the map's script text against the
base's text; lines that moved or changed since the map select what the map said about that whole region.

Only the Python standard library is used. The functions are pure where possible so tools/test_fast_tier.py needs no Godot.
"""
import difflib
import gzip
import json
import os
import re
import subprocess

# Tooling whose change can alter how tests run or are judged: it needs the whole suite.
TOOLS_AFFECTING_TESTS = {"run_tests.py", "gate.py", "coverage.py", "godot_run.py", "godot_path.py", "fast_tier.py"}
ALL_SCRIPTS = {"scripts/config.gd"}  # read by every test (and every scripts/*_config.gd, see impact)
HUNK_RE = re.compile(r"^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@")
FUNC_RE = re.compile(r"^(\t*)(?:static\s+)?func\s+(\w+)")


def impact(path):
    """How a changed path can affect Godot tests: "none", "script" (a scripts/*.gd the map can handle), "suite" (a
    tests/*_test.gd) or "all" (cannot tell: run everything)."""
    p = path.replace("\\", "/")
    if p.endswith((".md", ".uid")) or p.startswith(("design/", ".githooks/", ".scratch/", "coverage/", "reports/")):
        return "none"
    if p in ("coverage_baseline.json", "gdlintrc", ".gitignore", ".gitattributes", "tools/test_weights.json"):
        return "none"
    if p.startswith("tools/"):
        name = p[len("tools/"):]
        if "/" in name:
            return "all"  # tools/fixtures/...
        if name.endswith((".py", ".sh")):
            return "all" if name in TOOLS_AFFECTING_TESTS else "none"
        return "none" if name.endswith((".md", ".txt")) else "all"
    if p in ALL_SCRIPTS or (p.startswith("scripts/") and p.endswith("_config.gd") and "/" not in p[len("scripts/"):]):
        return "all"
    if p.startswith("scripts/") and p.endswith(".gd"):
        return "script"
    if p.startswith("tests/") and p.endswith("_test.gd") and "/" not in p[len("tests/"):]:
        return "suite"
    return "all"


def normalise(text):
    return text.replace("\r\n", "\n")


def parse_diff(text):
    """{path: {"status": "M"|"A"|"D", "hunks": [(old_start, old_count)]}} from `git diff -U0 --no-renames` output."""
    out = {}
    cur = None
    for line in text.splitlines():
        if line.startswith("diff --git "):
            m = re.match(r"diff --git a/(.*) b/(.*)$", line)
            cur = out.setdefault(m.group(2) if m else line, {"status": "M", "hunks": []})
        elif cur is not None and line.startswith("new file mode"):
            cur["status"] = "A"
        elif cur is not None and line.startswith("deleted file mode"):
            cur["status"] = "D"
        elif cur is not None:
            h = HUNK_RE.match(line)
            if h:
                cur["hunks"].append((int(h.group(1)), 1 if h.group(2) is None else int(h.group(2))))
    return out


def func_spans(lines):
    """[(name, first, last)] (1-based, inclusive) for each func in the GDScript lines. A function ends before the next
    code line indented no deeper than its `func` line."""
    spans = []
    for i, line in enumerate(lines):
        m = FUNC_RE.match(line)
        if not m:
            continue
        depth = len(m.group(1))
        last = i
        for j in range(i + 1, len(lines)):
            body = lines[j]
            if not body.strip() or body.lstrip().startswith("#"):
                continue
            if len(body) - len(body.lstrip("\t")) <= depth:
                break
            last = j
        spans.append((m.group(2), i + 1, last + 1))
    return spans


def changed_base_lines(hunks, n_lines):
    """The base-side line numbers a diff touched. A pure insertion after line a touches a and a + 1."""
    lines = set()
    for start, count in hunks:
        rng = range(start, start + count) if count else (start, start + 1)
        lines.update(n for n in rng if 1 <= n <= n_lines)
    return lines


def to_map_lines(map_lines, base_lines, changed):
    """Translates base-side line numbers into the map's: an unchanged line to its twin; a line in a region that differs
    between map and base to the whole region of the map (and its neighbours when the region is empty there)."""
    if map_lines == base_lines:
        return set(changed)
    out = set()
    matcher = difflib.SequenceMatcher(None, map_lines, base_lines, autojunk=False)
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        hit = [j for j in range(j1 + 1, j2 + 1) if j in changed]
        if not hit:
            continue
        if tag == "equal":
            out.update(i1 + (j - j1) for j in hit)
        else:
            region = range(i1 + 1, i2 + 1) if i2 > i1 else (i1, i1 + 1)  # (the map has nothing there: its neighbours)
            out.update(n for n in region if 1 <= n <= len(map_lines))
    return out


def regions_of_change(map_text, base_text, hunks):
    """(functions, whole_file) for a script. functions is {name: (first, last, changed map lines)} for the map's functions
    the change touches; whole_file is True when a changed line lies outside every function (then the whole file counts)."""
    map_lines = normalise(map_text).split("\n")
    base_lines = normalise(base_text).split("\n")
    changed = changed_base_lines(hunks, len(base_lines))
    mapped = to_map_lines(map_lines, base_lines, changed)
    spans = func_spans(map_lines)
    funcs = {}
    whole = False
    for n in mapped:
        owner = next((s for s in spans if s[1] <= n <= s[2]), None)
        if owner is None:
            whole = True
        else:
            funcs.setdefault(owner[0], (owner[1], owner[2], set()))[2].add(n)
    return funcs, whole


def units_hitting_lines(units, path, lines):
    """{line: set of unit names whose hits include that line of `path`} for the lines asked about."""
    prefix = path + ":"
    found = {n: set() for n in lines}
    for name, hits in units.items():
        for key in hits:
            if key.startswith(prefix):
                line = int(key[len(prefix):])
                if line in found:
                    found[line].add(name)
    return found


def units_hitting(units, path, spans):
    """Names of the units whose hits include a line of `path` inside any (first, last) span; spans None = any line."""
    prefix = path + ":"
    found = set()
    for name, hits in units.items():
        for key in hits:
            if not key.startswith(prefix):
                continue
            line = int(key[len(prefix):])
            if spans is None or any(a <= line <= b for a, b in spans):
                found.add(name)
                break
    return found


def select(tests, weights, threshold, changes, map_data, read_base):
    """Chooses the tests to run.

    tests: {suite: [names]} discovered. weights: {"suite::test": seconds}. changes: {path: {"status", "hunks"}}.
    map_data: {"units", "plan", "scripts"} (see coverage.save_clean_run) or None. read_base(path): the base text of a
    file, or None. Returns {"selected": {suite: [names]} or None, "notes": [str], "reason": str or None,
    "fast": n, "slow_total": n, "slow_selected": n}. selected None means "run everything" and reason says why.
    """
    notes = []

    def everything(reason):
        return {"selected": None, "notes": notes, "reason": reason, "fast": 0, "slow_total": 0, "slow_selected": 0}

    def seconds(suite, name):
        return weights.get("%s::%s" % (suite, name), 0.5)

    chosen = {s: set() for s in tests}
    slow_total = 0
    for suite, names in tests.items():
        for name in names:
            if seconds(suite, name) < threshold:
                chosen[suite].add(name)
            else:
                slow_total += 1
    fast = sum(len(v) for v in chosen.values())

    script_changes = {}
    for path, info in sorted(changes.items()):
        kind = impact(path)
        if kind == "all":
            return everything("%s changed and cannot be mapped to tests" % path)
        if kind == "suite":
            suite = path[len("tests/"):-3]
            if suite in tests:
                chosen[suite].update(tests[suite])
                notes.append("%s changed: its whole suite runs" % path)
        elif kind == "script":
            if info["status"] == "D":
                return everything("%s was deleted" % path)
            script_changes[path] = info
    if script_changes:
        if not map_data or not map_data.get("units") or not map_data.get("plan") or not map_data.get("scripts"):
            return everything("no coverage map from a full coverage run (run tools/gate.py --full or "
                              "tools/coverage.py --check-determinism to make one)")
        units, plan, scripts = map_data["units"], map_data["plan"], map_data["scripts"]
        covered = set()  # tests the map knows
        for entry in plan.values():
            covered.update((entry["suite"], n) for n in entry["tests"])
        for path, info in script_changes.items():
            if info["status"] == "A":
                notes.append("%s is new: no existing test covers it" % path)
                continue
            if path not in scripts:
                return everything("%s is not in the coverage map" % path)
            base_text = read_base(path)
            if base_text is None:
                return everything("cannot read the base version of %s" % path)
            funcs, whole = regions_of_change(scripts[path], base_text, info["hunks"])
            if whole:
                hit_units = units_hitting(units, path, None)
            else:
                # Line level where it is safe: every changed line was executed by some unit, so only the units that ran
                # those lines can behave differently. A changed line nobody ran (a signature, a comment, an else:, a
                # continuation) falls back to the whole function.
                by_line = units_hitting_lines(units, path, set().union(*(f[2] for f in funcs.values())))
                spans = []
                hit_units = set()
                for first, last, lines in funcs.values():
                    if all(by_line[n] for n in lines):
                        for n in lines:
                            hit_units |= by_line[n]
                    else:
                        spans.append((first, last))
                if spans:
                    hit_units |= units_hitting(units, path, spans)
            picked = set()
            for unit in hit_units:
                entry = plan.get(unit)
                if entry:
                    picked.update((entry["suite"], n) for n in entry["tests"])
            slow = [(s, n) for (s, n) in picked if s in tests and n in tests[s] and seconds(s, n) >= threshold]
            for s, n in slow:
                chosen[s].add(n)
            what = "outside any function (whole file)" if whole else ", ".join(sorted(funcs)) or "no function"
            notes.append("%s: %s -> %d slow test(s)" % (path, what, len(slow)))
        # A slow test the map never saw (added since) cannot be judged: run it.
        for suite, names in tests.items():
            for name in names:
                if seconds(suite, name) >= threshold and (suite, name) not in covered:
                    chosen[suite].add(name)
    selected = {s: [n for n in tests[s] if n in chosen[s]] for s in tests if chosen[s]}
    slow_selected = sum(1 for s, names in selected.items() for n in names if seconds(s, n) >= threshold)
    return {"selected": selected, "notes": notes, "reason": None, "fast": fast, "slow_total": slow_total,
            "slow_selected": slow_selected}


# --- git and the saved map -------------------------------------------------------------------------------------------

def _git(root, *args):
    return subprocess.run(["git", "-C", root, "-c", "core.quotepath=off"] + list(args), capture_output=True,
                          text=True, encoding="utf-8", errors="replace", check=True).stdout


def git_changes(root, base="HEAD"):
    """{path: {"status", "hunks"}} for the working tree against `base`, with untracked files as new. Raises
    subprocess.CalledProcessError / OSError when git cannot say."""
    changes = parse_diff(_git(root, "diff", base, "-U0", "--no-color", "--no-renames", "--no-ext-diff"))
    for path in _git(root, "ls-files", "--others", "--exclude-standard").splitlines():
        if path and path not in changes:
            changes[path] = {"status": "A", "hunks": []}
    return changes


def git_base_text(root, path, base="HEAD"):
    try:
        return _git(root, "show", "%s:%s" % (base, path))
    except (OSError, subprocess.CalledProcessError):
        return None


def load_map(units_file):
    """The saved coverage map ({"units", "plan", "scripts"}), or None when it is missing or from an older tool."""
    try:
        with gzip.open(units_file, "rt", encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError, TypeError):
        return None
    return data if isinstance(data, dict) else None


def choose(root, tests, weights, threshold, units_file, base="HEAD"):
    """select() for the real repo: reads the git changes and the saved map."""
    try:
        changes = git_changes(root, base)
    except (OSError, subprocess.CalledProcessError) as err:
        return {"selected": None, "notes": [], "reason": "git could not list the changes (%s)" % err, "fast": 0,
                "slow_total": 0, "slow_selected": 0}
    return select(tests, weights, threshold, changes, load_map(units_file), lambda p: git_base_text(root, p, base))


def describe(result, weights, threshold, tests):
    """Printable lines saying what the fast tier chose and why."""
    total = sum(len(v) for v in tests.values())
    if result["selected"] is None:
        return ["fast tier: running ALL %d tests: %s" % (total, result["reason"])]

    def secs(items):
        return sum(weights.get("%s::%s" % (s, n), 0.5) for s, names in items.items() for n in names)

    sel = result["selected"]
    n_sel = sum(len(v) for v in sel.values())
    skipped = {s: [n for n in tests[s] if n not in sel.get(s, [])] for s in tests}
    lines = ["fast tier: %d of %d tests (%d under %.0f s, %d slow chosen by the change); about %.0f s of test time "
             "chosen, %.0f s skipped" % (n_sel, total, result["fast"], threshold, result["slow_selected"],
                                         secs(sel), secs(skipped))]
    lines += ["  " + n for n in result["notes"]]
    if not result["notes"]:
        lines.append("  no script or test changes: only the fast tests run")
    return lines
