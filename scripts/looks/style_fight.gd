class_name StyleFight
extends RefCounted

# Graphics checkpoint 5: the styled pieces that read the fight (PatchFx and EdgeMarkerFx build and drive them in the
# styled look): the patch's ward (a dithered disc and a rim ring), the burst's streaks, the halos over the people it
# lifted and the trouble markers. Round 25: the light columns and posts are gone (no tall light at the edge). All of
# them are flat dithered shapes with an ink pixel and no alpha, so they stay crisp in the 640x360 pass. Pure visuals:
# the rules never read them.

const GOLD := Color("#ffd866")
const GOLD_RIM := Color("#fff3c4")
const WARD := Color("#5fe3cf")
const WARD_RIM := Color("#e8fff8")
const INK := Color("#3a2a20")


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
