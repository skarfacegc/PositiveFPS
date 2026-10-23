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
# The ring under the target's feet (see _update_highlight). Public so tests can check it.
var highlight: MeshInstance3D
var people: Array[Person] = []
var time_left: float = Config.TD_ROUND_SECONDS
var rescued_count: int = 0
var running: bool = true
# The F3 debug overlay: cover and protection labels above each person. Off by default.
var debug_on: bool = false
var _rng := RandomNumberGenerator.new()
# Wander state for each person: a Dictionary of {"target": Vector3, "timer": float}.
var _wander: Dictionary = {}
var _highlight_mat: StandardMaterial3D
var _pulse_time := 0.0
# Seconds since the cover (see _update_cover) was last worked out. It is refreshed every GROUND_UPDATE_INTERVAL.
var _cover_timer := 0.0


func _ready() -> void:
	Controls.setup()
	Controls.set_mouse_captured(false)
	_setup_environment()
	_build_level()

	ground = PaintedGround.new()
	add_child(ground)
	ground.setup(Config.TD_PLAZA_SIZE, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)

	player = TopDownPlayer.new()
	add_child(player)

	camera = Camera3D.new()
	camera.current = true
	add_child(camera)
	player.camera = camera

	_spawn_people()
	player.people = people
	_build_highlight()

	hud = Hud.new()
	add_child(hud)
	hud.set_crosshair_visible(false)
	hud.set_hint("WASD move  |  Shift run  |  Click a person to lock on  |  G/Q joy burst  |  R restart  |  M menu")
	hud.set_targeting(player.targeting_mode)
	player.target_changed.connect(hud.set_target)
	player.debug_toggled.connect(_toggle_debug)
	player.targeting_changed.connect(hud.set_targeting)
	hud.set_target(-1)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)


func _process(delta: float) -> void:
	_update_camera()
	_update_highlight(delta)
	if not running:
		return
	time_left -= delta
	hud.set_time(time_left)
	_update_people(delta)
	_update_cover(delta)
	GloomSim.update(people, delta, Config.TD_DRAIN_MULTIPLIER, true)
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


# F3: flips the debug overlay. The player reads the key and emits debug_toggled.
func _toggle_debug() -> void:
	_set_debug(not debug_on)


# Turns the F3 debug overlay on or off: a cover and protection label above each person, and a hint on the HUD.
func _set_debug(on: bool) -> void:
	debug_on = on
	for p: Person in people:
		p.set_debug_visible(on)
	hud.set_debug_on(on)


# Works out every person's cover and protection from the painted ground around them, every GROUND_UPDATE_INTERVAL.
# Cover is the average paint weight within TD_COVER_RADIUS; protection is derived from it (see GloomSim).
# Round 8: a rescued person's cover leaves out their own paint, so only other people's paint protects them.
func _update_cover(delta: float) -> void:
	_cover_timer += delta
	if _cover_timer < Config.GROUND_UPDATE_INTERVAL:
		return
	_cover_timer = 0.0
	for p: Person in people:
		if p.is_rescued:
			p.cover = ground.average_weight_excluding(p.global_position, Config.TD_COVER_RADIUS, p)
		else:
			p.cover = ground.average_weight(p.global_position, Config.TD_COVER_RADIUS)
		p.protection = GloomSim.protection_for(p.cover)


# The camera sits above and behind the player and always looks at them.
func _update_camera() -> void:
	var target: Vector3 = player.global_position
	camera.global_position = target + Vector3(0, Config.TD_CAMERA_HEIGHT, Config.TD_CAMERA_BACK)
	camera.look_at(target, Vector3.UP)


# Builds the target highlight: a flat warm ring that is shown under the target, hidden when there is none.
func _build_highlight() -> void:
	highlight = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = Config.TD_HIGHLIGHT_RADIUS
	mesh.bottom_radius = Config.TD_HIGHLIGHT_RADIUS
	mesh.height = 0.02
	highlight.mesh = mesh
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = Config.TD_HIGHLIGHT_COLOR
	highlight.material_override = _highlight_mat
	highlight.visible = false
	add_child(highlight)


# Moves the highlight to the target's feet and pulses it slowly. Hidden while there is no valid target.
func _update_highlight(delta: float) -> void:
	_pulse_time += delta
	if not is_instance_valid(player.target):
		highlight.visible = false
		return
	var t: Person = player.target
	highlight.visible = true
	highlight.global_position = Vector3(t.global_position.x, 0.03, t.global_position.z)
	var s := 1.0 + Config.TD_HIGHLIGHT_PULSE * sin(_pulse_time * Config.TD_HIGHLIGHT_PULSE_SPEED)
	highlight.scale = Vector3(s, 1.0, s)


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
		p.grace_seconds = Config.TD_RESCUE_GRACE_SECONDS
		p.use_cover = true
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


