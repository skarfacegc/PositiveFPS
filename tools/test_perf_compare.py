#!/usr/bin/env python3
"""Self-check of tools/perf_compare.py with fake runs (no Godot needed). Run:
    python tools/test_perf_compare.py
"""
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import perf_compare as pc  # noqa: E402
import run_tests  # noqa: E402

# Lines as run_tests.py --perf-only prints them (the real format of world_scale_test.gd and minimap_clouds_test.gd).
OUTPUT = "\n".join([
    "serial timing unit world_scale_test                                     exit 0",
    "  WORLD_SCALE sim update with 60 people, full border: 2.912 ms per frame",
    "serial timing unit minimap_clouds_test                                  exit 0",
    "  MINIMAP clouds recount with 60 people in 20 cells: 0.045 ms",
    "serial timing unit recorder_test                                        exit 1",
    "  something else: 9.0 ms",
])


class FakeResult:
    def __init__(self, code=0, timed_out=False):
        self.exit_code, self.timed_out, self.seconds, self.log_path = code, timed_out, 1.0, "fake.log"


class PerfCompareTest(unittest.TestCase):
    def test_readings_and_units_are_parsed(self):
        readings, units = pc.parse_output(OUTPUT)
        self.assertEqual(readings, {"WORLD_SCALE sim update with 60 people, full border": 2.912,
                                    "MINIMAP clouds recount with 60 people in 20 cells": 0.045})
        self.assertEqual(units["recorder_test"], 1)
        self.assertEqual(len(units), 3)

    def test_run_tests_echoes_the_prefixes_the_parser_reads(self):
        for line in OUTPUT.splitlines():
            if pc.READING.match(line.strip()):
                self.assertTrue(line.strip().startswith(run_tests.PERF_READING_PREFIXES), line)

    def test_report_has_each_reading_mean_spread_and_difference(self):
        a = [({"T": 2.0}, {"s": 0}), ({"T": 4.0}, {"s": 0})]
        b = [({"T": 3.0}, {"s": 0}), ({"T": 3.0}, {"s": 1})]
        text = pc.build_report(["A", "B"], {"A": a, "B": b})
        self.assertIn("readings 2.000, 4.000 ms", text)
        self.assertIn("mean 3.000  min 2.000  max 4.000  spread 2.000", text)
        self.assertIn("difference (B - A): +0.000 ms", text)
        self.assertIn("FAILED a run", text)

    def test_no_readings_is_a_warning(self):
        self.assertIn("no timing readings", pc.build_report(["A", "B"], {"A": [({}, {})], "B": [({}, {})]}))

    def test_environment_warnings(self):
        self.assertEqual(pc.environment_warnings([], 5.0), [])
        w = pc.environment_warnings(["Godot.exe (pid 1)"], 80.0)
        self.assertEqual(len(w), 2)
        self.assertIn("pid 1", w[0])
        self.assertIn("80 %", w[1])

    def test_alternation_order_with_folders(self):
        with tempfile.TemporaryDirectory() as ta, tempfile.TemporaryDirectory() as tb:
            order = []
            values = {ta: [1.0, 3.0], tb: [2.0, 2.0]}

            def runner(project, _log, _timeout):
                order.append(project)
                v = values[project].pop(0)
                return {"PERF x": v}, {"suite": 0}, FakeResult()

            text, failures = pc.compare(ta, tb, 2, 10, runner=runner, say=lambda _m: None,
                                        probe=lambda: (["Godot.exe (pid 9)"], 10.0))
            self.assertEqual(order, [os.path.abspath(ta), os.path.abspath(tb)] * 2)
            self.assertEqual(failures, 0)
            self.assertIn("WARNINGS during the comparison", text)
            self.assertIn("mean 2.000", text)

    def test_a_timed_out_run_counts_as_a_failure(self):
        with tempfile.TemporaryDirectory() as ta, tempfile.TemporaryDirectory() as tb:
            def runner(_project, _log, _timeout):
                return {}, {}, FakeResult(124, True)

            _text, failures = pc.compare(ta, tb, 1, 10, runner=runner, say=lambda _m: None, probe=lambda: ([], 0.0))
            self.assertEqual(failures, 2)

    def test_unknown_revision_is_rejected(self):
        with self.assertRaises(ValueError):
            pc.make_side("no-such-revision-xyz")


if __name__ == "__main__":
    unittest.main()
