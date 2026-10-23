# PositiveFPS — proof of concept

A gentle first-person "shooter" where instead of hurting people, you spread joy.
Twenty grey people are standing in a plaza. Shoot them with the right element to
fill their joy meter, and they turn colourful and bounce. You have two minutes.

## How to run

1. Open Godot 4.7.
2. Click **Import** and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button) to run the game.

## Modes

The game opens a menu. Pick a mode:

- **1 = First person** (the original): aim with the mouse and fire beams.
- **2 = Top-down** (new): a bigger plaza seen from above. You move and choose the element; joy fires automatically at the nearest person (or the one under your mouse).

Press **M** at any time to go back to the menu.

## Controls

First person:

- **WASD** move
- **Mouse** look around
- **Shift** run
- **Space** jump
- **Left click** spread joy (hold to keep firing)
- **1 / 2 / 3** or **mouse wheel** switch element (Music, Art, Nature)
- **Esc** free the mouse
- **R** restart
- **M** back to menu

Top-down:

- **WASD** move, **Shift** run
- **Mouse** aim (joy fires automatically)
- **1 / 2 / 3** or **mouse wheel** switch element
- **G** or **Q** joy burst (short cooldown; boosts everyone nearby)
- **R** restart, **M** back to menu

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

- Run the tests: `python tools/run_tests.py`. It runs headless against this project and writes HTML and
  JUnit reports to `reports/`. Exit code 1 means a test failed.
- Lint and format: `python tools/lint.py` checks formatting (gdformat, 120 columns) and lint (gdlint, settings in
  `gdlintrc`) over `scripts/` and `tests/`. `python tools/lint.py --fix` reformats the files first, then lints.
- Tests and coverage: `python tools/coverage.py`. It copies the project to `.coverage_build/`, instruments
  every executable line in `scripts/`, runs the tests there, and writes `coverage/index.html` (open it in a
  browser: a per-file table, then an annotated copy of each script with green lines that ran and red lines that
  never ran), plus `coverage/summary.txt` and `coverage/coverage.json`. Line coverage is the headline number;
  function coverage is kept as a secondary column.
- Coverage ratchet: `coverage_baseline.json` (committed) holds the line coverage of the last accepted run.
  - `python tools/coverage.py --check-baseline` fails (exit 3) if the total or any existing file drops by more
    than 0.5 points, or a new file is under 60%.
  - `python tools/coverage.py --update-baseline` records the current numbers. It only works if all tests pass,
    and refuses any decrease unless you add `--allow-decrease`.
- The Godot executable comes from the `GODOT` environment variable, or the default path in `tools/run_tests.py`.

Pre-commit gate: once the hooks are enabled, a commit that changes `*.gd`, `*.tscn`, `*.tres`, `project.godot`,
`tools/` or `tests/` runs `tools/lint.py` and `tools/coverage.py --check-baseline` first. That takes about two
minutes. It prints a one-line summary (tests passed, line coverage, baseline OK) or the failure. Fix the cause
and commit again; never use `--no-verify`. Known limitation: the gate tests the working tree, not only the staged
snapshot, so stash unstaged edits if you need the staged version tested exactly. Other commits skip the gate.

Test runs set `POSITIVEFPS_TEST=1` (or run headless). In that mode the game never captures the real mouse, so a
test run cannot take over your mouse; the window title is also changed to say it is an automated test.
