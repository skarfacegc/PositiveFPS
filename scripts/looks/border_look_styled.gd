class_name BorderLookStyled
extends BorderLook

# The styled border: never a hard line. A faint amber haze band (dithered, see shaders/style_haze.gdshader) and golden
# motes float between the members. In a gap the haze thins and turns coral, with coral motes and a soft coral glow on
# the ground; all of those swell and glow with the gap pulse (the game's own pulse value, 1.2 s, eased). The geometry
# is rebuilt about ten times a second; the pulse is applied every frame.

const HAZE_SHADER := "res://shaders/style_haze.gdshader"
const REBUILD_MS := 100
const HAZE_HALF_WIDTH := 0.9
const HAZE_HEIGHT := 0.045
const MOTE_STEP := 0.42
const GAP_MOTE_STEP := 0.6
const MAX_MOTES := 600
const AMBER := Color("#e8963a")
const CORAL := Color("#ff6a58")

var _haze: MeshInstance3D
var _haze_mat: ShaderMaterial
var _gold_motes: MultiMeshInstance3D
var _gap_motes: MultiMeshInstance3D
var _gap_mote_mat: ShaderMaterial
var _gap_glow_mat: ShaderMaterial
var _glows: Array[MeshInstance3D] = []
var _gap_points: PackedVector3Array = PackedVector3Array()
var _last_ms: int = -100000


func is_styled() -> bool:
	return true


func refresh() -> void:
	var pulse := subject.pulse()
	_haze_mat.set_shader_parameter("gap_pulse", pulse)
	_gap_mote_mat.set_shader_parameter("emit", 1.0 + 3.2 * pulse)
	_gap_glow_mat.set_shader_parameter("strength", 0.12 + 0.6 * pulse)
	var poly := subject.polygon
	var live := subject.active and poly.size() >= 3
	_haze.visible = live
	_gold_motes.visible = live
	_gap_motes.visible = live
	if not live:
		for g: MeshInstance3D in _glows:
			g.visible = false
		return
	var now := Time.get_ticks_msec()
	if now - _last_ms >= REBUILD_MS:
		_last_ms = now
		_rebuild()
	_swell(pulse)


func _build() -> void:
	_haze_mat = ShaderMaterial.new()
	_haze_mat.shader = load(HAZE_SHADER)
	_haze = MeshInstance3D.new()
	_haze.material_override = _haze_mat
	_haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_haze)
	_gap_mote_mat = StyleKit.unique_mat(StyleKit.hexc("#ff7a66"), 1.2)
	_gap_glow_mat = StyleKit.glow_mat(Color(1.0, 0.42, 0.34), 0.12)
	_gold_motes = _make_motes(StyleKit.mat(StyleKit.hexc("#ffe28a"), 0, 0.0, 1.2))
	_gap_motes = _make_motes(_gap_mote_mat)


func _make_motes(m: Material) -> MultiMeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.055
	mesh.height = 0.11
	mesh.radial_segments = 4
	mesh.rings = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = MAX_MOTES
	mm.visible_instance_count = 0
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.material_override = m
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
	return inst


