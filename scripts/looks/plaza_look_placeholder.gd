class_name PlazaLookPlaceholder
extends PlazaLook

# The placeholder plaza: a grey floor slab (top surface at y = 0) and four grey wall boxes.

const FLOOR_COLOUR := Color(0.5, 0.5, 0.5)
const WALL_COLOUR := Color(0.45, 0.45, 0.45)


func _build() -> void:
	var wall_at := side / 2.0 + 0.5
	_box(Vector3(side, 1, side), Vector3(0, -0.5, 0), FLOOR_COLOUR)
	_box(Vector3(side + 2, 3, 1), Vector3(0, 1.5, -wall_at), WALL_COLOUR)
	_box(Vector3(side + 2, 3, 1), Vector3(0, 1.5, wall_at), WALL_COLOUR)
	_box(Vector3(1, 3, side + 2), Vector3(-wall_at, 1.5, 0), WALL_COLOUR)
	_box(Vector3(1, 3, side + 2), Vector3(wall_at, 1.5, 0), WALL_COLOUR)


func _box(size: Vector3, pos: Vector3, colour: Color) -> void:
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mesh_inst.material_override = mat
	mesh_inst.position = pos
	add_child(mesh_inst)
