class_name EmbraceCue
extends Node3D

# Round 25 part S: the placeholder cue on a person being embraced (see Embrace): a warm glow disc on the ground that
# breathes, and a ring round the feet that fills clockwise toward the next stage. It is a child of the Person, not of
# their look, so it survives a look change (F4) and costs nothing for anyone not embraced. Its clock is the fixed-step
# one Embrace hands to show_progress(); the ring is rebuilt only when its fill moves by a segment.

var _glow: MeshInstance3D
var _glow_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _segments: int = -1  # How many ring segments are drawn now (-1 until the first draw).


func _ready() -> void:
	_glow_mat = _unshaded_mat()
	_glow = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = EmbraceConfig.EMBRACE_GLOW_RADIUS
	disc.bottom_radius = EmbraceConfig.EMBRACE_GLOW_RADIUS
	disc.height = 0.03
	_glow.mesh = disc
	_glow.position = Vector3(0, EmbraceConfig.EMBRACE_GLOW_Y, 0)
	_glow.material_override = _glow_mat
	add_child(_glow)
	_ring_mat = _unshaded_mat()
	_ring_mat.albedo_color = EmbraceConfig.EMBRACE_RING_COLOUR
	_ring = MeshInstance3D.new()
	_ring.position = Vector3(0, EmbraceConfig.EMBRACE_RING_Y, 0)
	_ring.material_override = _ring_mat
	add_child(_ring)
	Looks.note_placeholder(self, "embrace")


# `frac` (0..1) is how far through the step; `inside` false while they have left the loop (the glow is dim and the ring
# fades back); `clock` is the fixed-step seconds that breathe the glow.
func show_progress(frac: float, inside: bool, clock: float) -> void:
	if _glow == null:
		return
	var breathe := 0.5 + 0.5 * sin(clock * TAU * EmbraceConfig.EMBRACE_PULSE_HZ)
	var strength := 1.0 if inside else EmbraceConfig.EMBRACE_OUTSIDE_FADE
	var c := EmbraceConfig.EMBRACE_GLOW_COLOUR
	var alpha := EmbraceConfig.EMBRACE_GLOW_ALPHA * lerpf(0.6, 1.0, breathe) * (0.7 + 0.3 * frac) * strength
	_glow_mat.albedo_color = Color(c.r, c.g, c.b, alpha)
	var segs := roundi(clampf(frac, 0.0, 1.0) * EmbraceConfig.EMBRACE_RING_SEGMENTS)
	if segs != _segments:
		_segments = segs
		_ring.mesh = ring_mesh(segs)
	_ring.visible = segs > 0


# The number of ring segments drawn now (for tests).
func segments() -> int:
	return maxi(_segments, 0)


# A flat ring of `segs` of EMBRACE_RING_SEGMENTS segments, from the front (-Z), clockwise seen from above.
static func ring_mesh(segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inner := EmbraceConfig.EMBRACE_RING_INNER
	var outer := EmbraceConfig.EMBRACE_RING_OUTER
	var total := float(EmbraceConfig.EMBRACE_RING_SEGMENTS)
	for i: int in range(segs):
		var a0 := TAU * float(i) / total
		var a1 := TAU * float(i + 1) / total
		var p00 := Vector3(sin(a0) * inner, 0, -cos(a0) * inner)
		var p01 := Vector3(sin(a0) * outer, 0, -cos(a0) * outer)
		var p10 := Vector3(sin(a1) * inner, 0, -cos(a1) * inner)
		var p11 := Vector3(sin(a1) * outer, 0, -cos(a1) * outer)
		for v: Vector3 in [p00, p01, p10, p10, p01, p11]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	return st.commit()


static func _unshaded_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
