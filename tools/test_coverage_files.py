#!/usr/bin/env python3
"""Self-check of the targeted runs (round 23): run_tests --suites and coverage --check-files helpers. No Godot. Run:
    python tools/test_coverage_files.py
"""
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import coverage  # noqa: E402
import run_tests  # noqa: E402


class SuiteFilterTest(unittest.TestCase):
    def test_discover_tests_can_keep_only_named_suites(self):
        everything = run_tests.discover_tests(run_tests.ROOT)
        one = run_tests.discover_tests(run_tests.ROOT, ["menu_test"])
        self.assertEqual(list(one), ["menu_test"])
        self.assertEqual(one["menu_test"], everything["menu_test"])
        self.assertEqual(run_tests.discover_tests(run_tests.ROOT, None), everything)

    def test_an_unknown_suite_is_an_error_before_anything_runs(self):
        with self.assertRaises(RuntimeError) as ctx:
            run_tests.run_suite(run_tests.ROOT, suites=["no_such_test"])
        self.assertIn("no_such_test", str(ctx.exception))

    def test_integrity_check_only_expects_the_chosen_suites(self):
        results = [{"file": "menu_test", "name": n} for n in run_tests.discover_tests(run_tests.ROOT)["menu_test"]]
        self.assertEqual(run_tests.integrity_problems(run_tests.ROOT, results, [], suites=["menu_test"]), [])
        self.assertTrue(run_tests.integrity_problems(run_tests.ROOT, results, []))  # others missing without the filter


class CheckFilesTest(unittest.TestCase):
    known = {"scripts/menu.gd": 1, "scripts/looks/gait.gd": 1}

    def test_script_names_are_normalised_and_unknown_ones_refused(self):
        self.assertEqual(coverage.normalise_scripts(["menu.gd", "scripts\\menu.gd", "./scripts/looks/gait.gd"],
                                                    self.known), ["scripts/menu.gd", "scripts/looks/gait.gd"])
        with self.assertRaises(ValueError):
            coverage.normalise_scripts(["nope.gd"], self.known)

    def test_line_ranges(self):
        self.assertEqual(coverage.line_ranges([88, 41, 42, 43, 140]), "41-43, 88, 140")
        self.assertEqual(coverage.line_ranges([]), "")

    def test_rows_follow_the_ratchet_rules(self):
        files = {"scripts/a.gd": {"exec": [1, 2, 3, 4]}, "scripts/b.gd": {"exec": [1, 2]}, "scripts/c.gd": {"exec": [1]}}
        hits = {"scripts/a.gd:1": 1, "scripts/a.gd:2": 1, "scripts/a.gd:3": 1, "scripts/b.gd:1": 1}
        base = {"line_files": {"scripts/a.gd": 75.0, "scripts/b.gd": 100.0}}
        rows = {r["file"]: r for r in coverage.file_check_rows(["scripts/a.gd", "scripts/b.gd", "scripts/c.gd"], files,
                                                                hits, base)}
        self.assertEqual((rows["scripts/a.gd"]["now"], rows["scripts/a.gd"]["ok"], rows["scripts/a.gd"]["missed"]),
                         (75.0, True, [4]))
        self.assertFalse(rows["scripts/b.gd"]["ok"])  # 50% against a baseline of 100%
        self.assertFalse(rows["scripts/c.gd"]["ok"])  # a new file at 0%
        self.assertTrue(coverage.file_check_rows(["scripts/a.gd"], files, hits, None)[0]["ok"])  # new file at 75%

    def test_suites_are_found_by_class_name_path_or_matching_name(self):
        suites = coverage.suites_for_scripts(["scripts/menu.gd"])
        self.assertIn("menu_test", suites)
        self.assertIn("how_to_play_keys_test", suites)  # names res://scripts/menu.gd
        self.assertEqual(coverage.suites_for_scripts(["scripts/gap_patch.gd"]).count("gap_patch_test"), 1)


INNER_SAMPLE = """class_name Outer
extends RefCounted

var total := 0


class Stop:
\tvar at := 0.0
\tfunc _init(a: float) -> void:
\t\tat = a
\t\tif a > 1.0:
\t\t\tat = 1.0

\tclass Deep:
\t\tfunc go() -> int:
\t\t\treturn 1


func outer_fn() -> int:
\ttotal += 1
\treturn total
"""


class InnerClassTest(unittest.TestCase):
    """An inner class cannot see the outer script's static hit array, so its probes must go through CovProbe."""

    def _instrument(self, text, rel="scripts/outer.gd"):
        lines = text.split("\n")
        result = coverage.analyze_script(rel, lines)
        return lines, result, coverage.instrument_lines(rel, lines, result).split("\n")

    def test_inner_class_lines_use_the_global_registry_and_outer_lines_the_static_array(self):
        lines, result, out = self._instrument(INNER_SAMPLE)
        outer = coverage.cov_name("scripts/outer.gd")
        inner_probe = 'CovProbe.counts("scripts/outer.gd")'
        by_line = {}
        for idx in result["exec"]:
            by_line[idx + 1] = result["exec_map"][idx]["inner"]
        self.assertEqual(by_line, {10: True, 11: True, 12: True, 16: True, 20: False, 21: False})
        # Probes sit directly above their statement, keep its indent and use the right store.
        at = out.index("\t\tat = a")
        self.assertEqual(out[at - 1], "\t\t" + inner_probe + "[10] += 1")
        deep = out.index("\t\t\treturn 1")
        self.assertEqual(out[deep - 1], "\t\t\t" + inner_probe + "[16] += 1")
        total = out.index("\ttotal += 1")
        self.assertEqual(out[total - 1], "\t" + outer + "[20] += 1")
        # No inner-class line mentions the outer static array.
        body = "\n".join(out[: out.index("func outer_fn() -> int:")])
        self.assertNotIn(outer + "[", body)

    def test_inner_class_without_class_name_and_one_line_methods(self):
        text = "extends Node\nclass Box:\n\tfunc get_it() -> int: return 3\nfunc top() -> int: return 4\n"
        lines, result, out = self._instrument(text, "scripts/box.gd")
        self.assertIn('\t\tCovProbe.counts("scripts/box.gd")[3] += 1', out)
        self.assertIn("\t" + coverage.cov_name("scripts/box.gd") + "[4] += 1", out)
        self.assertNotIn("class_name", "\n".join(out))

    def test_code_after_the_inner_class_is_outer_again(self):
        _lines, result, _out = self._instrument(INNER_SAMPLE)
        self.assertFalse(result["exec_map"][19]["inner"])  # outer_fn body, line 20


if __name__ == "__main__":
    unittest.main()
