#!/usr/bin/env python3
"""Runs the PositiveFPS gdUnit4 test suite headless.

Usage:
    python tools/run_tests.py                 # test the repo itself, suites in parallel Godot processes
    python tools/run_tests.py --project DIR   # test another copy of the project
    python tools/run_tests.py --workers 1     # one Godot process runs everything (the old, serial behaviour)
    python tools/run_tests.py --update-weights  # after a run, record each test's duration in tools/test_weights.json
    python tools/run_tests.py --suites gap_patch_test minimap_test   # only these suites (a targeted run for a part agent)
    python tools/run_tests.py --perf-only     # only the timing tests (test_perf_*), serially, budget enforced
    python tools/run_tests.py --tier fast     # every test under FAST_TIER_SECONDS plus the slow ones the change reaches

The Godot console executable is found by tools/godot_path.py (GODOT environment variable, then PATH, then WinGet).
Reports are written to <project>/reports/<timestamp>/ (HTML and JUnit XML); only the newest REPORTS_KEEP runs are kept. The exit code is 0 when all
tests pass, 1 when any test fails, and 2 if Godot could not run.

Parallelism: the suites are independent (each builds its own scene), so they are split into units and run in
several Godot processes at once (`--workers`, default WORKERS_DEFAULT). A unit is a whole suite, or, for suites
with slow tests listed in tools/test_weights.json, a single slow test, so one slow suite cannot set the run time.
Every process uses the same fixed 1/60 s step and seed, so results do not depend on the split or the order.

Timing tests: a test whose name starts with PERF_PREFIX ("test_perf_") asserts a wall-clock budget, which parallel load
would make flaky. In a plain run they are left out of the parallel batch and run afterwards, one at a time, alone on the
machine, with POSITIVEFPS_PERF_ENFORCE=1 (the test only asserts its time when that is set). In an instrumented (coverage)
run they stay in the parallel batch so their lines are counted, with the time assertion off. `--perf-only` runs just
that serial pass (tools/gate.py --full uses it after the coverage run).

Weights: plan_units uses the durations the last full plain run recorded in .git/positivefps-test-times.json, falling back
to the committed tools/test_weights.json (--update-weights rewrites that file). Import: a run skips `godot --import` when
import_is_current() says nothing in the project changed since the last one; instrumented copies always import.

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
import time
import xml.etree.ElementTree as ET
from godot_path import godot_console, require  # noqa: E402  (where Godot lives: GODOT, PATH, then WinGet)


def _use_utf8_console():
    """Prints UTF-8 whatever the console code page is (Windows cp1252 cannot print the em dashes in Godot's output).

    Characters the console still cannot show are replaced, not raised, so a test name can never stop a run.
    """
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")


_use_utf8_console()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Frames per second forced for test runs (Godot --fixed-fps). Matches the physics tick rate in project.godot.
TEST_FIXED_FPS = 60
# Measured on 24 logical CPUs: the full suite took 311 s with 8 workers and 251 s with 16 (the Godot processes are
# independent and mostly single-threaded). So leave four cores free, never fewer than half, and cap at 16 (not measured above).
_CPUS = os.cpu_count() or 2
WORKERS_DEFAULT = max(1, min(16, max(_CPUS // 2, _CPUS - 4)))
WEIGHTS_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test_weights.json")
# Durations recorded by the last full plain run (untracked, in .git next to the gate cache). plan_units prefers them to
# the committed WEIGHTS_FILE, which stays as the fallback, so the weights cannot go stale.
TIMES_FILE_NAME = "positivefps-test-times.json"
FAST_TIER_SECONDS = 5.0  # --tier fast runs every test faster than this, plus the slower ones the change touches
UNIT_PLAN_FILE = "unit_plan.dat"  # written next to the hits files of an instrumented run: which tests each unit ran
IMPORT_STAMP = "positivefps-import-stamp"  # in .godot: touched with the START time of the last successful --import
IMPORT_IGNORED_DIRS = {".git", ".godot", "design", "reports", ".scratch", "coverage", ".coverage_build", "__pycache__",
                       ".claude", "dist-builds", "node_modules"}
IMPORT_IGNORED_SUFFIXES = (".md", ".py", ".pyc", ".sh", ".log", ".gz", ".html", ".txt")
UNKNOWN_TEST_SECONDS = 0.5  # weight of a test that is not in test_weights.json yet
PERF_PREFIX = "test_perf_"  # timing tests: see the module docstring
# Each run writes reports/<timestamp>/ (hundreds of files). Only the newest REPORTS_KEEP runs per report root are kept;
# older ones are removed when a run starts (271 old runs had piled up to 150,000 files).
REPORTS_KEEP = 10
_STAMP_RE = re.compile(r"^\d{8}-\d{6}$")
# Set to 1 by a parallel part agent (see ARCHITECTURE.md): the plain run then skips the serial timing pass, because the
# other agents' load would make the budget flaky. The coordinator's `gate.py --full` after the merge still enforces it.
PARALLEL_PART_ENV = "POSITIVEFPS_PARALLEL_PART"
PARALLEL_PART_NOTICE = ("perf pass skipped (parallel part); enforced by the coordinator's gate --full after merge")
# A timing test prints its reading on a line starting with one of these; the serial pass echoes them (tools/perf_compare.py
# reads them from this output). A new timing test that prints a reading must use one of these prefixes, or add its own.
PERF_READING_PREFIXES = ("WORLD_SCALE", "MINIMAP", "PERF")
OWN_UNIT_SECONDS = 3.0  # a test at least this slow gets a Godot process of its own
_print_lock = threading.Lock()


def godot_path():
    """The Godot console executable. Raises RuntimeError (exit 2 for the callers) when it cannot be found."""
    return require(godot_console, "GODOT")


def run_godot(args, cwd, env_extra=None, stream=True):
    """Runs Godot with the given arguments, streams its output, and returns (exit code, output text)."""
    env = dict(os.environ)
    env["POSITIVEFPS_TEST"] = "1"
    env.update(env_extra or {})
    cmd = [godot_path(), "--headless", "--path", cwd] + args
    # No console window pops up per headless Godot run on Windows.
    flags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    proc = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=flags)
    lines = []
    for raw in proc.stdout:
        line = raw.decode("utf-8", errors="replace").rstrip("\r\n")
        lines.append(line)
        if stream:
            print(line, flush=True)
    return proc.wait(), "\n".join(lines)


def import_project(project):
    """Builds Godot's import cache. Needed once per fresh copy of the project."""
    started = time.time()
    code, _ = run_godot(["--import"], project, stream=False)
    if code != 0:
        raise RuntimeError("Godot --import failed with exit code %d" % code)
    # Remember when this import STARTED: a file saved while it ran is newer than the stamp, so the next run imports again.
    marker = os.path.join(project, ".godot", IMPORT_STAMP)
    try:
        with open(marker, "w", encoding="utf-8") as fh:
            fh.write("imported\n")
        os.utime(marker, (started, started))
    except OSError:
        pass


def import_is_current(project):
    """True when a --import would change nothing, so a run can skip it (it costs about 38 s even when nothing changed).

    Conservative: false unless Godot's class cache exists and nothing in the project is newer than the last successful
    import. "Nothing" means every file and every folder (a folder's time moves when a file is added, removed or renamed)
    outside the ignored folders (IMPORT_IGNORED_DIRS: tool output, scratch and design mock-ups) and outside plain
    documents and tool scripts (IMPORT_IGNORED_SUFFIXES). So scripts, tests, scenes, resources, shaders, addons, imported
    images, fonts and audio, .import and .gdignore files, and project.godot all count. The stamp is the newer of the class
    cache and the marker import_project leaves (the class cache is not rewritten when nothing changed).
    """
    godot = os.path.join(project, ".godot")
    try:
        stamp = os.path.getmtime(os.path.join(godot, "global_script_class_cache.cfg"))
    except OSError:
        return False
    try:
        stamp = max(stamp, os.path.getmtime(os.path.join(godot, IMPORT_STAMP)))
    except OSError:
        pass
    try:
        for dirpath, dirs, files in os.walk(project):
            dirs[:] = [d for d in dirs if d not in IMPORT_IGNORED_DIRS]
            if os.path.getmtime(dirpath) > stamp:
                return False
            for name in files:
                if not name.endswith(IMPORT_IGNORED_SUFFIXES) and os.path.getmtime(os.path.join(dirpath, name)) > stamp:
                    return False
    except OSError:
        return False
    return os.path.isfile(os.path.join(project, "project.godot"))


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


def discover_tests(project, suites=None):
    """Returns {suite name: [test function names, in file order]} for tests/*_test.gd.
    `suites` (a collection of suite names, no .gd) keeps only those suites."""
    out = {}
    tests_dir = os.path.join(project, "tests")
    for name in sorted(os.listdir(tests_dir)):
        if not name.endswith("_test.gd") or (suites and name[:-3] not in suites):
            continue
        with open(os.path.join(tests_dir, name), encoding="utf-8") as fh:
            found = re.findall(r"^func (test_\w+)\(", fh.read(), re.M)
        if found:
            out[name[:-3]] = found
    return out


def times_cache_path():
    """Where the recorded test durations live (.git of this repo), or None when git cannot say."""
    try:
        git_dir = subprocess.run(["git", "-C", ROOT, "rev-parse", "--git-dir"], capture_output=True, text=True,
                                 check=True).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None
    return os.path.join(ROOT, git_dir, TIMES_FILE_NAME) if git_dir else None


def _read_json_dict(path):
    try:
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError, TypeError):
        return {}
    return data if isinstance(data, dict) else {}


