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


# --- Determinism reuse (tools/coverage.py): a saved clean run of the same code stands in for pass 1. No Godot here. ---
import coverage  # noqa: E402

saved_file = os.path.join(gate.ROOT, ".scratch", "det_reuse_%d.json" % os.getpid())
real_run_file, real_fingerprint, real_measure = coverage.det_run_file, coverage.code_fingerprint, coverage.measure_once
real_unit_hits = coverage.unit_hits
coverage.unit_hits = lambda _dir: None  # the fake passes write no hits files (a real build folder may be left over)
fake_results = [{"file": "t", "name": "test_a", "ok": True, "messages": [], "time": 0.1}]
fake_stats = {"line_overall": 50.0, "line_files": {"scripts/a.gd": 50.0}}
calls = []


def fake_measure(workers, build, report_root):
    calls.append(build)
    return 0, fake_results, fake_stats, fake_hits[0]


fake_hits = [{"scripts/a.gd:3": 2}]
try:
    os.makedirs(os.path.dirname(saved_file), exist_ok=True)
    coverage.det_run_file = lambda: saved_file
    coverage.measure_once = fake_measure
    coverage.code_fingerprint = lambda: "fp-a"
    coverage.save_clean_run("fp-a", 0, fake_results, fake_stats, fake_hits[0])
    expect("a clean run is saved", coverage.load_saved_run("fp-a") is not None, True)
    expect("a saved run is not reused for other code", coverage.load_saved_run("fp-b"), None)
    coverage.save_clean_run("fp-a", 1, fake_results, fake_stats, {"scripts/a.gd:9": 1})
    expect("a failed run never replaces a saved one", coverage.load_saved_run("fp-a")["hits"], fake_hits[0])
    expect("the check passes when the fresh run matches the saved one", coverage.check_determinism(None), 0)
    expect("with the saved run, only pass 2 is measured", calls, [coverage.DET_BUILDS[1]])
    fake_hits[0] = {"scripts/a.gd:3": 2, "scripts/a.gd:4": 1}  # the fresh run hits a line the saved run did not
    expect("a run that hits other lines fails the check", coverage.check_determinism(None), 3)
    fake_hits[0] = {"scripts/a.gd:3": 2}
    coverage.code_fingerprint = lambda: "fp-c"  # different code: nothing saved, both passes are fresh
    del calls[:]
    expect("without a saved run both passes run", coverage.check_determinism(None), 0)
    expect("two fresh runs when nothing is saved", sorted(calls), sorted(coverage.DET_BUILDS))
finally:
    coverage.det_run_file = real_run_file
    coverage.code_fingerprint = real_fingerprint
    coverage.measure_once = real_measure
    coverage.unit_hits = real_unit_hits
    if os.path.exists(saved_file):
        os.remove(saved_file)


# --- Parallel part opt-out (POSITIVEFPS_PARALLEL_PART=1): the timing pass is skipped, and that must not be cached as a
# full pass. No Godot here. ---
real_load_cache = gate.load_cache
try:
    skipped = {"last_pass": {"fingerprint": "fp-x", "level": "tests", "summary": "S", "perf_skipped": True}}
    enforced = {"last_pass": {"fingerprint": "fp-x", "level": "tests", "summary": "E", "perf_skipped": False}}
    gate.load_cache = lambda: skipped
    expect("a skipped-timing pass answers a request that also skips it",
           gate.cached_summary("fp-x", "tests", True), "S")
    expect("a skipped-timing pass does not answer the default tier", gate.cached_summary("fp-x", "tests", False), None)
    gate.load_cache = lambda: enforced
    expect("an enforcing pass answers the default tier", gate.cached_summary("fp-x", "tests", False), "E")
    expect("an enforcing pass also answers a skipping request", gate.cached_summary("fp-x", "tests", True), "E")
    expect("a tests pass never answers --full", gate.cached_summary("fp-x", "full", False), None)
finally:
    gate.load_cache = real_load_cache

perf_free = [{"file": suite, "name": name, "ok": True, "messages": [], "time": 0.0}
             for suite, names in run_tests.discover_tests(gate.ROOT).items()
             for name in names if not name.startswith(run_tests.PERF_PREFIX)]
expect("the integrity check accepts a run without timing tests when they are skipped",
       run_tests.integrity_problems(gate.ROOT, perf_free, [], skip_perf=True), [])
expect("the integrity check still expects the timing tests otherwise",
       len(run_tests.integrity_problems(gate.ROOT, perf_free, [], skip_perf=False)) > 0, True)
expect("the skip notice names the coordinator's gate", "gate --full" in run_tests.PARALLEL_PART_NOTICE, True)


if failures:
    print("test_gate: FAILED")
    for line in failures:
        print("  " + line)
    sys.exit(1)
print("test_gate: all cases pass")
