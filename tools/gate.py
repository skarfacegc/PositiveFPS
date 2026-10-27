#!/usr/bin/env python3
"""The PositiveFPS quality gate: the single entry point the pre-commit hook calls. Agents run the same thing.

Usage:
    python tools/gate.py               # lint, then the full test suite (parallel). About 25 s.
    python tools/gate.py --full        # lint, then tests with line coverage and the ratchet (about 35 s). Run this at
                                       # the end of every round, before committing a new coverage_baseline.json.
    python tools/gate.py --no-cache    # ignore the result cache and run everything again
    python tools/gate.py --hook        # what the pre-commit hook uses: like the default, but upgrades to --full when
                                       # coverage_baseline.json is staged
    python tools/gate.py --label pre-commit    # prefix for the messages (the hook sets it)

Steps: tools/lint.py, then tools/run_tests.py (default) or tools/coverage.py --check-baseline (--full, which runs the
same tests with instrumentation, so the tests are not run twice). Timing tests (test_perf_*) run serially and plain after
the parallel batch: run_tests.py does it itself in the default tier; --full follows the coverage run with
`run_tests.py --perf-only`. The cache fingerprint covers tools/ and tests/, so it needs no change for that pass.

Result cache: after a pass, the gate stores a fingerprint (sha256) of everything it depends on in
.git/positivefps-gate-cache.json. If the fingerprint is unchanged on the next run the gate prints the cached summary
and exits 0 at once. Any change to scripts/, tests/, tools/, scenes, resources, project.godot, gdlintrc, the gdUnit4
version or coverage_baseline.json (tracked or not) makes the fingerprint differ, so the full gate runs. A cached --full
pass also satisfies a plain run; a plain pass does not satisfy --full. A failed run is never cached.

Exit codes: 0 pass, 1 lint or test failure, 2 the tools could not run, 3 the coverage ratchet failed.
Only the Python standard library is used.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile
import time

for _stream in (sys.stdout, sys.stderr):  # the console may be cp1252; never fail on a character
    if hasattr(_stream, "reconfigure"):
        _stream.reconfigure(encoding="utf-8", errors="replace")

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PYTHON = sys.executable or "python"

# What the gate depends on. A path is part of the fingerprint when it matches one of these...
INCLUDE_PREFIXES = ("scripts/", "tests/", "tools/", ".githooks/")
INCLUDE_NAMES = {"project.godot", "gdlintrc", "coverage_baseline.json", "addons/gdUnit4/plugin.cfg"}
INCLUDE_SUFFIXES = (".tscn", ".tres")
# ...and none of these. design/ is mock-ups and notes; the rest is tool output or scratch.
EXCLUDE_PARTS = ("design/", ".scratch/", "__pycache__/", ".coverage_build/", "reports/", "coverage/", ".godot/")
EXCLUDE_SUFFIXES = (".pyc", ".md")  # Markdown docs cannot change a test result

LEVELS = ("tests", "full")  # a "full" pass is a superset of a "tests" pass


def git(*args):
    return subprocess.run(["git", "-C", ROOT] + list(args), capture_output=True, text=True, check=True).stdout


def cache_path():
    return os.path.join(ROOT, git("rev-parse", "--git-dir").strip(), "positivefps-gate-cache.json")


def depends_on(path):
    if path.startswith("design/") or any(part in path for part in EXCLUDE_PARTS) or path.endswith(EXCLUDE_SUFFIXES):
        return False
    return path in INCLUDE_NAMES or path.startswith(INCLUDE_PREFIXES) or path.endswith(INCLUDE_SUFFIXES)


def fingerprint():
    """sha256 over the working-tree contents of every file the gate depends on (tracked and untracked, not ignored).

    Line endings are normalised, so git's autocrlf setting cannot change the result. A tracked file that was deleted
    from the working tree is skipped, which changes the fingerprint just as removing it should.
    """
    listed = git("ls-files", "-z", "--cached", "--others", "--exclude-standard").split("\0")
    digest = hashlib.sha256()
    for path in sorted({p for p in listed if p and depends_on(p)}):
        full = os.path.join(ROOT, path)
        if not os.path.isfile(full):
            continue
        with open(full, "rb") as fh:
            data = fh.read().replace(b"\r\n", b"\n")
        digest.update(path.encode("utf-8") + b"\0" + hashlib.sha256(data).digest())
    return digest.hexdigest()


def load_cache():
    try:
        with open(cache_path(), encoding="utf-8") as fh:
            data = json.load(fh)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError, subprocess.CalledProcessError):
        return {}


def save_cache(print_, level, fp, summary):
    entry = {"fingerprint": fp, "level": level, "summary": summary,
             "when": datetime.datetime.now().isoformat(timespec="seconds")}
    try:
        with open(cache_path(), "w", encoding="utf-8") as fh:
            json.dump({"last_pass": entry}, fh, indent=2)
    except OSError as err:
        print_("could not write the gate cache (%s); the next run will not be cached" % err)


def cached_summary(fp, level):
    entry = load_cache().get("last_pass")
    if not entry or entry.get("fingerprint") != fp:
        return None
    if LEVELS.index(entry.get("level", "tests")) < LEVELS.index(level):
        return None
    return entry.get("summary")


def baseline_staged():
    try:
        return "coverage_baseline.json" in git("diff", "--cached", "--name-only").splitlines()
    except (OSError, subprocess.CalledProcessError):
        return False


def run_step(cmd, log):
    """Runs a command with its output going to `log`. Returns (exit code, output text)."""
    with open(log, "w", encoding="utf-8", errors="replace") as fh:
        proc = subprocess.run(cmd, cwd=ROOT, stdout=fh, stderr=subprocess.STDOUT)
    with open(log, encoding="utf-8", errors="replace") as fh:
        return proc.returncode, fh.read()


def key_lines(text):
    """The lines of a failing run worth showing: failures, the ratchet verdict and errors."""
    keep = re.compile(r"^FAIL |COVERAGE CHECK|^  - |^ERROR|Baseline NOT|^Tests:|^gdformat|^gdlint|\.gd:\d+")
    return [ln for ln in text.splitlines() if keep.search(ln)][:60]


def main():
    parser = argparse.ArgumentParser(description="Run the PositiveFPS quality gate (lint, tests, coverage ratchet).")
    parser.add_argument("--full", action="store_true", help="also run the coverage ratchet (tests run instrumented)")
    parser.add_argument("--no-cache", action="store_true", help="ignore the cache: always run everything")
    parser.add_argument("--hook", action="store_true", help="hook mode: --full is implied when the baseline is staged")
    parser.add_argument("--label", default="gate", help="prefix for the messages")
    args = parser.parse_args()

    def say(msg):
        print("%s: %s" % (args.label, msg), flush=True)

    full = args.full or (args.hook and baseline_staged())
    level = "full" if full else "tests"
    try:
        fp = fingerprint()
    except (OSError, subprocess.CalledProcessError) as err:
        say("could not fingerprint the working tree (%s); running without the cache" % err)
        fp = None

    if fp and not args.no_cache:
        summary = cached_summary(fp, level)
        if summary:
            say("gate already passed for this exact code (cached) — %s" % summary)
            return 0

    started = time.time()
    log_dir = tempfile.mkdtemp(prefix="positivefps-gate-")

    say("lint (tools/lint.py)")
    code, out = run_step([PYTHON, os.path.join("tools", "lint.py")], os.path.join(log_dir, "lint.log"))
    if code != 0:
        say("FAILED lint. Run: python tools/lint.py --fix   (then re-stage and commit again)")
        print(out)
        return 1 if code == 1 else 2

    if full:
        say("tests with line coverage and the ratchet (tools/coverage.py --check-baseline)")
        cmd = [PYTHON, os.path.join("tools", "coverage.py"), "--check-baseline"]
    else:
        say("tests (tools/run_tests.py)")
        cmd = [PYTHON, os.path.join("tools", "run_tests.py")]
    log = os.path.join(log_dir, "tests.log")
    code, out = run_step(cmd, log)
    if code == 0 and full:
        # The coverage run does not time the timing tests (test_perf_*, instrumented and in parallel they are noisy).
        # Run them now, alone and plain, with their budgets enforced. The plain run above already did this itself.
        say("timing tests, serial and uninstrumented (tools/run_tests.py --perf-only)")
        code, perf_out = run_step([PYTHON, os.path.join("tools", "run_tests.py"), "--perf-only"],
                                  os.path.join(log_dir, "perf.log"))
        if code != 0:
            say("FAILED timing tests (log: %s)" % os.path.join(log_dir, "perf.log"))
            print("\n".join(key_lines(perf_out)))
            return 1 if code == 1 else 2
    if code != 0:
        if code == 3:
            say("FAILED coverage ratchet (line coverage dropped below coverage_baseline.json)")
        elif code == 1:
            say("FAILED tests")
        else:
            say("FAILED, the test run could not complete (exit %d)" % code)
        print("\n".join(key_lines(out)))
        print("Full output: %s" % log)
        return code if code in (1, 3) else 2

    tests = re.search(r"^Tests: (\d+) passed", out, re.M)
    n_tests = tests.group(1) if tests else "unknown number of"
    if full:
        cov = re.search(r"^Line coverage: ([0-9.]+%)", out, re.M)
        summary = "%s tests passed, line coverage %s, baseline OK" % (n_tests, cov.group(1) if cov else "unknown")
    else:
        summary = "%s tests passed (coverage ratchet not run; use --full)" % n_tests
    elapsed = time.time() - started
    if fp:
        save_cache(say, level, fp, summary)
    say("OK in %.0f s: %s" % (elapsed, summary))
    return 0


if __name__ == "__main__":
    sys.exit(main())
