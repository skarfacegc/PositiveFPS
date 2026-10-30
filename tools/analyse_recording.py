#!/usr/bin/env python3
"""Summarises a PositiveFPS gameplay recording (round 18) and writes timeline.csv.

Usage:
    python tools/analyse_recording.py recordings/20261028-184243
    python tools/analyse_recording.py <session folder> --csv other/path/timeline.csv
    python tools/analyse_recording.py <session folder> --quiet-window 5

The folder holds events.jsonl (see scripts/recorder.gd). Python standard library only.

Definitions
- Samples come once a second. A sample second is QUIET when ALL of these hold:
    * no open gap in the border,
    * no dimmed person pressing on the border (the sample's `pressers` is 0),
    * the player is not dim,
    * no grab landed within the last second,
    * nothing sank to gloomy or dimmed within `--quiet-window` seconds either side (default 5).
  "Quiet (dimmed only)" is the same, but only sinks to DIMMED count, because wistful people drift to gloomy all the time.
- Sinks that happen in the first 0.5 s are the starting state, not events, and are ignored.
- THREAT events are: sink to dimmed, gap_open, grab, player_dim (going dim) and relapse. Threat cadence is the number of
  them per minute, by type, and the gaps (seconds) between one threat and the next.
- Decision density is target_change events per minute (the player choosing someone new to help).
- Gap durations come from gap_close events (a gap still open at the end is closed with the time so far).
Exit code: 0 on success, 2 when the folder has no usable events.
"""
import argparse
import csv
import json
import os
import statistics
import sys

THREAT_TYPES = ("sink_dimmed", "gap_open", "grab", "player_dim", "relapse")
STAGES = ("wistful", "gloomy", "dimmed", "rescued")
INITIAL_SECONDS = 0.5


def load_events(folder):
    """Reads events.jsonl, skipping blank or damaged lines (a crash can cut the last line)."""
    path = os.path.join(folder, "events.jsonl")
    events = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except ValueError:
                continue
    return events


def kind_of(event):
    """The analysis kind of an event: sinks to dimmed are split from other sinks."""
    if event["type"] == "sink":
        return "sink_dimmed" if event.get("to") == "dimmed" else "sink_other"
    if event["type"] == "player_dim":
        return "player_dim" if event.get("dim") else "player_recover"
    return event["type"]


def per_minute(count, seconds):
    return count * 60.0 / seconds if seconds > 0 else 0.0


def pct(part, whole):
    return 100.0 * part / whole if whole else 0.0


def stats_line(values):
    if not values:
        return "none"
    return "count %d, median %.1f s, mean %.1f s, p90 %.1f s, max %.1f s" % (
        len(values), statistics.median(values), statistics.fmean(values),
        sorted(values)[min(len(values) - 1, int(0.9 * len(values)))], max(values))


