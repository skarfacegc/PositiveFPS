class_name PlazaLookStyled
extends PlazaLook

# The styled plaza: low weathered stone walls round the cobbles. (The cobbles themselves are the GroundLookStyled
# plane; the floor box of the placeholder look is not needed.)


func is_styled() -> bool:
	return true


func _build() -> void:
	var wall_at := side / 2.0 + 0.5
	var stone := StyleKit.mat(StyleKit.hexc("#8d95a1"), 0, 1.0)
	var cap := StyleKit.mat(StyleKit.hexc("#6a727e"), 0, 0.8)
	_wall(Vector3(side + 2, 3, 1), Vector3(0, 1.5, -wall_at), stone, cap)
	_wall(Vector3(side + 2, 3, 1), Vector3(0, 1.5, wall_at), stone, cap)
	_wall(Vector3(1, 3, side + 2), Vector3(-wall_at, 1.5, 0), stone, cap)
	_wall(Vector3(1, 3, side + 2), Vector3(wall_at, 1.5, 0), stone, cap)


func _wall(size: Vector3, pos: Vector3, stone: Material, cap: Material) -> void:
	StyleKit.box(self, size, pos, stone)
	StyleKit.box(self, Vector3(size.x + 0.2, 0.3, size.z + 0.2), pos + Vector3(0.0, size.y * 0.5 + 0.15, 0.0), cap)
