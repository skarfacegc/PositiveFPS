class_name BurstFx
extends Node3D

# Round 22: the world marks for the burst (G/Q), drawn from BurstCue's reports (round 26: the F patch is gone).
#  - Burst: a streak from where each dimmed person stood to where the burst put them, a ring on each person lifted.
# Round 25 (edge cleanup): every result mark is short, and a new one replaces an earlier one at the same spot (within
# EDGE_FX_MERGE) instead of stacking on it. Meshes are pooled and only touched when shown.
# Graphics checkpoint 5: the styled look draws the same marks with flat rings (StyleFight). The pools are
# rebuilt when the look changes (sync notices it).

const GOLD_PLANE_Y := 0.12

var _streaks: Array[MeshInstance3D] = []
var _bursts: Array[Dictionary] = []  # {"from", "to", "left"}
# Round 23: the result marks. Texts {"pos", "text", "left", "colour"}, halos {"pos", "left"} on lifted people.
var _texts: Array[Dictionary] = []
var _text_nodes: Array[Label3D] = []
var _halos: Array[Dictionary] = []
var _halo_nodes: Array[MeshInstance3D] = []
# Walls and gates: Style update (#94). The styled mend marks {"pos", "left"} and their pooled nodes (a ring and a seam).
var _mends: Array[Dictionary] = []
var _mend_nodes: Array[Node3D] = []
# Which look the pools were built for.
var _built_styled: bool = false
var _streak_mat: ShaderMaterial


# Advances the burst and result marks.
func sync(delta: float) -> void:
	if Looks.is_styled() != _built_styled:
		_rebuild_pools()
	_sync_bursts(delta)
	_sync_results(delta)
	_sync_mends(delta)


# True when the pools hold the styled pieces.
func is_styled_built() -> bool:
	return _built_styled


# A burst happened: remember each clearing so the streaks can fade out. Streaks of an earlier burst that ended where
# these do are replaced.
func add_burst(cleared: Array) -> void:
	var spots: Array[Vector3] = []
	for c: Dictionary in cleared:
		var to: Vector3 = c["to"]
		spots.append(to)
	_replace_near(_bursts, spots, "to")
	for c: Dictionary in cleared:
		_bursts.append({"from": c["from"], "to": c["to"], "left": SpiritConfig.BURST_FX_SECONDS})


# Round 23: a halo on each person the burst lifted, and one small count where they now stand. Round 25: earlier halos
# and counts where these stand are replaced.
func add_lift_result(cleared: Array) -> void:
	if cleared.is_empty():
		return
	var spots: Array[Vector3] = []
	var sum := Vector3.ZERO
	for c: Dictionary in cleared:
		var to: Vector3 = c["to"]
		spots.append(to)
		sum += to
	var middle := sum / float(cleared.size())
	spots.append(middle)
	_replace_near(_halos, spots, "pos")
	_replace_near(_texts, [middle], "pos")
	for c: Dictionary in cleared:
		_halos.append({"pos": c["to"], "left": SpiritConfig.FX_HALO_SECONDS})
	(
		_texts
		. append(
			{
				"pos": middle,
				"text": SpiritConfig.FX_LIFT_TEXT % cleared.size(),
				"left": SpiritConfig.FX_TEXT_SECONDS,
				"colour": SpiritConfig.BURST_FX_COLOUR,
			}
		)
	)


# Walls and gates: Style update (#94). A break mended (Border.line_mended; a burst mends every break in reach,
# Loop tuning #93): the styled look shows a gold ring closing on the spot and a seam of light running up it, like a
# stitch. The placeholder look draws nothing new. A new mark at the same spot replaces the old one.
func add_mend(pos: Vector3, _seconds: float = 0.0) -> void:
	if not Looks.is_styled():
		return
	_replace_near(_mends, [pos], "pos")
	_mends.append({"pos": pos, "left": StyleConfig.SU_MEND_SECONDS})


func mend_count() -> int:
	return _mends.size()


