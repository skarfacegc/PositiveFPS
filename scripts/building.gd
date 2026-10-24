class_name Building
extends RefCounted

# One block the border can beautify. It is beautified after BORDER_BUILDING_SECONDS with enough of its footprint inside
# the border (see Border). Its tint fades toward warm over BORDER_TINT_SECONDS. Mechanical blocks keep their grey.
# Round 10: a beautified block on the border line is a post (see Border.post_count). How a block looks (its box or
# its styled buildings, the lantern and ring of a post) is its look (scripts/looks/building_look.gd); this script only
# keeps the rules state the look reads: tint, beautified and post.

var centre := Vector2.ZERO
var half := Vector2.ONE
var is_landmark: bool = false
# Seconds this building has had enough of its footprint inside the border in a row.
var inside_time: float = 0.0
# 0 (mechanical grey) to 1 (fully beautified colour).
var tint: float = 0.0
var beautified: bool = false
# True while the border counts this block as a post (see Border._assign_members).
var post: bool = false
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


# Shows or hides the post visuals, and records whether this block is a post.
func set_post(on: bool) -> void:
	post = on
	if look != null:
		look.set_post(on)


# `inside_fraction` is the share of the footprint (0..1) inside the border this frame.
func update(delta: float, inside_fraction: float) -> void:
	if inside_fraction >= Config.BORDER_BUILDING_INSIDE:
		inside_time += delta
	else:
		inside_time = 0.0
	beautified = inside_time >= Config.BORDER_BUILDING_SECONDS
	var target := 1.0 if beautified else 0.0
	tint = move_toward(tint, target, delta / Config.BORDER_TINT_SECONDS)
	if look != null:
		look.sync(delta)


func _make_look() -> void:
	look = Looks.building_look()
	_body.add_child(look)
	look.setup(self, _body, _size, _colour)
