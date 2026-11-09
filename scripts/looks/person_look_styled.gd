class_name PersonLookStyled
extends PersonLook

# The styled person (see StylePeople): a stiff grey body, a relaxed joyful body or a hunched dimmed body, whichever the
# rules say. Each body is built the first time it is needed and then only shown or hidden. A rescued person who is
# losing joy flickers between the joyful and the grey body.

const REACT_EMIT := 1.1  # How brightly a reaction lights the body (emit_add).

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
# Graphics checkpoint 5: the reaction, the wobble and a dimmed person's warming all work through the toon
# shader's tint and emit_add instance values (see _apply_body_light), and through two flat rings at the feet.
var _light_meshes: Array = [null, null, null]  # per Kind: Array[MeshInstance3D] (every mesh of the body)
var _light_key: int = -1
var _react_amount: float = 0.0
var _react_colour := Color.WHITE
var _react_ring: MeshInstance3D
var _last_warm: float = -1.0


func is_styled() -> bool:
	return true


# The body that is showing: the one for `kind`, or the grey one while a warning flickers to it. A wobble does
# not flicker: the body stays and greys (see _apply_body_light).
func shown_kind() -> int:
	if warning and wave < 0.0 and not wobbling:
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
	var seconds := clock
	if shown == Kind.GREY:
		_light_pips()
	elif shown == Kind.JOYFUL:
		var rocking := _bounce == null or not _bounce.is_valid() or not _bounce.is_running()
		if rocking:
			# The idle rock fades out as the person walks (the gait bobs them instead).
			var idle := absf(sin(seconds * 3.0 + float(subject.look_seed))) * 0.05
			_holders[Kind.JOYFUL].position.y = idle * (1.0 - gait.move)
		_holders[Kind.JOYFUL].rotation.z = wave * 0.12 if warning else 0.0
		_holders[Kind.JOYFUL].rotation.y = 0.0
		if wobbling:
			# Checkpoint 5: a shake that grows as the wobble runs out (the greying is in _apply_body_light). Round 25:
			# gentler, now that the wobble has a marker on the ground instead of a closing ring.
			var shake := 0.3 + 0.5 * wobble_prog
			_holders[Kind.JOYFUL].rotation.z = wave * PeopleConfig.WOBBLE_SWAY * 0.45 * shake
			_holders[Kind.JOYFUL].rotation.y = sin(seconds * PeopleConfig.WOBBLE_RATE * 1.7) * 0.2 * shake
	else:
		var soot: Node3D = _parts[Kind.DIMMED]["soot"]
		soot.rotation.y = seconds * 0.5
		_warm_dimmed()
	_pose_brace(shown)
	_apply_body_light()


# Checkpoint 7 (round 26 push, styled): a pusher leans into the line and plants their feet, as the placeholder does (see
# PersonLookPlaceholder._pose_brace). The lean goes on the body that is showing; the other bodies stand straight.
func _pose_brace(shown: int) -> void:
	for k: int in range(3):
		if _holders[k] != null and k != shown:
			_holders[k].rotation.x = 0.0
			_holders[k].rotation.z = 0.0
	var holder := _holder(shown)  # Built already: _sync_body builds the body that shows before it poses.
	var lean := brace_lean(subject.brace_dir, subject.brace, visual.global_transform.basis)
	var shake := 0.0
	if subject.brace > 0.5:
		shake = sin(clock * 40.0) * PushConfig.PUSH_BRACE_SHAKE * (subject.brace - 0.5) * 2.0
	# The joyful body sets its own sway (rotation.z) each frame before this runs, so the lean adds to it.
	var base_z := holder.rotation.z if shown == Kind.JOYFUL else 0.0
	holder.rotation.x = lean.x
	holder.rotation.z = base_z + lean.y + shake


# The lean of a pusher's body as (x, z) radians, forward positive: `dir` is the push's flat direction in the world,
# `amount` 0 to 1 (Person.brace), and `frame` the basis the body is drawn in. Static so the tests can check its sign.
static func brace_lean(dir: Vector3, amount: float, frame: Basis) -> Vector2:
	if amount <= 0.01 or dir == Vector3.ZERO:
		return Vector2.ZERO
	var local := frame.inverse() * dir
	var lean := amount * PushConfig.PUSH_BRACE_LEAN
	return Vector2(local.z * lean, -local.x * lean)


# Graphics checkpoint 4: the walk. The pose goes on the body that is showing; a body that was hidden while the person
# walked is put right when it shows again.
func _pose_gait() -> void:
	var shown := shown_kind()
	if _holders[shown] == null:
		return
	StyleWalk.apply(gait, _parts[shown])


# ---- Graphics checkpoint 2: the cues on the ground (see StyleCues). The shared base builds the placeholder shapes; the
# hooks below swap them for the pixel-style ones.


# The grab warning ring: a coral disc with an ink pixel and a bright rim (denser as the wind-up completes).
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


# The guarded wedge: a honey fan with a solid ink edge and a cream rim; denser and whiter while a shot lands.
func _style_guard_wedge() -> void:
	_wedge_style = StyleCues.wedge_material(MoodConfig.GUARDED_WEDGE_RADIUS, MoodConfig.GUARDED_ARC_DEG)
	guard_wedge.material_override = _wedge_style


func _show_wedge(open: bool) -> void:
	StyleCues.set_wedge_open(_wedge_style, open)


# The stage ripple: a thin ring that spreads out from the feet and thins away.
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
		ring,
		"scale",
		Vector3(PeopleConfig.STAGE_RIPPLE_RADIUS, 1.0, PeopleConfig.STAGE_RIPPLE_RADIUS),
		PeopleConfig.STAGE_RIPPLE_SECONDS
	)
	t.tween_method(set_fade, 1.0, 0.0, PeopleConfig.STAGE_RIPPLE_SECONDS)
	t.chain().tween_callback(ring.queue_free)


