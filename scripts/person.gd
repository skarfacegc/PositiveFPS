extends StaticBody3D

signal rescued
signal relapsed

var affinity: int = 0
var joy := 0.0
var is_rescued := false
# How grey this person is: 0.0 = light grey, 1.0 = nearly black. Main.gd changes this each frame.
var gloom := 0.0
# Seconds since this person was last hit by a beam.
var _since_hit := 99.0
var body_mat: StandardMaterial3D
var label: Label3D
var body: MeshInstance3D
var disc: MeshInstance3D
var _disc_mat: StandardMaterial3D


func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	# The person's body: a capsule whose colour shows how grey they are.
	body = MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.4
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)
	body_mat = StandardMaterial3D.new()
	body.material_override = body_mat
	add_child(body)

	# The coloured marker above the head shows the affinity.
	var marker := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.18
	sphere.height = 0.36
	marker.mesh = sphere
	marker.position = Vector3(0, 2.15, 0)
	var marker_mat := StandardMaterial3D.new()
	marker_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker_mat.albedo_color = Config.ELEMENT_COLORS[affinity]
	marker.material_override = marker_mat
	add_child(marker)

	# Shows the joy percentage, and a smiley when rescued.
	label = Label3D.new()
	label.position = Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.005
	label.no_depth_test = true
	label.text = ""
	add_child(label)

	# A flat coloured disc on the ground: the colour zone (rescued) or the darkness spread (dark).
	disc = MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = Config.ZONE_RADIUS
	disc_mesh.bottom_radius = Config.ZONE_RADIUS
	disc_mesh.height = 0.02
	disc.mesh = disc_mesh
	disc.position = Vector3(0, 0.02, 0)
	_disc_mat = StandardMaterial3D.new()
	_disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_disc_mat.no_depth_test = false
	_disc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disc.material_override = _disc_mat
	disc.visible = false
	add_child(disc)

	_update_visuals()


# The joy this person needs to be rescued. Darker people need more.
func joy_needed() -> float:
	return Config.JOY_MAX * (1.0 + gloom * Config.GLOOM_JOY_EXTRA)


# Called by the player's beam when it hits this person. Works on rescued people too (top-up).
func receive_joy(element: int, amount: float, distance: float) -> void:
	var mult := Config.multiplier(element, affinity)
	var gain := amount * mult * Config.falloff(distance)
	joy = minf(joy + gain, joy_needed())
	_since_hit = 0.0
	if Config.NUMBERS_ENABLED:
		_spawn_number(gain, mult)
	if is_rescued:
		_update_visuals()
	elif joy >= joy_needed():
		_rescue()
	else:
		_update_visuals()


# Called every frame by main.gd: handles joy fading and refreshes the visuals.
func tick(delta: float) -> void:
	_since_hit += delta
	if not is_rescued:
		if _since_hit > Config.JOY_FADE_DELAY:
			joy = maxf(0.0, joy - Config.JOY_FADE_RATE * delta)
		if joy >= joy_needed():
			_rescue()
	_update_visuals()


# Removes joy from a rescued person (used by nearby darkness). Relapses them if they drop too low.
func drain_joy(amount: float) -> void:
	if not is_rescued:
		return
	joy -= amount
	if joy < joy_needed() * Config.RELAPSE_FRACTION:
		_relapse()
	else:
		_update_visuals()


func _rescue() -> void:
	is_rescued = true
	gloom = 0.0
	joy = minf(joy, Config.JOY_MAX)
	_update_visuals()

	# A little bounce: up and down twice.
	var t := create_tween()
	t.tween_property(body, "position:y", 1.5, 0.15)
	t.tween_property(body, "position:y", 0.9, 0.15)
	t.tween_property(body, "position:y", 1.5, 0.15)
	t.tween_property(body, "position:y", 0.9, 0.15)

	rescued.emit()


func _relapse() -> void:
	is_rescued = false
	gloom = maxf(gloom, 0.6)
	_since_hit = 0.0
	_update_visuals()

	# A small slump so the player notices.
	var t := create_tween()
	t.tween_property(body, "scale:y", 0.85, 0.15)
	t.tween_property(body, "scale:y", 1.0, 0.15)

	relapsed.emit()


# Sets the body colour, the label and the ground disc from the current state.
func _update_visuals() -> void:
	if body_mat == null:
		return
	var need := joy_needed()
	var frac := clampf(joy / need, 0.0, 1.0)
	var elem_col: Color = Config.ELEMENT_COLORS[affinity]

	if is_rescued:
		body_mat.albedo_color = elem_col.lightened(0.15)
		if joy >= need * 0.85:
			label.text = ":)"
		else:
			label.text = ":| " + str(int(frac * 100)) + "%"
		_disc_mat.albedo_color = Color(elem_col.r, elem_col.g, elem_col.b, 0.25)
		disc.visible = true
	else:
		var base := Config.LIGHT_GREY.lerp(Config.DARK_GREY, gloom)
		body_mat.albedo_color = base.lerp(elem_col, frac * 0.6)
		label.text = "" if joy <= 0.0 else str(int(frac * 100)) + "%"
		if gloom > Config.SPREAD_THRESHOLD:
			var strength := (gloom - Config.SPREAD_THRESHOLD) / (1.0 - Config.SPREAD_THRESHOLD)
			_disc_mat.albedo_color = Color(0.1, 0.1, 0.12, 0.35 * strength)
			disc.visible = true
		else:
			disc.visible = false


# Spawns a floating joy number above the person. Bigger, brighter and bouncier for better matches.
func _spawn_number(value: float, mult: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.004
	lbl.fixed_size = false
	var elem_col: Color = Config.ELEMENT_COLORS[affinity]
	var start := global_position + Vector3(randf_range(-0.4, 0.4), 2.0, randf_range(-0.4, 0.4))
	parent.add_child(lbl)
	lbl.global_position = start
	var base_y := lbl.position.y
	var shown := int(round(value))

	if mult >= Config.MATCH_MULT:
		# Matched element: big, bright, gold outline, scale punch, bigger rise.
		lbl.text = "+" + str(shown) + "!"
		lbl.font_size = 110
		lbl.modulate = elem_col.lightened(0.2)
		lbl.outline_size = 18
		lbl.outline_modulate = Color(1, 0.95, 0.6)
		lbl.scale = Vector3(0.4, 0.4, 0.4)
		var t := lbl.create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "scale", Vector3(1.3, 1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "scale", Vector3.ONE, 0.1).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "position:y", base_y + 0.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "position:y", base_y - 1.6, 0.45).set_delay(0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.6)
		t.tween_callback(lbl.queue_free).set_delay(0.9)
	elif mult >= Config.STRONG_MULT:
		# Strong element: medium size, plain element colour, dark outline.
		lbl.text = "+" + str(shown)
		lbl.font_size = 70
		lbl.modulate = Color(elem_col.r, elem_col.g, elem_col.b, 0.95)
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0, 0, 0, 0.6)
		var t := lbl.create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "position:y", base_y + 0.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "position:y", base_y - 1.4, 0.4).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.5)
		t.tween_callback(lbl.queue_free).set_delay(0.8)
	else:
		# Weak element: small, grey, no outline, droops down with a slight sideways drift.
		lbl.text = "+" + str(shown)
		lbl.font_size = 42
		lbl.modulate = Color(0.7, 0.7, 0.7, 0.7)
		lbl.outline_size = 0
		var t := lbl.create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "position:y", base_y - 1.2, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(lbl, "position:x", lbl.position.x + randf_range(-0.3, 0.3), 0.7)
		t.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.4)
		t.tween_callback(lbl.queue_free).set_delay(0.7)
