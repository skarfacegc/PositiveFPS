class_name StyleDefence
extends RefCounted

# Walls and gates: Style update (#94). A defence planted at a gate (pass 3, F) in the styled look: a small piece of
# street furniture of the landmark it came from, in the toon materials of the other styled props: a bandstand (a
# round stand with a blue roof), a garden (a flower planter), a bell tower (a bell under a little roof) and a gallery
# (a framed picture on legs). While aiming, the same piece stands on a soft gold wash. Visual only: the rules never
# read it. `build` returns a node standing at `at` on the ground.

const BLUE := "#5f86b0"
const GREEN := "#6f9552"
const GOLD := "#e5b04a"
const ROSE := "#c0604f"
const TIMBER := "#7d5438"
const STONE := "#b8b2c4"
const CREAM := "#f1dfbd"
const LAMP := "#ffe28a"

const COLOURS: Array[String] = [BLUE, GREEN, GOLD, ROSE]


# The number of meshes a defence of `type` is made of (tests read it; the budget is small on purpose).
static func mesh_count(type: int) -> int:
	match type:
		Landmarks.BANDSTAND:
			return 8
		Landmarks.GARDEN:
			return 9
	return 6  # The bell tower and the gallery.


static func build(type: int, at: Vector3, ghost: bool) -> Node3D:
	var root := Node3D.new()
	root.position = at
	if ghost:
		var r := StyleConfig.SU_DEFENCE_GHOST_SIZE
		StyleKit.wash(
			root,
			Rect2(-r * 0.5, -r * 0.5, r, r),
			StyleKit.hexc(StyleTake.FREE_WASH),
			StyleConfig.SU_DEFENCE_GHOST_FILL,
			StyleConfig.SU_DEFENCE_GHOST_RIM,
			0.15
		)
	match type:
		Landmarks.BANDSTAND:
			_bandstand(root)
		Landmarks.GARDEN:
			_garden(root)
		Landmarks.BELL_TOWER:
			_bell(root)
		_:
			_gallery(root)
	return root


static func _m(hex: String, glow: float = 0.0) -> ShaderMaterial:
	return StyleKit.mat(StyleKit.hexc(hex), 0, 0.0, glow)


static func _bandstand(root: Node3D) -> void:
	var h := StyleConfig.SU_DEFENCE_HEIGHT
	StyleKit.cyl(root, 0.9, 0.35, Vector3(0.0, 0.18, 0.0), _m(STONE))
	for i: int in range(4):
		var a := TAU * float(i) / 4.0 + PI * 0.25
		StyleKit.cyl(
			root, 0.07, h * 0.8, Vector3(cos(a) * 0.7, h * 0.4 + 0.3, sin(a) * 0.7), _m(TIMBER), Vector3.ZERO, -1.0, 5
		)
	StyleKit.cyl(root, 1.1, 0.5, Vector3(0.0, h * 0.8 + 0.55, 0.0), _m(BLUE), Vector3.ZERO, 0.05, 8)
	StyleKit.sph(root, 0.14, Vector3(0.0, h * 0.8 + 0.95, 0.0), _m(LAMP, 1.3), Vector3.ONE, 5, false)
	StyleKit.cyl(root, 0.18, 0.5, Vector3(0.0, 0.6, 0.0), _m(GOLD), Vector3.ZERO, 0.12, 6)


static func _garden(root: Node3D) -> void:
	StyleKit.box(root, Vector3(1.8, 0.5, 1.0), Vector3(0.0, 0.25, 0.0), _m(TIMBER))
	StyleKit.box(root, Vector3(1.6, 0.14, 0.8), Vector3(0.0, 0.55, 0.0), _m("#4f8a48"))
	var spots: Array[Vector3] = [Vector3(-0.55, 0.85, 0.0), Vector3(0.0, 0.95, 0.15), Vector3(0.55, 0.85, -0.1)]
	var petals: Array[String] = [ROSE, "#f2c14e", "#e8667a"]
	for i: int in range(spots.size()):
		StyleKit.cyl(root, 0.04, 0.4, spots[i] - Vector3(0.0, 0.2, 0.0), _m(GREEN), Vector3.ZERO, -1.0, 4, false)
		StyleKit.sph(root, 0.26, spots[i], _m(petals[i], 0.3), Vector3.ONE, 6, false)
	StyleKit.sph(root, 0.4, Vector3(0.0, 0.75, -0.3), _m(GREEN), Vector3(1.4, 0.8, 1.0), 6)


static func _bell(root: Node3D) -> void:
	var h := StyleConfig.SU_DEFENCE_HEIGHT
	StyleKit.cyl(root, 0.1, h, Vector3(-0.5, h * 0.5, 0.0), _m(TIMBER), Vector3.ZERO, -1.0, 5)
	StyleKit.cyl(root, 0.1, h, Vector3(0.5, h * 0.5, 0.0), _m(TIMBER), Vector3.ZERO, -1.0, 5)
	StyleKit.box(root, Vector3(1.3, 0.14, 0.2), Vector3(0.0, h, 0.0), _m(TIMBER))
	StyleKit.prism(root, Vector3(1.6, 0.5, 0.7), Vector3(0.0, h + 0.3, 0.0), _m(ROSE, 0.0))
	StyleKit.cyl(root, 0.42, 0.7, Vector3(0.0, h - 0.5, 0.0), _m(GOLD, 0.4), Vector3.ZERO, 0.12, 8)
	StyleKit.sph(root, 0.1, Vector3(0.0, h - 0.92, 0.0), _m(GOLD), Vector3.ONE, 4, false)


static func _gallery(root: Node3D) -> void:
	var h := StyleConfig.SU_DEFENCE_HEIGHT
	StyleKit.cyl(root, 0.06, h, Vector3(-0.55, h * 0.5, 0.0), _m(TIMBER), Vector3.ZERO, -1.0, 4)
	StyleKit.cyl(root, 0.06, h, Vector3(0.55, h * 0.5, 0.0), _m(TIMBER), Vector3.ZERO, -1.0, 4)
	StyleKit.box(root, Vector3(1.5, 1.1, 0.12), Vector3(0.0, h * 0.7, 0.0), _m(GOLD))
	StyleKit.box(root, Vector3(1.25, 0.85, 0.14), Vector3(0.0, h * 0.7, 0.02), _m(CREAM))
	StyleKit.box(root, Vector3(0.6, 0.35, 0.16), Vector3(-0.2, h * 0.7 - 0.1, 0.04), _m(ROSE, 0.2))
	StyleKit.box(root, Vector3(0.45, 0.3, 0.16), Vector3(0.28, h * 0.7 + 0.15, 0.04), _m(BLUE, 0.2))
