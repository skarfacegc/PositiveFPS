#!/usr/bin/env python3
"""Renders the graphics checkpoint screenshots of the game, in both looks, at the same moment.

Usage:
    python tools/checkpoint_shots.py [--out DIR]     # default DIR: design/renders/checkpoint_02
    python tools/checkpoint_shots.py --set round19   # graphics checkpoint 3: beacon, landmarks, dawn screens
                                                     # (default DIR: design/renders/checkpoint_03)
    python tools/checkpoint_shots.py --set round20   # graphics checkpoint 4: reach guide, zone, minimap, walk
                                                     # (default DIR: design/renders/checkpoint_04)

It launches the GAME (the real level, not design/style_test) in a labelled window through
tools/checkpoint/checkpoint_shots.tscn. The scenario is scripted through the game's own API (fixed seed: a ring of
rescued people forms a border, two stretches are marked as gaps, dimmed people press one, the landmark and a block are
beautified, mid-night). The rules are then frozen and the same view is saved in the placeholder look and, after flipping
the look in place (F4), in the styled look:

    overview.png, gap_closeup.png          the styled look (what the checkpoint is about)
    overview_placeholder.png, overview_styled.png, gap_closeup_placeholder.png, gap_closeup_styled.png
    compare.png                            placeholder on the left, styled on the right
    timings.txt                            average ms per frame of each look (vsync off)

Needs a real window (no headless): it is titled "PositiveFPS - RENDERING CHECKPOINT SCREENSHOTS (closes automatically)",
never captures the mouse and quits by itself (hard limit 170 s here, 200 s for this script; the round20 set allows 600 s and 650 s). The Godot executable is the
non-console one next to the console one used by run_tests.py (tools/godot_path.py; GODOT_GUI overrides it).
Only the Python standard library is used.
"""
import argparse
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_path import godot_gui  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEWS = ["overview", "gap_closeup", "wedge_closeup", "shield_closeup", "ui_closeup", "minimap_closeup", "zoom_min",
         "zoom_max", "sealed_edge", "sealed_minimap"]
EXPECTED = (["overview.png", "compare.png", "contact_sheet.png", "contact_sheet_compare.png", "timings.txt"]
            + ["%s_%s.png" % (v, look) for v in VIEWS for look in ("placeholder", "styled")])
# Graphics checkpoint 3 (--set round19): the beacon, each landmark unheld / claiming / held, the HUD panel, the minimap
# and the four end screens.
VIEWS_R19 = (["overview", "beacon_closeup"]
             + ["%s_%s" % (n, s) for n in ("bandstand", "garden", "bell") for s in ("unheld", "claiming", "held")]
             + ["landmark_hud", "minimap_beacon", "dawn_3", "dawn_2", "dawn_1", "dawn_lost"])
EXPECTED_R19 = (["overview.png", "compare.png", "contact_sheet.png", "contact_sheet_compare.png", "landmarks_sheet.png"]
                + ["%s_%s.png" % (v, look) for v in VIEWS_R19 for look in ("placeholder", "styled")])


# Graphics checkpoint 4 (--set round20): the round 20 pieces, the walk strips and the round 19 flags.
VIEWS_R20 = ["reach_in_range", "reach_capped", "minimap_clouds", "landmark_claimed", "alert_claimed", "landmark_lost",
             "alert_lost", "zone_travel", "reach_travel_close", "zone_hold", "zone_snapped", "minimap_after",
             "walk_grey", "walk_joy", "walk_dimmed", "walk_player", "run_player", "walk_crowd", "flag_wedge_closeup",
             "flag_shield_closeup", "flag_ui_closeup", "flag_dawn"]
EXPECTED_R20 = (["overview.png", "compare.png", "contact_sheet.png", "contact_sheet_compare.png", "walk_sheet.png"]
                + ["%s_%s.png" % (v, look) for v in VIEWS_R20 for look in ("placeholder", "styled")])


def main():
    parser = argparse.ArgumentParser(description="Render the checkpoint screenshots in both looks.")
    parser.add_argument("--set", dest="shot_set", choices=("checkpoint2", "round19", "round20"),
                        default="checkpoint2")
    parser.add_argument("--out", default=None)
    args = parser.parse_args()
    if args.out is None:
        folder = {"round19": "checkpoint_03", "round20": "checkpoint_04"}.get(args.shot_set, "checkpoint_02")
        args.out = os.path.join("design", "renders", folder)
    out_abs = os.path.abspath(os.path.join(ROOT, args.out))
    exe = godot_gui()
    if not exe or not os.path.exists(exe):
        print("ERROR: Godot 4.7.2 not found (%s). Set GODOT_GUI or GODOT to the executable." % (exe or "no path"),
              file=sys.stderr)
        return 2
    os.makedirs(out_abs, exist_ok=True)
    env = dict(os.environ, POSITIVEFPS_TEST="1")
    scene = "checkpoint_round20.tscn" if args.shot_set == "round20" else "checkpoint_shots.tscn"
    cmd = [exe, "--path", ROOT, "res://tools/checkpoint/" + scene, "--", "--out", out_abs.replace("\\", "/")]
    if args.shot_set in ("round19", "round20"):
        cmd += ["--set", args.shot_set]
    if args.shot_set == "round20":
        cmd += ["--timeout", "600"]
    try:
        proc = subprocess.run(cmd, env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=650 if args.shot_set == "round20" else 200)
    except subprocess.TimeoutExpired:
        print("ERROR: the screenshot run timed out", file=sys.stderr)
        return 2
    for line in proc.stdout.splitlines():
        if line.startswith(("TIMING", "SAVED", "GAPS", "SEALED")) or "ERROR" in line:
            print(line)
    expected = {"round19": EXPECTED_R19, "round20": EXPECTED_R20}.get(args.shot_set, EXPECTED)
    missing = [name for name in expected if not os.path.exists(os.path.join(out_abs, name))]
    if missing:
        print("ERROR: missing outputs: " + ", ".join(missing), file=sys.stderr)
        return 1
    print("checkpoint shots: OK -> " + out_abs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
