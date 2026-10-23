#!/usr/bin/env python3
"""Checks (or fixes) the formatting and lint of the game and test GDScript.

Usage:
    python tools/lint.py          # check only; exit 1 if gdformat or gdlint reports a problem
    python tools/lint.py --fix    # run gdformat over scripts/ and tests/ (no --check), then gdlint

Uses gdtoolkit 4.x through its Python modules (python -m gdtoolkit.formatter / gdtoolkit.linter), so no
gdformat/gdlint launcher needs to be on PATH. Install with: python -m pip install --user "gdtoolkit==4.*"
Lint settings are read from gdlintrc at the repo root. Formatting uses a 120-column limit, matching gdlintrc.
Only the Python standard library is used. Exit code 2 means the tools could not run (gdtoolkit missing).
"""
import argparse
import importlib.util
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = ["scripts", "tests"]
LINE_LENGTH = "120"  # Must match max-line-length in gdlintrc.


def run_tool(module, extra_args):
    """Runs a gdtoolkit module from the repo root. Returns (exit code, combined output)."""
    cmd = [sys.executable, "-m", module] + extra_args + TARGETS
    proc = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    return proc.returncode, (proc.stdout + proc.stderr).strip()


def main():
    parser = argparse.ArgumentParser(description="Check or fix GDScript formatting and lint.")
    parser.add_argument("--fix", action="store_true", help="reformat the files with gdformat, then lint")
    args = parser.parse_args()

    if importlib.util.find_spec("gdtoolkit") is None:
        print('ERROR: gdtoolkit is not installed. Run: python -m pip install --user "gdtoolkit==4.*"',
              file=sys.stderr)
        return 2

    problems = False
    if args.fix:
        code, out = run_tool("gdtoolkit.formatter", ["-l", LINE_LENGTH])
        print(out or "gdformat: nothing to report")
        if code != 0:
            print("ERROR: gdformat failed", file=sys.stderr)
            return 2
    else:
        code, out = run_tool("gdtoolkit.formatter", ["-l", LINE_LENGTH, "--check"])
        if code != 0:
            problems = True
            print("gdformat: formatting problems (run: python tools/lint.py --fix)")
            print(out)
        else:
            print("gdformat: ok")

    code, out = run_tool("gdtoolkit.linter", [])
    if code != 0:
        problems = True
        print("gdlint: problems")
        print(out)
    else:
        print("gdlint: ok")

    if problems:
        if not args.fix:
            print("\nLint failed. Run: python tools/lint.py --fix")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
