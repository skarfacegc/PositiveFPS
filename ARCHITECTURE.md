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
- Systems that attach to the level use `X.attach(main)` (one line in `TopDownMain`, stored as `main.x`): `GapPatch`,
  `FirstLight`, `SpiritWarmth`, `WobbleAlert`. New systems should do the same and stay out of `topdown_main.gd` (near the line cap).

## Script map (`scripts/*.gd`)
- `topdown_main.gd`: the level (plaza, camera, zoom, win/lose, wiring, dim sink gate `_try_dim_sink`); `crowd_movement.gd`: unrescued people's movement
- `topdown_player.gd`: movement, aiming, targeting, firing, burst, spirit and the dim state, sticky hover; `controls.gd`: every InputMap action (no raw keys elsewhere)
- `person.gd`: one person (affinity, joy, gloom, rescued, wobble, shield, react); `moods.gd`: guarded/skittish/glum and sheltering; `grabs.gd`: dimmed grabs
- `gloom_sim.gd`: dimming, spreading, draining; `night_cycle.gd`: clock, strength, `dim_gap_at()`; `relapse_wave.gd`: relapse gate; `first_light.gd`: dawn rally
- `border.gd`: the living border (members, gaps, posts, push-back, polygon); `border_slots.gd`: slot assignment/ordering; `border_shape.gd`: pure static loop rules (call `BorderShape.X`; new pure border rules go here); `border_centre.gd`: centre, beacon stretch, arms, preview plan
- `gap_patch.gd`, `burst_clear.gd`, `border_warning.gd`, `patch_fx.gd`: spirit actions F and G/Q, warnings and their effects; `spirit_warmth.gd`: spare spirit warms strained members
- `beacon_marker.gd` (+ `BeaconPlacement`): beacon in the world, E hold/release/cancel; `reach_guide.gd`: zone preview; `building.gd`, `landmark.gd`, `landmarks.gd`: blocks, the three landmarks and boosts; `dawn_rating.gd`: pure 1-3 lights rules
- `painted_ground.gd`: 1 m paint grid; `joy_projectile.gd`, `bloom.gd`: shots; `floor_effects.gd`: floor overlay registry/cap
- `hud.gd`, `hud_safe_area.gd`, `minimap.gd`, `gap_arrows.gd`, `wobble_alert.gd`, `landmark_pointers.gd`: HUD, minimap, edge pointers (`HudSafeArea` is the one safe rectangle they share)
- `feedback_layer.gd`, `spirit_meter.gd`, `mood_icons.gd`, `intro.gd`, `prompt_bar.gd`: screen-space cues, prompts and `Intro.notice(id, words)`
- `recorder.gd`: gameplay recorder; `config_base.gd` + `config.gd`: all tuning (see Tuning)

## Areas (where to start; tests are `tests/<name>.gd`)
- **Border / territory:** `border.gd`, `border_slots.gd`, `border_shape.gd`, `building.gd`, `painted_ground.gd`; tests `border_*_test`, `edge_pressure_test`, `cover_test`; config `BORDER_*`. Slots are spaced along the open length; the map-edge stretch is sealed (no slots, never a gap).
- **Beacon / zone / landmarks / dawn rating:** `border_centre.gd`, `reach_guide.gd`, `beacon_marker.gd`, `landmark(s).gd`, `dawn_rating.gd`, `topdown_main.gd` (`try_place_beacon`, `_check_end`); tests `beacon_test`, `stretch_safety_test`, `shaped_zone_test`, `shaping_followup_test`, `reactions_test`, `landmarks_test`, `dawn_rating_test`; config `BEACON_*`, `LANDMARK_*`, `DAWN_*`. `BorderCentre.plan_toward()` is the one plan used by both the preview and the real stretch. Landmark positions are in the spawn exclusion (`_near_block`): moving one changes who spawns where and their gloom.
- **People / gloom / night / waves:** `person.gd`, `gloom_sim.gd`, `night_cycle.gd`, `relapse_wave.gd`, `first_light.gd`, `crowd_movement.gd`; tests `person_test`, `gloom_sim_test`, `night_cycle_test`, `topdown_crowd_test`, `dimmed_waves_test`, `first_light_test`; config `GLOOM_*`, `NIGHT_*`, `DIM_*`, `WOBBLE_*`, `FIRST_LIGHT_*`.
- **Moods / shelter / shield / guarded wedge / hover:** `moods.gd`, `person.gd` (`receive_joy`, `shot_lands_now`), `topdown_player.gd` (`_update_hover_target`), `feedback_layer.gd`; tests `moods_test`, `shield_test`, `shelter_nearest_test`, `guarded_wedge_test`, `hover_stick_test`, `stagger_test`; config `GUARDED_*`, `SKITTISH_*`, `GLUM_*`, `SHELTER_*`, `HOVER_*`.
- **Spirit / dim / grabs / spirit actions:** `topdown_player.gd`, `grabs.gd`, `gap_patch.gd`, `burst_clear.gd`, `border_warning.gd`, `spirit_warmth.gd`; tests `spirit_test`, `grab_test`, `spirit_warmth_test`, gap patch/burst suites; config `SPIRIT_*`, `DIM_*`, `GRAB_*`, `PATCH_*`, `BURST_*`, `SPARE_*`.
- **Projectiles / blooms / floor effects:** `joy_projectile.gd`, `bloom.gd`, `floor_effects.gd`; tests `projectile_*_test`, `floor_test`, `paint_bloom_camera_test`.
- **Targeting / input / zoom / camera:** `topdown_player.gd`, `controls.gd`, `topdown_main.gd` (`_update_camera`, `view_half_extents`); tests `targeting_test`, `topdown_mode_test`, `zoom_test`, `world_scale_test`.
- **HUD / minimap / cues / intro:** `hud.gd`, `minimap.gd`, `gap_arrows.gd`, `wobble_alert.gd`, `feedback_layer.gd`, `intro.gd`, `prompt_bar.gd`; tests `hud_test`, `readability_test`, `feedback_test`, `intro_test`, `debug_overlay_test`, `menu_test`. These are screen-space UI: both looks draw them.
- **Looks / styled art:** `scripts/looks/*`, `shaders/*`, `topdown_main.gd` (`set_look`); tests `looks_*_test`; tool `checkpoint_shots.py`. See Looks.
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
- **Gameplay rounds add a placeholder look only** (extend the base look class and the placeholder). Styled work happens
  only in graphics checkpoints.
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
- **Checkpoint renders:** `python tools/checkpoint_shots.py [--set round20|round24]` (needs a real window, 45-90 s, quits
  itself; output in `design/renders/checkpoint_NN/`; look at the PNGs and write `NOTES.md` there). If it hangs, a script has a
  parse error or the class cache is stale: run `python tools/run_tests.py --suites looks_checkpoint5_test` first, or run the scene with `--timeout 90` and read the output.

