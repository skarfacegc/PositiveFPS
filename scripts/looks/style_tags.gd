class_name StyleTags
extends RefCounted

# Walls and gates: Style update (#94). The world labels of the town (the gate counts, the tags on the cells next to
# the zone, the defence label and the floating joy numbers) in the styled look: warm palette colours, a chunky ink
# edge and a slightly bigger glyph, so they read in the 640x360 pass. The fallback font stays (a pixel font is #26).
# Visual only: `apply` flips a label back to its placeholder colours and edge when the look is the placeholder one.

enum Role { PLAIN, GATE_OK, GATE_SHORT, FREE, PAID, IDLE }

const INK := Color("#3a2a20")
const CREAM := Color("#fff3c4")
const GOLD := Color("#ffd24a")
const BLUE := Color("#9cc4f4")
const CORAL := Color("#ff8a72")
const GREY := Color("#d9d3e6")


# The styled colour of a role (a plain role keeps `plain`, warmed a little toward cream).
static func colour_of(role: int, plain: Color = Color.WHITE) -> Color:
	match role:
		Role.GATE_OK:
			return CREAM
		Role.GATE_SHORT:
			return CORAL
		Role.FREE:
			return GOLD
		Role.PAID:
			return BLUE
		Role.IDLE:
			return GREY
	return Color(plain.r, plain.g, plain.b, plain.a).lerp(CREAM, 0.25)


# Dresses `label` for the look on show. `plain` is the colour the placeholder look gives it. The label's placeholder
# edge size and font size are remembered the first time it is dressed and put back in the placeholder look.
static func apply(label: Label3D, role: int, plain: Color) -> void:
	if not label.has_meta("plain_outline"):
		label.set_meta("plain_outline", label.outline_size)
		label.set_meta("plain_font", label.font_size)
		label.set_meta("plain_edge", label.outline_modulate)
	var edge: int = label.get_meta("plain_outline")
	var font: int = label.get_meta("plain_font")
	if Looks.is_styled():
		var col := colour_of(role, plain)
		col.a = plain.a
		label.modulate = col
		label.outline_size = StyleConfig.SU_TAG_OUTLINE
		label.outline_modulate = INK
		label.font_size = roundi(float(font) * StyleConfig.SU_TAG_SCALE)
		return
	label.modulate = plain
	label.outline_size = edge
	label.outline_modulate = label.get_meta("plain_edge")
	label.font_size = font


# The floating joy number in the styled look: the element colour lifted toward cream, a thick ink edge (a matched hit
# keeps its gold edge as a warm rim). `mult` is the joy multiplier it was given.
static func joy_number(label: Label3D, mult: float) -> void:
	var col := label.modulate
	label.modulate = Color(col.r, col.g, col.b, col.a).lerp(CREAM, 0.2)
	label.outline_modulate = INK if mult < Config.MATCH_MULT else Color("#7a5538")
	label.outline_size = maxi(label.outline_size, StyleConfig.SU_TAG_OUTLINE - 2)
