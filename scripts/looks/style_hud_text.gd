class_name StyleHudText
extends RefCounted

# Checkpoint 6: the styled look's HUD text lines (the rescued count, the target line, the burst line, the targeting
# line and the key line), each a small parchment panel in the same cell style as the landmark panel and the minimap
# frame: an ink outline, a parchment rim, a pixel badge at the left and the words in ink. The Hud feeds the same text
# its Labels show (the placeholder look keeps those). A line has a state: IDLE (parchment), READY (pale gold with an
# amber rim), WARN (a coral rim, for a need) or DIM (greyed words, for a wait or no target). Pure visuals: they read
# nothing from the rules.

const IDLE := 0
const READY := 1
const WARN := 2
const DIM := 3

const PAD := 12.0
const ICON_W := 30.0
const SEP_W := 18.0
const READY_FILL := Color("#fff1b8")
const CORAL := Color("#e8453b")
const WARN_TEXT := Color("#8a2f26")
const DIM_TEXT := Color("#7a6a58")
const KEY_TEXT := Color("#9a5a12")


# The width a line of `text` needs.
static func line_width(kind: int, text: String) -> float:
	if kind == StyledPanel.Kind.KEYS:
		return PAD * 2.0 + keys_width(text)
	var w := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudConfig.CP6_LINE_FONT).x
	return PAD * 2.0 + ICON_W + w


# The width of the key line's words: each "|"-separated part, a gap and a pixel mark between them.
static func keys_width(text: String) -> float:
	var parts := text.split(" | ")
	var w := 0.0
	for part: String in parts:
		w += _part_width(part)
	return w + SEP_W * float(maxi(parts.size() - 1, 0))


static func _part_width(part: String) -> float:
	var font := ThemeDB.fallback_font
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, HudConfig.CP6_KEY_FONT).x
	var w := 0.0
	var tokens := part.split(" ")
	for t: String in tokens:
		w += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, HudConfig.CP6_KEY_FONT).x
	return w + space * float(maxi(tokens.size() - 1, 0))


# True for a word that names a key or a mouse button (drawn in amber in the key line).
static func is_key(token: String) -> bool:
	if token in ["Shift", "Click", "Right-click"]:
		return true
	if token.is_empty():
		return false
	for ch: String in token:
		if ch != ch.to_upper() or ch == ",":
			return false
	return true


# Draws one line panel: `ci.size` is its rectangle. `colour` is the badge colour (the target's element, or gold).
static func draw(ci: Control, kind: int, text: String, state: int, colour: Color) -> void:
	var c := StyleUi.cell(ci)
	StyleHud.align(ci, c)
	var rim := StyleUi.PARCHMENT_SHADE
	var fill := StyleUi.PARCHMENT
	if state == READY:
		rim = StyleUi.AMBER
		fill = READY_FILL
	elif state == WARN:
		rim = CORAL
	if kind == StyledPanel.Kind.PEOPLE:
		# Walls and gates: Style update (#94). The people line is slimmer than the others (it sits in the 25 px between
		# the spirit meter's marker and the key strip): an ink outline round a parchment fill, coral when short.
		var edge := CORAL if state == WARN else StyleUi.INK
		StyleUi.cut_rect(ci, Rect2(Vector2.ZERO, ci.size), c, edge)
		StyleUi.cut_rect(ci, Rect2(Vector2.ZERO, ci.size).grow(-c), c, fill)
	else:
		StyleUi.panel(ci, Rect2(Vector2.ZERO, ci.size), c, fill, rim)
	var mid := ci.size.y * 0.5
	if kind == StyledPanel.Kind.KEYS:
		_draw_keys(ci, text, mid)
		ci.draw_set_transform(Vector2.ZERO)
		return
	_draw_icon(ci, kind, state, colour, Vector2(PAD + ICON_W * 0.5 - 4.0, mid), c)
	var ink := StyleUi.INK
	if state == DIM:
		ink = DIM_TEXT
	elif state == WARN:
		ink = WARN_TEXT
	var at := Vector2(PAD + ICON_W, mid + float(HudConfig.CP6_LINE_FONT) * 0.35)
	ci.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, HudConfig.CP6_LINE_FONT, ink)
	ci.draw_set_transform(Vector2.ZERO)


