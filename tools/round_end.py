#!/usr/bin/env python3
"""One command for the end of a round: the full gate, the determinism check, then the coverage baseline.

Usage:
    python tools/round_end.py                 # start (or carry on with) the run, then wait up to 500 s for it
    python tools/round_end.py                 # ...run the SAME command again while it prints "still running"
    python tools/round_end.py --status        # show progress and the tail of the current step's log; waits for nothing
    python tools/round_end.py --restart       # forget the saved progress and start from step 1
    python tools/round_end.py --wait-seconds 300

The three steps run one after another, in this order, and the run STOPS at the first one that fails:
    1. python tools/gate.py --full                        (lint, tests with coverage, the ratchet, the timing pass)
    2. python tools/coverage.py --check-determinism       (uses the clean run step 1 saved, so it makes one fresh run)
    3. python tools/coverage.py --update-baseline         (refuses when coverage fell; never given --allow-decrease)

The steps run in a background worker (detached, so it survives the end of the command that started it), because the
whole chain can take longer than a 10-minute command limit. The worker writes everything under .scratch/round_end/:
state.json (progress), run.log (the worker's own lines) and one log per step. The command you run only waits and
reports, so it can be run again and again; each run reports where things stand and exits:
    0    all three steps passed (the baseline is updated: commit coverage_baseline.json with the docs)
    1-3  the exit code of the step that failed; later steps did not run (the log path is printed)
    124  still running when the wait ended; run the same command again
    2    also the tool itself could not run

Resuming: progress belongs to the exact code it ran on (gate.fingerprint(), leaving out coverage_baseline.json, which
step 3 rewrites). If the code is unchanged, a step that passed is not run again, so after fixing nothing but waiting
(or after the worker was lost), the run carries on at the first unfinished step. If any file the gate depends on
changed, the progress is dropped and the run starts again at step 1. A failed step runs again when you run the command
again. The tool never ends a process, and a worker that is still alive is never started twice.
Only the Python standard library is used.
"""
import argparse
import datetime
import json
import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate  # noqa: E402

PYTHON = sys.executable or "python"
STATE_DIR = os.path.join(ROOT, ".scratch", "round_end")
WAIT_SECONDS = 500  # under the 10-minute command limit
POLL_SECONDS = 5
STILL_RUNNING = 124
STARTING_GRACE = 120  # seconds a just-launched worker may take to write its first state before it counts as lost
# Never add --allow-decrease here. A coverage drop is fixed with tests, not by lowering the baseline.
STEPS = [
    {"name": "gate", "cmd": [PYTHON, os.path.join("tools", "gate.py"), "--full"]},
    {"name": "determinism", "cmd": [PYTHON, os.path.join("tools", "coverage.py"), "--check-determinism"]},
    {"name": "baseline", "cmd": [PYTHON, os.path.join("tools", "coverage.py"), "--update-baseline"]},
]
SKIP_IN_FINGERPRINT = ("coverage_baseline.json",)
for _stream in (sys.stdout, sys.stderr):
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")


def now_text():
    return datetime.datetime.now().isoformat(timespec="seconds")


def paths(state_dir):
    return {"state": os.path.join(state_dir, "state.json"), "run": os.path.join(state_dir, "run.log")}


def tree_fingerprint():
    return gate.fingerprint(skip=SKIP_IN_FINGERPRINT)


def load_state(state_dir):
    try:
        with open(paths(state_dir)["state"], encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) and "steps" in data else None
    except (OSError, ValueError):
        return None


