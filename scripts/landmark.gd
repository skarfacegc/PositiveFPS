class_name Landmark
extends Node3D

# The level's landmark: a taller block with a beacon pillar, away from the start. Its block is built by TopDownMain
# (it is an obstacle like the others); this node adds the beacon and the hold ring. The ring is a fixed outline with a
# disc inside it that grows with the hold progress, so the player can see how long is left.

const RING_INNER := 2.2
const RING_OUTER := 2.6

# Seconds the landmark has been held (beautified and inside the border). Resets when it is lost.
var hold: float = 0.0
var _disc: MeshInstance3D
var _label: Label3D


func _ready() -> void:
	position = Config.BORDER_LANDMARK_POS

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
	update(0.0, false)


# Holds the landmark: while `beautified` (the landmark block is inside the border) the hold grows, otherwise it resets.
func update(delta: float, beautified: bool) -> void:
	if beautified:
		hold = minf(hold + delta, Config.BORDER_LANDMARK_HOLD)
	else:
		hold = 0.0
	var frac := progress()
	_disc.scale = Vector3(frac, 1.0, frac)
	_label.text = "Landmark held %d%%" % roundi(frac * 100.0) if beautified or hold > 0.0 else "Landmark"


# How much of the hold is done, 0 to 1.
func progress() -> float:
	return hold / Config.BORDER_LANDMARK_HOLD


# True once the landmark has been held for BORDER_LANDMARK_HOLD seconds.
func is_held() -> bool:
	return hold >= Config.BORDER_LANDMARK_HOLD


func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat
