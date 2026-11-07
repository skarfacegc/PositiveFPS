#!/usr/bin/env python3
"""Self-check for tools/fast_tier.py (the pre-commit hook's change-based test selection). Needs no Godot. Run:
    python tools/test_fast_tier.py
"""
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import fast_tier  # noqa: E402

SCRIPT = "\n".join([
    "extends Node",                 # 1
    "",                             # 2
    "var warmth := 0",              # 3
    "",                             # 4
    "func warm(a: int) -> int:",    # 5
    "\tvar b := a + 1",             # 6
    "\treturn b",                   # 7
    "",                             # 8
    "func cool() -> int:",          # 9
    "\tif warmth > 0:",             # 10
    "\t\treturn 1",                 # 11
    "\treturn 0",                   # 12
    "",
])


def edit(text, line, new):
    lines = text.split("\n")
    lines[line - 1] = new
    return "\n".join(lines)


class ImpactTest(unittest.TestCase):
    def test_paths_map_to_their_impact(self):
        want = {
            "scripts/spirit_warmth.gd": "script", "scripts/looks/x.gd": "script", "scripts/spirit_warmth.gd.uid": "none",
            "scripts/config.gd": "all", "scripts/config_base.gd": "all", "tests/x_test.gd": "suite",
            "tests/topdown_test_util.gd": "all", "project.godot": "all", "scenes/a.tscn": "all", "a.tres": "all",
            "addons/gdUnit4/x.gd": "all", "README.md": "none", "design/a.png": "none", "IDEAS.md": "none",
            "tools/run_tests.py": "all", "tools/gate.py": "all", "tools/coverage.py": "all", "tools/godot_run.py": "all",
            "tools/fast_tier.py": "all", "tools/lint.py": "none", "tools/test_gate.py": "none",
            "tools/source_map.py": "none", "tools/test_weights.json": "none", "tools/fixtures/a.gd": "all",
            ".githooks/pre-commit": "none", "coverage_baseline.json": "none", "gdlintrc": "none",
        }
        for path, impact in want.items():
            self.assertEqual(fast_tier.impact(path), impact, path)


class DiffAndSpansTest(unittest.TestCase):
    def test_parse_diff_reads_hunks_and_statuses(self):
        text = "\n".join([
            "diff --git a/scripts/a.gd b/scripts/a.gd", "index 1..2 100644", "--- a/scripts/a.gd", "+++ b/scripts/a.gd",
            "@@ -5,2 +5,3 @@ func x", "@@ -20 +21 @@", "@@ -30,0 +32,2 @@",
            "diff --git a/scripts/n.gd b/scripts/n.gd", "new file mode 100644", "@@ -0,0 +1,3 @@",
            "diff --git a/scripts/d.gd b/scripts/d.gd", "deleted file mode 100644", "@@ -1,3 +0,0 @@",
        ])
        got = fast_tier.parse_diff(text)
        self.assertEqual(got["scripts/a.gd"], {"status": "M", "hunks": [(5, 2), (20, 1), (30, 0)]})
        self.assertEqual(got["scripts/n.gd"]["status"], "A")
        self.assertEqual(got["scripts/d.gd"]["status"], "D")

    def test_function_spans(self):
        spans = fast_tier.func_spans(SCRIPT.split("\n"))
        self.assertEqual(spans, [("warm", 5, 7), ("cool", 9, 12)])

    def test_changed_lines_of_a_pure_insertion_touch_both_neighbours(self):
        self.assertEqual(fast_tier.changed_base_lines([(6, 0)], 12), {6, 7})
        self.assertEqual(fast_tier.changed_base_lines([(6, 2)], 12), {6, 7})
        self.assertEqual(fast_tier.changed_base_lines([(0, 0)], 12), {1})


class RegionsTest(unittest.TestCase):
    def test_a_line_in_a_function_names_that_function(self):
        base = edit(SCRIPT, 6, "\tvar b := a + 2")
        funcs, whole = fast_tier.regions_of_change(SCRIPT, base, [(6, 1)])
        self.assertEqual((funcs, whole), ({"warm": (5, 7)}, False))

    def test_a_line_outside_any_function_means_the_whole_file(self):
        base = edit(SCRIPT, 3, "var warmth := 1")
        _funcs, whole = fast_tier.regions_of_change(SCRIPT, base, [(3, 1)])
        self.assertTrue(whole)

    def test_lines_are_translated_when_the_map_is_older_than_the_base(self):
        # Two lines were added to the top since the map was made; the change is now at base line 8 = map line 6.
        base = "# a\n# b\n" + edit(SCRIPT, 6, "\tvar b := a + 2")
        funcs, whole = fast_tier.regions_of_change(SCRIPT, base, [(8, 1)])
        self.assertEqual((funcs, whole), ({"warm": (5, 7)}, False))

    def test_a_region_that_changed_since_the_map_selects_all_the_map_said_about_it(self):
        base = edit(SCRIPT, 11, "\t\treturn 2")
        funcs, _whole = fast_tier.regions_of_change(SCRIPT, base, [(11, 1)])
        self.assertEqual(list(funcs), ["cool"])


