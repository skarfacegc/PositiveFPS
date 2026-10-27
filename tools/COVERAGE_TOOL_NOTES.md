# Coverage tool — extraction notes

A mini project inside PositiveFPS. Godot has no standard code coverage tool, so the one in `tools/coverage.py` may be worth extracting and publishing later. These notes record what we learn while using it on a real project.

## Status
- **Current:** line coverage is the headline (function coverage kept as a secondary column), with a committed
  ratchet (`coverage_baseline.json`) and a pre-commit gate. Used with gdUnit4 v6.2.2 on Godot 4.7.2.
- **Decision:** don't extract yet. Prove it on this project first (the ratchet and gate have to hold up across real
  commits), then decide.

## How it works today
1. Copies the project to `.coverage_build/` (excluding .git, .godot, coverage, reports).
2. Scans each `func` body in `scripts/*.gd` with a small GDScript-aware scanner (strings, comments, bracket depth,
   backslash and triple-quote continuations, `match` branch patterns) and inserts `CovProbe.hit("file:line")`
   before every executable statement, keyed by the original line number. Function coverage counts a function as hit
   when its first statement ran. One-line functions are split so their body gets its own probe.
3. `CovProbe` is a `class_name` script with a `static var hits` dictionary.
4. An autoload, added only to the copy's project.godot, writes the hits to JSON in `_exit_tree()`.
5. The gdUnit4 suite runs headless (`--headless --ignoreHeadlessMode -c`). Results come from the JUnit XML.
6. The tool writes `coverage/index.html`, `summary.txt` and `coverage.json`.

## Lessons so far
- **Function-level coverage is a weak signal.** The first run showed 100% (104/104), which only means every function was called once. Line or branch coverage is needed before the number means much.
- **Headless gotchas:** MultiMesh colour readback returns zeros, mouse capture doesn't work, and the gdUnit4 CLI creates a 64x64 window unless run headless.
- **Input simulation:** `Input.action_press` doesn't reach `_unhandled_input`, so tests use real InputEvents or the gdUnit4 `simulate_*` methods. The scene runner doesn't update the viewport's stored mouse position.
- **Instrumenting a copy** avoids touching source files, but means paths must be mapped back for reports.
- Dumping hits on `_exit_tree` of an autoload works in headless gdUnit4 runs.
- **Line rules that matter:** a probe must never go before `elif`/`else`, a `match` branch pattern or a continuation
  line (inside brackets or after a backslash). Those are the only places where an inserted line would break parsing.
  The instrumented build parsed and passed all 57 tests on the first real run.
- **Lines inside a multi-line lambda passed as an argument** (`foo(func():` with the body on following lines) are not
  measured: they sit inside brackets, so they count as continuation lines. Hoist the lambda into a `var` to measure it.
- **Windows path length:** copying the project into a deep folder (for example a scratchpad path) failed inside
  `.coverage_build` with WinError 3 (MAX_PATH). Keep test copies in a short path such as `C:
t_ratchet`.
- **Baseline files from PowerShell** (`Set-Content -Encoding utf8`) start with a BOM. The loader now accepts `utf-8-sig`.
- **gdformat 4.5 output** wraps long multi-line calls awkwardly (for example a `(
 hud
 . set_hint(...)
)`
  pattern for a chained call with a long string). Splitting the string into a variable avoids it.
- **gdlint `class-definitions-order`** wants `var` declarations in the order signals, enums, consts, then public and
  private vars. Moving a var is safe; only the order changes.

- **Probe cost dominates the instrumented run.** A call into a shared dictionary (`CovProbe.hit("file:line")`) costs
  about 210 ns; an inline `_cov_h[LINE] += 1` on a static array declared in the instrumented script itself costs about
  18 ns (a static array reached through another class costs 56 ns, the call with an int key 95 ns). Per-script arrays
  are registered with `CovProbe.register` from a static initializer and summed at exit.
- **Parallel test processes** each write their own hits file (`POSITIVEFPS_COV_OUT`); `merge_hits` sums them.
- **A test that passed only because of suite order** is invisible in one long process: one level test needed the
  1280x720 window that an earlier suite set. Running each suite in its own process found it.

