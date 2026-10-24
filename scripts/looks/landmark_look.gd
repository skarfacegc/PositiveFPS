class_name LandmarkLook
extends Node3D

# The look of the landmark: the beacon, the hold ring with its growing disc, and the label. The rules (landmark.gd)
# own the hold time; this node reads progress() and draws. A subclass overrides _build, sync and is_styled.

const RING_INNER := 2.2
const RING_OUTER := 2.6

var subject: Landmark


func setup(landmark: Landmark) -> void:
	subject = landmark
	_build()
	sync()


# True for the styled look.
func is_styled() -> bool:
	return false


# Reads the hold progress and whether the landmark block is beautified.
func sync() -> void:
	pass


func _build() -> void:
	pass
