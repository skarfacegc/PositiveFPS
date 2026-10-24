class_name BuildingLookPlaceholder
extends BuildingLook

# The placeholder block: a plain box whose colour fades toward warm when beautified. A block on the border line (a
# post) gets a warm lantern on top and a golden ring around its base.

var mat: StandardMaterial3D
var _lantern: MeshInstance3D
var _ring: MeshInstance3D


func sync(_delta: float = 0.0) -> void:
	mat.albedo_color = base_colour.lerp(Config.BORDER_BUILDING_COLOUR, subject.tint)


func set_post(on: bool) -> void:
	if _lantern != null:
		_lantern.visible = on
		_ring.visible = on


func _build() -> void:
	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	mat = StandardMaterial3D.new()
	mat.albedo_color = base_colour
	mesh_inst.material_override = mat
	add_child(mesh_inst)
	var top := size.y / 2.0
	_lantern = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	_lantern.mesh = sphere
	_lantern.position = Vector3(0.0, top + 0.6, 0.0)
	_lantern.material_override = _unshaded(Config.BORDER_POST_LANTERN_COLOUR)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Config.BORDER_POST_RING_INNER
	torus.outer_radius = Config.BORDER_POST_RING_OUTER
	_ring.mesh = torus
	# The body sits at the block's centre, so the base is `top` below it.
	_ring.position = Vector3(0.0, -top + 0.06, 0.0)
	_ring.material_override = _unshaded(Config.BORDER_POST_RING_COLOUR)
	add_child(_lantern)
	add_child(_ring)
	set_post(subject.post)


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	return m