## Before extracting
- [ ] Prior-art search: existing Godot 4 coverage add-ons, and gdUnit4/GUT roadmaps (contributing upstream may be better).
- [ ] Line coverage, then maybe branch coverage.
- [ ] Use Godot's own parser or tokenizer instead of regex, to handle multi-line statements, `match`, inner classes, lambdas and property get/set.
- [ ] Output standard formats (LCOV, Cobertura) for CI and Codecov.
- [ ] Framework-agnostic: gdUnit4 and GUT.
- [ ] Package as a Godot add-on with a CLI entry, not a project-specific Python script.
- [ ] Its own tests, docs and supported-version matrix.

## Log
- 2026-10-22: First version built alongside the gdUnit4 migration. 57 tests, 100% function coverage.
- 2026-10-22: Line coverage added. `analyze_script` finds the executable lines; the instrumented build has 1138 of them
  across 12 files. First run: 57/57 tests pass, 97.4% line coverage (1108/1138), function coverage 100% (104/104).
  Lowest files: config.gd 88.5%, controls.gd 94.4%.
- 2026-10-22: Ratchet added: `--check-baseline` fails (exit 3) when the total or an existing file drops by more than 0.5
  points, or a new file is under 60%. `--update-baseline` refuses any decrease unless `--allow-decrease` is given.
  Baseline committed as `coverage_baseline.json`.
- 2026-10-22: Pre-commit gate added (`.githooks/pre-commit`, enabled by `tools/install_hooks.py`). It runs
  `tools/lint.py` and then the ratchet on commits that touch code. It tests the working tree, not the staged snapshot;
  this is a known limitation. Its cost is about 2 minutes per code commit, which is a reason to keep the suite fast.
