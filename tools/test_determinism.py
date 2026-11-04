#!/usr/bin/env python3
"""Self-check of the per-unit hit-count rule in tools/coverage.py (round 23). No Godot here. Run:
    python tools/test_determinism.py

The rule: the hit COUNTS of a test unit (one Godot process) must match between the two determinism passes, except for
a small allowance (a 2-line recorder session-folder race) and the units named in KNOWN_REAL_TIME_UNITS.
"""
import json
import os
import shutil
import sys
import tempfile
import unittest
import unittest.mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import coverage  # noqa: E402

SCRATCH = os.path.join(os.path.dirname(HERE), ".scratch")


def lines(n, base=5):
    return {"scripts/a.gd:%d" % i: base for i in range(1, n + 1)}


class UnitRuleTest(unittest.TestCase):
    def test_identical_units_have_no_differences(self):
        units = {"hits_00.json": lines(50), "hits_01.json": lines(5)}
        self.assertEqual(coverage.unit_count_differences(units, json.loads(json.dumps(units))), {})

    def test_counts_are_compared_for_lines_hit_in_both_and_in_one_only(self):
        a = {"hits_00.json": {"x:1": 3, "x:2": 4, "x:3": 1}}
        b = {"hits_00.json": {"x:1": 3, "x:2": 5, "x:4": 1}}
        self.assertEqual(coverage.unit_count_differences(a, b), {"hits_00.json": 3})  # x:2 changed, x:3 and x:4 one-sided

    def test_units_missing_from_one_run_are_left_out(self):
        self.assertEqual(coverage.unit_count_differences({"hits_00.json": {"x:1": 1}}, {"hits_01.json": {"x:1": 2}}), {})

    def test_a_tiny_difference_is_noise_and_a_big_one_in_an_unknown_suite_is_a_problem(self):
        names = {"hits_00.json": "some_test", "hits_01.json": "other_test"}
        problems, notes = coverage.unit_rule_problems({"hits_00.json": coverage.DIFF_LINES_ALLOWED}, names)
        self.assertEqual((problems, notes), ([], []))
        problems, notes = coverage.unit_rule_problems({"hits_00.json": coverage.DIFF_LINES_ALLOWED + 1}, names)
        self.assertEqual(len(problems), 1)
        self.assertIn("some_test", problems[0])
        self.assertEqual(notes, [])

    def test_the_known_race_is_noted_not_failed_including_the_rest_unit_and_single_test_units(self):
        # The list is empty since round 24 (the looks suites were made repeatable), so the rule is tried on a made-up entry.
        self.assertEqual(coverage.KNOWN_REAL_TIME_UNITS, {})
        with unittest.mock.patch.dict(coverage.KNOWN_REAL_TIME_UNITS, {"racy_test": "made up"}):
            for label in ("racy_test", "racy_test (rest)", "racy_test::test_x"):
                problems, notes = coverage.unit_rule_problems({"hits_03.json": 1090}, {"hits_03.json": label})
                self.assertEqual(problems, [], label)
                self.assertEqual(len(notes), 1, label)
                self.assertIn("1090 lines", notes[0])

    def test_a_unit_with_no_known_name_uses_the_file_name(self):
        problems, _ = coverage.unit_rule_problems({"hits_09.json": 50}, {})
        self.assertIn("hits_09.json", problems[0])

    def test_unit_hits_reads_a_folder_and_keeps_only_lines_that_were_hit(self):
        os.makedirs(SCRATCH, exist_ok=True)
        tmp = tempfile.mkdtemp(prefix="unit_hits-", dir=SCRATCH)
        try:
            with open(os.path.join(tmp, "hits_00.json"), "w") as fh:
                json.dump({"a:1": 2, "a:2": 0}, fh)
            with open(os.path.join(tmp, "notes.txt"), "w") as fh:
                fh.write("ignored")
            self.assertEqual(coverage.unit_hits(tmp), {"hits_00.json": {"a:1": 2}})
            self.assertIsNone(coverage.unit_hits(os.path.join(tmp, "missing")))
        finally:
            shutil.rmtree(tmp, ignore_errors=True)


class SavedRunUnitsTest(unittest.TestCase):
    def setUp(self):
        os.makedirs(SCRATCH, exist_ok=True)
        self.tmp = tempfile.mkdtemp(prefix="det_units-", dir=SCRATCH)
        self.real = (coverage.det_run_file, coverage.det_units_file)
        coverage.det_run_file = lambda: os.path.join(self.tmp, "run.json")
        coverage.det_units_file = lambda: os.path.join(self.tmp, "units.json.gz")
        self.addCleanup(self._restore)

    def _restore(self):
        coverage.det_run_file, coverage.det_units_file = self.real
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_the_units_of_a_saved_run_come_back_with_it_only_for_the_same_code(self):
        results = [{"file": "t", "name": "n", "ok": True, "messages": [], "time": 0.1}]
        stats = {"line_overall": 50.0, "line_files": {"scripts/a.gd": 50.0}}
        units = {"hits_00.json": {"a:1": 2}}
        coverage.save_clean_run("fp-1", 0, results, stats, {"a:1": 2}, units)
        self.assertEqual(coverage.load_saved_run("fp-1")["units"], units)
        self.assertIsNone(coverage.load_saved_run("fp-2"))

    def test_an_older_saved_run_without_units_loads_with_units_none(self):
        results = [{"file": "t", "name": "n", "ok": True, "messages": [], "time": 0.1}]
        stats = {"line_overall": 50.0, "line_files": {}}
        coverage.save_clean_run("fp-1", 0, results, stats, {"a:1": 2})
        self.assertIsNone(coverage.load_saved_run("fp-1")["units"])

    def test_the_describe_helper_lists_files_and_the_worst_lines(self):
        diffs = coverage.diff_hit_counts({"a.gd:1": 10, "b.gd:2": 5, "b.gd:3": 7}, {"a.gd:1": 11, "b.gd:2": 50, "b.gd:3": 7})
        self.assertEqual([d[0] for d in diffs], ["a.gd:1", "b.gd:2"])
        text = "\n".join(coverage.describe_count_diffs(diffs))
        self.assertIn("b.gd 1", text)
        self.assertIn("b.gd:2: 5 vs 50", text)


if __name__ == "__main__":
    unittest.main()
