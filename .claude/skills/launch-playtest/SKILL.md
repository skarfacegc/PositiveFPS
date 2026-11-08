---
name: launch-playtest
description: Launch a PositiveFPS playtest from a clean detached copy of the committed round with recording on, confirm it started, and analyse the new recordings afterwards. Use at step 1 of the round loop or when the user asks to play the latest round.
---

# Launch a playtest

The round loop (CLAUDE.md) says: launch the committed round from a clean detached worktree in the scratchpad, never
from the live repo. Do this from the main session or one agent; it needs no build agent.

## 1. Check for a game already open (first, always)

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Select-Object Id, ProcessName, MainWindowTitle, Path
```

- A window titled like the game ("PositiveFPS") is a playtest the user may be playing. **Never close it.** Tell the user
  it is open and ask what to do. Do not open a second one unless they say so.
- Windows titled "AUTOMATED TEST" or "RENDERING CHECKPOINT" belong to tests, but you still may not stop them unless you
  started them.
- Console or headless Godot processes may be another agent's run. Leave them alone; mention them if they will skew
  nothing but the machine load.

## 2. Refresh the detached copy

The committed round is `git rev-parse --short main` in the live repo. Use a fresh folder per commit in the scratchpad
(the scratchpad path is in the session's environment notes), for example `<scratchpad>/playtest-<shortsha>`:

```powershell
git worktree add --detach "<scratchpad>/playtest-<shortsha>" main
```

- If a copy for that commit already exists and no game is running from it, reuse it.
- Remove an older copy only when no Godot process has its folder in its path (`Path` or command line) and the user is not
  playing it. A removal that fails with "Permission denied" or "Filename too long" is OneDrive or long paths: leave it
  and say so (`tools/cleanup_worktrees.py --dry-run` lists them).
- The copy is clean on purpose: uncommitted work is not in it. If the user wants uncommitted work played, say it is
  not included and commit first.

## 3. Import, then launch with recording

```powershell
python tools/godot_run.py --timeout 300 --console -- --headless --path "<copy>" --import
```

Check `exit=0` in the one-line summary (the log path is in it). Then start the windowed game, in the background, with
no timeout (the user plays as long as they like). Get the executable from `python tools/godot_path.py --gui`:

```powershell
& "<gui exe>" --path "<copy>" -- --record --look=placeholder
```

The `--look=` argument picks the starting look (F4 still switches). Gameplay rounds use `--look=placeholder`; graphics
checkpoints use `--look=styled`. Without the argument a copy run from the project starts placeholder (only exported
builds start styled). `tools/checkpoint_shots.py` needs no flag: it sets the look itself and flips both ways.

Use `run_in_background` for that command, so the session keeps working and is told when the game exits.

## 4. Confirm it started

Within about 20 seconds: a Godot process whose `Path` is the GUI executable exists with a "PositiveFPS" window title, and
a new folder `<copy>/recordings/<stamp>/` exists once the user starts a game from the menu (the recorder writes
`events.jsonl` then). If the process ended at once, read the background command's output and report the error. Tell
the user the game is ready and that the REC mark in the HUD means it is recording.

## 5. Analyse every new recording after the playtest

Do this when the user says they have finished (or the process has exited). List `<copy>/recordings/*` newer than the
launch. **Restarts under 10 s** (a game started and quit at once) are left out by `analyse_recording.py` itself, in the
single report (it prints a NOTE and writes nothing) and in `--compare`; add `--include-restarts` (single report) or
`--min-seconds 0` (compare) only if the user asks for them.

```powershell
python tools/analyse_recording.py "<copy>/recordings/<stamp>"            # one report each, plus timeline.csv
python tools/analyse_recording.py --compare "<older recording>" "<copy>/recordings/<stamp>" ...   # side by side
```

The single report ends with two round 23 sections: **PRESSURE CURVE** (15 s steps: mean dimmed, gaps and pressers,
relapses, threats and rescued at the end of each step) and **PATCH EFFECT** (for each patch: kind `gap` or `strain`,
gaps open at the patch, gaps 10 s and 20 s later, and whether they fell). Quote them for pressure and patch questions.

Compare against the previous round's recording when the user wants round-over-round numbers (older ones are in the
earlier playtest copies' `recordings/`). Summarise outcome, length, rescued, quiet share, gaps by phase, relapses, spirit,
beacons and landmarks, and quote real numbers, not impressions. Then go on to the interview and record the playtest in
IDEAS.md (round loop steps 2 and 3).

## Rules

- Never kill a process you did not start, and never close the user's game window.
- A safety check that denies a command means stop and report. Nobody runs it on your behalf.
- Temp files go in `.scratch/` or the scratchpad, never `C:\` paths.
