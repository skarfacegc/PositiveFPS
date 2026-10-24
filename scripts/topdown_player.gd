class_name TopDownPlayer
extends CharacterBody3D

# The player in top-down mode. WASD moves in world space and the mouse picks an aim point on the floor. The player
# picks a target (how depends on the targeting mode, see Config.TargetingMode) and fires physical joy projectiles at
# it. Every shot uses the target's own element, so there is no element switching here.

# Emitted when the target changes. The argument is the target's affinity, or -1 when there is no target.
signal target_changed(affinity: int)
# Emitted when F2 cycles the targeting mode (the argument is the new mode).
signal targeting_changed(mode: int)
# Emitted when F3 is pressed. The level toggles its debug overlay.
signal debug_toggled
# Emitted when the joy burst is used, with the player's position (the border shoves toward it).
signal burst_fired(at: Vector3)
# Emitted when the player goes dim (spirit reached 0) and when they leave it again.
signal dim_changed(is_dim: bool)

var targeting_mode: int = Config.TD_TARGETING_MODE
# The person being shot at, or null. Kept between frames in lock-on and hover modes.
var target: Person = null
var active: bool = true
# Set by topdown_main.gd after both the player and the people exist.
var people: Array[Person] = []
var camera: Camera3D
# Seconds left before the joy burst can be used again. topdown_main.gd shows this on the HUD.
var burst_cooldown: float = 0.0
# Round 12a: spirit (0..SPIRIT_MAX) and the dim state (spirit hit 0; it ends at DIM_EXIT_SPIRIT).
var spirit: float = Config.SPIRIT_START
var is_dim: bool = false
# The twirl: seconds until it can be used again, seconds of dash left, seconds since the last one began (large when
# there has not been one), and where it began.
var twirl_cooldown: float = 0.0
var twirl_left: float = 0.0
var twirl_age: float = 99.0
var twirl_from := Vector3.ZERO

# The look: draws the body and the ring under the feet from this state (see scripts/looks/player_look.gd).
var look: PlayerLook
# Turns a window mouse position into the camera's own view coordinates. Empty (the default) when the camera renders
# at window size. The styled look renders the 3D view smaller (see ViewPipeline.window_to_view) and sets this.
var mouse_mapper: Callable = Callable()
var _twirl_dir := Vector3.ZERO
var _fire_cooldown := 0.0
var _aim_point := Vector3.ZERO
var _has_aim := false
# Last mouse position from real mouse-motion events. Read by _update_aim (see _input).
var _mouse_pos := Vector2.ZERO
var _mouse_seen := false


func _ready() -> void:
	# Collision: a capsule the same size as a person.
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	look = Looks.player_look()
	add_child(look)
	look.setup(self)


# Swaps the look in place (F4).
func rebuild_look() -> void:
	if look != null:
		remove_child(look)
		look.queue_free()
	look = Looks.player_look()
	add_child(look)
	look.setup(self)
	look.sync()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_mouse_pos = motion.position
		_mouse_seen = true


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event.is_action_pressed("cycle_targeting"):
		_cycle_targeting()
	elif event.is_action_pressed("fire") and targeting_mode == Config.TargetingMode.LOCK_ON:
		_click_lock()
	elif event.is_action_pressed("burst") and can_burst():
		_burst()
	elif event.is_action_pressed("twirl"):
		_twirl()
	elif event.is_action_pressed("toggle_debug"):
		debug_toggled.emit()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if burst_cooldown > 0.0:
		burst_cooldown -= delta
	twirl_age += delta
	if twirl_cooldown > 0.0:
		twirl_cooldown = maxf(0.0, twirl_cooldown - delta)

	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_update_aim()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	var speed: float = Config.TD_RUN_SPEED if Input.is_action_pressed("run") else Config.TD_MOVE_SPEED
	if is_dim:
		speed *= Config.DIM_MOVE_MULT
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if twirl_left > 0.0:
		# The dash replaces walking: TWIRL_DISTANCE metres over TWIRL_TIME seconds (the last step may be shorter).
		var step := minf(delta, twirl_left)
		var dash := _twirl_dir * (Config.TWIRL_DISTANCE / Config.TWIRL_TIME) * (step / delta)
		velocity.x = dash.x
		velocity.z = dash.z
		twirl_left -= step
	move_and_slide()

	_face_aim()
	_fire_cooldown -= delta
	_update_target()
	look.sync()
	_try_fire()


