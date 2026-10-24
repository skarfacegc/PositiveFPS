class_name StyleKit
extends RefCounted

# Shared helpers of the styled look (ported from design/style_test/scene.gd): the toon material cache and small
# builders for boxes, cylinders, spheres, prisms, tori and segments. The materials are shared between every object
# (so the styled look adds only a handful of shader materials); a mesh that needs its own value (a glow, a dissolve)
# sets an instance uniform instead.

const TOON_SHADER := "res://shaders/style_toon.gdshader"
const GLOW_SHADER := "res://shaders/style_glow.gdshader"

static var _cache: Dictionary = {}
static var _toon: Shader
static var _glow: Shader


# A colour from a "#rrggbb" string.
static func hexc(h: String) -> Color:
	return Color.html(h)


# The shared toon material for these values. `dmode` 0 always drawn, 1 industrial, 2 whimsical (see
# style_toon.gdshader).
static func mat(
	col: Color, dmode: int = 0, grime: float = 0.0, emit: float = 0.0, pat: int = 0, vary: float = 0.0
) -> ShaderMaterial:
	var key := "%s|%d|%.2f|%.2f|%d|%.1f" % [col.to_html(), dmode, grime, emit, pat, vary]
	if _cache.has(key):
		return _cache[key]
	if _toon == null:
		_toon = load(TOON_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _toon
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("dmode", dmode)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("emit", emit)
	m.set_shader_parameter("pat", pat)
	m.set_shader_parameter("vary", vary)
	_cache[key] = m
	return m


# A toon material of its own (not shared), for a value that changes every frame (a pulsing emission).
static func unique_mat(col: Color, emit: float) -> ShaderMaterial:
	var m := mat(col, 0, 0.0, emit).duplicate() as ShaderMaterial
	return m


# A glow material (dithered radial glow on the ground, see style_glow.gdshader). Not shared: each caller owns its own.
static func glow_mat(col: Color, strength: float) -> ShaderMaterial:
	if _glow == null:
		_glow = load(GLOW_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _glow
	m.set_shader_parameter("glow_color", col)
	m.set_shader_parameter("strength", strength)
	return m


# A flat square of ground glow, `size` metres across, centred on `pos`.
static func glow_plane(parent: Node, m: Material, size: float, pos: Vector3) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	return _mi(parent, plane, m, pos, Vector3.ZERO, false)


static func _mi(
	parent: Node, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3, shadow: bool = true
) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n


static func box(
	p: Node, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, shadow: bool = true
) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(p, b, m, pos, rot, shadow)


static func cyl(
	p: Node,
	r: float,
	h: float,
	pos: Vector3,
	m: Material,
	rot: Vector3 = Vector3.ZERO,
	r_top: float = -1.0,
	sides: int = 10,
	shadow: bool = true
) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	c.radial_segments = sides
	c.rings = 1
	return _mi(p, c, m, pos, rot, shadow)


static func sph(
	p: Node, r: float, pos: Vector3, m: Material, scl: Vector3 = Vector3.ONE, sides: int = 8, shadow: bool = true
) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = sides
	s.rings = maxi(floori(sides / 2.0), 3)
	var n := _mi(p, s, m, pos, Vector3.ZERO, shadow)
	n.scale = scl
	return n


static func prism(
	p: Node, size: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, shadow: bool = true
) -> MeshInstance3D:
	var pr := PrismMesh.new()
	pr.size = size
	return _mi(p, pr, m, pos, rot, shadow)


static func torus(
	p: Node, ri: float, ro: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO
) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	t.rings = 10
	t.ring_segments = 6
	return _mi(p, t, m, pos, rot)


# A thin cylinder from `a` to `b`.
static func seg(
	p: Node, a: Vector3, b: Vector3, r: float, m: Material, sides: int = 6, shadow: bool = true
) -> MeshInstance3D:
	if a.y > b.y:
		var t := a
		a = b
		b = t
	var d := b - a
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = d.length()
	c.radial_segments = sides
	c.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.position = (a + b) * 0.5
	var dir := d.normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		n.basis = Basis(Quaternion(Vector3.UP, dir))
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(n)
	return n