def load_recorded_times():
    """{"suite::test": seconds} from the last full plain run on this checkout, or {}."""
    path = times_cache_path()
    return _read_json_dict(path) if path else {}


def load_weights():
    """Test durations: the committed WEIGHTS_FILE overlaid with the durations the last full plain run recorded."""
    weights = _read_json_dict(WEIGHTS_FILE)
    weights.update({k: v for k, v in load_recorded_times().items() if isinstance(v, (int, float))})
    return weights


def record_times(results):
    """Stores the duration of every passing test of a full plain run (replacing the old record, which drops removed tests)."""
    path = times_cache_path()
    if not path:
        return
    times = {"%s::%s" % (r["file"], r["name"]): round(r["time"], 1) for r in results if r["ok"]}
    try:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(times, fh, sort_keys=True)
    except OSError as err:
        print("note: could not record the test durations (%s)" % err, flush=True)


def plan_units(tests, weights, with_perf=True):
    """Splits the suites into units that run in separate Godot processes, heaviest first.

    Returns a list of {"name", "suite", "skip", "weight"}. A unit runs one suite minus the tests in `skip`.
    with_perf=False leaves the timing tests (PERF_PREFIX) out; run_perf_pass runs them.
    """
    units = []
    for suite, all_names in tests.items():
        names = [n for n in all_names if with_perf or not n.startswith(PERF_PREFIX)]
        if not names:
            continue
        skip_always = [n for n in all_names if n not in names]
        w = {n: weights.get("%s::%s" % (suite, n), UNKNOWN_TEST_SECONDS) for n in names}
        slow = [n for n in names if w[n] >= OWN_UNIT_SECONDS]
        rest = [n for n in names if n not in slow]
        for n in slow:
            units.append({"name": "%s::%s" % (suite, n), "suite": suite,
                          "skip": skip_always + [m for m in names if m != n], "weight": w[n]})
        if rest and slow:
            units.append({"name": "%s (rest)" % suite, "suite": suite, "skip": skip_always + slow,
                          "weight": sum(w[n] for n in rest)})
        elif rest:
            units.append({"name": suite, "suite": suite, "skip": skip_always, "weight": sum(w.values())})
    units.sort(key=lambda u: -u["weight"])
    return units


