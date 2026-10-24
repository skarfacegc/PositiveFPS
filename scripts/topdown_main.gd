class_name TopDownMain
extends Node3D

# The territory level (round 9): a bigger plaza seen from above. Rescued people form a living border around a centre
# (see border.gd). Darkness cannot cross an intact stretch of it. Inside the border the ground and the blocks are
# beautified. The light goes from dusk to dawn (night.gd); the level ends at dawn, or earlier when the landmark is held
# (win) or the border falls (lose).

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
const BLOCK_COLOUR := Color(0.6, 0.6, 0.62)

var ground: PaintedGround
var player: TopDownPlayer
var camera: Camera3D
var hud: Hud
var border: Border
var landmark: Landmark
var night: NightCycle
# The ring under the target's feet (see _update_highlight). Public so tests can check it.
var highlight: MeshInstance3D
var people: Array[Person] = []
var rescued_count: int = 0
var running: bool = true
# The F3 debug overlay: cover and protection labels above each person, and the border labels. Off by default.
var debug_on: bool = false
var _sun: DirectionalLight3D
var _env: Environment
var _obstacles: Array[StaticBody3D] = []
var _landmark_body: StaticBody3D
var _rng := RandomNumberGenerator.new()
# Wander state for each person: a Dictionary of {"target": Vector3, "timer": float}.
var _wander: Dictionary = {}
var _highlight_mat: StandardMaterial3D
var _pulse_time := 0.0
# Seconds since the cover (see _update_cover) was last worked out. It is refreshed every GROUND_UPDATE_INTERVAL.
var _cover_timer := 0.0


func _ready() -> void:
	Controls.setup()
	night = NightCycle.new()
	_setup_environment()
	_build_level()

	ground = PaintedGround.new()
	add_child(ground)
	ground.setup(Config.TD_PLAZA_SIZE, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)

	border = Border.new()
	add_child(border)
	border.setup(ground)
	for body: StaticBody3D in _obstacles:
		var is_landmark := body == _landmark_body
		border.register_building(body, Vector2(BLOCK_SIZE.x, BLOCK_SIZE.z) * 0.5, is_landmark)

	landmark = Landmark.new()
	add_child(landmark)

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
	hud.set_hint("WASD move  |  Shift run  |  Click a person to lock on  |  G/Q joy burst  |  R restart  |  M menu")
	hud.set_targeting(player.targeting_mode)
	player.target_changed.connect(hud.set_target)
	player.debug_toggled.connect(_toggle_debug)
	player.targeting_changed.connect(hud.set_targeting)
	hud.set_target(-1)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	hud.set_night_progress(0.0)


func _process(delta: float) -> void:
	_update_camera()
	_update_highlight(delta)
	if not running:
		return
	night.update(delta)
	var strength := night.strength()
	hud.set_night_progress(night.progress())
	_update_light()
	border.update(people, delta, strength)
	_update_people(delta)
	_update_cover(delta)
	GloomSim.update(people, delta, Config.TD_DRAIN_MULTIPLIER, strength, border)
	for p: Person in people:
		p.tick(delta)
	ground.update_paint(people, delta)
	landmark.update(delta, border.landmark_beautified())
	hud.set_burst(player.burst_cooldown)
	if debug_on:
		_update_debug_hint()
	_check_end()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event.is_action_pressed("menu"):
		get_tree().change_scene_to_file("res://menu.tscn")


# F3: flips the debug overlay. The player reads the key and emits debug_toggled.
func _toggle_debug() -> void:
	_set_debug(not debug_on)


# Turns the F3 debug overlay on or off: cover and protection labels above each person, border labels on the line,
# and a hint on the HUD.
func _set_debug(on: bool) -> void:
	debug_on = on
	for p: Person in people:
		p.set_debug_visible(on)
	border.set_debug(on)
	hud.set_debug_on(on)
	_update_debug_hint()


func _update_debug_hint() -> void:
	hud.set_debug_text("[F3] debug: c = cover, p = protection.  " + border.debug_summary())


# Works out every person's cover and protection every GROUND_UPDATE_INTERVAL. With a border, cover is how far inside
# the loop a person is (see Border.cover_at). Before the border forms it is the paint around them (round 8 rules): a
# rescued person's cover leaves out their own paint, so only other people's paint protects them.
func _update_cover(delta: float) -> void:
	_cover_timer += delta
	if _cover_timer < Config.GROUND_UPDATE_INTERVAL:
		return
	_cover_timer = 0.0
	for p: Person in people:
		if border.active:
			p.cover = border.cover_at(p.global_position)
			p.protection = p.cover
		elif p.is_rescued:
			p.cover = ground.average_weight_excluding(p.global_position, Config.TD_COVER_RADIUS, p)
			p.protection = GloomSim.protection_for(p.cover)
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
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.7, 0.72, 0.75)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.6, 0.6, 0.6)
	_env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, 30, 0)
	_sun.shadow_enabled = true
	add_child(_sun)


