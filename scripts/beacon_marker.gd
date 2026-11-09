class_name BeaconMarker
extends Node3D

# Round 19: the spirit beacon as it stands in the world (placeholder look): a thin pale-blue pillar on a flat ring.
# It shows while the border has a beacon and follows Border.beacon_pos(). The styled look (graphics checkpoint 3, see
# StyleBeacon) is a lantern post with a teal flame, and a line of dashes marching from the border's centre toward it to
# show the pull. rebuild_look() swaps between the two (F4).

var _pulse: float = 0.0
var _parts: Dictionary = {}
var _dashes: Array[MeshInstance3D] = []
var _dash_root: Node3D


func _ready() -> void:
	visible = false
	rebuild_look()


# Rebuilds the marker's visuals for the current look (the node's own position and visibility are kept).
func rebuild_look() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_parts = {}
	_dashes = []
	_dash_root = null
	scale = Vector3.ONE
	if Looks.is_styled():
		_parts = StyleBeacon.build(self)
		# The dashes live in world space beside the marker: a sibling, so they do not follow its position or scale.
		_dash_root = Node3D.new()
		_dash_root.top_level = true
		add_child(_dash_root)
		_dashes = StyleBeacon.build_dashes(_dash_root)
		return
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 6.0
	pillar.mesh = cyl
	pillar.position = Vector3(0, 3.0, 0)
	pillar.material_override = _unshaded()
	add_child(pillar)
	# Checkpoint 6: the mark sits on the pillar (freed with it when the look changes), not on this node, which lives on in
	# the styled look and would be counted as a placeholder there.
	Looks.note_placeholder(pillar, "beacon")
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.2
	ring.mesh = torus
	ring.position = Vector3(0, 0.06, 0)
	ring.material_override = _unshaded()
	add_child(ring)


# Moves to the beacon (or hides when there is none) and pulses a little.
func sync(pos: Vector3, delta: float, from: Vector3 = Vector3.INF) -> void:
	visible = pos != Vector3.INF
	if not visible:
		return
	_pulse += delta
	position = Vector3(pos.x, 0.0, pos.z)
	if not _parts.is_empty():
		StyleBeacon.animate(_parts, _pulse)
		if from != Vector3.INF:
			StyleBeacon.place_dashes(_dashes, Vector3.ZERO, from, position, _pulse)
		return
	var s := 1.0 + 0.15 * sin(_pulse * 3.0)
	scale = Vector3(s, 1.0, s)


func _unshaded() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = BeaconConfig.BEACON_COLOUR
	return mat