# Godot output that means a script did not load or crashed: gdUnit then skips the suite but still reports success.
SCRIPT_PROBLEM = re.compile(r"Parse Error|SCRIPT ERROR|Failed to load script|Failed to compile|Compile Error", re.I)


ANSI_CODE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
# The line after a SCRIPT ERROR names the script: "at: GDScript::reload (res://tests/x_test.gd:6)" for a parse error.
SCRIPT_AT = re.compile(r"^\s*at: .*?\(res://([^)]+)\)")
FAILED_LOAD = re.compile(r'Failed to load script "res://([^"]+)"')


def script_problems(output):
    """Lines of Godot output that show a test or game script failed to parse or load."""
    return [ln.strip() for ln in output.splitlines() if SCRIPT_PROBLEM.search(ln)][:12]


def broken_scripts(output):
    """{"tests/x_test.gd:6": "Parse Error: ..."} for each script a SCRIPT ERROR or failed load in `output` names."""
    found = {}
    pending = None  # the message of a SCRIPT ERROR whose "at:" line has not come yet
    for raw in output.splitlines():
        ln = ANSI_CODE.sub("", raw).strip()
        at = SCRIPT_AT.match(ln)
        if pending and at:
            found.setdefault(at.group(1), pending)
            pending = None
            continue
        pending = ln[len("SCRIPT ERROR:"):].strip() if ln.startswith("SCRIPT ERROR:") else None
        load = FAILED_LOAD.search(ln)
        if load and not any(key.split(":")[0] == load.group(1) for key in found):
            found[load.group(1)] = "failed to load"
    return found


