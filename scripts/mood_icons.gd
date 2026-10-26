class_name MoodIcons
extends RefCounted

# Round 13b: the small icons of the game's communication (screen-space UI, drawn with _draw on any CanvasItem, so they
# show in both looks). Original, simple shapes: a shield (guarded), speed lines and feet (skittish), a cloud (glum), an
# umbrella (sheltered) and a "!" (a faltering border person). Each is drawn inside a box `size` pixels wide, centred on
# `centre`, on a dark round badge so it reads on any ground.

enum Kind { NONE, SHIELD, FEET, CLOUD, UMBRELLA, BANG }

const BADGE_COLOUR := Color(0.09, 0.07, 0.14, 0.72)


# The icon that stands for a mood (Person.Mood).
static func kind_for_mood(mood: int) -> int:
	match mood:
		Person.Mood.GUARDED:
			return Kind.SHIELD
		Person.Mood.SKITTISH:
			return Kind.FEET
		Person.Mood.GLUM:
			return Kind.CLOUD
	return Kind.NONE


# The icon of a blocked-joy reason (Person.Block).
static func kind_for_block(reason: int) -> int:
	return Kind.UMBRELLA if reason == Person.Block.SHELTERED else Kind.SHIELD


# The usual colour of an icon kind.
static func colour_for(kind: int) -> Color:
	return Config.MOOD_ICON_COLOURS[clampi(kind, 0, Config.MOOD_ICON_COLOURS.size() - 1)]


# Draws icon `kind` on `ci`: a badge with the glyph inside, `size` pixels wide, centred on `centre`.
static func draw(ci: CanvasItem, kind: int, centre: Vector2, size: float, colour: Color) -> void:
	if kind == Kind.NONE:
		return
	var badge := BADGE_COLOUR
	badge.a *= colour.a
	ci.draw_circle(centre, size * 0.68, badge)
	ci.draw_arc(centre, size * 0.68, 0.0, TAU, 28, colour, maxf(1.5, size * 0.07), true)
	var s := size * 0.5
	match kind:
		Kind.SHIELD:
			_shield(ci, centre, s, colour)
		Kind.FEET:
			_feet(ci, centre, s, colour)
		Kind.CLOUD:
			_cloud(ci, centre, s, colour)
		Kind.UMBRELLA:
			_umbrella(ci, centre, s, colour)
		Kind.BANG:
			_bang(ci, centre, s, colour)


static func _poly(ci: CanvasItem, centre: Vector2, s: float, pts: Array[Vector2], colour: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(centre + p * s)
	ci.draw_colored_polygon(out, colour)


static func _shield(ci: CanvasItem, c: Vector2, s: float, colour: Color) -> void:
	var outer: Array[Vector2] = [
		Vector2(-0.62, -0.62),
		Vector2(0.0, -0.78),
		Vector2(0.62, -0.62),
		Vector2(0.62, 0.0),
		Vector2(0.4, 0.42),
		Vector2(0.0, 0.8),
		Vector2(-0.4, 0.42),
		Vector2(-0.62, 0.0),
	]
	_poly(ci, c, s, outer, colour)
	var inner: Array[Vector2] = []
	for p: Vector2 in outer:
		inner.append(p * 0.55 + Vector2(0.0, -0.05))
	_poly(ci, c, s, inner, colour.lerp(Color(0.12, 0.1, 0.2), 0.55))


# Two feet running, with three speed lines trailing behind them.
static func _feet(ci: CanvasItem, c: Vector2, s: float, colour: Color) -> void:
	for i: int in range(3):
		var y := -0.45 + 0.45 * float(i)
		ci.draw_line(c + Vector2(-0.8, y) * s, c + Vector2(-0.3, y) * s, colour, maxf(1.5, s * 0.14), true)
	_ellipse(ci, c + Vector2(0.28, -0.3) * s, Vector2(0.42, 0.2) * s, colour)
	_ellipse(ci, c + Vector2(0.18, 0.32) * s, Vector2(0.42, 0.2) * s, colour)


static func _ellipse(ci: CanvasItem, at: Vector2, radii: Vector2, colour: Color) -> void:
	var pts := PackedVector2Array()
	for i: int in range(14):
		var a := TAU * float(i) / 14.0
		pts.append(at + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	ci.draw_colored_polygon(pts, colour)


static func _cloud(ci: CanvasItem, c: Vector2, s: float, colour: Color) -> void:
	ci.draw_circle(c + Vector2(-0.36, 0.1) * s, 0.36 * s, colour)
	ci.draw_circle(c + Vector2(0.02, -0.18) * s, 0.46 * s, colour)
	ci.draw_circle(c + Vector2(0.4, 0.12) * s, 0.34 * s, colour)
	ci.draw_rect(Rect2(c + Vector2(-0.4, 0.1) * s, Vector2(0.84, 0.36) * s), colour)


static func _umbrella(ci: CanvasItem, c: Vector2, s: float, colour: Color) -> void:
	var canopy: Array[Vector2] = []
	for i: int in range(13):
		var a := PI + PI * float(i) / 12.0
		canopy.append(Vector2(cos(a) * 0.78, sin(a) * 0.7 - 0.05))
	_poly(ci, c, s, canopy, colour)
	var w := maxf(1.5, s * 0.12)
	ci.draw_line(c + Vector2(0.0, -0.05) * s, c + Vector2(0.0, 0.62) * s, colour, w, true)
	ci.draw_arc(c + Vector2(-0.13, 0.62) * s, 0.13 * s, 0.0, PI, 8, colour, w, true)


static func _bang(ci: CanvasItem, c: Vector2, s: float, colour: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-0.11, -0.62) * s, Vector2(0.22, 0.78) * s), colour)
	ci.draw_circle(c + Vector2(0.0, 0.46) * s, 0.15 * s, colour)
