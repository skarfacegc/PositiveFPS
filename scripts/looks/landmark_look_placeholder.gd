class_name LandmarkLookPlaceholder
extends LandmarkLook

# The placeholder landmark: a beacon pillar, a fixed outline ring with a disc inside that grows with the hold
# progress, and a label.

var _disc: MeshInstance3D
var _label: Label3D


func sync() -> void:
	if _disc == null:
		return
	var frac := subject.progress()
	_disc.scale = Vector3(frac, 1.0, frac)
	var shown := subject.beautified or subject.hold > 0.0
	_label.text = "Landmark held %d%%" % roundi(frac * 100.0) if shown else "Landmark"


func _build() -> void:
	var beacon := MeshInstance3D.new()
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.15
	pillar.bottom_radius = 0.15
	pillar.height = 9.0
	beacon.mesh = pillar
	beacon.position = Vector3(0, Config.BORDER_LANDMARK_SIZE.y + 4.5, 0)
	beacon.material_override = _unshaded(Config.BORDER_BEACON_COLOUR)
	add_child(beacon)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_INNER
	torus.outer_radius = RING_OUTER
	ring.mesh = torus
	ring.position = Vector3(0, 0.05, 0)
	ring.material_override = _unshaded(Config.BORDER_INTACT_COLOUR)
	add_child(ring)

	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RING_INNER
	disc.bottom_radius = RING_INNER
	disc.height = 0.03
	_disc.mesh = disc
	_disc.position = Vector3(0, 0.04, 0)
	_disc.material_override = _unshaded(Config.BORDER_BEACON_COLOUR)
	add_child(_disc)

	_label = Label3D.new()
	_label.position = Vector3(0, Config.BORDER_LANDMARK_SIZE.y + 9.6, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.012
	_label.no_depth_test = true
	add_child(_label)


func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat
