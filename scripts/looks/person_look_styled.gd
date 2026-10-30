class_name PersonLookStyled
extends PersonLook

# The styled person (see StylePeople): a stiff grey body, a relaxed joyful body or a hunched dimmed body, whichever the
# rules say. Each body is built the first time it is needed and then only shown or hidden. A rescued person who is
# losing joy flickers between the joyful and the grey body.

# The body for each Kind (null until built), the node that lifts and squashes it, and the parts it exposes.
var _bodies: Array[Node3D] = [null, null, null]
var _holders: Array[Node3D] = [null, null, null]
var _parts: Array[Dictionary] = [{}, {}, {}]
var _bounce: Tween
var _last_frac: float = -1.0
var _last_glow: float = 0.0
# Graphics checkpoint 2: the styled cue materials (see StyleCues).
var _wedge_style: ShaderMaterial
var _grab_style: ShaderMaterial


func is_styled() -> bool:
	return true


# The body that is showing: the one for `kind`, or the grey one while a warning flickers to it.
func shown_kind() -> int:
	if warning and wave < 0.0:
		return Kind.GREY
	return kind


func play_bounce() -> void:
	var holder := _holder(Kind.JOYFUL)
	if _bounce != null and _bounce.is_valid():
		_bounce.kill()
	_bounce = create_tween()
	for i: int in range(2):
		_bounce.tween_property(holder, "position:y", 0.6, 0.15)
		_bounce.tween_property(holder, "position:y", 0.0, 0.15)


func play_slump(scale_y: float, duration: float) -> void:
	var holder := _holder(shown_kind())
	var t := create_tween()
	t.tween_property(holder, "scale:y", scale_y, duration / 2.0)
	t.tween_property(holder, "scale:y", 1.0, duration / 2.0)


func _build_body() -> void:
	# The styled bodies face +z; people face -z in the game (so the grab lean is flipped).
	visual.rotation.y = PI
	_lean_sign = -1.0


# The dimmed person's smoke pool and soot are part of the dimmed body (see StylePeople.build_dimmed).
func has_styled_aura() -> bool:
	return shown_kind() == Kind.DIMMED and _parts[Kind.DIMMED].has("haze")


func _sync_body() -> void:
	var shown := shown_kind()
	for k: int in range(3):
		var on := k == shown
		if on:
			_holder(k)
		if _holders[k] != null:
			_holders[k].visible = on
	var seconds := Time.get_ticks_msec() / 1000.0
	if shown == Kind.GREY:
		_light_pips()
	elif shown == Kind.JOYFUL:
		var rocking := _bounce == null or not _bounce.is_valid() or not _bounce.is_running()
		if rocking:
			# The idle rock fades out as the person walks (the gait bobs them instead).
			var idle := absf(sin(seconds * 3.0 + float(subject.look_seed))) * 0.05
			_holders[Kind.JOYFUL].position.y = idle * (1.0 - gait.move)
		_holders[Kind.JOYFUL].rotation.z = wave * 0.12 if warning else 0.0
	else:
		var soot: Node3D = _parts[Kind.DIMMED]["soot"]
		soot.rotation.y = seconds * 0.5


# Graphics checkpoint 4: the walk. The pose goes on the body that is showing; a body that was hidden while the person
# walked is put right when it shows again.
func _pose_gait() -> void:
	var shown := shown_kind()
	if _holders[shown] == null:
		return
	StyleWalk.apply(gait, _parts[shown])


# ---- Graphics checkpoint 2: the cues on the ground (see StyleCues). The shared base builds the placeholder shapes; the
# hooks below swap them for the pixel-style ones.


# The grab warning ring: a coral dithered disc with an ink pixel and a bright rim (denser as the wind-up completes).
func _style_grab_ring() -> void:
	grab_ring.mesh = StyleCues.ring_mesh()
	_grab_style = StyleCues.ring_material(StyleCues.GRAB_FILL, StyleCues.GRAB_RIM, 0.5, 0.0)
	grab_ring.material_override = _grab_style


