class_name StyleTarget
extends RefCounted

# Checkpoint 6: the target highlight in the locked style. The placeholder is a flat warm disc under the target; this
# is a flat ring (an ink outer pixel, a bright rim and a gold fill, see style_ring.gdshader) with a
# faint disc inside it tinted by the target's element, so the ring says "this one" and the tint says which joy fits.
# It uses the ring shader only (no instance uniforms, so it costs nothing from the toon shader's instance buffer).

const GOLD := Color("#ffd866")
const GOLD_RIM := Color("#fff3c4")


# Turns `highlight` (a MeshInstance3D the level owns) into the styled ring, with the tint disc as its only child.
static func build(highlight: MeshInstance3D) -> void:
	highlight.mesh = StyleCues.ring_mesh()
	highlight.material_override = StyleCues.ring_material(GOLD, GOLD_RIM, 0.75, PlayerConfig.CP6_TARGET_RING_INNER)
	highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var disc := MeshInstance3D.new()
	disc.name = "TintDisc"
	disc.mesh = StyleCues.ring_mesh()
	disc.material_override = StyleCues.ring_material(GOLD, GOLD_RIM, 0.28, 0.0)
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.scale = Vector3.ONE * (PlayerConfig.CP6_TARGET_RING_INNER - 0.04)
	disc.position.y = -0.005
	highlight.add_child(disc)


# One frame: the ring's size (with the slow pulse `pulse`, about 1) and the tint disc's colour.
static func sync(highlight: MeshInstance3D, element_colour: Color, pulse: float) -> void:
	var r := PlayerConfig.TD_HIGHLIGHT_RADIUS * PlayerConfig.CP6_TARGET_RADIUS_SCALE * pulse
	highlight.scale = Vector3(r, 1.0, r)
	var disc := highlight.get_node_or_null("TintDisc") as MeshInstance3D
	if disc != null:
		var mat := disc.material_override as ShaderMaterial
		mat.set_shader_parameter("fill_color", element_colour)
		mat.set_shader_parameter("rim_color", element_colour.lerp(Color.WHITE, 0.5))
		mat.set_shader_parameter("rim_width", 0.0)
