#!/bin/bash
cd "$(dirname "$0")" || exit 1
ROOT="$(cd ../.. && pwd)"
# The Godot 4.7.2 console executable: GODOT, then PATH, then the WinGet install (see tools/godot_path.py).
GODOT_EXE="$(${PYTHON:-python} "$ROOT/tools/godot_path.py")" || exit 2
# first step registers the class_name scripts (StyleScene, MiniMap); harmless to repeat
timeout 120 "$GODOT_EXE" --headless --path . --import 2>&1 | tail -3
timeout 170 "$GODOT_EXE" --path . --resolution 960x540 2>&1 | tail -60
