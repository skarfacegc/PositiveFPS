class_name GroundLookPlaceholder
extends GroundLook

# The placeholder ground: a square grid of flat 1 m tiles just above the floor (a MultiMesh), one colour per tile.

var _multimesh: MultiMesh


func refresh(colours: Array[Color], _weights: Array[float]) -> void:
	for i: int in range(colours.size()):
		_multimesh.set_instance_color(i, colours[i])


func _build() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = grid_size * grid_size
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	mm.mesh = plane

	var half := grid_size / 2.0
	var i := 0
	for ix: int in range(grid_size):
		for iz: int in range(grid_size):
			var c := Vector3(-half + 0.5 + ix, 0.01, -half + 0.5 + iz)
			mm.set_instance_transform(i, Transform3D(Basis(), c))
			mm.set_instance_color(i, Config.GROUND_GREY)
			i += 1
	_multimesh = mm

	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	inst.material_override = mat
	add_child(inst)