# Rebuilds the haze band, the motes and the ground glows from the loop and its gaps.
func _rebuild() -> void:
	var poly := subject.polygon
	var n := poly.size()
	# Per point: how much of a gap it is in (0 intact .. 1 gap), from the two segments that meet there.
	var gap_w := PackedFloat32Array()
	gap_w.resize(n)
	for j: int in range(n):
		var before := 1.0 if subject.segment_is_gap((j - 1 + n) % n) else 0.0
		var after := 1.0 if subject.segment_is_gap(j) else 0.0
		gap_w[j] = maxf(before, after)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var dists := PackedFloat32Array()
	for j: int in range(n):
		var tangent := (poly[(j + 1) % n] - poly[(j - 1 + n) % n]).normalized()
		var nrm := Vector2(-tangent.y, tangent.x) * HAZE_HALF_WIDTH
		left.append(Vector3(poly[j].x - nrm.x, HAZE_HEIGHT, poly[j].y - nrm.y))
		right.append(Vector3(poly[j].x + nrm.x, HAZE_HEIGHT, poly[j].y + nrm.y))
		dists.append(dist)
		dist += poly[j].distance_to(poly[(j + 1) % n])
	for j: int in range(n):
		var k := (j + 1) % n
		var dk := dist if k == 0 else dists[k]
		var tris: Array[Array] = [
			[j, -1.0, dists[j]], [j, 1.0, dists[j]], [k, -1.0, dk], [k, -1.0, dk], [j, 1.0, dists[j]], [k, 1.0, dk]
		]
		for v: Array in tris:
			var idx: int = v[0]
			var side: float = v[1]
			var d: float = v[2]
			var w := gap_w[idx]
			var tint := AMBER.lerp(CORAL, w)
			st.set_normal(Vector3.UP)
			st.set_color(Color(tint.r, tint.g, tint.b, lerpf(1.0, 0.4, w)))
			st.set_uv(Vector2(side, d))
			st.set_uv2(Vector2(w, 0.0))
			st.add_vertex(left[idx] if side < 0.0 else right[idx])
	_haze.mesh = st.commit()
	_rebuild_motes(poly, gap_w, dist)
	_rebuild_glows()


# Golden motes along the loop (denser), and coral motes over the gaps. Positions come from a hash of the mote number, so
# they stay put between rebuilds.
func _rebuild_motes(poly: PackedVector2Array, gap_w: PackedFloat32Array, total: float) -> void:
	var gold := _gold_motes.multimesh
	var coral := _gap_motes.multimesh
	var n_gold := 0
	var n_gap := 0
	_gap_points = PackedVector3Array()
	var cum := 0.0
	var seg_i := 0
	var s := 0.0
	var k := 0
	var n := poly.size()
	while s < total and n_gold < MAX_MOTES and n_gap < MAX_MOTES:
		while seg_i < n - 1 and cum + poly[seg_i].distance_to(poly[(seg_i + 1) % n]) < s:
			cum += poly[seg_i].distance_to(poly[(seg_i + 1) % n])
			seg_i += 1
		var a := poly[seg_i]
		var b := poly[(seg_i + 1) % n]
		var f := clampf((s - cum) / maxf(a.distance_to(b), 0.0001), 0.0, 1.0)
		var w := lerpf(gap_w[seg_i], gap_w[(seg_i + 1) % n], f)
		var at := a.lerp(b, f)
		var tangent := (b - a).normalized()
		var nrm := Vector2(-tangent.y, tangent.x)
		var h1 := _hash(k)
		var h2 := _hash(k + 7919)
		var pos2 := at + nrm * (h1 - 0.5) * 1.4
		var pos := Vector3(pos2.x, 0.25 + h2 * 1.25, pos2.y)
		if w > 0.55:
			if _hash(k + 31) < 0.75:
				_gap_points.append(pos)
				n_gap += 1
			s += GAP_MOTE_STEP
		else:
			gold.set_instance_transform(n_gold, Transform3D(Basis(), pos))
			n_gold += 1
			s += MOTE_STEP
		k += 1
	gold.visible_instance_count = n_gold
	coral.visible_instance_count = _gap_points.size()


func _rebuild_glows() -> void:
	var gaps := subject.gap_midpoints()
	while _glows.size() < gaps.size():
		_glows.append(StyleKit.glow_plane(self, _gap_glow_mat, 6.5, Vector3.ZERO))
	for i: int in range(_glows.size()):
		_glows[i].visible = i < gaps.size()
		if i < gaps.size():
			_glows[i].position = Vector3(gaps[i].x, 0.055, gaps[i].z)


# The pulse: gap motes swell (0.8x to 2.1x), gap glows grow (0.8x to 1.25x).
func _swell(pulse: float) -> void:
	var coral := _gap_motes.multimesh
	var scale_now := 0.8 + 1.3 * pulse
	for i: int in range(_gap_points.size()):
		coral.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * scale_now), _gap_points[i]))
	var glow_scale := 0.8 + 0.45 * pulse
	for g: MeshInstance3D in _glows:
		g.scale = Vector3(glow_scale, 1.0, glow_scale)


static func _hash(k: int) -> float:
	return fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)