# Dusk to dawn: the sun and the ambient light follow the night (see NightCycle).
func _update_light() -> void:
	_sun.light_color = night.sun_color()
	_sun.light_energy = night.sun_energy()
	_env.ambient_light_color = night.ambient_color()


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
		var block := _make_box(BLOCK_SIZE, pos, BLOCK_COLOUR)
		add_child(block)
		_obstacles.append(block)

	# The landmark: a taller block (its base on the floor), away from the start.
	var lm_pos := Config.BORDER_LANDMARK_POS
	_landmark_body = _make_box(
		Config.BORDER_LANDMARK_SIZE,
		Vector3(lm_pos.x, Config.BORDER_LANDMARK_SIZE.y / 2.0, lm_pos.z),
		Config.BORDER_LANDMARK_COLOUR
	)
	add_child(_landmark_body)
	_obstacles.append(_landmark_body)


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
		add_child(p)
		p.rescued.connect(_on_person_rescued.bind(p))
		p.relapsed.connect(_on_person_relapsed.bind(p))
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


# True if `p` is inside any block's footprint (the landmark included), grown by `margin` metres.
func _near_block(p: Vector3, margin: float) -> bool:
	var reach := BLOCK_SIZE.x * 0.5 + margin
	for block: Vector3 in BLOCK_POSITIONS:
		if absf(p.x - block.x) < reach and absf(p.z - block.z) < reach:
			return true
	var lm := Config.BORDER_LANDMARK_POS
	return absf(p.x - lm.x) < reach and absf(p.z - lm.z) < reach


# Moves every unrescued person for this frame. Dark people drift toward the rescued person they are assigned to
# (see pursuit_assignments). A dark person with nobody to chase drifts to the nearest territory edge, and everyone
# else wanders. Everyone also steers away from close neighbours (_separation). Rescued people are moved by the border.
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


# Works out which rescued person each dark person drifts toward (the weakest point). Each rescued person takes at most
# TD_MAX_PURSUERS_PER_TARGET dark people. A dark person takes the rescued person with the lowest protection within
# TD_PURSUIT_SEARCH_RADIUS (ties go to the nearer one). People are handled in array order, so the result is the same on
# every run. Returns a Dictionary of dark Person -> rescued Person. A dark person with no target is not in it.
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
# A dark person outside the border cannot cross an intact stretch: its move stops at the line (see Border.clip_move).
func _step(p: Person, dir: Vector3, speed: float, delta: float) -> void:
	var move := dir * speed * delta
	move.y = 0.0
	var next_pos: Vector3 = p.position + move
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	next_pos.x = clampf(next_pos.x, -limit, limit)
	next_pos.z = clampf(next_pos.z, -limit, limit)
	if GloomSim.is_dark(p):
		next_pos = border.clip_move(p.position, next_pos)
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


# A rescued person (`p`) was made: the border takes them in. The count goes up.
func _on_person_rescued(p: Person) -> void:
	rescued_count += 1
	border.on_rescue(p)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)


# A rescued person (`p`) relapsed: they step out of the border, and the count goes down.
func _on_person_relapsed(p: Person) -> void:
	rescued_count -= 1
	border.on_relapse(p)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	hud.show_alert("Someone lost their joy!")


# The end conditions, in order: the border falling loses, holding the landmark wins, and dawn ends the level.
func _check_end() -> void:
	if border.formed and rescued_count < Config.BORDER_MIN_PEOPLE:
		_end_round("The border fell")
	elif landmark.is_held():
		_end_round("The landmark is ours!")
	elif night.is_over():
		_end_round("Dawn")


func _end_round(title: String) -> void:
	if not running:
		return
	running = false
	player.active = false
	hud.set_night_progress(night.progress())
	hud.show_end(title, _detail_text())


# The lines on the end screen: the landmark, how much of the plaza is painted, the buildings and the rescued count.
func _detail_text() -> String:
	var held := "yes" if landmark.is_held() else "no"
	var plaza := roundi(ground.beautified_fraction() * 100.0)
	return (
		"Landmark held: %s\nPlaza beautified: %d%%\nBuildings beautified: %d of %d\nPeople rescued: %d"
		% [held, plaza, border.beautified_building_count(), border.buildings.size(), rescued_count]
	)
