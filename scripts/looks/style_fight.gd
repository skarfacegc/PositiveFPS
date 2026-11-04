class_name StyleFight
extends RefCounted

# Graphics checkpoint 5: the styled pieces that read the fight (PatchFx builds and drives them in the styled
# look): the strain rings and their pings, the patch's ward (a dithered disc, a rim ring and a circle of light
# posts), the burst's streaks, the halos and light columns over the people it lifted, and the coral breach over
# an open gap (BorderLookStyled). All of them are flat dithered shapes or open columns with an ink pixel and no
# alpha, so they stay crisp in the 640x360 pass. Pure visuals: the rules never read them.

const BEAM_SHADER := "res://shaders/style_beam.gdshader"
const GOLD := Color("#ffd866")
const GOLD_RIM := Color("#fff3c4")
const CORAL := Color("#ff6a58")
const CORAL_CORE := Color("#ffd2c4")
const WARD := Color("#5fe3cf")
const WARD_RIM := Color("#e8fff8")
const WARD_CORE := Color("#eafffa")
const INK := Color("#3a2a20")

static var _beam_shader: Shader


# A column material (see style_beam.gdshader). Its own copy: the caller changes `fade` as the effect dies away.
static func beam_material(col: Color, core: Color, height: float, density: float) -> ShaderMaterial:
	if _beam_shader == null:
		_beam_shader = load(BEAM_SHADER)
	var m := ShaderMaterial.new()
	m.shader = _beam_shader
	m.set_shader_parameter("beam_color", col)
	m.set_shader_parameter("core_color", core)
	m.set_shader_parameter("height", height)
	m.set_shader_parameter("density", density)
	return m


# An open cylinder `radius` wide and `height` tall (no caps), centred on its middle.
static func beam_mesh(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 10
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	return c


# A column standing on the ground at the node's origin: the mesh is lifted so its foot is at y = 0.
static func beam_node(parent: Node, radius: float, height: float, mat: ShaderMaterial) -> MeshInstance3D:
	var holder := MeshInstance3D.new()
	holder.mesh = beam_mesh(radius, height)
	holder.material_override = mat
	holder.position.y = height * 0.5
	holder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.visible = false
	parent.add_child(holder)
	return holder


# A flat ring (or disc, `inner` 0) of radius 1 on the ground; scale it to the real radius. Its own material.
static func ring_node(parent: Node, inner: float, fill: Color, rim: Color, density: float) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = StyleCues.ring_mesh()
	m.material_override = StyleCues.ring_material(fill, rim, density, inner)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visible = false
	parent.add_child(m)
	return m


# Sets a ring node's colours, density, rim thickness (as a share of its radius) and fade.
static func set_ring(m: MeshInstance3D, fill: Color, density: float, rim_width: float, fade: float = 1.0) -> void:
	var mat := m.material_override as ShaderMaterial
	mat.set_shader_parameter("fill_color", fill)
	mat.set_shader_parameter("rim_color", fill.lerp(Color.WHITE, 0.6))
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("rim_width", rim_width)
	mat.set_shader_parameter("fade", fade)


# Tints a toon-shaded mesh toward `col` by `amount` (0 clears it), and lights it by `glow` (see style_toon.gdshader).
static func tint(mesh: GeometryInstance3D, id: int, amount: float, glow: float = 0.0) -> void:
	var packed := 0.0 if id <= 0 or amount <= 0.0 else float(id) + clampf(amount, 0.0, 1.0) * 0.99
	mesh.set_instance_shader_parameter("tint", packed)
	mesh.set_instance_shader_parameter("emit_add", glow)


# Every MeshInstance3D under `root` that is not under `skip` (a null skip skips nothing).
static func meshes_under(root: Node, skip: Node = null) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == skip:
			continue
		if n is MeshInstance3D:
			out.append(n as MeshInstance3D)
		for child: Node in n.get_children():
			stack.append(child)
	return out