func _show_grab(_col: Color, frac: float, radius: float) -> void:
	_grab_style.set_shader_parameter("density", lerpf(0.3, 0.9, frac))
	# Keep the rim about the same thickness on the ground while the ring grows.
	_grab_style.set_shader_parameter("rim_width", clampf(StyleCues.GRAB_RIM_METRES / maxf(radius, 0.1), 0.05, 0.45))


# The glum look-up glint: a small gold four-point sparkle (two crossed diamonds) instead of the plain sphere.
func _style_glint() -> void:
	glint.mesh = null
	var gold := StyleKit.mat(StyleKit.hexc("#ffd95a"), 0, 0.0, 1.8)
	StyleKit.sph(glint, 0.16, Vector3.ZERO, gold, Vector3(0.55, 1.7, 0.55), 4, false)
	StyleKit.sph(glint, 0.16, Vector3.ZERO, gold, Vector3(1.7, 0.55, 1.7), 4, false)


# The guarded wedge: a dithered honey fan with a solid ink edge and a cream rim; denser and whiter while a shot lands.
func _style_guard_wedge() -> void:
	_wedge_style = StyleCues.wedge_material(Config.GUARDED_WEDGE_RADIUS, Config.GUARDED_ARC_DEG)
	guard_wedge.material_override = _wedge_style


func _show_wedge(open: bool) -> void:
	StyleCues.set_wedge_open(_wedge_style, open)


# The stage ripple: a thin dithered ring that spreads out from the feet and thins away.
func play_ripple(color: Color) -> void:
	var ring := MeshInstance3D.new()
	ring.mesh = StyleCues.ring_mesh()
	var mat := StyleCues.ring_material(color, color.lightened(0.5), 0.45, 0.78)
	mat.set_shader_parameter("rim_width", 0.06)
	ring.material_override = mat
	ring.position = Vector3(0, 0.06, 0)
	ring.scale = Vector3(0.3, 1.0, 0.3)
	ring.add_to_group("stage_ripple")
	add_child(ring)
	var set_fade := func(v: float) -> void: mat.set_shader_parameter("fade", v)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(
		ring, "scale", Vector3(Config.STAGE_RIPPLE_RADIUS, 1.0, Config.STAGE_RIPPLE_RADIUS), Config.STAGE_RIPPLE_SECONDS
	)
	t.tween_method(set_fade, 1.0, 0.0, Config.STAGE_RIPPLE_SECONDS)
	t.chain().tween_callback(ring.queue_free)


func _set_glow(amount: float) -> void:
	if is_equal_approx(amount, _last_glow):
		return
	_last_glow = amount
	if _bodies[Kind.JOYFUL] == null:
		return
	var glow: Array[MeshInstance3D] = _parts[Kind.JOYFUL]["glow"]
	for m: MeshInstance3D in glow:
		m.set_instance_shader_parameter("emit_add", amount * 0.9)


# The grey person's pip, scarf and object glow a little more as joy builds up.
func _light_pips() -> void:
	if absf(frac - _last_frac) < 0.02:
		return
	_last_frac = frac
	var pips: Array[MeshInstance3D] = _parts[Kind.GREY]["pips"]
	for m: MeshInstance3D in pips:
		m.set_instance_shader_parameter("emit_add", frac * 1.6)


# The node holding the body for `k`, built on first use.
func _holder(k: int) -> Node3D:
	if _holders[k] != null:
		return _holders[k]
	var holder := Node3D.new()
	var rig := Node3D.new()
	var body := Node3D.new()
	holder.add_child(rig)
	rig.add_child(body)
	visual.add_child(holder)
	var parts: Dictionary = {}
	var pose := subject.look_seed % 3
	var outfit := floori(subject.look_seed / 3.0) % 3
	match k:
		Kind.GREY:
			StylePeople.build_grey(body, subject.affinity, pose, parts)
		Kind.JOYFUL:
			StylePeople.build_joy(body, subject.affinity, outfit, parts)
		_:
			StylePeople.build_dimmed(body, parts)
	# The smoke pool is on the ground: it stays out of the rig, which leans and bobs.
	var haze: Node3D = parts.get("haze")
	if haze != null:
		body.remove_child(haze)
		holder.add_child(haze)
	parts["rig"] = rig
	_bodies[k] = body
	_holders[k] = holder
	_parts[k] = parts
	return holder
