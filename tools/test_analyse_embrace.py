#!/usr/bin/env python3
"""Round 25 part S: the EMBRACE line of tools/analyse_recording.py (no Godot needed). Run:
    python tools/test_analyse_embrace.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyse_recording as ar  # noqa: E402


def base():
    ev = [{"t": 0.0, "type": "session_start", "seed": 42, "look": "Placeholder", "targeting_mode": "X", "zoom": 19.5,
           "people": 60}]
    for t in range(1, 41):
        ev.append({"t": float(t), "type": "sample", "night_phase": "calm", "night": float(t), "gaps": 0, "pressers": 0,
                   "stages": {"wistful": 10, "gloomy": 5, "dimmed": 1, "rescued": 3}, "spirit": 50.0,
                   "player_dim": False, "border_open": 30.0, "members": 3, "sheltered": 0, "guarded": 0,
                   "joy_landed": 0, "target": -1})
    ev.append({"t": 40.0, "type": "session_end", "outcome": "win", "reason": "win", "rescued": 4})
    return ev


class EmbraceLineTest(unittest.TestCase):
    def test_counts_lifts_rescues_and_mean_time(self):
        extra = [{"t": 5.0, "type": "embrace_start", "id": 1, "stage": "dimmed"},
                 {"t": 13.0, "type": "embrace_lift", "id": 1, "from": "dimmed", "to": "gloomy"},
                 {"t": 21.0, "type": "embrace_lift", "id": 1, "from": "gloomy", "to": "wistful"},
                 {"t": 29.0, "type": "embrace_rescue", "id": 1, "seconds": 24.0},
                 {"t": 30.0, "type": "embrace_start", "id": 2, "stage": "wistful"},
                 {"t": 38.0, "type": "embrace_rescue", "id": 2, "seconds": 8.0}]
        res = ar.analyse(sorted(base() + extra, key=lambda e: e["t"]))
        self.assertEqual(len(res["embrace_events"]), 6)
        text = ar.report(res, "x")
        self.assertIn("EMBRACE (round 25): 2 begun, 2 stage lifts, 2 rescues, mean time to rescue 16.0 s", text)

    def test_no_embrace_is_a_zero_line(self):
        text = ar.report(ar.analyse(base()), "x")
        self.assertIn("EMBRACE (round 25): 0 begun, 0 stage lifts, 0 rescues, mean time to rescue n/a", text)


if __name__ == "__main__":
    unittest.main()
