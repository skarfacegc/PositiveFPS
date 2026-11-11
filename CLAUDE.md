# PositiveFPS — instructions for Claude

**What to build next lives on the GitHub project board** "Positive game dev"
(https://github.com/users/skarfacegc/projects/3). It holds headlines only; the detail stays in the repo.
The design log is IDEAS.md: start with its "Current state" section (mechanics, controls, open items, push status).
Finished history and resolved issues are in IDEAS_RESOLVED.md. Unscheduled long-term ideas are in VISION.md. The agent map, tooling and gotchas are in
ARCHITECTURE.md, so point build agents there instead of telling them to read every file. To find code, search
SOURCE_MAP.md (every script's public functions with line numbers, generated: regenerate with
`python tools/source_map.py`; the commit hook refuses a stale map) and Read only the lines you need.

## Targets and versions

- **A target** is a goal you can play that ends in a playtest, named by what it is, with a version: "0.3 Living
  town", "0.4 Walls and gates". It holds gameplay, look and tooling work alike (a look-focused target replaces the old
  "graphics checkpoint"). A target may take several **passes** (build, then playtest); passes are known by date and
  commit, not numbered. Parts inside a target get short purpose names ("Walls and gates: Line").
- **Versions:** 0.x is pre-alpha. A finished target closes its milestone. Only a target the user releases is tagged
  `v0.N.0` (with a release build); internal targets get no tag (0.3 was internal). Fixes to a release are `v0.N.1`. 1.0 is alpha: one town fully playable and the core loop settled.
- Older work used round and checkpoint numbers; IDEAS_RESOLVED.md maps them to versions. Don't rename history.

## The board and the target loop (coordinator only)

The GitHub board, the target loop, keeping targets cheap and parallel builds are for the coordinating session only.
**The coordinating session loads the `coordinate-target` skill (`.claude/skills/coordinate-target/SKILL.md`) before it
touches the board, plans a pass or delegates build work.** Only the coordinating session touches the board; build agents
never do.

## Rules for every agent

- **Scratch files:** temp files go only in the gitignored `.scratch/` folder, never `C:\` paths.
- **Processes:** never kill a process you didn't start. A playtest window may be open.
- **Denied commands:** if a safety check denies a command, stop and report. Nobody runs it on the agent's behalf.
- **Commits:** commit explicit paths only (include new `.gd.uid` files). Never `git add -A`, never push, never amend.
  Mention issues as `Refs #N`.
- **Board:** build agents never edit the GitHub board or issues; the coordinator does.
- **No loosening:** never loosen a test threshold or a `test_perf_*` budget to get green. Stop and report instead.
- **Report honestly:** wait for the gate in the foreground before reporting. No partial hand-backs while it runs.
- **Styled look:** gameplay work changes only the placeholder look. The styled look and checkpoint screenshots
  change only in look-focused targets the user asks for.
- **Words:** player-facing text uses the gloom terms (wistful / gloomy / dimmed), never "dark people".
- **Art:** art must be original. Take inspiration at the technique level only, never copy another game's style.
