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


if __name__ == "__main__":
    unittest.main()
