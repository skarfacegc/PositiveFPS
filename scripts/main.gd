extends Node3D

const PlayerScript = preload("res://scripts/player.gd")
const PersonScript = preload("res://scripts/person.gd")
const HudScript = preload("res://scripts/hud.gd")

# Seed for the random number generator, so people appear in the same places every run.
const PEOPLE_SEED := 42

# The floor is this many tiles along each side (one metre per tile).
const TILE_COUNT := 40

# Centres of the six building blocks. Each one is 4 x 3 x 4 in size.
const BLOCK_POSITIONS := [
	Vector3(-10, 1.5, -8),
	Vector3(9, 1.5, -10),
	Vector3(-12, 1.5, 9),
	Vector3(11, 1.5, 8),
	Vector3(0, 1.5, -14),
	Vector3(0, 1.5, 12),
]

# Distance used for the gloom growth when nobody has been rescued yet (no colour zones).
const NO_ZONE_DISTANCE := 20.0

var player
var hud
var people: Array = []
var time_left := Config.ROUND_SECONDS
var rescued_count := 0
var running := true
# Painted ground: one tile per metre of floor, coloured through a MultiMesh.
var ground_mm: MultiMesh
var tile_centers: Array = []
var tile_colors: Array = []
var _paint_timer := 0.0


func _ready() -> void:
	_setup_input()
	_setup_environment()
	_build_level()
	_build_ground()

	player = PlayerScript.new()
	player.position = Vector3(0, 1, 0)
	add_child(player)

	_spawn_people()

	hud = HudScript.new()
	add_child(hud)
	player.element_changed.connect(hud.set_element)
	hud.set_element(player.current_element)
	hud.set_rescued(rescued_count, Config.PEOPLE_COUNT)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	hud.set_time(time_left)
	_update_gloom(delta)
	for p in people:
		p.tick(delta)
	_paint_timer += delta
	if _paint_timer >= Config.GROUND_UPDATE_INTERVAL:
		_paint_timer = 0.0
		_update_ground()
	if time_left <= 0.0:
		time_left = 0.0
		_end_round("Time's up!")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()


# Gloom: unrescued people darken over time (faster far from colour zones), heal inside a zone,
# and dark people spread darkness to neighbours (and drain joy from rescued ones).
func _update_gloom(delta: float) -> void:
	var zones: Array = []
	for p in people:
		if p.is_rescued:
			zones.append(p.global_position)

	for p in people:
		if p.is_rescued:
			continue
		var nearest := NO_ZONE_DISTANCE
		if not zones.is_empty():
			nearest = _nearest_distance(p.global_position, zones)
		if nearest <= Config.ZONE_RADIUS:
			p.gloom -= Config.ZONE_HEAL * delta
		else:
			p.gloom += (Config.GLOOM_GROWTH + Config.GLOOM_GROWTH_PER_METER * nearest) * delta
		p.gloom = clampf(p.gloom, 0.0, 1.0)

	for p in people:
		if p.is_rescued or Config.gloom_level(p.gloom) < Config.SPREAD_LEVEL:
			continue
		for q in people:
			if q == p:
				continue
			if _flat_dist(p.global_position, q.global_position) > Config.SPREAD_RADIUS:
				continue
			if q.is_rescued:
				q.drain_joy(Config.SPREAD_DRAIN_RATE * delta)
			else:
				q.gloom = clampf(q.gloom + Config.SPREAD_GLOOM_RATE * delta, 0.0, 1.0)


# Builds the painted ground: a grid of flat tiles just above the floor, coloured per instance.
func _build_ground() -> void:
	ground_mm = MultiMesh.new()
	ground_mm.transform_format = MultiMesh.TRANSFORM_3D
	ground_mm.use_colors = true
	ground_mm.instance_count = TILE_COUNT * TILE_COUNT
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	ground_mm.mesh = plane

	var i := 0
	for ix in range(TILE_COUNT):
		for iz in range(TILE_COUNT):
			var c := Vector3(-19.5 + ix, 0.01, -19.5 + iz)
			tile_centers.append(c)
			tile_colors.append(Config.GROUND_GREY)
			ground_mm.set_instance_transform(i, Transform3D(Basis(), c))
			ground_mm.set_instance_color(i, Config.GROUND_GREY)
			i += 1

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = ground_mm
	mmi.material_override = mat
	add_child(mmi)


