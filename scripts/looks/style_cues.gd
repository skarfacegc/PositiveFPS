class_name StyleCues
extends RefCounted

# Graphics checkpoint 2: the styled cues drawn on the ground round a person (the guarded wedge, the grab warning
# ring and
# the stage ripple). All are flat shapes with a solid ink pixel and a bright rim (no alpha blending, so
# they stay
# crisp in the 640x360 pixel pass). Pure visuals: the rules never read them.

const WEDGE_SHADER := "res://shaders/style_wedge.gdshader"
const RING_SHADER := "res://shaders/style_ring.gdshader"
const INK := Color("#3a2a20")
# The guarded wedge: honey fan with a cream rim; while a shot would land the fan is denser and the rim whiter.
const WEDGE_FILL := Color("#ffc94d")
const WEDGE_RIM := Color("#ffe9a8")
const WEDGE_OPEN_FILL := Color("#ffe27a")
const WEDGE_OPEN_RIM := Color("#fffbe8")
const WEDGE_DENSITY := 0.28
const WEDGE_OPEN_DENSITY := 0.78
const WEDGE_RIM_WIDTH := 0.1
const WEDGE_OPEN_RIM_WIDTH := 0.14
# The grab warning ring: coral-red, the gap colour family but redder.
const GRAB_FILL := Color("#e8453b")
const GRAB_RIM := Color("#ffb09a")
const GRAB_RIM_METRES := 0.12

static var _wedge_shader: Shader
static var _ring_shader: Shader


# The wedge material for a fan of `radius` metres and `half_deg` degrees either side of the facing. Its own copy (each
# person changes it as their state changes).
static func wedge_material(radius: float, half_deg: float) -> ShaderMaterial:
	if _wedge_shader == null:
		_wedge_shader = load(WEDGE_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _wedge_shader
	m.set_shader_parameter("ink_color", INK)
	m.set_shader_parameter("radius", radius)
	m.set_shader_parameter("half_angle", deg_to_rad(half_deg))
	set_wedge_open(m, false)
	return m


# Sets the wedge to its closed (dim) or open (a shot would land) colours.
static func set_wedge_open(m: ShaderMaterial, open: bool) -> void:
	m.set_shader_parameter("fill_color", WEDGE_OPEN_FILL if open else WEDGE_FILL)
	m.set_shader_parameter("rim_color", WEDGE_OPEN_RIM if open else WEDGE_RIM)
	m.set_shader_parameter("density", WEDGE_OPEN_DENSITY if open else WEDGE_DENSITY)
	m.set_shader_parameter("rim_width", WEDGE_OPEN_RIM_WIDTH if open else WEDGE_RIM_WIDTH)


# A ring material (see style_ring.gdshader). `inner` is the hole as a fraction of the radius (0 for a disc).
static func ring_material(fill: Color, rim: Color, density: float, inner: float) -> ShaderMaterial:
	if _ring_shader == null:
		_ring_shader = load(RING_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _ring_shader
	m.set_shader_parameter("fill_color", fill)
	m.set_shader_parameter("rim_color", rim)
	m.set_shader_parameter("ink_color", INK)
	m.set_shader_parameter("density", density)
	m.set_shader_parameter("inner", inner)
	return m


# A flat plane two metres across (radius 1) for a ring material; scale it to the real radius.
static func ring_mesh() -> PlaneMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	return plane
