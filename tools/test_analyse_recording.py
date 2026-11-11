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
    ev += [{"t": 12.2, "type": "break_open", "gap": 1}, {"t": 14.8, "type": "break_close", "gap": 1, "duration": 2.6},
           {"t": 25.0, "type": "sink", "to": "dimmed", "id": 4}, {"t": 6.0, "type": "target_change", "target": 3},
           {"t": 7.0, "type": "target_change", "target": 4},
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
        self.assertEqual(len(res["threats"]), 2)  # break_open and the dimmed sink; the t=0 sink is ignored
        self.assertAlmostEqual(res["threat_gaps"][0], 12.8)

    def test_bursts_and_burst_clears_are_reported(self):
        res = ar.analyse(synthetic())
        self.assertEqual(len(res["burst_clears"]), 1)
        text = ar.report(res, "x")
        self.assertIn("FIGHTING BACK (round 22): 1 bursts, 2 dimmed people cleared off the border", text)
        self.assertIn("burst at t=17 s lifted 2 dimmed, 5 joy hits", text)

    def test_the_dead_sections_are_gone(self):
        # Events the recorder no longer writes (beacons, zone stretches, gap patches) have no section.
        text = ar.report(ar.analyse(synthetic()), "x")
        for heading in ("SPIRIT BEACONS", "SHAPED ZONE", "PATCH EFFECT", "gap patches"):
            self.assertNotIn(heading, text)

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
                 {"t": 20.0, "type": "break_close", "gap": 2, "duration": 0.21}]
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

    def test_old_gap_event_names_are_read_as_breaks(self):
        # Recordings made before the rename hold gap_open / gap_close; they must analyse the same as break_*.
        old = [{"t": 0.0, "type": "session_start"}, sample(1.0), sample(2.0), sample(3.0),
               {"t": 12.2, "type": "gap_open", "gap": 1},
               {"t": 14.8, "type": "gap_close", "gap": 1, "duration": 2.6},
               {"t": 30.0, "type": "session_end", "outcome": "quit", "reason": "quit", "rescued": 0}]
        with tempfile.TemporaryDirectory() as tmp:
            folder = os.path.join(tmp, "old")
            os.makedirs(folder)
            with open(os.path.join(folder, "events.jsonl"), "w", encoding="utf-8") as fh:
                for e in old:
                    fh.write(json.dumps(e) + "\n")
            loaded = ar.load_events(folder)
            self.assertEqual([e["type"] for e in loaded if e["type"].startswith("break_")],
                             ["break_open", "break_close"])
            self.assertFalse(any(e["type"].startswith("gap_") for e in loaded))
            res = ar.analyse(loaded)
            self.assertEqual(res["gap_durations"], [2.6])
            self.assertEqual(len(res["threats"]), 1)
            table, skipped = ar.compare_recordings([folder], min_seconds=0)
            self.assertEqual(skipped, [])
            opened_row = next(ln for ln in table.splitlines() if ln.startswith("gaps opened"))
            self.assertTrue(opened_row.rstrip().endswith("1"))
            self.assertEqual(ar.cli(["--compare", folder]), 0)

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

    def test_report_has_the_new_sections(self):
        text = ar.report(ar.analyse(synthetic()), "x")
        self.assertIn("PRESSURE CURVE (15 s steps", text)
        self.assertIn("BLOCKS (walls and gates): 0 takes", text)
        self.assertIn("GATES (walls and gates): 0 breaks, 0 holds", text)
        self.assertIn("MARKS (F8): 0", text)

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
            self.assertEqual(rows["takes free/paid"].split()[-1], "0/0")
            self.assertEqual(rows["gate breaks"].split()[-1], "0")
            self.assertIn("1/1", rows["landmarks claimed/lost"])
            self.assertNotIn("beacons", table)
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
            {"t": 58.0, "type": "break_open"},
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


def walls_events():
    """A recording with takes, refusals, pips, ready cells (one taken, one auto-joined, one never) and a screenshot."""
    return [
        {"t": 1.0, "type": "session_start"},
        {"t": 2.0, "type": "pip", "cell": [3, 2], "pips": 1, "night_phase": "calm"},
        {"t": 5.0, "type": "cell_ready", "cell": [4, 2], "pips": 3, "night_phase": "calm"},
        {"t": 7.0, "type": "take_refused", "reason": "spirit_short", "cell": [4, 2], "spirit": 4.0,
         "people_needed": 2, "people_free": 3},
        {"t": 9.0, "type": "take", "cell": [4, 2], "free": False, "spirit_paid": 30.0, "spirit": 20.0,
         "gates_before": 4, "gates_after": 6, "people_needed": 2, "people_free": 3},
        {"t": 9.0, "type": "screenshot", "file": "shot_0001_take.png", "cause": "take"},
        {"t": 12.0, "type": "cell_ready", "cell": [5, 2], "pips": 3, "night_phase": "rising"},
        {"t": 15.0, "type": "auto_join", "cell": [5, 2], "gates_before": 6, "gates_after": 7, "people_needed": 4,
         "people_free": 2, "night_phase": "rising"},
        {"t": 16.0, "type": "take_refused", "reason": "not_next", "cell": [0, 0]},
        {"t": 20.0, "type": "take_refused", "reason": "cancelled", "cell": [1, 1]},
        {"t": 21.0, "type": "take_refused", "reason": "people_short", "cell": [1, 2]},
        {"t": 22.0, "type": "take_refused", "reason": "already_held", "cell": [2, 2]},
        {"t": 25.0, "type": "cell_ready", "cell": [9, 9], "pips": 3, "night_phase": "rising"},
        {"t": 30.0, "type": "session_end", "reason": "quit", "outcome": "quit", "rescued": 3},
    ]