# Projects the mouse onto the floor (y = 0) to find the aim point.
func _update_aim() -> void:
	if camera == null:
		return
	var m: Vector2 = _mouse_pos if _mouse_seen else get_viewport().get_mouse_position()
	if mouse_mapper.is_valid():
		m = mouse_mapper.call(m)
	var from := camera.project_ray_origin(m)
	var dir := camera.project_ray_normal(m)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	_has_aim = hit != null
	if _has_aim:
		_aim_point = hit


# Turns the player (yaw only) to face the aim point.
func _face_aim() -> void:
	if not _has_aim:
		return
	var to: Vector3 = _aim_point - global_position
	if Vector2(to.x, to.z).length() < 0.01:
		return
	rotation.y = atan2(-to.x, -to.z)


# F2: move to the next targeting mode. The current target is dropped so every mode starts clean.
func _cycle_targeting() -> void:
	targeting_mode = (targeting_mode + 1) % Config.TD_TARGETING_NAMES.size()
	_set_target(null)
	targeting_changed.emit(targeting_mode)


# Lock-on click: lock the valid person nearest the mouse ground point. Clicking empty ground clears the lock.
func _click_lock() -> void:
	_update_aim()
	if not _has_aim:
		return
	_set_target(_nearest_valid(_aim_point, Config.TD_CLICK_RADIUS))


# Keeps the target in step with the mode, and drops it when it is no longer valid.
func _update_target() -> void:
	if not is_instance_valid(target):
		_set_target(null)
	if targeting_mode == Config.TargetingMode.AUTO:
		_set_target(_most_urgent())
		return
	if target != null and not _can_keep(target):
		_set_target(null)
	if targeting_mode == Config.TargetingMode.HOVER_STICKY and target == null and _has_aim:
		_set_target(_nearest_valid(_aim_point, Config.TD_AIM_ASSIST_RADIUS))


# Fires one shot at the target when the cooldown is ready and the target is in range. Notes, paint and flowers are all
# fired the same way; the element is the target's affinity, so every shot is a best match.
func _try_fire() -> void:
	if is_dim or target == null or _fire_cooldown > 0.0:
		return
	if not _in_auto_range(target):
		return
	# Round 7: the fire rate depends on the target's element (music fast, art slow). Joy per second is the same.
	_fire_cooldown = (
		1.0 / (Config.TD_SHOTS_PER_SECOND * Config.TD_ELEMENT_FIRE_RATE_MULT[target.affinity] * fire_rate_mult())
	)
	var start := global_position + Vector3(0, 1.2, 0)
	var pr := JoyProjectile.new()
	pr.element = target.affinity
	pr.target = target
	pr.people = people
	pr.shooter_pos = global_position
	pr.ignore_rids = [get_rid()]
	pr.velocity = JoyProjectile.launch_velocity(pr.element, start, target.chest_position())
	get_parent().add_child(pr)
	pr.global_position = start


func _set_target(p: Person) -> void:
	if p == target:
		return
	target = p
	target_changed.emit(-1 if p == null else p.affinity)


# True when a person can still gain joy: unrescued, or rescued but losing joy (about to relapse).
func _is_eligible(p: Person) -> bool:
	return not p.is_rescued or p.is_warning()


# A valid target: eligible and within auto range of the player.
func _is_valid_target(p: Person) -> bool:
	return _is_eligible(p) and _in_auto_range(p)


func _in_auto_range(p: Person) -> bool:
	return _flat_dist(global_position, p.global_position) <= Config.TD_AUTO_RANGE


# A held target stays while it is eligible and inside the lock break range.
func _can_keep(p: Person) -> bool:
	return _is_eligible(p) and _flat_dist(global_position, p.global_position) <= Config.TD_LOCK_BREAK_RANGE


# The valid person nearest `point` within `radius` metres of it, or null.
func _nearest_valid(point: Vector3, radius: float) -> Person:
	var best: Person = null
	var best_d := INF
	for p: Person in people:
		if not is_instance_valid(p) or not _is_valid_target(p):
			continue
		var d := _flat_dist(point, p.global_position)
		if d <= radius and d < best_d:
			best_d = d
			best = p
	return best


# AUTO: rescued-and-warning people first, then the darkest, then the nearest.
func _most_urgent() -> Person:
	var best: Person = null
	for p: Person in people:
		if not is_instance_valid(p) or not _is_valid_target(p):
			continue
		if best == null or _more_urgent(p, best):
			best = p
	return best


