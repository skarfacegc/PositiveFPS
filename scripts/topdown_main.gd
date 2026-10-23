class_name TopDownMain
extends Node3D

# Top-down mode: a bigger plaza seen from above. Aiming is mostly automatic;
# you choose where to stand and which element to use.

# Obstacle blocks are 4 x 2 x 4. Their centres are fixed, within +-25, and the middle stays clear.
const BLOCK_SIZE := Vector3(4, 2, 4)
const BLOCK_POSITIONS: Array[Vector3] = [
	Vector3(-20, 1, -18),
	Vector3(-6, 1, -22),
	Vector3(12, 1, -20),
	Vector3(22, 1, -12),
	Vector3(-22, 1, -2),
	Vector3(20, 1, 4),
	Vector3(-14, 1, 12),
	Vector3(4, 1, 14),
	Vector3(18, 1, 20),
	Vector3(-6, 1, 24),
]

var ground: PaintedGround
var player: TopDownPlayer
var camera: Camera3D
var hud: Hud
var people: Array[Person] = []
var time_left: float = Config.TD_ROUND_SECONDS
var rescued_count: int = 0
var running: bool = true
var _rng := RandomNumberGenerator.new()
# Wander state for each person: a Dictionary of {"target": Vector3, "timer": float}.
var _wander: Dictionary = {}


func _ready() -> void:
	Controls.setup()
	Controls.set_mouse_captured(false)
	_setup_environment()
	_build_level()

	ground = PaintedGround.new()
	add_child(ground)
	ground.setup(Config.TD_PLAZA_SIZE)

	player = TopDownPlayer.new()
	add_child(player)

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	player.camera = camera

	_spawn_people()
	player.people = people

	hud = Hud.new()
	add_child(hud)
	hud.set_crosshair_visible(false)
	var hint := "WASD move  |  Shift run  |  1/2/3 or wheel: element  |  "
	hud.set_hint(hint + "G/Q joy burst  |  aim with mouse  |  R restart  |  M menu")
	player.element_changed.connect(hud.set_element)
	hud.set_element(player.current_element)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)


func _process(delta: float) -> void:
	_update_camera()
	if not running:
		return
	time_left -= delta
	hud.set_time(time_left)
	_update_people(delta)
	GloomSim.update(people, delta)
	for p: Person in people:
		p.tick(delta)
	ground.update_paint(people, delta)
	hud.set_burst(player.burst_cooldown)
	if time_left <= 0.0:
		time_left = 0.0
		_end_round("Time's up!")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("menu"):
		Controls.set_mouse_captured(false)
		get_tree().change_scene_to_file("res://menu.tscn")


# The camera sits above and behind the player and always looks at them.
func _update_camera() -> void:
	var target: Vector3 = player.global_position
	camera.global_position = target + Vector3(0, Config.TD_CAMERA_HEIGHT, Config.TD_CAMERA_BACK)
	camera.look_at(target, Vector3.UP)


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
	var side := float(Config.TD_PLAZA_SIZE)
	var wall_at := side / 2.0 + 0.5

	# Floor: top surface at y = 0.
	add_child(_make_box(Vector3(side, 1, side), Vector3(0, -0.5, 0), Color(0.5, 0.5, 0.5)))

	# Walls around the edge.
	var wall_color := Color(0.45, 0.45, 0.45)
	add_child(_make_box(Vector3(side + 2, 3, 1), Vector3(0, 1.5, -wall_at), wall_color))
	add_child(_make_box(Vector3(side + 2, 3, 1), Vector3(0, 1.5, wall_at), wall_color))
	add_child(_make_box(Vector3(1, 3, side + 2), Vector3(-wall_at, 1.5, 0), wall_color))
	add_child(_make_box(Vector3(1, 3, side + 2), Vector3(wall_at, 1.5, 0), wall_color))

	# Obstacle blocks.
	for pos: Vector3 in BLOCK_POSITIONS:
		add_child(_make_box(BLOCK_SIZE, pos, Color(0.6, 0.6, 0.62)))


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
	_rng.seed = Config.RNG_SEED
	var placed: Array[Vector3] = []
	for i: int in range(Config.TD_PEOPLE_COUNT):
		var pos := _find_spot(placed)
		placed.append(pos)

		var p: Person = Person.new()
		p.affinity = i % 3
		p.gloom = _rng.randf_range(Config.GLOOM_START_MIN, Config.GLOOM_START_MAX)
		p.position = pos
		p.ui_scale = Config.TD_UI_SCALE
		add_child(p)
		p.rescued.connect(_on_person_rescued)
		p.relapsed.connect(_on_person_relapsed)
		people.append(p)


# Tries up to 200 random spots inside the plaza and returns the first that is clear of the
# centre, the blocks and the other people. If none is found, returns the last try.
func _find_spot(placed: Array[Vector3]) -> Vector3:
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_SPAWN_EDGE
	var candidate := Vector3.ZERO
	for attempt: int in range(200):
		candidate = Vector3(_rng.randf_range(-limit, limit), 0.0, _rng.randf_range(-limit, limit))
		if _spot_ok(candidate, placed):
			return candidate
	return candidate


