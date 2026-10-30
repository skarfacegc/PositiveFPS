class_name BeaconMarker
extends Node3D

# Round 19: the spirit beacon as it stands in the world (placeholder look): a thin pale-blue pillar on a flat ring.
# It shows while the border has a beacon and follows Border.beacon_pos(). It has no styled look yet (graphics
# checkpoint 3), so it registers itself as a placeholder.

var _pulse: float = 0.0


func _ready() -> void:
	visible = false
	var pillar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.12
	cyl.bottom_radius = 0.12
	cyl.height = 6.0
	pillar.mesh = cyl
	pillar.position = Vector3(0, 3.0, 0)
	pillar.material_override = _unshaded()
	add_child(pillar)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.2
	ring.mesh = torus
	ring.position = Vector3(0, 0.06, 0)
	ring.material_override = _unshaded()
	add_child(ring)
	Looks.note_placeholder(self, "beacon")


# Moves to the beacon (or hides when there is none) and pulses a little.
func sync(pos: Vector3, delta: float) -> void:
	visible = pos != Vector3.INF
	if not visible:
		return
	_pulse += delta
	position = Vector3(pos.x, 0.0, pos.z)
	var s := 1.0 + 0.15 * sin(_pulse * 3.0)
	scale = Vector3(s, 1.0, s)


func _unshaded() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Config.BEACON_COLOUR
	return mat