# True if `a` should be shot at before `b` (see _most_urgent).
func _more_urgent(a: Person, b: Person) -> bool:
	if a.is_rescued != b.is_rescued:
		return a.is_rescued
	var level_a := Config.gloom_level(a.gloom)
	var level_b := Config.gloom_level(b.gloom)
	if level_a != level_b:
		return level_a > level_b
	return _flat_dist(global_position, a.global_position) < _flat_dist(global_position, b.global_position)


# ---- Spirit (round 12a)
# --------------------------------------------------------------------------------------------------------------


# The joy fire rate factor from spirit: 1 at SPIRIT_FULL_FIRE_FRACTION of spirit or more, then linearly down to
# SPIRIT_MIN_FIRE_FRACTION at (just above) zero.
func fire_rate_mult() -> float:
	var frac := spirit / Config.SPIRIT_MAX
	if frac >= Config.SPIRIT_FULL_FIRE_FRACTION:
		return 1.0
	return lerpf(Config.SPIRIT_MIN_FIRE_FRACTION, 1.0, frac / Config.SPIRIT_FULL_FIRE_FRACTION)


# True when the burst is ready, the player is not dim and spirit covers its cost.
func can_burst() -> bool:
	return burst_cooldown <= 0.0 and has_burst_spirit()


# True when spirit covers the burst (and the player is not dim).
func has_burst_spirit() -> bool:
	return not is_dim and spirit >= Config.BURST_SPIRIT_COST


func add_spirit(amount: float) -> void:
	_set_spirit(spirit + amount)


func lose_spirit(amount: float) -> void:
	_set_spirit(spirit - amount)


# 0 when not dim, up to 1 at spirit 0: how grey the player is drawn.
func dim_level() -> float:
	if not is_dim:
		return 0.0
	return 1.0 - clampf(spirit / Config.DIM_EXIT_SPIRIT, 0.0, 1.0)


# Sets spirit (clamped) and updates the dim state: dim at 0, back to normal at DIM_EXIT_SPIRIT.
func _set_spirit(value: float) -> void:
	spirit = clampf(value, 0.0, Config.SPIRIT_MAX)
	var was_dim := is_dim
	if spirit <= 0.0:
		is_dim = true
	elif is_dim and spirit >= Config.DIM_EXIT_SPIRIT:
		is_dim = false
	if is_dim != was_dim:
		dim_changed.emit(is_dim)
		if look != null:
			look.sync()


# ---- Twirl (round 12a)
# --------------------------------------------------------------------------------------------------------------


func is_twirling() -> bool:
	return twirl_left > 0.0


# Space: dash TWIRL_DISTANCE metres in the move direction (or the facing direction when standing still).
func _twirl() -> void:
	if twirl_cooldown > 0.0 or twirl_left > 0.0:
		return
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length() < 0.01:
		dir = -global_transform.basis.z
		dir.y = 0.0
	_twirl_dir = dir.normalized()
	twirl_from = global_position
	twirl_left = Config.TWIRL_TIME
	twirl_age = 0.0
	twirl_cooldown = Config.TWIRL_COOLDOWN


# The small joy burst of a perfect twirl: radius TWIRL_BURST_RADIUS, a fraction of the normal burst joy, free.
func mini_burst() -> void:
	for p: Person in people:
		if _flat_dist(global_position, p.global_position) <= Config.TWIRL_BURST_RADIUS:
			p.receive_joy(p.affinity, Config.TD_BURST_JOY * Config.TWIRL_BURST_JOY_FRACTION, 0.0)
	look.play_burst(Config.TWIRL_BURST_RADIUS, Config.TD_BURST_TIME)


# Joy burst: everyone close by gets a best-match hit, then a ring expands from the player's feet. It costs spirit.
func _burst() -> void:
	burst_cooldown = Config.TD_BURST_COOLDOWN
	lose_spirit(Config.BURST_SPIRIT_COST)
	for p: Person in people:
		if _flat_dist(global_position, p.global_position) <= Config.TD_BURST_RADIUS:
			p.receive_joy(p.affinity, Config.TD_BURST_JOY, 0.0)
	_spawn_burst_ring()
	burst_fired.emit(global_position)


func _spawn_burst_ring() -> void:
	look.play_burst(Config.TD_BURST_RADIUS, Config.TD_BURST_TIME)


# Distance between two points, ignoring height.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
