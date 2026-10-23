#!/usr/bin/env python3
"""Runs the PositiveFPS gdUnit4 test suite headless.

Usage:
    python tools/run_tests.py                 # test the repo itself
    python tools/run_tests.py --project DIR   # test another copy of the project

The Godot console executable comes from the GODOT environment variable, or the known install path below.
Reports are written to <project>/reports/<timestamp>/ (HTML and JUnit XML). The exit code is 0 when all
tests pass, 1 when any test fails, and 2 if Godot could not run.

Only the Python standard library is used. This module's functions are also used by tools/coverage.py.
"""
import argparse
import datetime
import os
import subprocess
import sys
import xml.etree.ElementTree as ET

DEFAULT_GODOT = (
    r"C:\Users\amw1\AppData\Local\Microsoft\WinGet\Packages"
    r"\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\Godot_v4.7.2-stable_win64_console.exe"
)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


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


def run_gdunit(project, report_dir, extra_args=None):
    """Runs every test under res://tests with the gdUnit4 CLI. Returns Godot's exit code."""
    args = [
        "-s", "res://addons/gdUnit4/bin/GdUnitCmdTool.gd",
        "--ignoreHeadlessMode",
        "-c",  # keep running after a failure
        "-a", "res://tests",
        "-rd", report_dir,
    ] + (extra_args or [])
    code, _ = run_godot(args, project)
    return code


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
    """Returns a list of {file, name, ok, messages} dicts, one per test case, from a gdUnit4 JUnit XML."""
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
        results.append({"file": file_name, "name": case.get("name", ""), "ok": ok, "messages": messages})
    return results


def run_suite(project, report_root=None):
    """Runs the whole suite on `project`. Returns (exit code, list of test result dicts or None)."""
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    report_root = report_root or os.path.join(project, "reports")
    report_dir = os.path.join(report_root, stamp)
    os.makedirs(report_dir, exist_ok=True)
    import_project(project)
    code = run_gdunit(project, report_dir)
    xml = latest_results_xml(report_dir)
    results = parse_results(xml) if xml else None
    return code, results, report_dir


def main():
    parser = argparse.ArgumentParser(description="Run the PositiveFPS gdUnit4 suite headless.")
    parser.add_argument("--project", default=ROOT, help="project folder (default: this repo)")
    args = parser.parse_args()
    project = os.path.abspath(args.project)
    try:
        code, results, report_dir = run_suite(project)
    except (RuntimeError, OSError) as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    if results is None:
        print("ERROR: no results.xml written; see the Godot output above.", file=sys.stderr)
        return 2
    failed = [r for r in results if not r["ok"]]
    print("")
    print("Tests: %d passed, %d failed (reports: %s)" % (len(results) - len(failed), len(failed), report_dir))
    for r in failed:
        print("FAIL %s::%s  %s" % (r["file"], r["name"], " | ".join(r["messages"])[:400]))
    return 1 if failed or code != 0 else 0


if __name__ == "__main__":
    sys.exit(main())
