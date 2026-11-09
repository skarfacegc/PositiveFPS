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


class GdignoreTest(unittest.TestCase):
    def test_existing_output_folders_get_a_gdignore_once(self):
        import tempfile
        root = tempfile.mkdtemp(prefix="gdignore_")
        try:
            os.makedirs(os.path.join(root, "reports"))
            os.makedirs(os.path.join(root, "scripts"))
            self.assertEqual(run_tests.ensure_gdignore(root), ["reports"])
            self.assertTrue(os.path.isfile(os.path.join(root, "reports", ".gdignore")))
            self.assertFalse(os.path.exists(os.path.join(root, "coverage")))
            self.assertFalse(os.path.exists(os.path.join(root, "scripts", ".gdignore")))
            self.assertEqual(run_tests.ensure_gdignore(root), [])
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


class ImportIsCurrentTest(unittest.TestCase):
    """import_is_current() is True only when nothing the Godot import cache depends on is newer than the last import."""

    STAMP = 1_000_000_000.0

    def setUp(self):
        import tempfile
        self.root = tempfile.mkdtemp(prefix="import_current_")
        for sub in ("scripts", "tests", "scenes", "resources", "shaders", "addons/x", "art/fonts", "design", "reports",
                    ".scratch", "coverage", ".coverage_build", "tools"):
            os.makedirs(os.path.join(self.root, sub))
        for rel in ("project.godot", "scripts/a.gd", "tests/a_test.gd", "scenes/a.tscn", "resources/a.tres",
                    "shaders/a.gdshader", "addons/x/p.gd", "art/a.png", "art/fonts/f.ttf", "art/a.png.import",
                    "README.md", "tools/x.py"):
            self.write(rel)
        os.makedirs(os.path.join(self.root, ".godot"))
        self.write(".godot/global_script_class_cache.cfg")
        self.age_everything()

    def tearDown(self):
        remove_tree(self.root)

    def write(self, rel):
        with open(os.path.join(self.root, rel), "w", encoding="utf-8") as fh:
            fh.write("x")

    def age_everything(self):
        """Every file and folder is older than the class cache."""
        for dirpath, _dirs, files in os.walk(self.root):
            for name in files + [""]:
                os.utime(os.path.join(dirpath, name) if name else dirpath, (self.STAMP - 100, self.STAMP - 100))
        cache = os.path.join(self.root, ".godot", "global_script_class_cache.cfg")
        os.utime(cache, (self.STAMP, self.STAMP))

    def touch(self, rel):
        os.utime(os.path.join(self.root, rel), (self.STAMP + 50, self.STAMP + 50))

    def test_a_project_nothing_changed_in_is_current(self):
        self.assertTrue(run_tests.import_is_current(self.root))

    def test_no_class_cache_means_import(self):
        os.remove(os.path.join(self.root, ".godot", "global_script_class_cache.cfg"))
        self.assertFalse(run_tests.import_is_current(self.root))

    def test_a_newer_file_in_each_place_that_matters_forces_an_import(self):
        for rel in ("project.godot", "scripts/a.gd", "tests/a_test.gd", "scenes/a.tscn", "resources/a.tres",
                    "shaders/a.gdshader", "addons/x/p.gd", "art/a.png", "art/fonts/f.ttf", "art/a.png.import"):
            with self.subTest(rel):
                self.touch(rel)
                self.assertFalse(run_tests.import_is_current(self.root))
                self.age_everything()
                self.assertTrue(run_tests.import_is_current(self.root))

    def test_a_new_gdignore_import_or_audio_file_forces_an_import(self):
        for rel in ("scripts/.gdignore", "art/new.png.import", "audio.ogg"):
            with self.subTest(rel):
                self.write(rel)
                self.touch(rel)
                self.assertFalse(run_tests.import_is_current(self.root))
                os.remove(os.path.join(self.root, rel))
                self.age_everything()

    def test_a_removed_or_added_file_moves_its_folder_and_forces_an_import(self):
        self.touch("scripts")  # what deleting scripts/a.gd does to the folder's time
        self.assertFalse(run_tests.import_is_current(self.root))

    def test_ignored_folders_and_documents_do_not(self):
        for rel in ("design/x.tscn", "reports/r.xml", ".scratch/s.gd", "coverage/c.html", ".coverage_build/b.gd",
                    "README.md", "tools/x.py"):
            with self.subTest(rel):
                self.write(rel)
                self.touch(rel)
                self.assertTrue(run_tests.import_is_current(self.root))

    def test_the_import_marker_counts_as_a_later_import(self):
        self.touch("scripts/a.gd")
        self.assertFalse(run_tests.import_is_current(self.root))
        marker = os.path.join(self.root, ".godot", run_tests.IMPORT_STAMP)
        with open(marker, "w", encoding="utf-8") as fh:
            fh.write("imported\n")
        os.utime(marker, (self.STAMP + 60, self.STAMP + 60))
        self.assertTrue(run_tests.import_is_current(self.root))


