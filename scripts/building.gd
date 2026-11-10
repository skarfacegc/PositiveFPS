class_name Building
extends RefCounted

# One block the border can beautify. It is beautified after BORDER_BUILDING_SECONDS with enough of its footprint inside
# the border (see Border). Its tint fades toward warm over BORDER_TINT_SECONDS. Mechanical blocks keep their grey.
# How a block looks (its box or its styled buildings) is its look (scripts/looks/building_look.gd); this script only
# keeps the rules state the look reads: tint and beautified. (0.4 removed the posts.)

var centre := Vector2.ZERO
var half := Vector2.ONE
var is_landmark: bool = false
# Seconds this building has had enough of its footprint inside the border in a row.
var inside_time: float = 0.0
# 0 (mechanical grey) to 1 (fully beautified colour).
var tint: float = 0.0
var beautified: bool = false
var look: BuildingLook
var _body: StaticBody3D
var _size := Vector3.ONE
var _colour := Color.WHITE


# Adds the block's look to its body. `size` is the block's collision box and `colour` its plain colour.
func attach(body: StaticBody3D, size: Vector3, colour: Color) -> void:
	_body = body
	_size = size
	_colour = colour
	_make_look()


# Swaps the look in place (F4).
func rebuild_look() -> void:
	if look != null:
		_body.remove_child(look)
		look.queue_free()
	_make_look()


# `inside_fraction` is the share of the footprint (0..1) inside the border this frame.
func update(delta: float, inside_fraction: float) -> void:
	if inside_fraction >= BorderConfig.BORDER_BUILDING_INSIDE:
		inside_time += delta
	else:
		inside_time = 0.0
	beautified = inside_time >= BorderConfig.BORDER_BUILDING_SECONDS
	var target := 1.0 if beautified else 0.0
	tint = move_toward(tint, target, delta / BorderConfig.BORDER_TINT_SECONDS)
	if look != null:
		look.sync(delta)


func _make_look() -> void:
	look = Looks.building_look()
	_body.add_child(look)
	look.setup(self, _body, _size, _colour)
