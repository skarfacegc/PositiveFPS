class_name ViewPipeline
extends Node

# The camera and post-process pipeline, the one switch behind the look (see Looks.mode).
#
# Placeholder: the game camera draws the 3D world straight into the window, as plain Godot does.
#
# Styled (the locked pixel look): the camera moves into a small SubViewport (about 640 x 360, the same height whatever
# the window) that shares the game's 3D world; its picture is shown full window with nearest filtering, so every pixel
# is a chunky block. A full-screen post shader on the camera draws depth and normal outlines. The sun gets its long
# warm shadows. The HUD, the minimap and the gap arrows stay in the window at full resolution (crisp).
#
# Mouse picking: the camera now lives in the small viewport, so a window mouse position is divided by view_scale()
# before it is used for a camera ray (see window_to_view; the player is given it as `mouse_mapper`), and a world point
# is multiplied by view_scale() to find its place on the window (TopDownMain.world_to_screen).

const VIEW_HEIGHT := 360
const POST_SHADER := "res://shaders/style_post.gdshader"
const STYLED_SUN_DIRECTION := Vector3(0.8, -0.5, -0.3)
const STYLED_BACKGROUND := Color(0.58, 0.63, 0.72)
const STYLED_AMBIENT_ENERGY := 0.62

var styled: bool = false
var _main: TopDownMain
var _viewport: SubViewport
var _layer: CanvasLayer
var _rect: TextureRect
var _post: MeshInstance3D
var _saved: Dictionary = {}


# Switches the pipeline to the current look (Looks.mode). Called by TopDownMain at the start and on every F4.
func apply(main: TopDownMain) -> void:
	_main = main
	if Looks.is_styled():
		_enter_styled()
	else:
		_leave_styled()


# A window position as the camera sees it (its own view size).
func window_to_view(window_pos: Vector2) -> Vector2:
	return window_pos / view_scale()


# A camera view position as a window position (the opposite of window_to_view).
func view_to_window(view_pos: Vector2) -> Vector2:
	return view_pos * view_scale()


# Window pixels per view pixel (x, y). One when the camera draws at window size.
func view_scale() -> Vector2:
	if not styled or _viewport == null:
		return Vector2.ONE
	return _window_size() / Vector2(_viewport.size)


# The size of the pixel view in view pixels (the window size when the camera draws straight into it).
func view_size() -> Vector2i:
	if styled and _viewport != null:
		return _viewport.size
	return Vector2i(_window_size())


func _process(_delta: float) -> void:
	if styled and _viewport != null:
		var want := _wanted_size()
		if want != _viewport.size:
			_viewport.size = want


func _enter_styled() -> void:
	if styled:
		return
	styled = true
	_viewport = SubViewport.new()
	_viewport.world_3d = _main.get_viewport().world_3d
	_viewport.size = _wanted_size()
	_viewport.msaa_3d = Viewport.MSAA_DISABLED
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	# The camera now draws into the small viewport.
	var cam := _main.camera
	_saved["near"] = cam.near
	_saved["far"] = cam.far
	cam.reparent(_viewport, false)
	cam.near = 0.1
	cam.far = 200.0
	cam.current = true
	_post = _make_post()
	cam.add_child(_post)
	# Show it in the window under the HUD, scaled up with no smoothing.
	_layer = CanvasLayer.new()
	_layer.layer = -1
	add_child(_layer)
	_rect = TextureRect.new()
	_rect.texture = _viewport.get_texture()
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_rect)
	_main.get_viewport().disable_3d = true
	_main.player.mouse_mapper = window_to_view
	_style_light()


func _leave_styled() -> void:
	if not styled:
		return
	styled = false
	_main.player.mouse_mapper = Callable()
	_main.get_viewport().disable_3d = false
	var cam := _main.camera
	cam.remove_child(_post)
	_post.queue_free()
	_post = null
	cam.reparent(_main, false)
	cam.near = _saved["near"]
	cam.far = _saved["far"]
	cam.current = true
	remove_child(_layer)
	_layer.queue_free()
	remove_child(_viewport)
	_viewport.queue_free()
	_viewport = null
	_restore_light()


func _make_post() -> MeshInstance3D:
	var mat := ShaderMaterial.new()
	mat.shader = load(POST_SHADER)
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# Warm directional light with long soft shadows, a cool sky and the style's ambient light.
func _style_light() -> void:
	var sun := _main.sun_light()
	var env := _main.environment()
	_saved["sun_basis"] = sun.transform.basis
	_saved["shadow_mode"] = sun.directional_shadow_mode
	_saved["shadow_distance"] = sun.directional_shadow_max_distance
	_saved["shadow_bias"] = sun.shadow_bias
	_saved["shadow_normal_bias"] = sun.shadow_normal_bias
	_saved["shadow_blur"] = sun.shadow_blur
	_saved["background"] = env.background_color
	_saved["ambient_energy"] = env.ambient_light_energy
	sun.transform = Transform3D(Basis.looking_at(STYLED_SUN_DIRECTION.normalized()), sun.transform.origin)
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 70.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.6
	env.background_color = STYLED_BACKGROUND
	env.ambient_light_energy = STYLED_AMBIENT_ENERGY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR


func _restore_light() -> void:
	var sun := _main.sun_light()
	var env := _main.environment()
	var basis: Basis = _saved["sun_basis"]
	sun.transform = Transform3D(basis, sun.transform.origin)
	sun.directional_shadow_mode = _saved["shadow_mode"]
	sun.directional_shadow_max_distance = _saved["shadow_distance"]
	sun.shadow_bias = _saved["shadow_bias"]
	sun.shadow_normal_bias = _saved["shadow_normal_bias"]
	sun.shadow_blur = _saved["shadow_blur"]
	env.background_color = _saved["background"]
	env.ambient_light_energy = _saved["ambient_energy"]


func _window_size() -> Vector2:
	return _main.get_viewport().get_visible_rect().size


# VIEW_HEIGHT tall, as wide as the window's shape needs (640 for 16:9).
func _wanted_size() -> Vector2i:
	var win := _window_size()
	return Vector2i(maxi(roundi(float(VIEW_HEIGHT) * win.x / maxf(win.y, 1.0)), 1), VIEW_HEIGHT)
