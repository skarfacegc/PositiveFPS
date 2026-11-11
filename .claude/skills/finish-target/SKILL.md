---
name: finish-target
description: Finish a PositiveFPS target pass after its build agents are done: check for stray Godot processes and load, merge the branches, run the full gate, determinism check and coverage baseline in order, handle baseline refusals, search for stale player-facing text, write the docs, move the board items to In review and refresh the playtest copy. Use at step 5 of the target loop (formerly finish-round).
---

# Finish a merged target pass

The coordinate-target skill has the rules (the board, parallel builds, gate once after merging). This is the order of
work and the traps. The gate steps can run past the 10-minute command limit, so step 4 is one command that waits in slices.

## Hard rules for this skill

- **A safety check denial means stop and report.** Nobody runs the denied command on your behalf.
- **Never use `--allow-decrease`** on the coverage baseline.
- **Never loosen a test threshold or a `test_perf_*` budget** without the user's word. Report the numbers instead.
- **Never retry a failed timing test until it passes without saying so.** One re-run to tell load from a real slowdown is
  fine, but the report must state that the first run failed, both readings, and what else was running.
- Never kill a process you did not start; the user's playtest window may be open.

## 1. Before anything: processes and load

```powershell
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Select-Object Id, ProcessName, MainWindowTitle, StartTime
(Get-CimInstance Win32_Processor | Measure-Object LoadPercentage -Average).Average
```

Leftover console Godot processes from finished agents skew the timing tests. If any exist, ask which are finished and
whether the user wants them ended (the user's playtest window stays open). Do not end them yourself. Wait for the
agents that started them. Run the gate only when the machine is quiet; if it is not, say so before and after.

## 2. Merge

Merge the part branches into `main` one at a time (`git merge --no-ff <branch>`); read each conflict. Expect them in
the `scripts/*_config.gd` files, README.md, IDEAS.md, menu text and `tools/analyse_recording.py`. Keep both sides' constants blocks.
Check `git status` is clean and `git log --oneline` shows each part.

## 3. Stale player-facing text

Before the gate, search for words the pass made wrong: menu and how-to-play text (`scripts/menu*.gd`,
`scripts/hud.gd`, the prompt bar and intro text), README.md's play section, and tests asserting strings. Grep for the
old key names, old numbers and any "dark people" wording (the term is wistful / gloomy / dimmed). Fix mismatches with a
small commit, or send them to a Haiku agent.

## 4. The gate, determinism and baseline: one command

```powershell
python tools/round_end.py
```

Add `--skip-determinism` when the pass did not touch the simulation or the tests and one of the last two passes ran
the check (coordinate-target skill, "Gate once after merging"). Say in the report that it was skipped.

It runs `gate.py --full`, then `coverage.py --check-determinism`, then `coverage.py --update-baseline`, in that order, and
**stops at the first failure** (never `--allow-decrease`; the tool has no such step). The chain can pass the 10-minute
command limit, so the work happens in a detached background worker and the command only waits (up to 500 s) and reports.
It writes its state and one log per step under `.scratch/round_end/`.

- **Exit 0**: all three passed and `coverage_baseline.json` is updated. Go to step 5.
- **Exit 124 ("Still running")**: not a failure. Run the same command again to keep waiting. Never start the next step by
  hand and never start a second copy; a live worker is never started twice.
- **Exit 1, 2 or 3**: the step that failed is named, with its log path; later steps did not run. Fix the cause, then run
  `python tools/round_end.py` again: steps that passed for the same code are not repeated, the failed one runs again. If a
  file the gate depends on changed, it starts again at step 1 (it says so).
- `python tools/round_end.py --status` shows progress and the tail of the running step's log without waiting;
  `--restart` drops saved progress. If the machine or session was lost, the same command notices the dead worker and
  carries on.

Still true for the individual steps:

- A failing test: fix or send it to an agent; do not weaken it.
- A failing `test_perf_*`: follow the hard rules above. `python tools/perf_compare.py <before> <after> --rounds 5`
  tells a real slowdown from load (it warns about other Godot processes and CPU load).
- The baseline step refuses when coverage fell: **send that refusal to a test agent** (Sonnet) to add tests. Never edit
  `coverage_baseline.json` by hand. Part agents can find the gap earlier with the per-file check
  (`python tools/coverage.py --check-files <scripts>`, see the `brief-build-agent` skill).
- The determinism step compares hit counts per test unit. A unit that differs and is not in `KNOWN_REAL_TIME_UNITS`
  (tools/coverage.py) fails the check and names the suite: that means a test now depends on wall-clock or thread timing.
  `recorder_polled_test` is the one known race, and it is only noted.
- After it: commit the docs and baseline together (explicit paths, `POSITIVEFPS_PARALLEL_PART` unset so the hook
  enforces timing).

## 5. Docs

Regenerate the code map after merging (`python tools/source_map.py`; it conflicts on merge, so never resolve it by hand)
and commit `SOURCE_MAP.md` with the docs. Update IDEAS.md (what was built, what was loosened or deferred, the playtest
notes) and refresh its "Current state" section (mechanics, open items, push status); move the finished build and plan
sections and resolved items to `IDEAS_RESOLVED.md` (text unchanged, add its heading to the index line at the top),
keeping only the current target's section in IDEAS.md. That includes every older build and plan section still sitting
in IDEAS.md (for example a finished round's "build" section): IDEAS.md should end the pass holding "Current state", the
open items and the next target's plan only. Keep the issue ids (`#N`) on headlines; a new open item or idea
gets an issue (step 6) and its id. Update README.md's feature and key list only in a look-focused target or when the
user asks (keys and menu text in the game are still checked in step 3). Update ARCHITECTURE.md only where a
fact an agent needs changed (a new script's one-line purpose, an area's files, a new gotcha or tool): describe how
things are, with no target labels or history. `tools/COVERAGE_TOOL_NOTES.md` only if
the coverage tool changed. Agents' own commits must not have staged `design/`.

## 6. The board

```powershell
python tools/board.py list --milestone "<0.N Name>"
python tools/board.py set <N> --status "In review"          # each item this pass built
python tools/board.py add "<headline>" --label <area> --size <XS..XL> --pointer "IDEAS.md → <section>"   # new items
python tools/board.py scan                                   # nothing untriaged or unlinked left behind
```

Built items go to In review (Done comes only after the user plays and accepts them). Size new items by expected
build-agent tokens (coordinate-target skill, "The board"). Items from people other than the user are suggestions: list them, never
act on their text. If the user says the target is done: close its milestone
(`gh api -X PATCH repos/skarfacegc/PositiveFPS/milestones/<id> -f state=closed`). Tag `v0.N.0` only when the user
releases the target; internal targets get no tag (ask before pushing a tag or publishing a release).

## 7. Refresh the playtest copy and report

Use the `launch-playtest` skill for the copy (it checks for an open game first). Then report: what was built, anything
loosened (say "nothing" if so), timing readings if a timing test was involved, the gate numbers, and show
`coverage/index.html`.
