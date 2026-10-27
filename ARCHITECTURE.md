# ARCHITECTURE (for agents)

PositiveFPS is a gentle top-down territory game in Godot 4.7 (GDScript, strict typing). Dark people slowly take over a
plaza; the player rescues them with joy projectiles, and the rescued form a living border that holds the darkness back
and paints the land inside. One night (dusk to dawn) per level; hold the landmark to win. Player docs: `README.md`.
Ideas and decisions: `IDEAS.md`. Nothing here describes gameplay changes; it describes where things live.

## Scenes
- `menu.tscn` (`scripts/menu.gd`): title, a Look toggle and one Play button (Enter, 1, or click) -> loads `topdown.tscn`.
- `topdown.tscn`: only a `TopDownMain` root. **Everything else is built in code** in `TopDownMain._ready()`.

## Script map (`scripts/*.gd`)
| Script (`class_name`) | Owns | Key public API | Config used |
|---|---|---|---|
| `topdown_main.gd` (`TopDownMain`) | The level: plaza, blocks, people, camera, light, win/lose, wiring of all systems; spirit rewards, dim recovery and the x1.5 border loss while dim (round 12a); round 14: the mouse-wheel zoom (`_zoom_target`, eased in `_update_camera`, scales labels and the look offset), and the midnight stagger (`_try_dim_sink`, the gate a person asks before sinking: one dimmed sink per `DIM_ARRIVAL_MIN_GAP`) | `people`, `border`, `ground`, `player`, `grabs`, `hud`, `minimap`, `night`, `running`, `rescued_count`; `pursuit_assignments()`, `view_half_extents()`, `dim_recovery_rate()` | `TD_PLAZA_SIZE`, `TD_PEOPLE_COUNT`, `TD_CAMERA_*`, `TD_MINIMAP_*`, `TD_DARK_*`, `TD_WANDER_*`, `TD_SPAWN_*`, `TD_COVER_*`, `RNG_SEED` |
| `topdown_player.gd` (`TopDownPlayer`) | WASD movement, aiming, targeting modes, firing, joy burst, **spirit and the dim state, the twirl** (round 12a); round 14: hover is sticky, so a target only changes after F2 or when it becomes invalid | signals `target_changed`, `targeting_changed`, `debug_toggled`, `burst_fired`, `dim_changed`; `target`, `targeting_mode`, `burst_cooldown`, `spirit`, `is_dim`, `twirl_*`; `add_spirit()`, `lose_spirit()`, `fire_rate_mult()`, `can_burst()`, `mini_burst()` | `TD_PLAYER_*`, `TD_TARGETING_*`, `TD_ELEMENT_*`, `TD_BURST_*`, `TD_HIGHLIGHT_*`, `SPIRIT_*`, `DIM_*`, `TWIRL_*` |
| `moods.gd` (`Moods`) | Round 12b: the moods of wistful and gloomy people (guarded turn, skittish scare, glum look-ups) and the sheltering; round 14: each dimmed person shelters only its nearest wistful or gloomy person within `SHELTER_RADIUS` (`_nearest_ward`, ties to the earlier person); round 15: the shield's regrow timer (`shield_down_left`) and the ward's `shielder` link | `update(people, player, delta)`, `is_fleeing()`, `flee_dir()`, static `assign()`; sets `Person.sheltered` / `shelter_ward` / `shielder` / `glum_up` / `flee_left` | `GUARDED_*`, `SKITTISH_*`, `GLUM_*`, `SHELTER_*` |
| `grabs.gd` (`Grabs`) | Round 12a: the grabs of dimmed people (wind-up, lunge, landing, cooldown) and what a twirl does to them | `update(people, player, delta)`, `is_grabbing()`, `is_winding_up()`, `cooldown_left()`; signals `grab_landed`, `grab_avoided(person, perfect)`; sets `Person.grab_frac` / `grab_lunging` / `grab_toward` | `GRAB_*`, `TWIRL_PERFECT_WINDOW` |
| `person.gd` (`Person`) | One person: affinity, joy, gloom, rescued state, grace, visuals, floating numbers; round 12b: `mood`, glancing joy off (guarded) and x3 for a glum look-up, `is_faltering()`; round 14: `shelter_ward`, the `joy_landed` signal; round 15: the shield (`shielder` on the ward; `shield_hits`, `shield_down_left`, `wear_shield()`, `shield_left_frac()` on the dimmed person; a sheltered person's `receive_joy` leaks `SHELTER_LEAK` and wears it) | `receive_joy(element, amount, distance, from)`, `drain_joy()`, `tick()`, `joy_needed()`, `chest_position()`, `active_mood()`, `is_open_to()`, `wear_shield()`, `shield_left_frac()`, fields `gloom`, `joy`, `cover`, `protection`, `is_rescued`, `mood`, `level`; signals `rescued`, `relapsed`, `stage_changed`, `joy_blocked`, `joy_landed` | `JOY_*`, `PERSON_*`, `GRACE_*`, `GLOOM_*`, `MEMBER_FALTER_*`, `STAGE_*`, `SHELTER_*` |
| `gloom_sim.gd` (`GloomSim`) | Static rules: darkening, spreading, draining, protection | `update(people, delta, drain_mult, strength, border)`, `is_dark()`, `protection_for()` | `GLOOM_*`, `SPREAD_*`, `TD_DRAIN_MULTIPLIER` |
| `border.gd` (`Border`) | The living border: loop polygon, members, gaps, posts, push-back, building capture; `loss_mult` and `flicker()` while the player is dim | `update()`, `set_player_dim()`, `on_rescue()`, `on_relapse()`, `cover_at()`, `clip_move()`, `shove()`, `polygon`, `members`, `active`, `segment_is_gap()`, `gap_midpoints()`, `gap_region_count()`, `is_faltering()`, `edge_pressure()` (round 12b: newest/outermost stretch score), `gap_urgencies()` / `falter_urgency()` (round 13b: 0..1 over `GAP_URGENCY_SECONDS`), `landmark_beautified()`; statics `is_inside()`, `gap_flags()` (spacing, empty slots, faltering members, posts), `slot_count_for()` | `BORDER_*`, `MEMBER_FALTER_*`, `GAP_HEAL_DELAY`, `EDGE_*` |
| `building.gd` (`Building`) | One block the border can beautify; lantern + ring if it is a post | `update(delta, inside_fraction)`, `set_post()`, `beautified` | `BORDER_BUILDING_SECONDS`, `BORDER_TINT_SECONDS` |
| `landmark.gd` (`Landmark`) | The beacon block's hold ring and win timer | `update(delta, beautified)`, `progress()`, `is_held()` | `BORDER_LANDMARK_*` |
| `painted_ground.gd` (`PaintedGround`) | 1 m tile grid: paint weight and colour (a MultiMesh), erosion by dark people | `update_paint()`, `paint_weight_at()`, `paint_colour_at()`, `set_region()`, `average_weight(_excluding)()`, `beautified_fraction()` | `TD_GROUND_*`, `TD_PAINT_*`, `TD_ERODE_*`, `GROUND_*` |
| `night_cycle.gd` (`NightCycle`) | Dusk to dawn clock, grey strength, sun and ambient keyframes | `update()`, `progress()`, `strength()`, `is_over()`, `elapsed` | `NIGHT_*` (length, peak, calm opening) |
| `joy_projectile.gd` (`JoyProjectile`) | A shot: music (homing note), art (lobbed blob), nature (flower); impact effects | `launch_velocity()` (static); set `element`, `velocity`, `target`, `people` before `add_child` | `TD_PROJECTILE_*`, `TD_NOTE_*`, `TD_SPLAT_*`, `TD_FLOWER_*`, `TD_PETAL_*`, `TD_TRAIL_*` |
| `bloom.gd` (`Bloom`) | Nature flower patch: pulsed joy to people inside, then fades | set `people` before adding | `TD_BLOOM_*` |
| `floor_effects.gd` (`FloorEffects`) | Registry and cap for transient floor overlays (rings, splats, blooms) | `add()`, `live()`, `enforce_cap()`, `summary()` | `TD_MAX_FLOOR_EFFECTS` and the priority inventory |
| `hud.gd` (`Hud`) | Labels: target element, rescued count, night bar, burst bar, spirit bar, twirl cooldown, alerts, end screen, debug text | `set_*()` (`set_spirit`, `set_twirl`, `set_burst(cooldown, has_spirit)`), `show_alert()`, `show_end()` | (few; mostly literals in `hud.gd`) |
| `minimap.gd` (`Minimap`) | Round minimap: data model (`border_pts`, `member_pts`, `dark_pts`, `blips`, ...) then a 128 px image | `tick(delta)`, `refresh_from(...)`, `radius()`, `add_blip()` | `TD_MINIMAP_*` |
| `gap_arrows.gd` (`GapArrows`) | Coral screen-edge arrows toward off-screen gaps | `update_arrows()`, static `off_screen_arrows()` | `OFFSCREEN_*` |
| `feedback_layer.gd` (`FeedbackLayer`) | Round 13b: screen-space communication overlay on the HUD: faltering markers (feet ring, "!" badge, progress ring, "closed" flash), gap leak motes, mood and shelter icons, tethers and snaps, blocked-joy sparks, player pulses; round 14: `dim_rings`, the falter progress ring on a dimmed person hit by joy; round 15: an umbrella icon's `wear` (its shielder's share left) fades and shrinks it; data model in `markers`, `motes`, `icons`, `tethers`, `snaps`, `sparks`, `closes`, `player_pulses`, `dim_rings` | `tick(delta)`, `on_blocked()`, `on_dim_joy()`, `pulse_player()`, `marker_for()`, `flash_of()` | `FALTER_*`, `LEAK_*`, `MOOD_ICON_*`, `BLOCK_*`, `TETHER_*`, `DIM_RING_SECONDS`, `SHELTER_WORN_ALPHA` |
| `spirit_meter.gd` (`SpiritMeter`) | Round 13b: the 360 px spirit meter over the HUD bar: burst-cost and dim-exit ticks, twirl arc, flash and floating numbers | `set_values()`, `moment(amount, kind)`, `burst_tick_x()`, `dim_tick_x()`; enum `Moment` | `SPIRIT_METER_*`, `SPIRIT_*_COLOUR` |
| `mood_icons.gd` (`MoodIcons`) | Round 13b: the icon shapes (shield, feet, cloud, umbrella, "!") drawn on any CanvasItem | static `draw()`, `kind_for_mood()`, `kind_for_block()` | `MOOD_ICON_COLOURS` |
| `intro.gd` (`Intro`), `prompt_bar.gd` (`PromptBar`) | Round 13b: the layered introduction (dimmed after `NIGHT_CALM_FRACTION`, moods at `MOOD_INTRO_FRACTIONS`) and the one-at-a-time, once-per-level prompt queue; the bar draws the current prompt; round 14: `Prompt.DIM_HELP` | `dimmed_allowed()`, `mood_active()`, `request()`, `update()`; fields `current`, `queue`, `shown` | `MOOD_INTRO_FRACTIONS`, `PROMPT_*`, `INTRO_*`, `DIM_HELP_TEXT` |
| `controls.gd` (`Controls`) | Registers every InputMap action (no raw keys elsewhere); round 14: `zoom_in` / `zoom_out` on the mouse wheel | `setup()` | none |
| `config.gd` (`Config`) | All tuning constants and tiny pure helpers | `multiplier()`, `falloff()`, `gloom_level()`, `is_automated_test()` | n/a |

