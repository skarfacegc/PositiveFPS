#!/usr/bin/env python3
"""Self-check of tools/analyse_recording.py on a synthetic recording (no Godot needed). Run:
    python tools/test_analyse_recording.py
"""
import csv
import json
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse_recording as ar  # noqa: E402


def sample(t, gaps=0, pressers=0, dimmed=0, phase="calm"):
    return {"t": t, "type": "sample", "night_phase": phase, "night": t, "gaps": gaps, "pressers": pressers,
            "stages": {"wistful": 10, "gloomy": 5, "dimmed": dimmed, "rescued": 3}, "spirit": 50.0,
            "player_dim": False, "border_open": 30.0, "members": 3, "sheltered": 0, "guarded": 0,
            "joy_landed": 0, "target": -1}


def synthetic():
    ev = [{"t": 0.0, "type": "session_start", "seed": 42, "look": "Placeholder", "targeting_mode": "X", "zoom": 19.5,
           "people": 60},
          {"t": 0.0, "type": "sink", "to": "gloomy", "id": 1}]  # initial state, ignored
    for t in range(1, 31):
        ev.append(sample(float(t), gaps=1 if 12 <= t <= 14 else 0, phase="calm" if t <= 15 else "rising"))
    ev += [{"t": 12.2, "type": "gap_open", "gap": 1}, {"t": 14.8, "type": "gap_close", "gap": 1, "duration": 2.6},
           {"t": 25.0, "type": "sink", "to": "dimmed", "id": 4}, {"t": 6.0, "type": "target_change", "target": 3},
           {"t": 7.0, "type": "target_change", "target": 4},
           {"t": 8.0, "type": "beacon_placed", "pos": [10.0, -4.0], "cost": 30.0, "spirit_after": 20.0},
           {"t": 8.0, "type": "zone_stretch", "beacon": [10.0, -4.0], "tip_target": [9.0, -3.5], "max_reach": 31.5},
           {"t": 20.0, "type": "beacon_reached", "pos": [10.0, -4.0]},
           {"t": 20.0, "type": "zone_grow", "tip": [9.0, -3.5], "gain": 41.5, "angle": 0.3, "people": 9, "zone": 210.0},
           {"t": 28.0, "type": "zone_shrink", "lost": 12.0, "people": 7, "zone": 198.0},
           {"t": 16.0, "type": "gap_patched", "pos": [3.0, 4.0], "kind": "gap", "cost": 25.0, "spirit_after": 60.0,
            "gaps_open": 2},
           {"t": 17.0, "type": "burst", "pos": [3.0, 4.0]},
           {"t": 17.0, "type": "burst_clear", "lifted": 2, "joy_hits": 5, "ids": [4, 9], "gaps_open": 1,
            "spirit_after": 30.0},
           {"t": 21.0, "type": "landmark_claimed", "name": "Garden", "held": 1},
           {"t": 26.0, "type": "landmark_lost", "name": "Garden", "held": 0},
           {"t": 29.9, "type": "win", "title": "Dawn", "rescued": 9, "lights": 2, "people_share": 0.52,
            "ground_share": 0.31, "landmarks_held": 1},
           {"t": 30.0, "type": "session_end", "outcome": "win",
                                                             "reason": "win", "rescued": 9}]
    return sorted(ev, key=lambda e: e["t"])


