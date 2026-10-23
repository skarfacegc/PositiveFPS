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
  `.coverage_build` with WinError 3 (MAX_PATH). Keep test copies in a short path such as `C:t_ratchet`.
- **Baseline files from PowerShell** (`Set-Content -Encoding utf8`) start with a BOM. The loader now accepts `utf-8-sig`.
- **gdformat 4.5 output** wraps long multi-line calls awkwardly (for example a `(
 hud
 . set_hint(...)
)`
  pattern for a chained call with a long string). Splitting the string into a variable avoids it.
- **gdlint `class-definitions-order`** wants `var` declarations in the order signals, enums, consts, then public and
  private vars. Moving a var is safe; only the order changes.

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
