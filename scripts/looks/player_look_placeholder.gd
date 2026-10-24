class_name PlayerLookPlaceholder
extends PlayerLook

# The placeholder player: a saffron capsule with a small nose to show facing, an element ring under the feet and the
# warm double ring and soft glow that mark the player.

# The body material (round 10: saffron, a colour no person uses). Exposed so tests can check it.
var body_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D


func sync() -> void:
	# Round 12a: a dim player's colour drains toward grey (see TopDownPlayer.dim_level).
	body_mat.albedo_color = Config.TD_PLAYER_COLOUR.lerp(Config.DIM_PLAYER_GREY, subject.dim_level())
	# The ring under the player is the target's element colour, or cream with no target.
	if subject.target == null:
		_ring_mat.albedo_color = Config.TD_NO_TARGET_COLOR
	else:
		_ring_mat.albedo_color = Config.ELEMENT_COLORS[subject.target.affinity]


func _build_body() -> void:
	# Body: a capsule, with a small nose in front so facing is visible.
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Config.TD_PLAYER_COLOUR
	body.material_override = body_mat
	add_child(body)

	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.2, 0.2, 0.2)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 1.2, -0.5)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.4, 0.4, 0.42)
	nose.material_override = nose_mat
	add_child(nose)

	# Element ring under the feet.
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.02
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.03, 0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Config.TD_NO_TARGET_COLOR
	ring.material_override = _ring_mat
	add_child(ring)
	_build_marker()


# Round 10: the warm double ring on the ground and the soft glow under the player.
func _build_marker() -> void:
	for r: float in Config.TD_PLAYER_RING_RADII:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r
		torus.outer_radius = r + Config.TD_PLAYER_RING_WIDTH
		ring.mesh = torus
		ring.position = Vector3(0, 0.035, 0)
		ring.material_override = _warm_material(Config.TD_PLAYER_RING_COLOUR)
		add_child(ring)
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Config.TD_PLAYER_GLOW_RADIUS
	disc.bottom_radius = Config.TD_PLAYER_GLOW_RADIUS
	disc.height = 0.01
	glow.mesh = disc
	glow.position = Vector3(0, 0.02, 0)
	var glow_col := Config.TD_PLAYER_RING_COLOUR
	glow_col.a = Config.TD_PLAYER_GLOW_ALPHA
	glow.material_override = _warm_material(glow_col)
	add_child(glow)


func _warm_material(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	return mat
