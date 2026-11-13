class_name TidePointer
extends Control

# Round 25: the gloom tide's edge pointer. A grey ring and arrow at the screen edge, pointing toward the side a tide is
# coming from. GloomTide.refresh_pointer places it inside HudSafeArea (as the wobble pointers) and shows it
# only during the warning. Both looks draw it (Style update, #94: the styled look draws a pixel storm tag).

var shown: bool = false
var tip := Vector2.ZERO
var dir := Vector2.UP
var pulse_left: float = 0.0  # Seconds the current pulse has to go (see pulse).


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


# Surge warning: swells the pointer for NightConfig.SURGE_PULSE_SECONDS (the warning and the "soon" mark ask for it).
func pulse() -> void:
	pulse_left = NightConfig.SURGE_PULSE_SECONDS
	queue_redraw()


# How big the pulse is now, 0 (none) to 1 (the top of a beat).
func pulse_amount() -> float:
	return pulse_shape(pulse_left)


# The size of a pulse with `left` seconds to go, 0 to 1: SURGE_PULSE_BEATS swells that die away (the pointer and the
# banner share it).
static func pulse_shape(left: float) -> float:
	if left <= 0.0:
		return 0.0
	var t := clampf(1.0 - left / NightConfig.SURGE_PULSE_SECONDS, 0.0, 1.0)
	return absf(sin(t * PI * NightConfig.SURGE_PULSE_BEATS)) * (1.0 - t * 0.5)


func _process(delta: float) -> void:
	if pulse_left <= 0.0:
		return
	pulse_left = maxf(pulse_left - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if not shown:
		return
	var swell := 1.0 + NightConfig.SURGE_PULSE_POINTER * pulse_amount()
	var col := NightConfig.TIDE_POINTER_COLOUR
	var ring := NightConfig.TIDE_POINTER_RING * swell
	var arrow := NightConfig.TIDE_POINTER_ARROW * swell
	var centre := tip - dir * (arrow + ring)
	if Looks.is_styled():  # Walls and gates: Style update (#94): a pixel storm tag and arrow.
		StyleHud.draw_tide_pointer(self, centre, ring, tip, dir, arrow, pulse_amount())
		return
	draw_circle(centre, ring, Color(col.r, col.g, col.b, 0.2 + 0.3 * pulse_amount()))
	draw_arc(centre, ring, 0.0, TAU, 24, col, 2.0, true)
	var side := Vector2(-dir.y, dir.x)
	var base := tip - dir * arrow
	var a := arrow * 0.6
	draw_colored_polygon(PackedVector2Array([tip, base + side * a, base - side * a]), col)
