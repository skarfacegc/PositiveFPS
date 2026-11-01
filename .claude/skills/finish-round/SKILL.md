---
name: finish-round
description: Finish a PositiveFPS round after its build agents are done: check for stray Godot processes and load, merge the branches, run the full gate, determinism check and coverage baseline in order, handle baseline refusals, search for stale player-facing text, write the docs and refresh the playtest copy. Use at step 5 of the round loop.
---

# Finish a merged round

CLAUDE.md has the rules (parallel builds, gate once after merging). This is the order of work and the traps. The
gate steps can run past the 10-minute command limit, so run them as described in step 4.

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
`scripts/config.gd`, README.md, IDEAS.md, menu text and `tools/analyse_recording.py`. Keep both sides' constants blocks.
Check `git status` is clean and `git log --oneline` shows each part.

## 3. Stale player-facing text

Before the gate, search for words the round made wrong: menu and how-to-play text (`scripts/menu*.gd`,
`scripts/hud.gd`, the prompt bar and intro text), README.md's play section, and tests asserting strings. Grep for the
old key names, old numbers and any "dark people" wording (the term is wistful / gloomy / dimmed). Fix mismatches with a
small commit, or send them to a Haiku agent.

## 4. The gate, determinism and baseline, in order

Each step in the foreground when it fits in the limit; otherwise start it with `run_in_background`, give it a `.scratch/`
log (`... > .scratch/gate.log 2>&1`), and wait for the exit notice, then read the log. Never report while a step is
still running, and never start the next one in parallel (they fight over the CPU).

```powershell
python tools/gate.py --full
python tools/coverage.py --check-determinism
python tools/coverage.py --update-baseline
```

- A failing test: fix or send it to an agent; do not weaken it.
- A failing `test_perf_*`: follow the hard rules above. `python tools/perf_compare.py <before> <after> --rounds 5`
  tells a real slowdown from load (it warns about other Godot processes and CPU load).
- `--update-baseline` refuses when coverage fell: **send that refusal to a test agent** (Sonnet) to add tests. Never
  edit `coverage_baseline.json` by hand.
- After the baseline: commit the docs and baseline together (explicit paths, `POSITIVEFPS_PARALLEL_PART` unset so the
  hook enforces timing).

## 5. Docs

Update IDEAS.md (what was built, what was loosened or deferred, the playtest notes), README.md's feature and key list,
and ARCHITECTURE.md's script map, config and tests sections for what changed. `tools/COVERAGE_TOOL_NOTES.md` only if
the coverage tool changed. Agents' own commits must not have staged `design/`.

## 6. Refresh the playtest copy and report

Use the `launch-playtest` skill for the copy (it checks for an open game first). Then report: what was built, anything
loosened (say "nothing" if so), timing readings if a timing test was involved, the gate numbers, and show
`coverage/index.html`.
