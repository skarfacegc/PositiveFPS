# PositiveFPS — instructions for Claude

The design log is IDEAS.md: start with its "Current state" section (mechanics, controls, open items, push status).
Finished round history and resolved issues are in IDEAS_RESOLVED.md. The agent map, tooling and gotchas are in
ARCHITECTURE.md, so point build agents there instead of telling them to read every file. To find code, search
SOURCE_MAP.md (every script's public functions with line numbers, generated: regenerate with
`python tools/source_map.py`; the commit hook refuses a stale map) and Read only the lines you need.

## Round loop

1. **Playtest:** launch the committed round from a clean detached worktree in the scratchpad, never from the live repo.
2. **Interview:** ask structured questions, then ask "anything else?" before building.
3. **Record:** write the playtest and the plan in IDEAS.md and commit them.
4. **Build:** delegate to subagents on the cheapest capable model (Haiku for tuning and small features, Sonnet for
   debugging emergent behaviour or tooling). The main session only coordinates.
5. **Report:** relay the results, list anything loosened, and show `coverage/index.html`.

## Parallel builds

- **Split independent parts.** When a round splits into parts that don't depend on each other, give each part its own
  agent with `isolation: "worktree"`, then merge the branches.
  - Expect small conflicts in shared files (`scripts/config.gd`, README.md, IDEAS.md, menu text). The coordinator
    resolves them at merge time.
  - Give each part its own constants block (for example "Round N: guarded wedge") to keep conflicts small.
- **Check the base first.** Worktree agents start from `origin/main`, not local main, and main is usually ahead
  because rounds aren't pushed. Before launching, compare `git rev-parse origin/main main`. If they differ, tell
  each agent the local main commit hash and have it run `git merge --ff-only <hash>` in its worktree before any edit,
  then stop and report if `git log --oneline -1` doesn't show that hash.
- **Gate per part.** Part agents run only their own targeted suites (`tools/run_tests.py`) and lint. They do not run
  the full gate, the determinism check or the baseline update, because parallel full gates fight over the CPU.
  Part agents set `POSITIVEFPS_PARALLEL_PART=1` for their commits, which skips the flaky serial timing pass; the
  coordinator's post-merge `gate.py --full` enforces it.
- **Gate once after merging.** After the merge, run these once, in order: `python tools/gate.py --full`, then
  `python tools/coverage.py --check-determinism`, then `python tools/coverage.py --update-baseline` (never
  `--allow-decrease`). Then make the docs and baseline commit.
- **Sequential parts stay sequential.** If one part depends on another, or the round is a single bug hunt, use one
  agent.
- **Build while the user plays.** During a playtest, background agents can work on backlog items that need no
  playtest feedback, such as refactors, tooling and housekeeping. They must stay off files the next gameplay round
  will touch.

## Rules for every agent

- **Scratch files:** temp files go only in the gitignored `.scratch/` folder, never `C:\` paths.
- **Processes:** never kill a process you didn't start. A playtest window may be open.
- **Denied commands:** if a safety check denies a command, stop and report. Nobody runs it on the agent's behalf.
- **Commits:** commit explicit paths only (include new `.gd.uid` files). Never `git add -A`, never push, never amend.
- **No loosening:** never loosen a test threshold or a `test_perf_*` budget to get green. Stop and report instead.
- **Report honestly:** wait for the gate in the foreground before reporting. No partial hand-backs while it runs.
- **Styled look:** gameplay rounds change only the placeholder look. The styled look and checkpoint screenshots
  change only in graphics checkpoints the user asks for.
- **Words:** player-facing text uses the gloom terms (wistful / gloomy / dimmed), never "dark people".
- **Art:** art must be original. Take inspiration at the technique level only, never copy another game's style.