static func _draw_icon(ci: Control, kind: int, state: int, colour: Color, centre: Vector2, c: float) -> void:
	if kind == StyledPanel.Kind.PEOPLE:  # A small bead (the line is too slim for the person glyph): gold, coral if short.
		_disc(ci, centre, 3, c, StyleUi.INK)
		_disc(ci, centre, 2, c, CORAL if state == WARN else StyleUi.GOLD)
		_disc(ci, centre + Vector2(-c, -c), 1, c, StyleUi.GOLD_LIGHT)
	elif kind == StyledPanel.Kind.RESCUED:
		var rows := StyleGlyphs.PERSON
		var cells := StyleGlyphs.size_of("hud_person", rows)
		var at := centre - Vector2(cells) * c * 0.5
		StyleGlyphs.draw(ci, "hud_person", rows, at, c, StyleGlyphs.palette_for(colour))
	elif kind == StyledPanel.Kind.TARGET:
		var col := colour if state != DIM else StyleHud.DIM_MAIN
		_disc(ci, centre, 5, c, StyleUi.INK)
		_disc(ci, centre, 4, c, col.lerp(Color.WHITE, 0.45))
		_disc(ci, centre + Vector2(c, c), 3, c, col)
		if state == DIM:  # No target: an empty badge.
			_disc(ci, centre, 2, c, StyleUi.PARCHMENT)
	elif kind == StyledPanel.Kind.BURST:
		var col := StyleUi.GOLD
		if state == WARN:
			col = CORAL
		elif state == DIM:
			col = StyleHud.DIM_MAIN
		StyleUi.sparkle(ci, centre, 5, c, StyleUi.INK)
		StyleUi.sparkle(ci, centre, 4, c, col)
		StyleUi.sparkle(ci, centre, 1, c, StyleUi.GOLD_LIGHT if state == READY else StyleUi.PARCHMENT)
	elif kind == StyledPanel.Kind.TARGETING:
		StyleUi.ring(ci, centre, 8.0, c, StyleUi.INK, 3)
		StyleUi.ring(ci, centre, 8.0, c, StyleUi.AMBER, 1)
		StyleUi.put(ci, StyleUi.cell_of(centre, c), c, StyleUi.INK)


# A filled disc of `r` cells round `centre`.
static func _disc(ci: CanvasItem, centre: Vector2, r: int, c: float, col: Color) -> void:
	var mid := StyleUi.cell_of(centre, c)
	for dy: int in range(-r, r + 1):
		for dx: int in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r + r:
				StyleUi.put(ci, mid + Vector2i(dx, dy), c, col)


# The key line: the "|"-separated parts in ink with the key names in amber, and a small gold pixel mark between parts.
static func _draw_keys(ci: Control, text: String, mid: float) -> void:
	var font := ThemeDB.fallback_font
	var fs := HudConfig.CP6_KEY_FONT
	var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var base := mid + float(fs) * 0.35
	var c := StyleUi.cell(ci)
	var x := PAD
	var parts := text.split(" | ")
	for i: int in range(parts.size()):
		for t: String in parts[i].split(" "):
			var col := KEY_TEXT if is_key(t) else StyleUi.INK
			ci.draw_string(font, Vector2(x, base), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
			x += font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + space
		x -= space
		if i < parts.size() - 1:
			var spot := StyleUi.cell_of(Vector2(x + SEP_W * 0.5, mid), c)
			StyleUi.put(ci, spot, c, StyleUi.AMBER)
			for off: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				StyleUi.put(ci, spot + off, c, StyleUi.GOLD_DARK)
			x += SEP_W
