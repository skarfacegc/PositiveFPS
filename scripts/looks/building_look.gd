class_name BuildingLook
extends Node3D

# The look of one block the border can beautify. The rules (building.gd) own the inside time, the tint, `beautified`
# and `post`; this node draws the block on its body from that state. A subclass overrides _build, sync, set_post and
# is_styled.

var subject: Building
var body: StaticBody3D
# The block's size in metres (the collision box) and its plain colour.
var size := Vector3.ONE
var base_colour := Color.WHITE


# Builds the block's visuals. This node is a child of `block_body`, which sits at the block's centre.
func setup(building: Building, block_body: StaticBody3D, block_size: Vector3, colour: Color) -> void:
	subject = building
	body = block_body
	size = block_size
	base_colour = colour
	_build()


# True for the styled look.
func is_styled() -> bool:
	return false


# Reads the building's state (tint, beautified) and updates what is drawn.
func sync(_delta: float = 0.0) -> void:
	pass


# Shows or hides the post visuals.
func set_post(_on: bool) -> void:
	pass


func _build() -> void:
	pass
