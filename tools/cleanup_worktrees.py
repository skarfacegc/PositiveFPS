#!/usr/bin/env python3
"""Removes old playtest git worktrees for PositiveFPS, plus their stale registrations.

Playtest builds run from detached git worktrees in a temp folder. Once a build is no longer needed, its
worktree stays registered under .git/worktrees/, and git warns about the stale entries on every commit.
This script removes them.

Usage:
    python tools/cleanup_worktrees.py                 show the plan, ask "Proceed? [y/N]", then do it
    python tools/cleanup_worktrees.py --dry-run       print what would happen, change nothing
    python tools/cleanup_worktrees.py --keep-latest   also keep the most recently created worktree
    python tools/cleanup_worktrees.py -y              skip the confirmation prompt

Rules:
- The main worktree (the repo itself) is never touched.
- A worktree whose folder is used by a running Godot process (its command line mentions the folder) is skipped.
- Folders are removed with `git worktree remove --force`. If that fails, the folder is deleted directly, with
  read-only files made writable first. Then `git worktree prune` clears the registrations.
- Any remaining .git/worktrees/<name> whose gitdir points to a missing path is deleted.

Exit code: 0 on success, 1 if anything could not be removed, 2 if git itself failed.
Only the Python standard library is used (Python 3.12 or newer, for shutil.rmtree's onexc argument).
"""
import argparse
import os
import re
import shutil
import stat
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PERMISSION_HINT = (
    "If you see Permission denied, close any program using the folder (Godot, Explorer, editors) "
    "and pause OneDrive sync, then re-run."
)


def git(*args):
    return subprocess.run(
        ["git", "-C", ROOT, *args], capture_output=True, text=True, encoding="utf-8", errors="replace"
    )


def norm(path):
    return os.path.normcase(os.path.normpath(os.path.abspath(path)))


def slashed(text):
    return text.replace("\\", "/").lower()


def parse_worktrees(text):
    """Parse `git worktree list --porcelain` into a list of dicts, in the order git prints them."""
    entries, current = [], None
    for line in text.splitlines():
        if not line.strip():
            if current is not None:
                entries.append(current)
            current = None
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            if current is not None:
                entries.append(current)
            current = {"path": value, "head": "", "branch": ""}
        elif current is not None:
            if key == "HEAD":
                current["head"] = value[:8]
            elif key == "branch":
                current["branch"] = value.replace("refs/heads/", "")
            elif key == "detached":
                current["branch"] = "detached"
    if current is not None:
        entries.append(current)
    return entries


def running_game_command_lines():
    """Command lines of running Godot processes. Raises RuntimeError if they cannot be listed."""
    if sys.platform == "win32":
        cmd = [
            "powershell",
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            "Get-CimInstance Win32_Process -Filter \"Name like 'Godot%'\" | "
            "Select-Object -ExpandProperty CommandLine",
        ]
    else:
        cmd = ["ps", "-eo", "args="]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    except OSError as err:
        raise RuntimeError("could not list running processes (%s)" % err)
    if result.returncode != 0:
        raise RuntimeError("could not list running processes (%s)" % result.stderr.strip())
    lines = [line.strip() for line in result.stdout.splitlines() if line.strip()]
    if sys.platform != "win32":
        lines = [line for line in lines if "godot" in line.lower()]
    return lines


def in_use_by_game(folder, command_lines):
    """True if a running Godot command line mentions this folder (slash-insensitive, case-insensitive)."""
    pattern = re.compile(re.escape(slashed(folder).rstrip("/")) + r"(?=[/\"'\s]|$)")
    return any(pattern.search(slashed(line)) for line in command_lines)


def _make_writable_and_retry(func, path, exc):
    """shutil.rmtree error handler: clear the read-only bit, then retry the failed operation once."""
    os.chmod(path, stat.S_IWRITE | stat.S_IREAD)
    func(path)


def rmtree_writable(path):
    shutil.rmtree(path, onexc=_make_writable_and_retry)


def git_common_dir():
    result = git("rev-parse", "--git-common-dir")
    return norm(os.path.join(ROOT, result.stdout.strip()))


def stale_metadata_dirs():
    """Return (stale, unreadable): .git/worktrees/<name> folders whose gitdir target no longer exists."""
    base = os.path.join(git_common_dir(), "worktrees")
    stale, unreadable = [], []
    if not os.path.isdir(base):
        return stale, unreadable
    for name in sorted(os.listdir(base)):
        entry = os.path.join(base, name)
        if not os.path.isdir(entry):
            continue
        try:
            with open(os.path.join(entry, "gitdir"), encoding="utf-8") as handle:
                target = handle.read().strip()
        except FileNotFoundError:
            # No gitdir file at all: nothing can be using this registration, so git prune drops it too.
            stale.append(entry)
            continue
        except OSError as err:
            unreadable.append((entry, str(err)))
            continue
        if not os.path.exists(target):
            stale.append(entry)
    return stale, unreadable


def build_plan(worktrees, keep_latest, command_lines):
    """Return a list of (state, path, note). state is remove, skip, keep or gone."""
    latest = None
    if keep_latest:
        existing = [wt["path"] for wt in worktrees if os.path.isdir(wt["path"])]
        if existing:
            latest = max(existing, key=os.path.getmtime)
    plan = []
    for wt in worktrees:
        path = wt["path"]
        if not os.path.isdir(path):
            plan.append(("gone", path, "folder already missing; its registration will be pruned"))
        elif in_use_by_game(path, command_lines):
            plan.append(("skip", path, "in use by a running game - close the game and re-run"))
        elif latest is not None and norm(path) == norm(latest):
            plan.append(("keep", path, "most recently created (--keep-latest)"))
        else:
            plan.append(("remove", path, "playtest worktree, no running game"))
    return plan


