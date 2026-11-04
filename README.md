# PositiveFPS: the living border

A gentle top-down territory game. Gloom slowly takes over a plaza, and you rescue people to bring joy back. The
people you rescue form a living border that holds the gloom back and paints the land inside it. The level runs from
dusk to dawn: the light fades, the grey gets stronger at midnight, and the level ends at dawn. (Round 11. The first person
mode was retired.)

## How to play

- **Goal:** Bring joy to the gloomy townsfolk. Everyone you help joins a living border around your town. Survive
  until dawn: the level is won at dawn and rated in **dawn lights** (1 to 3) from the people rescued, the ground held and
  the landmarks held.
- **Helping:** Point at a person and joy flies to them automatically. Guarded people only accept joy from the front,
  skittish people flee if you run at them, and glum people take extra joy when they look up.
- **The gloom:** Dimmed people press on your border and reach for you. Where they push, border folk falter and gaps
  open. Re-joy a faltering person to close the gap.
- **Spirit:** Helping people fills it; a joy burst and a gap patch cost some. At zero you go dim. Recover inside your border.
- **Fighting back (round 22):** rings on border folk show where the border is about to break (amber, then red as it
  gets urgent). **F** spends 25 spirit to patch the gap or strained spot nearest the cursor for 12 s; **G** or **Q**
  clears dimmed people off the border.
- **Wobble, burst and first light (round 24):** a border person who is drained too far **wobbles** (greys and sways) for
  about five seconds before they relapse, and a joy hit in that time saves them. A joy burst lifts every dimmed person
  near you, and joy wins a dimmed person back faster. In the last 45 seconds **first light** creeps in from the map edge:
  people it has passed lift out of the gloom and stop draining, so the end of the night is a rally.
- **Wobble alert (checkpoint 5):** a wobbling person out of view gets a pulsing amber pointer at the screen edge (one per
  nearby cluster; it pulses faster as the wobble runs out), and each wobbler is a pulsing blip on the minimap.
- **Icons:** shield = guarded · running feet = skittish · cloud = glum · umbrella = sheltered (its pips count the four hits left) · ! = faltering. The night
  introduces them one at a time, with a short one-time prompt each.
- **Keys:** WASD move · Shift run · E shape the zone (spirit beacon) · G or Q joy burst · F patch gap · Mouse point at
  people (F2 changes targeting) · Mouse wheel zoom · F3 debug · F4 switch look · R restart · M menu

## How to run

1. Open Godot 4.7.
2. Click **Import** and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button) to run the game.

## Play

The game opens a menu with one **Play** button. Press **Enter**, **1** or click Play to start the level. The border
variants were retired in round 10; the organic push is the border.

In the level: WASD to move, the mouse to point at people, **E** to shape the zone, **F** to patch a gap, **G** or **Q**
for a joy burst. A small cue beside the spirit meter glows when F or G can be used right now. Press **M** at any time to go back
to the menu. **R** restarts the level.

## The living border

- **The centre forms by itself.** It is the average position of the rescued people. There is no pre-placed heart.
- **Three people make a border.** The rescued people stand evenly spaced along it, 2.6 m apart (the outermost ones are
  the border; the rest stand inside). A stretch longer than 3.5 m is a **gap**, which glows coral and pulses softly.
  Gaps let the gloom through.
- **Posts.** A beautified block on the line (or the landmark, once beautified) is a **post**: it has a warm lantern and
  a golden ring, and it holds three people's worth of border, so the loop needs three fewer people. Segments beside a
  post are never gaps.
- **The gloom is held back.** Dimmed people outside the border cannot cross a solid (gold) stretch. Pressing on an intact
  stretch pushes them back, and it drains the nearest border person a little (a quarter of the rate through a gap).
  Through a gap they can get in, and they drain the nearest border person at the full rate.
- **Relapses open holes.** A border person who relapses steps out, and the others shuffle to close the gap. With too
  few people, the gaps stay open.
- **Local gaps (round 12b).** A gap can open at one stretch. A border person drained below 75% of their joy **falters**:
  they step back half a metre and the stretch on both sides of them glows as a gap. Gaps also open everywhere when the
  loop is stretched too wide. Neighbours do not smooth a faltering stretch away at once: after 3 s a spare inside person
  takes the place, if there is one. Shooting joy at the faltering person (they flicker and show "!") closes the gap.
  Dimmed people prefer the newest, outermost part of the border, and they walk right up to the line to press it, so a
  push on one person is a push on one stretch.
