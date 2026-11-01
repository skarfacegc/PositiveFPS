---
name: brief-build-agent
description: Template for briefing a PositiveFPS build agent (Haiku or Sonnet, usually in a worktree): base-commit check, rules, commit trailer and the "every Godot run must end itself" line. Use whenever delegating build, tuning or tooling work in this repo.
---

# Brief a build agent

Fill in the angle-bracket parts, delete the lines that do not apply, and send it as the agent prompt. Do not paste
CLAUDE.md into it: the agent reads it. Point to ARCHITECTURE.md ("How to brief an agent") for the files of the area
instead of listing every file. Choose the model by CLAUDE.md: Haiku for tuning and small features, Sonnet for
debugging emergent behaviour or tooling.

For a worktree agent (`isolation: "worktree"`), first compare `git rev-parse origin/main main`. If they differ, use
the BASE CHECK block with local main's hash. Worktree agents start from `origin/main`, which is usually behind.

## Template

```
PositiveFPS (Godot 4.7.2 GDScript with Python tools). Read CLAUDE.md, then ARCHITECTURE.md; your task is
"<round and item names>" in IDEAS.md. <One or two sentences on what to build and the numbers to use.>

FIRST, before any edit: run `git merge --ff-only <local main hash>` in your worktree. If `git log --oneline -1`
doesn't then show that hash, stop and report.                                   <- BASE CHECK, worktree agents only

Scope: <files you may change>. Stay out of <files other parallel agents own>. Put new constants in their own block
("Round N: <part name>") in scripts/config.gd. <Other parts running in parallel and what they touch.>

Tests: add tests for new behaviour in tests/<name>_test.gd. Run only your own suites
(`python tools/run_tests.py` for the targeted suite, `python tools/lint.py`), not the full gate, determinism or baseline
(<coordinator> runs those after the merge).                                      <- parallel parts
Run `python tools/gate.py` and wait for it in the foreground before you report.  <- single agent

Rules (CLAUDE.md has the full list): temp files only in .scratch/; never kill a process you did not start (a playtest
window may be open); if a safety check denies a command, stop and report; never loosen a test threshold or a test_perf_*
budget (stop and report); gameplay rounds change only the placeholder look; player-facing words are wistful / gloomy /
dimmed.

EVERY GODOT RUN MUST END ITSELF. Give every scripted Godot run a timeout and a log, with
`python tools/godot_run.py --timeout <seconds> -- <command>` (it ends only the process tree it started and prints the
exit, time and log path). Never leave a Godot process behind, and never end one you did not start.

Commits: explicit paths only (include new .gd.uid files), never `git add -A`, never push, never amend. Set
POSITIVEFPS_PARALLEL_PART=1 for your commits.                                    <- parallel parts only
End every commit message with:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
(use the trailer line the session's attribution reminder gives, if it differs)

Report: your branch and commit hashes, what you built and how to use it, test and lint results, anything loosened
(say "nothing" if so), and anything left undone. Deliver it with SubagentHandback.
```

## After the agent reports

Check the branch with `git log --oneline` and `git diff --stat main..<branch>`, merge it (the `finish-round` skill has
the order), and look for files the agent touched outside its scope.
