# Build timings

Measured on the dev machine (Windows 11, 24 logical CPUs, Godot 4.7.2 headless, gdUnit4 6.2.2), 183 tests. Wall-clock
seconds, one run each unless noted. Tooling round of 2026-10-24.

## Before

| What | Command | Time |
|---|---|---|
| Lint | `python tools/lint.py` | 3.0 s |
| Plain tests | `python tools/run_tests.py` | 75.6 s |
| Tests with coverage | `python tools/coverage.py --check-baseline` | 483 s (8 min 3 s) |
| Pre-commit hook (code commit) | lint + coverage ratchet | about 486 s |
| Hook, same code again | no cache: ran everything again | about 486 s |

The coverage run was 6.4x the plain run: every instrumented line called `CovProbe.hit("file:line")`, a static function
that hashed a string key into a dictionary (about 210 ns per hit, against 18 ns for an inline array increment), and the
game executes millions of lines per run.

Per suite (plain run, sum of test times 68.5 s; the rest is Godot start-up and import):

| Suite | s | Suite | s |
|---|---|---|---|
| edge_pressure_test | 23.2 | cover_test | 1.6 |
| border_level_test | 10.9 | readability_test | 1.3 |
| projectile_rhythm_test | 9.2 | menu_test | 0.4 |
| topdown_mode_test | 4.4 | floor_test | 0.4 |
| grace_cue_test | 4.0 | other 10 suites | < 0.2 each |
| projectile_physics_test | 4.0 | | |
| targeting_test | 3.6 | | |
| projectile_trail_test | 1.9 | | |
| topdown_crowd_test | 1.8 | | |
| paint_bloom_camera_test | 1.8 | | |

The 15 slowest tests (plain run, serial):

| s | Test |
|---|---|
| 13.72 | edge_pressure_test::test_a_dark_person_outside_the_border_cannot_get_inside_it (2400 frames) |
| 5.25 | edge_pressure_test::test_a_lone_rescued_person_next_to_a_dark_person_relapses_within_a_bounded_time |
| 3.29 | projectile_rhythm_test::test_music_fires_twice_as_often_as_nature_and_art_half_as_often |
| 3.05 | border_level_test::test_the_landmark_is_held_and_the_level_is_won |
| 2.26 | projectile_rhythm_test::test_joy_per_second_is_about_equal_for_music_and_art |
| 2.00 | grace_cue_test::test_light_person_three_metres_away_is_rescued_quickly_by_each_element |
| 1.68 | border_level_test::test_the_joy_burst_near_the_border_bulges_it_toward_the_player |
| 1.62 | border_level_test::test_three_locked_rescues_by_real_clicks_form_the_border |
| 1.53 | edge_pressure_test::test_a_lone_rescued_person_gets_no_protection_from_their_own_paint |
| 1.53 | grace_cue_test::test_rescue_shows_a_pulsing_ring_and_glow_that_end_with_the_grace |
| 1.40 | edge_pressure_test::test_border_members_on_the_line_have_no_protection |
| 1.36 | projectile_rhythm_test::test_nature_hit_bursts_petals_and_blooms_then_both_free_themselves |
| 1.30 | projectile_rhythm_test::test_art_splat_is_bigger_than_before_and_frees_itself |
| 1.18 | cover_test::test_cover_and_protection_follow_the_painted_ground_in_the_level |
| 1.15 | topdown_mode_test::test_crowd_wanders_and_paints_for_several_hundred_frames |

Why the tests were slow: they are frame-bound. `simulate_frames(n)` already waits for real frames with no delay, so the
cost is the game's own work per frame (about 3.2 ms headless, 60 people), times many frames (the longest test runs 2400).
A profile of one frame showed the minimap redraw (a 128x128 image, 8.5 ms every 6th frame) was about 45% of it.

## After

| What | Command | Before | After | Speedup |
|---|---|---|---|---|
| Lint | `python tools/lint.py` | 3.0 s | 3.0 s | 1x |
| Plain tests | `python tools/run_tests.py` | 75.6 s | 22.5 s | 3.4x |
| Plain tests, serial | `python tools/run_tests.py --workers 1` | 75.6 s | 58.7 s | 1.3x |
| Tests with coverage | `python tools/coverage.py --check-baseline` | 483 s | 30.1 s | 16x |
| Hook, code commit (lint + tests) | `sh .githooks/pre-commit` | about 486 s | 27 s | 18x |
| Hook, same code again (cached) | `sh .githooks/pre-commit` | about 486 s | 1 s | about 490x |
| Full gate, end of round | `python tools/gate.py --full` | about 486 s | 33 s | 15x |

Coverage overhead: the instrumented run is 30.1 s against 23.1 s for the plain run in the same session (+30%). That is
not under the 30% rule, so the hook runs lint and the plain suite, and the ratchet runs in `gate.py --full` (and in the
hook whenever `coverage_baseline.json` is staged). See README, "Tests & coverage".

Estimated cost of a round of 5 code commits plus the baseline commit:

| | Before | After |
|---|---|---|
| 5 commits through the hook | 5 x 486 s = 2430 s | 5 x 27 s = 135 s |
| Baseline: two identical coverage runs, then the update | 2 x 483 s + 486 s = 1450 s | `gate.py --full` 33 s + `--check-determinism` 62 s + baseline commit 33 s = 128 s |
| Total | about 3880 s (65 min) | about 263 s (4.4 min) |

Where the time went (plain suite, in the order of effect):

1. Serial execution of independent suites: now parallel Godot processes, slow tests in their own process (75.6 s -> 27 s).
2. Instrumentation cost: dictionary-and-call probes replaced by inline per-script array increments (483 s -> 31 s).
3. The minimap redraw in every level test: switched off in the level test helper (59 s serial instead of 75 s).
4. Re-running an unchanged tree: the gate result cache (27 s -> 1 s).
5. Coverage copy: skips `design/` and `.scratch/`, starts from the repo's import cache (about 2 s).

What is left: the 2400-frame test (about 16 s when 8 Godot processes share the machine) sets the floor for the plain run.
