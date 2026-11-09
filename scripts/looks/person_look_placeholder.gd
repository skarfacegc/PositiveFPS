class_name PersonLookPlaceholder
extends PersonLook

# The placeholder person: a capsule whose colour shows how grey they are, a coloured marker above the head for the
# affinity, and dimmed wisps for dimmed people.

var body_mat: StandardMaterial3D
var body: MeshInstance3D
var wisp: CPUParticles3D
# Graphics checkpoint 4: the body, marker and wisps hang from this node, which the walk bobs, sways and leans.
var rig: Node3D
var _grace_amount: float = 0.0
var _react_amount: float = 0.0
var _react_colour := Color.WHITE


func _build_body() -> void:
	gait.legs = false
	gait_every = 2
	rig = Node3D.new()
	visual.add_child(rig)
	# The person's body: a capsule whose colour shows how grey they are.
	body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)
	body_mat = StandardMaterial3D.new()
	body.material_override = body_mat
	rig.add_child(body)

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
	rig.add_child(marker)

	# Dimmed wisps drift up from dimmed people (only while the person is at the dimmed level).
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
	rig.add_child(wisp)


# The capsule has no legs: the walk is a bob, a sway over the standing foot and a lean into the way it goes (the capsule
# faces -z, so a forward lean is a negative rotation about x).
func _pose_gait() -> void:
	rig.position = Vector3(gait.sway, gait.bob, 0.0)
	rig.rotation = Vector3(-gait.pitch, gait.yaw, gait.roll)


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
		if wobbling:
			# Round 24: a wide wobble and a body that greys steadily toward the end of the wobble.
			var grey := lerpf(PeopleConfig.WOBBLE_GREY_FROM, 1.0, wobble_prog)
			body_mat.albedo_color = elem_col.lerp(PeopleConfig.LEVEL_COLORS[1], grey)
			body.rotation.y = wave * PeopleConfig.WOBBLE_SWAY
			body.rotation.z = wave * PeopleConfig.WOBBLE_SWAY * 0.5
		elif warning:
			# Flicker between the affinity colour and grey, and wobble.
			var pulse := 0.5 + 0.5 * wave
			body_mat.albedo_color = elem_col.lerp(PeopleConfig.LEVEL_COLORS[1], pulse)
			body.rotation.y = wave * 0.15
			body.rotation.z = 0.0
		else:
			body_mat.albedo_color = elem_col.lightened(0.15)
			body.rotation.y = 0.0
			body.rotation.z = 0.0
	else:
		# Round 24: a dimmed person shows their progress strongly: the body warms to their colour as joy builds.
		var tint := PeopleConfig.DIMMED_PROGRESS_TINT if subject.level >= 2 else 0.6
		body_mat.albedo_color = PeopleConfig.LEVEL_COLORS[subject.level].lerp(elem_col, frac * tint)
		body.rotation.y = 0.0
		body.rotation.z = 0.0
		wisp.emitting = subject.level == 2
		# Round 25: a dimmed person outside the border has lower contrast against the ground.
		body_mat.albedo_color = EdgeDim.faded(body_mat.albedo_color, outside_fade)
	_pose_brace()


# Round 26: a person under push leans into it and plants their feet (the body widens a little); the harder the push, the
# more they struggle (a quick shake past half brace). A border member leans out against the push, a dimmed pusher leans
# into the line. Subject.brace is 0 to 1 and brace_dir the flat direction of the lean (world).
func _pose_brace() -> void:
	var amount := subject.brace
	body.scale.x = 1.0 + PushConfig.PUSH_BRACE_WIDEN * amount
	body.scale.z = body.scale.x
	if amount <= 0.01 or subject.brace_dir == Vector3.ZERO:
		body.rotation.x = 0.0
		return
	var local := subject.global_transform.basis.inverse() * subject.brace_dir
	var lean := amount * PushConfig.PUSH_BRACE_LEAN
	body.rotation.x = local.z * lean
	body.rotation.z += -local.x * lean
	if amount > 0.5:
		body.rotation.z += sin(clock * 40.0) * PushConfig.PUSH_BRACE_SHAKE * (amount - 0.5) * 2.0


func _set_glow(amount: float) -> void:
	_grace_amount = amount
	_apply_glow()


# Round 24: a reaction's glow shares the body's emission with the grace glow; the stronger one shows.
func _set_react_glow(colour: Color, amount: float) -> void:
	_react_colour = colour
	_react_amount = amount
	_apply_glow()


func _apply_glow() -> void:
	var react_energy := PeopleConfig.REACT_GLOW_ENERGY * _react_amount
	var grace_energy := PeopleConfig.GRACE_GLOW_ENERGY * _grace_amount
	if react_energy <= 0.0 and grace_energy <= 0.0:
		body_mat.emission_enabled = false
		return
	body_mat.emission_enabled = true
	if react_energy > grace_energy:
		body_mat.emission = _react_colour
		body_mat.emission_energy_multiplier = react_energy
	else:
		body_mat.emission = PeopleConfig.GRACE_GLOW_COLOR
		body_mat.emission_energy_multiplier = grace_energy
