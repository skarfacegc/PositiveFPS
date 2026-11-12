class_name StylePush
extends RefCounted

# The styled gloom tide. 0.3.1: the wave is a low, churning storm cloud (shaders/style_cloud.gdshader): rows of soft
# puffs (one MultiMesh) as long as the stretch being pushed, dark in the core and pale at the edge, with a smooth alpha
# falloff and no dither. The figures in it are small dark pixel people, half hidden by the cloud. GloomTide builds both
# under one styled fog node, places and fades that node like the placeholder fog, sizes the cloud to the pushed stretch
# and sways the figures. Visual only: nothing here reads or writes the rules.

const SHADER := "res://shaders/style_cloud.gdshader"


# The cloud: a MultiMesh of puffs (child 0 of the returned node, which stands at the fog's height) at most `width`
# metres long and `depth` deep. `set_length` then lays the puffs out for the stretch being pushed.
static func build_fog(parent: Node3D, width: float, depth: float, top: float = StyleConfig.L31_FOG_TOP) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	mm.instance_count = max_puffs(width)
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER)
	mat.set_shader_parameter("churn", StyleConfig.L31_FOG_CHURN)
	mat.set_shader_parameter("edge_col", StyleKit.hexc(StyleConfig.L31_FOG_EDGE))
	mat.set_shader_parameter("core_col", StyleKit.hexc(StyleConfig.L31_FOG_CORE))
	mat.set_shader_parameter("puff_ref", StyleConfig.L31_FOG_PUFF)
	mat.set_shader_parameter("alpha_max", StyleConfig.L31_FOG_ALPHA)
	# After the post-process quad (which would paint over soft alpha) and after the mist (which would pale the cloud).
	mat.render_priority = StyleConfig.L31_SOFT_PRIORITY + 1
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-width, -4.0, -depth * 2.0), Vector3(width * 2.0, 12.0, depth * 4.0))
	root.add_child(mi)
	root.set_meta("depth", depth)
	root.set_meta("top", top)
	root.set_meta("length", -1.0)
	set_length(root, minf(width, StyleConfig.L31_FOG_MIN_LENGTH))
	return root


# The most puffs a cloud `width` metres long holds.
static func max_puffs(width: float) -> int:
	return (ceili(width / StyleConfig.L31_FOG_SPACING) + 1) * StyleConfig.L31_FOG_ROWS


# How long the cloud is for a wave whose middle stands `distance` metres from the border's centre: the chord of the
# pushed stretch (the wave pushes TIDE_HALF_WIDTH either side of its direction), within the shortest and widest band.
static func fog_length(distance: float) -> float:
	var chord := 2.0 * maxf(distance, 0.0) * sin(NightConfig.TIDE_HALF_WIDTH)
	return clampf(chord, StyleConfig.L31_FOG_MIN_LENGTH, NightConfig.TIDE_FOG_WIDTH)


# The puffs of a cloud `length` metres long and `depth` deep: position (x along the band, z across it, y up from
# the fog's origin, which stands TIDE_FOG_Y above the ground), diameter and colour. Rows near the middle of the
# depth, and puffs near the middle of the length, are darker, bigger and more opaque; the ends and edges taper off.
static func layout_puffs(length: float, depth: float, top: float = StyleConfig.L31_FOG_TOP) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var along := maxi(2, ceili(length / StyleConfig.L31_FOG_SPACING))
	var rows := maxi(1, StyleConfig.L31_FOG_ROWS)
	var edge := StyleKit.hexc(StyleConfig.L31_FOG_EDGE)
	var core := StyleKit.hexc(StyleConfig.L31_FOG_CORE)
	for r: int in range(rows):
		var zn := 0.0 if rows == 1 else lerpf(-1.0, 1.0, float(r) / float(rows - 1))
		for i: int in range(along):
			var u := (float(i) + 0.5) / float(along)
			var h1 := _hash(float(i) * 7.13 + float(r) * 3.7)
			var h2 := _hash(float(i) * 2.91 + float(r) * 9.3 + 1.7)
			var taper := lerpf(0.55, 1.0, sin(PI * u))
			var heart := (1.0 - absf(zn) * 0.8) * taper
			# The size carries the depth in the cloud (0.6 to 1.1 of a puff): the shader reads it back as the colour.
			var size := StyleConfig.L31_FOG_PUFF * lerpf(0.6, 1.1, heart) * (0.94 + 0.12 * h1)
			var x := (u - 0.5) * length + (h2 - 0.5) * StyleConfig.L31_FOG_SPACING * 0.6
			var z := zn * depth * 0.4 + (h1 - 0.5) * depth * 0.1
			var colour := edge.lerp(core, clampf(heart * 1.1, 0.0, 1.0))
			colour.a = lerpf(0.55, 1.0, heart)
			# The blob's height is `top` for the biggest puff; its bottom rests on the ground.
			var height := top * size / (1.1 * StyleConfig.L31_FOG_PUFF)
			var y := height * 0.5 - NightConfig.TIDE_FOG_Y
			out.append({"pos": Vector3(x, y, z), "size": size, "height": height, "colour": colour})
	return out


# Lays the puffs of `fog` out for a cloud `length` metres long (skipped when it is already about that long).
static func set_length(fog: Node3D, length: float) -> void:
	var prev: float = fog.get_meta("length", -1.0)
	if absf(prev - length) < 0.25:
		return
	fog.set_meta("length", length)
	var depth: float = fog.get_meta("depth", NightConfig.TIDE_FOG_DEPTH)
	var mm := (fog.get_child(0) as MultiMeshInstance3D).multimesh
	var top: float = fog.get_meta("top", StyleConfig.L31_FOG_TOP)
	var puffs := layout_puffs(length, depth, top)
	var n := mini(puffs.size(), mm.instance_count)
	for i: int in range(n):
		var p: Dictionary = puffs[i]
		var size: float = p["size"]
		var at: Vector3 = p["pos"]
		var height: float = p["height"]
		var b := Basis().scaled(Vector3(size, height, 1.0))
		mm.set_instance_transform(i, Transform3D(b, at))
	mm.visible_instance_count = n


# How many puffs `fog` shows now.
static func puff_count(fog: Node3D) -> int:
	return (fog.get_child(0) as MultiMeshInstance3D).multimesh.visible_instance_count


# The length `fog` is laid out for now.
static func current_length(fog: Node3D) -> float:
	return fog.get_meta("length", -1.0)


static func _hash(v: float) -> float:
	return fposmod(sin(v * 12.9898) * 43758.5453, 1.0)


# One figure: a dark pixel body with a round head, standing on its origin (the base). The sway sets its position.
static func build_figure(parent: Node3D) -> Node3D:
	var fig := Node3D.new()
	parent.add_child(fig)
	var m := StyleKit.mat(StyleKit.hexc(StyleConfig.CP7_FIGURE_COLOUR))
	var height := StyleConfig.CP7_FIGURE_HEIGHT
	StyleKit.cyl(fig, 0.3, height * 0.6, Vector3(0.0, height * 0.3, 0.0), m, Vector3.ZERO, -1.0, 6, false)
	StyleKit.sph(fig, 0.2, Vector3(0.0, height * 0.8, 0.0), m, Vector3.ONE, 6, false)
	return fig
