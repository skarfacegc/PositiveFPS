class_name BorderLook
extends Node3D

# The look of the living border. The rules (border.gd) own the loop, the members and the gaps; this node reads
# `polygon`, `active`, `segment_is_gap()`, `segment_colour()` and `pulse()` and draws. A subclass overrides _build,
# refresh and is_styled.

var subject: Border


func setup(border: Border) -> void:
	subject = border
	_build()


# True for the styled look.
func is_styled() -> bool:
	return false


# Redraws from the border's current state. Called by the border every update.
func refresh() -> void:
	pass


func _build() -> void:
	pass
