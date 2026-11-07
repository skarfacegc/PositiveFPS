class_name TidePointer
extends Control

# Round 25: the gloom tide's edge pointer. A grey ring and arrow at the screen edge, pointing toward the side a tide is
# coming from. GloomTide.refresh_pointer places it inside HudSafeArea (as the wobble pointers) and shows it
# only during the warning. Placeholder look only.

var shown: bool = false
var tip := Vector2.ZERO
var dir := Vector2.UP


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# Shows the pointer with its tip at `at` (window pixels) and its outward direction `direction` (a unit vector).
func show_at(at: Vector2, direction: Vector2) -> void:
	shown = true
	tip = at
	dir = direction
	queue_redraw()


func hide_pointer() -> void:
	if not shown:
		return
	shown = false
	queue_redraw()


func _draw() -> void:
	if not shown:
		return
	var col := Config.TIDE_POINTER_COLOUR
	var centre := tip - dir * (Config.TIDE_POINTER_ARROW + Config.TIDE_POINTER_RING)
	draw_circle(centre, Config.TIDE_POINTER_RING, Color(col.r, col.g, col.b, 0.2))
	draw_arc(centre, Config.TIDE_POINTER_RING, 0.0, TAU, 24, col, 2.0, true)
	var side := Vector2(-dir.y, dir.x)
	var base := tip - dir * Config.TIDE_POINTER_ARROW
	var a := Config.TIDE_POINTER_ARROW * 0.6
	draw_colored_polygon(PackedVector2Array([tip, base + side * a, base - side * a]), col)
