# ARCHITECTURE (for agents)

PositiveFPS is a gentle top-down territory game in Godot 4.7 (GDScript, strict typing): dimmed people take over a plaza,
the player rescues them with joy, the rescued form a living border. One night (dusk to dawn) per level, rated 1-3 dawn
lights. Player docs: `README.md`. Design and state: `IDEAS.md` ("Current state"; history in `IDEAS_RESOLVED.md`).
This file says where things live, not how the game plays. Project rules (commits, scratch, processes, no loosening) are
in `CLAUDE.md`.

**Read only the sections you need: Known gotchas and Quality gate always; your area's line in "Areas"; Looks only if you
touch looks.** To find code, search `SOURCE_MAP.md` (generated: `python tools/source_map.py`; every script's public
functions with line numbers) and Read only those lines.

## Scenes
- `menu.tscn` (`scripts/menu.gd`): title, Look toggle, Play (Enter, 1, click) -> `topdown.tscn`.
- `topdown.tscn`: only a `TopDownMain` root; **everything else is built in code** in `TopDownMain._ready()`.
- **`TopDownMain` only coordinates** (about 220 lines): `_ready` builds the systems in order, `_process` calls them in
  order, and each system's set-up and per-frame work lives in its own script (below). Order matters (child order and
  signal-connection order are part of the simulation): keep each call where it is when adding one.
- Systems that attach to the level use `X.attach(main)` (one line in `TopDownMain`, stored as `main.x`): `BurstCue`,
  `FirstLight`, `SpiritWarmth`, `WobbleAlert`, `GloomTide`, `TargetHighlight`. New systems should do the same and
  never add logic to `topdown_main.gd`; its helpers (`main.plaza`, `main.camera_rig`, `main.events`, `main.level_hud`,
  `main.level_end`, `main.dim_gate`, `main.cover_update`, `main.dim_recovery`) are plain objects built with `X.new(main)`.

