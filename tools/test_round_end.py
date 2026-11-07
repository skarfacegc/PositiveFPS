#!/usr/bin/env python3
"""Self-check of tools/round_end.py with tiny fake steps (no Godot). Run:
    python tools/test_round_end.py
The worker is really started detached, as in use; the steps are `python -c` one-liners that leave marker files.
"""
import contextlib
import io
import json
import os
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import round_end as ro  # noqa: E402

SCRATCH = os.path.join(os.path.dirname(HERE), ".scratch")
ro.POLL_SECONDS = 0.2


def step(name, code, marker, flag=None, sleep=0.0):
    """A fake step: appends a line to `marker`, sleeps, then exits `code` (or 0 once `flag` exists, if given)."""
    py = ("import os,sys,time; open(%r,'a').write('x\\n'); time.sleep(%s); " % (marker, sleep))
    py += "sys.exit(0 if os.path.exists(%r) else %d)" % (flag, code) if flag else "sys.exit(%d)" % code
    return {"name": name, "cmd": [sys.executable, "-c", py]}


def runs(marker):
    return open(marker).read().count("x") if os.path.exists(marker) else 0


class RoundEndTest(unittest.TestCase):
    def setUp(self):
        os.makedirs(SCRATCH, exist_ok=True)
        self.tmp = tempfile.mkdtemp(prefix="round_end-", dir=SCRATCH)
        self.state_dir = os.path.join(self.tmp, "state")
        self.addCleanup(self._cleanup)

    def _cleanup(self):
        import time
        for _ in range(20):  # the detached worker may still hold a log for a moment
            try:
                import shutil
                shutil.rmtree(self.tmp)
                return
            except OSError:
                time.sleep(0.25)

    def marker(self, name):
        return os.path.join(self.tmp, name + ".mark")

    def go(self, steps, *extra, wait="240"):
        argv = ["--state-dir", self.state_dir, "--wait-seconds", wait, "--steps-json", json.dumps(steps)] + list(extra)
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = ro.main(argv)
        return code, out.getvalue()

    def state(self):
        return ro.load_state(self.state_dir)

    def test_all_steps_pass_in_order(self):
        steps = [step("one", 0, self.marker("a")), step("two", 0, self.marker("b")), step("three", 0, self.marker("c"))]
        code, text = self.go(steps)
        self.assertEqual(code, 0, text)
        self.assertEqual([runs(self.marker(n)) for n in "abc"], [1, 1, 1])
        self.assertEqual(self.state()["state"], "passed")
        self.assertIn("Round end OK", text)
        for i, name in enumerate(("one", "two", "three"), 1):
            self.assertTrue(os.path.exists(os.path.join(self.state_dir, "%d-%s.log" % (i, name))))

    def test_stops_at_the_first_failure_and_reports_its_exit_code(self):
        steps = [step("one", 0, self.marker("a")), step("two", 3, self.marker("b")), step("three", 0, self.marker("c"))]
        code, text = self.go(steps)
        self.assertEqual(code, 3, text)
        self.assertEqual(runs(self.marker("c")), 0)
        self.assertEqual([s["status"] for s in self.state()["steps"]], ["passed", "failed", "pending"])
        self.assertIn("STOPPED at step 'two'", text)

    def test_a_second_run_resumes_at_the_failed_step_and_skips_what_passed(self):
        flag = self.marker("flag")
        steps = [step("one", 0, self.marker("a")), step("two", 1, self.marker("b"), flag=flag),
                 step("three", 0, self.marker("c"))]
        self.assertEqual(self.go(steps)[0], 1)
        open(flag, "w").close()
        code, text = self.go(steps)
        self.assertEqual(code, 0, text)
        self.assertEqual([runs(self.marker(n)) for n in "abc"], [1, 2, 1])  # step one was not run again

    def test_a_finished_run_for_the_same_code_is_not_repeated(self):
        steps = [step("one", 0, self.marker("a"))]
        self.assertEqual(self.go(steps)[0], 0)
        code, text = self.go(steps)
        self.assertEqual(code, 0)
        self.assertIn("Already done", text)
        self.assertEqual(runs(self.marker("a")), 1)

    def test_restart_runs_everything_again(self):
        steps = [step("one", 0, self.marker("a"))]
        self.go(steps)
        self.assertEqual(self.go(steps, "--restart")[0], 0)
        self.assertEqual(runs(self.marker("a")), 2)

    def test_changed_code_drops_the_saved_progress(self):
        steps = [step("one", 0, self.marker("a"))]
        self.go(steps)
        saved = self.state()
        saved["fingerprint"] = "older code"
        ro.save_state(self.state_dir, saved)
        code, text = self.go(steps)
        self.assertEqual(code, 0, text)
        self.assertIn("code changed", text)
        self.assertEqual(runs(self.marker("a")), 2)

    def test_waiting_past_the_limit_returns_124_and_the_next_call_keeps_waiting(self):
        steps = [step("slow", 0, self.marker("a"), sleep=3), step("after", 0, self.marker("b"))]
        code, text = self.go(steps, wait="0.6")
        self.assertEqual(code, ro.STILL_RUNNING, text)
        self.assertIn("Still running", text)
        code, text = self.go(steps, wait="240")
        self.assertEqual(code, 0, text)
        self.assertEqual([runs(self.marker("a")), runs(self.marker("b"))], [1, 1])  # one worker only

    def test_status_shows_progress_without_starting_anything(self):
        steps = [step("one", 0, self.marker("a"))]
        code, text = self.go(steps, "--status")
        self.assertEqual(code, 0)
        self.assertIn("No round end run saved", text)
        self.go(steps)
        code, text = self.go(steps, "--status")
        self.assertEqual(code, 0)
        self.assertIn("state: passed", text)
        self.assertEqual(runs(self.marker("a")), 1)

    def test_a_lost_worker_is_noticed_and_the_run_carries_on(self):
        steps = [step("one", 0, self.marker("a")), step("two", 0, self.marker("b"))]
        self.go(steps)
        saved = self.state()
        saved["state"] = "running"  # as if the worker died while step two ran
        saved["worker_pid"] = 2 ** 22 - 7
        saved["steps"][1].update({"status": "running", "exit": None})
        ro.save_state(self.state_dir, saved)
        code, text = self.go(steps)
        self.assertEqual(code, 0, text)
        self.assertIn("gone", text)
        self.assertEqual([runs(self.marker("a")), runs(self.marker("b"))], [1, 2])


