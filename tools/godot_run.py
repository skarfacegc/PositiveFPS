#!/usr/bin/env python3
"""Runs any command (usually Godot) with a timeout and captured output, and ends only what it started.

Usage:
    python tools/godot_run.py --timeout 120 -- <godot.exe> --headless --path . res://x.tscn
    python tools/godot_run.py --timeout 120 --log .scratch/run.log --gui -- --path . res://tools/x.tscn
    (--gui or --console in front of the arguments means: put the Godot executable first, from tools/godot_path.py)

Every run gets a hard timeout and its output is written to a log file (default .scratch/godot_run/<stamp>.log), so a run
that fails to load cannot hang the caller or lose its output. When the timeout hits, the process this wrapper started and
all of its children are ended (Windows: `taskkill /T /F /PID <that pid>`; elsewhere: the whole process group it started).
It never looks for other Godot processes, so a playtest window or another agent's run is never touched.
Prints one line at the end: `godot_run: exit=<code> time=<seconds> timed_out=<yes|no> log=<path>`.
Exit code: the command's own, 124 on a timeout, 2 when it could not start.

From Python: `from godot_run import run; result = run(cmd, timeout=120)` returns a RunResult with .exit_code, .seconds,
.timed_out, .log_path and .output() (the captured text). Only the Python standard library is used.
"""
import argparse
import os
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_path import godot_console, godot_gui  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIMEOUT_EXIT = 124
START_FAILED_EXIT = 2


class RunResult:
    def __init__(self, exit_code, seconds, timed_out, log_path, pid):
        self.exit_code = exit_code
        self.seconds = seconds
        self.timed_out = timed_out
        self.log_path = log_path
        self.pid = pid

    def output(self):
        try:
            with open(self.log_path, encoding="utf-8", errors="replace") as fh:
                return fh.read()
        except OSError:
            return ""

    def summary(self):
        return "godot_run: exit=%s time=%.1fs timed_out=%s log=%s" % (
            self.exit_code, self.seconds, "yes" if self.timed_out else "no", self.log_path)


def default_log_path():
    folder = os.path.join(ROOT, ".scratch", "godot_run")
    os.makedirs(folder, exist_ok=True)
    return os.path.join(folder, "%s-%d.log" % (time.strftime("%Y%m%d-%H%M%S"), os.getpid()))


def end_tree(proc):
    """Ends the process we started and its children. Never looks at any other process."""
    if proc.poll() is not None:
        return
    if os.name == "nt":
        subprocess.run(["taskkill", "/T", "/F", "/PID", str(proc.pid)], capture_output=True, check=False)
    else:
        import signal
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            proc.kill()
    try:
        proc.wait(timeout=15)
    except subprocess.TimeoutExpired:
        proc.kill()


def run(cmd, timeout, log_path=None, env=None, cwd=None):
    """Runs cmd (a list) with a timeout; stdout and stderr go to a log file. Returns a RunResult."""
    log_path = os.path.abspath(log_path) if log_path else default_log_path()
    os.makedirs(os.path.dirname(log_path), exist_ok=True)
    kwargs = {}
    if os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["start_new_session"] = True
    start = time.monotonic()
    with open(log_path, "wb") as log:
        try:
            proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdin=subprocess.DEVNULL, stdout=log,
                                    stderr=subprocess.STDOUT, **kwargs)
        except OSError as err:
            log.write(("could not start %r: %s\n" % (cmd[0], err)).encode("utf-8"))
            return RunResult(START_FAILED_EXIT, 0.0, False, log_path, None)
        timed_out = False
        try:
            code = proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            end_tree(proc)
            code = TIMEOUT_EXIT
    return RunResult(code, time.monotonic() - start, timed_out, log_path, proc.pid)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run a command with a timeout and a log; end only what it started.")
    parser.add_argument("--timeout", type=float, required=True, help="seconds before the run is ended")
    parser.add_argument("--log", default=None, help="log file (default .scratch/godot_run/<stamp>.log)")
    parser.add_argument("--gui", action="store_true", help="prepend the windowed Godot executable")
    parser.add_argument("--console", action="store_true", help="prepend the console Godot executable")
    parser.add_argument("cmd", nargs=argparse.REMAINDER, help="-- then the command and its arguments")
    args = parser.parse_args(argv)
    cmd = args.cmd[1:] if args.cmd and args.cmd[0] == "--" else args.cmd
    if args.gui or args.console:
        exe = godot_gui() if args.gui else godot_console()
        if not exe:
            print("ERROR: Godot not found (set GODOT or GODOT_GUI)", file=sys.stderr)
            return 2
        cmd = [exe] + cmd
    if not cmd:
        parser.error("no command given")
    result = run(cmd, args.timeout, args.log)
    print(result.summary())
    return result.exit_code


if __name__ == "__main__":
    sys.exit(main())