class WeightsAndWorkersTest(unittest.TestCase):
    def test_recorded_durations_win_over_the_committed_weights(self):
        import unittest.mock as mock
        committed = {"a::t": 1.0, "a::u": 2.0}

        def read(path):
            return dict(committed) if path == run_tests.WEIGHTS_FILE else {"a::t": 9.0}
        with mock.patch.object(run_tests, "_read_json_dict", side_effect=read), \
                mock.patch.object(run_tests, "times_cache_path", return_value="recorded.json"):
            self.assertEqual(run_tests.load_weights(), {"a::t": 9.0, "a::u": 2.0})
        with mock.patch.object(run_tests, "_read_json_dict", side_effect=read), \
                mock.patch.object(run_tests, "times_cache_path", return_value=None):
            self.assertEqual(run_tests.load_weights(), committed)

    def test_a_recorded_slow_test_gets_its_own_unit(self):
        tests = {"s_test": ["test_a", "test_b"]}
        before = run_tests.plan_units(tests, {"s_test::test_a": 0.1, "s_test::test_b": 0.1})
        after = run_tests.plan_units(tests, {"s_test::test_a": 0.1, "s_test::test_b": 20.0})
        self.assertEqual([u["name"] for u in before], ["s_test"])
        self.assertEqual({u["name"] for u in after}, {"s_test::test_b", "s_test (rest)"})

    def test_times_are_recorded_for_passing_tests_only_and_read_back(self):
        import tempfile
        import unittest.mock as mock
        path = os.path.join(tempfile.mkdtemp(prefix="times_"), "t.json")
        try:
            with mock.patch.object(run_tests, "times_cache_path", return_value=path):
                run_tests.record_times([{"file": "a_test", "name": "test_x", "ok": True, "time": 1.26},
                                        {"file": "a_test", "name": "test_bad", "ok": False, "time": 9.0}])
                self.assertEqual(run_tests.load_recorded_times(), {"a_test::test_x": 1.3})
        finally:
            remove_tree(os.path.dirname(path))

    def test_default_workers_leave_cores_free_and_are_capped(self):
        cpus = os.cpu_count() or 2
        self.assertLessEqual(run_tests.WORKERS_DEFAULT, 16)
        self.assertGreaterEqual(run_tests.WORKERS_DEFAULT, max(1, min(16, cpus // 2)))


class SelectedTestsTest(unittest.TestCase):
    def test_a_partial_suite_skips_the_tests_that_were_not_selected(self):
        import unittest.mock as mock
        seen = []

        def fake_run(args, cwd, env_extra=None, stream=True):
            seen.append(args)
            return 0, ""
        every = {"s_test": ["test_a", "test_b", "test_c"]}
        with mock.patch.object(run_tests, "discover_tests", return_value=every), \
                mock.patch.object(run_tests, "load_weights", return_value={}), \
                mock.patch.object(run_tests, "run_godot", side_effect=fake_run), \
                mock.patch.object(run_tests, "latest_results_xml", return_value=None):
            run_tests.run_parallel("p", os.path.join(run_tests.ROOT, ".scratch", "sel"), 1,
                                   selected={"s_test": ["test_b"]})
        skipped = [a for a in seen[0] if a.startswith("res://tests/s_test.gd:")]
        self.assertEqual(sorted(skipped), ["res://tests/s_test.gd:test_a", "res://tests/s_test.gd:test_c"])

    def test_the_integrity_check_expects_only_the_selected_tests(self):
        ran = [{"file": "s_test", "name": "test_b", "ok": True}]
        self.assertEqual(run_tests.integrity_problems(run_tests.ROOT, ran, [], selected={"s_test": ["test_b"]}), [])
        self.assertTrue(run_tests.integrity_problems(run_tests.ROOT, ran, [],
                                                     selected={"s_test": ["test_b", "test_z"]}))


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
