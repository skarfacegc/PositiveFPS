class_name StyleAtmosphere
extends Node3D

# Checkpoint 7 (change 5): the styled gloom atmosphere. Scenery only: it reads the night clock, held landmarks, and the
# paint-weight picture, and never writes any of them.
#
# - Mist: two flat planes of drifting low mist, thick over unpainted ground and cleared where the zone is painted
#   (shaders/style_mist.gdshader; the cold desaturated tint of the ground itself is in style_ground.gdshader).
# - Sky: cooler toward midnight, back to the dusk blue as first light begins (first light's own warm sky takes over).
# - Skyline: rooftops round the plaza in three sectors, one per landmark; a sector's rooftops light up warm as that
#   landmark is held and go back to grey when it is lost.

const MIST_SHADER := "res://shaders/style_mist.gdshader"
const PLANE_SIZE := 220.0

var _main: TopDownMain
var _mist_mats: Array[ShaderMaterial] = []
var _roof_mats: Array[StandardMaterial3D] = []
# How lit each skyline sector is (0 grey, 1 warm), eased toward whether its landmark is held.
var _lit: Array[float] = []
var _skyline: Array[MultiMeshInstance3D] = []
var _weights: Texture2D


# Builds the mist and the skyline into this node (call once, after adding the node to the level).
func build(main: TopDownMain) -> void:
	_main = main
	for i: int in range(2):
		var mat := ShaderMaterial.new()
		mat.shader = load(MIST_SHADER)
		mat.set_shader_parameter("plaza", float(Config.TD_PLAZA_SIZE))
		mat.set_shader_parameter("strength", StyleConfig.CP7_MIST_STRENGTH * (1.0 if i == 0 else 0.6))
		mat.set_shader_parameter("scale", StyleConfig.CP7_MIST_SCALE * (1.0 if i == 0 else 1.7))
		mat.set_shader_parameter("drift", Vector2(0.45, 0.18) * (1.0 if i == 0 else -0.7))
		mat.set_shader_parameter("seed", 13.0 * float(i))
		mat.set_shader_parameter("mist_col", StyleConfig.CP7_MIST_COLOUR)
		# 0.3.1: drawn after the view's post-process quad (priority 0), which would otherwise paint over soft alpha.
		mat.render_priority = StyleConfig.L31_SOFT_PRIORITY
		_mist_mats.append(mat)
		var plane := PlaneMesh.new()
		plane.size = Vector2(PLANE_SIZE, PLANE_SIZE)
		var inst := MeshInstance3D.new()
		inst.mesh = plane
		inst.material_override = mat
		inst.position.y = StyleConfig.CP7_MIST_HEIGHT * (1.0 if i == 0 else 2.4)
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(inst)
	_build_skyline()
	sync(0.0)


func mist_layer_count() -> int:
	return _mist_mats.size()


func mist_material(i: int) -> ShaderMaterial:
	return _mist_mats[i]


# How lit skyline sector `i` is (0 grey, 1 warm).
func skyline_lit(i: int) -> float:
	return _lit[i]


func skyline_roof_count(i: int) -> int:
	return _skyline[i].multimesh.instance_count


# The sky colour for the night's progress (0 at dusk, 1 at dawn). Cooler toward midnight; the share of the night before
# first light starts is mapped to 0..1 and the sky returns to the dusk blue when first light begins.
static func sky_for(night_progress: float) -> Color:
	var first_light_start := 1.0 - NightConfig.FIRST_LIGHT_SECONDS / NightConfig.NIGHT_LENGTH
	var t := clampf(night_progress / maxf(first_light_start, 0.01), 0.0, 1.0)
	return ViewPipeline.STYLED_BACKGROUND.lerp(HudConfig.CP7_NIGHT_SKY, StyleConfig.CP7_SKY_NIGHT_MIX * sin(PI * t))


# One frame: the sky, the skyline sectors and the paint-weight picture the mist reads.
func sync(delta: float) -> void:
	if _main == null:
		return
	var ground_look := _main.ground.look as GroundLookStyled if _main.ground != null else null
	if ground_look != null:
		var tex := ground_look.weights_texture()
		if tex != null and tex != _weights:
			_weights = tex
			for mat: ShaderMaterial in _mist_mats:
				mat.set_shader_parameter("weights", tex)
				mat.set_shader_parameter("plaza", float(ground_look.grid_size))
	if _main.night != null and not _main.night.first_light_active():
		_main.environment().background_color = sky_for(_main.night.progress())
	var held: Array[bool] = _main.landmarks.held_flags() if _main.landmarks != null else []
	for i: int in range(_lit.size()):
		var want := 1.0 if (i < held.size() and held[i]) else 0.0
		_lit[i] = move_toward(_lit[i], want, delta / StyleConfig.CP7_SKYLINE_EASE)
		_roof_mats[i].albedo_color = StyleConfig.CP7_ROOF_GREY.lerp(StyleConfig.CP7_ROOF_WARM, _lit[i])


func _build_skyline() -> void:
	var count := LandmarkConfig.LANDMARK_POSITIONS.size()
	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.albedo_color = StyleConfig.CP7_BODY_GREY
	var rng := RandomNumberGenerator.new()
	rng.seed = 7007
	for i: int in range(count):
		var lm := LandmarkConfig.LANDMARK_POSITIONS[i]
		var base_angle := atan2(lm.z, lm.x)
		var n := StyleConfig.CP7_SKYLINE_ROOFS
		var body := MultiMesh.new()
		body.transform_format = MultiMesh.TRANSFORM_3D
		body.mesh = BoxMesh.new()
		body.instance_count = n
		var roof := MultiMesh.new()
		roof.transform_format = MultiMesh.TRANSFORM_3D
		var prism := PrismMesh.new()
		roof.mesh = prism
		roof.instance_count = n
		for k: int in range(n):
			var a := base_angle + (float(k) / float(n - 1) - 0.5) * StyleConfig.CP7_SKYLINE_ARC
			var radius := StyleConfig.CP7_SKYLINE_RADIUS + rng.randf_range(0.0, 7.0)
			var w := rng.randf_range(3.0, 5.0)
			var h := rng.randf_range(3.5, 7.0)
			var d := rng.randf_range(3.0, 4.5)
			var pos := Vector3(cos(a) * radius, 0.0, sin(a) * radius)
			var basis := Basis(Vector3.UP, -a + PI * 0.5)
			body.set_instance_transform(k, Transform3D(basis.scaled(Vector3(w, h, d)), pos + Vector3(0, h * 0.5, 0)))
			var rh := rng.randf_range(1.6, 2.6)
			roof.set_instance_transform(
				k, Transform3D(basis.scaled(Vector3(w * 1.15, rh, d * 1.1)), pos + Vector3(0, h + rh * 0.5, 0))
			)
		var bi := MultiMeshInstance3D.new()
		bi.multimesh = body
		bi.material_override = body_mat
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(bi)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = StyleConfig.CP7_ROOF_GREY
		_roof_mats.append(mat)
		var ri := MultiMeshInstance3D.new()
		ri.multimesh = roof
		ri.material_override = mat
		ri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ri)
		_skyline.append(ri)
		_lit.append(0.0)
