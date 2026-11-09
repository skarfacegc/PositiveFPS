class_name StyleHud
extends RefCounted

# Graphics checkpoint 2: the styled drawing of the spirit meter, the prompt bar and the off-screen gap arrows (see
# StyleUi
# for the cell style). The same data, positions and numbers as the placeholder drawing: a stepped parchment-and-ink
# frame, an amber fill with a light top edge and a dark bottom edge, pixel glyphs for the ticks, and
# arrows with an ink edge. HUD text (Labels) stays the placeholder text.

const DIM_LIGHT := Color("#cfcbdd")
const DIM_MAIN := Color("#9c97ad")
const DIM_DARK := Color("#6e6a82")


# Puts the control's local origin on the window's cell grid, so its cells line up with the pixels of the 3D view.
static func align(ci: Control, c: float) -> void:
	var at := ci.get_global_position()
	ci.draw_set_transform((at / c).ceil() * c - at)


static func draw_spirit(m: SpiritMeter) -> void:
	var c := StyleUi.cell(m)
	align(m, c)
	var h := m.size.y
	var bar := Rect2(Vector2.ZERO, m.size)
	StyleUi.cut_rect(m, bar.grow(3.0 * c), c, StyleUi.INK)
	StyleUi.cut_rect(m, bar.grow(2.0 * c), c, StyleUi.PARCHMENT_SHADE)
	StyleUi.cut_rect(m, bar.grow(c), c, StyleUi.INK)
	StyleUi.rect(m, bar, c, StyleUi.NIGHT)
	_fill(m, c, h)
	if m.flash > 0.0:
		var f := m.flash_colour
		f.a = 0.6 * m.flash
		var x := 0.0
		while x < m.size.x:
			m.draw_rect(Rect2(x, 0.0, c, h), f)
			x += 2.0 * c
	_ticks(m, c, h)
	_popups(m, c)
	m.draw_set_transform(Vector2.ZERO)


# The spirit fill: a light top row, a dark bottom pair of rows, and a solid head (no chequer) at its tip.
static func _fill(m: SpiritMeter, c: float, h: float) -> void:
	var cells_wide := floori(m.size.x * clampf(m.spirit / SpiritConfig.SPIRIT_MAX, 0.0, 1.0) / c)
	if cells_wide < 1:
		return
	var light := StyleUi.GOLD_LIGHT
	var main := StyleUi.GOLD
	var dark := StyleUi.GOLD_DARK
	if m.is_dim:
		light = DIM_LIGHT
		main = DIM_MAIN
		dark = DIM_DARK
	var rows := floori(h / c)
	for r: int in range(rows):
		var col := main
		if r == 0:
			col = light
		elif r >= rows - 2:
			col = dark
		StyleUi.run(m, Vector2i(0, r), cells_wide, false, c, col)


# The burst-cost tick with a pixel sunburst above it and the dim-exit tick with a pixel moon below it.
static func _ticks(m: SpiritMeter, c: float, h: float) -> void:
	var bx := floorf(m.burst_tick_x() / c)
	var can := not m.is_dim and m.spirit >= SpiritConfig.BURST_SPIRIT_COST
	var burst_col := Color(1.0, 0.95, 0.75) if can else Color(0.9, 0.5, 0.45)
	var top := floori(-5.0 / c)
	StyleUi.run(m, Vector2i(int(bx), top), floori((h + 7.0) / c) + 1, true, c, StyleUi.INK)
	StyleUi.run(m, Vector2i(int(bx), top + 1), floori((h + 3.0) / c), true, c, burst_col)
	var star := Vector2(bx * c, -16.0)
	StyleUi.sparkle(m, star, 3, c, StyleUi.INK)
	StyleUi.sparkle(m, star, 2, c, burst_col)
	var pulse := 0.5 + 0.5 * sin(m.clock() * TAU * 1.5)
	var dim_col := Color(0.82, 0.8, 0.95, 0.95)
	if m.is_dim:
		dim_col = Color(1.0, 0.95, 0.8, 0.7 + 0.3 * pulse)
	var dx := floorf(m.dim_tick_x() / c)
	StyleUi.run(m, Vector2i(int(dx), floori(-2.0 / c)), floori((h + 8.0) / c), true, c, StyleUi.INK)
	StyleUi.run(m, Vector2i(int(dx), floori(-2.0 / c) + 1), floori((h + 4.0) / c), true, c, dim_col)
	var moon := Vector2i(int(dx), floori((h + 14.0) / c))
	for j: int in range(-3, 4):
		for i: int in range(-3, 4):
			var inside := Vector2(i, j).length() <= 3.2 and Vector2(i - 1.3, j + 0.9).length() > 2.8
			if inside:
				StyleUi.put(m, moon + Vector2i(i, j), c, dim_col)


# The floating numbers: the same text, over a thick ink edge, rising in cell steps.
static func _popups(m: SpiritMeter, c: float) -> void:
	var font := ThemeDB.fallback_font
	for p: Dictionary in m.popups:
		var left: float = p["left"]
		var t := 1.0 - left / HudConfig.SPIRIT_MOMENT_SECONDS
		var shown_text: String = p["text"]
		var col: Color = p["colour"]
		col.a = clampf(left / 0.4, 0.0, 1.0)
		var at := Vector2(m.size.x * 0.5 - 20.0, -26.0 - 34.0 * t)
		at = (at / c).floor() * c
		var ink := StyleUi.INK
		ink.a = col.a
		m.draw_string_outline(
			font, at, shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SpiritMeter.POPUP_FONT_SIZE, int(3.0 * c), ink
		)
		m.draw_string(font, at, shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SpiritMeter.POPUP_FONT_SIZE, col)


