class_name StylePush
extends RefCounted

# Checkpoint 7: the styled gloom tide (round 26). The wave is a row of pixel fog banks in toon shading (no transparency,
# so it keeps the low resolution and the outlines), and the figures in it are small dark pixel people. GloomTide builds
# both under one styled fog node, places and fades that node like the placeholder fog, and sways the figures. Visual
# only: nothing here reads or writes the rules.


# The fog banks: `Config.CP7_FOG_BANKS` blocks along the front, `width` metres across and `depth` deep, standing on the
# ground. The node sits at the fog's height, so the banks drop back down by that height.
static func build_fog(parent: Node3D, width: float, depth: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var m := StyleKit.mat(StyleKit.hexc(Config.CP7_FOG_COLOUR))
	var count := Config.CP7_FOG_BANKS
	var bank_width := width / float(count) * 1.2
	for i: int in range(count):
		var t := (float(i) + 0.5) / float(count)
		var h := Config.CP7_FOG_BANK_HEIGHT * bank_height_share(i)
		var at := Vector3(lerpf(-width * 0.5, width * 0.5, t), h * 0.5 - Config.TIDE_FOG_Y, 0.0)
		StyleKit.box(root, Vector3(bank_width, h, depth), at, m, Vector3.ZERO, false)
	return root


# How tall bank `i` is, as a share of the tallest (0.6 to 1.0): a fixed pattern, so the wave looks the same each time.
static func bank_height_share(i: int) -> float:
	return 0.6 + 0.4 * absf(sin(float(i) * 1.9 + 0.7))


# One figure: a dark pixel body with a round head, standing on its origin (the base). The sway sets its position.
static func build_figure(parent: Node3D) -> Node3D:
	var fig := Node3D.new()
	parent.add_child(fig)
	var m := StyleKit.mat(StyleKit.hexc(Config.CP7_FIGURE_COLOUR))
	var height := Config.CP7_FIGURE_HEIGHT
	StyleKit.cyl(fig, 0.3, height * 0.6, Vector3(0.0, height * 0.3, 0.0), m, Vector3.ZERO, -1.0, 6, false)
	StyleKit.sph(fig, 0.2, Vector3(0.0, height * 0.8, 0.0), m, Vector3.ONE, 6, false)
	return fig