- **Inside the border the land changes.** The ground is painted warm (it fills in slowly), and blocks inside are
  beautified after a few seconds. A grey person deep inside the border lightens instead of dimming.
- **The border stays put (round 19).** Once it forms, its centre no longer follows you or the people who push it. Press
  **E** to place a **spirit beacon** at the mouse (50 spirit, one at a time, a new one replaces the old and costs again):
  the zone stretches toward it (about 1.7 m a second, up to what your people can hold; about 34 m from its centre at 24 people) and the arm stays,
  so you build a shape over the night. Rescue more people to expand further; lose people and the zone draws in
  from its longest arms once the body has squeezed to its smallest. A stretch stops short of dimmed people, and E is refused with a reason if it can't be held.
- **Three landmarks** stand far from the start, so you need beacons to reach them: the **bandstand** (music joy x2),
  the **garden** (nature joy x2) and the **bell tower** (border members within 17 m lose 60% less to the gloom).
  Beautify one inside the border and keep it for 3 seconds to hold it; it loses its boost the moment the border drops
  it. The top right lists the landmarks you hold; an arrow at the screen edge points to each one you do not hold.
- **Losing**: if the border has formed and fewer than three people are rescued, the border falls.
- **Calm opening**: the first quarter of the night is calm (almost no grey pressure), then it builds toward midnight.
  Dimmed people arrive sooner than they did, then ease off: the last third of the night is gentler.
- **Dusk to dawn**: a bar at the top shows the night. The level ends at dawn, and reaching dawn wins. The end screen gives
  1 to 3 **dawn lights** and why: 1 for reaching dawn; 2 when two of "40% of the people rescued", "20% of the plaza held"
  and "one landmark held" are met; 3 when 60% of the people are rescued and one landmark is held at dawn.

## Spirit, going dim and the dance with the gloom (round 12a)

- **Spirit** is your spendable resource (0 to 100, you start with 50). Every rescue gives +20. The joy burst costs 30,
  so with less than that it is unavailable (the HUD says "needs 30 spirit"). Your joy fire rate depends on spirit:
  full at 50 or more, then slower, down to 40% of the rate just above 0. The spirit bar is bottom left, above the burst.
- **Dimmed people reach for you.** A dimmed person who notices you (within 7 m) walks toward you. Within 2 m they start a
  **grab**: a clear wind-up (0.7 s) where they lean back and a red ring grows at their feet toward you, then a lunge. If
  you are within 1.3 m of them when the lunge ends, it lands and drains 25 spirit. Each person waits 2.5 s between grabs.
  To dodge one, step out of reach before the lunge ends: walking away works.
- **Going dim.** At 0 spirit you go dim: half walking speed, no joy fire and no burst, and your colour drains toward
  grey. Dimmed people ignore a dim player and go back to pressing the border. While you are dim the
  border loses ground 1.5 times faster and its line flickers, so the cause is clear.
- **Recovering.** A dim player recovers 10 spirit a second, scaled by how deep inside the border they stand (30% at the
  line up to 100% a metre in), and only inside the border. Before a border exists, stand within 6 m of a landmark.
  At 30 spirit you are back to normal.

## Reading the person: moods and sheltering (round 12b)

Every wistful or gloomy person has one mood (dimmed people have none). The HUD shows the target's mood next to its
element, and F3 labels it above the person.

- **Guarded** (shield icon, back to you): they turn slowly to keep their back to you. A glowing wedge on the ground shows
  where joy gets in: the open side, within 110 degrees either side of the way they face. It brightens while a shot from
  you would land. From behind it glances off in a small white puff. Run round them: they turn slower than you can circle.
- **Skittish** (jittery): if you run (Shift) at them within 5 m, they back away for 1.5 s. Walking up does not scare them.
- **Glum** (slumped, leaning forward): every 3 s they look up for 0.8 s (they straighten and a warm glint shows above
  them). Joy that lands then counts triple.