class AnalyseTest(unittest.TestCase):
    def test_quiet_time_gaps_and_cadence(self):
        res = ar.analyse(synthetic(), quiet_window=5.0)
        rows = {int(r["t"]): r for r in res["rows"]}
        self.assertEqual(rows[13]["quiet"], 0)  # a gap is open
        self.assertEqual(rows[5]["quiet"], 1)
        self.assertEqual(rows[22]["quiet"], 0)  # a dimmed sink at 25 is within 5 s
        self.assertEqual(rows[19]["quiet"], 1)
        self.assertEqual(res["gap_durations"], [2.6])
        self.assertEqual(res["target_changes"], 2)
        self.assertEqual(len(res["threats"]), 2)  # gap_open and the dimmed sink; the t=0 sink is ignored
        self.assertAlmostEqual(res["threat_gaps"][0], 12.8)

    def test_beacons_are_counted_and_reported(self):
        res = ar.analyse(synthetic())
        self.assertEqual(len(res["beacons_placed"]), 1)
        self.assertEqual(len(res["beacons_reached"]), 1)
        text = ar.report(res, "x")
        self.assertIn("SPIRIT BEACONS: 1 placed (30 spirit spent), 1 reached", text)

    def test_patches_and_burst_clears_are_reported(self):
        res = ar.analyse(synthetic())
        self.assertEqual(len(res["patches"]), 1)
        self.assertEqual(len(res["burst_clears"]), 1)
        text = ar.report(res, "x")
        self.assertIn("FIGHTING BACK (round 22): 1 gap patches (25 spirit), 1 bursts, 2 dimmed people cleared", text)
        self.assertIn("patch at t=16 s (gap)", text)
        self.assertIn("burst at t=17 s lifted 2 dimmed, 5 joy hits", text)

    def test_the_stretching_zone_is_reported(self):
        res = ar.analyse(synthetic())
        self.assertEqual(len(res["stretches"]), 1)
        self.assertEqual(len(res["grows"]), 1)
        self.assertEqual(len(res["shrinks"]), 1)
        text = ar.report(res, "x")
        self.assertIn("SHAPED ZONE: 1 stretches, 1 arms kept (+42 sq m), 1 pull-ins (-12 sq m)", text)
        self.assertIn("max reach 31.5 m", text)
        self.assertIn("zone_grow at t=20 s", text)
        self.assertIn("zone_shrink at t=28 s", text)

    def test_landmarks_and_the_dawn_rating_are_reported(self):
        res = ar.analyse(synthetic())
        self.assertEqual([e["type"] for e in res["landmark_events"]], ["landmark_claimed", "landmark_lost"])
        self.assertEqual(res["win"]["lights"], 2)
        text = ar.report(res, "x")
        self.assertIn("LANDMARKS: 1 claimed, 1 lost", text)
        self.assertIn("DAWN RATING: 2 of 3 dawn lights (people 52%, ground 31%, landmarks held 1)", text)

    def test_wobbles_saves_and_first_light_are_counted_and_reported(self):
        extra = [{"t": 10.0, "type": "wobble", "id": 1, "seconds": 5.0},
                 {"t": 11.0, "type": "wobble", "id": 2, "seconds": 4.5},
                 {"t": 12.0, "type": "save", "id": 1},
                 {"t": 16.0, "type": "relapse", "id": 2},
                 {"t": 24.0, "type": "first_light_start", "rescued": 9, "dimmed": 3},
                 {"t": 29.0, "type": "first_light_end", "people_lifted": 6, "stages_lifted": 8, "rescued": 12}]
        res = ar.analyse(sorted(synthetic() + extra, key=lambda e: e["t"]))
        self.assertEqual((len(res["wobbles"]), len(res["saves"])), (2, 1))
        self.assertEqual((len(res["first_light_starts"]), len(res["first_light_ends"])), (1, 1))
        text = ar.report(res, "x")
        self.assertIn("WOBBLES (round 24): 2 wobbles, 1 saved by a joy hit, 1 relapses", text)
        self.assertIn("FIRST LIGHT (round 24): 1 started, 1 finished", text)
        self.assertIn("start at t=24 s, 9 rescued, 3 dimmed", text)
        self.assertIn("end at t=29 s, 6 people lifted, 8 stages lifted, 12 rescued", text)
        plain = ar.analyse(synthetic())
        self.assertEqual((len(plain["wobbles"]), len(plain["saves"]), len(plain["first_light_starts"])), (0, 0, 0))
        self.assertIn("WOBBLES (round 24): 0 wobbles, 0 saved by a joy hit, 0 relapses", ar.report(plain, "x"))

    def test_spare_spirit_gifts_and_gap_blinks_are_counted(self):
        extra = [{"t": 10.0, "type": "spirit_warm", "id": 1, "joy": 40.0, "amount": 1.6, "pool": 8.4},
                 {"t": 10.5, "type": "spirit_warm", "id": 2, "joy": 40.0, "amount": 1.6, "pool": 6.8},
                 {"t": 11.0, "type": "spirit_warm", "id": 1, "joy": 20.0, "amount": 0.8, "pool": 6.0},
                 {"t": 20.0, "type": "gap_close", "gap": 2, "duration": 0.21}]
        res = ar.analyse(sorted(synthetic() + extra, key=lambda e: e["t"]))
        self.assertEqual(len(res["warms"]), 3)
        text = ar.report(res, "x")
        self.assertIn("SPARE SPIRIT (checkpoint 5): 3 gifts to 2 people, 4 spirit as 100 joy", text)
        self.assertIn("GAP BLINKS (checkpoint 5): 1 gaps that closed within half a second", text)
        plain = ar.report(ar.analyse(synthetic()), "x")
        self.assertIn("SPARE SPIRIT (checkpoint 5): 0 gifts to 0 people, 0 spirit as 0 joy", plain)

    def test_report_and_csv(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "events.jsonl"), "w", encoding="utf-8") as fh:
                for e in synthetic():
                    fh.write(json.dumps(e) + "\n")
                fh.write('{"t": 31.0, "type": "sam')  # a line cut off by a crash is skipped
            self.assertEqual(ar.main([tmp]), 0)
            with open(os.path.join(tmp, "timeline.csv"), encoding="utf-8") as fh:
                rows = list(csv.DictReader(fh))
            self.assertEqual(len(rows), 30)
            self.assertIn("quiet", rows[0])

    def test_empty_recording_is_an_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "events.jsonl"), "w", encoding="utf-8") as fh:
                fh.write("")
            self.assertEqual(ar.main([tmp]), 2)


