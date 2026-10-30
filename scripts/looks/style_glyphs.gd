class_name StyleGlyphs
extends RefCounted

# Graphics checkpoint 3: the pixel bitmaps of the round 19 screens (the dawn lights, the three landmarks, the reason
# icons and a tick). Original shapes, drawn in cells (see StyleUi) with an ink outline and a light and dark edge added
# by code, like the checkpoint 2 icons. Characters: '#' main colour (shaded), any other letter a colour of its own
# from the palette, '.' empty, 'o' ink outline (added), 'l' and 'd' the light and dark edges of '#' (added).

const SUN_LIT: Array[String] = [
	".......h.......",
	".......h.......",
	"..h.........h..",
	"...h.#####.h...",
	"....#######....",
	"...#########...",
	"...#########...",
	"hh.#########.hh",
	"...#########...",
	"...#########...",
	"....#######....",
	"...h.#####.h...",
	"..h.........h..",
	".......h.......",
	".......h.......",
]
const SUN_OUT: Array[String] = [
	"...............",
	"...............",
	"...............",
	".....#####.....",
	"....#######....",
	"...#########...",
	"...#########...",
	"...#########...",
	"...#########...",
	"...#########...",
	"....#######....",
	".....#####.....",
	"...............",
	"...............",
	"...............",
]
const BANDSTAND: Array[String] = [
	".....h.....",
	"....###....",
	"..#######..",
	".#########.",
	"###########",
	".b...b...b.",
	".b...b...b.",
	".b...b...b.",
	"ggggggggggg",
	"ggggggggggg",
]
const GARDEN: Array[String] = [
	"...#####...",
	".#h#####h#.",
	"###########",
	"##h#####h##",
	".#########.",
	".....b.....",
	".....b.....",
	"ggggbbbgggg",
	"ggggggggggg",
]
const BELL: Array[String] = [
	".....b.....",
	"....###....",
	"...#####...",
	"...#####...",
	"..#######..",
	"..#######..",
	".#########.",
	"###########",
	".....h.....",
]
const PERSON: Array[String] = [
	"...###...",
	"..#####..",
	"..#####..",
	"...###...",
	".#######.",
	"#########",
	"#########",
	"#########",
]
const COBBLES: Array[String] = [
	"##.###.###.",
	"##.###.###.",
	".###.###.##",
	".###.###.##",
	"##.###.###.",
	"##.###.###.",
]
const STAR: Array[String] = [
	".....#.....",
	".....#.....",
	"....###....",
	"###########",
	".#########.",
	"..#######..",
	"..#######..",
	".####.####.",
	".##.....##.",
]
const TICK: Array[String] = [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
]

static var _cache: Dictionary = {}


# The rows of bitmap `key` with the outline and the edge shading added (cached).
static func outlined(key: String, rows: Array[String]) -> Array[String]:
	if _cache.has(key):
		var cached: Array[String] = _cache[key]
		return cached
	var out: Array[String] = []
	var h := rows.size()
	var w := rows[0].length()
	for y: int in range(-1, h + 1):
		var text := ""
		for x: int in range(-1, w + 1):
			var here := _at(rows, x, y)
			if here == "#":
				text += _edge(rows, x, y)
			elif here != ".":
				text += here
			elif _near_filled(rows, x, y):
				text += "o"
			else:
				text += "."
		out.append(text)
	_cache[key] = out
	return out


static func _at(rows: Array[String], x: int, y: int) -> String:
	if y < 0 or y >= rows.size() or x < 0 or x >= rows[y].length():
		return "."
	return rows[y][x]


static func _near_filled(rows: Array[String], x: int, y: int) -> bool:
	return (
		_at(rows, x - 1, y) != "."
		or _at(rows, x + 1, y) != "."
		or _at(rows, x, y - 1) != "."
		or _at(rows, x, y + 1) != "."
	)


# A main-colour cell takes a light edge on its upper left and a dark edge on its lower right.
static func _edge(rows: Array[String], x: int, y: int) -> String:
	if _at(rows, x - 1, y) == "." or _at(rows, x, y - 1) == ".":
		return "l"
	if _at(rows, x + 1, y) == "." or _at(rows, x, y + 1) == ".":
		return "d"
	return "#"


# The palette of a main colour: '#', its light and dark edges and the ink outline.
static func palette_for(main: Color, extra: Dictionary = {}) -> Dictionary:
	var pal: Dictionary = {
		"#": main, "l": main.lerp(Color.WHITE, 0.5), "d": main.lerp(StyleUi.INK, 0.45), "o": StyleUi.INK
	}
	pal.merge(extra, true)
	return pal


# The width and height in cells of an outlined bitmap.
static func size_of(key: String, rows: Array[String]) -> Vector2i:
	var o := outlined(key, rows)
	return Vector2i(o[0].length(), o.size())


# Draws bitmap `key` with its top-left cell at window position `at`, cells `c` pixels wide, in `palette`. A letter that
# is not in the palette is skipped; `alpha` fades it all.
static func draw(
	ci: CanvasItem, key: String, rows: Array[String], at: Vector2, c: float, palette: Dictionary, alpha: float = 1.0
) -> void:
	var o := outlined(key, rows)
	var origin := StyleUi.cell_of(at, c)
	for y: int in range(o.size()):
		var row := o[y]
		var x := 0
		while x < row.length():
			var ch := row[x]
			var end := x
			while end < row.length() and row[end] == ch:
				end += 1
			if ch != "." and palette.has(ch):
				var col: Color = palette[ch]
				col.a *= alpha
				StyleUi.run(ci, origin + Vector2i(x, y), end - x, false, c, col)
			x = end


# ---- Palettes of the round 19 pieces ---------------------------------------------------------------------------------


# The dawn light: lit (a round honey sun with eight rays) or out (a dimmed, rayless disc). Graphics checkpoint 4: no
# ground band under it, which read as a hill.
static func sun_palette(lit: bool) -> Dictionary:
	if lit:
		return palette_for(StyleUi.GOLD, {"h": StyleUi.GOLD_LIGHT})
	return palette_for(StyleHud.DIM_MAIN, {"h": StyleHud.DIM_LIGHT})


# A landmark's icon colours: lit when held, grey when not.
static func landmark_palette(index: int, held: bool) -> Dictionary:
	if not held:
		return palette_for(
			StyleHud.DIM_MAIN, {"h": StyleHud.DIM_LIGHT, "b": StyleHud.DIM_DARK, "g": StyleHud.DIM_LIGHT}
		)
	if index == Landmarks.GARDEN:
		return palette_for(Color("#6f9552"), {"h": Color("#e8453b"), "b": Color("#8a5a3c"), "g": Color("#c9b389")})
	if index == Landmarks.BELL_TOWER:
		return palette_for(Color("#e5b04a"), {"h": Color("#7a5538"), "b": Color("#7a5538")})
	return palette_for(Color("#5f86b0"), {"h": Color("#ffd466"), "b": Color("#f1dfbd"), "g": Color("#c9b389")})


# The bitmap rows of a landmark's icon.
static func landmark_rows(index: int) -> Array[String]:
	if index == Landmarks.GARDEN:
		return GARDEN
	if index == Landmarks.BELL_TOWER:
		return BELL
	return BANDSTAND
