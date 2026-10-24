#!/usr/bin/env python3
"""Runs the PositiveFPS gdUnit4 test suite headless.

Usage:
    python tools/run_tests.py                 # test the repo itself, suites in parallel Godot processes
    python tools/run_tests.py --project DIR   # test another copy of the project
    python tools/run_tests.py --workers 1     # one Godot process runs everything (the old, serial behaviour)
    python tools/run_tests.py --update-weights  # after a run, record each test's duration in tools/test_weights.json

The Godot console executable comes from the GODOT environment variable, or the known install path below.
Reports are written to <project>/reports/<timestamp>/ (HTML and JUnit XML). The exit code is 0 when all
tests pass, 1 when any test fails, and 2 if Godot could not run.

Parallelism: the suites are independent (each builds its own scene), so they are split into units and run in
several Godot processes at once (`--workers`, default WORKERS_DEFAULT). A unit is a whole suite, or, for suites
with slow tests listed in tools/test_weights.json, a single slow test, so one slow suite cannot set the run time.
Every process uses the same fixed 1/60 s step and seed, so results do not depend on the split or the order.

Only the Python standard library is used. This module's functions are also used by tools/coverage.py.
"""
import argparse
import concurrent.futures
import datetime
import json
import os
import re
import subprocess
import sys
import threading
import xml.etree.ElementTree as ET


def _use_utf8_console():
    """Prints UTF-8 whatever the console code page is (Windows cp1252 cannot print the em dashes in Godot's output).

    Characters the console still cannot show are replaced, not raised, so a test name can never stop a run.
    """
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


_use_utf8_console()

