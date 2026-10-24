class_name Building
extends RefCounted

# One block the border can beautify. It is beautified after BORDER_BUILDING_SECONDS with enough of its footprint inside
# the border (see Border). Its colour fades toward warm over BORDER_TINT_SECONDS. Mechanical blocks keep their grey.

var centre := Vector2.ZERO
var half := Vector2.ONE
var mat: StandardMaterial3D
var base_colour := Color.WHITE
var is_landmark: bool = false
# Seconds this building has had enough of its footprint inside the border in a row.
var inside_time: float = 0.0
# 0 (mechanical grey) to 1 (fully beautified colour).
var tint: float = 0.0
var beautified: bool = false


# `inside_fraction` is the share of the footprint (0..1) inside the border this frame.
func update(delta: float, inside_fraction: float) -> void:
	if inside_fraction >= Config.BORDER_BUILDING_INSIDE:
		inside_time += delta
	else:
		inside_time = 0.0
	beautified = inside_time >= Config.BORDER_BUILDING_SECONDS
	var target := 1.0 if beautified else 0.0
	tint = move_toward(tint, target, delta / Config.BORDER_TINT_SECONDS)
	if mat != null:
		mat.albedo_color = base_colour.lerp(Config.BORDER_BUILDING_COLOUR, tint)