class BlocksTest(unittest.TestCase):
    def test_takes_refusals_ready_cells_and_auto_joins_are_counted(self):
        facts = ar.block_facts(ar.analyse(walls_events()))
        self.assertEqual((len(facts["takes"]), facts["free"], facts["paid"]), (1, 0, 1))
        self.assertAlmostEqual(facts["spirit_paid"], 30.0)
        self.assertEqual(facts["gates_added"], 3)  # the take adds 2 gates, the auto-join 1
        self.assertEqual(facts["refusals"], {"spirit_short": 1, "not_next": 1, "already_held": 1, "cancelled": 1, "people_short": 1})
        self.assertEqual(facts["pips"], 1)
        self.assertEqual(facts["ready_waits"], [4.0, 3.0])  # [4, 2] taken at 9, [5, 2] auto-joined at 15
        self.assertEqual(facts["still_ready"], 1)  # [9, 9] never taken
        self.assertEqual(facts["short"], 1)  # the auto-join needed 4 people with 2 free

    def test_block_lines_list_each_take_and_join_with_its_shot(self):
        text = "\n".join(ar.block_lines(ar.analyse(walls_events())))
        self.assertIn("BLOCKS (walls and gates): 1 takes (0 free, 1 paid, 30 spirit paid), 1 auto-joins, 3 gates added",
                      text)
        self.assertIn("refusals: 5 (spirit_short 1, people_short 1, not_next 1, already_held 1, cancelled 1)", text)
        self.assertIn("ready cells (pips full, not yet joined): 2 waited to be taken: count 2", text)
        self.assertIn("1 still ready at the end", text)
        self.assertIn("take at t=9 s (paid): cell [4, 2], spirit 20.0, gates 4 -> 6, people 2 needed, 3 free  "
                      "shot shot_0001_take.png", text)
        self.assertIn("auto-join at t=15 s: cell [5, 2], gates 6 -> 7, people 4 needed, 2 free", text)
        self.assertIn("takes or auto-joins short of people: 1", text)

    def test_a_free_take_is_counted_as_free(self):
        events = [{"t": 1.0, "type": "take", "cell": [1, 1], "free": True, "spirit_paid": 0.0, "gates_before": 2,
                   "gates_after": 3, "people_needed": 1, "people_free": 1}]
        facts = ar.block_facts(ar.analyse(events))
        self.assertEqual((facts["free"], facts["paid"]), (1, 0))

    def test_an_old_recording_with_none_of_the_events_has_empty_sections(self):
        old = [{"t": 0.0, "type": "session_start"}, {"t": 30.0, "type": "session_end", "outcome": "quit"}]
        text = "\n".join(ar.block_lines(ar.analyse(old)) + ar.gate_lines(ar.analyse(old)) + ar.mark_lines(ar.analyse(old)))
        self.assertIn("BLOCKS (walls and gates): 0 takes (0 free, 0 paid, 0 spirit paid), 0 auto-joins, 0 gates added",
                      text)
        self.assertIn("ready cells (pips full, not yet joined): 0 waited to be taken: none; 0 still ready", text)
        self.assertIn("GATES (walls and gates): 0 breaks, 0 holds", text)
        self.assertIn("MARKS (F8): 0", text)

    def test_compare_has_the_walls_columns(self):
        column = ar.compare_column(ar.analyse(walls_events() + [sample(1.0), sample(2.0)]))
        self.assertEqual(column["takes free/paid"], "0/1")
        self.assertEqual(column["refusals"], "5")
        self.assertEqual(column["ready wait median"], "3.5 s")
        self.assertEqual(column["gate breaks"], "0")