# Moves each tile's colour toward its target: the nearest rescued person's element colour near them,
# otherwise plain grey. Edges are soft, and paint fades back out when people relapse.
func _update_ground() -> void:
	var rescued_people: Array = []
	for p in people:
		if p.is_rescued:
			rescued_people.append(p)

	for i in range(tile_centers.size()):
		var c: Vector3 = tile_centers[i]
		var target: Color = Config.GROUND_GREY
		var best_dist := INF
		var best_person = null
		for p in rescued_people:
			var d := _flat_dist(c, p.global_position)
			if d < best_dist:
				best_dist = d
				best_person = p
		if best_person != null and best_dist <= Config.ZONE_RADIUS:
			var k := Config.GROUND_PAINT_STRENGTH * (1.0 - smoothstep(Config.ZONE_RADIUS * 0.6, Config.ZONE_RADIUS, best_dist))
			target = Config.GROUND_GREY.lerp(Config.ELEMENT_COLORS[best_person.affinity], k)
		var current: Color = tile_colors[i]
		var next := current.lerp(target, Config.GROUND_PAINT_SPEED)
		tile_colors[i] = next
		ground_mm.set_instance_color(i, next)


# Registers the input actions in code, but only if they do not already exist.
func _setup_input() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_back", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("run", KEY_SHIFT)
	_add_key_action("jump", KEY_SPACE)
	_add_mouse_action("fire", MOUSE_BUTTON_LEFT)
	_add_key_action("element_1", KEY_1)
	_add_key_action("element_2", KEY_2)
	_add_key_action("element_3", KEY_3)
	_add_mouse_action("element_next", MOUSE_BUTTON_WHEEL_DOWN)
	_add_mouse_action("element_prev", MOUSE_BUTTON_WHEEL_UP)
	_add_key_action("restart", KEY_R)
	_add_key_action("release_mouse", KEY_ESCAPE)


func _add_key_action(action: String, keycode: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


func _add_mouse_action(action: String, button: int) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


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
	for pos in BLOCK_POSITIONS:
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
	var placed: Array = []
	for i in range(Config.PEOPLE_COUNT):
		var pos := _find_spot(rng, placed)
		placed.append(pos)

		var p = PersonScript.new()
		p.affinity = i % 3
		p.gloom = rng.randf_range(Config.GLOOM_START_MIN, Config.GLOOM_START_MAX)
		p.position = pos
		add_child(p)
		p.rescued.connect(_on_person_rescued)
		p.relapsed.connect(_on_person_relapsed)
		people.append(p)


# Tries up to 200 random spots and returns the first one that is far enough from
# the start, the blocks and the other people. If none is found, returns the last try.
func _find_spot(rng: RandomNumberGenerator, placed: Array) -> Vector3:
	var candidate := Vector3.ZERO
	for attempt in range(200):
		candidate = Vector3(rng.randf_range(-17.0, 17.0), 0.0, rng.randf_range(-17.0, 17.0))
		if _spot_ok(candidate, placed):
			return candidate
	return candidate


func _spot_ok(p: Vector3, placed: Array) -> bool:
	if _flat_dist(p, Vector3.ZERO) < 3.5:
		return false
	for block in BLOCK_POSITIONS:
		if _flat_dist(p, block) < 3.5:
			return false
	for other in placed:
		if _flat_dist(p, other) < 2.5:
			return false
	return true


# Distance between two points, ignoring height.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# Smallest flat distance from `pos` to any point in `points`.
func _nearest_distance(pos: Vector3, points: Array) -> float:
	var best := INF
	for other in points:
		best = minf(best, _flat_dist(pos, other))
	return best


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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	hud.set_time(time_left)
	hud.show_end(Config.buildings_for(rescued_count), title)
