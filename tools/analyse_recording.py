#!/usr/bin/env python3
"""Summarises a PositiveFPS gameplay recording (round 18) and writes timeline.csv.

Usage:
    python tools/analyse_recording.py recordings/20261028-184243
    python tools/analyse_recording.py <session folder> --csv other/path/timeline.csv
    python tools/analyse_recording.py <session folder> --quiet-window 5
    python tools/analyse_recording.py <session folder> --include-restarts   # a recording under 10 s is skipped otherwise
    python tools/analyse_recording.py --compare recordings/A recordings/B [...]   # side by side; restarts under 10 s skipped

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
- THREAT events are: sink to dimmed, break_open, grab, player_dim (going dim) and relapse. Threat cadence is the number of
  them per minute, by type, and the gaps (seconds) between one threat and the next.
- Decision density is target_change events per minute (the player choosing someone new to help).
- Break durations come from break_close events (a gap still open at the end is closed with the time so far).
- PRESSURE CURVE (15 s steps: mean dimmed, gaps and pressers, relapses and threats in the step, rescued at its end).
- BLOCKS (walls and gates, #59): takes (free against paid, the spirit at each take, the gates before and after, the people
  needed against the people free), refusals by reason, the time between takes, ready cells (pips full, not yet taken)
  and how long each waited, auto-joins, and takes or auto-joins with too few people.
- GATES (#59): gate breaks and holds, seconds under push before a break, pushers per break, breaks per minute by phase.
- MARKS (#60): each mark (F8) with its time, phase and the events 10 s either side, counted by type.
- A screenshot is listed beside the event that asked for it (#61; the `screenshot` event's `cause`).
- Event types the recorder no longer writes (zone stretches, beacons, gap patches) are not read. A recording without an
  event type shows an empty section for it.
Exit code: 0 on success, 2 when the folder has no usable events.
"""
import argparse
import csv
import json
import os
import statistics
import sys

THREAT_TYPES = ("sink_dimmed", "break_open", "grab", "player_dim", "relapse")
STAGES = ("wistful", "gloomy", "dimmed", "rescued")
INITIAL_SECONDS = 0.5
# Recordings made before the rename used the old names for breaks (gap_open / gap_close); they are read as the new names.
OLD_EVENT_NAMES = {"gap_open": "break_open", "gap_close": "break_close"}