## Tuning (`scripts/config.gd`, `scripts/config_base.gd`)
- `Config extends ConfigBase`, so `Config.X` reaches everything. **New constants go in `config.gd` as a "Round N: <part>"
  block just above the first helper function (`intro_on`).** A constant in `ConfigBase` cannot read one in `Config`.
  Keep each file under the 1000-line lint cap. No magic numbers in other scripts.
- Search both files for block names ("Territory game", "Round 9: the living border", "Round 19: beacon", "Checkpoint 6" ...).
- **World scale:** `Config.WORLD_SCALE` (100/70) scales TERRITORY constants (plaza, blocks, spawn, border spacing/gap/radii,
  cover, paint, search reach); INTERACTION and BODY constants (sizes, projectile ranges and speeds, `GRAB_*`, `SHELTER_RADIUS`,
  hit radii) are not; per-metre rates are divided by it. New distances: decide which kind and write `* WORLD_SCALE` if territory. Test: `world_scale_test`.
- Zoom: `TD_CAMERA_ORTHO_SIZE` is the default zoom; `TD_CAMERA_LOOK_OFFSET` and `TD_UI_SCALE` scale with it.

## Data flow per frame (`TopDownMain._process`)
1. Camera, highlight, readability (minimap about every 0.1 s, arrows) run even when ended.
2. If `running`: `night.update` -> HUD night bar and light.
3. `border.update(...)`: members, gaps, patches, push-back, building capture, polygon, ground region.
4. People steering (`CrowdMovement`), then `Moods.update`.
5. `_update_cover` (every `GROUND_UPDATE_INTERVAL`), `_update_dim`, `GloomSim.update`, `Grabs.update`, `Person.tick`.
6. `ground.update_paint`, landmarks, HUD spirit and burst, `_check_end`.
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
  `config.gd`, scenes, `project.godot`, the test tooling or a missing/old map, runs everything). `--full` when
  `coverage_baseline.json` is staged. A commit that cannot change a Godot test (docs, tools other than
  run_tests/gate/coverage/godot_run/godot_path/fast_tier) runs lint + that tool's `tools/test_*.py` only. A fast pass
  never answers a plain or `--full` request in the gate cache.
- Speed: `run_tests.py` uses `WORKERS_DEFAULT` (up to 16) workers and plans units from the durations of the last full plain
  run (`.git/positivefps-test-times.json`; committed `tools/test_weights.json` is the fallback). It skips `godot --import`
  when `import_is_current()` (nothing newer than the last import; coverage copies always import). `coverage.py
  --update-baseline` / `--check-baseline` reuse the saved clean run of the same code fingerprint (`--fresh` runs again);
  the saved map is written by every instrumented run (`save_clean_run`).
- **Every round ends with `python tools/gate.py --full`, then `python tools/coverage.py --check-determinism`, then the baseline
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
- Self-checks (run by hand when you change a tool): `tools/test_godot_run.py`, `test_perf_compare.py`, `test_analyse_recording.py`, `test_run_tests.py`, `test_gate.py`, `test_round_end.py`, `test_determinism.py`, `test_fast_tier.py`, `test_coverage_files.py`, `test_cleanup_worktrees.py`, `test_source_map.py`, `test_agent_dashboard.py`.
- Project skills (`.claude/skills/<name>/SKILL.md`, committed): `launch-playtest`, `finish-round`, `brief-build-agent`.
- Finding code: search `SOURCE_MAP.md`; for project state read IDEAS.md "Current state" only.