func result_text_count() -> int:
	return _texts.size()


func halo_count() -> int:
	return _halos.size()


func streak_count() -> int:
	return _visible_count(_streaks)


# Drops every entry of `list` whose `key` position is within EDGE_FX_MERGE of any of `spots` (ground distance).
func _replace_near(list: Array[Dictionary], spots: Array, key: String) -> void:
	for i: int in range(list.size() - 1, -1, -1):
		var at: Vector3 = list[i][key]
		for spot: Vector3 in spots:
			if Vector2(at.x - spot.x, at.z - spot.z).length() <= BorderConfig.EDGE_FX_MERGE:
				list.remove_at(i)
				break


func _visible_count(list: Array[MeshInstance3D]) -> int:
	var n := 0
	for m: MeshInstance3D in list:
		if m.visible:
			n += 1
	return n


# The look changed: free every pooled piece (the data lists stay) and build the next ones in the new look.
func _rebuild_pools() -> void:
	_built_styled = Looks.is_styled()
	for list: Array in [_streaks, _text_nodes, _halo_nodes, _mend_nodes]:
		for n: Node in list:
			n.queue_free()
		list.clear()
	_streak_mat = null


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
		var frac := left / SpiritConfig.BURST_FX_SECONDS
		var mid := (from + to) * 0.5
		var span := Vector2(to.x - from.x, to.z - from.z)
		m.position = Vector3(mid.x, 0.5, mid.z)
		m.rotation = Vector3(0.0, -atan2(span.y, span.x), 0.0)
		if _built_styled:
			# No alpha in the pixel style: the streak thins as it fades.
			m.scale = Vector3(maxf(span.length(), 0.1), 1.0, maxf(0.08, frac))
			continue
		m.scale = Vector3(maxf(span.length(), 0.1), 1.0, 1.0)
		var col := SpiritConfig.BURST_FX_COLOUR
		_set_colour(m, Color(col.r, col.g, col.b, 0.85 * frac))


func _sync_results(delta: float) -> void:
	_age(_texts, delta)
	_age(_halos, delta)
	while _text_nodes.size() < _texts.size():
		_text_nodes.append(_make_text())
	for i: int in range(_text_nodes.size()):
		var lbl := _text_nodes[i]
		lbl.visible = i < _texts.size()
		if not lbl.visible:
			continue
		var left: float = _texts[i]["left"]
		var frac := left / SpiritConfig.FX_TEXT_SECONDS
		var at: Vector3 = _texts[i]["pos"]
		var col: Color = _texts[i]["colour"]
		lbl.text = _texts[i]["text"]
		lbl.position = Vector3(at.x, 1.6 + SpiritConfig.FX_TEXT_RISE * (1.0 - frac), at.z)
		lbl.modulate = Color(col.r, col.g, col.b, minf(1.0, frac * 2.0))
	_sync_halos()


# The mend marks (styled look only): a gold ring that closes on the spot and a seam of light that rises and thins.
func _sync_mends(delta: float) -> void:
	_age(_mends, delta)
	if not _built_styled:
		for n: Node3D in _mend_nodes:
			n.visible = false
		return
	while _mend_nodes.size() < _mends.size():
		_mend_nodes.append(_make_mend())
	for i: int in range(_mend_nodes.size()):
		var node := _mend_nodes[i]
		node.visible = i < _mends.size()
		if not node.visible:
			continue
		var left: float = _mends[i]["left"]
		var frac := clampf(left / StyleConfig.SU_MEND_SECONDS, 0.0, 1.0)
		var at: Vector3 = _mends[i]["pos"]
		node.position = Vector3(at.x, 0.0, at.z)
		var ring := node.get_child(0) as MeshInstance3D
		var r := lerpf(1.2, StyleConfig.SU_MEND_RADIUS, frac)
		ring.position.y = GOLD_PLANE_Y
		ring.scale = Vector3(r, 1.0, r)
		StyleFight.set_ring(ring, StyleFight.GOLD, 0.9, 0.14, minf(1.0, frac * 2.0))
		var seam := node.get_child(1) as MeshInstance3D
		seam.scale = Vector3(maxf(0.15, frac), StyleConfig.SU_MEND_SEAM * (1.2 - frac), maxf(0.15, frac))
		seam.position.y = seam.scale.y * 0.5


