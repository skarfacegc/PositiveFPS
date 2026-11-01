#!/usr/bin/env python3
"""Self-check of tools/godot_run.py with Python child processes (no Godot needed). Run:
    python tools/test_godot_run.py
"""
import os
import subprocess
import sys
import tempfile
import time
import unittest

TOOLS = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, TOOLS)
import godot_run  # noqa: E402


def pid_alive(pid):
    if os.name == "nt":
        out = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/NH"], capture_output=True, text=True).stdout
        return str(pid) in out
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


# A parent that starts a long-sleeping child, writes the child's pid to argv[1], then sleeps itself.
PARENT = ("import subprocess, sys, time\n"
          "c = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(60)'])\n"
          "open(sys.argv[1], 'w').write(str(c.pid))\n"
          "print('parent started', flush=True)\n"
          "time.sleep(60)\n")


class GodotRunTest(unittest.TestCase):
    def test_normal_exit_is_captured(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = godot_run.run([sys.executable, "-c", "import sys; print('hello'); sys.exit(3)"],
                                timeout=30, log_path=os.path.join(tmp, "a.log"))
            self.assertEqual(res.exit_code, 3)
            self.assertFalse(res.timed_out)
            self.assertIn("hello", res.output())
            self.assertIn("exit=3", res.summary())

    def test_timeout_ends_the_whole_tree(self):
        with tempfile.TemporaryDirectory() as tmp:
            pid_file = os.path.join(tmp, "child.pid")
            res = godot_run.run([sys.executable, "-c", PARENT, pid_file], timeout=3,
                                log_path=os.path.join(tmp, "b.log"))
            self.assertTrue(res.timed_out)
            self.assertEqual(res.exit_code, godot_run.TIMEOUT_EXIT)
            self.assertIn("parent started", res.output())
            with open(pid_file, encoding="utf-8") as fh:
                child = int(fh.read())
            time.sleep(0.5)
            self.assertFalse(pid_alive(child), "the child of the timed-out run is still alive")
            self.assertFalse(pid_alive(res.pid))

    def test_missing_executable_is_exit_2(self):
        with tempfile.TemporaryDirectory() as tmp:
            res = godot_run.run(["definitely-not-a-program-xyz"], timeout=5, log_path=os.path.join(tmp, "c.log"))
            self.assertEqual(res.exit_code, 2)
            self.assertIn("could not start", res.output())

    def test_cli_prints_summary_and_returns_exit(self):
        with tempfile.TemporaryDirectory() as tmp:
            log = os.path.join(tmp, "d.log")
            proc = subprocess.run([sys.executable, os.path.join(TOOLS, "godot_run.py"), "--timeout", "20", "--log", log,
                                   "--", sys.executable, "-c", "raise SystemExit(5)"], capture_output=True, text=True)
            self.assertEqual(proc.returncode, 5)
            self.assertIn("godot_run: exit=5", proc.stdout)


if __name__ == "__main__":
    unittest.main()