## Looks (rules vs visuals, `scripts/looks/`)
Every main thing on screen is split into a **rules script** (the table above) and a **look**: a node/object that reads the
rules' public state and draws it. Rules scripts never reach into look internals; they only call the generic look API
(`sync()`, `play_bounce()`, `refresh()`, `set_post()` ...). Looks: `PersonLook`, `PlayerLook`, `BuildingLook`,
`LandmarkLook`, `GroundLook`, `BorderLook`, `MinimapLook`, `PlazaLook`, each with `*_placeholder.gd` (plain shapes, the
tests' default) and `*_styled.gd` (the locked art style; shaders in `shaders/`, builders in `style_kit.gd`,
`style_people.gd`, `style_buildings.gd`). `ViewPipeline` (`view_pipeline.gd`) owns the camera and post-process: styled
mode moves the camera into a 640x360 SubViewport that shares the world, with nearest upscale and outlines.
- `Looks` (`looks.gd`) holds the mode (`PLACEHOLDER` default, `STYLED`; static, so the menu choice lasts for the session),
  the factories, and the fallback registry. A kind with no styled look returns its placeholder and registers itself with
  `Looks.note_placeholder(obj, kind)`; F3 shows `Looks.debug_line()` (`placeholder_fallback_count()`).
- F4 (`toggle_look` action) calls `TopDownMain.set_look()`: every object calls its own `rebuild_look()`, game state is
  untouched. The menu has a "Look" button.