def analyse(events, quiet_window=5.0):
    """Returns a dict of results (and the per-second rows used for the CSV)."""
    events = [e for e in events if "type" in e and "t" in e]
    real = [e for e in events if not (e["type"] in ("sink", "lift") and e["t"] < INITIAL_SECONDS)]
    start = next((e for e in events if e["type"] == "session_start"), {})
    end = next((e for e in reversed(events) if e["type"] == "session_end"), None)
    samples = [e for e in events if e["type"] == "sample"]
    duration = end["t"] if end else (events[-1]["t"] if events else 0.0)

    sinks_any = sorted(e["t"] for e in real if e["type"] == "sink")
    sinks_dim = sorted(e["t"] for e in real if e["type"] == "sink" and e.get("to") == "dimmed")
    grabs = sorted(e["t"] for e in real if e["type"] == "grab")

    def near(times, t, window):
        return any(abs(x - t) <= window for x in times)

    rows = []
    for s in samples:
        t = s["t"]
        calm = s.get("gaps", 0) == 0 and s.get("pressers", 0) == 0 and not s.get("player_dim", False)
        calm = calm and not any(0.0 <= t - g <= 1.0 for g in grabs)
        rows.append({
            "t": t, "night_phase": s.get("night_phase", ""), "night": s.get("night", 0.0),
            "wistful": s["stages"].get("wistful", 0), "gloomy": s["stages"].get("gloomy", 0),
            "dimmed": s["stages"].get("dimmed", 0), "rescued": s["stages"].get("rescued", 0),
            "gaps": s.get("gaps", 0), "border_open": s.get("border_open", 0), "members": s.get("members", 0),
            "pressers": s.get("pressers", 0), "sheltered": s.get("sheltered", 0), "guarded": s.get("guarded", 0),
            "spirit": s.get("spirit", 0), "player_dim": int(bool(s.get("player_dim", False))),
            "joy_landed": s.get("joy_landed", 0), "target": s.get("target", -1),
            "quiet": int(calm and not near(sinks_any, t, quiet_window)),
            "quiet_dimmed_only": int(calm and not near(sinks_dim, t, quiet_window)),
        })

    # Events counted into the second they happened in (the sample row whose t is the next whole second up).
    kinds = ("sink_dimmed", "sink_other", "lift", "rescue", "relapse", "gap_open", "gap_close", "grab", "grab_avoided",
             "umbrella_pop", "guarded_glance", "shelter_block", "burst", "target_change", "player_dim")
    for row in rows:
        for k in kinds:
            row["n_" + k] = 0
    by_second = {}
    for row in rows:
        by_second[int(row["t"])] = row
    for e in real:
        k = kind_of(e)
        row = by_second.get(int(e["t"]))
        if row is not None and ("n_" + k) in row:
            row["n_" + k] += 1

    threats = sorted((e["t"], kind_of(e)) for e in real if kind_of(e) in THREAT_TYPES)
    threat_gaps = [b[0] - a[0] for a, b in zip(threats, threats[1:])]
    counts = {}
    for e in real:
        counts[kind_of(e)] = counts.get(kind_of(e), 0) + 1
    gap_durations = [e["duration"] for e in real if e["type"] == "gap_close"]
    return {
        "start": start, "end": end, "duration": duration, "samples": samples, "rows": rows, "counts": counts,
        "threats": threats, "threat_gaps": threat_gaps, "gap_durations": gap_durations,
        "target_changes": counts.get("target_change", 0),
        "beacons_placed": [e for e in real if e["type"] == "beacon_placed"],
        "beacons_reached": [e for e in real if e["type"] == "beacon_reached"],
        "stretches": [e for e in real if e["type"] == "zone_stretch"],
        "snaps": [e for e in real if e["type"] == "zone_snap"],
        "landmark_events": [e for e in real if e["type"] in ("landmark_claimed", "landmark_lost")],
        "win": next((e for e in real if e["type"] == "win"), None),
    }


def phases(rows):
    """Row groups per night phase, in order of first appearance."""
    out = {}
    for r in rows:
        out.setdefault(r["night_phase"], []).append(r)
    return out