def remove_worktree(path):
    """Remove one worktree folder. Returns (ok, message)."""
    result = git("worktree", "remove", "--force", path)
    if result.returncode == 0:
        return True, "removed"
    git_error = (result.stderr or result.stdout).strip()
    try:
        rmtree_writable(path)
    except OSError as err:
        return False, "git could not remove it (%s); deleting the folder also failed: %s" % (git_error, err)
    return True, "folder deleted directly (git said: %s); registration cleared by prune" % git_error


def remove_metadata_dir(entry):
    try:
        rmtree_writable(entry)
    except OSError as err:
        return False, str(err)
    return True, "deleted"


def run_prune(dry_run):
    args = ["worktree", "prune", "-v"]
    if dry_run:
        args.append("--dry-run")
    result = git(*args)
    output = (result.stdout + result.stderr).strip()
    return result.returncode == 0, output


def print_worktree_list():
    print("\ngit worktree list:")
    print(git("worktree", "list").stdout.rstrip())


LABELS = {"remove": "REMOVE", "skip": "SKIP", "keep": "KEEP", "gone": "GONE"}


def main(argv=None):
    parser = argparse.ArgumentParser(description="Remove old playtest git worktrees and their stale registrations.")
    parser.add_argument("--dry-run", action="store_true", help="print what would happen, change nothing")
    parser.add_argument("--keep-latest", action="store_true",
                        help="also keep the most recently created worktree (by folder mtime)")
    parser.add_argument("-y", "--yes", action="store_true", help="skip the 'Proceed? [y/N]' prompt")
    args = parser.parse_args(argv)

    listing = git("worktree", "list", "--porcelain")
    if listing.returncode != 0:
        print("ERROR: git worktree list failed: %s" % listing.stderr.strip(), file=sys.stderr)
        return 2
    entries = parse_worktrees(listing.stdout)
    # git lists the main worktree first; it is never a cleanup candidate.
    worktrees = [e for i, e in enumerate(entries) if i > 0 and norm(e["path"]) != norm(ROOT)]

    try:
        command_lines = running_game_command_lines()
    except RuntimeError as err:
        print("ERROR: %s. Refusing to change anything without knowing which games are running." % err,
              file=sys.stderr)
        return 1

    plan = build_plan(worktrees, args.keep_latest, command_lines)
    stale, unreadable = stale_metadata_dirs()

    print("Repo: %s" % ROOT)
    print("Playtest worktrees (main worktree is never touched):")
    if not plan:
        print("  none")
    for state, path, note in plan:
        print("  %-6s %s" % (LABELS[state], path))
        print("         %s" % note)
    print("Stale registrations in .git/worktrees (after prune):")
    if not stale:
        print("  none")
    for entry in stale:
        print("  DELETE %s" % entry)
    for entry, err in unreadable:
        print("  WARNING: could not read %s (%s); leaving it alone" % (entry, err))

    to_remove = [path for state, path, _ in plan if state == "remove"]
    if args.dry_run:
        print("\nDry run: nothing was changed. Prune preview:")
        ok, output = run_prune(dry_run=True)
        print(output or "  (nothing to prune)")
        print("Would remove %d worktree folder(s) and delete %d stale registration(s)."
              % (len(to_remove), len(stale)))
        print_worktree_list()
        return 0 if ok else 2

    if not to_remove and not stale and not any(state == "gone" for state, _, _ in plan):
        print("\nNothing to clean up.")
        print_worktree_list()
        return 0

    if not args.yes:
        try:
            answer = input("\nProceed? [y/N] ")
        except EOFError:
            answer = ""
        if answer.strip().lower() not in ("y", "yes"):
            print("Cancelled. Nothing was changed.")
            return 0

    failures = []
    removed, skipped = 0, 0
    print()
    for state, path, _ in plan:
        if state == "skip":
            skipped += 1
            print("SKIP (in use by a running game): %s" % path)
        elif state == "remove":
            ok, message = remove_worktree(path)
            if ok:
                removed += 1
                print("REMOVED: %s (%s)" % (path, message))
            else:
                failures.append("%s: %s" % (path, message))
                print("FAILED: %s: %s" % (path, message))

    ok, output = run_prune(dry_run=False)
    print("prune: %s" % (output or "nothing to prune"))
    if not ok:
        failures.append("git worktree prune failed")

    # Prune already drops registrations whose folder is gone; this deletes the leftovers it could not.
    leftover_stale, _ = stale_metadata_dirs()
    pruned = len([entry for entry in stale if entry not in leftover_stale])
    deleted = 0
    for entry in leftover_stale:
        ok, message = remove_metadata_dir(entry)
        if ok:
            deleted += 1
            print("DELETED stale registration: %s" % entry)
        else:
            failures.append("%s: %s" % (entry, message))
            print("FAILED to delete stale registration %s: %s" % (entry, message))

    print("\nSummary: removed %d worktree folder(s), skipped %d in use, cleared %d stale registration(s) "
          "(%d by prune, %d deleted directly), %d failure(s)."
          % (removed, skipped, pruned + deleted, pruned, deleted, len(failures)))
    print_worktree_list()

    if failures:
        print("\nCould not remove everything:", file=sys.stderr)
        for failure in failures:
            print("  - %s" % failure, file=sys.stderr)
        print("\nHint: " + PERMISSION_HINT, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