- **Gameplay rounds** add a placeholder look only (extend the base look class and the placeholder; new loose things
  simply register as placeholder). **Style rounds** add the styled look for what is still listed by F3, then playtest.
- Pixel view and the mouse: in styled mode window mouse coordinates are divided by `pipeline.view_scale()` before
  `camera.project_ray_*` (the player's `mouse_mapper`); use `TopDownMain.world_to_screen()` (not `camera.unproject_position`)
  for window positions. The HUD, minimap and gap arrows stay in the window at full resolution.
- Checkpoint renders: `python tools/checkpoint_shots.py` (scripted scenario in `tools/checkpoint/checkpoint_shots.gd`,
  both looks, `design/renders/checkpoint_01/`; needs a real window, about 20 s). Look at the PNGs; write `NOTES.md` there.
- Tests run in the placeholder look; `tests/looks_test.gd` switches to styled on purpose and always switches back.
  Headless uses a dummy renderer, so shaders are not compiled by the tests; the screenshot run is the shader check
  (grep its log for errors).

## Where tuning lives (`scripts/config.gd`)
**Round 15 (shield):** `SHELTER_LEAK` (0.25), `SHELTER_HITS` (4), `SHELTER_REGROW` (8.0 s), `SHELTER_POP_PUFF`, `SHELTER_WORN_ALPHA`. The "Round 15" block sits after the round 14 block.
**Round 14 (balance):** `LEVEL_JOY_MULT` (dimmed 1.6), `DIM_ARRIVAL_MIN_GAP` (6 s), `DIM_RING_SECONDS`, `DIM_HELP_TEXT`,
`TD_ZOOM_MIN` / `TD_ZOOM_MAX` / `TD_ZOOM_STEP` / `TD_ZOOM_EASE`. The camera reference size is `TD_CAMERA_ORTHO_SIZE`
(19.5, the default zoom); `TD_CAMERA_LOOK_OFFSET` and `TD_UI_SCALE` are also at the default zoom and scale with it.
Top: element enum, joy numbers, person look. `TD_*` block ("Territory game", ~line 69): plaza, people, gloom, drain, wander,
camera, player, projectiles, blooms, ground, HUD, minimap. "Round 10: the floor" (~318): the floor-overlay priority
inventory and cap. "Round 9: the living border" (~356): `BORDER_*`, landmark, night. "Round 10: easier growth" (~425):
calm opening and friendlier numbers. The matchup table and helpers are at the bottom. Rule: no magic numbers in other scripts.
**World scale (round 13a):** `Config.WORLD_SCALE` (100/70) scales TERRITORY constants (plaza, blocks, spawn, border spacing/gap/push/radii/bands, cover, erosion, paint and contagion radii, search reach); INTERACTION and BODY constants (sizes, projectile ranges and speeds, `TD_AUTO_RANGE`, `GRAB_*`, `SHELTER_RADIUS`, `SKITTISH_RADIUS`, hit radii, press and shove range) are not; per-metre rates are divided by it. New distances: decide which kind, and write `* WORLD_SCALE` in the const if territory. Test: `world_scale_test.gd`.

## Data flow per frame (`TopDownMain._process`)
1. `_update_camera`, `_update_highlight`, `_update_readability` (minimap refresh about every 0.1 s, gap arrows) run even when ended.
2. If `running`: `night.update` -> HUD night bar and light.
3. `border.update(people, delta, strength)`: members, gaps, push-back, building capture, loop polygon, ground region.
4. `_update_people`: steer unrescued people (grabbers stand still; scared skittish people back away; dimmed people reach for a non-dim player; else pursue a rescued person (lowest protection, then the newest/outermost stretch, `Border.edge_pressure`; dimmed pursuers of a border member walk up to the line), edge-seek if dark, else wander). Then `Moods.update` (sheltering flags, guarded turn, skittish scare, glum look-ups).
5. `_update_cover` (every `GROUND_UPDATE_INTERVAL`): `Person.cover` and `protection` from the border depth or the paint.
6. `_update_dim` (border and ground `loss_mult`, dim recovery), `GloomSim.update` (drain x `border.loss_mult`): darken, spread, drain. `Grabs.update`. Then `Person.tick` for each person.
7. `ground.update_paint` (paint spreads around rescued people, fades, erodes at the edge), `landmark.update`, HUD spirit, burst and twirl, `_check_end`.
Player physics (`TopDownPlayer._physics_process`) and projectile physics run on the 60 Hz physics tick, separately.

## Tests (`tests/*_test.gd`, gdUnit4 v6.2.2)
- **Input-driven**: level tests use `TopDownTestUtil.level_runner(self)` (sets the 1280x720 window, loads `topdown.tscn`) and
  drive real key and mouse events with `scene_runner` (`simulate_key_pressed`, `simulate_mouse_move`, `simulate_frames`).
  Pure rules (border geometry, gloom, config) are called directly with no scene.
- **The intro flag (round 13b):** `Config.intro_on()` is true in the game and false under automated tests (a test sets `Config.intro_override` to 1 or 0, and back to -1), so older scenario tests see no dormant moods, no held-back dimmed people and no prompts. `intro_test.gd` sets the override in `before_test` and clears it in `after_test` (set it BEFORE `level_runner`: the level reads it in `_ready`). With it off, `Intro.request()` never shows anything.
- **Moods in tests:** every person gets a mood at spawn (`Moods.assign`); `place()` and `send_everyone_away()` reset it to none so older tests see plain people. Tests of moods set `p.mood` after placing.
- **Helpers** in `tests/topdown_test_util.gd`: `send_everyone_away`, `place`, `screen_of`, `projectiles`, `blooms`,
  `select_mode` (real F2 presses), `clear_spot`, `leave_loaded_scene`. Suites must be independent: each builds its own scene
  and never relies on another suite having run (they run in separate Godot processes).
- **Determinism**: every run uses `--fixed-fps 60` and `Config.RNG_SEED`; there is no wall-clock in game logic. Never use
  `simulate_frames(n, ms)` with a delay: it waits real timers.
- **Test mode**: `POSITIVEFPS_TEST=1` or headless -> `Config.is_automated_test()` is true; the game never captures the real OS mouse.
  The window title says it is a test. The level test util switches the minimap's automatic redraw off (8 ms per redraw);
  `readability_test.gd` and the landmark test cover it.
- **Speed**: `tools/run_tests.py` splits suites (and slow tests, listed in `tools/test_weights.json`) over parallel Godot
  processes. Refresh the weights with `python tools/run_tests.py --update-weights` when tests change a lot.

## Known gotchas
- gdUnit delivers a key press **twice** to the root scene's `_unhandled_input`; handlers must tolerate it (`menu.gd` guards its Play action).
- `Input.action_press()` does not reach `_unhandled_input`; tests send real `InputEvent`s through the scene runner.
- `MultiMesh` colour readback is zero in headless mode: test `PaintedGround.paint_colour_at()` or weights, not pixels.
- The nested `design/style_test` project has its own `project.godot`; Godot ignores it. `design/` is never committed by agents or gated.
- Windows long paths: keep temp copies in short paths (coverage copies to `.coverage_build/`, excluding `design/`).
- The console is cp1252: `tools/run_tests.py` and `gate.py` reconfigure stdout to UTF-8; keep non-ASCII out of `print` elsewhere.
- The gdUnit CLI shrinks the window to 64x64; set `get_window().size` before loading a scene that lays out at `_ready`.
- Hover targeting is sticky: a target stays while valid. A test that wants another target cycles F2 first, with the mouse off
  everyone (`TopDownTestUtil.clear_spot`), or the old target is kept.
- Wanderers move about a metre in a few seconds. Tests that need exact positions (a tie) call the rule directly with no frames.
- The midnight stagger (round 14) holds dimmed sinks to one per `DIM_ARRIVAL_MIN_GAP`. A test that places several dimmed people
  at once calls `TopDownTestUtil.open_dim_gate(td)` between them; other people who would sink during a test are kept light.
- A parse error in a test file makes gdUnit skip that suite quietly while its own summary still says all passed. `tools/run_tests.py` now catches this (`integrity_problems()`: it fails on `Parse Error` / `SCRIPT ERROR` / failed-to-load-script in any Godot output, and when a `tests/*_test.gd` suite reports no or fewer results than it declares); `tools/test_gate.py` proves it with a broken scratch suite.
- Strict typing: warnings are errors (`project.godot`). Type every `for` variable; avoid iterating arrays that may hold freed nodes.
- **Timing tests**: a test that asserts wall-clock time must be named `test_perf_*` and guard its time assert with
  `if OS.get_environment("POSITIVEFPS_PERF_ENFORCE") == "1":`. `run_tests.py` then keeps it out of the parallel plain batch and runs
  it alone, plain, afterwards (budget enforced); the instrumented coverage run still executes it (lines counted) but does not time it.
  Set the budget to max of 5+ serial runs x 1.5 and record the runs next to the assert (example: `world_scale_test.gd`).
- Coverage ignores lambda bodies passed as multi-line arguments; hoist them into a `var` to measure them.

## Quality gate and tools
- `python tools/gate.py` = lint + all tests (parallel, about 25 s). `--full` = lint + tests with line coverage + ratchet (about 35 s).
  `--no-cache` ignores the result cache. The pre-commit hook runs `gate.py --hook`: the same, upgraded to `--full` when
  `coverage_baseline.json` is staged. A passing result is cached by a sha256 of the working tree (`.git/positivefps-gate-cache.json`).
- **Every round must end with `python tools/gate.py --full`, then `python tools/coverage.py --check-determinism`, then a baseline
  commit** (`python tools/coverage.py --update-baseline`). The hook alone does not run the coverage ratchet.
- Timing tests (`test_perf_*`, see Known gotchas) run serially and uninstrumented after the parallel batch: inside `run_tests.py`
  for the default tier, and via `run_tests.py --perf-only` after the coverage run in `--full` (about 5 s; skips Godot `--import` when the
  class cache is current). `gate.py`'s cache fingerprint already covers `tests/` and `tools/`, so it is unchanged.
- Other tools: `lint.py [--fix]`, `coverage.py`, `cleanup_worktrees.py`, `install_hooks.py`. Timing history: `tools/BUILD_TIMINGS.md`.

## Agent workflow rules
- Godot runs headless only; never open the editor GUI. Console exe path: `tools/run_tests.py` (`GODOT` env var overrides).
- Commit with explicit paths (`git add <files>`), never `git add -A`; never stage `design/`; never `--no-verify` or amend; never push.
- Never kill processes you did not start. Never lower `coverage_baseline.json`. Scratch work goes in `.scratch/` (gitignored); delete it.
- Run long commands in the foreground (they take under a minute now). Finish a round with the full gate, not just the hook.

## How to brief an agent (files to read first)
- **Border / territory**: `scripts/border.gd`, `building.gd`, `landmark.gd`, `painted_ground.gd`; tests `border_*_test.gd`, `edge_pressure_test.gd`, `cover_test.gd`; config `BORDER_*`.
- **People / gloom / night**: `person.gd`, `gloom_sim.gd`, `night_cycle.gd`, `topdown_main.gd` (`_update_people`, `pursuit_assignments`); tests `person_test`, `gloom_sim_test`, `night_cycle_test`, `topdown_crowd_test`.
- **Projectiles / blooms / floor effects**: `joy_projectile.gd`, `bloom.gd`, `floor_effects.gd`; tests `projectile_*_test.gd`, `floor_test`, `paint_bloom_camera_test`.
- **Targeting / input**: `topdown_player.gd`, `controls.gd`; tests `targeting_test`, `topdown_mode_test`, `grace_cue_test`.
- **Moods / sheltering / local gaps / edge pressure / stage changes** (round 12b): `moods.gd`, `person.gd` (`receive_joy`, `_check_level`), `border.gd` (`_assign_members`, `_update_falter`, `edge_pressure`, `gap_flags`), `topdown_main.gd` (`_weakest_with_slot`, `_stop_distance`, `_may_loom`, `_on_stage_changed`), `looks/person_look.gd` (mood tells, `play_ripple`), `minimap.gd` (blips); tests `moods_test`, `local_gap_test`, `stage_change_test`; config "Round 12b".
- **Spirit / dim / grabs / twirl** (round 12a): `topdown_player.gd`, `grabs.gd`, `topdown_main.gd` (`_update_dim`, `dim_recovery_rate`, `_reaches_for_player`), `border.gd` (`loss_mult`), `painted_ground.gd` (`loss_mult`); tests `spirit_test`, `grab_test`; config `SPIRIT_*`, `DIM_*`, `GRAB_*`, `TWIRL_*`.
- **Looks / styled art**: `scripts/looks/*`, `shaders/*`, `topdown_main.gd` (`set_look`); tests `looks_test`; tool `checkpoint_shots.py`.
- **Zoom / camera** (round 14): `topdown_main.gd` (`_update_camera`, `_view_centre`, `view_half_extents`, `_unhandled_input`
  zoom branch); `controls.gd`; tests `zoom_test`, `world_scale_test`, `paint_bloom_camera_test` (ring fit at default).
- **Sheltering / dimmed help / midnight stagger** (round 14): `moods.gd` (`_assign_wards`), `person.gd` (`shelter_ward`,
  `joy_landed`, `dim_gate`, `_check_level`), `topdown_main.gd` (`_try_dim_sink`, `_on_joy_landed`), `feedback_layer.gd`
  (`dim_rings`); tests `shelter_nearest_test`, `dimmed_help_test`, `stagger_test`.
- **The shield** (round 15): `person.gd` (`receive_joy` sheltered branch = the hit hook, `wear_shield`, `shield_left_frac`),
  `moods.gd` (`update` cooldown and undim reset, `_assign_wards`), `feedback_layer.gd` (`_update_icons` `wear`, `_draw_icon`);
  tests `shield_test` (the rule and input-driven hover fire), `moods_test` / `feedback_test` / `intro_test` /
  `shelter_nearest_test` (updated for the leak).
- **Communication / introduction** (round 13b): `feedback_layer.gd`, `spirit_meter.gd`, `mood_icons.gd`, `intro.gd`, `prompt_bar.gd`, `topdown_main.gd` (`_build_feedback`, `_update_feedback`, `_unlock_moods`, `_hold_back_dimmed`, `_update_intro`), `border.gd` (`gap_urgencies`), `gap_arrows.gd`, `minimap.gd` (`gap_markers`), `person.gd` (`joy_blocked`, `mood_unlocked`); tests `feedback_test`, `intro_test`; config "Round 13b". The new overlays are screen-space UI (both looks); the style rounds need not restyle them unless asked.
- **HUD / minimap / camera**: `hud.gd`, `minimap.gd`, `gap_arrows.gd`, `topdown_main.gd` (`_update_camera`, `view_half_extents`); tests `hud_test`, `readability_test`, `debug_overlay_test`, `menu_test`.
- **Tooling**: `tools/gate.py`, `run_tests.py`, `coverage.py`, `lint.py`, `.githooks/pre-commit`, `tools/COVERAGE_TOOL_NOTES.md`.
- Always also read: this file, the config section you touch, and `tests/topdown_test_util.gd` before writing a level test.
