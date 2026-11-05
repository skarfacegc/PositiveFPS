#!/usr/bin/env python3
"""Self-check of tools/source_map.py on a throwaway tree under .scratch/. Run:
    python tools/test_source_map.py
"""
import os
import sys
import tempfile
import unittest
import shutil

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import source_map as sm  # noqa: E402

SCRATCH = os.path.join(os.path.dirname(HERE), ".scratch")

SAMPLE = """class_name Sample
extends Node

# gdlint: ignore=max-public-methods
# Does the sample things.
# More words.

signal done(x: int)
signal quiet

const A := 1
const B: float = 2.0
var not_a_const := 3


# Starts it.
# Second line.
static func start(a: int,
		b: float) -> bool:
	return true


func _private() -> void:
	pass


func plain() -> void:
	const INNER := 1
	pass

class Inner:
	func hidden() -> void:
		pass
"""

TEST_SAMPLE = """extends GdUnitTestSuite


func test_one() -> void:
	pass


func test_two() -> void:
	pass


func helper() -> void:
	pass
"""


class SourceMapTest(unittest.TestCase):
    def setUp(self):
        os.makedirs(SCRATCH, exist_ok=True)
        self.root = tempfile.mkdtemp(prefix="srcmap-", dir=SCRATCH)
        self.addCleanup(lambda: shutil.rmtree(self.root, ignore_errors=True))
        os.makedirs(os.path.join(self.root, "scripts", "looks"))
        os.makedirs(os.path.join(self.root, "tests"))
        self.write("scripts/sample.gd", SAMPLE)
        self.write("scripts/looks/other.gd", "extends RefCounted\n\nfunc go() -> void:\n\tpass\n")
        self.write("tests/sample_test.gd", TEST_SAMPLE)
        self.write("tests/topdown_test_util.gd", "extends RefCounted\n")

    def write(self, rel, text):
        with open(os.path.join(self.root, rel), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)

    def test_script_header_signals_and_constants(self):
        text = sm.build(self.root)
        self.assertIn("### scripts/sample.gd (Sample)", text)
        self.assertIn("extends Node | 2 const | Does the sample things.", text)
        self.assertIn("signals: done(x: int), quiet", text)

    def test_public_functions_only_with_line_and_comment(self):
        text = sm.build(self.root)
        self.assertIn("- L18 `static start(a: int, b: float) -> bool` - Starts it.", text)
        self.assertIn("- L27 `plain() -> void`", text)
        self.assertNotIn("_private", text)
        self.assertNotIn("hidden", text)

    def test_tests_section_counts_suites_only(self):
        text = sm.build(self.root)
        self.assertIn("- sample_test (tests/sample_test.gd): 2 tests", text)
        self.assertNotIn("topdown_test_util", text)

    def test_files_are_sorted_and_output_is_deterministic(self):
        text = sm.build(self.root)
        self.assertLess(text.index("scripts/looks/other.gd"), text.index("scripts/sample.gd"))
        self.assertEqual(text, sm.build(self.root))

    def test_check_detects_a_stale_file(self):
        target = os.path.join(self.root, sm.OUTPUT)
        self.assertEqual(self.check(target, None), 1)
        self.assertEqual(self.check(target, sm.build(self.root)), 0)
        self.assertEqual(self.check(target, sm.build(self.root) + "x"), 1)
        self.assertEqual(self.check(target, sm.build(self.root).replace("\n", "\r\n")), 0)

    def check(self, target, content):
        """Runs main(--check) against self.root with SOURCE_MAP.md set to `content` (None: missing)."""
        if os.path.exists(target):
            os.remove(target)
        if content is not None:
            with open(target, "w", encoding="utf-8", newline="") as fh:
                fh.write(content)
        saved = sm.ROOT
        sm.ROOT = self.root
        try:
            return sm.main(["--check"])
        finally:
            sm.ROOT = saved

    def test_the_real_tree_map_builds(self):
        text = sm.build(sm.ROOT)
        self.assertIn("### scripts/topdown_main.gd (TopDownMain)", text)
        self.assertIn("## tests/", text)


if __name__ == "__main__":
    unittest.main()
