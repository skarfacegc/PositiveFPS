extends Node3D

# A visual-only joy projectile for top-down mode. It flies from the player to a person in an arc, then pops.
# It has no physics: the joy is already applied by the player when this is spawned.
# Set element, start and end_pos before adding it to the scene.

const BLOB_SCALE := Vector3(1.2, 0.8, 1.2)
const FLOWER_CENTRE_COLOR := Color(1.0, 0.9, 0.3)

var element: int = 0
var start: Vector3 = Vector3.ZERO
var end_pos: Vector3 = Vector3.ZERO
var speed: float = Config.TD_PROJECTILE_SPEED

var _duration := 0.1
var _t := 0.0
var _age := 0.0
var _body: Node3D
var _done := false


func _ready() -> void:
	var dist := start.distance_to(end_pos)
	_duration = maxf(dist / speed, Config.TD_PROJECTILE_MIN_TIME)
	global_position = start

	if element == Config.Element.MUSIC:
		_build_music()
	elif element == Config.Element.ART:
		_build_paint()
	else:
		_build_flower()


func _process(delta: float) -> void:
	if _done:
		return
	_age += delta
	_t = minf(_t + delta / _duration, 1.0)

	var pos: Vector3 = start.lerp(end_pos, _t)
	pos.y += sin(_t * PI) * Config.TD_PROJECTILE_ARC
	if element == Config.Element.MUSIC:
		pos.x += sin(_age * 12.0) * Config.TD_PROJECTILE_BOB
	global_position = pos

	if element == Config.Element.ART and _body != null:
		_body.scale = BLOB_SCALE * (1.0 + 0.12 * sin(_age * 14.0))
	if element == Config.Element.NATURE:
		rotation.y += Config.TD_FLOWER_SPIN * delta

	if _t >= 1.0:
		_arrive()


# Music note: a squashed sphere head with a stem on the upper right.
func _build_music() -> void:
	var mat := _make_mat(Config.ELEMENT_COLORS[element])

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.3
	head.mesh = sphere
	head.material_override = mat
	add_child(head)

	var stem := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.6, 0.06)
	stem.mesh = box
	stem.position = Vector3(0.18, 0.3, 0.0)
	stem.material_override = mat
	add_child(stem)


# Paint blob: a squashed pink sphere that wobbles as it flies.
func _build_paint() -> void:
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	blob.mesh = sphere
	blob.material_override = _make_mat(Config.ELEMENT_COLORS[element])
	blob.scale = BLOB_SCALE
	add_child(blob)
	_body = blob


# Flower: a yellow centre with five green petals in a ring. The whole flower spins as it flies.
func _build_flower() -> void:
	var centre := MeshInstance3D.new()
	var centre_mesh := SphereMesh.new()
	centre_mesh.radius = 0.12
	centre_mesh.height = 0.24
	centre.mesh = centre_mesh
	centre.material_override = _make_mat(FLOWER_CENTRE_COLOR)
	add_child(centre)

	var petal_mat := _make_mat(Config.ELEMENT_COLORS[element])
	for i in range(5):
		var a := TAU * i / 5.0
		var petal := MeshInstance3D.new()
		var petal_mesh := SphereMesh.new()
		petal_mesh.radius = 0.13
		petal_mesh.height = 0.26
		petal.mesh = petal_mesh
		petal.material_override = petal_mat
		petal.position = Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
		add_child(petal)


# Arrives at the person: paint leaves a splat, then every type gives a small puff and frees itself.
func _arrive() -> void:
	_done = true
	if element == Config.Element.ART:
		_spawn_splat()
	_spawn_puff()
	queue_free()


# A flat, fading paint splat on the ground. It is added to the level so it outlives this projectile.
func _spawn_splat() -> void:
	var splat := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = Config.TD_SPLAT_RADIUS
	cyl.bottom_radius = Config.TD_SPLAT_RADIUS
	cyl.height = 0.02
	splat.mesh = cyl
	var col: Color = Config.ELEMENT_COLORS[Config.Element.ART]
	col.a = Config.TD_SPLAT_ALPHA
	var mat := _make_mat(col)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splat.material_override = mat
	get_parent().add_child(splat)
	splat.global_position = Vector3(end_pos.x, 0.02, end_pos.z)

	var t := splat.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_SPLAT_FADE_TIME)
	t.tween_callback(splat.queue_free)


# A tiny one-shot burst of particles in the element colour, freed after one second.
func _spawn_puff() -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 10
	puff.lifetime = 0.6
	puff.spread = 180.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 3.0
	puff.gravity = Vector3(0, -2, 0)
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.material = _make_mat(Config.ELEMENT_COLORS[element])
	puff.mesh = m
	get_parent().add_child(puff)
	puff.global_position = end_pos
	puff.emitting = true
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)


func _make_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	return mat
