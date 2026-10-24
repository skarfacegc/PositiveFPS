class_name GroundLook
extends Node3D

# The look of the painted ground. The rules (painted_ground.gd) own the paint weights and colours per 1 m tile; this
# node draws them. A subclass overrides _build, refresh and is_styled.

var subject: PaintedGround
# Tiles along each side of the grid.
var grid_size: int = 0


# Builds the ground for a grid of `size` x `size` tiles centred on the origin.
func setup(ground: PaintedGround, size: int) -> void:
	subject = ground
	grid_size = size
	_build()


# True for the styled look.
func is_styled() -> bool:
	return false


# Draws the current paint. `colours` and `weights` hold one entry per tile, index = ix * size + iz, where tile
# (ix, iz) is centred at (-size / 2 + 0.5 + ix, -size / 2 + 0.5 + iz).
func refresh(_colours: Array[Color], _weights: Array[float]) -> void:
	pass


func _build() -> void:
	pass
