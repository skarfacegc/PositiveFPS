class_name MinimapLookStyled
extends MinimapLook

# The styled minimap (per REVIEW_NOTES): a round parchment-framed map. Grey and warm ground in two shades with a faint
# checker, buildings in rust or slate, a gold border line with coral gaps, cream border people, dimmed people with a
# pale ring, a gold star for the landmark and a bright player dot, every marker outlined in dark brown. It is drawn at
# window resolution (crisp), not in the pixel pass. The picture is the same data model as the placeholder minimap.

const INK := Color("#3a2a20")
const GREY_A := Color("#7f8896")
const GREY_B := Color("#757d8b")
const WARM_A := Color("#ead09a")
const WARM_B := Color("#e0c088")


func is_styled() -> bool:
	return true


# Warm territory shows as soon as a tile has any paint, like the placeholder minimap (which shows the tile's colour,
# grey toward warm). Round 12a fixed a port that waited for half paint, so slowly filling ground looked unclaimed. The
# warm share of the blend is warm_amount(), the same model the placeholder's colour follows.
func ground_colour(ground: PaintedGround, w: Vector2, px: int, py: int) -> Color:
	var weight := 0.0 if ground == null else ground.paint_weight_at(Vector3(w.x, 0.0, w.y))
	var checker := ((px * 7 + py * 13) % 11) < 2
	var grey := GREY_B if checker else GREY_A
	var warm := WARM_B if checker else WARM_A
	return grey.lerp(warm, warm_amount(weight))


# How warm a tile of paint `weight` is drawn (0 grey .. 1 fully warm): any paint shows, and it is fully warm by 0.6.
static func warm_amount(weight: float) -> float:
	if weight <= 0.0:
		return 0.0
	return clampf(0.25 + weight / 0.6 * 0.75, 0.0, 1.0)


func building_colour(warm: bool) -> Color:
	return Color("#b8744d") if warm else Color("#4d5461")


func line_colour(is_gap: bool) -> Color:
	return Color("#e2402f") if is_gap else Color("#ffd24a")


# Round 16: the stretch closed by the map edge is a thicker, deeper honey line (the same honey as the world look's
# sealed
# band), so it reads as a wall the map itself builds, apart from the gold line of people.
func seal_colour() -> Color:
	return Color("#d98a1f")


func seal_width() -> int:
	return 2


# Checkpoint 5: a wobbling person (`wobble_pulse` 0 to 1) is a warm orange-amber blip, outlined in ink like the other
# markers, that pulses.
func member_colour(wobble_pulse: float = -1.0) -> Color:
	if wobble_pulse < 0.0:
		return Color("#fff3c4")
	var col := Color("#ffb45c")
	col.a = lerpf(0.7, 1.0, wobble_pulse)
	return col


func dimmed_colour() -> Color:
	return Color("#16181d")


func landmark_colour() -> Color:
	return Color("#ffd24a")


# Graphics checkpoint 3: a held landmark is a gold star (with its ring); one not yet held is a dimmed grey-violet star.
func landmark_state_colour(held: bool) -> Color:
	return landmark_colour() if held else Color("#9c97ad")


# Graphics checkpoint 4: the people clouds are a dusk violet mist that shows on both the grey and the warm ground.
func cloud_colour() -> Color:
	return Color("#54479a")


# Graphics checkpoint 5: first light. The lit ground behind the front takes a warm gold wash, dithered like the world's
# front (every other pixel stronger), the front itself is a pale line and a dark ink line runs just ahead of it.
func first_light(part: String, col: Color, px: int, py: int) -> Color:
	if part == "ground":
		var strong := (px + py) % 2 == 0
		return col.lerp(Color("#ffd98a"), 0.5 if strong else 0.28)
	if part == "line":
		return Color("#fff6d0")
	return INK


# The spirit beacon: the teal-white of its flame in the world, outlined like the other markers.
func beacon_colour() -> Color:
	return Color("#9cf0dc")


func player_colour() -> Color:
	return Color("#ffe27a")


func view_colour() -> Color:
	return Color(1.0, 1.0, 1.0, 0.6)


func halo_colour(kind: String) -> Color:
	return Color("#c9ced8") if kind == "dimmed" else INK


func draw_back(ctl: Control) -> void:
	ctl.draw_circle(ctl.size * 0.5, ctl.size.x * 0.5, INK)


func draw_frame(ctl: Control) -> void:
	var c := ctl.size * 0.5
	var r := ctl.size.x * 0.5
	var k := ctl.size.x / 144.0
	ctl.draw_arc(c, r - 3.0 * k, 0.0, TAU, 96, Color("#7a5538"), 2.0 * k, true)
	ctl.draw_arc(c, r - 1.5 * k, 0.0, TAU, 96, Color("#f0d9a8"), 3.0 * k, true)
	ctl.draw_arc(c, r - 0.5 * k, 0.0, TAU, 96, INK, 1.5 * k, true)