class RealStepsTest(unittest.TestCase):
    def test_the_real_steps_run_in_the_required_order_and_never_allow_a_decrease(self):
        commands = [" ".join(s["cmd"][1:]).replace("\\", "/") for s in ro.STEPS]
        self.assertEqual(commands, ["tools/gate.py --full", "tools/coverage.py --check-determinism",
                                    "tools/coverage.py --update-baseline"])
        self.assertFalse(any("allow-decrease" in part for s in ro.STEPS for part in s["cmd"]))
        with open(os.path.join(HERE, "round_end.py"), encoding="utf-8") as fh:
            code_lines = [ln for ln in fh if not ln.lstrip().startswith("#")]
        self.assertFalse(any("--allow-decrease" in ln and "STEPS" in ln for ln in code_lines))

    def test_skip_determinism_keeps_gate_then_baseline(self):
        self.assertEqual([s["name"] for s in ro.chosen_steps(True)], ["gate", "baseline"])
        self.assertEqual(ro.chosen_steps(False), ro.STEPS)

    def test_the_fingerprint_ignores_the_baseline_file(self):
        import gate
        self.assertEqual(ro.SKIP_IN_FINGERPRINT, ("coverage_baseline.json",))
        self.assertTrue(gate.depends_on("coverage_baseline.json"))


if __name__ == "__main__":
    unittest.main()