## Script map (`scripts/*.gd`)
- `topdown_main.gd`: the level coordinator (builds the systems, calls them each frame, F4 and input routing). Its helpers: `plaza.gd` (floor, walls, `BLOCK_*`, spawn spots, the level's `rng`, `near_block`), `camera_rig.gd` (environment, sun, camera, wheel zoom), `target_highlight.gd` (the ring under the target), `level_hud.gd` (builds and updates the HUD layer, the F3 debug overlay), `level_events.gd` (rescue, relapse, joy, burst, grab, dim and landmark handlers), `level_end.gd` (win/lose, rating, leaving the level), `dim_gate.gd` (the midnight stagger), `cover_update.gd` (cover and protection), `dim_recovery.gd` (the dim player's recovery), `look_switch.gd` (F4); `crowd_movement.gd`: unrescued people's movement (separation uses a spatial grid, `rebuild_grid()`, and a cached index)
- `topdown_player.gd`: movement, aiming, targeting, firing, burst, spirit and the dim state, sticky hover; `controls.gd`: every InputMap action (no raw keys elsewhere)
- `person.gd`: one person (affinity, joy, gloom, rescued, wobble, shield, react); `moods.gd`: guarded/skittish/glum and sheltering; `grabs.gd`: dimmed grabs
- `gloom_sim.gd`: dimming, spreading, draining; `night_cycle.gd`: clock, strength, `dim_gap_at()`; `relapse_wave.gd`: relapse gate; `first_light.gd`: dawn rally
- `town_grid.gd` (`TownGrid`): the plan of the town, a 5 x 5 grid of 12 m cells (the start square's column and row 18 m wide, so the blocks beside it are 18 x 12) with 12 m streets, 114 m across (`Config.TD_PLAZA_SIZE`; cells, kinds, rectangles, neighbours, the tile lattice); `zone.gd` (`Zone`): the cells you hold and the outline of them, split into walls and gates (see Areas)
- `border.gd`: the living border (the traced line `polygon`, members on gates, breaks, push); `border_slots.gd`: who stands on which gate; `border_shape.gd`: pure static geometry (inside, crossings, block walks; call `BorderShape.X`; new pure border rules go here)
- `border_push.gd`: the physical push (pushers and the tide's wave dent the gates, calm, breaks and mending), owned by `Border` as `border.push`; `burst_cue.gd`, `burst_fx.gd`, `burst_clear.gd`: the G/Q burst (cue, world marks, rules); `spirit_warmth.gd`: spare spirit warms strained members
- `building.gd`, `landmark.gd`, `landmarks.gd`: blocks, the four landmarks and boosts; `dawn_rating.gd`: pure 1-3 lights rules
- `painted_ground.gd`: 1 m paint grid; `joy_projectile.gd`, `bloom.gd`: shots; `floor_effects.gd`: floor overlay registry/cap
- `hud.gd`, `hud_safe_area.gd`, `minimap.gd`, `gap_arrows.gd`, `wobble_alert.gd`, `landmark_pointers.gd`: HUD, minimap, edge pointers (`HudSafeArea` is the one safe rectangle they share)
- `feedback_layer.gd`, `spirit_meter.gd`, `mood_icons.gd`, `intro.gd`, `prompt_bar.gd`: screen-space cues, prompts and `Intro.notice(id, words)`
- `recorder.gd`: gameplay recorder; `config.gd` + `*_config.gd`: all tuning, one config script per system (see Tuning)

## Areas (where to start; tests are `tests/<name>.gd`)
- **Border / territory (walls and gates, 0.4):** E-only growth (Grid fixes): `take_block.gd` (hold E, point, release; free when `RescuePips.is_ready`, else `TAKE_SPIRIT_COST`; people never refuse; `taken`/`refused` signals; takeable-cell glow `mark_of`/`mark_rects`, the pulse and the preview label), `rescue_pips.gd` (pips only: a cell never joins by itself), `gate_marks.gd` (members/need label on each gate, the push glow, `GateMarks.pointers` for the gap arrows); also `zone.gd`, `town_grid.gd`, `border.gd`, `border_slots.gd`, `border_shape.gd`, `border_push.gd`, `edge_ribbon.gd`, `building.gd`, `painted_ground.gd`; tests `zone_test`, `town_layout_test`, `border_level_test`, `border_gates_test`, `border_push_test`, `border_shape_test`, `push_defence_test`, `edge_ribbon_test`, `edge_pressure_test`, `cover_test`; config `BORDER_*`, `GATE_*`, `PUSH_*`, `TOWN_*`. **The zone** (`Border.zone`, a `Zone`) is the set of held cells (it starts as the start square; `held`, `has`, `can_take(cell)`, `take(cell)`, `lose(cell)`, `preview(cell, adding)` for the gates a change opens and closes and the members they need, `members_needed()`, `gates`, `runs`, `centre()`, `contains(pos)`, `version`). Its **line** is the outline traced on the tile lattice (5 x 5 cells, 4 + 4 street strips and 16 crossings): a **wall** runs along the face of a held built block or the map's edge (firm, needs nobody, never dents), a **gate** along an open side of a held square or across a street mouth (a street strip is held only when both its cells are, a crossing when all four are; a cell the zone surrounds joins by itself). `Border._trace()` (when `zone.version` changes) turns the runs into `polygon` points: a corner per wall, a point every `GATE_POINT_STEP` m along a gate; `point_gate`, `point_dentable`, `is_wall(seg)`, `gate_point(g, t)`, `out_at(pos)`, `nearest_point`. Members stand only on gates (`BorderSlots`: a gate needs its length over `BORDER_TARGET_SPACING`, rounded up; fewer people are shared out in proportion; the rest are inner and stand on the zone's open ground). A break is a gap made by pushing (`BorderPush`): `Border.update` calls `push.update`, then builds the dented polygon (`_dented`), and `segment_gap` marks the broken segments; `push.carry` keeps dents and breaks at the points that survive a re-trace. Pushers are dimmed people within `PUSH_LEAN_RANGE` outside a gate (a wall is never pressed) and the night's surge (`GloomTide` calls `push.set_gate_wave` with the gates it pushes and their shares). **Pressure (0.4, #12 #13 #14):** a gate breaks at `Border.break_depth(g)` = `PUSH_BREAK_DEPTH` x lerp(`THIN_LINE_MIN_STRENGTH`, 1, `gate_fill(g)`, its members over its need) x its `strength_mult`; the members of a short gate stand further apart (`BorderSlots.share_out`). Defence interface (the Defences pass codes against it): `Border.set_gate_modifiers(g, {"strength_mult", "cannot_break", "cannot_lose"})` / `gate_modifiers(g)`, kept by the gate's `key` across re-traces and dropped when the gate closes (`gate_closed(old index)`); `cannot_break` gates dent but never snap, `cannot_lose` gates keep the cells beside them (`Zone.cells_behind`). A gate broken `GATE_LOST_SECONDS` loses the cell behind it (`Zone.cell_behind`; never the start square; cut-off cells go too): `Border._track_losses` -> `cells_lost(cells, gate)`, `last_loss` for the recorder, `RescuePips.reset`, and `LevelEvents.on_cells_lost` (banner `Intro.Prompt.LOST` + `LostPulse`, grey). Dimmed people outside head for the nearest gate along the streets (`Border.route_to_gate`, a flow over the walkable tiles); a person caught inside an intact gate that springs back is swept out (`_sweep_out`).
- **Landmarks / dawn rating / town layout:** `landmark(s).gd`, `dawn_rating.gd`, `level_end.gd` (`check`), `town_layout.gd`; tests `landmarks_test`, `dawn_rating_test`, `reactions_test`, `town_layout_test`, `style_props_plaza_test`; config `LANDMARK_*`, `DAWN_*`, `TOWN_*`. A landmark is held while its square (a `TownGrid` landmark cell: the four diagonals next to the start) is in the zone for the claim hold. **Town layout:** `TownGrid` is the plan; `Plaza.BLOCK_POSITIONS` are the twenty block cells (12 x 3 x 12 solid, 18 x 12 or 12 x 18 beside the start square; `Plaza.block_size(i)`); `town_layout.gd` answers the props' questions (lamps against block faces, a bench and planter on each block's face toward the start, stalls on the start square); `StyleProps.layout_streets` and `layout_props` follow it. Landmark positions are in the spawn exclusion (`near_block`): a layout change shifts the spawns and the gloom, so check a bot night, not only the gate.
- **People / gloom / night / waves:** `person.gd`, `gloom_sim.gd`, `night_cycle.gd`, `relapse_wave.gd`, `first_light.gd`, `crowd_movement.gd`; `gloom_tide.gd` (class `GloomTide`; since Pressure #14 the night's ONE surge, not two tides: `surge` Dictionary, `Phase` IDLE / WARNING / SURGE / AFTERMATH / DONE; picks one of 16 `streets()` that meets a zone gate at the warning, peaks at midnight; pushes the gate it meets at full and its line neighbours at `SURGE_SIDE_SHARE`; sets `NightCycle.chill` (cooler light) and `arrival_ease` (dimmed arrivals ease in the aftermath, read by `dim_gate.gd`); fog band, pointer and `Minimap.surge_from/dir/front` mark; signals `surge_warned/started/ended`), `lost_pulse.gd`; tests `person_test`, `gloom_sim_test`, `night_cycle_test`, `topdown_crowd_test`, `dimmed_waves_test`, `first_light_test`, `gloom_tide_test` (the surge), `gloom_tide_edges_test`, `pressure_test`, `pressure_balance_test` (real level runs: compact zone keeps its cells through the surge, over-reached zone loses one); config `GLOOM_*`, `NIGHT_*`, `SURGE_*`, `DIM_*`, `WOBBLE_*`, `FIRST_LIGHT_*`, `THIN_LINE_*`, `GATE_LOST_*`. The surge runs only when `Config.tides_on()` (tests turn it on with `tides_override`). Recorder events `surge_warn/start/end` and `cell_lost` (old `tide_*` still read by the analyser's SURGE section).
- **Moods / shelter / shield / guarded wedge / hover:** `moods.gd`, `person.gd` (`receive_joy`, `shot_lands_now`), `topdown_player.gd` (`_update_hover_target`), `feedback_layer.gd`; tests `moods_test`, `shield_test`, `shelter_nearest_test`, `guarded_wedge_test`, `hover_stick_test`, `stagger_test`; config `GUARDED_*`, `SKITTISH_*`, `GLUM_*`, `SHELTER_*`, `HOVER_*`.
- **Spirit / dim / grabs / spirit actions:** `topdown_player.gd`, `grabs.gd`, `burst_cue.gd`, `burst_fx.gd`, `burst_clear.gd`, `spirit_warmth.gd`; the only spirit action is the burst (G or Q; E takes a block, see Border / territory), and there is no patch action; tests `spirit_test`, `grab_test`, `spirit_warmth_test`, `burst_cue_test`, `burst_clear_test`, `defence_cues_test`; config `SPIRIT_*`, `DIM_*`, `GRAB_*`, `BURST_*`, `SPARE_*`.
- **Projectiles / blooms / floor effects:** `joy_projectile.gd`, `bloom.gd`, `floor_effects.gd`; tests `projectile_*_test`, `floor_test`, `paint_bloom_camera_test`.
- **Targeting / input / zoom / camera:** `topdown_player.gd`, `controls.gd`, `camera_rig.gd` (`update`, `view_half_extents`, wheel zoom); tests `targeting_test`, `topdown_mode_test`, `zoom_test`, `world_scale_test`.
- **HUD / minimap / cues / intro:** `hud.gd`, `minimap.gd`, `gap_arrows.gd` (the pointer to an off-screen break; `LevelHud` also feeds it the gates bent past half the break depth, `GateMarks.pointers`), `wobble_alert.gd`, `feedback_layer.gd`, `intro.gd`, `prompt_bar.gd` (every prompt and notice is a slim banner under the night bar). `edge_markers.gd`, `edge_marker_fx.gd` and `border_warning.gd` are deleted; do not reintroduce them. Tests `hud_test`, `readability_test`, `feedback_test`, `intro_test`, `debug_overlay_test`, `menu_test`. These are screen-space UI: both looks draw them.
- **Looks / styled art:** `scripts/looks/*`, `shaders/*`, `look_switch.gd` (F4, via `TopDownMain.set_look`); tests `looks_*_test`; tool `checkpoint_shots.py`. See Looks.
- **Recorder:** `recorder.gd`; tests `recorder_test`, `python tools/test_analyse_recording.py`.
- **Tooling:** `tools/*`, `.githooks/pre-commit`, `tools/COVERAGE_TOOL_NOTES.md`; self-checks in `tools/test_*.py`.
- Before writing a level test read `tests/topdown_test_util.gd`.

## Looks (rules vs visuals, `scripts/looks/`)
- Every main thing on screen is a **rules script** plus a **look** that reads its public state and draws it. Rules scripts
  never reach into look internals; they call only the generic look API (`sync()`, `play_bounce()`, `refresh()`, `set_post()`,
  `rebuild_look()` ...). Looks: `PersonLook`, `PlayerLook`, `BuildingLook`, `LandmarkLook`, `GroundLook`, `BorderLook`,
  `MinimapLook`, `PlazaLook`, each with `*_placeholder.gd` (plain shapes, the tests' default) and `*_styled.gd` (locked art
  style; shaders in `shaders/`, builders in `style_kit.gd`, `style_people.gd`, `style_buildings.gd`, other `style_*.gd`).
- `Looks` (`looks.gd`) holds the mode (static, `PLACEHOLDER` default or `STYLED`), the factories and the fallback registry:
  a kind with no styled look returns its placeholder and calls `Looks.note_placeholder(obj, kind)`; F3 lists these.
  F4 (`toggle_look`) calls `TopDownMain.set_look()`, every object calls `rebuild_look()`, game state is untouched.
- **Start look:** `Looks.start_mode(args, exported)` (`looks.gd`). A `--look=styled|placeholder` user argument
  (`Config.CP7_LOOK_ARG`) wins; otherwise exported builds (`OS.has_feature("template")`) start styled, and the editor,
  tests and headless runs start placeholder.
- **Styled scenery and atmosphere** (visual only: they read the paint weight, the night clock and the landmarks, and never
  write them): `style_props.gd` (street props: lamp posts, benches, planters, market stalls, bunting and washing lines,
  MultiMesh), `style_ambient.gd` (butterflies, fireflies, birds on beautified roofs, idling rescued people),
  `style_atmosphere.gd` (the gloom mist plane, `shaders/style_mist.gdshader`; the sky warming toward dawn; skyline lights
  as landmarks are held), `style_push.gd` (the styled gloom tide: pixel fog banks and the figures in them).
- **Styled shading:** smooth toon bands and soft alpha falloff instead of dither patterns, with the low resolution and
  the outlines kept.
- **Gameplay work adds a placeholder look only** (extend the base look class and the placeholder). Styled work happens
  only in look-focused targets (formerly graphics checkpoints).
- `ViewPipeline` owns camera and post-process: styled mode renders in a 640x360 SubViewport with nearest upscale and outlines.
  Window mouse coordinates are divided by `pipeline.view_scale()` before `camera.project_ray_*`; use
  `TopDownMain.world_to_screen()` (not `camera.unproject_position`) for window positions. HUD, minimap and edge pointers
  stay in the window at full resolution. Screen-space UI branches on `Looks.is_styled()` at draw time (`style_ui.gd`, `style_feedback.gd`, `style_hud.gd`, `StyledPanel` kinds drawn by `StyleHudText` / `StyleDawn`).
- Ground cues of person looks are hooks in `PersonLook` overridden by `PersonLookStyled`. `Gait` (`looks/gait.gd`) follows real movement for the walk and the player's jog; `StyleWalk` poses styled bodies; placeholder capsules only bob.
- `HudSafeArea` is the one place that works out the rectangle edge pointers keep inside (window less HUD panels, minimap, spirit cue).
- **Shader instance buffer:** every mesh using `style_toon.gdshader` reserves 16 vec4 of
  `rendering/limits/global_shader_variables/buffer_size` (262144 in `project.godot`), hidden meshes included; a styled level
  peaks near 4344 of 16384 meshes. `tests/shader_instances_test.gd` fails if twice the worst case exceeds capacity: check it
  before adding many instance-uniform meshes. Keep the toon `tint` a packed float (a vec4 overflowed the buffer).
- Tests run in the placeholder look; `tests/looks_test.gd` switches to styled on purpose and switches back. Headless uses a
  dummy renderer, so shaders are not compiled by tests: the screenshot run is the shader check (grep its log for errors).
- **Checkpoint renders:** `python tools/checkpoint_shots.py [--set round19|round20|round24|checkpoint7]` (needs a real window, 45-90 s, quits
  itself; output in `design/renders/checkpoint_NN/`; look at the PNGs and write `NOTES.md` there). If it hangs, a script has a
  parse error or the class cache is stale: run `python tools/run_tests.py --suites looks_checkpoint5_test` first, or run the scene with `--timeout 90` and read the output.

## Tuning (`scripts/config.gd` and `scripts/*_config.gd`)
- **One config script per system**, constants filed by system, not by round. `Config` (`config.gd`) keeps only the shared
  core: `WORLD_SCALE`, the elements and joy matchups, plaza size, people count, `RNG_SEED`, and the pure helpers
  (`multiplier`, `falloff`, `gloom_level`, `intro_on`, `tides_on`, `is_automated_test`). The rest is read as
  `<System>Config.X`: `BorderConfig` (members, slots, gaps, ribbon, edge pressure, zone control), `PushConfig`,
  `NightConfig` (night curve, dimmed arrivals, first light, tides), `PeopleConfig` (gloom, relapse, wobble, wandering,
  spawn, grace, reactions), `MoodConfig` (moods, shelter, shield readability), `GroundConfig` (paint, cover, contagion,
  erosion), `ProjectileConfig`, `PlayerConfig` (camera, zoom, targeting, hover, player marker), `SpiritConfig` (spirit,
  dim, grabs, burst, spare spirit), `LandmarkConfig` (landmarks, dawn rating), `TownConfig` (the town
  grid, props), `HudConfig` (HUD, minimap, notices, intro, cue panel, edge pointers), `RecorderConfig`,
  `StyleConfig` (styled-look numbers; the rules never read them). (0.4 pass 2 deleted `BeaconConfig` and
  `RoundLoopConfig` with the beacon and the round loop; the walls-and-gates constants are in the "Walls and gates"
  blocks of `TownConfig`, `BorderConfig` and `PushConfig`.)
- **New constants go in the config of the system they tune** (a new file if it is a new system). A constant that reads
  another config's value names it (`BorderConfig.X`); configs must not depend on each other in a cycle. Keep each file
  under the 1000-line lint cap. No magic numbers in other scripts. Find a constant by name: search `scripts/*_config.gd`.
- **World scale:** `Config.WORLD_SCALE` (100/70) scales TERRITORY constants (plaza, blocks, spawn, border spacing/gap/radii,
  cover, paint, search reach); INTERACTION and BODY constants (sizes, projectile ranges and speeds, `GRAB_*`, `SHELTER_RADIUS`,
  hit radii) are not; per-metre rates are divided by it. New distances: decide which kind and write `* WORLD_SCALE` if territory. Test: `world_scale_test`.
- Zoom: `TD_CAMERA_ORTHO_SIZE` is the default zoom; `TD_CAMERA_LOOK_OFFSET` and `TD_UI_SCALE` scale with it.

## Data flow per frame (`TopDownMain._process`)
1. Camera, highlight, readability (minimap about every 0.1 s, arrows) run even when ended.
2. If `running`: `night.update` -> HUD night bar and light.
3. `border.update(...)`: members, breaks, push, building capture, polygon, ground region.
4. People steering (`CrowdMovement`), then `Moods.update`.
5. `cover_update.update` (every `GROUND_UPDATE_INTERVAL`), `dim_recovery.update`, `GloomSim.update`, `dim_gate.hold_back`, `Grabs.update`, `Person.tick`.
6. `ground.update_paint`, landmarks, HUD spirit and burst (`level_hud`), `level_end.check`.
Player and projectile physics run on the 60 Hz physics tick.

## Recorder
`scripts/recorder.gd` writes `events.jsonl` (one JSON object per line with `t`, `night_phase`, `night`, `type`) plus
screenshots into `recordings/<stamp>/` (editor) or `user://recordings/<stamp>/`. Off unless the menu check box or `-- --record`
asks. Person ids are indexes into `TopDownMain.people`. **To add an event:** connect a signal in `Recorder.attach()` (or poll
in a `_poll_*`) and call `emit_event("name", {...})`; keep it cheap (nothing per frame but a comparison). Add it to
`tools/analyse_recording.py` (`kind_of`, `THREAT_TYPES`) if it should count. Tests: `recorder_test` (folders in
`user://rec_tests/` via `Recorder.base_dir_override`).

## Tests (`tests/*_test.gd`, gdUnit4 v6.2.2)
- **Input-driven:** level tests use `TopDownTestUtil.level_runner(self)` (1280x720, loads `topdown.tscn`) and real key and
  mouse events via `scene_runner`. Pure rules are called directly with no scene.
- **Intro flag:** `Config.intro_on()` is false under automated tests; a test sets `Config.intro_override` to 1 or 0 BEFORE
  `level_runner` and back to -1 in `after_test`.
- **Moods:** every person gets a mood at spawn; `place()` and `send_everyone_away()` reset it to none. Set `p.mood` after placing.
- **Helpers** in `tests/topdown_test_util.gd`: `send_everyone_away`, `place`, `screen_of`, `projectiles`, `blooms`,
  `select_mode`, `clear_spot`, `open_dim_gate`, `leave_loaded_scene`. Suites must be independent (separate Godot processes).
- **Determinism:** `--fixed-fps 60` and `Config.RNG_SEED`; no wall clock in game logic. Never `simulate_frames(n, ms)` with a delay.
- **Test mode:** `POSITIVEFPS_TEST=1` or headless makes `Config.is_automated_test()` true; the real mouse is never captured.
  The level test util turns the minimap's automatic redraw off (8 ms per redraw).
- **Speed:** `tools/run_tests.py` splits suites and slow tests (`tools/test_weights.json`) over parallel Godot processes;
  refresh with `--update-weights` when tests change a lot.

## Known gotchas
- gdUnit delivers a key press **twice** to the root scene's `_unhandled_input`; handlers must tolerate it (`menu.gd` guards Play).
- `Input.action_press()` does not reach `_unhandled_input`; tests send real `InputEvent`s through the scene runner.
- `MultiMesh` colour readback is zero in headless mode: test `PaintedGround.paint_colour_at()` or weights, not pixels.
- The nested `design/style_test` project has its own `project.godot`; Godot ignores it. `design/` is never committed by agents or gated.
- Windows long paths: keep temp copies in short paths (coverage copies to `.coverage_build/`, excluding `design/`).
- The console is cp1252: `run_tests.py` and `gate.py` reconfigure stdout to UTF-8; keep non-ASCII out of `print` elsewhere.
- The gdUnit CLI shrinks the window to 64x64; set `get_window().size` before loading a scene that lays out at `_ready`.
- Hover: a held target drops once the cursor has been off it (and not nearest to anyone) for 0.2 s. A test that keeps a target over a wandering person must re-hover every ~30 frames.
- Wanderers move about a metre in a few seconds; tests needing exact positions (a tie) call the rule directly with no frames.
- The midnight stagger holds dimmed sinks to one per `DIM_ARRIVAL_MIN_GAP`. A test that places several dimmed people calls `TopDownTestUtil.open_dim_gate(td)` between them.
- A parse error in a test file makes gdUnit skip that suite quietly while its summary says all passed. `run_tests.py` catches this (`integrity_problems()`; reported last as `BROKEN <file>:<line>: <message>`); proved by `test_gate.py` and `test_run_tests.py`.
- Strict typing: warnings are errors (`project.godot`). Type every `for` variable; avoid iterating arrays that may hold freed nodes.
- **Timing tests:** a test asserting wall-clock time must be named `test_perf_*` and guard its assert with
  `if OS.get_environment("POSITIVEFPS_PERF_ENFORCE") == "1":`. `run_tests.py` runs it serially, plain, after the parallel batch.
  Set the budget to max of 5+ serial runs x 1.5 and record the runs next to the assert (example: `world_scale_test.gd`). Never loosen a budget.
- Coverage ignores lambda bodies passed as multi-line arguments; hoist them into a `var` to measure them.
- Godot runs headless only; never open the editor GUI. Give every Godot run a hard timeout through `tools/godot_run.py`.
- On a merge conflict in `SOURCE_MAP.md`, regenerate it rather than merge.

## Quality gate and tools
- `python tools/gate.py` = lint + all tests (parallel). `--full` = lint + tests with line coverage + ratchet. `--no-cache`
  ignores the result cache (sha256 of the tree in `.git/positivefps-gate-cache.json`) and the saved coverage run.
- **Pre-commit hook = `gate.py --hook`:** lint + the fast tier (`run_tests.py --tier fast`: every test under 5 s, plus the
  slow tests that the changed functions of staged `scripts/*.gd` can reach per the saved per-unit coverage map, plus the
  whole suite of a changed `tests/*_test.gd`; `tools/fast_tier.py` prints what it chose; anything it cannot map, such as
  `config.gd` or any `*_config.gd`, scenes, `project.godot`, the test tooling or a missing/old map, runs everything). `--full` when
  `coverage_baseline.json` is staged. A commit that cannot change a Godot test (docs, tools other than
  run_tests/gate/coverage/godot_run/godot_path/fast_tier) runs lint + that tool's `tools/test_*.py` only. A fast pass
  never answers a plain or `--full` request in the gate cache.
- Speed: `run_tests.py` uses `WORKERS_DEFAULT` (up to 16) workers and plans units from the durations of the last full plain
  run (`.git/positivefps-test-times.json`; committed `tools/test_weights.json` is the fallback). It skips `godot --import`
  when `import_is_current()` (nothing newer than the last import; coverage copies always import). `coverage.py
  --update-baseline` / `--check-baseline` reuse the saved clean run of the same code fingerprint (`--fresh` runs again);
  the saved map is written by every instrumented run (`save_clean_run`).
- **Every target pass ends with `python tools/gate.py --full`, then `python tools/coverage.py --check-determinism`, then the baseline
  commit (`python tools/coverage.py --update-baseline`).** `python tools/round_end.py` runs all three (stops at the first
  failure; detached worker, state in `.scratch/round_end/`; re-run while it says "still running", exit 124). The hook alone
  does not run the ratchet. Never lower `coverage_baseline.json`.
- `test_perf_*` tests run serially and uninstrumented after the parallel batch (in `run_tests.py`, and via `run_tests.py --perf-only` after the coverage run in `--full`).
  With `POSITIVEFPS_PARALLEL_PART=1` the plain tier and the hook skip that pass; `gate.py --full` ignores the variable.
- Part agents: `python tools/run_tests.py --suites a_test b_test` (chosen suites), `python tools/coverage.py --check-files scripts/x.gd` (per-file coverage), `python tools/lint.py [--fix]` (warns from 950 lines per file).
- `python tools/source_map.py` writes `SOURCE_MAP.md` (`--check` exits 1 if stale; the hook runs it when a `.gd` file or the map is staged). Regenerate after any `.gd` change.
- `python tools/godot_run.py --timeout 120 [--log F] [--gui|--console] -- <cmd...>`: wrapper for any scripted Godot run (hard timeout, log in `.scratch/godot_run/`, kills only its own child tree, exit 124 = timed out).
- `python tools/perf_compare.py A B [--rounds N]`: alternating serial `--perf-only` runs of two commits or folders; prints per-test statistics.
- `python tools/analyse_recording.py [--compare A B ...]`: analyse recordings (recordings under 10 s skipped unless `--include-restarts`).
- `python tools/checkpoint_shots.py`: checkpoint renders (see Looks). `python tools/cleanup_worktrees.py`: removes stale worktrees and orphan `.claude/worktrees/agent-*` folders. `python tools/agent_dashboard.py [--port] [--session]`: read-only page of subagent status. `python tools/install_hooks.py`: installs the hook.
- Details: each tool's `--help`, `tools/COVERAGE_TOOL_NOTES.md`, timing history `tools/BUILD_TIMINGS.md`. Godot is found by `tools/godot_path.py` (`GODOT` env, PATH, WinGet).
- Self-checks (run by hand when you change a tool): `tools/test_godot_run.py`, `test_perf_compare.py`, `test_analyse_recording.py`, `test_run_tests.py`, `test_gate.py`, `test_round_end.py`, `test_determinism.py`, `test_fast_tier.py`, `test_coverage_files.py`, `test_cleanup_worktrees.py`, `test_source_map.py`, `test_agent_dashboard.py`, `test_board.py`.
- Project skills (`.claude/skills/<name>/SKILL.md`, committed): `coordinate-target` (the coordinator's rules: board, loop, parallel builds), `launch-playtest`, `finish-target`, `brief-build-agent`.
- `python tools/board.py list | add | set | archive | drop | scan`: the GitHub project board ("Positive game dev", items are
  repo issues; milestone = target version, labels = area, Size = token cost). Coordinator only; build agents never touch
  the board. Write commands take `--dry-run`. gh is found by `GH`, PATH, then `C:\Program Files\GitHub CLI\gh.exe`.
- Finding code: search `SOURCE_MAP.md`; for project state read IDEAS.md "Current state" only.