- 2026-10-22: Lint: gdtoolkit 4.5.0 (`python -m gdtoolkit.formatter` and `python -m gdtoolkit.linter`), 120 columns.
- 2026-10-23: Strict typing (`gdscript/warnings/*` set to errors in `project.godot`) across `scripts/` and `tests/`.
  The tool needed no changes. `class_name` scripts instrument and load in the copy, and `CovProbe` is unaffected.
  Three things learned:
  - A typed loop variable over a list that can hold freed nodes fails at runtime ("Trying to assign invalid
    previously freed instance"). Check the scene tree (`get_children()`) instead of iterating the freed list.
  - Line coverage of `scripts/topdown_main.gd` moved between 95.3% (182/191) and 96.9% (185/191) on identical code.
    The top-down tests are not fully deterministic: the blocked-move and wander-fallback lines flip between runs
    (the cause is not yet confirmed; wander timing uses real frame deltas). The baseline keeps the lower value so the
    0.5-point ratchet does not fail on a lucky run. Making those tests deterministic would remove the noise.
  - Typed locals and `as` casts add executable lines: the total rose from 1138 to 1144. The covered ratio stayed
    within the run-to-run noise above (97.4% to 97.6%).
- 2026-10-22: Determinism fixed. Cause: top-down wander timers, the blocked-move check and the wander fallback all
  ran on wall-clock frame deltas (gdUnit `simulate_frames(n, 16)` waits real 16 ms timers, and physics ticks took
  whatever the real frame time was), so the timings and positions drifted between runs. Global `randf` in the cosmetic
  floating numbers was also unseeded. Fix: `Config.RNG_SEED` (42) seeds every random source (top-down placement and
  wandering, and a seeded RNG for the floating-number jitter in `person.gd`), and `tools/run_tests.py` launches Godot
  with `--fixed-fps 60` (`TEST_FIXED_FPS`), so each frame advances exactly 1/60 s and the physics step matches.
  Proof: three full `tools/coverage.py` runs gave identical per-file line coverage (topdown_main.gd 95.3% (182/191),
  topdown_player.gd 95.9% (142/148), total 97.4%, 57/57 tests).
- 2026-10-24: Round 9 step 1 (first person retired). Deleted scripts are dropped from the baseline: `--check-baseline`
  reports a removed file as a note, not a failure, and `--update-baseline` writes only the files that still exist.
  Found and fixed: `run_tests.py` and `coverage.py` could not print Godot's em dashes on a cp1252 Windows console, so an
  `--update-baseline` run died halfway. Both now reconfigure stdout and stderr to UTF-8 (`errors="replace"`) when
  `run_tests.py` loads, so no `PYTHONIOENCODING` workaround is needed.
- 2026-10-24: Tooling round (timings in `tools/BUILD_TIMINGS.md`). Instrumented run 483 s -> 30 s, plain suite 75.6 s -> 22.5 s.
  - Probes are inline per-script array increments (see Lessons); the copy skips `design/` and `.scratch/` and starts
    from the repo's `.godot` import cache.
  - Test suites run in parallel Godot processes (`tools/run_tests.py`); coverage sums the per-process hits. Per-file
    line and function coverage were identical before and after (99.0%, 2411 of 2436 lines).
  - `--check-determinism` runs the instrumented suite twice and compares the exact set of lines hit (and reports the
    hit counts that differ; with the fixed 1/60 s step they were identical). It replaces "two identical runs before
    every `--update-baseline`": one run normally, the determinism check once at the end of a round.
  - Tiering decision: instrumented 30.1 s against plain 23.1 s is +30%, not under the 30% rule. The hook (via
    `tools/gate.py --hook`) runs lint and the plain suite; the ratchet runs when `coverage_baseline.json` is staged or
    with `gate.py --full`, and every round must end with `--full`.
  - `tools/gate.py` caches a passing result keyed on a sha256 of the working tree (scripts, tests, tools, scenes,
    resources, project.godot, gdlintrc, the gdUnit4 version and the baseline; not `design/` or Markdown).
  - Hit counts for a line now come from per-process arrays indexed by the original line number, so the JSON format
    (`"scripts/x.gd:LINE": count`) and the reports are unchanged.
- 2026-10-24: Gate hole closed (round 12b). gdUnit skips a suite whose script has a parse error and still reports
  "all passed". `run_tests.py` now fails the run when any Godot output contains `Parse Error`, `SCRIPT ERROR`,
  `Failed to load script` or a compile error, or when a discovered `tests/*_test.gd` suite reports no results or fewer
  tests than it declares (`integrity_problems()`, used by the serial and parallel paths, so `coverage.py` gets it too).
  `tools/test_gate.py` proves it with a deliberately broken suite in a temporary project under `.scratch/`.

## Future idea (2026-10-26): change-based test selection (test impact analysis)
For small turns, run only the tests likely to be affected; releases and significant reviews still run the full suite.
- **Impact map:** during a full coverage run, record per test suite which files and lines it executes (the current tool
  only records hits for the whole run). Save the suite → lines map.
- **Selection:** `git diff` since the last full run → changed lines → run only suites whose recorded lines include them,
  plus new or changed test files.
- **Fall back to the full suite** if: the map is missing or stale; shared foundations change (config.gd, controls.gd,
  scenes, project.godot); a changed file isn't in the map; or the selection would cover most suites anyway.
- **Two tiers:** quick (pre-commit: lint + impacted suites + coverage of changed files only; no ratchet) and full
  (`--full` / `FULL=1`, release, round end, significant reviews: whole suite + coverage + ratchet + rebuild the map).
  Build agents run full before each round's final commit.
- **Caveat:** misses breakage through paths no test exercised before; the full tier catches those. gdUnit4 selects by
  suite, which is fine at this size.

## Timing tests and coverage (2026-10-26)
`coverage.py` itself is unchanged, but it runs `run_tests.run_suite(..., cov_dir=...)`, which keeps `test_perf_*` tests in the
instrumented parallel batch (so their lines are counted) with their time assert switched off. The budgets are enforced by a
separate plain, serial pass (`run_tests.py --perf-only`, called by `gate.py --full`). A tool extracted from this repo needs
both halves: the counted run and an uninstrumented timing run.
