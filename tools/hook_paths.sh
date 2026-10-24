#!/bin/sh
# Path rules for the pre-commit hook (.githooks/pre-commit sources this file; tools/test_hook_paths.sh tests it).
# Each function reads the staged paths, one per line, on stdin.

# Exit 0 when every path is under design/ or is a Markdown doc (*.md), and there is at least one path.
is_docs_only() {
	seen=0
	while IFS= read -r path; do
		[ -z "$path" ] && continue
		seen=1
		case "$path" in
			design/*|*.md) ;;
			*) return 1 ;;
		esac
	done
	[ "$seen" -eq 1 ]
}

# Exit 0 when any path is code that needs the test gate (*.gd, *.tscn, *.tres, project.godot, tools/ or tests/).
needs_gate() {
	grep -Eq '(\.gd|\.tscn|\.tres)$|^project\.godot$|^(tools|tests)/'
}