func _spot_ok(p: Vector3, placed: Array[Vector3]) -> bool:
	if _flat_dist(p, Vector3.ZERO) < Config.TD_SPAWN_CENTRE_CLEAR:
		return false
	if _near_block(p, Config.TD_BLOCK_CLEARANCE):
		return false
	for other: Vector3 in placed:
		if _flat_dist(p, other) < Config.TD_SPAWN_SPACING:
			return false
	return true


# True if `p` is inside any block's footprint, grown by `margin` metres.
func _near_block(p: Vector3, margin: float) -> bool:
	var reach := BLOCK_SIZE.x * 0.5 + margin
	for block: Vector3 in BLOCK_POSITIONS:
		if absf(p.x - block.x) < reach and absf(p.z - block.z) < reach:
			return true
	return false


# Moves every person for this frame. Dark people drift toward rescued people; everyone else wanders.
func _update_people(delta: float) -> void:
	var rescued_list: Array[Person] = []
	for p: Person in people:
		if p.is_rescued:
			rescued_list.append(p)

	for p: Person in people:
		var dark: bool = not p.is_rescued and Config.gloom_level(p.gloom) >= Config.SPREAD_LEVEL
		if dark:
			var target_p: Person = _nearest_person(p.global_position, rescued_list)
			if target_p != null:
				var to: Vector3 = target_p.global_position - p.global_position
				to.y = 0.0
				if to.length() > Config.TD_DARK_STOP_DISTANCE:
					_step(p, to.normalized(), Config.TD_DARK_DRIFT_SPEED, delta)
				continue
		_wander_step(p, delta)


# Returns the nearest person in `list` to `pos`, or null if the list is empty.
func _nearest_person(pos: Vector3, list: Array[Person]) -> Person:
	var best: Person = null
	var best_d := INF
	for q: Person in list:
		var d := _flat_dist(pos, q.global_position)
		if d < best_d:
			best_d = d
			best = q
	return best


# Walks a person toward a wander target. When they arrive, or their time is up, they pick a new one.
func _wander_step(p: Person, delta: float) -> void:
	if not _wander.has(p):
		_wander[p] = {"target": p.global_position, "timer": 0.0}
	var st: Dictionary = _wander[p]
	st["timer"] = st["timer"] - delta
	var here: Vector3 = p.global_position
	var to: Vector3 = st["target"] - here
	to.y = 0.0
	if st["timer"] <= 0.0 or to.length() <= Config.TD_WANDER_REACH:
		st["target"] = _new_wander_target(here)
		st["timer"] = _rng.randf_range(Config.TD_WANDER_TIME_MIN, Config.TD_WANDER_TIME_MAX)
		to = st["target"] - here
		to.y = 0.0
	if to.length() > 0.01:
		_step(p, to.normalized(), Config.TD_WANDER_SPEED, delta)


# Picks a random spot within TD_WANDER_RANGE of `from`, inside the plaza and clear of blocks.
func _new_wander_target(from: Vector3) -> Vector3:
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	for attempt: int in range(10):
		var angle := _rng.randf() * TAU
		var dist := _rng.randf() * Config.TD_WANDER_RANGE
		var c := from + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		c.x = clampf(c.x, -limit, limit)
		c.z = clampf(c.z, -limit, limit)
		if not _near_block(c, Config.TD_BLOCK_CLEARANCE):
			return c
	return from


# Moves a person along a flat direction, keeping them inside the plaza and out of blocks, and turns them to face it.
func _step(p: Person, dir: Vector3, speed: float, delta: float) -> void:
	var move := dir * speed * delta
	move.y = 0.0
	var next_pos: Vector3 = p.position + move
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	next_pos.x = clampf(next_pos.x, -limit, limit)
	next_pos.z = clampf(next_pos.z, -limit, limit)
	if _near_block(next_pos, Config.TD_BLOCK_CLEARANCE):
		# Blocked: make a wanderer choose a new target next time.
		if _wander.has(p):
			_wander[p]["timer"] = 0.0
		return
	p.position = next_pos
	p.look_at(next_pos + Vector3(dir.x, 0.0, dir.z), Vector3.UP)


# Distance between two points, ignoring height.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _on_person_rescued() -> void:
	rescued_count += 1
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	if rescued_count == Config.TD_PEOPLE_COUNT:
		_end_round("Everyone's happy!")


func _on_person_relapsed() -> void:
	rescued_count -= 1
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	hud.show_alert("Someone lost their joy!")


func _end_round(title: String) -> void:
	if not running:
		return
	running = false
	player.active = false
	Controls.set_mouse_captured(false)
	hud.set_time(time_left)
	hud.show_end(Config.buildings_for(rescued_count, Config.TD_BUILDING_THRESHOLDS), title)
