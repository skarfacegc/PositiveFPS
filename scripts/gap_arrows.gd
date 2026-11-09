class_name GapArrows
extends Control

# Off-screen gap arrows (round 10). For each gap whose middle is off the screen, a coral arrow badge sits on the
# screen edge pointing at it. It pulses with the gap pulse, and it is kept clear of the minimap circle. Drawn in
# screen space (the HUD).

# The arrows this frame: each entry has "pos" (the badge, in screen pixels) and "angle" (the direction it points,
# radians).
var arrows: Array[Dictionary] = []
var _alpha: float = 1.0
# Round 13b: a clock for the urgency pulse (an urgent gap's arrow pulses faster, brighter and bigger).
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# Works out the arrows for this frame from the gap middles, then redraws. `minimap_rect` is the minimap circle's
# bounding box on screen. `pulse` is the gap pulse (0 to 1), which sets the badges' brightness.
func update_arrows(
	camera: Camera3D,
	screen: Rect2,
	gaps: Array[Vector3],
	minimap_rect: Rect2,
	pulse: float,
	view_scale: Vector2 = Vector2.ONE,
	urgencies: Array[float] = [],
	delta: float = 0.0,
	safe: Rect2 = Rect2()
) -> void:
	_clock += delta
	arrows = off_screen_arrows(camera, screen, gaps, minimap_rect, view_scale, urgencies, safe)
	_alpha = lerpf(0.45, 1.0, pulse)
	queue_redraw()


# The arrows for the gaps that are off the screen. Each badge sits where the line from the screen centre to the gap
# leaves an inset rectangle (OFFSCREEN_ARROW_MARGIN pixels in from the edge). A badge that would land on the minimap
# circle (plus OFFSCREEN_ARROW_PAD) is pushed out radially from the minimap centre, and kept on screen.
# `view_scale` turns the camera's own view coordinates into window coordinates (the styled look draws the 3D view
# small).
static func off_screen_arrows(
	camera: Camera3D,
	screen: Rect2,
	gaps: Array[Vector3],
	minimap_rect: Rect2,
	view_scale: Vector2 = Vector2.ONE,
	urgencies: Array[float] = [],
	safe: Rect2 = Rect2()
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	# Checkpoint 6: with a safe rectangle (HudSafeArea) the badge sits where the ray from the screen centre leaves it,
	# shrunk by CP6_GAP_ARROW_REACH so the whole arrow stays inside; the minimap is already outside it.
	var tips := safe.grow(-HudConfig.CP6_GAP_ARROW_REACH)
	if safe.has_area() and tips.has_area():
		for gi: int in range(gaps.size()):
			var sp := camera.unproject_position(gaps[gi]) * view_scale
			if screen.has_point(sp):
				continue
			var placed := WobbleAlert.tip_for(sp, screen.size, tips)
			var dir: Vector2 = placed["dir"]
			var urgency := urgencies[gi] if gi < urgencies.size() else 0.0
			out.append({"pos": placed["tip"], "angle": dir.angle(), "urgency": urgency})
		return out
	var inner := screen.grow(-HudConfig.OFFSCREEN_ARROW_MARGIN)
	var centre := inner.get_center()
	var half := inner.size * 0.5
	var mm_centre := minimap_rect.get_center()
	var mm_clear := minimap_rect.size.x * 0.5 + HudConfig.OFFSCREEN_ARROW_PAD
	for gi: int in range(gaps.size()):
		var g: Vector3 = gaps[gi]
		var urgency := urgencies[gi] if gi < urgencies.size() else 0.0
		var sp := camera.unproject_position(g) * view_scale
		if screen.has_point(sp):
			continue
		var dir := sp - centre
		var s := INF
		if absf(dir.x) > 0.001:
			s = minf(s, half.x / absf(dir.x))
		if absf(dir.y) > 0.001:
			s = minf(s, half.y / absf(dir.y))
		var edge := centre + dir * s
		var away := edge - mm_centre
		if away.length() < mm_clear:
			# Slide the badge along the edge: down the screen (below the minimap), or else right (past it).
			var down := Vector2(edge.x, maxf(edge.y, mm_centre.y + mm_clear)).clamp(inner.position, inner.end)
			var right := Vector2(maxf(edge.x, mm_centre.x + mm_clear), edge.y).clamp(inner.position, inner.end)
			edge = down if (down - mm_centre).length() >= mm_clear else right
		out.append({"pos": edge, "angle": dir.angle(), "urgency": urgency})
	return out


# The look was swapped (F4): draw again in the new style.
func rebuild_look() -> void:
	queue_redraw()


func _draw() -> void:
	for arrow: Dictionary in arrows:
		var pos: Vector2 = arrow["pos"]
		var angle: float = arrow["angle"]
		var urgency: float = arrow.get("urgency", 0.0)
		var col := arrow_colour(urgency, _clock, _alpha)
		# Graphics checkpoint 2: the styled arrow is a pixel pointer with an ink edge (see StyleHud).
		if Looks.is_styled():
			StyleHud.draw_arrow(self, pos, angle, HudConfig.OFFSCREEN_ARROW_SIZE * (1.0 + 0.6 * urgency), col)
			continue
		var fwd := Vector2(cos(angle), sin(angle))
		var side := Vector2(-fwd.y, fwd.x)
		var k := HudConfig.OFFSCREEN_ARROW_SIZE * (1.0 + 0.6 * urgency)
		var tip := pos + fwd * k
		var a := pos - fwd * k * 0.5 + side * k * 0.6
		var b := pos - fwd * k * 0.5 - side * k * 0.6
		draw_colored_polygon(PackedVector2Array([tip, a, b]), col)


# The colour of an arrow at `urgency` (0 to 1) at clock time `t`: the coral gap colour, pulsing faster and brighter
# (toward a hot white-coral) as the gap stays open. `base_alpha` is the slow gap pulse used at urgency 0.
static func arrow_colour(urgency: float, t: float, base_alpha: float) -> Color:
	var col := BorderConfig.BORDER_GAP_COLOUR.lerp(Color(1.0, 0.82, 0.74), urgency * 0.7)
	if urgency <= 0.0:
		col.a = base_alpha
		return col
	var hz := lerpf(1.0, 3.2, urgency)
	var wave := 0.5 - 0.5 * cos(TAU * t * hz)
	col.a = lerpf(0.45 + 0.4 * urgency, 1.0, wave)
	return col
