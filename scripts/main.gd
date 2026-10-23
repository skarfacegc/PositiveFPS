class_name Main
extends Node3D

# Seed for the random number generator, so people appear in the same places every run.
const PEOPLE_SEED := 42

# The floor is this many tiles along each side (one metre per tile).
const TILE_COUNT := 40

# Centres of the six building blocks. Each one is 4 x 3 x 4 in size.
const BLOCK_POSITIONS: Array[Vector3] = [
	Vector3(-10, 1.5, -8),
	Vector3(9, 1.5, -10),
	Vector3(-12, 1.5, 9),
	Vector3(11, 1.5, 8),
	Vector3(0, 1.5, -14),
	Vector3(0, 1.5, 12),
]

var player: Player
var hud: Hud
var ground: PaintedGround
var people: Array[Person] = []
var time_left: float = Config.ROUND_SECONDS
var rescued_count: int = 0
var running: bool = true


func _ready() -> void:
	Controls.setup()
	_setup_environment()
	_build_level()
	ground = PaintedGround.new()
	add_child(ground)
	ground.setup(TILE_COUNT)

	player = Player.new()
	player.position = Vector3(0, 1, 0)
	add_child(player)

	_spawn_people()

	hud = Hud.new()
	add_child(hud)
	hud.set_hint(
		"1 Music  2 Art  3 Nature  |  Shift run  |  Get close for more joy  |  Esc free mouse  |  R restart  |  M menu"
	)
	player.element_changed.connect(hud.set_element)
	hud.set_element(player.current_element)
	hud.set_rescued(rescued_count, Config.PEOPLE_COUNT)

	Controls.set_mouse_captured(true)


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	hud.set_time(time_left)
	GloomSim.update(people, delta)
	for p: Person in people:
		p.tick(delta)
	ground.update_paint(people, delta)
	if time_left <= 0.0:
		time_left = 0.0
		_end_round("Time's up!")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("menu"):
		Controls.set_mouse_captured(false)
		get_tree().change_scene_to_file("res://menu.tscn")


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)


func _build_level() -> void:
	# Floor: 40 x 40, top surface at y = 0.
	add_child(_make_box(Vector3(40, 1, 40), Vector3(0, -0.5, 0), Color(0.5, 0.5, 0.5)))

	# Boundary walls around the floor edge.
	var wall_color := Color(0.45, 0.45, 0.45)
	add_child(_make_box(Vector3(42, 3, 1), Vector3(0, 1.5, -20.5), wall_color))
	add_child(_make_box(Vector3(42, 3, 1), Vector3(0, 1.5, 20.5), wall_color))
	add_child(_make_box(Vector3(1, 3, 40), Vector3(-20.5, 1.5, 0), wall_color))
	add_child(_make_box(Vector3(1, 3, 40), Vector3(20.5, 1.5, 0), wall_color))

	# Building blocks scattered around the plaza.
	for pos: Vector3 in BLOCK_POSITIONS:
		add_child(_make_box(Vector3(4, 3, 4), pos, Color(0.6, 0.6, 0.62)))


# Creates a solid grey box with a collision shape and a matching mesh.
func _make_box(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)

	var mesh_inst := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_inst.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	return body


func _spawn_people() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = PEOPLE_SEED
	var placed: Array[Vector3] = []
	for i: int in range(Config.PEOPLE_COUNT):
		var pos := _find_spot(rng, placed)
		placed.append(pos)

		var p: Person = Person.new()
		p.affinity = i % 3
		p.gloom = rng.randf_range(Config.GLOOM_START_MIN, Config.GLOOM_START_MAX)
		p.position = pos
		add_child(p)
		p.rescued.connect(_on_person_rescued)
		p.relapsed.connect(_on_person_relapsed)
		people.append(p)


# Tries up to 200 random spots and returns the first one that is far enough from
# the start, the blocks and the other people. If none is found, returns the last try.
func _find_spot(rng: RandomNumberGenerator, placed: Array[Vector3]) -> Vector3:
	var candidate := Vector3.ZERO
	for attempt: int in range(200):
		candidate = Vector3(rng.randf_range(-17.0, 17.0), 0.0, rng.randf_range(-17.0, 17.0))
		if _spot_ok(candidate, placed):
			return candidate
	return candidate


func _spot_ok(p: Vector3, placed: Array[Vector3]) -> bool:
	if _flat_dist(p, Vector3.ZERO) < 3.5:
		return false
	for block: Vector3 in BLOCK_POSITIONS:
		if _flat_dist(p, block) < 3.5:
			return false
	for other: Vector3 in placed:
		if _flat_dist(p, other) < 2.5:
			return false
	return true


# Distance between two points, ignoring height.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_person_rescued() -> void:
	rescued_count += 1
	hud.set_rescued(rescued_count, Config.PEOPLE_COUNT)
	if rescued_count == Config.PEOPLE_COUNT:
		_end_round("Everyone's happy!")


func _on_person_relapsed() -> void:
	rescued_count -= 1
	hud.set_rescued(rescued_count, Config.PEOPLE_COUNT)
	hud.show_alert("Someone lost their joy!")


func _end_round(title: String) -> void:
	if not running:
		return
	running = false
	player.active = false
	Controls.set_mouse_captured(false)
	hud.set_time(time_left)
	hud.show_end(Config.buildings_for(rescued_count), title)
