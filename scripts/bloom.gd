class_name Bloom
extends Node3D

# A flower patch left where a nature projectile stopped. For TD_BLOOM_SECONDS, everyone standing inside its
# radius gets Nature joy (no distance falloff) in pulses, then it fades out and frees itself.
# Set people before adding it to the scene.

const PETAL_COLOR := Color(0.35, 0.7, 0.3)
const CENTRE_COLOR := Color(1.0, 0.9, 0.3)
const FLOWER_COUNT := 7
const PETALS_PER_FLOWER := 5

var people: Array[Person] = []

var _age := 0.0
var _pulse := 0.0


func _ready() -> void:
	_build_patch()


func _physics_process(delta: float) -> void:
	_age += delta
	_pulse += delta
	if _pulse >= Config.TD_BLOOM_PULSE_SECONDS:
		_soak(_pulse)
		_pulse = 0.0
	var left := Config.TD_BLOOM_SECONDS - _age
	scale = Vector3.ONE * clampf(left / Config.TD_BLOOM_FADE_SECONDS, 0.0, 1.0)
	if _age >= Config.TD_BLOOM_SECONDS:
		queue_free()


# Gives joy to everyone inside the radius. `seconds` is how long the pulse covers.
func _soak(seconds: float) -> void:
	var amount := Config.TD_BLOOM_JOY_PER_SEC * seconds
	for p: Person in people:
		if GloomSim.flat_dist(global_position, p.global_position) <= Config.TD_BLOOM_RADIUS:
			p.receive_joy(Config.Element.NATURE, amount, 0.0)


# A faint green disc for the patch, with a few small flowers (five petals and a yellow centre) on it.
func _build_patch() -> void:
	var ground := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Config.TD_BLOOM_RADIUS
	disc.bottom_radius = Config.TD_BLOOM_RADIUS
	disc.height = 0.01
	ground.mesh = disc
	ground.position = Vector3(0, 0.01, 0)
	ground.material_override = _make_mat(Color(PETAL_COLOR.r, PETAL_COLOR.g, PETAL_COLOR.b, 0.3), true)
	add_child(ground)

	var petal_mat := _make_mat(PETAL_COLOR, false)
	var centre_mat := _make_mat(CENTRE_COLOR, false)
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


func _make_mat(col: Color, translucent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	if translucent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
