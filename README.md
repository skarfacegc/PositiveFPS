# PositiveFPS: the living border

A gentle top-down territory game. Dark people slowly take over a plaza, and you rescue people to bring joy back. The
people you rescue form a living border that holds the darkness back and paints the land inside it. The level runs from
dusk to dawn: the light fades, the grey gets stronger at midnight, and the level ends at dawn. (Round 10. The first person
mode was retired.)

## How to run

1. Open Godot 4.7.
2. Click **Import** and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button) to run the game.

## Play

The game opens a menu with one **Play** button. Press **Enter**, **1** or click Play to start the level. The border
variants were retired in round 10; the organic push is the border.

Press **M** at any time to go back to the menu. **R** restarts the level.

## The living border

- **The centre forms by itself.** It is the average position of the rescued people. There is no pre-placed heart.
- **Three people make a border.** The rescued people stand evenly spaced along it, 3 m apart (the outermost ones are
  the border; the rest stand inside). A stretch longer than 3.5 m is a **gap**, which glows coral and pulses softly.
  Gaps let darkness through.
- **Posts.** A beautified block on the line (or the landmark, once beautified) is a **post**: it has a warm lantern and
  a golden ring, and it holds three people's worth of border, so the loop needs three fewer people. Segments beside a
  post are never gaps.
- **Darkness is held back.** Dark people outside the border cannot cross a solid (gold) stretch. Pressing on an intact
  stretch pushes them back, and nobody is drained. Through a gap they can get in, and they drain the nearest border
  person.
- **Relapses open holes.** A border person who relapses steps out, and the others shuffle to close the gap. With too
  few people, the gaps stay open.
- **Inside the border the land changes.** The ground is painted warm (it fills in slowly), and blocks inside are
  beautified after a few seconds. A grey person deep inside the border lightens instead of darkening.
- **The landmark** is the taller block with a beacon, 18 m east and 16 m north of the plaza centre. Beautify it and hold
  the border around it for 10 seconds to win.
- **Losing**: if the border has formed and fewer than three people are rescued, the border falls.
- **Calm opening**: the first quarter of the night is calm (almost no grey pressure), then it builds toward midnight.
- **Dusk to dawn**: a bar at the top shows the night. The level ends at dawn. The end screen says whether the landmark
  was held, how much of the plaza is painted, how many buildings are beautified, and how many people were rescued.

## Controls

- **WASD** move, **Shift** run.
- **Click** a person to lock on (in lock-on mode). The default is **hover**: the person under the mouse becomes the
  target. **F2** cycles the modes: lock-on, hover (default) and auto (the most urgent person in range).
- Every shot uses the target's element, so it is always a best match. Music is quick and small, art is slow and big
  (it splashes), nature is a floating flower that blooms where it lands.
- **G** or **Q** joy burst: everyone close by gets a best-match hit (short cooldown). Used within 4 m of the border, it
  also shoves the line outward toward you.
- **F3** toggles the debug overlay: cover (`c`) and protection (`p`) above each person, a label per border segment (its
  spacing, and GAP where it is one), and the member, inner, post and night numbers at the top left, and the live floor-effect counts (for example
  `floor fx 12/40: ring 2, splat 3`, against the cap of 40). Off by default. If F3 does
  nothing on your keyboard, the F-row may be set to media keys: try Fn+F3.
- **R** restart, **M** back to the menu.

**On screen (round 10):** the camera is orthographic and looks down at the plaza. A circular **minimap** sits top-left
(warm and grey ground, buildings, the border, gaps, members, dark people, the landmark star, you, and the view rectangle).
When a gap is off screen, a coral **arrow** on the screen edge points at it. You are a saffron figure with a warm ring
under your feet, and people are drawn bigger.

Gamepad: not bound yet. Every gameplay action goes through the InputMap, and `scripts/controls.gd` lists the action a
future gamepad mapping would use for each one.

## Tuning

All the numbers live in `scripts/config.gd`. Change them there and run the game
again to see how it feels. Each one has a short comment explaining what it does.

## How the matchups work

Elements form a soft cycle:

- Music is strong against Art
- Art is strong against Nature
- Nature is strong against Music

Using the element that matches a person's marker gives double joy (2x).
Using an element that is strong against them gives 1.5x. Anything else gives 1x.

## Tests & coverage

The tests use [gdUnit4](https://github.com/godot-gdunit-labs/gdUnit4) (in `addons/gdUnit4`, enabled in
`project.godot`). The suites live in `tests/`. Rule for new features: add tests that drive real inputs
(key presses, mouse buttons and motion, actions) through `scene_runner(...)`, the same way a player would.
Pure rules can be tested directly.

Setup (once per clone):