func _make_mend() -> Node3D:
	var root := Node3D.new()
	root.visible = false
	add_child(root)
	StyleFight.ring_node(root, 0.7, StyleFight.GOLD, StyleFight.GOLD_RIM, 0.9).visible = true
	var seam := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.0, 0.4)
	seam.mesh = box
	seam.material_override = StyleKit.mat(StyleFight.GOLD_RIM, 0, 0.0, 1.8)
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(seam)
	return root


# The halo on each person a burst lifted: a flat ring that opens and fades (round 25: no column of light any more).
func _sync_halos() -> void:
	while _halo_nodes.size() < _halos.size():
		if _built_styled:
			_halo_nodes.append(_styled_ring(0.6, GOLD_PLANE_Y))
		else:
			_halo_nodes.append(_make_ring(0.7, 0.85))
	for i: int in range(_halo_nodes.size()):
		var m := _halo_nodes[i]
		m.visible = i < _halos.size()
		if not m.visible:
			continue
		var left2: float = _halos[i]["left"]
		var frac2 := left2 / SpiritConfig.FX_HALO_SECONDS
		var at2: Vector3 = _halos[i]["pos"]
		var col2 := SpiritConfig.BURST_FX_COLOUR
		m.position = Vector3(at2.x, GOLD_PLANE_Y, at2.z)
		if _built_styled:
			var grow := 1.0 + 0.6 * (1.0 - frac2)
			m.scale = Vector3(1.1 * grow, 1.0, 1.1 * grow)
			StyleFight.set_ring(m, StyleFight.GOLD, 0.85, 0.12, minf(1.0, frac2 * 1.5))
			continue
		_set_colour(m, Color(col2.r, col2.g, col2.b, 0.9 * minf(1.0, frac2 * 1.5)))


# Counts every entry's "left" down and drops the finished ones.
func _age(list: Array[Dictionary], delta: float) -> void:
	for i: int in range(list.size() - 1, -1, -1):
		var left: float = list[i]["left"] - delta
		list[i]["left"] = left
		if left <= 0.0:
			list.remove_at(i)


func _make_text() -> Label3D:
	var l := Label3D.new()
	l.pixel_size = SpiritConfig.FX_TEXT_SIZE
	l.font_size = 48
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.outline_size = 8
	l.visible = false
	add_child(l)
	if _built_styled:
		# Chunky: a bigger glyph with a thick ink edge reads in the 640x360 pass.
		l.font_size = 64
		l.pixel_size = SpiritConfig.FX_TEXT_SIZE * 1.15
		l.outline_size = 16
		l.outline_modulate = StyleFight.INK
	else:
		Looks.note_placeholder(l, "spirit_fx")
	return l


# A placeholder ring (a torus). The styled look builds its flat rings with _styled_ring.
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


func _styled_ring(inner_frac: float, y: float) -> MeshInstance3D:
	var m := StyleFight.ring_node(self, inner_frac, StyleFight.WARD, StyleFight.WARD_RIM, 0.5)
	m.position.y = y
	return m


func _make_streak() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.0, 0.12, 0.35)
	m.mesh = box
	m.visible = false
	add_child(m)
	if _built_styled:
		if _streak_mat == null:
			_streak_mat = StyleKit.mat(StyleFight.GOLD, 0, 0.0, 1.7)
		m.material_override = _streak_mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return m
	m.material_override = _material()
	Looks.note_placeholder(m, "spirit_fx")
	return m


func _material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


func _set_colour(m: MeshInstance3D, col: Color) -> void:
	(m.material_override as StandardMaterial3D).albedo_color = col
