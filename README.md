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
- **2 = Top-down**: a bigger plaza seen from above. You move and pick your target; joy flies at it as physical projectiles.

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
- **Left click** a person to lock on. A warm ring under their feet marks the target, and your shots fly at them while
  you hold the lock. Click empty ground to let go. The lock drops when they are rescued or you walk more than 14 m away.
- **F2** cycles the targeting mode (shown top right):
  - **Lock-on** (default): click to lock, as above.
  - **Hover**: with no target, the person under the mouse becomes the target and stays one until they are rescued
    or out of reach, even if you move the mouse.
  - **Auto**: no clicks. The most urgent person in range is shot at: someone about to relapse first, then the darkest.
- No element switching in top-down: every shot uses the **target's** element, so it is always a best match. The ring
  under you shows the target's element colour (cream with no target).
- Shots are real projectiles and take a moment to arrive. Each element has its own rhythm, and all three give the same
  joy per second. **Music** is small, quick notes (twice as many shots): they home in on the target, leave a wavy
  dusty-blue ribbon, and ring the ground where they land. **Art** is a big, slow paint blob (half as many shots): it
  lobs in a high arc, drips rose and terracotta on the way, and leaves a large splat and a splash on nearby people.
  **Nature** is a floating flower at a steady pace: it sheds sage and pink petals, blooms where it lands, and bursts
  petals.
- A rescued person has a 4-second grace period: a warm ring pulses on the ground under them and they glow, until it
  ends. Nearby darkness cannot drain them during it.
- **Cover:** painted ground protects people standing in it. Deep inside a painted area, darkness cannot reach people and
  grey people slowly lighten (joy contagion, which never rescues anyone on its own). Darkness still creeps in at the
  edges of painted ground. Paint takes a few seconds to spread in and lingers for a long time after someone relapses.
- **F3** toggles a debug overlay: above each person, `c` is their cover (the paint around them) and `p` their
  protection from it. Off by default.
- **G** or **Q** joy burst (short cooldown; boosts everyone nearby)
- **R** restart, **M** back to menu

Gamepad: not bound yet. Every gameplay action goes through the InputMap, and `scripts/controls.gd` lists the action
a future gamepad mapping would use for each one.

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
- Test runs use a fixed timestep (`--fixed-fps 60`, `TEST_FIXED_FPS` in `tools/run_tests.py`) and one seed
  (`Config.RNG_SEED`), so repeated runs give the same coverage.
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