# Checkpoint 7: how many of a bar's `cells_wide` cells are gold at `progress` (0 at dusk, 1 at dawn).
static func night_fill_cells(progress: float, cells_wide: int) -> int:
	return floori(float(cells_wide) * clampf(progress, 0.0, 1.0))


# Checkpoint 7: the styled Dusk to Dawn panel: a parchment panel with the placeholder's label on top and, under it, a
# stepped bar that fills gold as the night goes on (a light top row and a dark bottom pair, like the spirit meter).
static func draw_night(ci: Control, progress: float, text: String) -> void:
	var c := StyleUi.cell(ci)
	align(ci, c)
	var size := ci.size
	StyleUi.panel(ci, Rect2(Vector2.ZERO, size), c, StyleUi.PARCHMENT)
	var font := ThemeDB.fallback_font
	var fs := HudConfig.CP7_NIGHT_FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2((size.x - width) * 0.5, HudConfig.CP7_NIGHT_TEXT_Y)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, StyleUi.INK)
	var inset := HudConfig.CP7_NIGHT_BAR_INSET
	var bar_h := HudConfig.CP7_NIGHT_BAR_HEIGHT
	var bar := Rect2(inset, size.y - inset - bar_h, size.x - 2.0 * inset, bar_h)
	StyleUi.rect(ci, bar.grow(c), c, StyleUi.INK)
	StyleUi.rect(ci, bar, c, StyleUi.NIGHT)
	var x0 := floori(bar.position.x / c)
	var y0 := floori(bar.position.y / c)
	var rows := floori(bar.size.y / c)
	var cells := night_fill_cells(progress, floori(bar.size.x / c))
	for r: int in range(rows):
		var col := StyleUi.GOLD
		if r == 0:
			col = StyleUi.GOLD_LIGHT
		elif r >= rows - 2:
			col = StyleUi.GOLD_DARK
		StyleUi.run(ci, Vector2i(x0, y0 + r), cells, false, c, col)


# Checkpoint 7: the styled spirit label: a small parchment tag with an ink frame and a pixel badge (grey when the player
# is dim, gold otherwise). The text is the placeholder label's.
static func draw_tag(ci: Control, text: String, dim: bool) -> void:
	var c := StyleUi.cell(ci)
	align(ci, c)
	var size := ci.size
	StyleUi.panel(ci, Rect2(Vector2.ZERO, size), c, StyleUi.PARCHMENT)
	var mid := size.y * 0.5
	var badge := DIM_MAIN if dim else StyleUi.GOLD
	StyleUi.sparkle(ci, Vector2(14.0, mid), 2, c, StyleUi.INK)
	StyleUi.sparkle(ci, Vector2(14.0, mid), 1, c, badge)
	var font := ThemeDB.fallback_font
	var fs := HudConfig.CP7_TAG_FONT
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2((size.x - width) * 0.5 + 8.0, HudConfig.CP7_TAG_TEXT_Y)
	ci.draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, StyleUi.INK)


# The prompt bar: a parchment panel with an ink frame and stepped corners, the icon at its left and ink text. The bar
# fades with its self_modulate (the panel is opaque).
static func draw_prompt(bar: PromptBar, rect: Rect2, text: String, icon: int, big: bool = false) -> void:
	var c := StyleUi.cell(bar)
	if big:
		# Graphics checkpoint 5: a refusal or notice is a parchment panel with a coral rim and a coral pixel mark at its left
		# (it is sized for the smaller notice font, so the words fit; the placeholder look gives it a coral edge too).
		StyleUi.panel(bar, rect, c, StyleUi.PARCHMENT, Color("#e8453b"))
		var mid := rect.position.y + rect.size.y * 0.5
		StyleUi.sparkle(bar, Vector2(rect.position.x + 22.0, mid), 2, c, StyleUi.INK)
		StyleUi.sparkle(bar, Vector2(rect.position.x + 22.0, mid), 1, c, Color("#e8453b"))
		var fs := bar.font_px
		bar.draw_string(
			ThemeDB.fallback_font,
			Vector2(rect.position.x + 40.0, mid + fs * 0.35),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			fs,
			StyleUi.INK
		)
		return
	StyleUi.panel(bar, rect, c, StyleUi.PARCHMENT)
	var mid_y := rect.position.y + PromptBar.HEIGHT * 0.5
	var text_x := rect.position.x + 24.0
	if icon != MoodIcons.Kind.NONE:
		MoodIcons.draw(bar, icon, Vector2(rect.position.x + 28.0, mid_y), 24.0, MoodIcons.colour_for(icon))
		text_x = rect.position.x + 56.0
	var at := Vector2(text_x, mid_y + PromptBar.FONT_SIZE * 0.35)
	bar.draw_string(ThemeDB.fallback_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, PromptBar.FONT_SIZE, StyleUi.INK)


# One off-screen gap arrow: a solid pointer with an ink edge, in the arrow's pulsing colour.
static func draw_arrow(arrows: GapArrows, pos: Vector2, angle: float, size: float, col: Color) -> void:
	var c := StyleUi.cell(arrows)
	var fwd := Vector2(cos(angle), sin(angle))
	var side := Vector2(-fwd.y, fwd.x)
	var edge := StyleUi.INK
	edge.a = col.a
	for k: int in range(2):
		var grow := 2.0 * c if k == 0 else 0.0
		var s := size + grow
		var tip := pos + fwd * (s + grow * 0.5)
		var a := pos - fwd * s * 0.5 + side * (s * 0.6 + grow)
		var b := pos - fwd * s * 0.5 - side * (s * 0.6 + grow)
		StyleUi.poly(arrows, PackedVector2Array([tip, a, b]), c, edge if k == 0 else col)
