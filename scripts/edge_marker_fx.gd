class_name EdgeMarkerFx
extends Node3D

# Round 25 (edge cleanup): draws the trouble markers (EdgeMarkers.pick) as ONE flat breathing ring per spot, coloured
# by kind (coral gap, pale wobble, amber strain, warm gift). No columns, no pings, no second ring. Both looks: the
# placeholder look uses a plain torus, the styled look the dithered ring of StyleFight. The pool holds
# EDGE_MARKER_MAX rings and is rebuilt when the look changes. GapPatch owns this node and feeds it `markers`.

const RING_Y := 0.1
const INNER := 0.86  # The placeholder torus's hole (as a share of its radius).
const STYLED_INNER := 0.6  # The styled ring's: wide enough to hold its ink edge, rim and dithered fill.

var _rings: Array[MeshInstance3D] = []
var _built_styled: bool = false
var _time: float = 0.0
var _shown: int = 0


# Shows `markers` (EdgeMarkers.pick, at most EDGE_MARKER_MAX) and advances the breathing by `delta`.
func sync(delta: float, markers: Array[EdgeMarkers.Marker]) -> void:
	_time += delta
	if Looks.is_styled() != _built_styled:
		_rebuild()
	while _rings.size() < mini(markers.size(), Config.EDGE_MARKER_MAX):
		_rings.append(_make_ring())
	_shown = 0
	for i: int in range(_rings.size()):
		var ring := _rings[i]
		ring.visible = i < markers.size()
		if not ring.visible:
			continue
		_shown += 1
		_place(ring, markers[i], i)


# How many markers are showing.
func shown_count() -> int:
	return _shown


# True when the pool holds the styled rings.
func is_styled_built() -> bool:
	return _built_styled


# The marker ring `i` (for tests and the checkpoint shots).
func ring_at(i: int) -> MeshInstance3D:
	return _rings[i]


func _rebuild() -> void:
	_built_styled = Looks.is_styled()
	for ring: MeshInstance3D in _rings:
		ring.queue_free()
	_rings.clear()


func _place(ring: MeshInstance3D, marker: EdgeMarkers.Marker, i: int) -> void:
	var at := marker.pos
	var base := EdgeMarkers.radius_of(marker)
	var col := EdgeMarkers.colour_of(marker)
	var rate := 2.4 + 3.0 * marker.severity
	var breath := 0.5 + 0.5 * sin(_time * rate + float(i))
	var size := base * (0.92 + 0.12 * breath)
	ring.position = Vector3(at.x, RING_Y, at.z)
	ring.scale = Vector3(size, 1.0, size)
	if _built_styled:
		StyleFight.set_ring(ring, col, 0.55 + 0.4 * breath, 0.1)
		return
	col.a = 0.55 + 0.4 * breath
	(ring.material_override as StandardMaterial3D).albedo_color = col


func _make_ring() -> MeshInstance3D:
	if _built_styled:
		return StyleFight.ring_node(self, STYLED_INNER, Config.EDGE_MARKER_COLOUR_GAP, Color.WHITE, 0.6)
	var m := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = INNER
	torus.outer_radius = 1.0
	m.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material_override = mat
	m.visible = false
	add_child(m)
	Looks.note_placeholder(m, "spirit_fx")
	return m
