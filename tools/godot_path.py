#!/usr/bin/env python3
"""Finds the Godot 4.7.2 executables for the PositiveFPS tools. The one place that knows where Godot lives.

Usage:
    python tools/godot_path.py          # prints the console executable (run_tests.py, coverage.py, the gate)
    python tools/godot_path.py --gui    # prints the windowed executable (tools/checkpoint_shots.py)
Exit code 2, with a message on stderr, when Godot cannot be found.

Lookup order for the console executable:
  1. the GODOT environment variable (used as given);
  2. `godot` or `Godot_v4.7.2-stable_win64_console.exe` on PATH;
  3. the newest WinGet install: %LOCALAPPDATA%/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/
     Godot_v4.7.2-stable_win64*_console.exe.

The windowed executable (--gui): the GODOT_GUI environment variable, else the non-console executable next to the
console one found above, else the console one itself (it opens a window too).

No paths are hard-coded here, so the tools work for any Windows user account. Only the Python standard library is used.
"""
import glob
import os
import shutil
import sys

CONSOLE_NAME = "Godot_v4.7.2-stable_win64_console.exe"
WINGET_PATTERN = os.path.join("Microsoft", "WinGet", "Packages", "GodotEngine.GodotEngine_*",
                              "Godot_v4.7.2-stable_win64*_console.exe")


def godot_console():
    """The console executable's path, or None if it cannot be found."""
    env = os.environ.get("GODOT")
    if env:
        return env
    for name in ("godot", CONSOLE_NAME):
        found = shutil.which(name)
        if found:
            return found
    local = os.environ.get("LOCALAPPDATA")
    if local:
        matches = sorted(glob.glob(os.path.join(local, WINGET_PATTERN)))
        if matches:
            return matches[-1]
    return None


def godot_gui():
    """The windowed executable's path, or None if no Godot can be found at all."""
    env = os.environ.get("GODOT_GUI")
    if env:
        return env
    console = godot_console()
    if console is None:
        return None
    gui = console.replace("_console.exe", ".exe")
    return gui if gui != console and os.path.exists(gui) else console


def require(path_fn, what):
    """path_fn() or a RuntimeError that says how to point the tools at Godot."""
    path = path_fn()
    if not path:
        raise RuntimeError("Godot 4.7.2 not found (%s). Set the GODOT environment variable to the console "
                           "executable, or install it with WinGet." % what)
    return path


def main():
    gui = "--gui" in sys.argv[1:]
    try:
        print(require(godot_gui if gui else godot_console, "GODOT_GUI" if gui else "GODOT"))
    except RuntimeError as err:
        print("ERROR: " + str(err), file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
