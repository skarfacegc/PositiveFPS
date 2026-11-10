class_name LandmarkLookPlaceholder
extends LandmarkLook

# The placeholder landmark: a pillar, a fixed outline ring with a disc inside that grows with the hold progress, a
# label, and (round 19) a simple shape of its own on top: a flat canopy for the bandstand, a ball for the garden, a
# tall box for the bell tower. Held or not shows in the pillar's colour (gold when held, grey when not) and the label.

const UNHELD_COLOUR := Color(0.62, 0.62, 0.66)

var _disc: MeshInstance3D
var _label: Label3D
var _pillar: MeshInstance3D
var _pillar_mat: StandardMaterial3D
var _shape_mat: StandardMaterial3D
var _pulse: Tween


# Round 20: a claim or a loss makes the pillar swell and settle, so the change is seen on the landmark itself.
func play_change(_held: bool) -> void:
	if _pillar == null:
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = create_tween()
	_pulse.tween_property(_pillar, "scale", Vector3(3.0, 1.0, 3.0), 0.15)
	_pulse.tween_property(_pillar, "scale", Vector3.ONE, 0.6)


# True while the pulse is still running (tests).
func pulse_running() -> bool:
	return _pulse != null and _pulse.is_valid() and _pulse.is_running()


func sync() -> void:
	if _disc == null:
		return
	var frac := subject.progress()
	_disc.scale = Vector3(frac, 1.0, frac)
	var name_text := subject.landmark_name()
	var held := subject.is_held()
	_pillar_mat.albedo_color = LandmarkConfig.LANDMARK_LIT_COLOUR if held else UNHELD_COLOUR
	_shape_mat.albedo_color = LandmarkConfig.LANDMARK_COLOURS[subject.index] if held else UNHELD_COLOUR
	if held:
		_label.text = "%s HELD: %s" % [name_text, subject.boost_text()]
	elif subject.beautified or subject.hold > 0.0:
		_label.text = "%s %d%%" % [name_text, roundi(frac * 100.0)]
	else:
		_label.text = name_text


func _build() -> void:
	var height := LandmarkConfig.LANDMARK_SIZES[subject.index].y
	_pillar_mat = _unshaded(UNHELD_COLOUR)
	_pillar = MeshInstance3D.new()
	var pillar := CylinderMesh.new()
	pillar.top_radius = 0.15
	pillar.bottom_radius = 0.15
	pillar.height = 9.0
	_pillar.mesh = pillar
	_pillar.position = Vector3(0, height + 4.5, 0)
	_pillar.material_override = _pillar_mat
	add_child(_pillar)

	_shape_mat = _unshaded(UNHELD_COLOUR)
	var shape := MeshInstance3D.new()
	shape.mesh = _shape_mesh(subject.index)
	shape.position = Vector3(0, height + 1.2, 0)
	shape.material_override = _shape_mat
	add_child(shape)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = RING_INNER
	torus.outer_radius = RING_OUTER
	ring.mesh = torus
	ring.position = Vector3(0, 0.05, 0)
	ring.material_override = _unshaded(BorderConfig.BORDER_INTACT_COLOUR)
	add_child(ring)

	_disc = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = RING_INNER
	disc.bottom_radius = RING_INNER
	disc.height = 0.03
	_disc.mesh = disc
	_disc.position = Vector3(0, 0.04, 0)
	_disc.material_override = _unshaded(LandmarkConfig.LANDMARK_LIT_COLOUR)
	add_child(_disc)

	_label = Label3D.new()
	_label.position = Vector3(0, height + 9.6, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.012
	_label.no_depth_test = true
	add_child(_label)


# Each landmark's own simple shape: a flat canopy (bandstand), a ball (garden), a tall box (bell tower), a wide thin
# wall (gallery).
func _shape_mesh(index: int) -> Mesh:
	if index == Landmarks.GARDEN:
		var ball := SphereMesh.new()
		ball.radius = 1.0
		ball.height = 2.0
		return ball
	if index == Landmarks.BELL_TOWER:
		var tall := BoxMesh.new()
		tall.size = Vector3(1.2, 2.4, 1.2)
		return tall
	if index == Landmarks.GALLERY:
		var wall := BoxMesh.new()
		wall.size = Vector3(3.2, 1.8, 0.5)
		return wall
	var canopy := CylinderMesh.new()
	canopy.top_radius = 2.2
	canopy.bottom_radius = 2.2
	canopy.height = 0.3
	return canopy


func _unshaded(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	return mat
