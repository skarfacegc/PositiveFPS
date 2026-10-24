class_name PersonLookPlaceholder
extends PersonLook

# The placeholder person: a capsule whose colour shows how grey they are, a coloured marker above the head for the
# affinity, and dark wisps for dark people.

var body_mat: StandardMaterial3D
var body: MeshInstance3D
var wisp: CPUParticles3D


func _build_body() -> void:
	# The person's body: a capsule whose colour shows how grey they are.
	body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)
	body_mat = StandardMaterial3D.new()
	body.material_override = body_mat
	visual.add_child(body)

	# The coloured marker above the head shows the affinity.
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	marker.mesh = sphere
	marker.position = Vector3(0, 2.15, 0)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Config.ELEMENT_COLORS[subject.affinity]
	marker.material_override = marker_mat
	visual.add_child(marker)

	# Dark wisps drift up from dark people (only while the person is at the dark level).
	wisp = CPUParticles3D.new()
	wisp.position = Vector3(0, 1.0, 0)
	wisp.amount = 12
	wisp.lifetime = 1.5
	wisp.direction = Vector3.UP
	wisp.spread = 25.0
	wisp.initial_velocity_min = 0.5
	wisp.initial_velocity_max = 0.7
	wisp.gravity = Vector3(0, 0.3, 0)
	wisp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wisp.emission_sphere_radius = 0.5
	var wisp_mesh := SphereMesh.new()
	wisp_mesh.radius = 0.08
	wisp_mesh.height = 0.16
	var wisp_mat := StandardMaterial3D.new()
	wisp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wisp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wisp_mat.albedo_color = Color(0.1, 0.1, 0.12, 0.6)
	wisp_mesh.material = wisp_mat
	wisp.mesh = wisp_mesh
	wisp.emitting = false
	visual.add_child(wisp)


func play_bounce() -> void:
	var t := create_tween()
	t.tween_property(body, "position:y", 1.5, 0.15)
	t.tween_property(body, "position:y", 0.9, 0.15)
	t.tween_property(body, "position:y", 1.5, 0.15)
	t.tween_property(body, "position:y", 0.9, 0.15)


func play_slump(scale_y: float, duration: float) -> void:
	var t := create_tween()
	t.tween_property(body, "scale:y", scale_y, duration / 2.0)
	t.tween_property(body, "scale:y", 1.0, duration / 2.0)


func _sync_body() -> void:
	var elem_col: Color = Config.ELEMENT_COLORS[subject.affinity]
	if subject.is_rescued:
		wisp.emitting = false
		if warning:
			# Flicker between the affinity colour and grey, and wobble.
			var pulse := 0.5 + 0.5 * wave
			body_mat.albedo_color = elem_col.lerp(Config.LEVEL_COLORS[1], pulse)
			body.rotation.y = wave * 0.15
		else:
			body_mat.albedo_color = elem_col.lightened(0.15)
			body.rotation.y = 0.0
	else:
		body_mat.albedo_color = Config.LEVEL_COLORS[subject.level].lerp(elem_col, frac * 0.6)
		body.rotation.y = 0.0
		wisp.emitting = subject.level == 2


func _set_glow(amount: float) -> void:
	if amount <= 0.0:
		body_mat.emission_enabled = false
		return
	body_mat.emission_enabled = true
	body_mat.emission = Config.GRACE_GLOW_COLOR
	body_mat.emission_energy_multiplier = Config.GRACE_GLOW_ENERGY * amount