DEFAULT_GODOT = (
    r"C:\Users\amw1\AppData\Local\Microsoft\WinGet\Packages"
    r"\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\Godot_v4.7.2-stable_win64_console.exe"
)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Frames per second forced for test runs (Godot --fixed-fps). Matches the physics tick rate in project.godot.
TEST_FIXED_FPS = 60
WORKERS_DEFAULT = max(1, min(8, (os.cpu_count() or 2) // 2))
WEIGHTS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_weights.json")
UNKNOWN_TEST_SECONDS = 0.5  # weight of a test that is not in test_weights.json yet
OWN_UNIT_SECONDS = 3.0  # a test at least this slow gets a Godot process of its own
_print_lock = threading.Lock()


def godot_path():
    return os.environ.get("GODOT") or DEFAULT_GODOT


def run_godot(args, cwd, env_extra=None, stream=True):
    """Runs Godot with the given arguments, streams its output, and returns (exit code, output text)."""
    env = dict(os.environ)
    env["POSITIVEFPS_TEST"] = "1"
    env.update(env_extra or {})
    cmd = [godot_path(), "--headless", "--path", cwd] + args
    proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    lines = []
    for raw in proc.stdout:
        line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
        lines.append(line)
        if stream:
            print(line, flush=True)
    return proc.wait(), "\n".join(lines)


def import_project(project):
    """Builds Godot's import cache. Needed once per fresh copy of the project."""
    code, _ = run_godot(["--import"], project, stream=False)
    if code != 0:
        raise RuntimeError("Godot --import failed with exit code %d" % code)


def gdunit_args(report_dir, suite=None, skip=None):
    """The Godot arguments for one gdUnit4 CLI run: every test (or one suite), minus the `skip` test names."""
    args = [
        # Fixed timestep: every frame advances exactly 1/60 s of game time and the physics steps match,
        # so frame timing (and the top-down wander and firing timers) cannot vary from run to run.
        "--fixed-fps", str(TEST_FIXED_FPS),
        "-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
        "--ignoreHeadlessMode",
        "-c",  # keep running after a failure
        "-a", "res://tests" + ("/%s.gd" % suite if suite else ""),
        "-rd", report_dir,
    ]
    for name in skip or []:
        args += ["-i", "res://tests/%s.gd:%s" % (suite, name)]
    return args


def discover_tests(project):
    """Returns {suite name: [test function names, in file order]} for tests/*_test.gd."""
    out = {}
    tests_dir = os.path.join(project, "tests")
    for name in sorted(os.listdir(tests_dir)):
        if not name.endswith("_test.gd"):
            continue
        with open(os.path.join(tests_dir, name), encoding="utf-8") as fh:
            found = re.findall(r"^func (test_\w+)\(", fh.read(), re.M)
        if found:
            out[name[:-3]] = found
    return out


def load_weights():
    try:
        with open(WEIGHTS_FILE, encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {}


def plan_units(tests, weights):
    """Splits the suites into units that run in separate Godot processes, heaviest first.

    Returns a list of {"name", "suite", "skip", "weight"}. A unit runs one suite minus the tests in `skip`.
    """
    units = []
    for suite, names in tests.items():
        w = {n: weights.get("%s::%s" % (suite, n), UNKNOWN_TEST_SECONDS) for n in names}
        slow = [n for n in names if w[n] >= OWN_UNIT_SECONDS]
        rest = [n for n in names if n not in slow]
        for n in slow:
            units.append({"name": "%s::%s" % (suite, n), "suite": suite,
                          "skip": [m for m in names if m != n], "weight": w[n]})
        if rest and slow:
            units.append({"name": "%s (rest)" % suite, "suite": suite, "skip": slow,
                          "weight": sum(w[n] for n in rest)})
        elif rest:
            units.append({"name": suite, "suite": suite, "skip": [], "weight": sum(w.values())})
    units.sort(key=lambda u: -u["weight"])
    return units


# Godot output that means a script did not load or crashed: gdUnit then skips the suite but still reports success.
SCRIPT_PROBLEM = re.compile(r"Parse Error|SCRIPT ERROR|Failed to load script|Failed to compile|Compile Error", re.I)


def script_problems(output):
    """Lines of Godot output that show a test or game script failed to parse or load."""
    return [ln.strip() for ln in output.splitlines() if SCRIPT_PROBLEM.search(ln)][:12]


def integrity_problems(project, results, outputs):
    """Checks a finished run for what gdUnit hides. Returns a list of problem strings (empty = fine).

    A parse error in a test file makes gdUnit skip that suite while the summary still says all passed, so:
    (1) any script error in the Godot output is a problem, and (2) every discovered suite must report, with at
    least as many tests as the file declares.
    """
    problems = ["script error in Godot output: " + ln for out in outputs for ln in script_problems(out)]
    ran = {}
    for r in results or []:
        ran[r["file"]] = ran.get(r["file"], 0) + 1
    for suite, names in discover_tests(project).items():
        if suite not in ran:
            problems.append("suite %s did not report any results (skipped?)" % suite)
        elif ran[suite] < len(names):
            problems.append("suite %s ran %d of its %d tests" % (suite, ran[suite], len(names)))
    return problems


def run_parallel(project, report_dir, workers, cov_dir=None):
    """Runs all test units, `workers` Godot processes at a time. Returns (worst exit code, results list, outputs)."""
    units = plan_units(discover_tests(project), load_weights())

    def job(i, unit):
        unit_dir = os.path.join(report_dir, "u%02d" % i)
        os.makedirs(unit_dir, exist_ok=True)
        env = {}
        if cov_dir:
            env["POSITIVEFPS_COV_OUT"] = os.path.join(cov_dir, "hits_%02d.json" % i)
        code, out = run_godot(gdunit_args(unit_dir, unit["suite"], unit["skip"]), project, env, stream=False)
        xml = latest_results_xml(unit_dir)
        parsed = parse_results(xml) if xml else None
        with _print_lock:
            print("unit %-70s exit %d" % (unit["name"], code), flush=True)
            if parsed is None or code not in (0, 100):
                print(out, flush=True)
        return code, parsed, out

    code = 0
    results = []
    outputs = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, workers)) as pool:
        futures = [pool.submit(job, i, u) for i, u in enumerate(units)]
        for f in futures:
            unit_code, parsed, out = f.result()
            outputs.append(out)
            if parsed is None:
                code = max(code, 2)
            else:
                results.extend(parsed)
                code = max(code, 1 if unit_code not in (0, 100) else 0)
    results.sort(key=lambda r: (r["file"], r["name"]))
    return code, results, outputs


def latest_results_xml(report_dir):
    """Finds the JUnit XML that the gdUnit4 CLI wrote below report_dir (the newest one)."""
    best = None
    for dirpath, _dirs, files in os.walk(report_dir):
        if "results.xml" in files:
            path = os.path.join(dirpath, "results.xml")
            if best is None or os.path.getmtime(path) > os.path.getmtime(best):
                best = path
    return best


def parse_results(xml_path):
    """Returns a list of {file, name, ok, messages, time} dicts, one per test case, from a gdUnit4 JUnit XML."""
    tree = ET.parse(xml_path)
    results = []
    for case in tree.iter("testcase"):
        classname = case.get("classname", "")
        file_name = classname.split(".")[0] if classname else ""
        messages = []
        ok = True
        for child in case:
            if child.tag in ("failure", "error"):
                ok = False
                text = (child.get("message") or "") + " " + (child.text or "")
                messages.append(" ".join(text.split()))
        results.append({"file": file_name, "name": case.get("name", ""), "ok": ok, "messages": messages,
                        "time": float(case.get("time", 0) or 0)})
    return results


def run_suite(project, report_root=None, workers=None, cov_dir=None):
    """Runs the whole suite on `project`. Returns (exit code, list of test result dicts or None, report dir).

    workers=1 runs everything in one Godot process; more runs units in parallel (see the module docstring).
    cov_dir: a folder where each process writes its coverage hits (used by tools/coverage.py).
    """
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    report_root = report_root or os.path.join(project, "reports")
    report_dir = os.path.join(report_root, stamp)
    os.makedirs(report_dir, exist_ok=True)
    import_project(project)
    workers = WORKERS_DEFAULT if workers is None else workers
    if workers <= 1:
        env = {"POSITIVEFPS_COV_OUT": os.path.join(cov_dir, "hits_00.json")} if cov_dir else None
        code, out = run_godot(gdunit_args(report_dir), project, env)
        xml = latest_results_xml(report_dir)
        results, outputs = (parse_results(xml) if xml else None), [out]
    else:
        code, results, outputs = run_parallel(project, report_dir, workers, cov_dir)
        results = results or None
    if results is not None:
        problems = integrity_problems(project, results, outputs)
        for p in problems:
            print("ERROR: " + p, flush=True)
        if problems:
            code = max(code, 1)
    return code, results, report_dir


def main():
    parser = argparse.ArgumentParser(description="Run the PositiveFPS gdUnit4 suite headless.")
    parser.add_argument("--project", default=ROOT, help="project folder (default: this repo)")
    parser.add_argument("--workers", type=int, default=None,
                        help="Godot processes to run at once (default %d; 1 = serial)" % WORKERS_DEFAULT)
    parser.add_argument("--update-weights", action="store_true",
                        help="after the run, write each test's duration to tools/test_weights.json")
    args = parser.parse_args()
    project = os.path.abspath(args.project)
    try:
        code, results, report_dir = run_suite(project, workers=args.workers)
    except (RuntimeError, OSError) as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    if results is None:
        print("ERROR: no results.xml written; see the Godot output above.", file=sys.stderr)
        return 2
    failed = [r for r in results if not r["ok"]]
    if args.update_weights:
        weights = {"%s::%s" % (r["file"], r["name"]): round(r["time"], 1) for r in results}
        with open(WEIGHTS_FILE, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(weights, fh, indent=0, sort_keys=True)
            fh.write("\n")
        print("Wrote %s" % WEIGHTS_FILE)
    print("")
    print("Tests: %d passed, %d failed (reports: %s)" % (len(results) - len(failed), len(failed), report_dir))
    for r in failed:
        print("FAIL %s::%s  %s" % (r["file"], r["name"], " | ".join(r["messages"])[:400]))
    return 1 if failed or code != 0 else 0


if __name__ == "__main__":
    sys.exit(main())