func _set_glow(amount: float) -> void:
	if is_equal_approx(amount, _last_glow):
		return
	_last_glow = amount
	if _bodies[Kind.JOYFUL] == null:
		return
	var glow: Array[MeshInstance3D] = _parts[Kind.JOYFUL]["glow"]
	for m: MeshInstance3D in glow:
		m.set_instance_shader_parameter("emit_add", maxf(amount * 0.9, _react_amount * REACT_EMIT))
	_light_key = -1  # The next _apply_body_light starts from this.


# The grey person's pip, scarf and object glow a little more as joy builds up.
func _light_pips() -> void:
	if absf(frac - _last_frac) < 0.02:
		return
	_last_frac = frac
	var pips: Array[MeshInstance3D] = _parts[Kind.GREY]["pips"]
	for m: MeshInstance3D in pips:
		m.set_instance_shader_parameter("emit_add", maxf(frac * 1.6, _react_amount * REACT_EMIT))


# ---- Graphics checkpoint 5: the reaction, the wobble and a dimmed person warming ----------------------------


# A reaction's pose: the styled bodies face +z and the visual is turned half a circle to face the game's -z,
# so the turn is added to that.
func _react_pose(hop: float, turn: float) -> void:
	visual.position.y = hop
	visual.rotation.y = PI + turn


# A reaction's glow: the whole body takes the colour (teal for a patch, gold for a lift) and lights up, and a
# flat ring opens at the feet. 0 puts everything back.
func _set_react_glow(colour: Color, amount: float) -> void:
	_react_colour = colour
	_react_amount = amount
	if amount <= 0.0:
		if _react_ring != null:
			_react_ring.visible = false
		return
	if _react_ring == null:
		_react_ring = StyleFight.ring_node(self, 0.7, colour, colour, 0.6)
		_react_ring.position.y = 0.075
	var p := maxf(subject.react_progress(), 0.0)
	var r := lerpf(0.6, 2.4, p)
	_react_ring.visible = true
	_react_ring.scale = Vector3(r, 1.0, r)
	StyleFight.set_ring(_react_ring, colour, 0.7, 0.14, 1.0 - p * p)


# The tint and the glow of the body that is showing, from the reaction, the wobble, the grace glow, a grey
# person's joy and a dimmed person's warmth. Costs a few integer sums when nothing changed.
func _apply_body_light() -> void:
	var k := shown_kind()
	var react_q := roundi(_react_amount * 20.0)
	var glow_q := roundi(_last_glow * 10.0)
	var wobble_q := roundi(wobble_prog * 20.0) + 1 if wobbling else 0
	var warm_q := roundi(frac * 20.0) if k != Kind.JOYFUL else 0
	var which := 1 if _react_colour == SpiritConfig.BURST_FX_COLOUR else 0
	# Round 25: a dimmed person outside the border is tinted toward the ground grey (0 to 5 steps).
	var out_q := roundi(outside_fade * 5.0) if k == Kind.DIMMED else 0
	var key := k + 3 * (react_q + 21 * (glow_q + 11 * (wobble_q + 22 * (warm_q + 21 * (which + 2 * out_q)))))
	if key == _light_key:
		return
	if _light_key == -1 and react_q == 0 and glow_q == 0 and wobble_q == 0 and warm_q == 0 and out_q == 0:
		_light_key = key
		return
	_light_key = key
	if _light_meshes[k] == null:
		var skip: Node = null
		if k == Kind.DIMMED:
			skip = _parts[Kind.DIMMED].get("soot")
		_light_meshes[k] = StyleFight.meshes_under(_bodies[k], skip)
	var meshes: Array = _light_meshes[k]
	var glow_set: Array = _parts[k].get("glow", []) if k == Kind.JOYFUL else _parts[k].get("pips", [])
	# The tint ids are the palette of style_toon.gdshader: 1 patch teal, 2 lift gold, 3 wobble grey, 4 to 6 the coats.
	var tid := 0
	var amount := 0.0
	var emit_base := 0.0
	if k == Kind.DIMMED:
		tid = 4 + clampi(subject.affinity, 0, 2)
		amount = StyleConfig.CP5_WARM_TINT * frac
		emit_base = frac * 0.3
		if out_q > 0:
			# Round 25: the lower contrast outside the border: the coat is greyed toward the ground tone.
			tid = 3
			amount = BorderConfig.EDGE_OUT_FADE * float(out_q) / 5.0
	if wobbling:
		tid = 3
		amount = lerpf(0.45, 1.0, wobble_prog) * 0.9
	if _react_amount > 0.0:
		tid = 2 if which == 1 else 1
		amount = maxf(amount, 0.3 * _react_amount)
	for node: Variant in meshes:
		var m := node as MeshInstance3D
		var base := emit_base
		if glow_set.has(m):
			base = maxf(base, _last_glow * 0.9 if k == Kind.JOYFUL else frac * 1.6)
		StyleFight.tint(m, tid, amount, maxf(base, _react_amount * REACT_EMIT))


# A dimmed person warms as joy builds: the coat takes the affinity colour (see _apply_body_light), the smoke
# pool shrinks and the soot thins.
func _warm_dimmed() -> void:
	if absf(frac - _last_warm) < 0.02:
		return
	_last_warm = frac
	var parts := _parts[Kind.DIMMED]
	var haze: Node3D = parts["haze"]
	var s := lerpf(1.0, 0.45, frac)
	haze.scale = Vector3(s, 1.0, s)
	var soot: Node3D = parts["soot"]
	soot.scale = Vector3.ONE * lerpf(1.0, 0.6, frac)


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
