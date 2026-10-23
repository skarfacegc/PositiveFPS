extends CharacterBody3D

# The player in top-down mode. WASD moves in world space, the mouse picks the aim point on the floor,
# and joy fires automatically at a nearby person. Hits are instant; the projectiles are only visual.

signal element_changed(element: int)

const JoyProjectileScript = preload("res://scripts/joy_projectile.gd")

var current_element: int = Config.Element.MUSIC
var active := true
# Set by topdown_main.gd after both the player and the people exist.
var people: Array = []
var camera: Camera3D
# Seconds left before the joy burst can be used again. topdown_main.gd shows this on the HUD.
var burst_cooldown := 0.0

var _fire_cooldown := 0.0
var _aim_point := Vector3.ZERO
var _has_aim := false
var _ring_mat: StandardMaterial3D


func _ready() -> void:
	# Collision, same as the first-person player.
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
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.95, 0.95, 0.9)
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

	# Element ring under the feet, in the current element's colour.
	var ring := MeshInstance3D.new()
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.9
	ring_mesh.bottom_radius = 0.9
	ring_mesh.height = 0.02
	ring.mesh = ring_mesh
	ring.position = Vector3(0, 0.03, 0)
	_ring_mat = StandardMaterial3D.new()
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.albedo_color = Config.ELEMENT_COLORS[current_element]
	ring.material_override = _ring_mat
	add_child(ring)


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event.is_action_pressed("element_1"):
		_set_element(0)
	elif event.is_action_pressed("element_2"):
		_set_element(1)
	elif event.is_action_pressed("element_3"):
		_set_element(2)
	elif event.is_action_pressed("element_next"):
		_set_element((current_element + 1) % 3)
	elif event.is_action_pressed("element_prev"):
		_set_element((current_element + 2) % 3)
	elif event.is_action_pressed("burst") and burst_cooldown <= 0.0:
		_burst()


func _set_element(e: int) -> void:
	if e != current_element:
		current_element = e
		_ring_mat.albedo_color = Config.ELEMENT_COLORS[e]
		element_changed.emit(e)


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
	_auto_fire()


# Projects the mouse onto the floor (y = 0) to find the aim point.
func _update_aim() -> void:
	if camera == null:
		return
	var m := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(m)
	var dir := camera.project_ray_normal(m)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
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


# Fires at the chosen target when the cooldown is ready. The joy is applied at once.
func _auto_fire() -> void:
	if _fire_cooldown > 0.0:
		return
	var target = _pick_target()
	if target == null:
		return
	_fire_cooldown = 1.0 / Config.TD_SHOTS_PER_SECOND
	var dist := _flat_dist(global_position, target.global_position)
	target.receive_joy(current_element, Config.TD_JOY_PER_SHOT, dist)

	var pr = JoyProjectileScript.new()
	pr.element = current_element
	pr.start = global_position + Vector3(0, 1.2, 0)
	pr.end_pos = target.chest_position()
	get_parent().add_child(pr)


# Picks a target among people who can still gain joy (unrescued, or rescued but about to relapse) and are in range.
# Prefers the one closest to the aim point if they are close enough to it; otherwise the nearest one to the player.
func _pick_target():
	var best_aim = null
	var best_aim_d := INF
	var best_near = null
	var best_near_d := INF
	for p in people:
		if p.is_rescued and not p.is_warning():
			continue
		var d_player := _flat_dist(global_position, p.global_position)
		if d_player > Config.TD_AUTO_RANGE:
			continue
		if d_player < best_near_d:
			best_near_d = d_player
			best_near = p
		if _has_aim:
			var d_aim := _flat_dist(_aim_point, p.global_position)
			if d_aim < best_aim_d:
				best_aim_d = d_aim
				best_aim = p
	if best_aim != null and best_aim_d <= Config.TD_AIM_ASSIST_RADIUS:
		return best_aim
	return best_near


# Joy burst: everyone close by gets a best-match hit, then a ring expands from the player's feet.
func _burst() -> void:
	burst_cooldown = Config.TD_BURST_COOLDOWN
	for p in people:
		if _flat_dist(global_position, p.global_position) <= Config.TD_BURST_RADIUS:
			p.receive_joy(p.affinity, Config.TD_BURST_JOY, 0.0)
	_spawn_burst_ring()


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
