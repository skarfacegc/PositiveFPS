class_name StyleUi
extends RefCounted

# Graphics checkpoint 2: the styled look of the screen-space UI (the feedback layer, the mood icons, the spirit
# meter, the
# prompt bar, the off-screen gap arrows). The UI stays at window resolution, so the pixel style is made by drawing in
# "cells": squares as big as one pixel of the 640x360 view (window height / 360, so a cell lines up with the pixels of
# the 3D view), with a dark ink outline, parchment and amber colours from the locked style, dithered tracks and fills,
# and stepped (not round) corners. Pure visuals: every function draws on a CanvasItem and reads nothing from the rules.
# Icons are small hand-made bitmaps (original shapes), outlined and shaded by code.

const INK := Color("#3a2a20")
const PARCHMENT := Color("#f0d9a8")
const PARCHMENT_SHADE := Color("#d2b27a")
const AMBER := Color("#e8963a")
const GOLD := Color("#ffc94d")
const GOLD_LIGHT := Color("#ffe9a0")
const GOLD_DARK := Color("#d9962e")
const NIGHT := Color("#2a2036")
const GLYPH_SIZE := 11
# The badge round an icon: a disc of 15 cells inside a rim of one cell (17 cells across).
const BADGE_INNER := 7.5
const BADGE_OUTER := 8.5

# The icon bitmaps, 11 x 11 ('#' main colour, 'd' dark, 'l' light, '.' empty). The outline and the shading are added by
# glyph_rows(). Kinds follow MoodIcons.Kind (NONE has no bitmap).
const GLYPHS: Dictionary = {
	1:
	[
		"###########",
		"#####d#####",
		"###ddddd###",
		"#####d#####",
		"#####d#####",
		".####d####.",
		".####d####.",
		"..#######..",
		"...#####...",
		"....###....",
		".....#.....",
	],
	2:
	[
		"...........",
		"......####.",
		"##...######",
		".....######",
		"......####.",
		"...........",
		"..####.....",
		".######....",
		"##.######..",
		"..####.....",
		"...........",
	],
	3:
	[
		"...........",
		"....####...",
		"..#######..",
		".#########.",
		"###########",
		"###########",
		".#########.",
		"...........",
		"..l...l...l",
		"...l...l...",
		"...........",
	],
	4:
	[
		"....###....",
		"..###d###..",
		".##d###d##.",
		"##d#####d##",
		"#.#.#.#.#.#",
		".....#.....",
		".....#.....",
		".....#.....",
		".....#.....",
		"....##.....",
		"...........",
	],
	5:
	[
		"....###....",
		"....###....",
		"....###....",
		"....###....",
		"....###....",
		".....#.....",
		"...........",
		"....###....",
		"....###....",
		"....###....",
		"...........",
	],
}

static var _glyph_cache: Dictionary = {}

# ---- Cells --------------------------------------------------------------------------------------------------------


# The size in window pixels of one cell (one pixel of the 640x360 view), at least 1.
static func cell(ci: CanvasItem) -> float:
	return maxf(1.0, roundf(ci.get_viewport_rect().size.y / float(ViewPipeline.VIEW_HEIGHT)))


# The cell index (column, row) of a window position.
static func cell_of(p: Vector2, c: float) -> Vector2i:
	return Vector2i(floori(p.x / c), floori(p.y / c))


# One filled cell.
static func put(ci: CanvasItem, at: Vector2i, c: float, col: Color) -> void:
	ci.draw_rect(Rect2(Vector2(at) * c, Vector2(c, c)), col)


# A run of `count` cells across (or `count` down when `down`) from cell `at`.
static func run(ci: CanvasItem, at: Vector2i, count: int, down: bool, c: float, col: Color) -> void:
	if count <= 0:
		return
	var size := Vector2(c, c * float(count)) if down else Vector2(c * float(count), c)
	ci.draw_rect(Rect2(Vector2(at) * c, size), col)


# A rectangle snapped to the cell grid (outside edges rounded out).
static func rect(ci: CanvasItem, r: Rect2, c: float, col: Color) -> void:
	var a := Vector2(floorf(r.position.x / c), floorf(r.position.y / c)) * c
	var b := Vector2(ceilf(r.end.x / c), ceilf(r.end.y / c)) * c
	ci.draw_rect(Rect2(a, b - a), col)


# A rectangle with its four corner cells cut off (the stepped corner of the style).
static func cut_rect(ci: CanvasItem, r: Rect2, c: float, col: Color) -> void:
	var a := Vector2(floorf(r.position.x / c), floorf(r.position.y / c)) * c
	var b := Vector2(ceilf(r.end.x / c), ceilf(r.end.y / c)) * c
	var s := b - a
	ci.draw_rect(Rect2(a + Vector2(c, 0.0), Vector2(s.x - 2.0 * c, s.y)), col)
	ci.draw_rect(Rect2(a + Vector2(0.0, c), Vector2(s.x, s.y - 2.0 * c)), col)


