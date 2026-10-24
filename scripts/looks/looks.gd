class_name Looks
extends RefCounted

# The look switch. Every main thing on screen has a rules script (person.gd, border.gd, ...) and a look: a separate
# script that reads the rules' public state and draws it. There are two looks: PLACEHOLDER (plain shapes, the default
# and the one the tests use) and STYLED (the locked art style from design/style_test). Anything without a styled
# look falls back to its placeholder look and is counted (see note_placeholder).
# The mode is static, so it survives a scene reload and the menu choice lasts for the session.

enum Mode { PLACEHOLDER, STYLED }

static var mode: int = Mode.PLACEHOLDER
# Objects that always use their placeholder look, even in styled mode: {"ref": WeakRef, "kind": String}.
static var _fallbacks: Array[Dictionary] = []


static func is_styled() -> bool:
	return mode == Mode.STYLED


static func mode_name() -> String:
	return "Styled" if is_styled() else "Placeholder"


static func set_mode(new_mode: int) -> void:
	mode = new_mode


# Flips between the two looks. Returns the new mode.
static func toggle() -> int:
	mode = Mode.PLACEHOLDER if is_styled() else Mode.STYLED
	return mode


# Records that `obj` (a node or look that has no styled version) is drawn with its placeholder look.
static func note_placeholder(obj: Object, kind: String) -> void:
	_fallbacks.append({"ref": weakref(obj), "kind": kind})


# How many live objects are using a placeholder look while the styled look is on (0 in placeholder mode, where
# everything is a placeholder by choice).
static func placeholder_fallback_count() -> int:
	if not is_styled():
		return 0
	return _live_fallbacks().size()


# "kind x count, ..." for the F3 line, e.g. "projectile x3, bloom x1".
static func fallback_summary() -> String:
	var counts: Dictionary = {}
	for entry: Dictionary in _live_fallbacks():
		var kind: String = entry["kind"]
		var so_far: int = counts.get(kind, 0)
		counts[kind] = so_far + 1
	var parts: PackedStringArray = []
	for kind: String in counts:
		parts.append("%s x%d" % [kind, counts[kind]])
	return ", ".join(parts)


# One line for the F3 overlay.
static func debug_line() -> String:
	var line := "Look: %s" % mode_name()
	if is_styled():
		line += " (%d on placeholder: %s)" % [placeholder_fallback_count(), fallback_summary()]
	return line


static func _live_fallbacks() -> Array[Dictionary]:
	var live: Array[Dictionary] = []
	for entry: Dictionary in _fallbacks:
		var ref: WeakRef = entry["ref"]
		if ref.get_ref() != null:
			live.append(entry)
	_fallbacks = live
	return live


# ---- Factories. Each returns the look for the current mode. A kind with no styled version returns its placeholder.


static func person_look() -> PersonLook:
	return PersonLookPlaceholder.new()


static func player_look() -> PlayerLook:
	return PlayerLookPlaceholder.new()


static func building_look() -> BuildingLook:
	return BuildingLookPlaceholder.new()


static func landmark_look() -> LandmarkLook:
	return LandmarkLookPlaceholder.new()


static func ground_look() -> GroundLook:
	return GroundLookPlaceholder.new()


static func border_look() -> BorderLook:
	return BorderLookPlaceholder.new()


static func minimap_look() -> MinimapLook:
	return MinimapLookPlaceholder.new()


static func plaza_look() -> PlazaLook:
	return PlazaLookPlaceholder.new()
