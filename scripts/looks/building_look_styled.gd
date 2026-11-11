class_name BuildingLookStyled
extends BuildingLook

# The styled block (0.4 pass 2b, #58): a tight group of small houses that fills the town cell (StyleHouses): grey
# industrial houses and, built the first time it is needed, the whimsical version of the same group (plaster, gable
# roofs, coloured doors, lit windows). They are swapped with a short dissolve that follows the rules' tint (0
# industrial to 1 whimsical). The block's size is the collision box; the houses fill its footprint.

# The two versions (the whimsical one is null until it is first shown).
var industrial: Node3D
var whimsical: Node3D
var _houses: Array[Dictionary] = []
var _seed: int = 0
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
	_seed = int(absf(subject.centre.x * 7.0 + subject.centre.y * 13.0))
	_houses = StyleHouses.layout(size.x, size.z, _seed)
	industrial = _make_version(true)
	sync()


# One version of the block: the group of houses, turned a quarter turn at a time so the alleys do not all run one way.
func _make_version(is_industrial: bool) -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.0, -size.y * 0.5, 0.0)
	root.rotation.y = float((_seed / 2) % 4) * PI * 0.5
	add_child(root)
	if is_industrial:
		StyleHouses.build_industrial(root, _houses)
	else:
		StyleHouses.build_whimsical(root, _houses)
	return root


# Sets the dissolve (0 industrial .. 1 whimsical) on every mesh of a version.
func _set_dissolve(root: Node3D, amount: float) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).set_instance_shader_parameter("dissolve", amount)