def sample_map():
    return {
        "units": {"hits_00.json": {"scripts/a.gd:6": 3, "scripts/a.gd:7": 3, "scripts/b.gd:2": 1},
                  "hits_01.json": {"scripts/a.gd:10": 1, "scripts/c.gd:4": 1},
                  "hits_02.json": {"scripts/a.gd:3": 1}},
        "plan": {"hits_00.json": {"name": "s1_test::test_slow_warm", "suite": "s1_test", "tests": ["test_slow_warm"]},
                 "hits_01.json": {"name": "s2_test::test_slow_cool", "suite": "s2_test", "tests": ["test_slow_cool"]},
                 "hits_02.json": {"name": "s3_test", "suite": "s3_test", "tests": ["test_slow_decl", "test_quick"]}},
        "scripts": {"scripts/a.gd": SCRIPT},
    }


TESTS = {"s1_test": ["test_slow_warm", "test_quick_1"], "s2_test": ["test_slow_cool", "test_quick_2"],
         "s3_test": ["test_slow_decl", "test_quick"], "s4_test": ["test_slow_new"]}
WEIGHTS = {"s1_test::test_slow_warm": 20.0, "s1_test::test_quick_1": 0.2, "s2_test::test_slow_cool": 30.0,
           "s2_test::test_quick_2": 0.1, "s3_test::test_slow_decl": 9.0, "s3_test::test_quick": 0.1,
           "s4_test::test_slow_new": 7.0}


def run_select(changes, map_data, base_text=SCRIPT):
    return fast_tier.select(TESTS, WEIGHTS, 5.0, changes, map_data, lambda path: base_text)


class SelectTest(unittest.TestCase):
    def selected(self, result):
        return {s: sorted(n) for s, n in result["selected"].items()}

    def test_no_changes_runs_only_the_fast_tests(self):
        result = run_select({}, None)
        self.assertEqual(self.selected(result), {"s1_test": ["test_quick_1"], "s2_test": ["test_quick_2"],
                                                 "s3_test": ["test_quick"]})
        self.assertEqual((result["fast"], result["slow_total"], result["slow_selected"]), (3, 4, 0))

    def test_a_changed_function_adds_the_slow_tests_that_cover_it(self):
        base = edit(SCRIPT, 6, "\tvar b := a + 2")
        result = run_select({"scripts/a.gd": {"status": "M", "hunks": [(6, 1)]}}, sample_map(), base)
        chosen = self.selected(result)
        self.assertIn("test_slow_warm", chosen["s1_test"])
        self.assertNotIn("s2_test", [s for s, n in chosen.items() if "test_slow_cool" in n])
        self.assertIn("test_slow_new", chosen["s4_test"])  # a slow test the map has never seen runs
        self.assertNotIn("test_slow_decl", chosen["s3_test"])
        self.assertIn("scripts/a.gd: warm -> 1 slow test(s)", result["notes"][0])

    def test_a_change_outside_functions_runs_every_test_that_touched_the_file(self):
        base = edit(SCRIPT, 3, "var warmth := 1")
        result = run_select({"scripts/a.gd": {"status": "M", "hunks": [(3, 1)]}}, sample_map(), base)
        chosen = self.selected(result)
        self.assertIn("test_slow_decl", chosen["s3_test"])
        self.assertIn("test_slow_warm", chosen["s1_test"])
        self.assertIn("test_slow_cool", chosen["s2_test"])

    def test_a_changed_test_file_runs_its_whole_suite(self):
        result = run_select({"tests/s2_test.gd": {"status": "M", "hunks": [(3, 1)]}}, None)
        self.assertEqual(self.selected(result)["s2_test"], ["test_quick_2", "test_slow_cool"])
        self.assertNotIn("test_slow_warm", self.selected(result)["s1_test"])

    def test_things_it_cannot_map_run_everything_and_say_why(self):
        for path in ("scripts/config.gd", "tests/topdown_test_util.gd", "project.godot", "scenes/x.tscn",
                     "tools/run_tests.py"):
            result = run_select({path: {"status": "M", "hunks": [(1, 1)]}}, sample_map())
            self.assertIsNone(result["selected"], path)
            self.assertIn(path, result["reason"])

    def test_no_map_or_an_old_map_runs_everything(self):
        change = {"scripts/a.gd": {"status": "M", "hunks": [(6, 1)]}}
        self.assertIn("no coverage map", run_select(change, None)["reason"])
        old = sample_map()
        old["plan"] = None
        self.assertIn("no coverage map", run_select(change, old)["reason"])

    def test_a_deleted_script_runs_everything_and_a_new_one_does_not(self):
        self.assertIn("deleted", run_select({"scripts/a.gd": {"status": "D", "hunks": []}}, sample_map())["reason"])
        result = run_select({"scripts/new.gd": {"status": "A", "hunks": []}}, sample_map())
        self.assertIsNotNone(result["selected"])
        self.assertTrue(any("is new" in n for n in result["notes"]))

    def test_docs_and_other_tools_change_nothing(self):
        result = run_select({"README.md": {"status": "M", "hunks": [(1, 1)]},
                             "tools/lint.py": {"status": "M", "hunks": [(1, 1)]}}, None)
        self.assertEqual(result["slow_selected"], 0)
        self.assertIsNotNone(result["selected"])

    def test_describe_says_what_was_chosen(self):
        result = run_select({}, None)
        text = "\n".join(fast_tier.describe(result, WEIGHTS, 5.0, TESTS))
        self.assertIn("fast tier: 3 of 7 tests", text)
        all_text = fast_tier.describe(run_select({"project.godot": {"status": "M", "hunks": []}}, None), WEIGHTS, 5.0,
                                      TESTS)[0]
        self.assertIn("running ALL 7 tests", all_text)


if __name__ == "__main__":
    unittest.main()
