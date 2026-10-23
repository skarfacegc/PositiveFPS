#!/usr/bin/env python3
"""Points this clone's git hooks at the versioned .githooks/ folder.

Usage:
    python tools/install_hooks.py

Run it once after cloning. It sets `git config core.hooksPath .githooks`, so the pre-commit gate
(.githooks/pre-commit) runs on every commit that changes code. Only the Python standard library is used.
"""
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    hook = os.path.join(ROOT, ".githooks", "pre-commit")
    if not os.path.isfile(hook):
        print("ERROR: %s is missing; is this a full clone?" % hook, file=sys.stderr)
        return 2
    try:
        subprocess.run(["git", "-C", ROOT, "config", "core.hooksPath", ".githooks"], check=True)
    except (OSError, subprocess.CalledProcessError) as err:
        print("ERROR: could not set core.hooksPath: %s" % err, file=sys.stderr)
        return 2
    print("Git hooks enabled: core.hooksPath = .githooks (pre-commit runs lint, tests and the coverage ratchet)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
