#!/usr/bin/env python3
"""Renders the graphics checkpoint screenshots of the game, in both looks, at the same moment.

Usage:
    python tools/checkpoint_shots.py [--out DIR]     # default DIR: design/renders/checkpoint_02
    python tools/checkpoint_shots.py --set round19   # graphics checkpoint 3: beacon, landmarks, dawn screens
                                                     # (default DIR: design/renders/checkpoint_03)
    python tools/checkpoint_shots.py --set round20   # graphics checkpoint 4: reach guide, zone, minimap, walk
                                                     # (default DIR: design/renders/checkpoint_04)
    python tools/checkpoint_shots.py --set round24   # graphics checkpoint 5: the fight, first light, shape preview
                                                     # (default DIR: design/renders/checkpoint_05)
    python tools/checkpoint_shots.py --set checkpoint7   # graphics checkpoint 7: calm opening, mid-night inside and
                                                         # outside the zone, a push, dawn (default DIR: design/renders/checkpoint_07)

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
never captures the mouse and quits by itself (hard limit 170 s here, 200 s for this script; the round20 set allows 600 s and 650 s). The run goes
through tools/godot_run.py: a timeout ends only the process tree it started, and the log is <out>/checkpoint_run.log. The Godot executable is the
non-console one next to the console one used by run_tests.py (tools/godot_path.py; GODOT_GUI overrides it).
Only the Python standard library is used.
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from godot_path import godot_gui  # noqa: E402
from godot_run import run as godot_run  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
VIEWS = ["overview", "wedge_closeup", "shield_closeup", "ui_closeup", "minimap_closeup", "zoom_min", "zoom_max"]
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


# Graphics checkpoint 5 (--set round24): reading the fight (gaps, strain rings, patch, burst, wobble, reactions, cue,
# notice), first light, the shape preview, dimmed warming and the walks.
VIEWS_R24 = ["fight_strain", "fight_gap_closeup", "fight_strain_closeup", "fight_cue_ready", "fight_burst_before",
             "fight_burst", "fight_burst_closeup", "fight_notice", "wobble_overview", "wobble_closeup",
             "dimmed_warming", "reach_preview", "reach_limited", "reach_stretching", "reach_pulse",
             "dawn_early", "dawn_banner", "dawn_minimap_early", "dawn_mid", "dawn_lifted_closeup",
             "dawn_minimap_mid", "dawn_late", "dawn_minimap_late",
             "walk_grey", "walk_joy", "walk_dimmed", "walk_player", "run_player", "walk_crowd"]
# Graphics checkpoint 7 (--set checkpoint7): calm opening, mid-night inside and outside the zone, a push, dawn.
# 0.3.1 adds the play-zoom views (full frame at zoom 19.5): calm opening, mid-night inside and outside the zone, a push.
VIEWS_PLAY = ["play_calm_opening", "play_midnight_inside_zone", "play_midnight_outside_zone", "play_push_in_progress",
              "play_props_bunting"]
VIEWS_C7 = (["calm_opening", "midnight_inside_zone", "midnight_outside_zone", "push_in_progress", "push_closeup"]
            + VIEWS_PLAY + ["dawn"])
EXPECTED_C7 = (["contact_sheet.png", "contact_sheet_compare.png", "play_sheet.png"]
               + ["%s_%s.png" % (v, look) for v in VIEWS_C7 for look in ("placeholder", "styled")])
# `--play-only` (checkpoint7 only): the styled look and the four play-zoom views, for tuning rounds.
EXPECTED_PLAY_ONLY = ["play_sheet.png"] + ["%s_styled.png" % v for v in VIEWS_PLAY]

# 0.4 pass 2b (--set grid): the town grid at play zoom, styled and placeholder pairs.
VIEWS_GRID = ["start_square", "gate_closeup", "taken_block", "taken_block_closeup", "taken_minimap", "rescue_pips", "take_preview",
              "gate_push"]
EXPECTED_GRID = (["contact_sheet.png", "contact_sheet_compare.png"]
                 + ["%s_%s.png" % (v, look) for v in VIEWS_GRID for look in ("placeholder", "styled")])

# 0.4 Style update (--set style04): the styled look caught up with passes 2c and 3 and the Clean HUD, at play zoom.
VIEWS_STYLE04 = ["hud_calm", "banner", "town_unheld", "town_unheld_closeup", "takeable_cells", "cell_tags", "take_preview",
                 "taken_pulse", "bloom_mid", "taken_block", "gate_arch", "defences", "defences_closeup", "lost_cell",
                 "lost_cooling", "break_open", "break_mended", "surge_warning", "surge_radar", "surge_front"]
EXPECTED_STYLE04 = (["contact_sheet.png", "contact_sheet_compare.png"]
                    + ["%s_%s.png" % (v, look) for v in VIEWS_STYLE04 for look in ("placeholder", "styled")])

EXPECTED_R24 = (["overview.png", "contact_sheet.png", "contact_sheet_compare.png", "walk_sheet.png",
                 "fight_sheet.png", "dawn_sheet.png"]
                + ["%s_%s.png" % (v, look) for v in VIEWS_R24 for look in ("placeholder", "styled")])


def main():
    parser = argparse.ArgumentParser(description="Render the checkpoint screenshots in both looks.")
    parser.add_argument("--set", dest="shot_set",
                        choices=("checkpoint2", "round19", "round20", "round24", "checkpoint7", "grid", "style04"),
                        default="checkpoint2")
    parser.add_argument("--out", default=None)
    parser.add_argument("--play-only", action="store_true",
                        help="checkpoint7 only: the styled look and the four play-zoom views (tuning rounds)")
    args = parser.parse_args()
    if args.play_only and args.shot_set != "checkpoint7":
        parser.error("--play-only needs --set checkpoint7")
    if args.out is None:
        folder = {"round19": "checkpoint_03", "round20": "checkpoint_04", "round24": "checkpoint_05",
                       "checkpoint7": "checkpoint_07", "grid": "v0.4-grid", "style04": "v0.4-style"}.get(
            args.shot_set, "checkpoint_02")
        args.out = os.path.join("design", "renders", folder)
    out_abs = os.path.abspath(os.path.join(ROOT, args.out))
    exe = godot_gui()
    if not exe or not os.path.exists(exe):
        print("ERROR: Godot 4.7.2 not found (%s). Set GODOT_GUI or GODOT to the executable." % (exe or "no path"),
              file=sys.stderr)
        return 2
    os.makedirs(out_abs, exist_ok=True)
    env = dict(os.environ, POSITIVEFPS_TEST="1")
    scene = {"round20": "checkpoint_round20.tscn", "round24": "checkpoint_round24.tscn",
             "checkpoint7": "checkpoint_checkpoint7.tscn", "grid": "checkpoint_grid.tscn",
             "style04": "checkpoint_style04.tscn"}.get(
        args.shot_set, "checkpoint_shots.tscn")
    cmd = [exe, "--path", ROOT, "res://tools/checkpoint/" + scene, "--", "--out", out_abs.replace("\\", "/")]
    if args.shot_set in ("round19", "round20", "round24", "checkpoint7", "grid", "style04"):
        cmd += ["--set", args.shot_set]
    if args.play_only:
        cmd += ["--play-only"]
    if args.shot_set in ("round20", "round24", "checkpoint7", "grid", "style04"):
        cmd += ["--timeout", "600"]
    # tools/godot_run.py: hard timeout, output in a log file, ends only the process tree it started.
    log_path = os.path.join(out_abs, "checkpoint_run.log")
    long_run = args.shot_set in ("round20", "round24", "checkpoint7", "grid", "style04")
    result = godot_run(cmd, timeout=650 if long_run else 200, log_path=log_path, env=env)
    print(result.summary())
    if result.timed_out:
        print("ERROR: the screenshot run timed out (log: %s)" % log_path, file=sys.stderr)
        return 2
    for line in result.output().splitlines():
        if line.startswith(("TIMING", "SAVED", "GAPS", "SEALED")) or "ERROR" in line:
            print(line)
    expected = {"round19": EXPECTED_R19, "round20": EXPECTED_R20, "round24": EXPECTED_R24,
                "checkpoint7": EXPECTED_PLAY_ONLY if args.play_only else EXPECTED_C7,
                "grid": EXPECTED_GRID, "style04": EXPECTED_STYLE04}.get(args.shot_set, EXPECTED)
    missing = [name for name in expected if not os.path.exists(os.path.join(out_abs, name))]
    if missing:
        print("ERROR: missing outputs: " + ", ".join(missing), file=sys.stderr)
        return 1
    print("checkpoint shots: OK -> " + out_abs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