class Round23Test(unittest.TestCase):
    def test_pressure_curve_in_15_second_steps(self):
        events = synthetic() + [{"t": 3.0, "type": "relapse", "id": 2}, {"t": 18.0, "type": "relapse", "id": 3}]
        curve = ar.pressure_curve(ar.analyse(sorted(events, key=lambda e: e["t"])))
        self.assertEqual([c["t"] for c in curve], [0.0, 15.0, 30.0])
        self.assertEqual([c["relapses"] for c in curve], [1, 1, 0])
        self.assertEqual(curve[0]["phase"], "calm")
        self.assertEqual(curve[2]["phase"], "rising")
        self.assertAlmostEqual(curve[0]["gaps"], 3 / 14, places=3)  # samples 1..14 (t=0 has no sample); 3 with a gap
        self.assertEqual(curve[1]["rescued"], 3)

    def test_patch_effect_gaps_fell_rose_and_unknown(self):
        events = synthetic()  # one patch at t=16 with 2 gaps open; the later samples show none
        res = ar.analyse(events)
        effect = ar.patch_effects(res)[0]
        self.assertEqual((effect["kind"], effect["gaps_open"], effect["later"], effect["verdict"]),
                         ("gap", 2, [0, None], "fell"))  # the recording ends before 36 s
        late = [e for e in events if not (e["type"] == "sample" and e["t"] >= 24)] + [sample(26.0, gaps=3)]
        self.assertEqual(ar.patch_effects(ar.analyse(late))[0]["verdict"], "rose")
        early = events + [{"t": 29.5, "type": "gap_patched", "kind": "strain", "gaps_open": 0}]
        last = ar.patch_effects(ar.analyse(sorted(early, key=lambda e: e["t"])))[-1]
        self.assertEqual((last["kind"], last["later"][1], last["verdict"]), ("strain", None, "unknown"))
        nothing = [e for e in events if e["type"] != "gap_patched"]
        self.assertEqual(ar.patch_effect_lines(ar.analyse(nothing)), [])

    def test_report_has_the_new_sections(self):
        text = ar.report(ar.analyse(synthetic()), "x")
        self.assertIn("PATCH EFFECT", text)
        self.assertIn("gaps fell after 1 of 1 patches", text)
        self.assertIn("PRESSURE CURVE (15 s steps", text)

    def test_a_restart_is_left_out_unless_asked(self):
        short = [{"t": 0.0, "type": "session_start"}, sample(1.0), sample(2.0),
                 {"t": 3.0, "type": "session_end", "outcome": "quit", "reason": "quit", "rescued": 0}]
        with tempfile.TemporaryDirectory() as tmp:
            folder = os.path.join(tmp, "r")
            os.makedirs(folder)
            with open(os.path.join(folder, "events.jsonl"), "w", encoding="utf-8") as fh:
                for e in short:
                    fh.write(json.dumps(e) + chr(10))
            csv_path = os.path.join(tmp, "t.csv")
            self.assertEqual(ar.main([folder, "--csv", csv_path]), 0)
            self.assertFalse(os.path.exists(csv_path))
            self.assertEqual(ar.main([folder, "--csv", csv_path, "--include-restarts"]), 0)
            self.assertTrue(os.path.exists(csv_path))