1. Install the lint tools: `python -m pip install --user "gdtoolkit==4.*"` (gdtoolkit 4.x, the gdformat and
   gdlint modules, run through `python -m gdtoolkit.formatter` and `python -m gdtoolkit.linter`).
2. Enable the git hooks: `python tools/install_hooks.py` (sets `core.hooksPath` to `.githooks`).

Commands:

- Run the tests: `python tools/run_tests.py` (about 25 s). It runs headless against this project, with the suites split
  over parallel Godot processes (`--workers N`; `--workers 1` runs everything in one process), and writes HTML and
  JUnit reports to `reports/`. Exit code 1 means a test failed. Slow tests get a process of their own; their
  durations live in `tools/test_weights.json` (refresh with `--update-weights`). Every suite must be independent of the
  others (the level tests start with `TopDownTestUtil.level_runner(self)`).
- Test runs use a fixed timestep (`--fixed-fps 60`, `TEST_FIXED_FPS` in `tools/run_tests.py`) and one seed
  (`Config.RNG_SEED`), so repeated runs give the same coverage.
- Lint and format: `python tools/lint.py` checks formatting (gdformat, 120 columns) and lint (gdlint, settings in
  `gdlintrc`) over `scripts/` and `tests/`. `python tools/lint.py --fix` reformats the files first, then lints.
- The gate: `python tools/gate.py` runs exactly what the pre-commit hook runs (lint, then all tests). `--full` adds
  line coverage and the ratchet (the tests run instrumented, so they are not run twice), `--no-cache` ignores the
  result cache. A pass is cached, keyed on a sha256 of the working tree (`.git/positivefps-gate-cache.json`): running
  it again on identical code returns in about a second.
- Tests and coverage: `python tools/coverage.py` (about 30 s). It copies the project to `.coverage_build/`, instruments
  every executable line in `scripts/`, runs the tests there, and writes `coverage/index.html` (open it in a
  browser: a per-file table, then an annotated copy of each script with green lines that ran and red lines that
  never ran), plus `coverage/summary.txt` and `coverage/coverage.json`. Line coverage is the headline number;
  function coverage is kept as a secondary column.
- Coverage ratchet: `coverage_baseline.json` (committed) holds the line coverage of the last accepted run.
  - `python tools/coverage.py --check-baseline` fails (exit 3) if the total or any existing file drops by more
    than 0.5 points, or a new file is under 60%.
  - `python tools/coverage.py --update-baseline` records the current numbers. It only works if all tests pass,
    and refuses any decrease unless you add `--allow-decrease`. One run is enough.
  - `python tools/coverage.py --check-determinism` runs the instrumented suite twice and fails (exit 3) if the set of
    lines hit differs. Run it once at the end of a round, before the baseline commit.
- The Godot executable comes from the `GODOT` environment variable, or the default path in `tools/run_tests.py`.

Pre-commit gate: once the hooks are enabled, a commit that changes `*.gd`, `*.tscn`, `*.tres`, `project.godot`,
`tools/` or `tests/` runs `python tools/gate.py --hook`: lint, then the whole test suite (about 27 s; 1 s if the
working tree already passed). It prints a one-line summary or the failure. Fix the cause and commit again; never use
`--no-verify`. Known limitation: the gate tests the working tree, not only the staged snapshot, so stash unstaged
edits if you need the staged version tested exactly. Commits that only touch `design/` or Markdown skip the gate.

Coverage tier: the instrumented run costs about 30% more than the plain run, so the coverage ratchet is not part of
every commit. It runs in the hook only when `coverage_baseline.json` is staged. **Agents must finish every round with
`python tools/gate.py --full`, then `python tools/coverage.py --check-determinism`, and commit the baseline**
(`python tools/coverage.py --update-baseline`) so a drop in coverage cannot hide between rounds. Timings:
`tools/BUILD_TIMINGS.md`. Agent briefing: `ARCHITECTURE.md`.

Test runs set `POSITIVEFPS_TEST=1` (or run headless), and the window title says it is an automated test.

## Cleaning up playtest worktrees

Playtest builds run from detached git worktrees in a temp folder. Old ones leave stale entries under `.git/worktrees/`,
and git warns about them on every commit. To remove them:

- `python tools/cleanup_worktrees.py --dry-run` prints what would be removed, and changes nothing.
- `python tools/cleanup_worktrees.py` lists the plan, asks "Proceed? [y/N]", then removes the worktrees and the stale entries.
- `python tools/cleanup_worktrees.py --keep-latest` also keeps the most recently created worktree.

The main worktree is never touched. A worktree that a running Godot game is using is skipped: close the game and run the
script again. Add `-y` to skip the prompt. If you see "Permission denied", close any program using the folder (Godot,
Explorer, editors) and pause OneDrive sync, then re-run.
