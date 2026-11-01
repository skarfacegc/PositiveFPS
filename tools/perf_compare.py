#!/usr/bin/env python3
"""Compares the timing tests (test_perf_*) of two commits by alternating serial runs, so machine drift hits both alike.

Usage:
    python tools/perf_compare.py <commit-or-folder A> <commit-or-folder B> [--rounds 3] [--timeout 900]
    python tools/perf_compare.py main~3 HEAD --rounds 5
    python tools/perf_compare.py C:/some/checkout .scratch/other_checkout

A side that names an existing folder is used as given (never modified or removed). Anything else is a git revision: it
gets a detached scratch worktree under .scratch/perf_compare/ which is removed at the end. Each round runs
`run_tests.py --perf-only` on A, then on B (A B A B ...), one after the other, never in parallel. The first run of a fresh
worktree also does Godot's import, so it is slow; its readings count like the others.

The readings come from the output of `run_tests.py --perf-only`. A timing test prints its reading on a line starting with
WORLD_SCALE, MINIMAP or PERF and containing "<label>: <number> ms" (see run_tests.PERF_READING_PREFIXES; the serial pass
echoes those lines, so they are in the captured log). Timing tests that print no reading, or that fail their budget, are
listed too, by suite, with their exit status. Every run goes through tools/godot_run.py's timeout, with a log in
.scratch/perf_compare/logs/. Output: each reading, then mean, min, max and spread (max - min) per test and side, and the
difference of the means. It warns when other Godot processes are running or the CPU is busy (checked before every run);
it only reports them, it never touches them. Exit code: 0 done, 1 a run failed or timed out, 2 bad arguments.
"""
import argparse
import os
import re
import shutil
import statistics
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_run import run as godot_run  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRATCH = os.path.join(ROOT, ".scratch", "perf_compare")
CPU_BUSY_PERCENT = 30.0
READING = re.compile(r"^(?P<label>(?:WORLD_SCALE|MINIMAP|PERF)\b.*?):\s*(?P<value>\d+(?:\.\d+)?) ms")
UNIT = re.compile(r"^serial timing unit (?P<suite>\S+)\s+exit (?P<code>-?\d+)")


def parse_output(text):
    """Returns ({label: ms}, {suite: exit code}) from the output of `run_tests.py --perf-only`."""
    readings, units = {}, {}
    for line in text.splitlines():
        m = READING.match(line.strip())
        if m:
            readings[m.group("label")] = float(m.group("value"))
            continue
        m = UNIT.match(line)
        if m:
            units[m.group("suite")] = int(m.group("code"))
    return readings, units


def summarise(values):
    """mean, min, max and spread of a list of readings."""
    return {"n": len(values), "mean": statistics.fmean(values), "min": min(values), "max": max(values),
            "spread": max(values) - min(values)}


def build_report(names, runs):
    """runs: {side name: [(readings, units), ...]} in run order. Returns the report text."""
    lines = []
    labels = sorted({k for rs in runs.values() for r, _u in rs for k in r})
    for label in labels:
        lines.append(label)
        means = {}
        for side in names:
            values = [r[label] for r, _u in runs[side] if label in r]
            if not values:
                lines.append("  %-14s no reading" % side)
                continue
            s = summarise(values)
            means[side] = s["mean"]
            lines.append("  %-14s readings %s ms" % (side, ", ".join("%.3f" % v for v in values)))
            lines.append("  %-14s mean %.3f  min %.3f  max %.3f  spread %.3f ms" % ("", s["mean"], s["min"], s["max"],
                                                                                    s["spread"]))
        if len(means) == 2:
            a, b = (means[n] for n in names)
            lines.append("  difference (%s - %s): %+.3f ms (%+.1f %%)" % (names[1], names[0], b - a,
                                                                          100.0 * (b - a) / a if a else 0.0))
        lines.append("")
    suites = sorted({u for rs in runs.values() for _r, us in rs for u in us})
    for suite in suites:
        codes = {side: [us.get(suite) for _r, us in runs[side]] for side in names}
        bad = any(c not in (0, 100, None) for cs in codes.values() for c in cs)
        lines.append("unit %s: exit codes %s%s" % (suite, "; ".join("%s %s" % (n, codes[n]) for n in names),
                                                   "   <-- FAILED a run (budget missed or error)" if bad else ""))
    if not labels:
        lines.append("WARNING: no timing readings were found in any output. Check the logs.")
    return "\n".join(lines)


def godot_processes():
    """Names and pids of running Godot processes (reported, never touched). Empty when it cannot tell."""
    try:
        if os.name == "nt":
            out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True,
                                 timeout=30).stdout
            found = []
            for row in out.splitlines():
                parts = [p.strip('"') for p in row.split('","')]
                if len(parts) > 1 and "godot" in parts[0].lower():
                    found.append("%s (pid %s)" % (parts[0], parts[1]))
            return found
        out = subprocess.run(["pgrep", "-ai", "godot"], capture_output=True, text=True, timeout=30).stdout
        return [ln for ln in out.splitlines() if ln.strip()]
    except (OSError, subprocess.SubprocessError):
        return []


