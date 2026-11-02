class_name PatchFx
extends Node3D

# Round 22 (placeholder look): the world marks for the spirit actions, drawn from GapPatch's state.
#  - Warning rings at the feet of strained border members (amber, growing and reddening with urgency, pulsing faster).
#  - Patches: a teal disc and ring over the sealed stretch; the ring blinks when the patch is about to run out.
#  - Burst: a streak from where each dimmed person stood to where the burst put them, and a warm ring that opens.
# Meshes are pooled and only touched when shown, so a calm border costs nothing per frame.

var _warn: Array[MeshInstance3D] = []
var _patch_discs: Array[MeshInstance3D] = []
var _patch_rings: Array[MeshInstance3D] = []
var _streaks: Array[MeshInstance3D] = []
var _bursts: Array[Dictionary] = []  # {"from", "to", "left"}
var _time: float = 0.0
# Round 23: the result marks. Texts {"pos", "text", "left", "colour"}, halos {"pos", "left"} on lifted people, pulses
# {"pos", "left"} for a new patch.
var _texts: Array[Dictionary] = []
var _text_nodes: Array[Label3D] = []
var _halos: Array[Dictionary] = []
var _halo_nodes: Array[MeshInstance3D] = []
var _pulses: Array[Dictionary] = []
var _pulse_nodes: Array[MeshInstance3D] = []


# Shows the warnings (Array of {"pos", "urgency"}) and patches (Array of {"pos", "left"}); advances the burst marks.
func sync(delta: float, warnings: Array[Dictionary], patches: Array[Dictionary]) -> void:
	_time += delta
	_sync_warnings(warnings)
	_sync_patches(patches)
	_sync_bursts(delta)
	_sync_results(delta)


# A burst happened: remember each clearing so the streaks can fade out.
func add_burst(cleared: Array) -> void:
	for c: Dictionary in cleared:
		_bursts.append({"from": c["from"], "to": c["to"], "left": Config.BURST_FX_SECONDS})


# Round 23: a patch was made at `at`: a pulse opens over the sealed stretch and a small count rises ("Held: 3").
func add_patch_result(at: Vector3, held: int) -> void:
	_pulses.append({"pos": at, "left": Config.FX_PATCH_PULSE_SECONDS})
	(
		_texts
		. append(
			{
				"pos": at,
				"text": Config.FX_PATCH_TEXT % held,
				"left": Config.FX_TEXT_SECONDS,
				"colour": Config.PATCH_COLOUR,
			}
		)
	)


# Round 23: a halo on each person the burst lifted, and one small count where they now stand.
func add_lift_result(cleared: Array) -> void:
	if cleared.is_empty():
		return
	var sum := Vector3.ZERO
	for c: Dictionary in cleared:
		var to: Vector3 = c["to"]
		_halos.append({"pos": to, "left": Config.FX_HALO_SECONDS})
		sum += to
	(
		_texts
		. append(
			{
				"pos": sum / float(cleared.size()),
				"text": Config.FX_LIFT_TEXT % cleared.size(),
				"left": Config.FX_TEXT_SECONDS,
				"colour": Config.BURST_FX_COLOUR,
			}
		)
	)


func result_text_count() -> int:
	return _texts.size()


func halo_count() -> int:
	return _halos.size()


func pulse_count() -> int:
	return _pulses.size()


func warning_ring_count() -> int:
	return _visible_count(_warn)


func patch_disc_count() -> int:
	return _visible_count(_patch_discs)


func streak_count() -> int:
	return _visible_count(_streaks)


func _visible_count(list: Array[MeshInstance3D]) -> int:
	var n := 0
	for m: MeshInstance3D in list:
		if m.visible:
			n += 1
	return n


func _sync_warnings(warnings: Array[Dictionary]) -> void:
	while _warn.size() < warnings.size():
		_warn.append(_make_ring(0.62, 0.8))
	for i: int in range(_warn.size()):
		var ring := _warn[i]
		ring.visible = i < warnings.size()
		if not ring.visible:
			continue
		var u: float = warnings[i]["urgency"]
		var at: Vector3 = warnings[i]["pos"]
		var pulse := 0.5 + 0.5 * sin(_time * (4.0 + 8.0 * u))
		var s := 1.0 + 0.9 * u + 0.25 * pulse * (0.4 + u)
		ring.position = Vector3(at.x, 0.08, at.z)
		ring.scale = Vector3(s, 1.0, s)
		var col := BorderWarning.colour_for(u)
		col.a = 0.55 + 0.4 * u
		_set_colour(ring, col)


func _sync_patches(patches: Array[Dictionary]) -> void:
	while _patch_discs.size() < patches.size():
		_patch_discs.append(_make_disc(Config.PATCH_RADIUS))
		_patch_rings.append(_make_ring(Config.PATCH_RADIUS - 0.18, Config.PATCH_RADIUS))
	for i: int in range(_patch_discs.size()):
		var show := i < patches.size()
		_patch_discs[i].visible = show
		_patch_rings[i].visible = show
		if not show:
			continue
		var at: Vector3 = patches[i]["pos"]
		var left: float = patches[i]["left"]
		_patch_discs[i].position = Vector3(at.x, 0.05, at.z)
		_patch_rings[i].position = Vector3(at.x, 0.1, at.z)
		var blink := 1.0
		if left < 3.0:
			blink = 0.4 + 0.6 * (0.5 + 0.5 * sin(_time * 14.0))
		var col := Config.PATCH_COLOUR
		_set_colour(_patch_discs[i], Color(col.r, col.g, col.b, 0.14 * blink))
		_set_colour(_patch_rings[i], Color(col.r, col.g, col.b, 0.9 * blink))


