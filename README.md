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
- **Spirit:** Helping people fills it; a joy burst costs some. At zero you go dim. Recover inside your border.
- **Fighting back:** rings on border folk show where the border is about to break (amber, then red as it gets
  urgent). **G** or **Q** clears dimmed people off the border with a joy burst.
- **Wobble, burst and first light (round 24):** a border person who is drained too far **wobbles** (greys and sways) for
  about five seconds before they relapse, and a joy hit in that time saves them. A joy burst lifts every dimmed person
  near you, and joy wins a dimmed person back faster. In the last 45 seconds **first light** closes in as a ring from
  beyond the map's corners to the centre ("First light: dawn is coming in from the edges"): people it has passed lift
  out of the gloom and stop draining, so the end of the night is a rally.
- **Checkpoint 7 look:** the ground is alive. Inside the zone it has grass tufts, wildflowers, moss in the cobble cracks
  and puddles that catch the warm light; outside it is cracked grey slabs with litter and dead leaves. Street props
  stand between the buildings (lamp posts, benches, planters, market stalls, bunting and washing lines): dark, broken or
  bare in the gloom, lit, unfurled and in bloom inside the zone. Butterflies drift by day and fireflies by night inside
  the zone, birds land on beautified rooftops, and rescued people idle there (sitting, waving, tending flower boxes).
  Low mist drifts over the grey ground outside the zone and clears inside it, the sky warms toward dawn, and distant
  rooftops light up as each landmark is restored. The styled look uses smooth bands and soft edges instead of dithering,
  with the low resolution and the outlines kept. Scenery is visual only and does not change the rules.
  The look depends on the work: the game starts styled when exported and placeholder otherwise. Pass
  `--look=styled` or `--look=placeholder` to pick the start look (F4 still switches).
- **Checkpoint 6 look:** notices are slim banners under the Dusk to Dawn bar, edge arrows and pointers stay clear of the
  HUD, the styled look has its own HUD text lines and target ring, the stipple is lighter, and running is a real jog
  (wider stride, more lean and bounce, dust at each step in the styled look).
- **Wobble alert (checkpoint 5):** a wobbling person out of view gets a pulsing amber pointer at the screen edge (one per
  nearby cluster; it pulses faster as the wobble runs out), and each wobbler is a pulsing blip on the minimap.
- **Icons:** shield = guarded · running feet = skittish · cloud = glum · umbrella = sheltered (its pips count the four hits left) · ! = faltering. The night
  introduces them one at a time, with a short one-time prompt each.
- **Keys:** WASD move · Shift run · G or Q
  joy burst · Mouse point at people (F2 changes targeting) · Mouse wheel zoom · F3 debug · F4 switch look ·
  R restart · M menu

## How to run

1. Open Godot 4.7.
2. Click **Import** and pick the `project.godot` file in this folder.
3. Press **F5** (or the Play button) to run the game.

## Play

The game opens a menu with one **Play** button. Press **Enter**, **1** or click Play to start the level. The border
variants were retired in round 10; the organic push is the border.

In the level: WASD to move, the mouse to point at people, **G** or **Q** for a joy burst (E is free until you can take a block). A small cue beside the spirit meter glows when G can be used right now. Press **M** at any time to go back
to the menu. **R** restarts the level.

## The living border

- **The town is a grid (0.4).** Five by five cells of 12 m with 10 m streets between them. The middle cell is the start
  square, the four cells next to it on the diagonals are the landmark squares, and the other twenty are solid built
  blocks that nobody walks through.
- **The zone is the cells you hold.** It starts as the start square, once three people are rescued. Its line is the
  outline of the cells you hold: along the face of a held block (or the map's edge) it is a **wall**, which holds
  firm and needs nobody; across a street mouth, or along the open side of a held square, it is a **gate**.
- **People stand on the gates.** The rescued stand across the gates, about 3.7 m apart (a street mouth takes about 3, an
  open square side about 4); with fewer people than that they spread wider. The rest stand inside.
- **The gloom is held back at the gates.** Dimmed people head along the streets for the nearest gate, and lean on it
  from outside: it bends inward where they push, and past a depth it **breaks**, which glows coral and pulses softly.
  Through a break they can get in, and they drain the nearest border person at the full rate. Pressing on an intact
  gate also drains the nearest border person a little (a quarter of the rate). Joy at a bending person, or a burst,
  calms the spot, and a break mends once nobody dimmed is near it and someone beside it has had joy.
- **Relapses.** A border person who relapses steps out through their gate, and the others spread to fill the places.
- **Inside the border the land changes.** The ground is painted warm (it fills in slowly), and blocks inside are
  beautified after a few seconds. A grey person deep inside the border lightens instead of dimming.
- **The zone stays on the start square for now.** Growing it block by block is the next pass; until then the line is
  the start square's four gates.
- **Four landmarks** stand in their own squares on the diagonals next to the start: the **bandstand** (music joy x2),
  the **garden** (nature joy x2), the **bell tower** (border members within 17 m lose 60% less to the gloom) and the
  **gallery** (no boost yet). Hold the square inside the line for 3 seconds to hold the landmark; it loses its boost the
  moment the line drops it. The top right lists the landmarks you hold; an arrow at the screen edge points to each one
  you do not hold.
- **Losing**: if the border has formed and fewer than three people are rescued, the border falls.
- **Calm opening**: the first quarter of the night is calm (almost no grey pressure), then it builds toward midnight.
  Dimmed people arrive sooner than they did, then ease off: the last third of the night is gentler.
- **Dusk to dawn**: a bar at the top shows the night. The level ends at dawn, and reaching dawn wins. The end screen gives
  1 to 3 **dawn lights** and why: 1 for reaching dawn; 2 when two of "40% of the people rescued", "20% of the plaza held"
  and "one landmark held" are met; 3 when 75% of the people are rescued and two landmarks are held at dawn.

## Spirit, going dim and the dance with the gloom (round 12a)

- **Spirit** is your spendable resource (0 to 100, you start with 50). Every rescue gives +20. The joy burst costs 30,
  so with less than that it is unavailable (the HUD says "needs 30 spirit"). Your joy fire rate depends on spirit:
  full at 50 or more, then slower, down to 40% of the rate just above 0. The spirit bar is bottom left, above the burst.
- **Spare spirit warms the border.** When the bar is full, the spirit a rescue would have added is not lost: it goes
  into a pool (up to 40) that slowly tops up the joy of the most strained people on the border, one at a time (about 80
  joy a second in all, 25 joy for each spirit, and only people under 90% of their joy), and they glow softly as it
  reaches them.
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

- **WASD** move, **Shift** run. (E is unbound for now; "Take a block" comes next.)
- **Click** a person to lock on (in lock-on mode). The default is **hover**: the person under the mouse becomes the
  target. **F2** cycles the modes: lock-on, hover (default) and auto (the most urgent person in range).
- Every shot uses the target's element, so it is always a best match. Music is quick and small, art is slow and big
  (it splashes), nature is a floating flower that blooms where it lands.
- **G** or **Q** joy burst (8 s cooldown, costs 30 spirit): dimmed people pressing the border within 8 m are pushed back
  4 m and lifted to gloomy (streaks show it; the HUD says how many are in reach), border folk in range get a joy top-up,
  and it calms the gates near it so they spring back.
- **F3** toggles the debug overlay: cover (`c`) and protection (`p`) above each person, a label per gate (how many
  people it needs, and GAP where a break is open), and the member, inner, gate and night numbers at the top left, and the live floor-effect counts (for example
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