def save_state(state_dir, state):
    os.makedirs(state_dir, exist_ok=True)
    target = paths(state_dir)["state"]
    temp = target + ".tmp"
    with open(temp, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(state, fh, indent=2)
    os.replace(temp, target)  # a reader never sees half a file


def pid_alive(pid):
    """True when a process with this id exists. Only looks; never signals or ends anything."""
    if not pid:
        return False
    if os.name == "nt":
        try:
            done = subprocess.run(["tasklist", "/FI", "PID eq %d" % pid, "/FO", "CSV", "/NH"], capture_output=True,
                                  text=True, errors="replace", timeout=60)
        except (OSError, subprocess.SubprocessError):
            return True  # could not look: assume it is alive rather than start a second worker
        if done.returncode != 0:
            return True
        return ('"%d"' % pid) in done.stdout
    try:
        os.kill(pid, 0)  # signal 0 checks existence only
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def new_state(steps, fingerprint):
    return {"fingerprint": fingerprint, "started": now_text(), "state": "pending", "worker_pid": None,
            "steps": [{"name": s["name"], "cmd": s["cmd"], "status": "pending", "exit": None, "seconds": None,
                       "log": None} for s in steps]}


def plan_state(saved, steps, fingerprint, restart):
    """The state to carry on from: the saved one when it is for the same code and steps, else a fresh one.
    A step that failed (or was cut off while running) goes back to pending; a passed step stays passed."""
    same = (saved is not None and not restart and saved.get("fingerprint") == fingerprint
            and [s["name"] for s in saved["steps"]] == [s["name"] for s in steps]
            and [s["cmd"] for s in saved["steps"]] == [s["cmd"] for s in steps])
    if not same:
        return new_state(steps, fingerprint)
    for step in saved["steps"]:
        if step["status"] != "passed":
            step.update({"status": "pending", "exit": None, "seconds": None})
    saved["state"] = "pending"
    return saved


def summary_exit(state):
    """The exit code the waiting command reports for a state: 0 passed, the failed step's code, 124 not finished."""
    if state["state"] == "passed":
        return 0
    if state["state"] == "failed":
        failed = next((s for s in state["steps"] if s["status"] == "failed"), None)
        code = failed["exit"] if failed and failed["exit"] else 1
        return code if code in (1, 2, 3) else 2
    return STILL_RUNNING


def progress_lines(state, tail=0):
    out = []
    for i, step in enumerate(state["steps"], 1):
        took = "" if step["seconds"] is None else " (%.0f s)" % step["seconds"]
        code = "" if step["exit"] in (None, 0) else ", exit %s" % step["exit"]
        out.append("  %d. %-12s %s%s%s" % (i, step["name"], step["status"], code, took))
    if tail:
        running = next((s for s in state["steps"] if s["status"] == "running"), None)
        if running and running.get("log") and os.path.exists(running["log"]):
            with open(running["log"], encoding="utf-8", errors="replace") as fh:
                lines = fh.read().splitlines()[-tail:]
            out.append("  tail of %s:" % running["log"])
            out.extend("    " + ln[:200] for ln in lines)
    return out


# ---- the worker ------------------------------------------------------------------------------------------------------

def worker(state_dir, steps, fingerprint, restart):
    """Runs the steps in order, saving progress after each. Returns the exit code of the first failing step, or 0."""
    os.makedirs(state_dir, exist_ok=True)
    state = plan_state(load_state(state_dir), steps, fingerprint, restart)
    state["worker_pid"] = os.getpid()
    state["state"] = "running"
    save_state(state_dir, state)
    run_log = open(paths(state_dir)["run"], "a", encoding="utf-8", buffering=1)

    def say(text):
        run_log.write("%s %s\n" % (now_text(), text))

    say("worker started (pid %d), %d steps" % (os.getpid(), len(steps)))
    for index, step in enumerate(state["steps"]):
        if step["status"] == "passed":
            say("step %d %s already passed for this code, skipped" % (index + 1, step["name"]))
            continue
        log = os.path.join(state_dir, "%d-%s.log" % (index + 1, step["name"]))
        step.update({"status": "running", "exit": None, "seconds": None, "log": log})
        save_state(state_dir, state)
        say("step %d %s: %s" % (index + 1, step["name"], " ".join(step["cmd"])))
        started = time.time()
        try:
            with open(log, "w", encoding="utf-8", errors="replace") as out:
                code = subprocess.run(step["cmd"], cwd=ROOT, stdout=out, stderr=subprocess.STDOUT).returncode
        except OSError as err:
            code = 2
            with open(log, "a", encoding="utf-8") as out:
                out.write("could not start the step: %s\n" % err)
        step.update({"status": "passed" if code == 0 else "failed", "exit": code, "seconds": time.time() - started})
        say("step %d %s %s (exit %d, %.0f s)" % (index + 1, step["name"], step["status"], code, step["seconds"]))
        if code != 0:
            state["state"] = "failed"
            state["worker_pid"] = None
            save_state(state_dir, state)
            say("stopped: later steps did not run")
            return code
        save_state(state_dir, state)
    state["state"] = "passed"
    state["worker_pid"] = None
    save_state(state_dir, state)
    say("all steps passed")
    return 0


def start_worker(state_dir, steps_json, restart):
    """Starts the worker detached from this command (it keeps running after this command ends)."""
    cmd = [PYTHON, os.path.abspath(__file__), "--worker", "--state-dir", state_dir]
    if steps_json:
        cmd += ["--steps-json", steps_json]
    if restart:
        cmd.append("--restart")
    os.makedirs(state_dir, exist_ok=True)
    flags = 0
    if os.name == "nt":
        # CREATE_NO_WINDOW | CREATE_NEW_PROCESS_GROUP: a hidden console the worker's children inherit. (DETACHED_PROCESS
        # left the worker with no console at all, so Windows opened a new window for every python, godot and git child.)
        flags = 0x08000000 | 0x00000200
    out = open(os.path.join(state_dir, "worker-stdout.log"), "a")
    subprocess.Popen(cmd, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=out, stderr=subprocess.STDOUT,
                     creationflags=flags, close_fds=True, start_new_session=(os.name != "nt"))


# ---- the command you run --------------------------------------------------------------------------------------------

def finish_report(state):
    code = summary_exit(state)
    print("")
    print("\n".join(progress_lines(state)))
    if code == 0:
        print("\nRound end OK: gate, determinism and baseline all passed. coverage_baseline.json is updated: commit it "
              "with the docs (explicit paths).")
    else:
        failed = next(s for s in state["steps"] if s["status"] == "failed")
        print("\nSTOPPED at step '%s' (exit %s). Later steps did not run. Log: %s" % (failed["name"], failed["exit"],
                                                                                      failed["log"]))
        print("Fix the cause (tests, not the baseline), then run this command again: passed steps are not repeated "
              "unless the code changed.")
    return code


def command(args, steps):
    state_dir = os.path.abspath(args.state_dir)
    try:
        fingerprint = tree_fingerprint()
    except (OSError, subprocess.CalledProcessError) as err:
        print("ERROR: could not fingerprint the working tree (%s)." % err, file=sys.stderr)
        return 2
    saved = load_state(state_dir)
    current = saved is not None and not args.restart and saved.get("fingerprint") == fingerprint
    if args.status:
        if saved is None:
            print("No round end run saved in %s." % state_dir)
            return 0
        note = "" if current else " (for OLDER code: the files changed since; the next run starts again at step 1)"
        print("Round end run started %s, state: %s%s" % (saved["started"], saved["state"], note))
        print("\n".join(progress_lines(saved, tail=5)))
        return 0 if saved["state"] in ("passed", "pending") else summary_exit(saved)

    starting = (saved is not None and saved["state"] == "starting"
                and time.time() - saved.get("starting_at", 0) < STARTING_GRACE)  # a worker was just launched
    live = starting or (saved is not None and saved["state"] == "running" and pid_alive(saved.get("worker_pid")))
    if live and not current:
        print("ERROR: a worker (pid %s) is still running a round end for other code or was told to restart. "
              "Let it finish (it is never ended by this tool), then run this again." % saved["worker_pid"],
              file=sys.stderr)
        return 2
    if current and saved["state"] in ("passed", "failed") and not live:
        if saved["state"] == "passed":
            print("Already done for this exact code (%s)." % saved["started"])
            return finish_report(saved)
        print("The saved run FAILED earlier; running the failed step again.")
    if live:
        print("A run is in progress (worker %s). Waiting." % saved["worker_pid"])
    else:
        if current and saved["state"] == "running":
            print("The worker of the saved run is gone (it was cut off). Carrying on at the first unfinished step.")
        elif saved is not None and not current and not args.restart:
            print("The code changed since the saved run; starting again at step 1.")
        # Save the new state before the worker starts, so the wait below never reads the old verdict.
        fresh = plan_state(saved, steps, fingerprint, args.restart)
        fresh["state"] = "starting"
        fresh["starting_at"] = time.time()
        fresh["worker_pid"] = None
        save_state(state_dir, fresh)
        start_worker(state_dir, args.steps_json, args.restart)

    deadline = time.time() + args.wait_seconds
    seen = {}
    while True:
        time.sleep(POLL_SECONDS if args.wait_seconds > POLL_SECONDS else 0.2)
        state = load_state(state_dir)
        if state is not None and state.get("fingerprint") == fingerprint:
            for step in state["steps"]:
                if seen.get(step["name"]) != step["status"]:
                    seen[step["name"]] = step["status"]
                    print("[%s] %s: %s" % (now_text(), step["name"], step["status"]), flush=True)
            if state["state"] in ("passed", "failed"):
                return finish_report(state)
            if state["state"] == "running" and not pid_alive(state.get("worker_pid")) and (
                    time.sleep(1.0) or load_state(state_dir)["state"] == "running"
                    and not pid_alive(state.get("worker_pid"))):
                print("The worker ended without finishing. Run the command again to carry on.")
                print("\n".join(progress_lines(state)))
                return 2
        if time.time() >= deadline:
            print("\nStill running after %d s. Run the same command again to keep waiting "
                  "(the worker is not affected by this command ending)." % args.wait_seconds)
            if state is not None:
                print("\n".join(progress_lines(state, tail=3)))
            return STILL_RUNNING


def main(argv=None):
    parser = argparse.ArgumentParser(description="Round end: gate --full, determinism, baseline; stops at the first "
                                                 "failure; waits in slices under the command limit.")
    parser.add_argument("--status", action="store_true", help="show progress and exit")
    parser.add_argument("--restart", action="store_true", help="drop saved progress and start at step 1")
    parser.add_argument("--wait-seconds", type=float, default=WAIT_SECONDS,
                        help="how long this command waits for the run (default %(default)s, under the 10 min limit)")
    parser.add_argument("--state-dir", default=STATE_DIR, help="where progress and logs go (default .scratch/round_end)")
    parser.add_argument("--worker", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--steps-json", default=None, help=argparse.SUPPRESS)  # tests: a JSON list of {name, cmd}
    args = parser.parse_args(argv)
    steps = json.loads(args.steps_json) if args.steps_json else STEPS
    if args.worker:
        return worker(os.path.abspath(args.state_dir), steps, tree_fingerprint(), args.restart)
    return command(args, steps)


if __name__ == "__main__":
    sys.exit(main())
