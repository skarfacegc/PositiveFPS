class_name PlazaLook
extends Node3D

# The look of the plaza itself: the floor and the four walls round it. (The blocks are BuildingLooks and the painted
# paint is a GroundLook.) The collision for all of them is built by TopDownMain. A subclass overrides _build and
# is_styled.

# Side of the square plaza in metres.
var side: float = 0.0


func setup(plaza_side: float) -> void:
	side = plaza_side
	_build()


# True for the styled look.
func is_styled() -> bool:
	return false


func _build() -> void:
	pass