def report(res, folder):
    lines = []
    add = lines.append
    start, end, rows = res["start"], res["end"], res["rows"]
    dur = res["duration"]
    add("Recording: %s" % folder)
    add("Duration: %.0f s (%d:%02d)   Outcome: %s%s" % (
        dur, dur // 60, dur % 60, end.get("outcome", "?") if end else "unknown (no session_end: crash or cut off)",
        (" (%s)" % end["reason"]) if end and end.get("reason") not in (None, end.get("outcome")) else ""))
    if start:
        add("Setup: seed %s, look %s, targeting %s, zoom %s, %s people" % (
            start.get("seed"), start.get("look"), start.get("targeting_mode"), start.get("zoom"), start.get("people")))
    if end:
        add("People rescued at the end: %s" % end.get("rescued"))
    add("")
    n = len(rows)
    quiet = sum(r["quiet"] for r in rows)
    quiet_dim = sum(r["quiet_dimmed_only"] for r in rows)
    add("QUIET TIME (no open gap, no presser, player not dim, no grab, no sink within the window)")
    add("  strict (any sink counts):   %5.1f %%  (%d of %d s)" % (pct(quiet, n), quiet, n))
    add("  relaxed (dimmed sinks only): %4.1f %%  (%d of %d s)" % (pct(quiet_dim, n), quiet_dim, n))
    run, longest, longest_at = 0, 0, 0.0
    for r in rows:
        run = run + 1 if r["quiet"] else 0
        if run > longest:
            longest, longest_at = run, r["t"]
    add("  longest quiet stretch (strict): %d s%s" % (longest, (" (ending at t=%.0f)" % longest_at) if longest else ""))
    add("")
    add("TIMELINE BY NIGHT PHASE")
    add("  %-9s %5s %7s %8s %6s %6s %7s %8s %8s %7s" % (
        "phase", "secs", "quiet%", "threats", "gaps", "grabs", "rescues", "retargets", "spirit", "dimmed"))
    for name, group in phases(rows).items():
        a, b = group[0]["t"], group[-1]["t"] + 1.0
        in_phase = [x for x in res["threats"] if a <= x[0] < b]
        add("  %-9s %5d %6.1f%% %8d %6d %6d %7d %8d %8.1f %7.1f" % (
            name, len(group), pct(sum(r["quiet"] for r in group), len(group)), len(in_phase),
            sum(r["n_gap_open"] for r in group), sum(r["n_grab"] for r in group), sum(r["n_rescue"] for r in group),
            sum(r["n_target_change"] for r in group), statistics.fmean(r["spirit"] for r in group),
            statistics.fmean(r["dimmed"] for r in group)))
    add("")
    add("THREAT CADENCE (events per minute over %.0f s)" % dur)
    for k in ("sink_other", "sink_dimmed", "gap_open", "grab", "player_dim", "relapse", "rescue", "umbrella_pop",
              "guarded_glance", "burst"):
        c = res["counts"].get(k, 0)
        add("  %-15s %4d total  %5.2f /min" % (k, c, per_minute(c, dur)))
    add("  all threats (%s): %d, %.2f /min" % (", ".join(THREAT_TYPES), len(res["threats"]),
                                              per_minute(len(res["threats"]), dur)))
    add("  seconds between consecutive threats: %s" % stats_line(res["threat_gaps"]))
    add("")
    add("GAP OPEN DURATIONS: %s" % stats_line(res["gap_durations"]))
    add("DECISION DENSITY: %d target changes, %.1f /min" % (res["target_changes"],
                                                            per_minute(res["target_changes"], dur)))
    for name, group in phases(rows).items():
        c = sum(r["n_target_change"] for r in group)
        add("  %-9s %5.1f /min" % (name, per_minute(c, len(group))))
    add("")
    placed, reached = res["beacons_placed"], res["beacons_reached"]
    spent = sum(e.get("cost", 0) for e in placed)
    add("SPIRIT BEACONS: %d placed (%.0f spirit spent), %d reached by the centre" % (len(placed), spent, len(reached)))
    for e in placed:
        add("  placed at t=%.0f s, pos %s, spirit left %s" % (e["t"], e.get("pos"), e.get("spirit_after")))
    for e in reached:
        add("  tip arrived at t=%.0f s, tip %s" % (e["t"], e.get("pos")))
    stretches, snaps = res["stretches"], res["snaps"]
    add("STRETCHING ZONE: %d stretches, %d snaps back to a circle" % (len(stretches), len(snaps)))
    for e in stretches:
        add("  stretch at t=%.0f s toward %s, tip aimed at %s, max reach %s m" % (
            e["t"], e.get("beacon"), e.get("tip_target"), e.get("max_reach")))
    for e in snaps:
        add("  snap at t=%.0f s, centre %s -> %s (%s rescued)" % (e["t"], e.get("from"), e.get("to"), e.get("people")))
    add("")
    lm_events = res["landmark_events"]
    claims = sum(1 for e in lm_events if e["type"] == "landmark_claimed")
    add("LANDMARKS: %d claimed, %d lost" % (claims, len(lm_events) - claims))
    for e in lm_events:
        add("  t=%.0f s  %s %s (%s held)" % (e["t"], e.get("name"), e["type"].split("_")[1], e.get("held")))
    win = res["win"]
    if win:
        add("DAWN RATING: %s of 3 dawn lights (people %.0f%%, ground %.0f%%, landmarks held %s)" % (
            win.get("lights", "?"), 100.0 * win.get("people_share", 0.0), 100.0 * win.get("ground_share", 0.0),
            win.get("landmarks_held", "?")))
    add("")
    add("STAGE COUNTS OVER TIME (mean per 30 s)")
    add("  %6s %8s %7s %7s %8s %5s %9s" % ("t", "wistful", "gloomy", "dimmed", "rescued", "gaps", "pressers"))
    for i in range(0, n, 30):
        chunk = rows[i:i + 30]
        m = lambda key: statistics.fmean(r[key] for r in chunk)  # noqa: E731
        add("  %6.0f %8.1f %7.1f %7.1f %8.1f %5.1f %9.1f" % (
            chunk[0]["t"], m("wistful"), m("gloomy"), m("dimmed"), m("rescued"), m("gaps"), m("pressers")))
    return "\n".join(lines)


def write_csv(rows, path):
    if not rows:
        return
    with open(path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Summarise a PositiveFPS gameplay recording.")
    parser.add_argument("folder", help="a session folder holding events.jsonl")
    parser.add_argument("--csv", help="where to write the timeline (default: <folder>/timeline.csv)")
    parser.add_argument("--quiet-window", type=float, default=5.0, help="seconds either side of a sink that are not quiet")
    args = parser.parse_args(argv)
    try:
        events = load_events(args.folder)
    except OSError as err:
        print("ERROR: cannot read events.jsonl: %s" % err, file=sys.stderr)
        return 2
    res = analyse(events, args.quiet_window)
    if not res["rows"]:
        print("ERROR: no samples in the recording", file=sys.stderr)
        return 2
    print(report(res, args.folder))
    csv_path = args.csv or os.path.join(args.folder, "timeline.csv")
    write_csv(res["rows"], csv_path)
    print("\nWrote %s" % csv_path)
    return 0


if __name__ == "__main__":
    sys.exit(main())
