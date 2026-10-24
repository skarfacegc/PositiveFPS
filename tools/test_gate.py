#!/usr/bin/env python3
"""Dry run of the gate cache rules in tools/gate.py (no Godot needed). Exits 1 if any answer is wrong.

Checks which paths count towards the fingerprint, and that the fingerprint changes when (and only when) a file the
gate depends on changes. Run by tools/test_hook_paths.sh.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate  # noqa: E402

failures = []


def expect(label, got, want):
    if got != want:
        failures.append("%s: expected %r, got %r" % (label, want, got))


for path, want in [
    ("scripts/border.gd", True), ("scripts/border.gd.uid", True), ("tests/x_test.gd", True),
    ("tools/gate.py", True), ("tools/test_weights.json", True), ("topdown.tscn", True), ("menu.tscn", True),
    ("theme.tres", True), ("project.godot", True), ("gdlintrc", True), ("coverage_baseline.json", True),
    ("addons/gdUnit4/plugin.cfg", True), (".githooks/pre-commit", True),
    ("design/style_test/project.godot", False), ("design/a.tscn", False), ("README.md", False),
    ("IDEAS.md", False), ("tools/BUILD_TIMINGS.md", False), ("tools/__pycache__/gate.cpython-312.pyc", False), (".scratch/x.gd", False),
    ("reports/x/results.xml", False), ("coverage/index.html", False), ("addons/gdUnit4/src/x.gd", False),
]:
    expect("depends_on(%s)" % path, gate.depends_on(path), want)

probe_dep = os.path.join(gate.ROOT, "tests", "zz_fingerprint_probe.gd")
probe_doc = os.path.join(gate.ROOT, "design", "zz_fingerprint_probe.tscn")
base = gate.fingerprint()
expect("fingerprint is stable", gate.fingerprint(), base)
try:
    os.makedirs(os.path.dirname(probe_doc), exist_ok=True)
    with open(probe_doc, "w", encoding="utf-8") as fh:
        fh.write("x")
    expect("a file under design/ does not change the fingerprint", gate.fingerprint(), base)
    with open(probe_dep, "w", encoding="utf-8") as fh:
        fh.write("extends Node\n")
    changed = gate.fingerprint()
    expect("a new untracked test file changes the fingerprint", changed != base, True)
    with open(probe_dep, "w", encoding="utf-8", newline="") as fh:
        fh.write("extends Node\r\n")
    expect("line endings do not change the fingerprint", gate.fingerprint(), changed)
    with open(probe_dep, "w", encoding="utf-8") as fh:
        fh.write("extends Node2D\n")
    expect("editing the file changes the fingerprint", gate.fingerprint() not in (base, changed), True)
finally:
    for path in (probe_dep, probe_doc):
        if os.path.exists(path):
            os.remove(path)
expect("fingerprint returns to the start", gate.fingerprint(), base)


# --- Gate hole (round 12b): a test file with a parse error must fail the run, not be skipped quietly. ---
import shutil  # noqa: E402
import time  # noqa: E402
import run_tests  # noqa: E402

NL = chr(10)
SAMPLE = NL.join(["ok", "SCRIPT ERROR: Parse Error: x", "   at: y"])
expect("script_problems finds a parse error", len(run_tests.script_problems(SAMPLE)), 1)
expect("script_problems ignores clean output", run_tests.script_problems("Tests passed"), [])


def remove_tree(path):
    """rmtree that retries: Windows (and OneDrive) can hold a freshly used folder for a moment."""
    for _ in range(10):
        shutil.rmtree(path, ignore_errors=True)
        if not os.path.exists(path):
            return
        time.sleep(0.5)


def write_suite(folder, name, body_lines):
    with open(os.path.join(folder, name), "w", encoding="utf-8", newline="") as fh:
        fh.write(NL.join(["extends GdUnitTestSuite", "", ""] + body_lines) + NL)


scratch = os.path.join(gate.ROOT, ".scratch", "gate_broken_%d" % os.getpid())
try:
    remove_tree(scratch)
    os.makedirs(os.path.join(scratch, "tests"))
    shutil.copy(os.path.join(gate.ROOT, "project.godot"), scratch)
    shutil.copytree(os.path.join(gate.ROOT, "addons"), os.path.join(scratch, "addons"))
    tests_dir = os.path.join(scratch, "tests")
    write_suite(tests_dir, "good_test.gd", ["func test_ok() -> void:", "	assert_int(1).is_equal(1)"])
    write_suite(tests_dir, "good2_test.gd", ["func test_ok2() -> void:", "	assert_int(2).is_equal(2)"])
    code, results, _ = run_tests.run_suite(scratch, workers=2)
    expect("a healthy scratch project passes", code, 0)
    write_suite(tests_dir, "broken_test.gd", ["func test_broken() -> void:", "	var x: int = ", "	assert_int(x).is_equal(1"])
    code, results, _ = run_tests.run_suite(scratch, workers=2)
    expect("a suite with a parse error fails the run", code != 0, True)
    problems = run_tests.integrity_problems(scratch, results, [])  # the check itself, whatever Godot's exit code says
    expect("the skipped suite is reported by name", any("broken_test" in p for p in problems), True)
    code, results, _ = run_tests.run_suite(scratch, workers=1)
    expect("a suite with a parse error fails the serial run", code != 0, True)
finally:
    remove_tree(scratch)


if failures:
    print("test_gate: FAILED")
    for line in failures:
        print("  " + line)
    sys.exit(1)
print("test_gate: all cases pass")
