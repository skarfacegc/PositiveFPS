#!/bin/sh
# Dry run of the pre-commit path rules (tools/hook_paths.sh) against fake staged lists. Exits 1 if any answer is wrong.
cd "$(dirname "$0")/.." || exit 1
. tools/hook_paths.sh

fail=0
classify() {
	if printf '%s\n' "$1" | is_docs_only; then
		echo docs
	elif printf '%s\n' "$1" | needs_gate; then
		echo gate
	else
		echo none
	fi
}

expect() {
	got=$(classify "$2")
	if [ "$got" != "$1" ]; then
		echo "FAIL: expected $1, got $got for: $2"
		fail=1
	fi
}

expect docs "design/style_test/renders/a.png"
expect docs "$(printf 'design/a.html\nREADME.md')"
expect docs "IDEAS.md"
expect docs "$(printf 'design/x.tscn\ndesign/y.gd')"
expect gate "$(printf 'design/a.html\nscripts/border.gd')"
expect gate "scripts/border.gd"
expect gate "tools/coverage.py"
expect gate "tools/hook_paths.sh"
expect gate "tests/x.gd"
expect gate "project.godot"
expect gate "$(printf 'docs/notes.md\nscripts/x.gd')"
expect none "$(printf 'readme.txt\n')"
expect none ""

if [ "$fail" -eq 0 ]; then
	echo "test_hook_paths: all cases pass"
fi
exit "$fail"
