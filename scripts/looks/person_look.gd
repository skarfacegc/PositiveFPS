class_name PersonLook
extends Node3D

# The look of one Person. The rules (person.gd) own joy, gloom, rescue and the grace period; this node reads them and
# draws. The base class holds what every look shares (the percentage label, the floating joy numbers, the grace ring
# on the ground, the puff of particles). A subclass draws the body: it overrides _build_body, _sync_body, play_bounce,
# play_slump, _set_glow and is_styled.

# Which of the three states the person is drawn in.
enum Kind { GREY, JOYFUL, DARK }

var subject: Person
# The drawn parts of the person, scaled by Config.PERSON_VISUAL_SCALE. The collision and hit radius are not scaled.
var visual: Node3D
var label: Label3D
# The warm ring on the ground shown during the grace period.
var grace_ring: MeshInstance3D
# The state this frame (set by sync).
var kind: int = Kind.GREY
# Joy as a fraction of what the person needs (0 to 1).
var frac: float = 0.0
# True when a rescued person is losing joy and close to relapsing. `wave` is then a -1..1 flicker; `danger` is 0..1.
var warning: bool = false
var danger: float = 0.0
var wave: float = 0.0
# Round 12a (placeholder, shared by both looks): the warning ring that grows at a grabber's feet toward the player, and
# the soft dark haze under a dimmed person (the styled look draws its own, see has_aura).
var grab_ring: MeshInstance3D
var aura: MeshInstance3D
# Round 12b (placeholder in both looks): the mood tells. A glum person shows a warm glint when they look up and a
# skittish person jitters (see _update_mood_cue). Round 13b: the guarded crossed-arms bar is gone; the shield icon over
# the head (FeedbackLayer) says "guarded".
var glint: MeshInstance3D
var _grace_mat: StandardMaterial3D
# +1 leans the body back as the rules say; the styled bodies face the other way and flip it.
var _lean_sign: float = 1.0
var _grab_mat: StandardMaterial3D
# Seeded random numbers for purely cosmetic jitter (floating number positions), so runs repeat.
var _fx_rng := RandomNumberGenerator.new()


