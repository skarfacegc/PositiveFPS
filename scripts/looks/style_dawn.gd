class_name StyleDawn
extends RefCounted

# Graphics checkpoint 3: the styled drawing of the two round 19 HUD pieces, in pixel cells like the rest of the styled
# UI (see StyleUi): the landmark panel (top right) and the dawn rating end screen. The same data and numbers as the
# placeholder labels; only the drawing differs. Pure visuals: they read nothing from the rules.

const DIM_TEXT := Color("#7a6a58")
const AMBER_TEXT := Color("#9a5a12")
const MET := Color("#6f9552")
const LIGHT_SCALE := 3
const LIGHT_GAP := 24.0
const FOOTER := "Press R to play again, M for the menu"
const FONT_ROW := 16
const FONT_SUB := 13


# The landmark panel: a parchment panel with one row per landmark: its pixel icon (lit when held, grey when not), its
# name and what it gives. `held` is the held flags in Config.LANDMARK_NAMES order.
static func draw_landmarks(ci: Control, held: Array[bool]) -> void:
	var c := StyleUi.cell(ci)
	StyleHud.align(ci, c)
	StyleUi.panel(ci, Rect2(Vector2.ZERO, ci.size), c, StyleUi.PARCHMENT)
	var font := ThemeDB.fallback_font
	var count := 0
	for flag: bool in held:
		if flag:
			count += 1
	var total := Config.LANDMARK_NAMES.size()
	ci.draw_string(
		font,
		Vector2(14.0, 26.0),
		"Landmarks %d of %d" % [count, total],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_ROW,
		StyleUi.INK
	)
	for i: int in range(total):
		var on := i < held.size() and held[i]
		var y := 38.0 + 40.0 * float(i)
		var rows := StyleGlyphs.landmark_rows(i)
		StyleGlyphs.draw(ci, "landmark%d" % i, rows, Vector2(14.0, y), c, StyleGlyphs.landmark_palette(i, on))
		var text_x := 14.0 + float(StyleGlyphs.size_of("landmark%d" % i, rows).x) * c + 8.0
		var name_col := StyleUi.INK if on else DIM_TEXT
		ci.draw_string(
			font, Vector2(text_x, y + 14.0), Config.LANDMARK_NAMES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_ROW, name_col
		)
		var sub_col := AMBER_TEXT if on else DIM_TEXT
		ci.draw_string(
			font,
			Vector2(text_x, y + 30.0),
			Config.LANDMARK_BOOST_TEXT[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			FONT_SUB,
			sub_col
		)
	ci.draw_set_transform(Vector2.ZERO)


# The plain detail lines of the end screen: the detail text without the text version of the lights and without the
# reason lines (those are drawn with icons).
static func plain_lines(detail: String, rating: Dictionary) -> Array[String]:
	var skip: Array[String] = []
	if not rating.is_empty():
		skip.assign(rating["lines"] as Array)
	var out: Array[String] = []
	for line: String in detail.split("\n"):
		if line.is_empty() or line.begins_with("Dawn lights:") or skip.has(line):
			continue
		out.append(line)
	return out


# Which of the three goals (people, ground, landmarks) a rating meets at its lower mark.
static func goals_met(rating: Dictionary) -> Array[bool]:
	var people: float = rating["people"]
	var ground: float = rating["ground"]
	var landmarks: int = rating["landmarks"]
	return [people >= Config.DAWN_PEOPLE_LOW, ground >= Config.DAWN_GROUND_LOW, landmarks >= Config.DAWN_LANDMARKS_LOW]


# The dawn rating end screen: a parchment panel with the title, the three dawn lights (lit or out), the reasons with
# their pixel icons and ticks, the other detail lines and the footer. `rating` is empty when the round was lost.
static func draw_dawn(ci: Control, title: String, detail: String, rating: Dictionary) -> void:
	var c := StyleUi.cell(ci)
	var plain := plain_lines(detail, rating)
	var lights_h := 0.0
	if not rating.is_empty():
		lights_h = float(StyleGlyphs.size_of("sun_lit", StyleGlyphs.SUN_LIT).y * LIGHT_SCALE) * c
	var h := 28.0 + 46.0 + 40.0 + float(plain.size()) * 28.0
	if not rating.is_empty():
		h += lights_h + 18.0 + 3.0 * 46.0 + 8.0
	var w := minf(ci.size.x - 80.0, 760.0)
	var panel := Rect2((ci.size - Vector2(w, h)) * 0.5, Vector2(w, h))
	panel.position = (panel.position / c).floor() * c
	StyleUi.panel(ci, panel, c, StyleUi.PARCHMENT)
	var font := ThemeDB.fallback_font
	var y := panel.position.y + 28.0
	ci.draw_string(font, Vector2(panel.position.x, y + 24.0), title, HORIZONTAL_ALIGNMENT_CENTER, w, 30, StyleUi.INK)
	y += 46.0
	if not rating.is_empty():
		var lit: int = rating["lights"]
		y = _draw_lights(ci, panel, y, lit, c)
		y = _draw_reasons(ci, panel, y, rating, c)
	for line: String in plain:
		ci.draw_string(font, Vector2(panel.position.x, y + 18.0), line, HORIZONTAL_ALIGNMENT_CENTER, w, 18, StyleUi.INK)
		y += 28.0
	ci.draw_string(
		font, Vector2(panel.position.x, panel.end.y - 22.0), FOOTER, HORIZONTAL_ALIGNMENT_CENTER, w, FONT_ROW, DIM_TEXT
	)


# Three dawn lights in a row, `lit` of them lit. Returns the next y.
static func _draw_lights(ci: Control, panel: Rect2, y: float, lit: int, c: float) -> float:
	var cw := c * float(LIGHT_SCALE)
	var size := StyleGlyphs.size_of("sun_lit", StyleGlyphs.SUN_LIT)
	var icon_w := float(size.x) * cw
	var total_w := 3.0 * icon_w + 2.0 * LIGHT_GAP
	var x := panel.position.x + (panel.size.x - total_w) * 0.5
	for i: int in range(3):
		var on := i < lit
		var rows := StyleGlyphs.SUN_LIT if on else StyleGlyphs.SUN_OUT
		var key := "sun_lit" if on else "sun_out"
		StyleGlyphs.draw(ci, key, rows, Vector2(x, y), cw, StyleGlyphs.sun_palette(on))
		if on:
			var mid := Vector2(x + icon_w * 0.5, y + 4.0 * cw)
			StyleUi.sparkle(ci, mid, 1, cw, StyleUi.GOLD_LIGHT)
		x += icon_w + LIGHT_GAP
	return y + float(size.y) * cw + 18.0


# The three reason lines, each with its pixel icon and a tick when that goal is met. Returns the next y.
static func _draw_reasons(ci: Control, panel: Rect2, y: float, rating: Dictionary, c: float) -> float:
	var font := ThemeDB.fallback_font
	var met := goals_met(rating)
	var lines: Array[String] = []
	lines.assign(rating["lines"] as Array)
	var icons: Array[Array] = [StyleGlyphs.PERSON, StyleGlyphs.COBBLES, StyleGlyphs.STAR]
	var left := panel.position.x + 56.0
	for i: int in range(mini(3, lines.size())):
		var rows := icons[i]
		var pal := StyleGlyphs.palette_for(
			Color("#c0604f") if i == 0 else (Color("#8aa55a") if i == 1 else StyleUi.GOLD)
		)
		StyleGlyphs.draw(ci, "reason%d" % i, rows, Vector2(left, y + 2.0), c * 2.0, pal)
		var text_col := StyleUi.INK if met[i] else DIM_TEXT
		ci.draw_string(font, Vector2(left + 60.0, y + 24.0), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, text_col)
		var tick_at := Vector2(panel.end.x - 90.0, y + 4.0)
		if met[i]:
			StyleGlyphs.draw(ci, "tick", StyleGlyphs.TICK, tick_at, c * 2.0, StyleGlyphs.palette_for(MET))
		else:
			var dash := c * 2.0
			StyleUi.run(ci, StyleUi.cell_of(tick_at + Vector2(0.0, 14.0 * c), dash), 4, false, dash, DIM_TEXT)
		y += 46.0
	return y + 8.0
