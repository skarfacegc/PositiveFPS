class_name BuildingLookStyled
extends BuildingLook

# The styled block: an industrial building (steel, pipes, vents) and, built the first time it is needed, the whimsical
# version of the same block (plaster, timber, shutters, flower boxes, bunting). They are swapped with a short dithered
# dissolve that follows the rules' tint (0 industrial to 1 whimsical). The block's size is the collision box; the
# drawn building is a little taller than it. A block that is a border post gets a glowing lantern and a gold ring.

const ROOFS: Array[String] = ["#ad6249", "#5f86b0", "#c0604f", "#7f9d62"]
const SHUTTERS: Array[String] = ["#5f86b0", "#c0604f", "#7f9d62", "#5f86b0"]
const DOORS: Array[String] = ["#5f86b0", "#c0604f", "#7f9d62", "#c0604f"]
const EXTRA_HEIGHT := 1.0
const LANDMARK_EXTRA_HEIGHT := 0.7

# The two versions (the whimsical one is null until it is first shown).
var industrial: Node3D
var whimsical: Node3D
var _opts: Dictionary = {}
var _dims := Vector3.ZERO
var _applied: float = -1.0
var _lantern: MeshInstance3D
var _post_ring: MeshInstance3D


func is_styled() -> bool:
	return true


func sync(_delta: float = 0.0) -> void:
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


func set_post(on: bool) -> void:
	if _lantern != null:
		_lantern.visible = on
		_post_ring.visible = on


func _build() -> void:
	var idx := int(absf(subject.centre.x * 7.0 + subject.centre.y * 13.0)) % 4
	var extra := LANDMARK_EXTRA_HEIGHT if subject.is_landmark else EXTRA_HEIGHT
	_dims = Vector3(minf(size.x, 4.0) - 0.1, size.y + extra, minf(size.z, 4.0) - 0.4)
	if subject.is_landmark:
		_opts = {
			"kiosk": true,
			"nwin": 1,
			"roof": "#5f86b0",
			"shutter": "#c0604f",
			"door": "#c0604f",
			"tank": true,
			"tankside": -1.0,
			"stack": true,
			"landmark": true
		}
	else:
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
	_build_post_marker()
	set_post(subject.post)
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


func _build_post_marker() -> void:
	var gold := StyleKit.mat(StyleKit.hexc("#ffd466"), 0, 0.0, 1.2)
	_lantern = StyleKit.sph(
		self, 0.4, Vector3(0.0, size.y * 0.5 + EXTRA_HEIGHT + 1.2, 0.0), gold, Vector3.ONE, 8, false
	)
	_post_ring = StyleKit.torus(
		self,
		Config.BORDER_POST_RING_INNER,
		Config.BORDER_POST_RING_OUTER,
		Vector3(0.0, -size.y * 0.5 + 0.08, 0.0),
		gold
	)
	_post_ring.scale = Vector3(1.0, 0.3, 1.0)
	_post_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
