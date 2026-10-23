class_name Person
extends StaticBody3D

signal rescued
signal relapsed

var affinity: int = 0
var joy: float = 0.0
var is_rescued: bool = false
# Scales the joy label and floating numbers. Top-down mode sets this higher, because the camera is far away.
var ui_scale: float = 1.0
# Hidden darkness value, 0.0 (light) to 1.0 (nearly black). Main.gd changes this each frame.
var gloom: float = 0.0
# The visible grey level (0 light, 1 grey, 2 dark). When it changes, a short moment plays.
var level: int = 0
var body_mat: StandardMaterial3D
var label: Label3D
var body: MeshInstance3D
var wisp: CPUParticles3D
# Seconds after a rescue during which nearby darkness cannot drain this person. 0 (first person) means no grace.
var grace_seconds: float = 0.0
# Seconds of grace left. The grace cue (ring and glow) is shown while this is above zero.
var grace_left: float = 0.0
# The warm ring on the ground shown during the grace period (see _update_grace_cue).
var grace_ring: MeshInstance3D
# Cover (0..1): the average paint weight of the ground around this person. Set by topdown_main.gd.
var cover: float = 0.0
# Protection (0..1) from the cover: 0 at a painted edge, 1 deep inside. Darkness and joy fade scale by it.
var protection: float = 0.0
# True in top-down mode: the partial-joy fade is scaled by protection. First person leaves it off.
var use_cover: bool = false
# Cover and protection labels, built the first time the F3 debug overlay is turned on (see set_debug_visible).
var debug_label: Label3D
var _grace_mat: StandardMaterial3D
# Seconds since the person was made (drives the grace ring's pulse).
var _grace_time: float = 0.0
# Seconds since this person was last hit by a beam.
var _since_hit: float = 99.0
# Seconds left to show the sad face after a relapse.
var _sad_timer: float = 0.0
# Seeded random numbers for purely cosmetic jitter (floating number positions), so runs repeat.
var _fx_rng := RandomNumberGenerator.new()


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

	# Shows the joy percentage, a warning, or a smiley.
	label = Label3D.new()
	label.position = Vector3(0, 2.5, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.005 * ui_scale
	label.no_depth_test = true
	label.text = ""
	add_child(label)

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
	add_child(wisp)

	# The grace ring: a bright warm disc on the ground under the person, hidden unless in grace.
	grace_ring = MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = Config.GRACE_RING_RADIUS
	ring_mesh.bottom_radius = Config.GRACE_RING_RADIUS
	ring_mesh.height = 0.03
	grace_ring.mesh = ring_mesh
	grace_ring.position = Vector3(0, 0.04, 0)
	_grace_mat = StandardMaterial3D.new()
	_grace_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grace_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grace_mat.albedo_color = Config.GRACE_RING_COLOR
	grace_ring.material_override = _grace_mat
	grace_ring.visible = false
	add_child(grace_ring)

	_fx_rng.seed = Config.RNG_SEED
	_update_visuals()


# The joy this person needs to be rescued. Darker levels need more.
func joy_needed() -> float:
	return Config.JOY_MAX * Config.LEVEL_JOY_MULT[Config.gloom_level(gloom)]


# True when a rescued person is losing joy and close to relapsing (they flicker and show "!").
func is_warning() -> bool:
	return is_rescued and joy < joy_needed() * Config.WARN_FRACTION


# Where a joy projectile should land: a little above the feet, at chest height.
func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


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


# Called every frame by topdown_main.gd or main.gd: handles joy fading, level changes and visuals.
func tick(delta: float) -> void:
	_since_hit += delta
	_grace_time += delta
	if _sad_timer > 0.0:
		_sad_timer -= delta
	if grace_left > 0.0:
		grace_left = maxf(0.0, grace_left - delta)
	if not is_rescued:
		if _since_hit > Config.JOY_FADE_DELAY:
			# With cover (top-down), partial joy does not fade deep inside painted ground.
			var exposure := (1.0 - protection) if use_cover else 1.0
			joy = maxf(0.0, joy - Config.JOY_FADE_RATE * delta * exposure)
		if joy >= joy_needed():
			_rescue()
		else:
			_check_level()
	_update_visuals()
	_update_debug_label()


# Removes joy from a rescued person (used by nearby darkness). Relapses them if they drop too low.
func drain_joy(amount: float) -> void:
	if not is_rescued or grace_left > 0.0:
		return
	joy -= amount
	if joy < joy_needed() * Config.RELAPSE_FRACTION:
		_relapse()
	else:
		_update_visuals()


func _rescue() -> void:
	is_rescued = true
	gloom = 0.0
	level = 0
	grace_left = grace_seconds
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
	level = Config.gloom_level(gloom)
	_since_hit = 0.0
	_sad_timer = 1.5
	_update_visuals()
	_puff(Color(0.15, 0.15, 0.18), 30)
	_slump(0.85, 0.3)
	relapsed.emit()


# Fires a moment when the visible grey level changes: darker is a slump and dark puff, lighter is a sparkle.
func _check_level() -> void:
	var new_level := Config.gloom_level(gloom)
	if new_level == level:
		return
	if new_level > level:
		_slump(0.8, 0.35)
		_puff(Color(0.15, 0.15, 0.18), 20)
	else:
		_puff(Color(0.95, 0.95, 0.95), 10)
	level = new_level


# Squashes the body vertically and springs it back. `duration` is the total time.
func _slump(scale_y: float, duration: float) -> void:
	var t := create_tween()
	t.tween_property(body, "scale:y", scale_y, duration / 2.0)
	t.tween_property(body, "scale:y", 1.0, duration / 2.0)


# A one-off burst of small coloured particles from the body centre.
func _puff(color: Color, count: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -2, 0)
	p.position = Vector3(0, 0.9, 0)
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	m.material = mat
	p.mesh = m
	add_child(p)
	p.emitting = true
	var timer := get_tree().create_timer(1.2)
	timer.timeout.connect(p.queue_free)


# Sets the body colour, the label, the wobble and the wisps from the current state.
func _update_visuals() -> void:
	if body_mat == null:
		return
	_update_grace_cue()
	var need := joy_needed()
	var frac := clampf(joy / need, 0.0, 1.0)
	var elem_col: Color = Config.ELEMENT_COLORS[affinity]

	if is_rescued:
		wisp.emitting = false
		var warn_line := need * Config.WARN_FRACTION
		if joy < warn_line:
			# Losing joy: flicker faster the closer they are to relapsing, wobble, and show "!".
			var relapse_line := need * Config.RELAPSE_FRACTION
			var danger := clampf((warn_line - joy) / (warn_line - relapse_line), 0.0, 1.0)
			var speed := lerpf(4.0, 14.0, danger)
			var wave := sin(Time.get_ticks_msec() / 1000.0 * speed)
			var pulse := 0.5 + 0.5 * wave
			body_mat.albedo_color = elem_col.lerp(Config.LEVEL_COLORS[1], pulse)
			body.rotation.y = wave * 0.15
			label.text = "!"
			label.modulate = Color(1, 0.6, 0.1)
			label.font_size = 72
		else:
			body_mat.albedo_color = elem_col.lightened(0.15)
			body.rotation.y = 0.0
			label.text = ":)"
			label.modulate = Color.WHITE
			label.font_size = 48
	else:
		body_mat.albedo_color = Config.LEVEL_COLORS[level].lerp(elem_col, frac * 0.6)
		body.rotation.y = 0.0
		label.font_size = 48
		if _sad_timer > 0.0:
			label.text = ":("
			label.modulate = Color(0.6, 0.6, 0.65)
		else:
			label.text = "" if joy <= 0.0 else str(int(frac * 100)) + "%"
			label.modulate = Color.WHITE
		wisp.emitting = level == 2


# The grace cue: while the grace period runs, a warm ring on the ground pulses in size and the body glows softly.
# Both fade out over the last GRACE_FADE_SECONDS of the grace period.
func _update_grace_cue() -> void:
	grace_ring.visible = grace_left > 0.0
	if not grace_ring.visible:
		body_mat.emission_enabled = false
		return
	var fade := clampf(grace_left / Config.GRACE_FADE_SECONDS, 0.0, 1.0)
	var wave := sin(_grace_time * TAU * Config.GRACE_RING_PULSE_HZ)
	var size := Config.GRACE_RING_SCALE_MID + Config.GRACE_RING_PULSE_AMPLITUDE * wave
	grace_ring.scale = Vector3(size, 1.0, size)
	var col := Config.GRACE_RING_COLOR
	_grace_mat.albedo_color = Color(col.r, col.g, col.b, col.a * fade)
	body_mat.emission_enabled = true
	body_mat.emission = Config.GRACE_GLOW_COLOR
	body_mat.emission_energy_multiplier = Config.GRACE_GLOW_ENERGY * fade


# Shows or hides the cover and protection labels above this person (the F3 debug overlay).
func set_debug_visible(on: bool) -> void:
	if debug_label == null and on:
		debug_label = Label3D.new()
		debug_label.position = Vector3(0, Config.TD_DEBUG_LABEL_HEIGHT, 0)
		debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		debug_label.font_size = 40
		debug_label.pixel_size = 0.005 * ui_scale
		debug_label.no_depth_test = true
		debug_label.outline_size = 10
		add_child(debug_label)
	if debug_label != null:
		debug_label.visible = on
	_update_debug_label()


# Writes the cover and protection percentages into the debug label (only while it is visible).
func _update_debug_label() -> void:
	if debug_label == null or not debug_label.visible:
		return
	debug_label.text = "c %d%%  p %d%%" % [roundi(cover * 100.0), roundi(protection * 100.0)]


# Spawns a floating joy number above the person. Bigger, brighter and bouncier for better matches.
func _spawn_number(value: float, mult: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.004 * ui_scale
	lbl.fixed_size = false
	var elem_col: Color = Config.ELEMENT_COLORS[affinity]
	var start := global_position + Vector3(_fx_rng.randf_range(-0.4, 0.4), 2.0, _fx_rng.randf_range(-0.4, 0.4))
	parent.add_child(lbl)
	lbl.global_position = start
	var base_y := lbl.position.y
	var shown := roundi(value)

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
		t.tween_property(lbl, "scale", Vector3(1.3, 1.3, 1.3), 0.08).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
		t.tween_property(lbl, "scale", Vector3.ONE, 0.1).set_delay(0.08).set_trans(Tween.TRANS_BACK).set_ease(
			Tween.EASE_OUT
		)
		t.tween_property(lbl, "position:y", base_y + 0.6, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "position:y", base_y - 1.6, 0.45).set_delay(0.45).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_OUT
		)
		t.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.6)
		t.tween_callback(lbl.queue_free).set_delay(0.9)
	elif mult >= Config.STRONG_MULT:
		# Strong element: large, full-strength element colour, heavy dark outline.
		lbl.text = "+" + str(shown)
		lbl.font_size = 80
		lbl.modulate = Color(elem_col.r, elem_col.g, elem_col.b, 1.0)
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0, 0, 0, 0.85)
		var t := lbl.create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "position:y", base_y + 0.4, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(lbl, "position:y", base_y - 1.4, 0.4).set_delay(0.4).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_OUT
		)
		t.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.5)
		t.tween_callback(lbl.queue_free).set_delay(0.8)
	else:
		# Weak element: smaller but clearly readable, light grey with a dark outline, droops down with a slight drift.
		lbl.text = "+" + str(shown)
		lbl.font_size = 58
		lbl.modulate = Color(0.88, 0.88, 0.88, 1.0)
		lbl.outline_size = 8
		lbl.outline_modulate = Color(0, 0, 0, 0.7)
		var t := lbl.create_tween()
		t.set_parallel(true)
		t.tween_property(lbl, "position:y", base_y - 1.2, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(lbl, "position:x", lbl.position.x + _fx_rng.randf_range(-0.3, 0.3), 0.7)
		t.tween_property(lbl, "modulate:a", 0.0, 0.3).set_delay(0.4)
		t.tween_callback(lbl.queue_free).set_delay(0.7)
