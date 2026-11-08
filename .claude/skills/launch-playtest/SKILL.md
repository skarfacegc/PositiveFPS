---
name: launch-playtest
description: Launch a PositiveFPS playtest from a clean detached copy of the committed target pass with recording on, confirm it started, analyse the new recordings afterwards and update the board after the interview. Use at step 1 of the target loop or when the user asks to play the latest build.
---

# Launch a playtest

The target loop (CLAUDE.md) says: launch the committed pass from a clean detached worktree in the scratchpad, never
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

The committed pass is `git rev-parse --short main` in the live repo. Use a fresh folder per commit in the scratchpad
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

The `--look=` argument picks the starting look (F4 still switches). Gameplay passes use `--look=placeholder`; look-focused
targets use `--look=styled`. Without the argument a copy run from the project starts placeholder (only exported
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

Compare against the previous pass's recording when the user wants pass-over-pass numbers (older ones are in the
earlier playtest copies' `recordings/`). Summarise outcome, length, rescued, quiet share, gaps by phase, relapses, spirit,
beacons and landmarks, and quote real numbers, not impressions. Then go on to the interview and record the playtest in
IDEAS.md (target loop steps 2 and 3), then update the board (section 6).

## 6. Update the board after the interview

Read the board first (`python tools/board.py list`) so the interview covers what this pass built (items In review).
After the interview, in the same turn:

- Items the user played and accepts: `python tools/board.py set <N> --status Done` (this closes the issue).
- Items that need more work stay In review, or go back to Ready with a note in IDEAS.md.
- New ideas and snags from the interview: `python tools/board.py add "<headline>" --label <area> --size <XS..XL>
  --pointer "IDEAS.md → <section>"`, Status Backlog unless the user targets them, and put the new `#N` on the
  matching IDEAS.md line.
- Anything the user targets ("do X next", "put Y in Tug of war"): set its milestone and Status Ready.

Say what changed on the board in one or two lines.

## Rules

- Never kill a process you did not start, and never close the user's game window.
- A safety check that denies a command means stop and report. Nobody runs it on your behalf.
- Temp files go in `.scratch/` or the scratchpad, never `C:\` paths.
