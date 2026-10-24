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

var targeting_mode: int = Config.TD_TARGETING_MODE
# The person being shot at, or null. Kept between frames in lock-on and hover modes.
var target: Person = null
var active: bool = true
# Set by topdown_main.gd after both the player and the people exist.
var people: Array[Person] = []
var camera: Camera3D
# Seconds left before the joy burst can be used again. topdown_main.gd shows this on the HUD.
var burst_cooldown: float = 0.0

# The body material (round 10: saffron, a colour no person uses). Exposed so tests can check it.
var body_mat: StandardMaterial3D
var _fire_cooldown := 0.0
var _aim_point := Vector3.ZERO
var _has_aim := false
# Last mouse position from real mouse-motion events. Read by _update_aim (see _input).
var _mouse_pos := Vector2.ZERO
var _mouse_seen := false
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	# Collision: a capsule the same size as a person.
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	# Body: a white-ish capsule, with a small nose in front so facing is visible.
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.45
	body_mesh.height = 1.8
	body.mesh = body_mesh
	body.position = Vector3(0, 0.9, 0)
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Config.TD_PLAYER_COLOUR
	body.material_override = body_mat
	add_child(body)

	var nose := MeshInstance3D.new()
	var nose_mesh := BoxMesh.new()
	nose_mesh.size = Vector3(0.2, 0.2, 0.2)
	nose.mesh = nose_mesh
	nose.position = Vector3(0, 1.2, -0.5)
	var nose_mat := StandardMaterial3D.new()
	nose_mat.albedo_color = Color(0.4, 0.4, 0.42)
	nose.material_override = nose_mat
	add_child(nose)

	# Element ring under the feet: the target's element colour, or cream with no target.
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.02
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.03, 0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Config.TD_NO_TARGET_COLOR
	ring.material_override = _ring_mat
	add_child(ring)
	_build_marker()


# Round 10: the warm double ring on the ground and the soft glow under the player (a placeholder for the locked player
# art).
func _build_marker() -> void:
	for r: float in Config.TD_PLAYER_RING_RADII:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = r
		torus.outer_radius = r + Config.TD_PLAYER_RING_WIDTH
		ring.mesh = torus
		ring.position = Vector3(0, 0.035, 0)
		ring.material_override = _warm_material(Config.TD_PLAYER_RING_COLOUR)
		add_child(ring)
	var glow := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Config.TD_PLAYER_GLOW_RADIUS
	disc.bottom_radius = Config.TD_PLAYER_GLOW_RADIUS
	disc.height = 0.01
	glow.mesh = disc
	glow.position = Vector3(0, 0.02, 0)
	var glow_col := Config.TD_PLAYER_RING_COLOUR
	glow_col.a = Config.TD_PLAYER_GLOW_ALPHA
	glow.material_override = _warm_material(glow_col)
	add_child(glow)


func _warm_material(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	return mat


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
	elif event.is_action_pressed("burst") and burst_cooldown <= 0.0:
		_burst()
	elif event.is_action_pressed("toggle_debug"):
		debug_toggled.emit()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	if burst_cooldown > 0.0:
		burst_cooldown -= delta

	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_update_aim()

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	var speed: float = Config.TD_RUN_SPEED if Input.is_action_pressed("run") else Config.TD_MOVE_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	_face_aim()
	_fire_cooldown -= delta
	_update_target()
	_refresh_ring()
	_try_fire()


# Projects the mouse onto the floor (y = 0) to find the aim point.
func _update_aim() -> void:
	if camera == null:
		return
	var m: Vector2 = _mouse_pos if _mouse_seen else get_viewport().get_mouse_position()
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
	if target == null or _fire_cooldown > 0.0:
		return
	if not _in_auto_range(target):
		return
	# Round 7: the fire rate depends on the target's element (music fast, art slow). Joy per second is the same.
	_fire_cooldown = 1.0 / (Config.TD_SHOTS_PER_SECOND * Config.TD_ELEMENT_FIRE_RATE_MULT[target.affinity])
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


# Sets the ring under the player to the target's element colour, or cream with no target.
func _refresh_ring() -> void:
	if target == null:
		_ring_mat.albedo_color = Config.TD_NO_TARGET_COLOR
	else:
		_ring_mat.albedo_color = Config.ELEMENT_COLORS[target.affinity]


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


# Joy burst: everyone close by gets a best-match hit, then a ring expands from the player's feet.
func _burst() -> void:
	burst_cooldown = Config.TD_BURST_COOLDOWN
	for p: Person in people:
		if _flat_dist(global_position, p.global_position) <= Config.TD_BURST_RADIUS:
			p.receive_joy(p.affinity, Config.TD_BURST_JOY, 0.0)
	_spawn_burst_ring()
	burst_fired.emit(global_position)


func _spawn_burst_ring() -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.9, 0.5, 0.6)
	ring.material_override = mat
	ring.scale = Vector3(0.1, 1.0, 0.1)
	get_parent().add_child(ring)
	ring.global_position = Vector3(global_position.x, 0.03, global_position.z)

	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(Config.TD_BURST_RADIUS, 1.0, Config.TD_BURST_RADIUS), Config.TD_BURST_TIME)
	t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_BURST_TIME)
	t.chain().tween_callback(ring.queue_free)


# Distance between two points, ignoring height.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