def output_problems(outputs):
    """One problem string per broken script across all the Godot outputs, file and line first; raw lines otherwise."""
    problems = []
    for out in outputs:
        named = broken_scripts(out)
        lines = ["%s: %s" % kv for kv in named.items()] if named else \
            ["script error in Godot output: " + ln for ln in script_problems(out)]
        problems += [p for p in lines if p not in problems]
    return problems


def integrity_problems(project, results, outputs, skip_perf=False, suites=None, selected=None):
    """Checks a finished run for what gdUnit hides. Returns a list of problem strings (empty = fine).

    A parse error in a test file makes gdUnit skip that suite while the summary still says all passed, so:
    (1) any script error in the Godot output is a problem, and (2) every discovered suite must report, with at
    least as many tests as the file declares (the timing tests are not expected when skip_perf is set).
    `selected` ({suite: [tests]}, from --tier fast) replaces the discovered tests as what is expected to run.
    """
    problems = output_problems(outputs)
    ran = {}
    for r in results or []:
        ran[r["file"]] = ran.get(r["file"], 0) + 1
    for suite, names in (selected if selected is not None else discover_tests(project, suites)).items():
        if skip_perf:
            names = [n for n in names if not n.startswith(PERF_PREFIX)]
        if not names:
            continue
        if suite not in ran:
            problems.append("tests/%s.gd: suite did not report any results (skipped?)" % suite)
        elif ran[suite] < len(names):
            problems.append("tests/%s.gd: suite ran %d of its %d tests" % (suite, ran[suite], len(names)))
    return problems


