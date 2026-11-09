#!/usr/bin/env python3
"""Checks (or fixes) the formatting and lint of the game and test GDScript.

Usage:
    python tools/lint.py          # check only; exit 1 if gdformat or gdlint reports a problem
    python tools/lint.py --fix    # run gdformat over scripts/ and tests/ (no --check), regenerate SOURCE_MAP.md, then gdlint

Uses gdtoolkit 4.x through its Python modules (python -m gdtoolkit.formatter / gdtoolkit.linter), so no
gdformat/gdlint launcher needs to be on PATH. Install with: python -m pip install --user "gdtoolkit==4.*"
Lint settings are read from gdlintrc at the repo root. Formatting uses a 120-column limit, matching gdlintrc.
Only the Python standard library is used. A file of 950 lines or more also prints a WARNING (gdlintrc fails
it at 1000). Exit code 2 means the tools could not run (gdtoolkit missing).
"""
import argparse
import importlib.util
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGETS = ["scripts", "tests"]
LINE_LENGTH = "120"  # Must match max-line-length in gdlintrc.
WARN_FILE_LINES = 950  # A file this long gets a warning; gdlintrc fails it at 1000 (max-file-lines).


def long_files(root=ROOT, targets=TARGETS, warn_from=WARN_FILE_LINES):
    """GDScript files with at least `warn_from` lines, as (relative path, line count), longest first."""
    found = []
    for target in targets:
        folder = os.path.join(root, target)
        for name in sorted(os.listdir(folder)) if os.path.isdir(folder) else []:
            if name.endswith(".gd"):
                with open(os.path.join(folder, name), encoding="utf-8", errors="replace") as fh:
                    count = sum(1 for _ in fh)
                if count >= warn_from:
                    found.append(("%s/%s" % (target, name), count))
    return sorted(found, key=lambda item: -item[1])


def size_warnings(root=ROOT, targets=TARGETS, warn_from=WARN_FILE_LINES):
    """Warning lines for files nearing the 1000-line cap (a warning only: it never fails the lint)."""
    return ["WARNING: %s has %d lines; the cap is 1000. Split it before it blocks a merge." % item
            for item in long_files(root, targets, warn_from)]


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
        # Formatting moves line numbers, so the map would be stale: rewrite it (the commit hook still checks it).
        proc = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "source_map.py")], cwd=ROOT,
                              capture_output=True, text=True, encoding="utf-8", errors="replace")
        print("SOURCE_MAP.md: regenerated" if proc.returncode == 0 else "SOURCE_MAP.md: regenerate failed")
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

    for warning in size_warnings():
        print(warning)

    if problems:
        if not args.fix:
            print("\nLint failed. Run: python tools/lint.py --fix")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