# Moves every unrescued person for this frame. Dark people drift toward the rescued person they are assigned to
# (see pursuit_assignments). A dark person with nobody to chase drifts to the nearest territory edge, and everyone
# else wanders. Everyone also steers away from close neighbours (_separation).
func _update_people(delta: float) -> void:
	var pursuit: Dictionary = pursuit_assignments(people)
	for p: Person in people:
		if p.is_rescued:
			continue
		if pursuit.has(p):
			var target_p: Person = pursuit[p]
			var to: Vector3 = target_p.global_position - p.global_position
			to.y = 0.0
			var desired := Vector3.ZERO
			if to.length() > Config.TD_DARK_STOP_DISTANCE:
				desired = to.normalized()
			_steer(p, desired, Config.TD_DARK_DRIFT_SPEED, delta)
		elif GloomSim.is_dark(p) and ground.has_edge():
			var to_edge: Vector3 = ground.nearest_edge_point(p.global_position) - p.global_position
			to_edge.y = 0.0
			var edge_desired := Vector3.ZERO
			if to_edge.length() > Config.TD_EDGE_REACH:
				edge_desired = to_edge.normalized()
			_steer(p, edge_desired, Config.TD_DARK_DRIFT_SPEED, delta)
		else:
			_steer(p, _wander_dir(p, delta), Config.TD_WANDER_SPEED, delta)


# Works out which rescued person each dark person drifts toward (round 8: the weakest point). Each rescued person
# takes at most TD_MAX_PURSUERS_PER_TARGET dark people. A dark person takes the rescued person with the lowest
# protection within TD_PURSUIT_SEARCH_RADIUS (ties go to the nearer one). People are handled in array order, so the
# result is the same on every run. Returns a Dictionary of dark Person -> rescued Person. A dark person with no
# target is not in it (see _update_people).
func pursuit_assignments(list: Array[Person]) -> Dictionary:
	var rescued_list: Array[Person] = []
	for p: Person in list:
		if p.is_rescued:
			rescued_list.append(p)
	var slots: Dictionary = {}
	var out: Dictionary = {}
	for p: Person in list:
		if not GloomSim.is_dark(p):
			continue
		var best := _weakest_with_slot(p.global_position, rescued_list, slots)
		if best != null:
			out[p] = best
			var used: int = slots.get(best, 0)
			slots[best] = used + 1
	return out


# The rescued person a dark person at `pos` goes for: the lowest protection within TD_PURSUIT_SEARCH_RADIUS that
# still has a free pursuer slot (see pursuit_assignments). Ties go to the nearest. Null if there is none.
func _weakest_with_slot(pos: Vector3, rescued_list: Array[Person], slots: Dictionary) -> Person:
	var best: Person = null
	var best_d := INF
	for r: Person in rescued_list:
		var used: int = slots.get(r, 0)
		if used >= Config.TD_MAX_PURSUERS_PER_TARGET:
			continue
		var d := _flat_dist(pos, r.global_position)
		if d > Config.TD_PURSUIT_SEARCH_RADIUS:
			continue
		if best == null or r.protection < best.protection or (r.protection == best.protection and d < best_d):
			best = r
			best_d = d
	return best


# Returns the flat direction a wandering person walks in this frame, or zero if they are standing still.
# They pick a new spot when they arrive or their time is up.
func _wander_dir(p: Person, delta: float) -> Vector3:
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
		return to.normalized()
	return Vector3.ZERO


# Moves a person along `desired` (a flat direction, or zero to stand still) plus the push away from neighbours.
# The push is added before normalising, so the step is always speed * delta long and the speed cap holds.
func _steer(p: Person, desired: Vector3, speed: float, delta: float) -> void:
	var want := desired + _separation(p) * Config.TD_SEPARATION_STRENGTH
	want.y = 0.0
	if want.length() < 0.001:
		return
	_step(p, want.normalized(), speed, delta)


# The push away from each person within TD_SEPARATION_RADIUS: one unit of push per neighbour, away from it. A constant
# push (not a falloff) is stronger than a wander step, so people settle at about the radius apart instead of drifting
# back together. Two people standing exactly on the same spot are split by array order: the earlier one is pushed
# right, the later one left.
func _separation(p: Person) -> Vector3:
	var push := Vector3.ZERO
	var my_index := people.find(p)
	for i: int in range(people.size()):
		var q: Person = people[i]
		if q == p:
			continue
		var diff: Vector3 = p.global_position - q.global_position
		diff.y = 0.0
		var d := diff.length()
		if d >= Config.TD_SEPARATION_RADIUS:
			continue
		if d < 0.001:
			diff = Vector3.RIGHT if my_index < i else Vector3.LEFT
		push += diff.normalized()
	return push


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
