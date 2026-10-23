#!/bin/bash
D="/c/Users/amw1/AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe"
cd "$(dirname "$0")"
timeout 90 "$D/Godot_v4.7.2-stable_win64_console.exe" --path . --resolution 960x540 2>&1 | tail -60