# A framed panel: an ink outline, a parchment rim, a shaded inner line and the fill, with stepped corners. Opaque
# (fade it
# with the node's self_modulate).
static func panel(ci: CanvasItem, r: Rect2, c: float, fill: Color, rim: Color = PARCHMENT_SHADE) -> void:
	cut_rect(ci, r, c, INK)
	cut_rect(ci, r.grow(-c), c, rim)
	cut_rect(ci, r.grow(-2.0 * c), c, fill)


# A filled disc of `radius` window pixels, in cell rows.
static func disc(ci: CanvasItem, centre: Vector2, radius: float, c: float, col: Color) -> void:
	var mid := cell_of(centre, c)
	var rc := radius / c
	var reach := ceili(rc)
	for j: int in range(-reach, reach + 1):
		var w := floori(sqrt(maxf(rc * rc - float(j * j), 0.0)) + 0.5)
		run(ci, mid + Vector2i(-w, j), 2 * w + 1, false, c, col)


# A ring (or an arc) of cells: `thick` cells wide, `flatten` squashes it vertically, from angle `a0` to `a1` (radians,
# from the +x axis, clockwise on screen). `checker` leaves every other cell out (a dithered track).
static func ring(
	ci: CanvasItem,
	centre: Vector2,
	radius: float,
	c: float,
	col: Color,
	thick: int = 1,
	flatten: float = 1.0,
	a0: float = 0.0,
	a1: float = TAU,
	checker: bool = false
) -> void:
	var r_out := radius + float(thick) * c * 0.5
	var r_in := maxf(radius - float(thick) * c * 0.5, 0.0)
	var whole := a1 - a0 >= TAU - 0.001 and not checker
	var span := a1 - a0
	var j0 := floori((centre.y - r_out * flatten) / c)
	var j1 := floori((centre.y + r_out * flatten) / c)
	for j: int in range(j0, j1 + 1):
		var dy := ((float(j) + 0.5) * c - centre.y) / flatten
		var out_sq := r_out * r_out - dy * dy
		if out_sq < 0.0:
			continue
		var in_sq := r_in * r_in - dy * dy
		var dx_out := sqrt(out_sq)
		var dx_in := sqrt(in_sq) if in_sq > 0.0 else 0.0
		# The cells whose centres lie in [dx_in, dx_out] from the centre, on the right and on the left.
		var right_a := ceili((centre.x + dx_in) / c - 0.5)
		var right_b := floori((centre.x + dx_out) / c - 0.5)
		var left_a := ceili((centre.x - dx_out) / c - 0.5)
		var left_b := floori((centre.x - dx_in) / c - 0.5)
		if in_sq <= 0.0:
			left_b = mini(left_b, right_a - 1)
		if whole:
			run(ci, Vector2i(right_a, j), right_b - right_a + 1, false, c, col)
			run(ci, Vector2i(left_a, j), left_b - left_a + 1, false, c, col)
			continue
		for i: int in range(left_a, right_b + 1):
			if i > left_b and i < right_a:
				continue
			if checker and (i + j) % 2 != 0:
				continue
			var ang := atan2(dy, (float(i) + 0.5) * c - centre.x)
			if fposmod(ang - a0, TAU) <= span:
				put(ci, Vector2i(i, j), c, col)


# A line of cells from `a` to `b`; `every` 2 draws every other cell (dotted).
static func line(ci: CanvasItem, a: Vector2, b: Vector2, c: float, col: Color, every: int = 1) -> void:
	var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / c))
	var last := Vector2i(-999999, -999999)
	var n := 0
	for i: int in range(steps + 1):
		var at := cell_of(a.lerp(b, float(i) / float(steps)), c)
		if at == last:
			continue
		last = at
		if n % every == 0:
			put(ci, at, c, col)
		n += 1


# A filled polygon in cells (a cell is filled when its centre is inside).
static func poly(ci: CanvasItem, pts: PackedVector2Array, c: float, col: Color) -> void:
	var lo := pts[0]
	var hi := pts[0]
	for p: Vector2 in pts:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	var a := cell_of(lo, c)
	var b := cell_of(hi, c)
	for j: int in range(a.y, b.y + 1):
		var start := -1
		for i: int in range(a.x, b.x + 2):
			var inside := i <= b.x and Geometry2D.is_point_in_polygon((Vector2(i, j) + Vector2(0.5, 0.5)) * c, pts)
			if inside and start < 0:
				start = i
			elif not inside and start >= 0:
				run(ci, Vector2i(start, j), i - start, false, c, col)
				start = -1


# A small four-point sparkle (a plus shape) centred on a window position, `arm` cells long.
static func sparkle(ci: CanvasItem, centre: Vector2, arm: int, c: float, col: Color) -> void:
	var mid := cell_of(centre, c)
	run(ci, mid + Vector2i(-arm, 0), 2 * arm + 1, false, c, col)
	run(ci, mid + Vector2i(0, -arm), 2 * arm + 1, true, c, col)