- **Sheltering:** a dimmed person shelters the single nearest wistful or gloomy person within 2 m of them. The umbrella
  lets a little joy through (a quarter); each hit empties a pip under it, and after four hits it breaks (a burst shows). A broken umbrella
  stays down for 8 s, and only if the dimmed person is still dimmed can they put up a new one.
  Others nearby still take joy. Deal with the dimmed person first, or draw them away: they chase you when you are close.
- **Dimmed people can be helped too, just slower** (they need about 1.6 times the joy of a wistful person). A dimmed
  person hit by joy shows a progress ring. Dimmed people sink one at a time through the night, at least a few seconds
  apart.
- **Stage changes are visible.** When someone sinks a stage (wistful, gloomy, dimmed) a grey-violet puff and ripple
  plays, a warm one when they lift. The minimap flashes a violet ring where someone has just become dimmed.

## Controls

- **WASD** move, **Shift** run, **E** place a spirit beacon at the mouse (50 spirit); the zone stretches toward it and the arm stays.
- **Click** a person to lock on (in lock-on mode). The default is **hover**: the person under the mouse becomes the
  target. **F2** cycles the modes: lock-on, hover (default) and auto (the most urgent person in range).
- Every shot uses the target's element, so it is always a best match. Music is quick and small, art is slow and big
  (it splashes), nature is a floating flower that blooms where it lands.
- **G** or **Q** joy burst (8 s cooldown, costs 30 spirit): dimmed people pressing the border within 8 m are pushed back
  4 m and lifted to gloomy (streaks show it; the HUD says how many are in reach), border folk in range get a joy top-up,
  and used within 4 m of the border it also shoves the line outward toward you.
- **F** patch gap (costs 25 spirit, lasts 12 s, up to 4 at once): point the cursor near an open gap or a red-ringed member.
  A teal disc shows the sealed stretch: gloom does not pass it and members inside lose joy at 15% of the rate. It buys
  time; it does not heal anyone. Refused (with a notice) when you are out of spirit or no gap is within 9 m of the cursor.
- **F3** toggles the debug overlay: cover (`c`) and protection (`p`) above each person, a label per border segment (its
  spacing, and GAP where it is one), and the member, inner, post and night numbers at the top left, and the live floor-effect counts (for example
  `floor fx 12/40: ring 2, splat 3`, against the cap of 40). Off by default. If F3 does
  nothing on your keyboard, the F-row may be set to media keys: try Fn+F3.
- **Mouse wheel** zooms the view in and out (a closer or wider look at the plaza; the labels keep their size on screen).
- **R** restart, **M** back to the menu.

**Recording a game for review (round 18):** tick **Record this game (for review)** in the top right of the menu (it is
off by default and the choice is remembered), or start the game with `-- --record`. While it is on a red **REC** mark
shows in the HUD, and each game writes a folder `recordings/YYYYMMDD-HHMMSS/` in the project folder (gitignored) when
run from the editor; an exported build writes to `user://recordings/` instead (Godot's user data folder, for example
`%APPDATA%/Godot/app_userdata/PositiveFPS/recordings` on Windows; the path is also printed to the console). The folder
holds `events.jsonl` (one JSON event per line: a sample every second, plus sinks, rescues, gaps opening and closing,
grabs, umbrella pops, target changes and the end) and a small `shot_0001.png` every 18 seconds. Summarise it with
`python tools/analyse_recording.py recordings/<folder>` (quiet time, threat cadence, gap durations, decisions per minute,
and a `timeline.csv`). Recording never changes how the game plays.

**On screen (round 10):** the camera is orthographic and looks down at the plaza. A circular **minimap** sits top-left
(warm and grey ground, buildings, the border, gaps, members, dimmed people, the landmark star, you, and the view rectangle).
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
- The Godot executable comes from the `GODOT` environment variable, then `godot` on PATH, then the WinGet install under `%LOCALAPPDATA%` (all in `tools/godot_path.py`).

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

## License

PositiveFPS is released under the [MIT License](LICENSE). The bundled `addons/gdUnit4` test framework keeps its own MIT
license (see `addons/gdUnit4/LICENSE`). Builds made with Godot include the Godot engine, which is MIT licensed; see
[godotengine.org/license](https://godotengine.org/license) for the notice to ship with exported games.
