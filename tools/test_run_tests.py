#!/usr/bin/env python3
"""Self-check that tools/run_tests.py fails loudly when a test suite cannot load. Run:
    python tools/test_run_tests.py

The parsing tests need no Godot. The end-to-end test copies tools/fixtures/warning_error_suite.gd (a suite that only
fails under the project's warnings-as-errors setting) into a scratch project in .scratch/ and runs the real CLI on it;
it is skipped when Godot cannot be found.
"""
import os
import shutil
import subprocess
import sys
import time
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import run_tests  # noqa: E402
from godot_path import godot_console  # noqa: E402

FIXTURE = os.path.join(TOOLS, "fixtures", "warning_error_suite.gd")

# Trimmed from a real Godot 4.7 run on that fixture (one parallel unit).
PARSE_OUTPUT = "\n".join([
    "Godot Engine v4.7.2.stable.official",
    'SCRIPT ERROR: Parse Error: The argument 1 of the constructor "int()" requires the subtype "int", "bool", or '
    '"float" but the supertype "Variant" was provided. (Warning treated as error.)',
    "   at: GDScript::reload (res://tests/warn_cast_test.gd:9)",
    "   GDScript backtrace (most recent call first):",
    "       [0] load_with_disabled_warnings (res://addons/gdUnit4/src/core/GdUnitTestSuiteScanner.gd:225)",
    'ERROR: Failed to load script "res://tests/warn_cast_test.gd" with error "Parse error".',
    "   at: load (modules/gdscript/gdscript_resource_format.cpp:46)",
    "\x1b[38;2;220;20;60mScript errors were detected during test discovery!\x1b[0m",
    "\x1b[38;2;220;20;60mAbnormal exit with 105\x1b[0m",
])


def remove_tree(path):
    """rmtree that retries: Windows (and OneDrive) can hold a freshly used folder for a moment."""
    for _ in range(10):
        shutil.rmtree(path, ignore_errors=True)
        if not os.path.exists(path):
            return
        time.sleep(0.5)


class PruneReportsTest(unittest.TestCase):
    def test_keeps_the_newest_runs_and_leaves_other_folders_alone(self):
        import tempfile
        root = tempfile.mkdtemp(prefix="prune_reports_")
        try:
            stamps = ["20261101-0900%02d" % i for i in range(5)]
            for name in stamps + ["determinism-1", "notes"]:
                os.makedirs(os.path.join(root, name, "u00"))
            removed = run_tests.prune_reports(root, keep=2)
            self.assertEqual(removed, stamps[:3])
            self.assertEqual(sorted(os.listdir(root)), sorted(stamps[3:] + ["determinism-1", "notes"]))
            self.assertEqual(run_tests.prune_reports(os.path.join(root, "missing")), [])
        finally:
            remove_tree(root)


class BrokenScriptParsingTest(unittest.TestCase):
    def test_parse_error_names_file_and_line(self):
        found = run_tests.broken_scripts(PARSE_OUTPUT)
        self.assertEqual(list(found), ["tests/warn_cast_test.gd:9"])  # the failed load of the same file is not repeated
        self.assertIn("Warning treated as error", found["tests/warn_cast_test.gd:9"])

    def test_failed_load_alone_still_names_file(self):
        found = run_tests.broken_scripts('ERROR: Failed to load script "res://tests/a_test.gd" with error "x".')
        self.assertEqual(found, {"tests/a_test.gd": "failed to load"})

    def test_clean_output_has_no_problems(self):
        self.assertEqual(run_tests.output_problems(["Tests passed", "Run dispose test resources"]), [])

    def test_same_error_in_two_units_is_reported_once(self):
        self.assertEqual(len(run_tests.output_problems([PARSE_OUTPUT, PARSE_OUTPUT])), 1)

    def test_unattributed_script_error_still_counts(self):
        problems = run_tests.output_problems(["SCRIPT ERROR: something odd"])
        self.assertEqual(len(problems), 1)

    def test_suite_without_results_is_reported_by_path(self):
        problems = run_tests.integrity_problems(run_tests.ROOT, [], [])
        self.assertTrue(any(p.startswith("tests/") and "did not report" in p for p in problems))


@unittest.skipIf(godot_console() is None, "Godot not found (GODOT, PATH or WinGet)")
class BrokenSuiteEndToEndTest(unittest.TestCase):
    """The real CLI on a scratch project with one good suite and the broken fixture: non-zero exit, file named last."""

    def setUp(self):
        # One folder per test: on Windows the previous test's folder can still be locked when the next one starts.
        self.project = os.path.join(run_tests.ROOT, ".scratch",
                                    "run_tests_broken_%d_%s" % (os.getpid(), self._testMethodName))
        remove_tree(self.project)
        tests_dir = os.path.join(self.project, "tests")
        os.makedirs(tests_dir)
        shutil.copy(os.path.join(run_tests.ROOT, "project.godot"), self.project)
        shutil.copytree(os.path.join(run_tests.ROOT, "addons"), os.path.join(self.project, "addons"))
        with open(os.path.join(tests_dir, "good_test.gd"), "w", encoding="utf-8", newline="") as fh:
            fh.write("extends GdUnitTestSuite\n\n\nfunc test_ok() -> void:\n\tassert_int(1).is_equal(1)\n")
        shutil.copy(FIXTURE, os.path.join(tests_dir, "warn_cast_test.gd"))

    def tearDown(self):
        remove_tree(self.project)

    def run_cli(self, *extra):
        proc = subprocess.run([sys.executable, os.path.join(TOOLS, "run_tests.py"), "--project", self.project]
                              + list(extra), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        return proc.returncode, proc.stdout.decode("utf-8", errors="replace")

    def test_parallel_run_fails_and_names_the_suite(self):
        code, out = self.run_cli("--workers", "2")
        self.assertNotEqual(code, 0)
        tail = out.strip().splitlines()[-3:]
        self.assertTrue(any(ln.startswith("Tests: 1 passed, 0 failed, ") and "broken or skipped" in ln for ln in tail),
                        tail)
        self.assertTrue(any(ln.startswith("BROKEN tests/warn_cast_test.gd:9: Parse Error") for ln in tail), tail)

    def test_serial_run_fails_too(self):
        code, out = self.run_cli("--workers", "1")
        self.assertNotEqual(code, 0)
        self.assertIn("BROKEN tests/warn_cast_test.gd:9", out)


if __name__ == "__main__":
    unittest.main()