class GatesTest(unittest.TestCase):
    def test_breaks_and_holds_with_their_seconds_pushers_and_phases(self):
        extra = [
            {"t": 10.0, "type": "gate_break", "gate": 1, "seconds": 2.5, "pushers": 3, "night_phase": "rising"},
            {"t": 20.0, "type": "gate_hold", "gate": 2, "seconds": 1.0, "pushers": 2, "night_phase": "calm"},
            {"t": 22.0, "type": "gate_break", "gate": 3, "seconds": 0.5, "pushers": 1, "night_phase": "calm"},
        ]
        res = ar.analyse(sorted(synthetic() + extra, key=lambda e: e["t"]))
        text = "\n".join(ar.gate_lines(res))
        self.assertIn("GATES (walls and gates): 2 breaks, 1 holds (pushes that ended without a break)", text)
        self.assertIn("seconds under push before a break: count 2, median 1.5 s", text)
        self.assertIn("pushers per break: mean 2.0, max 3", text)
        self.assertIn("seconds in holds: count 1, median 1.0 s", text)
        self.assertIn("breaks in calm", text)
        self.assertIn("breaks in rising", text)
        self.assertIn("break of gate 1 at t=10 s after 2.5 s under push, 3 pushers", text)

    def test_gate_breaks_per_minute_use_the_seconds_of_each_phase(self):
        extra = [{"t": 10.0, "type": "gate_break", "gate": 1, "seconds": 2.5, "pushers": 3, "night_phase": "rising"}]
        lines = ar.gate_lines(ar.analyse(sorted(synthetic() + extra, key=lambda e: e["t"])))
        # Samples: 15 s of calm and 15 s of rising in the synthetic recording; one break in rising = 4.00 a minute.
        rising = next(ln for ln in lines if ln.startswith("  breaks in rising"))
        calm = next(ln for ln in lines if ln.startswith("  breaks in calm"))
        self.assertEqual(rising.split(), ["breaks", "in", "rising", "1", "4.00", "/min"])
        self.assertEqual(calm.split(), ["breaks", "in", "calm", "0", "0.00", "/min"])


class DefencesTest(unittest.TestCase):
    def test_plants_refusals_hand_backs_and_bells_are_counted_and_listed(self):
        events = [
            {"t": 20.0, "type": "defence_plant", "gate": 2, "defences": 1, "kind": "Garden"},
            {"t": 30.0, "type": "defence_refused", "reason": "no_member"},
            {"t": 31.0, "type": "defence_refused", "reason": "no_member"},
            {"t": 40.0, "type": "defence_returned", "gate": 2, "reason": "gate_closed"},
            {"t": 50.0, "type": "bell_ring", "gate": 3, "bend": 0.55, "lifted": 4},
        ]
        text = "\n".join(ar.defence_lines(ar.analyse(events)))
        self.assertIn("DEFENCES (walls and gates): 1 planted (Garden 1), 2 refused", text)
        self.assertIn("(no_member 2), 1 handed back, 1 bell rings", text)
        self.assertIn("plant at t=20 s: Garden at gate 2, 1 defences now", text)
        self.assertIn("handed back at t=40 s", text)
        self.assertIn("bell at t=50 s: gate 3, bent 0.55, 4 lifted", text)
        self.assertIn("seconds from the start to the first defence: 20", text)

    def test_an_old_recording_has_an_empty_defences_section(self):
        old = [{"t": 0.0, "type": "session_start"}, {"t": 30.0, "type": "session_end", "outcome": "quit"}]
        text = "\n".join(ar.defence_lines(ar.analyse(old)))
        self.assertIn("DEFENCES (walls and gates): 0 planted (none), 0 refused (none), 0 handed back, 0 bell rings", text)


class MarksTest(unittest.TestCase):
    def test_a_mark_lists_its_time_phase_and_the_events_10_seconds_either_side(self):
        events = sorted(synthetic() + [
            {"t": 10.0, "type": "mark", "n": 1, "night_phase": "rising"},
            {"t": 10.0, "type": "screenshot", "file": "shot_0002_mark.png", "cause": "mark"},
            {"t": 12.2, "type": "screenshot", "file": "shot_0003_break_open.png", "cause": "break_open"},
        ], key=lambda e: e["t"])
        text = "\n".join(ar.mark_lines(ar.analyse(events)))
        self.assertIn("MARKS (F8): 1", text)
        self.assertIn("mark 1 at t=10 s, phase rising (10 s either side: break_close 1, break_open 1, "
                      "burst 1, burst_clear 1, session_start 1, target_change 2)  shot shot_0002_mark.png", text)
        self.assertIn("t=12.2 s  break_open  shot shot_0003_break_open.png", text)
        self.assertNotIn("t=10.0 s  screenshot", text)  # screenshots are shown as shots, not as events
        self.assertNotIn("sample", text)

    def test_events_outside_the_window_are_not_listed(self):
        events = [{"t": 1.0, "type": "take", "cell": [1, 1], "free": False}, {"t": 30.0, "type": "mark", "n": 1}]
        text = "\n".join(ar.mark_lines(ar.analyse(events)))
        self.assertIn("mark 1 at t=30 s, phase ?", text)
        self.assertIn("nothing", text)
        self.assertNotIn("t=1.0 s", text)

    def test_marks_are_in_the_report(self):
        events = synthetic() + [{"t": 10.0, "type": "mark", "n": 1, "night_phase": "rising"}]
        self.assertIn("MARKS (F8): 1", ar.report(ar.analyse(events), "x"))


if __name__ == "__main__":
    unittest.main()