def cpu_percent():
    """Current CPU load in percent, or None when it cannot be read."""
    try:
        if os.name == "nt":
            cmd = ["powershell", "-NoProfile", "-Command",
                   "(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average"]
            out = subprocess.run(cmd, capture_output=True, text=True, timeout=60).stdout.strip()
            return float(out)
        return 100.0 * os.getloadavg()[0] / (os.cpu_count() or 1)
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def environment_warnings(procs, cpu):
    out = []
    if procs:
        out.append("other Godot processes are running (they skew timings): " + ", ".join(procs))
    if cpu is not None and cpu >= CPU_BUSY_PERCENT:
        out.append("CPU load is %.0f %% (>= %.0f %%): readings will be noisy" % (cpu, CPU_BUSY_PERCENT))
    return out


def make_side(spec):
    """Returns (display name, project folder, worktree to remove or None) for a commit or folder."""
    if os.path.isdir(spec):
        return os.path.basename(os.path.abspath(spec)) or spec, os.path.abspath(spec), None
    sha = subprocess.run(["git", "rev-parse", "--short", spec + "^{commit}"], cwd=ROOT, capture_output=True, text=True)
    if sha.returncode != 0:
        raise ValueError("%r is neither a folder nor a git revision" % spec)
    name = "%s@%s" % (spec, sha.stdout.strip()) if spec != sha.stdout.strip() else spec
    path = os.path.join(SCRATCH, "wt_" + sha.stdout.strip())
    if os.path.exists(path):
        remove_worktree(path)
    os.makedirs(SCRATCH, exist_ok=True)
    add = subprocess.run(["git", "worktree", "add", "--detach", path, spec], cwd=ROOT, capture_output=True, text=True)
    if add.returncode != 0:
        raise ValueError("git worktree add failed: " + add.stderr.strip())
    return name, path, path


def remove_worktree(path):
    subprocess.run(["git", "worktree", "remove", "--force", path], cwd=ROOT, capture_output=True, text=True)
    if os.path.exists(path):
        shutil.rmtree(path, ignore_errors=True)
    subprocess.run(["git", "worktree", "prune"], cwd=ROOT, capture_output=True, text=True)


def run_side(project, log_path, timeout):
    """One `run_tests.py --perf-only` on a project. Returns (readings, units, RunResult)."""
    cmd = [sys.executable, os.path.join(ROOT, "tools", "run_tests.py"), "--project", project, "--perf-only"]
    result = godot_run(cmd, timeout=timeout, log_path=log_path)
    readings, units = parse_output(result.output())
    return readings, units, result


def compare(spec_a, spec_b, rounds, timeout, runner=run_side, say=print, probe=None):
    """Runs the alternating comparison. Returns (report text, number of failed runs). `runner` and `probe` can be faked."""
    probe = probe or (lambda: (godot_processes(), cpu_percent()))
    sides = [make_side(spec_a), make_side(spec_b)]
    names = [s[0] for s in sides]
    if names[0] == names[1]:
        names = [names[0] + " (A)", names[1] + " (B)"]
    runs = {n: [] for n in names}
    failures = 0
    warnings = []
    try:
        for rnd in range(1, rounds + 1):
            for name, (_n, project, _wt) in zip(names, sides):
                for w in environment_warnings(*probe()):
                    say("WARNING before round %d, %s: %s" % (rnd, name, w))
                    warnings.append(w)
                log = os.path.join(SCRATCH, "logs", "round%d_%s.log" % (rnd, re.sub(r"[^\w.-]", "_", name)))
                readings, units, result = runner(project, log, timeout)
                say("round %d %-20s exit %s, %.0f s, %d readings (log %s)" % (
                    rnd, name, result.exit_code, result.seconds, len(readings), result.log_path))
                if result.timed_out or result.exit_code not in (0, 1):
                    failures += 1
                    say("  this run did not finish cleanly; its readings may be missing")
                runs[name].append((readings, units))
    finally:
        for _n, _p, wt in sides:
            if wt:
                remove_worktree(wt)
    text = build_report(names, runs)
    if warnings:
        text += "\n\nWARNINGS during the comparison (%d): the numbers above may be skewed.\n  " % len(warnings)
        text += "\n  ".join(sorted(set(warnings)))
    return text, failures


def main(argv=None):
    parser = argparse.ArgumentParser(description="Alternate serial timing runs of two commits and report the spread.")
    parser.add_argument("a", help="a git revision or an existing project folder")
    parser.add_argument("b", help="a git revision or an existing project folder")
    parser.add_argument("--rounds", type=int, default=3, help="runs per side (default 3)")
    parser.add_argument("--timeout", type=float, default=900, help="seconds allowed for one run (default 900)")
    args = parser.parse_args(argv)
    if args.rounds < 1:
        print("ERROR: --rounds must be at least 1", file=sys.stderr)
        return 2
    try:
        text, failures = compare(args.a, args.b, args.rounds, args.timeout)
    except ValueError as err:
        print("ERROR: %s" % err, file=sys.stderr)
        return 2
    print("")
    print(text)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
