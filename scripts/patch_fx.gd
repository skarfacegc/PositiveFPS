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


# Shows the warnings (Array of {"pos", "urgency"}) and patches (Array of {"pos", "left"}); advances the burst marks.
func sync(delta: float, warnings: Array[Dictionary], patches: Array[Dictionary]) -> void:
	_time += delta
	_sync_warnings(warnings)
	_sync_patches(patches)
	_sync_bursts(delta)


# A burst happened: remember each clearing so the streaks can fade out.
func add_burst(cleared: Array) -> void:
	for c: Dictionary in cleared:
		_bursts.append({"from": c["from"], "to": c["to"], "left": Config.BURST_FX_SECONDS})


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
