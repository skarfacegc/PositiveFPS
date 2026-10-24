#!/usr/bin/env python3
"""Dry run of the gate cache rules in tools/gate.py (no Godot needed). Exits 1 if any answer is wrong.

Checks which paths count towards the fingerprint, and that the fingerprint changes when (and only when) a file the
gate depends on changes. Run by tools/test_hook_paths.sh.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gate  # noqa: E402

failures = []


def expect(label, got, want):
    if got != want:
        failures.append("%s: expected %r, got %r" % (label, want, got))


for path, want in [
    ("scripts/border.gd", True), ("scripts/border.gd.uid", True), ("tests/x_test.gd", True),
    ("tools/gate.py", True), ("tools/test_weights.json", True), ("topdown.tscn", True), ("menu.tscn", True),
    ("theme.tres", True), ("project.godot", True), ("gdlintrc", True), ("coverage_baseline.json", True),
    ("addons/gdUnit4/plugin.cfg", True), (".githooks/pre-commit", True),
    ("design/style_test/project.godot", False), ("design/a.tscn", False), ("README.md", False),
    ("IDEAS.md", False), ("tools/BUILD_TIMINGS.md", False), ("tools/__pycache__/gate.cpython-312.pyc", False), (".scratch/x.gd", False),
    ("reports/x/results.xml", False), ("coverage/index.html", False), ("addons/gdUnit4/src/x.gd", False),
]:
    expect("depends_on(%s)" % path, gate.depends_on(path), want)

probe_dep = os.path.join(gate.ROOT, "tests", "zz_fingerprint_probe.gd")
probe_doc = os.path.join(gate.ROOT, "design", "zz_fingerprint_probe.tscn")
base = gate.fingerprint()
expect("fingerprint is stable", gate.fingerprint(), base)
try:
    os.makedirs(os.path.dirname(probe_doc), exist_ok=True)
    with open(probe_doc, "w", encoding="utf-8") as fh:
        fh.write("x")
    expect("a file under design/ does not change the fingerprint", gate.fingerprint(), base)
    with open(probe_dep, "w", encoding="utf-8") as fh:
        fh.write("extends Node\n")
    changed = gate.fingerprint()
    expect("a new untracked test file changes the fingerprint", changed != base, True)
    with open(probe_dep, "w", encoding="utf-8", newline="") as fh:
        fh.write("extends Node\r\n")
    expect("line endings do not change the fingerprint", gate.fingerprint(), changed)
    with open(probe_dep, "w", encoding="utf-8") as fh:
        fh.write("extends Node2D\n")
    expect("editing the file changes the fingerprint", gate.fingerprint() not in (base, changed), True)
finally:
    for path in (probe_dep, probe_doc):
        if os.path.exists(path):
            os.remove(path)
expect("fingerprint returns to the start", gate.fingerprint(), base)

if failures:
    print("test_gate: FAILED")
    for line in failures:
        print("  " + line)
    sys.exit(1)
print("test_gate: all cases pass")