def write_unit_plan(cov_dir, units, tests):
    """Records which tests each numbered unit ran ({"hits_NN.json": {name, suite, tests}}) next to the hits files, so a
    coverage map stays readable after the recorded weights (and with them the numbering) change."""
    plan = {}
    for i, unit in enumerate(units):
        plan["hits_%02d.json" % i] = {"name": unit["name"], "suite": unit["suite"],
                                      "tests": [n for n in tests[unit["suite"]] if n not in unit["skip"]]}
    try:
        with open(os.path.join(cov_dir, UNIT_PLAN_FILE), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(plan, fh)
    except OSError as err:
        print("note: could not write the unit plan (%s)" % err, flush=True)


def run_parallel(project, report_dir, workers, cov_dir=None, suites=None, selected=None):
    """Runs all test units, `workers` Godot processes at a time. Returns (worst exit code, results list, outputs).

    `selected` ({suite: [tests]}) runs only those tests (--tier fast); None runs everything (or the chosen suites)."""
    tests = selected if selected is not None else discover_tests(project, suites)
    units = plan_units(tests, load_weights(), with_perf=bool(cov_dir))
    if selected is not None:  # the tests of a suite that were not selected must be skipped too
        every = discover_tests(project)
        for unit in units:
            unit["skip"] = unit["skip"] + [n for n in every[unit["suite"]] if n not in selected[unit["suite"]]]
    if cov_dir:
        write_unit_plan(cov_dir, units, tests)

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


def run_perf_pass(project, report_dir, suites=None, selected=None):
    """Runs the timing tests (PERF_PREFIX) one Godot process at a time, with nothing else running, budget enforced.

    Returns (worst exit code, results list, outputs). Plain, not instrumented: probes would inflate the times.
    """
    code = 0
    results = []
    outputs = []
    for suite, names in (selected if selected is not None else discover_tests(project, suites)).items():
        perf = [n for n in names if n.startswith(PERF_PREFIX)]
        if not perf:
            continue
        unit_dir = os.path.join(report_dir, "perf_" + suite)
        os.makedirs(unit_dir, exist_ok=True)
        skip = [n for n in discover_tests(project)[suite] if n not in perf]
        unit_code, out = run_godot(gdunit_args(unit_dir, suite, skip), project,
                                   {"POSITIVEFPS_PERF_ENFORCE": "1"}, stream=False)
        xml = latest_results_xml(unit_dir)
        parsed = parse_results(xml) if xml else None
        print("serial timing unit %-55s exit %d" % (suite, unit_code), flush=True)
        outputs.append(out)
        for ln in out.splitlines():  # a timing test prints its measurement; show it
            if ln.startswith(PERF_READING_PREFIXES):
                print("  " + ln, flush=True)
        if parsed is None or unit_code not in (0, 100):
            print(out, flush=True)
        if parsed is None:
            code = max(code, 2)
        else:
            results.extend(parsed)
            code = max(code, 1 if unit_code not in (0, 100) else 0)
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


def prune_reports(report_root, keep=REPORTS_KEEP):
    """Removes all but the newest `keep` timestamped run folders in report_root. Returns the names removed.

    Only folders named like a run stamp (YYYYMMDD-HHMMSS) are touched; anything else in the folder is left alone. A
    folder that cannot be removed (still open somewhere) is skipped and tried again next time.
    """
    import shutil
    try:
        runs = sorted(n for n in os.listdir(report_root)
                      if _STAMP_RE.match(n) and os.path.isdir(os.path.join(report_root, n)))
    except OSError:
        return []
    old = runs[:-keep] if keep > 0 else runs
    for name in old:
        shutil.rmtree(os.path.join(report_root, name), ignore_errors=True)
    return old


def run_suite(project, report_root=None, workers=None, cov_dir=None, perf_only=False, problems=None, suites=None,
              selected=None):
    """Runs the whole suite on `project`. Returns (exit code, list of test result dicts or None, report dir).

    workers=1 runs everything in one Godot process; more runs units in parallel (see the module docstring).
    cov_dir: a folder where each process writes its coverage hits (used by tools/coverage.py).
    problems: a list that receives the integrity problems (broken scripts, skipped suites), for the caller's summary.
    suites: run only these suites (names without .gd, e.g. ["gap_patch_test"]); an unknown name is an error.
    selected: {suite: [test names]}, run only these tests (--tier fast; see tools/fast_tier.py).
    """
    if suites:
        unknown = sorted(set(suites) - set(discover_tests(project)))
        if unknown:
            raise RuntimeError("unknown test suite(s): %s (suites are the tests/*_test.gd names without .gd)"
                               % ", ".join(unknown))
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    report_root = report_root or os.path.join(project, "reports")
    report_dir = os.path.join(report_root, stamp)
    os.makedirs(report_dir, exist_ok=True)
    prune_reports(report_root)  # the new folder is the newest, so it is always kept
    # An instrumented copy always imports; any other run skips the ~38 s import when nothing changed (import_is_current).
    if cov_dir or not import_is_current(project):
        import_project(project)
    workers = WORKERS_DEFAULT if workers is None else workers
    # A plain run as a parallel part agent: no serial timing pass, and the timing tests are not run at all.
    skip_perf = not cov_dir and os.environ.get(PARALLEL_PART_ENV) == "1"
    if perf_only:
        code, results, outputs = run_perf_pass(project, report_dir, suites, selected)
        return code, results or None, report_dir
    if workers <= 1 and cov_dir and not suites:  # (a plain serial run goes through run_parallel with one worker: it must split off the timing tests)
        env = {"POSITIVEFPS_COV_OUT": os.path.join(cov_dir, "hits_00.json")} if cov_dir else None
        code, out = run_godot(gdunit_args(report_dir), project, env)
        xml = latest_results_xml(report_dir)
        results, outputs = (parse_results(xml) if xml else None), [out]
    else:
        code, results, outputs = run_parallel(project, report_dir, workers, cov_dir, suites, selected)
        if not cov_dir and skip_perf:
            print("WARNING: " + PARALLEL_PART_NOTICE, flush=True)
        elif not cov_dir:  # plain run: the timing tests run now, one at a time, alone
            perf_code, perf_results, perf_outputs = run_perf_pass(project, report_dir, suites, selected)
            code = max(code, perf_code)
            results = (results or []) + perf_results
            outputs += perf_outputs
            results.sort(key=lambda r: (r["file"], r["name"]))
        results = results or None
    # With no results at all (gdUnit aborted the whole run) only the script errors can say which file is to blame.
    if results is not None:
        found = integrity_problems(project, results, outputs, skip_perf=skip_perf, suites=suites,
                                    selected=selected)
    else:
        found = output_problems(outputs)
    for p in found:
        print("ERROR: " + p, flush=True)
    if found:
        code = max(code, 1)
    if problems is not None:
        problems.extend(found)
    if (results and code == 0 and os.path.abspath(project) == os.path.abspath(ROOT)
            and not (cov_dir or suites or selected or skip_perf or perf_only)):
        record_times(results)  # a full plain run: keep the durations for the next plan (plan_units prefers them)
    return code, results, report_dir


def fast_selection(project, base="HEAD"):
    """The {suite: [tests]} the fast tier runs (printed with the reasons), or None for everything."""
    import fast_tier
    tests = discover_tests(project)
    weights = load_weights()
    # The saved coverage map lives next to the gate cache of this repo; a project elsewhere has none and runs everything.
    cache = times_cache_path()
    units_file = os.path.join(os.path.dirname(cache), "positivefps-determinism-units.json.gz") if cache else ""
    if os.path.abspath(project) != os.path.abspath(ROOT):
        result = {"selected": None, "reason": "--project is not this checkout", "notes": []}
    else:
        result = fast_tier.choose(ROOT, tests, weights, FAST_TIER_SECONDS, units_file, base)
    for line in fast_tier.describe(result, weights, FAST_TIER_SECONDS, tests):
        print(line, flush=True)
    return result["selected"]


def main():
    parser = argparse.ArgumentParser(description="Run the PositiveFPS gdUnit4 suite headless.")
    parser.add_argument("--project", default=ROOT, help="project folder (default: this repo)")
    parser.add_argument("--workers", type=int, default=None,
                        help="Godot processes to run at once (default %d; 1 = serial)" % WORKERS_DEFAULT)
    parser.add_argument("--perf-only", action="store_true",
                        help="run only the timing tests (test_perf_*), serially, with their budgets enforced")
    parser.add_argument("--suites", nargs="+", metavar="SUITE", default=None,
                        help="run only these suites, named like tests/<name>.gd without the .gd (for example "
                             "gap_patch_test). A targeted run for a part agent; the round end runs everything")
    parser.add_argument("--tier", choices=("all", "fast"), default="all",
                        help="fast: every test under %d s plus the slower ones the changed files and functions can reach "
                             "(tools/fast_tier.py; falls back to everything when it cannot tell). Used by the pre-commit "
                             "hook; the default runs everything" % FAST_TIER_SECONDS)
    parser.add_argument("--base", default="HEAD", metavar="REV",
                        help="with --tier fast: the revision the changes are measured against (a merge base for a branch)")
    parser.add_argument("--update-weights", action="store_true",
                        help="after the run, write each test's duration to tools/test_weights.json")
    args = parser.parse_args()
    project = os.path.abspath(args.project)
    problems = []
    selected = None
    if args.tier == "fast":
        if args.perf_only or args.suites or args.update_weights:
            parser.error("--tier fast cannot be combined with --perf-only, --suites or --update-weights")
        selected = fast_selection(project, args.base)
    try:
        code, results, report_dir = run_suite(project, workers=args.workers, perf_only=args.perf_only,
                                              problems=problems, suites=args.suites, selected=selected)
    except (RuntimeError, OSError) as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    if results is None:
        for p in problems:
            print("BROKEN " + p, file=sys.stderr)
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
    broken = (", %d broken or skipped" % len(problems)) if problems else ""
    print("Tests: %d passed, %d failed%s (reports: %s)" % (len(results) - len(failed), len(failed), broken,
                                                          report_dir))
    for r in failed:
        print("FAIL %s::%s  %s" % (r["file"], r["name"], " | ".join(r["messages"])[:400]))
    for p in problems:  # last, so a dropped suite cannot hide above a summary that says "0 failed"
        print("BROKEN " + p)
    return 1 if failed or problems or code != 0 else 0


if __name__ == "__main__":
    sys.exit(main())
