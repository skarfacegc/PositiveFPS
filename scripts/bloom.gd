class_name Bloom
extends Node3D

# A flower patch left where a nature projectile stopped. For TD_BLOOM_SECONDS, everyone standing inside its
# radius gets Nature joy (no distance falloff) in pulses, then it fades out and frees itself.
# Set people before adding it to the scene.
#
# Round 8: the patch has a crisp, outlined edge. A thin darker sage disc of radius TD_BLOOM_RADIUS sits under a
# translucent fill that stops TD_BLOOM_RING_WIDTH short of it, so the outline is exactly at TD_BLOOM_RADIUS and has no
# soft rim. The whole patch fades together at the end (alpha only).

const PETAL_COLOR := Color(0.35, 0.7, 0.3)
const CENTRE_COLOR := Color(1.0, 0.9, 0.3)
const FLOWER_COUNT := 7
const PETALS_PER_FLOWER := 5

var people: Array[Person] = []

var _age := 0.0
var _pulse := 0.0
# Every material in the patch, and its alpha when fully visible. The fade scales these together.
var _mats: Array[StandardMaterial3D] = []
var _base_alpha: Array[float] = []


func _ready() -> void:
	_build_patch()


func _physics_process(delta: float) -> void:
	_age += delta
	_pulse += delta
	if _pulse >= Config.TD_BLOOM_PULSE_SECONDS:
		_soak(_pulse)
		_pulse = 0.0
	var left := Config.TD_BLOOM_SECONDS - _age
	_set_fade(clampf(left / Config.TD_BLOOM_FADE_SECONDS, 0.0, 1.0))
	if _age >= Config.TD_BLOOM_SECONDS:
		queue_free()


# Gives joy to everyone inside the radius. `seconds` is how long the pulse covers.
func _soak(seconds: float) -> void:
	var amount := Config.TD_BLOOM_JOY_PER_SEC * seconds
	for p: Person in people:
		if GloomSim.flat_dist(global_position, p.global_position) <= Config.TD_BLOOM_RADIUS:
			p.receive_joy(Config.Element.NATURE, amount, 0.0)


# Scales the alpha of every material in the patch by `factor` (1 is fully visible, 0 is gone).
func _set_fade(factor: float) -> void:
	for i: int in range(_mats.size()):
		var col := _mats[i].albedo_color
		_mats[i].albedo_color = Color(col.r, col.g, col.b, _base_alpha[i] * factor)


# An outlined patch: the dark sage outline at the edge, a translucent fill inside it, and a few small flowers.
func _build_patch() -> void:
	var outline := _disc(Config.TD_BLOOM_RADIUS, Config.TD_BLOOM_RING_COLOR, 1.0, 0.0)
	var fill := _disc(
		Config.TD_BLOOM_RADIUS - Config.TD_BLOOM_RING_WIDTH, PETAL_COLOR, Config.TD_BLOOM_FILL_ALPHA, 0.01
	)
	add_child(outline)
	add_child(fill)

	var petal_mat := _track(PETAL_COLOR, 1.0)
	var centre_mat := _track(CENTRE_COLOR, 1.0)
	for i: int in range(FLOWER_COUNT):
		var a := TAU * i / float(FLOWER_COUNT)
		var r := Config.TD_BLOOM_RADIUS * (0.35 if i % 2 == 0 else 0.6)
		var flower := Node3D.new()
		flower.position = Vector3(cos(a) * r, 0.03, sin(a) * r)
		add_child(flower)
		for k: int in range(PETALS_PER_FLOWER):
			var pa := TAU * k / float(PETALS_PER_FLOWER)
			var petal := MeshInstance3D.new()
			var petal_mesh := CylinderMesh.new()
			petal_mesh.top_radius = 0.12
			petal_mesh.bottom_radius = 0.12
			petal_mesh.height = 0.02
			petal.mesh = petal_mesh
			petal.material_override = petal_mat
			petal.position = Vector3(cos(pa) * 0.14, 0.0, sin(pa) * 0.14)
			flower.add_child(petal)
		var centre := MeshInstance3D.new()
		var centre_mesh := SphereMesh.new()
		centre_mesh.radius = 0.07
		centre_mesh.height = 0.14
		centre.mesh = centre_mesh
		centre.material_override = centre_mat
		flower.add_child(centre)


# A flat disc of `radius` metres, lying on the ground at height `y`, in `col` with alpha `alpha`.
func _disc(radius: float, col: Color, alpha: float, y: float) -> MeshInstance3D:
	var disc_node := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.01
	disc_node.mesh = disc
	disc_node.position = Vector3(0, 0.01 + y, 0)
	disc_node.material_override = _track(col, alpha)
	return disc_node


# A new unshaded, translucent material, remembered so the fade can reach it.
func _track(col: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	_mats.append(mat)
	_base_alpha.append(alpha)
	return mat
