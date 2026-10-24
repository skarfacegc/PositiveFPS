class_name GapArrows
extends Control

# Off-screen gap arrows (round 10). For each gap whose middle is off the screen, a coral arrow badge sits on the
# screen edge pointing at it. It pulses with the gap pulse, and it is kept clear of the minimap circle. Drawn in
# screen space (the HUD).

# The arrows this frame: each entry has "pos" (the badge, in screen pixels) and "angle" (the direction it points,
# radians).
var arrows: Array[Dictionary] = []
var _alpha: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# Works out the arrows for this frame from the gap middles, then redraws. `minimap_rect` is the minimap circle's
# bounding box on screen. `pulse` is the gap pulse (0 to 1), which sets the badges' brightness.
func update_arrows(camera: Camera3D, screen: Rect2, gaps: Array[Vector3], minimap_rect: Rect2, pulse: float) -> void:
	arrows = off_screen_arrows(camera, screen, gaps, minimap_rect)
	_alpha = lerpf(0.45, 1.0, pulse)
	queue_redraw()


# The arrows for the gaps that are off the screen. Each badge sits where the line from the screen centre to the gap
# leaves an inset rectangle (OFFSCREEN_ARROW_MARGIN pixels in from the edge). A badge that would land on the minimap
# circle (plus OFFSCREEN_ARROW_PAD) is pushed out radially from the minimap centre, and kept on screen.
static func off_screen_arrows(
	camera: Camera3D, screen: Rect2, gaps: Array[Vector3], minimap_rect: Rect2
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var inner := screen.grow(-Config.OFFSCREEN_ARROW_MARGIN)
	var centre := inner.get_center()
	var half := inner.size * 0.5
	var mm_centre := minimap_rect.get_center()
	var mm_clear := minimap_rect.size.x * 0.5 + Config.OFFSCREEN_ARROW_PAD
	for g: Vector3 in gaps:
		var sp := camera.unproject_position(g)
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
		out.append({"pos": edge, "angle": dir.angle()})
	return out


func _draw() -> void:
	var col := Config.BORDER_GAP_COLOUR
	col.a = _alpha
	for arrow: Dictionary in arrows:
		var pos: Vector2 = arrow["pos"]
		var angle: float = arrow["angle"]
		var fwd := Vector2(cos(angle), sin(angle))
		var side := Vector2(-fwd.y, fwd.x)
		var k := Config.OFFSCREEN_ARROW_SIZE
		var tip := pos + fwd * k
		var a := pos - fwd * k * 0.5 + side * k * 0.6
		var b := pos - fwd * k * 0.5 - side * k * 0.6
		draw_colored_polygon(PackedVector2Array([tip, a, b]), col)