# ---- Icons --------------------------------------------------------------------------------------------------------


# The 13 x 13 rows of icon `kind` (outline added, light and dark edges shaded), with `tatter` 0 to 3 holes shot in a
# canopy (the worn umbrella). Cached. Characters: 'o' ink outline, '#' main, 'l' light, 'd' dark, '.' empty.
static func glyph_rows(kind: int, tatter: int = 0) -> Array[String]:
	var key := kind * 10 + tatter
	if _glyph_cache.has(key):
		var cached: Array[String] = _glyph_cache[key]
		return cached
	var out: Array[String] = []
	var src: Array = GLYPHS.get(kind, [])
	var n := GLYPH_SIZE
	var fill: Array[Array] = []
	for y: int in range(n):
		var row: Array = []
		var line_src: String = src[y] if y < src.size() else ".".repeat(n)
		for x: int in range(n):
			var ch := line_src[x]
			# Tatter: hash out some of the canopy (the top four rows of the umbrella).
			if tatter > 0 and kind == 4 and y < 4 and ch != "." and _hole(x, y) < 0.14 * float(tatter):
				ch = "."
			row.append(ch)
		fill.append(row)
	for y: int in range(-1, n + 1):
		var text := ""
		for x: int in range(-1, n + 1):
			var here := _cell(fill, x, y)
			if here != ".":
				text += _shade(fill, x, y, here)
			elif (
				_cell(fill, x - 1, y) != "."
				or _cell(fill, x + 1, y) != "."
				or _cell(fill, x, y - 1) != "."
				or _cell(fill, x, y + 1) != "."
			):
				text += "o"
			else:
				text += "."
		out.append(text)
	_glyph_cache[key] = out
	return out


static func _cell(fill: Array[Array], x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= GLYPH_SIZE or y >= GLYPH_SIZE:
		return "."
	var row: Array = fill[y]
	var ch: String = row[x]
	return ch


# A main-colour cell takes a light edge on its upper left and a dark edge on its lower right.
static func _shade(fill: Array[Array], x: int, y: int, here: String) -> String:
	if here != "#":
		return here
	if _cell(fill, x - 1, y) == "." or _cell(fill, x, y - 1) == ".":
		return "l"
	if _cell(fill, x + 1, y) == "." or _cell(fill, x, y + 1) == ".":
		return "d"
	return "#"


static func _hole(x: int, y: int) -> float:
	return fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)


# How many tatter steps (0 to 3) an umbrella with `wear` (1 fresh, 0.25 about to pop) shows.
static func tatter_for(wear: float) -> int:
	return clampi(roundi((1.0 - wear) / 0.75 * 3.0), 0, 3)


# Draws icon `kind` on `ci`: a dark badge with a rim and the outlined bitmap inside it, centred on `centre`. `size`
# is the
# placeholder's size in pixels (26 for a normal icon): the cells grow in whole steps with it. `colour.a` fades it all.
static func draw_icon(
	ci: CanvasItem, kind: int, centre: Vector2, size: float, colour: Color, wear: float = 1.0
) -> void:
	var c := cell(ci) * float(maxi(1, roundi(size / Config.MOOD_ICON_SIZE)))
	var mid := cell_of(centre, c)
	var alpha := colour.a
	var ink := INK
	ink.a = alpha
	var rim := colour.lerp(PARCHMENT, 0.35)
	rim.a = alpha
	var back := NIGHT
	back.a = 0.9 * alpha
	for j: int in range(-8, 9):
		var wo := floori(sqrt(maxf(BADGE_OUTER * BADGE_OUTER - float(j * j), 0.0)))
		var wi_sq := BADGE_INNER * BADGE_INNER - float(j * j)
		if wi_sq < 0.0:
			run(ci, mid + Vector2i(-wo, j), 2 * wo + 1, false, c, rim)
			continue
		var wi := floori(sqrt(wi_sq))
		run(ci, mid + Vector2i(-wo, j), wo - wi, false, c, rim)
		run(ci, mid + Vector2i(-wi, j), 2 * wi + 1, false, c, back)
		run(ci, mid + Vector2i(wi + 1, j), wo - wi, false, c, rim)
	if kind < 1 or kind > 5:
		return
	var rows := glyph_rows(kind, tatter_for(wear) if kind == 4 else 0)
	var light := colour.lerp(Color.WHITE, 0.5)
	var dark := colour.lerp(INK, 0.5)
	var palette: Dictionary = {"o": ink, "#": colour, "l": light, "d": dark}
	var origin := mid - Vector2i(6, 6)
	for y: int in range(rows.size()):
		var row := rows[y]
		var x := 0
		while x < row.length():
			var ch := row[x]
			if ch == ".":
				x += 1
				continue
			var end := x
			while end < row.length() and row[end] == ch:
				end += 1
			var col: Color = palette[ch]
			col.a = alpha
			run(ci, origin + Vector2i(x, y), end - x, false, c, col)
			x = end
