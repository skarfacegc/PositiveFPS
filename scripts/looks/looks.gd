class_name Looks
extends RefCounted

# The look switch. Every main thing on screen has a rules script (person.gd, border.gd, ...) and a look: a separate
# script that reads the rules' public state and draws it. There are two looks: PLACEHOLDER (plain shapes, the default
# and the one the tests use) and STYLED (the locked art style from design/style_test). Anything without a styled
# look falls back to its placeholder look and is counted (see note_placeholder). Every kind below has a styled look;
# what is still placeholder (projectiles, blooms, the burst ring, labels) registers itself with note_placeholder. (The
# target highlight and the HUD text lines have styled looks since checkpoint 6.)
# The mode is static, so it survives a scene reload and the menu choice lasts for the session.

enum Mode { PLACEHOLDER, STYLED }

static var mode: int = Mode.PLACEHOLDER
# True once apply_start_mode has run (it acts only once per process).
static var _start_applied: bool = false
# Objects that always use their placeholder look, even in styled mode: {"ref": WeakRef, "kind": String}.
static var _fallbacks: Array[Dictionary] = []


# Checkpoint 7: the look the game starts in. A `--look=styled|placeholder` user argument wins; otherwise an exported
# build (feature "template") starts styled and everything else (the editor, tests, headless) starts placeholder. F4
# still switches. `args` are the user arguments, `exported` is OS.has_feature("template").
static func start_mode(args: PackedStringArray, exported: bool) -> int:
	for arg: String in args:
		if arg.begins_with(Config.CP7_LOOK_ARG):
			var value := arg.substr(Config.CP7_LOOK_ARG.length()).to_lower()
			if value == "styled":
				return Mode.STYLED
			if value == "placeholder":
				return Mode.PLACEHOLDER
	return Mode.STYLED if exported else Mode.PLACEHOLDER


# Applies the starting look once per process (the menu and the level both call it from _ready, whichever comes first).
# It only ever switches TO styled: the placeholder is already the default, so a test that set a look keeps it.
static func apply_start_mode() -> void:
	if _start_applied:
		return
	_start_applied = true
	apply_start_choice(OS.get_cmdline_user_args(), OS.has_feature("template"))


# The switch itself (apply_start_mode passes the real arguments; tests pass their own).
static func apply_start_choice(args: PackedStringArray, exported: bool) -> void:
	if start_mode(args, exported) == Mode.STYLED:
		mode = Mode.STYLED


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
	return PersonLookStyled.new() if is_styled() else PersonLookPlaceholder.new()


static func player_look() -> PlayerLook:
	return PlayerLookStyled.new() if is_styled() else PlayerLookPlaceholder.new()


static func building_look() -> BuildingLook:
	return BuildingLookStyled.new() if is_styled() else BuildingLookPlaceholder.new()


static func landmark_look() -> LandmarkLook:
	return LandmarkLookStyled.new() if is_styled() else LandmarkLookPlaceholder.new()


static func ground_look() -> GroundLook:
	return GroundLookStyled.new() if is_styled() else GroundLookPlaceholder.new()


static func border_look() -> BorderLook:
	return BorderLookStyled.new() if is_styled() else BorderLookPlaceholder.new()


static func minimap_look() -> MinimapLook:
	return MinimapLookStyled.new() if is_styled() else MinimapLookPlaceholder.new()


static func plaza_look() -> PlazaLook:
	return PlazaLookStyled.new() if is_styled() else PlazaLookPlaceholder.new()