def load_events(folder):
    """Reads events.jsonl, skipping blank or damaged lines (a crash can cut the last line).

    Old recordings' gap_open / gap_close events are renamed to break_open / break_close as they are read.
    """
    path = os.path.join(folder, "events.jsonl")
    events = []
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                event = json.loads(line)
            except ValueError:
                continue
            if isinstance(event, dict) and event.get("type") in OLD_EVENT_NAMES:
                event["type"] = OLD_EVENT_NAMES[event["type"]]
            events.append(event)
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
    kinds = ("sink_dimmed", "sink_other", "lift", "rescue", "relapse", "break_open", "break_close", "grab", "grab_avoided",
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
    gap_durations = [e["duration"] for e in real if e["type"] == "break_close"]
    return {
        "start": start, "end": end, "duration": duration, "samples": samples, "rows": rows, "counts": counts,
        "threats": threats, "threat_gaps": threat_gaps, "gap_durations": gap_durations,
        "target_changes": counts.get("target_change", 0),
        "landmark_events": [e for e in real if e["type"] in ("landmark_claimed", "landmark_lost")],
        "bursts": [e for e in real if e["type"] == "burst"],
        "burst_clears": [e for e in real if e["type"] == "burst_clear"],
        "wobbles": [e for e in real if e["type"] == "wobble"],
        "saves": [e for e in real if e["type"] == "save"],
        "warms": [e for e in real if e["type"] == "spirit_warm"],
        "first_light_starts": [e for e in real if e["type"] == "first_light_start"],
        "first_light_ends": [e for e in real if e["type"] == "first_light_end"],
        "win": next((e for e in real if e["type"] == "win"), None),
        "real": real,  # Round 25: the TIDES section reads the events between a tide's start and end.
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
            sum(r["n_break_open"] for r in group), sum(r["n_grab"] for r in group), sum(r["n_rescue"] for r in group),
            sum(r["n_target_change"] for r in group), statistics.fmean(r["spirit"] for r in group),
            statistics.fmean(r["dimmed"] for r in group)))
    add("")
    add("THREAT CADENCE (events per minute over %.0f s)" % dur)
    for k in ("sink_other", "sink_dimmed", "break_open", "grab", "player_dim", "relapse", "rescue", "umbrella_pop",
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
    bursts, clears = res["bursts"], res["burst_clears"]
    add("FIGHTING BACK (round 22): %d bursts, %d dimmed people cleared off the border" % (
        len(bursts), sum(e.get("lifted", 0) for e in clears)))
    for e in clears:
        add("  burst at t=%.0f s lifted %s dimmed, %s joy hits, %s gaps open, spirit left %s" % (
            e["t"], e.get("lifted"), e.get("joy_hits"), e.get("gaps_open"), e.get("spirit_after")))
    wobbles, saves = res["wobbles"], res["saves"]
    add("WOBBLES (round 24): %d wobbles, %d saved by a joy hit, %d relapses" % (
        len(wobbles), len(saves), res["counts"].get("relapse", 0)))
    warms = res["warms"]
    add("SPARE SPIRIT (checkpoint 5): %d gifts to %d people, %.0f spirit as %.0f joy" % (
        len(warms), len({e.get("id") for e in warms}), sum(e.get("amount", 0) for e in warms),
        sum(e.get("joy", 0) for e in warms)))
    blinks = [d for d in res["gap_durations"] if d < 0.5]
    add("GAP BLINKS (checkpoint 5): %d gaps that closed within half a second" % len(blinks))
    starts, ends = res["first_light_starts"], res["first_light_ends"]
    add("FIRST LIGHT (round 24): %d started, %d finished" % (len(starts), len(ends)))
    for e in starts:
        add("  start at t=%.0f s, %s rescued, %s dimmed" % (e["t"], e.get("rescued"), e.get("dimmed")))
    for e in ends:
        add("  end at t=%.0f s, %s people lifted, %s stages lifted, %s rescued" % (
            e["t"], e.get("people_lifted"), e.get("stages_lifted"), e.get("rescued")))
    lm_events = res["landmark_events"]
    claims = sum(1 for e in lm_events if e["type"] == "landmark_claimed")
    add("LANDMARKS: %d claimed, %d lost" % (claims, len(lm_events) - claims))
    for e in lm_events:
        add("  t=%.0f s  %s %s (%s held)" % (e["t"], e.get("name"), e["type"].split("_")[1], e.get("held")))
    for block in pressure_curve_lines(res) + tide_lines(res) + block_lines(res) + gate_lines(res) + mark_lines(res):
        add(block)
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


def tide_lines(res):
    """Round 25: the gloom tides. Each tide's side, the rescued border members on that side when it started, and the
    wobbles, relapses and gaps opened between its start and its end (or the end of the recording)."""
    real = res["real"]
    starts = [e for e in real if e["type"] == "tide_start"]
    ends = [e for e in real if e["type"] == "tide_end"]
    warns = sum(1 for e in real if e["type"] == "tide_warn")
    lines = ["TIDES (round 25): %d tides started, %d warnings" % (len(starts), warns)]
    for s in starts:
        end_t = next((e["t"] for e in ends if e["t"] >= s["t"]), res["duration"])
        during = [e for e in real if s["t"] <= e["t"] <= end_t]
        lines.append("  tide at t=%.0f s from the %s, %s members on that side: %d wobbles, %d relapses, %d gaps opened" % (
            s["t"], s.get("side", "?"), s.get("members", "?"),
            sum(1 for e in during if e["type"] == "wobble"),
            sum(1 for e in during if e["type"] == "relapse"),
            sum(1 for e in during if e["type"] == "break_open")))
    return lines


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
    parser.add_argument("--include-restarts", action="store_true",
                        help="also report a recording shorter than %.0f s (skipped by default as a restart)"
                        % RESTART_SECONDS)
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
    if res["duration"] < RESTART_SECONDS and not args.include_restarts:
        print("NOTE: %s skipped, a restart (%.0f s, under %.0f s). Use --include-restarts to report it." % (
            args.folder, res["duration"], RESTART_SECONDS), file=sys.stderr)
        return 0
    print(report(res, args.folder))
    csv_path = args.csv or os.path.join(args.folder, "timeline.csv")
    write_csv(res["rows"], csv_path)
    print("\nWrote %s" % csv_path)
    return 0


# ---- Round 23: pressure curve and patch effect -----------------------------------------------------------------------
CURVE_STEP = 15.0  # seconds per step of the pressure curve


def pressure_curve(res, step=CURVE_STEP):
    """Pressure in `step` second blocks: a list of dicts (t, dimmed, gaps, pressers, relapses, threats, rescued)."""
    rows = res["rows"]
    if not rows:
        return []
    out = []
    last = rows[-1]["t"]
    t0 = 0.0
    while t0 <= last:
        block = [r for r in rows if t0 <= r["t"] < t0 + step]
        if block:
            threats = [x for x in res["threats"] if t0 <= x[0] < t0 + step]
            out.append({
                "t": t0, "phase": block[0]["night_phase"],
                "dimmed": statistics.fmean(r["dimmed"] for r in block),
                "gaps": statistics.fmean(r["gaps"] for r in block),
                "pressers": statistics.fmean(r["pressers"] for r in block),
                "relapses": sum(1 for x in threats if x[1] == "relapse"),
                "threats": len(threats), "rescued": block[-1]["rescued"],
            })
        t0 += step
    return out


def pressure_curve_lines(res, step=CURVE_STEP):
    curve = pressure_curve(res, step)
    lines = ["", "PRESSURE CURVE (%.0f s steps; dimmed, gaps and pressers are means, relapses and threats are counts)"
             % step,
             "  %6s %-9s %7s %6s %9s %8s %8s %8s" % ("t", "phase", "dimmed", "gaps", "pressers", "relapses",
                                                       "threats", "rescued")]
    for c in curve:
        lines.append("  %6.0f %-9s %7.1f %6.1f %9.1f %8d %8d %8d" % (
            c["t"], c["phase"], c["dimmed"], c["gaps"], c["pressers"], c["relapses"], c["threats"], c["rescued"]))
    lines.append("")
    return lines


# ---- Round 22: round-over-round comparison (python tools/analyse_recording.py --compare A B [C ...]) ----------------
# Kept at the end of the file, in new functions only, so it merges cleanly with the other report sections.
RESTART_SECONDS = 10.0  # a recording shorter than this is a restart (menu start, quit at once) and is skipped


def compare_column(res):
    """The comparison figures of one analysed recording, as {row name: text}."""
    end, rows = res["end"], res["rows"]
    n = len(rows)
    dur = res["duration"]
    by_phase = []
    for name, group in phases(rows).items():
        by_phase.append("%s %d" % (name, sum(r["n_break_open"] for r in group)))
    lm_events = res["landmark_events"]
    claims = sum(1 for e in lm_events if e["type"] == "landmark_claimed")
    win = res["win"]
    facts = block_facts(res)
    waits = facts["ready_waits"]
    return {
        "outcome": end.get("outcome", "?") if end else "no end (cut off)",
        "length": "%d:%02d" % (dur // 60, dur % 60),
        "rescued": str(end.get("rescued", "?")) if end else "?",
        "dawn lights": str(win.get("lights", "?")) if win else "-",
        "quiet % strict": "%.1f" % pct(sum(r["quiet"] for r in rows), n),
        "gaps opened": str(res["counts"].get("break_open", 0)),
        "gaps by phase": ", ".join(by_phase) or "-",
        "relapses": str(res["counts"].get("relapse", 0)),
        "spirit mean": "%.1f" % statistics.fmean(r["spirit"] for r in rows),
        "takes free/paid": "%d/%d" % (facts["free"], facts["paid"]),
        "refusals": str(sum(facts["refusals"].values())),
        "ready wait median": ("%.1f s" % statistics.median(waits)) if waits else "-",
        "gate breaks": str(len(facts["breaks"])),
        "landmarks claimed/lost": "%d/%d" % (claims, len(lm_events) - claims),
    }


def compare_table(columns):
    """columns: [(heading, {row: text})]. Returns the side by side table as text."""
    names = list(columns[0][1].keys())
    widths = [max(len(h), max(len(c[row]) for row in names)) for h, c in columns]
    label_w = max(len(r) for r in names)
    out = ["%-*s  %s" % (label_w, "", "  ".join("%-*s" % (w, h) for w, (h, _c) in zip(widths, columns)))]
    for row in names:
        out.append("%-*s  %s" % (label_w, row, "  ".join("%-*s" % (w, c[row]) for w, (_h, c) in zip(widths, columns))))
    return "\n".join(out)


def compare_recordings(folders, quiet_window=5.0, min_seconds=RESTART_SECONDS):
    """Returns (table text, skipped notes). Recordings with no samples or shorter than min_seconds are skipped."""
    columns, skipped = [], []
    for folder in folders:
        label = os.path.basename(os.path.normpath(folder))
        try:
            res = analyse(load_events(folder), quiet_window)
        except OSError as err:
            skipped.append("%s: cannot read events.jsonl (%s)" % (label, err))
            continue
        if not res["rows"] or res["duration"] < min_seconds:
            skipped.append("%s: skipped, a restart or empty (%.0f s, under %.0f s)" % (label, res["duration"],
                                                                                      min_seconds))
            continue
        columns.append((label, compare_column(res)))
    if not columns:
        return "", skipped
    return compare_table(columns), skipped


def compare_main(argv):
    parser = argparse.ArgumentParser(prog="analyse_recording.py --compare",
                                     description="Compare two or more recordings side by side.")
    parser.add_argument("folders", nargs="+", help="session folders holding events.jsonl, oldest first")
    parser.add_argument("--quiet-window", type=float, default=5.0)
    parser.add_argument("--min-seconds", type=float, default=RESTART_SECONDS,
                        help="recordings shorter than this are restarts and are skipped (default %(default)s)")
    args = parser.parse_args(argv)
    table, skipped = compare_recordings(args.folders, args.quiet_window, args.min_seconds)
    for note in skipped:
        print("NOTE: " + note, file=sys.stderr)
    if not table:
        print("ERROR: no usable recordings to compare", file=sys.stderr)
        return 2
    print(table)
    return 0


# ---- Walls and gates: BLOCKS, GATES and MARKS (#59, #60, #61) --------------------------------------------------------
# Events: take, take_refused, pip, cell_ready, auto_join, gate_break, gate_hold, mark, screenshot (with `cause`).
# Grid fixes: people_short is gone (people never refuse a take) and not_next split into not_next and already_held; old
# recordings still hold people_short and auto_join events, so both are read and shown.
REFUSAL_REASONS = ("spirit_short", "people_short", "not_next", "already_held", "cancelled")
MARK_WINDOW = 10.0  # seconds either side of a mark whose events are listed


def shot_files(real):
    """(cause, t) -> the shot file. A screenshot is written in the same frame as the event that asked for it."""
    return {(e.get("cause"), e["t"]): e.get("file") for e in real if e["type"] == "screenshot"}


def shot_note(shots, e):
    """'  shot <file>' for an event that has a screenshot, else ''."""
    file_name = shots.get((e["type"], e["t"]))
    return "  shot %s" % file_name if file_name else ""


def block_facts(res):
    """The walls-and-gates figures: takes (free, paid, spirit), refusals, pips, ready cells and how long each waited,
    auto-joins, takes and auto-joins short of people, and the gate breaks and holds. Missing events count as none."""
    real = res["real"]
    takes = [e for e in real if e["type"] == "take"]
    joins = [e for e in real if e["type"] == "auto_join"]
    refusals = {}
    for e in real:
        if e["type"] == "take_refused":
            reason = e.get("reason", "?")
            refusals[reason] = refusals.get(reason, 0) + 1
    # A ready cell waits until the next take or auto-join of the same cell (taken in file order); none = still ready.
    waits = []
    still_ready = 0
    for i, e in enumerate(real):
        if e["type"] != "cell_ready":
            continue
        cell = e.get("cell")
        done = next((f for f in real[i + 1:] if f["type"] in ("take", "auto_join") and f.get("cell") == cell), None)
        if done is None:
            still_ready += 1
        else:
            waits.append(done["t"] - e["t"])
    free = sum(1 for e in takes if e.get("free") is True)
    return {
        "takes": takes,
        "joins": joins,
        "free": free,
        "paid": len(takes) - free,
        "spirit_paid": sum(e.get("spirit_paid", 0) for e in takes),
        "gates_added": sum(e.get("gates_after", 0) - e.get("gates_before", 0) for e in takes + joins),
        "take_gaps": [b["t"] - a["t"] for a, b in zip(takes, takes[1:])],
        "refusals": refusals,
        "pips": sum(1 for e in real if e["type"] == "pip"),
        "ready_waits": waits,
        "still_ready": still_ready,
        "short": sum(1 for e in takes + joins if e.get("people_needed", 0) > e.get("people_free", 0)),
        "breaks": [e for e in real if e["type"] == "gate_break"],
        "holds": [e for e in real if e["type"] == "gate_hold"],
    }


def block_lines(res):
    facts = block_facts(res)
    shots = shot_files(res["real"])
    takes, joins = facts["takes"], facts["joins"]
    lines = ["", "BLOCKS (walls and gates): %d takes (%d free, %d paid, %.0f spirit paid), %d auto-joins, %d gates added"
             % (len(takes), facts["free"], facts["paid"], facts["spirit_paid"], len(joins), facts["gates_added"])]
    refused = facts["refusals"]
    others = sorted(r for r in refused if r not in REFUSAL_REASONS)
    lines.append("  refusals: %d (%s)" % (sum(refused.values()), ", ".join(
        "%s %d" % (r, refused.get(r, 0)) for r in list(REFUSAL_REASONS) + others)))
    lines.append("  seconds between takes: %s" % stats_line(facts["take_gaps"]))
    lines.append("  pips filled by rescues: %d" % facts["pips"])
    lines.append("  ready cells (pips full, not yet joined): %d waited to be taken: %s; %d still ready at the end"
                 % (len(facts["ready_waits"]), stats_line(facts["ready_waits"]), facts["still_ready"]))
    lines.append("  takes or auto-joins short of people: %d" % facts["short"])
    for e in takes:
        lines.append("  take at t=%.0f s (%s): cell %s, spirit %s, gates %s -> %s, people %s needed, %s free%s" % (
            e["t"], "free" if e.get("free") else "paid", e.get("cell"), e.get("spirit"), e.get("gates_before"),
            e.get("gates_after"), e.get("people_needed"), e.get("people_free"), shot_note(shots, e)))
    for e in joins:
        lines.append("  auto-join at t=%.0f s: cell %s, gates %s -> %s, people %s needed, %s free%s" % (
            e["t"], e.get("cell"), e.get("gates_before"), e.get("gates_after"), e.get("people_needed"),
            e.get("people_free"), shot_note(shots, e)))
    return lines


def gate_lines(res):
    facts = block_facts(res)
    shots = shot_files(res["real"])
    breaks, holds = facts["breaks"], facts["holds"]
    lines = ["", "GATES (walls and gates): %d breaks, %d holds (pushes that ended without a break)"
             % (len(breaks), len(holds))]
    lines.append("  seconds under push before a break: %s" % stats_line([e["seconds"] for e in breaks if "seconds" in e]))
    pushers = [e["pushers"] for e in breaks if "pushers" in e]
    lines.append("  pushers per break: %s" % (
        "none" if not pushers else "mean %.1f, max %d" % (statistics.fmean(pushers), max(pushers))))
    lines.append("  seconds in holds: %s" % stats_line([e["seconds"] for e in holds if "seconds" in e]))
    for name, group in phases(res["rows"]).items():
        c = sum(1 for e in breaks if e.get("night_phase") == name)
        lines.append("  breaks in %-9s %4d  %5.2f /min" % (name, c, per_minute(c, len(group))))
    for e in breaks:
        lines.append("  break of gate %s at t=%.0f s after %.1f s under push, %s pushers" % (
            e.get("gate"), e["t"], e.get("seconds", 0.0), e.get("pushers", "?")))
    return lines


def mark_lines(res):
    """Each mark (F8): its time, phase, and the events within MARK_WINDOW seconds either side, counted by type and listed."""
    real = res["real"]
    shots = shot_files(real)
    marks = [e for e in real if e["type"] == "mark"]
    lines = ["", "MARKS (F8): %d" % len(marks)]
    for m in marks:
        near = sorted(
            (e for e in real if e is not m and e["type"] not in ("sample", "screenshot")
             and abs(e["t"] - m["t"]) <= MARK_WINDOW),
            key=lambda e: e["t"])
        counts = {}
        for e in near:
            counts[e["type"]] = counts.get(e["type"], 0) + 1
        summary = ", ".join("%s %d" % (k, counts[k]) for k in sorted(counts)) or "nothing"
        lines.append("  mark %s at t=%.0f s, phase %s (%.0f s either side: %s)%s" % (
            m.get("n", "?"), m["t"], m.get("night_phase", "?"), MARK_WINDOW, summary, shot_note(shots, m)))
        for e in near:
            lines.append("    t=%.1f s  %s%s" % (e["t"], e["type"], shot_note(shots, e)))
    return lines


def cli(argv=None):
    """`--compare A B ...` compares recordings; anything else is the single-recording report of main()."""
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] == "--compare":
        return compare_main(argv[1:])
    return main(argv)


if __name__ == "__main__":
    sys.exit(cli())