class CompareTest(unittest.TestCase):
    def write(self, tmp, name, events):
        folder = os.path.join(tmp, name)
        os.makedirs(folder)
        with open(os.path.join(folder, "events.jsonl"), "w", encoding="utf-8") as fh:
            for e in events:
                fh.write(json.dumps(e) + "\n")
        return folder

    def test_two_recordings_side_by_side_and_restarts_skipped(self):
        short = [{"t": 0.0, "type": "session_start"}, sample(1.0), sample(2.0),
                 {"t": 3.0, "type": "session_end", "outcome": "quit", "reason": "quit", "rescued": 0}]
        with tempfile.TemporaryDirectory() as tmp:
            a = self.write(tmp, "20261031-100000", synthetic())
            restart = self.write(tmp, "20261031-101000", short)
            b = self.write(tmp, "20261031-102000", synthetic())
            table, skipped = ar.compare_recordings([a, restart, b])
            self.assertEqual(len(skipped), 1)
            self.assertIn("20261031-101000", skipped[0])
            lines = table.splitlines()
            self.assertIn("20261031-100000", lines[0])
            self.assertIn("20261031-102000", lines[0])
            self.assertNotIn("20261031-101000", table)
            rows = {ln.split("  ")[0].strip(): ln for ln in lines[1:]}
            self.assertIn("win", rows["outcome"])
            self.assertIn("0:30", rows["length"])
            self.assertIn("calm 1, rising 0", rows["gaps by phase"])
            self.assertIn("1/1", rows["beacons placed/reached"])
            self.assertIn("1/1", rows["landmarks claimed/lost"])
            self.assertIn("relapses", table)

    def test_compare_cli_and_all_restarts(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = self.write(tmp, "r1", synthetic())
            self.assertEqual(ar.cli(["--compare", a]), 0)
            only_short = self.write(tmp, "r2", [{"t": 0.0, "type": "session_start"}, sample(1.0)])
            self.assertEqual(ar.cli(["--compare", only_short]), 2)
            self.assertEqual(ar.cli(["--compare", os.path.join(tmp, "missing")]), 2)


class TidesTest(unittest.TestCase):
    """Round 25: the TIDES section (its own events only)."""

    def test_each_tide_reports_its_side_members_and_what_happened_in_it(self):
        events = [
            {"t": 1.0, "type": "session_start"},
            {"t": 40.0, "type": "tide_warn", "side": "north", "angle": -1.57},
            {"t": 55.0, "type": "tide_start", "side": "north", "angle": -1.57, "members": 4},
            {"t": 57.0, "type": "wobble"},
            {"t": 58.0, "type": "gap_open"},
            {"t": 59.0, "type": "relapse"},
            {"t": 67.0, "type": "tide_end", "side": "north", "angle": -1.57, "members": 3},
            {"t": 80.0, "type": "wobble"},
            {"t": 95.0, "type": "tide_start", "side": "west", "angle": 3.1, "members": 2},
            {"t": 97.0, "type": "relapse"},
            {"t": 98.0, "type": "relapse"},
            {"t": 120.0, "type": "tide_end", "side": "west", "angle": 3.1, "members": 0},
            {"t": 130.0, "type": "session_end", "reason": "win"},
        ]
        res = ar.analyse(events)
        lines = ar.tide_lines(res)
        self.assertEqual(lines[0], "TIDES (round 25): 2 tides started, 1 warnings")
        self.assertIn("tide at t=55 s from the north, 4 members on that side: 1 wobbles, 1 relapses, 1 gaps opened",
                      lines[1])
        self.assertIn("tide at t=95 s from the west, 2 members on that side: 0 wobbles, 2 relapses, 0 gaps opened",
                      lines[2])

    def test_no_tides_is_a_zero_line_and_a_tide_still_running_ends_at_the_recording(self):
        res = ar.analyse([{"t": 1.0, "type": "session_start"}, {"t": 30.0, "type": "sample", "stages": {}}])
        self.assertEqual(ar.tide_lines(res), ["TIDES (round 25): 0 tides started, 0 warnings"])
        res = ar.analyse([
            {"t": 1.0, "type": "session_start"},
            {"t": 60.0, "type": "tide_start", "side": "east", "angle": 0.0, "members": 1},
            {"t": 75.0, "type": "wobble"},
            {"t": 90.0, "type": "session_end", "reason": "quit"},
        ])
        lines = ar.tide_lines(res)
        self.assertIn("1 wobbles, 0 relapses, 0 gaps opened", lines[1])


if __name__ == "__main__":
    unittest.main()
