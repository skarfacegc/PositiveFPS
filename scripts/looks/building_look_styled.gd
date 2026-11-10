class_name BuildingLookStyled
extends BuildingLook

# The styled block: an industrial building (steel, pipes, vents) and, built the first time it is needed, the whimsical
# version of the same block (plaster, timber, shutters, flower boxes, bunting). They are swapped with a short
# dissolve that follows the rules' tint (0 industrial to 1 whimsical). The block's size is the collision box; the
# drawn building is a little taller than it. (0.4: the town grid's blocks are 12 m cells; the styled grid town, with a
# group of houses filling each cell, is a later look-focused target, so for now one building stands in the cell.)

const ROOFS: Array[String] = ["#ad6249", "#5f86b0", "#c0604f", "#7f9d62"]
const SHUTTERS: Array[String] = ["#5f86b0", "#c0604f", "#7f9d62", "#5f86b0"]
const DOORS: Array[String] = ["#5f86b0", "#c0604f", "#7f9d62", "#c0604f"]
const EXTRA_HEIGHT := 1.0

# The two versions (the whimsical one is null until it is first shown).
var industrial: Node3D
var whimsical: Node3D
var _opts: Dictionary = {}
var _dims := Vector3.ZERO
var _applied: float = -1.0


func is_styled() -> bool:
	return true


func sync(_delta: float = 0.0) -> void:
	if industrial == null:
		return
	var mix := clampf(subject.tint, 0.0, 1.0)
	if is_equal_approx(mix, _applied):
		return
	_applied = mix
	if mix > 0.0 and whimsical == null:
		whimsical = _make_version(false)
	industrial.visible = mix < 1.0
	_set_dissolve(industrial, mix)
	if whimsical != null:
		whimsical.visible = mix > 0.0
		_set_dissolve(whimsical, mix)


func _build() -> void:
	if subject.is_landmark:
		# Graphics checkpoint 3: a landmark's building is drawn by its own look (LandmarkLookStyled).
		return
	var idx := int(absf(subject.centre.x * 7.0 + subject.centre.y * 13.0)) % 4
	_dims = Vector3(minf(size.x, 4.0) - 0.1, size.y + EXTRA_HEIGHT, minf(size.z, 4.0) - 0.4)
	_opts = {
		"kiosk": true,
		"nwin": 1,
		"roof": ROOFS[idx],
		"shutter": SHUTTERS[idx],
		"door": DOORS[idx],
		"tank": idx % 2 == 0,
		"tankside": 1.0 if idx < 2 else -1.0,
		"stack": idx == 1
	}
	industrial = _make_version(true)
	sync()


func _make_version(is_industrial: bool) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.0, -size.y * 0.5, 0.0)
	add_child(root)
	if is_industrial:
		StyleBuildings.build_industrial(root, _dims.x, _dims.z, _dims.y, _opts)
	else:
		StyleBuildings.build_whimsical(root, _dims.x, _dims.z, _dims.y, _opts)
	return root


# Sets the dissolve (0 industrial .. 1 whimsical) on every mesh of a version.
func _set_dissolve(root: Node3D, amount: float) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).set_instance_shader_parameter("dissolve", amount)
