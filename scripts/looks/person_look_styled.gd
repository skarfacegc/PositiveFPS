class_name PersonLookStyled
extends PersonLook

# The styled person (see StylePeople): a stiff grey body, a relaxed joyful body or a hunched dark body, whichever the
# rules say. Each body is built the first time it is needed and then only shown or hidden. A rescued person who is
# losing joy flickers between the joyful and the grey body.

# The body for each Kind (null until built), the node that lifts and squashes it, and the parts it exposes.
var _bodies: Array[Node3D] = [null, null, null]
var _holders: Array[Node3D] = [null, null, null]
var _parts: Array[Dictionary] = [{}, {}, {}]
var _bounce: Tween
var _last_frac: float = -1.0
var _last_glow: float = 0.0


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
	# The styled bodies face +z; people face -z in the game.
	visual.rotation.y = PI


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
			_holders[Kind.JOYFUL].position.y = absf(sin(seconds * 3.0 + float(subject.look_seed))) * 0.05
		_holders[Kind.JOYFUL].rotation.z = wave * 0.12 if warning else 0.0
	else:
		var soot: Node3D = _parts[Kind.DARK]["soot"]
		soot.rotation.y = seconds * 0.5


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
	var body := Node3D.new()
	holder.add_child(body)
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
			StylePeople.build_dark(body, parts)
	_bodies[k] = body
	_holders[k] = holder
	_parts[k] = parts
	return holder
