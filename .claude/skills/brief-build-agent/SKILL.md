---
name: brief-build-agent
description: Template for briefing a PositiveFPS build agent (Haiku or Sonnet, usually in a worktree): base-commit check, rules, commit trailer and the "every Godot run must end itself" line. Use whenever delegating build, tuning or tooling work in this repo.
---

# Brief a build agent

Fill in the angle-bracket parts, delete the lines that do not apply, and send it as the agent prompt. Do not paste
CLAUDE.md into it: the agent reads it. Point to ARCHITECTURE.md ("Areas") for the files of the area
instead of listing every file. Choose the model by the coordinate-target skill's loop (step 4): Haiku for tuning and small features, Sonnet for
debugging emergent behaviour or tooling.

For a worktree agent (`isolation: "worktree"`), first compare `git rev-parse origin/main main`. If they differ, use
the BASE CHECK block with local main's hash. Worktree agents start from `origin/main`, which is usually behind.

## Template

```
PositiveFPS (Godot 4.7.2 GDScript with Python tools). Read CLAUDE.md (its rules are yours), then only ARCHITECTURE.md's "Known gotchas", "Quality gate and tools" ("For build agents" part only) and your area's line under "Areas" (not the whole file); your task is
"<target>: <part>" in IDEAS.md (board issues <#N, #M>). <One or two sentences on what to build and the numbers to use.>
To find code, search SOURCE_MAP.md first (every script's public functions with line numbers), then Read only the
lines you need. Do not read whole scripts, and do not read all of IDEAS.md: its "Current state" section and your
target's section are enough (history is in IDEAS_RESOLVED.md).

FIRST, before any edit: run `git merge --ff-only <local main hash>` in your worktree. If `git log --oneline -1`
doesn't then show that hash, stop and report.                                   <- BASE CHECK, worktree agents only

Scope: <files you may change>. Stay out of <files other parallel agents own>. Put new constants in their own block
("<Target>: <part name>") in the system's config script (scripts/<system>_config.gd; ARCHITECTURE.md "Tuning" lists them). <Other parts running in parallel and what they touch.>

Tests: add tests for new behaviour in tests/<name>_test.gd. Run only your own suites
(`python tools/run_tests.py --suites <name>_test [<other>_test ...]`, `python tools/lint.py`), not the full gate,
determinism or baseline (<coordinator> runs those after the merge). Before your last commit, run the per-file coverage
check on every script you changed or added: `python tools/coverage.py --check-files scripts/<a>.gd scripts/<b>.gd`
(about a minute; it runs only the suites that name those scripts, or pass `--suites ...`). It prints each script's line
coverage against `coverage_baseline.json` and the lines not hit; add tests until no script says BELOW. Its numbers are a
floor (only those suites ran). Do not run the baseline update.               <- parallel parts
Run `python tools/gate.py` and wait for it in the foreground before you report.  <- single agent
A tools-only or docs-only change (no scripts/, tests/, scenes or test tooling): do not run gate.py, which runs every
Godot suite. The commit hook is the gate there: lint plus the changed tool's tools/test_*.py.  <- tools/docs only

Tools: view file lines with the Read tool (offset/limit), never shell loops, sed, head/tail or pipes; create and edit
files only with Read/Edit/Write, never shell scripts or heredocs; run shell commands as plain single commands from your
own worktree, and read their logs with the Read tool at the printed path. (The worktree guard refuses compound commands
it can't check.) To save round trips, use one search instead of many reads: the Grep tool (with -A/-B context and a
glob) and command flags in place of pipes (`git log --oneline -5`, `git diff --stat`, `git show <hash>:<file>`). Run test suites and commits in the foreground (give
them a long timeout); never start background "wait", "sleep" or echo-marker commands to poll for something. (Round 25
agents launched dozens of these, and they filled the user's task panel with killed and failed entries.) Send exactly one
hand-back, when finished.

EVERY GODOT RUN MUST END ITSELF. Give every scripted Godot run a timeout and a log, with
`python tools/godot_run.py --timeout <seconds> -- <command>` (it ends only the process tree it started and prints the
exit, time and log path). Never leave a Godot process behind, and never end one you did not start.

SOURCE_MAP.md: the commit hook refuses a commit with .gd files when the map is stale. `python tools/lint.py --fix`
regenerates it (after formatting); otherwise run `python tools/source_map.py`. Add SOURCE_MAP.md to your commit. (Parallel parts: the coordinator regenerates it
after the merge, so a conflict there is resolved by regenerating, never by hand.)

Commits: explicit paths only (include new .gd.uid files), never `git add -A`, never push, never amend. Mention the
issues as `Refs #N` (never `Closes`). Set
POSITIVEFPS_PARALLEL_PART=1 for your commits.                                    <- parallel parts only
End every commit message with:
Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>
(use the trailer line the session's attribution reminder gives, if it differs)

Report in at most 15 lines: branch and commit hashes; what you built, one line per item; tests and lint pass or fail
(with counts); anything loosened (say "nothing" if so); anything left undone or any open question for the
coordinator. No tables, no per-test lists and no measurement logs: put details the coordinator might need in the
commit message or in .scratch/report_<branch>.md and give its path. Deliver it with SubagentHandback.
```

## Why the per-file check

The coverage baseline refused only after the full gate three rounds running. A part agent that changes
`scripts/x.gd` can see right away whether its tests cover the new lines. `--check-files` is the targeted version of
the ratchet: same tolerance (0.5 points below a file's baseline, 60% for a new file), same lines, but only the suites
that name the script. A script that reads BELOW there may still pass the full ratchet if other suites cover the lines;
one that reads ok will not fail it on that file.

## After the agent reports

Check the branch with `git log --oneline` and `git diff --stat main..<branch>`, merge it (the `finish-target` skill has
the order), and look for files the agent touched outside its scope.
