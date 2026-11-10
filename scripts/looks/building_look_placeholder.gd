class_name BuildingLookPlaceholder
extends BuildingLook

# The placeholder block: a plain box whose colour fades toward warm when beautified.

var mat: StandardMaterial3D


func sync(_delta: float = 0.0) -> void:
	mat.albedo_color = base_colour.lerp(BorderConfig.BORDER_BUILDING_COLOUR, subject.tint)


func _build() -> void:
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mat = StandardMaterial3D.new()
	mat.albedo_color = base_colour
	mesh_inst.material_override = mat
	add_child(mesh_inst)
