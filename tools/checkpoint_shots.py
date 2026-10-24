#!/usr/bin/env python3
"""Renders the graphics checkpoint screenshots of the game, in both looks, at the same moment.

Usage:
    python tools/checkpoint_shots.py [--out DIR]     # default DIR: design/renders/checkpoint_01

It launches the GAME (the real level, not design/style_test) in a labelled window through
tools/checkpoint/checkpoint_shots.tscn. The scenario is scripted through the game's own API (fixed seed: a ring of
rescued people forms a border, two stretches are marked as gaps, dark people press one, the landmark and a block are
beautified, mid-night). The rules are then frozen and the same view is saved in the placeholder look and, after flipping
the look in place (F4), in the styled look:

    overview.png, gap_closeup.png          the styled look (what the checkpoint is about)
    overview_placeholder.png, overview_styled.png, gap_closeup_placeholder.png, gap_closeup_styled.png
    compare.png                            placeholder on the left, styled on the right
    timings.txt                            average ms per frame of each look (vsync off)

Needs a real window (no headless): it is titled "PositiveFPS - RENDERING CHECKPOINT SCREENSHOTS (closes automatically)",
never captures the mouse and quits by itself (hard limit 60 s here, 90 s for this script). The Godot executable is the
non-console one next to the console one used by run_tests.py (the GODOT_GUI environment variable overrides it).
Only the Python standard library is used.
"""
import argparse
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_GODOT_GUI = (
    r"C:\Users\amw1\AppData\Local\Microsoft\WinGet\Packages"
    r"\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
    r"\Godot_v4.7.2-stable_win64.exe"
)
EXPECTED = ["overview.png", "gap_closeup.png", "compare.png", "overview_placeholder.png", "overview_styled.png",
            "gap_closeup_placeholder.png", "gap_closeup_styled.png", "timings.txt"]


def main():
    parser = argparse.ArgumentParser(description="Render the checkpoint screenshots in both looks.")
    parser.add_argument("--out", default=os.path.join("design", "renders", "checkpoint_01"))
    args = parser.parse_args()
    out_abs = os.path.abspath(os.path.join(ROOT, args.out))
    exe = os.environ.get("GODOT_GUI", DEFAULT_GODOT_GUI)
    if not os.path.exists(exe):
        print("ERROR: Godot executable not found: " + exe, file=sys.stderr)
        return 2
    os.makedirs(out_abs, exist_ok=True)
    env = dict(os.environ, POSITIVEFPS_TEST="1")
    cmd = [exe, "--path", ROOT, "res://tools/checkpoint/checkpoint_shots.tscn", "--", "--out", out_abs.replace("\\", "/")]
    try:
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=90)
    except subprocess.TimeoutExpired:
        print("ERROR: the screenshot run timed out", file=sys.stderr)
        return 2
    for line in proc.stdout.splitlines():
        if line.startswith(("TIMING", "SAVED", "GAPS")) or "ERROR" in line:
            print(line)
    missing = [name for name in EXPECTED if not os.path.exists(os.path.join(out_abs, name))]
    if missing:
        print("ERROR: missing outputs: " + ", ".join(missing), file=sys.stderr)
        return 1
    print("checkpoint shots: OK -> " + out_abs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
