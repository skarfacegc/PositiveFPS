extends CharacterBody3D

signal element_changed(element: int)

var current_element: int = Config.Element.MUSIC
var active := true
var _cooldown := 0.0
var camera: Camera3D
var beam: MeshInstance3D
var _beam_mesh: BoxMesh
var _beam_mat: StandardMaterial3D


func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.6, 0)
	camera.current = true
	add_child(camera)

	# The beam is a thin box that is shown for a moment after each shot.
	beam = MeshInstance3D.new()
	_beam_mesh = BoxMesh.new()
	_beam_mesh.size = Vector3(0.04, 0.04, 1.0)
	beam.mesh = _beam_mesh
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Config.ELEMENT_COLORS[current_element]
	beam.material_override = _beam_mat
	beam.visible = false
	camera.add_child(beam)

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * Config.MOUSE_SENSITIVITY)
		camera.rotate_x(-event.relative.y * Config.MOUSE_SENSITIVITY)
		camera.rotation.x = clamp(camera.rotation.x, deg_to_rad(-85), deg_to_rad(85))
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

	if event.is_action_pressed("release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return

	# Clicking the game window again while the mouse is free captures it.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _set_element(e: int) -> void:
	if e != current_element:
		current_element = e
		element_changed.emit(e)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta

	if not active:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = Config.JUMP_VELOCITY

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
	var speed: float = Config.RUN_SPEED if Input.is_action_pressed("run") else Config.WALK_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	move_and_slide()

	_cooldown -= delta
	if Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and _cooldown <= 0.0:
		_cooldown = 1.0 / Config.SHOTS_PER_SECOND
		_fire()


func _fire() -> void:
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z) * Config.BEAM_RANGE

	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.exclude = [self.get_rid()]
	var hit := space.intersect_ray(q)

	var length: float = Config.BEAM_RANGE
	if not hit.is_empty():
		length = from.distance_to(hit.position)
		if hit.collider.has_method("receive_joy"):
			hit.collider.receive_joy(current_element, Config.JOY_PER_SHOT, length)

	# Show the beam briefly, in the element's colour.
	_beam_mesh.size = Vector3(0.04, 0.04, length)
	beam.position = Vector3(0.15, -0.15, -length / 2.0)
	_beam_mat.albedo_color = Config.ELEMENT_COLORS[current_element]
	beam.visible = true
	get_tree().create_timer(0.05).timeout.connect(func(): beam.visible = false)