func _sync_bursts(delta: float) -> void:
	for b: Dictionary in _bursts:
		var was: float = b["left"]
		b["left"] = was - delta
	for i: int in range(_bursts.size() - 1, -1, -1):
		var remaining: float = _bursts[i]["left"]
		if remaining <= 0.0:
			_bursts.remove_at(i)
	while _streaks.size() < _bursts.size():
		_streaks.append(_make_streak())
	for i: int in range(_streaks.size()):
		var m := _streaks[i]
		m.visible = i < _bursts.size()
		if not m.visible:
			continue
		var from: Vector3 = _bursts[i]["from"]
		var to: Vector3 = _bursts[i]["to"]
		var left: float = _bursts[i]["left"]
		var frac := left / Config.BURST_FX_SECONDS
		var mid := (from + to) * 0.5
		var span := Vector2(to.x - from.x, to.z - from.z)
		m.position = Vector3(mid.x, 0.5, mid.z)
		m.rotation = Vector3(0.0, -atan2(span.y, span.x), 0.0)
		m.scale = Vector3(maxf(span.length(), 0.1), 1.0, 1.0)
		var col := Config.BURST_FX_COLOUR
		_set_colour(m, Color(col.r, col.g, col.b, 0.85 * frac))


func _sync_results(delta: float) -> void:
	_age(_texts, delta)
	_age(_halos, delta)
	_age(_pulses, delta)
	while _text_nodes.size() < _texts.size():
		_text_nodes.append(_make_text())
	for i: int in range(_text_nodes.size()):
		var lbl := _text_nodes[i]
		lbl.visible = i < _texts.size()
		if not lbl.visible:
			continue
		var left: float = _texts[i]["left"]
		var frac := left / Config.FX_TEXT_SECONDS
		var at: Vector3 = _texts[i]["pos"]
		var col: Color = _texts[i]["colour"]
		lbl.text = _texts[i]["text"]
		lbl.position = Vector3(at.x, 1.6 + Config.FX_TEXT_RISE * (1.0 - frac), at.z)
		lbl.modulate = Color(col.r, col.g, col.b, minf(1.0, frac * 2.0))
	while _halo_nodes.size() < _halos.size():
		_halo_nodes.append(_make_ring(0.7, 0.85))
	for i: int in range(_halo_nodes.size()):
		var m := _halo_nodes[i]
		m.visible = i < _halos.size()
		if not m.visible:
			continue
		var left2: float = _halos[i]["left"]
		var frac2 := left2 / Config.FX_HALO_SECONDS
		var at2: Vector3 = _halos[i]["pos"]
		var col2 := Config.BURST_FX_COLOUR
		m.position = Vector3(at2.x, 0.12, at2.z)
		_set_colour(m, Color(col2.r, col2.g, col2.b, 0.9 * minf(1.0, frac2 * 1.5)))
	while _pulse_nodes.size() < _pulses.size():
		_pulse_nodes.append(_make_ring(0.9, 1.0))
	for i: int in range(_pulse_nodes.size()):
		var m2 := _pulse_nodes[i]
		m2.visible = i < _pulses.size()
		if not m2.visible:
			continue
		var left3: float = _pulses[i]["left"]
		var frac3 := left3 / Config.FX_PATCH_PULSE_SECONDS
		var at3: Vector3 = _pulses[i]["pos"]
		var sc := Config.PATCH_RADIUS * (1.1 - frac3 * 0.9)
		var col3 := Config.PATCH_COLOUR
		m2.position = Vector3(at3.x, 0.14, at3.z)
		m2.scale = Vector3(sc, 1.0, sc)
		_set_colour(m2, Color(col3.r, col3.g, col3.b, 0.9 * frac3))


# Counts every entry's "left" down and drops the finished ones.
func _age(list: Array[Dictionary], delta: float) -> void:
	for i: int in range(list.size() - 1, -1, -1):
		var left: float = list[i]["left"] - delta
		list[i]["left"] = left
		if left <= 0.0:
			list.remove_at(i)


func _make_text() -> Label3D:
	var l := Label3D.new()
	l.pixel_size = Config.FX_TEXT_SIZE
	l.font_size = 48
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 8
	l.visible = false
	add_child(l)
	Looks.note_placeholder(l, "spirit_fx")
	return l


func _make_ring(inner: float, outer: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	m.mesh = torus
	m.material_override = _material()
	m.visible = false
	add_child(m)
	Looks.note_placeholder(m, "spirit_fx")
	return m


func _make_disc(radius: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.04
	m.mesh = cyl
	m.material_override = _material()
	m.visible = false
	add_child(m)
	Looks.note_placeholder(m, "spirit_fx")
	return m


func _make_streak() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.12, 0.35)
	m.mesh = box
	m.material_override = _material()
	m.visible = false
	add_child(m)
	Looks.note_placeholder(m, "spirit_fx")
	return m


func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _set_colour(m: MeshInstance3D, col: Color) -> void:
	(m.material_override as StandardMaterial3D).albedo_color = col
