class_name CameraRig
extends RefCounted

# The level's view: the environment and sun (dusk to dawn), the orthographic camera that follows the player, and the
# wheel zoom. TopDownMain builds it as `camera_rig` and keeps the camera in `main.camera`.

var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
# Round 14: the wheel zoom. The ortho size the camera is easing toward, and the frame the last zoom step was taken (the
# key press can arrive twice in one frame, see Known gotchas).
var zoom_target: float = PlayerConfig.TD_CAMERA_ORTHO_SIZE
var _zoom_frame: int = -1
# The ortho size the label scales were last set for (they are only rewritten when the zoom moves).
var _scaled_for_size: float = -1.0
var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


func setup_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.7, 0.72, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = env
	_main.add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	_main.add_child(sun)


# Dusk to dawn: the sun and the ambient light follow the night (see NightCycle).
func update_light() -> void:
	sun.light_color = _main.night.sun_color()
	sun.light_energy = _main.night.sun_energy()
	env.ambient_light_color = _main.night.ambient_color()


# Makes the camera and gives it to the level (`main.camera`).
func build() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = PlayerConfig.TD_CAMERA_ORTHO_SIZE
	camera.current = true
	_main.add_child(camera)
	_main.camera = camera


# One wheel notch per frame (a repeated delivery in the same frame counts once).
func handle_zoom(event: InputEvent) -> void:
	var frame := Engine.get_process_frames()
	if frame != _zoom_frame:
		_zoom_frame = frame
		var step := -PlayerConfig.TD_ZOOM_STEP if event.is_action_pressed("zoom_in") else PlayerConfig.TD_ZOOM_STEP
		zoom_target = clampf(zoom_target + step, PlayerConfig.TD_ZOOM_MIN, PlayerConfig.TD_ZOOM_MAX)


# The camera follows the player from above and behind, looking at a point just north of them (round 10: orthographic, at
# TD_CAMERA_PITCH_DEG degrees, so the player sits a little below the centre of the screen). Round 14: the ortho size
# eases toward the wheel's target, and the labels and the look offset scale with it (so they look the same on screen).
func update(delta: float) -> void:
	var size := lerpf(camera.size, zoom_target, 1.0 - exp(-PlayerConfig.TD_ZOOM_EASE * delta))
	if size != camera.size:
		camera.size = size
	if camera.size != _scaled_for_size:
		_scaled_for_size = camera.size
		var zoom := camera.size / PlayerConfig.TD_CAMERA_ORTHO_SIZE
		for p: Person in _main.people:
			p.set_ui_scale(PlayerConfig.TD_UI_SCALE * zoom)
	var target := view_centre()
	var pitch := deg_to_rad(PlayerConfig.TD_CAMERA_PITCH_DEG)
	var d := PlayerConfig.TD_CAMERA_DISTANCE
	camera.global_position = target + Vector3(0, d * sin(pitch), d * cos(pitch))
	camera.look_at(target, Vector3.UP)


# The point the camera looks at: the player plus TD_CAMERA_LOOK_OFFSET, scaled with the zoom (the player keeps the same
# place on screen at every zoom).
func view_centre() -> Vector3:
	return (
		_main.player.global_position
		+ PlayerConfig.TD_CAMERA_LOOK_OFFSET * (camera.size / PlayerConfig.TD_CAMERA_ORTHO_SIZE)
	)


# The half size of the camera's view on the ground, in metres: x across the screen, z along the ground (the view is
# tilted, so the depth is stretched by 1 / sin(pitch)).
func view_half_extents() -> Vector2:
	var screen := _main.get_viewport().get_visible_rect().size
	var aspect := screen.x / screen.y
	var pitch := deg_to_rad(PlayerConfig.TD_CAMERA_PITCH_DEG)
	return Vector2(camera.size * aspect * 0.5, camera.size * 0.5 / sin(pitch))