# Builds the look for `person`.
func setup(person: Person) -> void:
	subject = person
	visual = Node3D.new()
	visual.scale = Vector3.ONE * Config.PERSON_VISUAL_SCALE
	add_child(visual)
	_build_body()

	# Shows the joy percentage, a warning, or a smiley.
	label = Label3D.new()
	label.position = Vector3(0, Config.PERSON_LABEL_HEIGHT, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 48
	label.pixel_size = 0.005 * subject.ui_scale
	label.no_depth_test = true
	label.text = ""
	add_child(label)

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
	_build_grab_ring()
	_build_aura()
	_build_mood_parts()
	_fx_rng.seed = Config.RNG_SEED


# True for the styled look.
func is_styled() -> bool:
	return false


# Reads the person's state and updates what is drawn. Called by the person every tick and on every change.
func sync() -> void:
	if subject == null or label == null:
		return
	_update_grace_cue()
	_update_grab_cue()
	_update_mood_cue()
	var need := subject.joy_needed()
	frac = clampf(subject.joy / need, 0.0, 1.0)
	warning = false
	danger = 0.0
	wave = 0.0
	if subject.is_rescued:
		kind = Kind.JOYFUL
		var warn_line := need * Config.WARN_FRACTION
		if subject.joy < warn_line:
			# Losing joy: flicker faster the closer they are to relapsing, and show "!".
			var relapse_line := need * Config.RELAPSE_FRACTION
			warning = true
			danger = clampf((warn_line - subject.joy) / (warn_line - relapse_line), 0.0, 1.0)
			wave = sin(Time.get_ticks_msec() / 1000.0 * lerpf(4.0, 14.0, danger))
			label.text = "!"
			label.modulate = Color(1, 0.6, 0.1)
			label.font_size = 72
		else:
			label.text = ":)"
			label.modulate = Color.WHITE
			label.font_size = 48
	else:
		kind = Kind.DARK if subject.level == 2 else Kind.GREY
		label.font_size = 48
		if subject.sad_left > 0.0:
			label.text = ":("
			label.modulate = Color(0.6, 0.6, 0.65)
		else:
			label.text = "" if subject.joy <= 0.0 else str(int(frac * 100)) + "%"
			label.modulate = Color.WHITE
	_sync_body()
	if aura != null:
		aura.visible = kind == Kind.DARK and not has_styled_aura()


# A little bounce: up and down twice (a rescue).
func play_bounce() -> void:
	pass


# Squashes the body vertically and springs it back. `duration` is the total time.
func play_slump(_scale_y: float, _duration: float) -> void:
	pass


# A one-off burst of small coloured particles from the body centre.
func play_puff(color: Color, count: int) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = count
	p.lifetime = 0.6
	p.spread = 180.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 3.0
	p.gravity = Vector3(0, -2, 0)
	p.position = Vector3(0, 0.9 * Config.PERSON_VISUAL_SCALE, 0)
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


# Spawns a floating joy number above the person. Bigger, brighter and bouncier for better matches.
func show_number(value: float, mult: float) -> void:
	var parent := subject.get_parent()
	if parent == null:
		return
	var lbl := Label3D.new()
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.pixel_size = 0.004 * subject.ui_scale
	lbl.fixed_size = false
	var elem_col: Color = Config.ELEMENT_COLORS[subject.affinity]
	var start := subject.global_position + Vector3(_fx_rng.randf_range(-0.4, 0.4), 2.0, _fx_rng.randf_range(-0.4, 0.4))
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


# True when the look draws the dimmed-person aura itself (the styled look), so the placeholder haze stays hidden.
func has_styled_aura() -> bool:
	return false


# True when a dimmed person is showing a smoke or haze aura, in either look.
func has_aura() -> bool:
	return kind == Kind.DARK and (has_styled_aura() or (aura != null and aura.visible))


func _build_aura() -> void:
	aura = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = Config.DIM_AURA_RADIUS
	mesh.bottom_radius = Config.DIM_AURA_RADIUS
	mesh.height = 0.01
	aura.mesh = mesh
	aura.position = Vector3(0, 0.025, 0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Config.DIM_AURA_COLOUR
	aura.material_override = mat
	aura.visible = false
	add_child(aura)


func _build_grab_ring() -> void:
	grab_ring = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.02
	grab_ring.mesh = mesh
	_grab_mat = StandardMaterial3D.new()
	_grab_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_grab_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_grab_mat.albedo_color = Config.GRAB_RING_COLOUR
	grab_ring.material_override = _grab_mat
	grab_ring.visible = false
	add_child(grab_ring)
	# The ring is a loose placeholder in the styled look too (see Looks.note_placeholder).
	if is_styled():
		Looks.note_placeholder(grab_ring, "grab warning ring")


# The grab cue (round 12a): during the wind-up the body leans back and a red ring grows at the feet toward the player;
# in the lunge the body snaps forward. Nothing shows when the person is not grabbing.
func _update_grab_cue() -> void:
	var grabbing := subject.grab_frac > 0.0 or subject.grab_lunging
	grab_ring.visible = grabbing
	var lean := 0.0
	if subject.grab_lunging:
		lean = -Config.GRAB_LEAN
	elif subject.grab_frac > 0.0:
		lean = Config.GRAB_LEAN * subject.grab_frac
	visual.rotation.x = lean * _lean_sign
	if not grabbing:
		return
	var frac := 1.0 if subject.grab_lunging else subject.grab_frac
	var radius := lerpf(0.2, Config.GRAB_HIT_RANGE, frac)
	grab_ring.scale = Vector3(radius, 1.0, radius)
	# The ring is placed in the person's own frame, which is turned to face the player, so "toward" is local forward.
	var local := subject.global_transform.basis.inverse() * subject.grab_toward
	grab_ring.position = Vector3(local.x, 0.05, local.z) * (Config.GRAB_HIT_RANGE * 0.5 * frac)
	var col := Config.GRAB_RING_COLOUR
	col.a = lerpf(0.25, 0.7, frac)
	_grab_mat.albedo_color = col


# Round 12b: the mood tells, drawn over the body in both looks. Skittish: a small
# sideways jitter of the whole body. Glum: hunched forward, and while they look up the body straightens and a warm
# glint shows above the head. Nothing shows for rescued or dimmed people (they have no mood).
func _update_mood_cue() -> void:
	var mood := subject.active_mood()
	glint.visible = mood == Person.Mood.GLUM and subject.glum_up
	if mood == Person.Mood.SKITTISH:
		visual.position.x = sin(subject.mood_phase * 38.0) * Config.SKITTISH_JITTER
	else:
		visual.position.x = 0.0
	if mood == Person.Mood.GLUM:
		visual.rotation.x = 0.0 if subject.glum_up else 0.45 * _lean_sign


func _build_mood_parts() -> void:
	glint = MeshInstance3D.new()
	var spark := SphereMesh.new()
	spark.radius = 0.2
	spark.height = 0.4
	glint.mesh = spark
	glint.position = Vector3(0, 2.7, 0)
	var glint_mat := StandardMaterial3D.new()
	glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glint_mat.albedo_color = Config.GLUM_GLINT_COLOUR
	glint.material_override = glint_mat
	glint.visible = false
	visual.add_child(glint)
	if is_styled():
		Looks.note_placeholder(glint, "glum look-up glint")


# Round 12b: a flat ring that spreads out from the feet and fades (the stage-change ripple). Placeholder in both looks.
func play_ripple(color: Color) -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.9
	mesh.outer_radius = 1.0
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	ring.material_override = mat
	ring.position = Vector3(0, 0.06, 0)
	ring.scale = Vector3.ONE * 0.3
	ring.add_to_group("stage_ripple")
	add_child(ring)
	if is_styled():
		Looks.note_placeholder(ring, "stage ripple")
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3.ONE * Config.STAGE_RIPPLE_RADIUS, Config.STAGE_RIPPLE_SECONDS)
	t.tween_property(mat, "albedo_color:a", 0.0, Config.STAGE_RIPPLE_SECONDS)
	t.chain().tween_callback(ring.queue_free)


# Builds the body under `visual`. Overridden by each look.
func _build_body() -> void:
	pass


# Draws the body for the state in `kind`, `frac`, `warning`, `danger` and `wave`. Overridden by each look.
func _sync_body() -> void:
	pass


# Sets the soft body glow of the grace period (0 = none, 1 = full). Overridden by each look.
func _set_glow(_amount: float) -> void:
	pass


# The grace cue: while the grace period runs, a warm ring on the ground pulses in size and the body glows softly.
# Both fade out over the last GRACE_FADE_SECONDS of the grace period.
func _update_grace_cue() -> void:
	grace_ring.visible = subject.grace_left > 0.0
	if not grace_ring.visible:
		_set_glow(0.0)
		return
	var fade := clampf(subject.grace_left / Config.GRACE_FADE_SECONDS, 0.0, 1.0)
	var pulse := sin(subject.grace_time * TAU * Config.GRACE_RING_PULSE_HZ)
	var size := Config.GRACE_RING_SCALE_MID + Config.GRACE_RING_PULSE_AMPLITUDE * pulse
	grace_ring.scale = Vector3(size, 1.0, size)
	var col := Config.GRACE_RING_COLOR
	_grace_mat.albedo_color = Color(col.r, col.g, col.b, col.a * fade)
	_set_glow(fade)
