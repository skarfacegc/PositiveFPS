class_name StyleDress
extends RefCounted

# Walls and gates: Style update (#94). The town look pass: what a built block wears. An unheld block is cold and
# industrial (the "Style pillars" in IDEAS.md: pipes, valves, exhaust fans, vents, gas tanks, soot); when it is taken it
# blooms to the whimsical counterpart of each piece (pipe to vine, fan to pinwheel, vent to birdhouse, tank to flower
# barrel, soot to flower bed) and when it is lost it cools again (the block's own dissolve, BuildingLookStyled). Sparse
# on purpose: four of a block's five houses wear one piece each (the fifth stays bare), so the corners stay readable
# at play zoom. Original shapes in the same toon materials as the houses. Pieces are built in a house's own space
# (origin at the middle of its base, its door and the alley toward local +z).

enum Role { PIPES, STACK, FAN, TANK, BARE }

const INDUSTRIAL_MESHES := 11  # A block's dressing: pipes 3 + soot 1, stack 2 + streak 1, fan 2, tank 2.
const WHIMSICAL_MESHES := 16  # Vine 4, pinwheel 4, birdhouse 2, flower barrel 4, flower bed 2.

const STEEL := "#a2aab5"
const PIPE := "#7f8896"
const PIPE_DARK := "#555c68"
const SOOT := "#33363f"
const RUST := "#8a5a3c"
const TANK := "#6d7684"
const STICK := "#7d5438"
const LEAF := "#56753f"
const BLOOMS: Array[String] = ["#e8667a", "#f2c14e", "#c9b5ee"]
const BLADE_A := "#e8667a"
const BLADE_B := "#f2c14e"
const BIRD_WALL := "#f1dfbd"
const BIRD_ROOF := "#5f86b0"
const BARREL := "#8a5a3c"
const BED := "#4f8a48"
const BED_FLOWER := "#e8667a"


# The role of house number `n` of a block with this seed: every role once across the five houses.
static func role_of(n: int, seed_idx: int) -> int:
	return posmod(n + seed_idx, 5)


# Builds the industrial piece of `role` on the house node `g` (its width `w`, depth `d`, wall height `ht`).
static func industrial(g: Node3D, role: int, w: float, d: float, ht: float) -> void:
	var top := ht + 0.25  # The roof slab's top.
	var pipe := StyleBuildings.ind(PIPE, 1.0)
	var dark := StyleBuildings.ind(PIPE_DARK, 1.0)
	var soot := StyleBuildings.ind(SOOT, 1.0)
	match role:
		Role.PIPES:
			# A run of pipe along the roof, a riser at one end and a valve wheel on the riser.
			var rot := Vector3(0.0, 0.0, PI * 0.5)
			StyleKit.cyl(g, 0.15, w * 0.85, Vector3(0.0, top + 0.5, -d * 0.2), pipe, rot, -1.0, 8)
			StyleKit.cyl(g, 0.15, 0.6, Vector3(w * 0.42, top + 0.25, -d * 0.2), pipe, Vector3.ZERO, -1.0, 8)
			StyleKit.cyl(g, 0.3, 0.07, Vector3(w * 0.42, top + 0.7, -d * 0.2), dark, Vector3.ZERO, -1.0, 8)
			StyleKit.box(g, Vector3(w * 0.5, 0.04, d * 0.35), Vector3(-w * 0.15, top + 0.03, d * 0.1), soot)
		Role.STACK:
			StyleKit.cyl(g, 0.34, 1.7, Vector3(w * 0.28, top + 0.85, d * 0.2), pipe, Vector3.ZERO, 0.28, 8)
			StyleKit.cyl(g, 0.4, 0.22, Vector3(w * 0.28, top + 1.75, d * 0.2), soot, Vector3.ZERO, -1.0, 8)
			StyleKit.box(g, Vector3(0.7, ht * 0.7, 0.05), Vector3(w * 0.28, ht * 0.5, d * 0.5 + 0.04), soot)
		Role.FAN:
			StyleKit.box(
				g, Vector3(0.9, 0.4, 0.9), Vector3(-w * 0.2, top + 0.2, -d * 0.1), StyleBuildings.ind(STEEL, 0.8)
			)
			StyleKit.cyl(g, 0.32, 0.06, Vector3(-w * 0.2, top + 0.43, -d * 0.1), dark, Vector3.ZERO, -1.0, 8)
		Role.TANK:
			var rot := Vector3(0.0, 0.0, PI * 0.5)
			StyleKit.cyl(
				g, 0.55, 1.7, Vector3(-w * 0.2, top + 0.55, d * 0.1), StyleBuildings.ind(TANK, 1.0), rot, -1.0, 10
			)
			StyleKit.cyl(
				g, 0.58, 0.14, Vector3(-w * 0.2, top + 0.55, d * 0.1), StyleBuildings.ind(RUST, 1.0), rot, -1.0, 10
			)


# Builds the whimsical counterpart of the piece of `role` (the roof ridge stands ROOF_RISE above the walls).
static func whimsical(g: Node3D, role: int, w: float, d: float, ht: float) -> void:
	var ridge := ht + StyleHouses.ROOF_RISE
	var stick := StyleBuildings.whim(STICK)
	var leaf := StyleBuildings.whim(LEAF)
	match role:
		Role.PIPES:
			# A vine along the ridge, in bloom.
			StyleKit.cyl(g, 0.14, w * 0.85, Vector3(0.0, ridge + 0.1, 0.0), leaf, Vector3(0.0, 0.0, PI * 0.5), -1.0, 6)
			for i: int in range(3):
				var x := (float(i) - 1.0) * w * 0.28
				StyleKit.sph(
					g, 0.24, Vector3(x, ridge + 0.32, 0.0), StyleBuildings.whim(BLOOMS[i], 0.15), Vector3.ONE, 6, false
				)
		Role.STACK:
			# A pinwheel on a stick: two crossed blades and a gold hub.
			var at := Vector3(w * 0.28, ridge, 0.0)
			StyleKit.cyl(g, 0.05, 1.1, at + Vector3(0.0, 0.55, 0.0), stick, Vector3.ZERO, -1.0, 4, false)
			StyleKit.box(
				g,
				Vector3(0.9, 0.34, 0.05),
				at + Vector3(0.0, 1.15, 0.0),
				StyleBuildings.whim(BLADE_A, 0.1),
				Vector3(0.0, 0.0, 0.5),
				false
			)
			StyleKit.box(
				g,
				Vector3(0.9, 0.34, 0.05),
				at + Vector3(0.0, 1.15, 0.03),
				StyleBuildings.whim(BLADE_B, 0.1),
				Vector3(0.0, 0.0, -1.07),
				false
			)
			StyleKit.sph(
				g, 0.1, at + Vector3(0.0, 1.15, 0.06), StyleBuildings.whim("#ffd88a", 0.7), Vector3.ONE, 5, false
			)
		Role.FAN:
			# A birdhouse on the ridge.
			var at := Vector3(-w * 0.2, ridge + 0.25, 0.0)
			StyleKit.box(g, Vector3(0.6, 0.5, 0.6), at, StyleBuildings.whim(BIRD_WALL))
			StyleKit.prism(
				g, Vector3(0.85, 0.35, 0.85), at + Vector3(0.0, 0.42, 0.0), StyleBuildings.whim(BIRD_ROOF, 0.0, 1)
			)
		Role.TANK:
			# A flower barrel by the door, in the alley.
			var at := Vector3(w * 0.2, 0.0, d * 0.5 + 0.55)
			StyleKit.cyl(g, 0.32, 0.6, at + Vector3(0.0, 0.3, 0.0), StyleBuildings.whim(BARREL), Vector3.ZERO, 0.28, 8)
			StyleKit.sph(g, 0.34, at + Vector3(0.0, 0.7, 0.0), leaf, Vector3(1.0, 0.7, 1.0), 6, false)
			StyleKit.sph(
				g, 0.14, at + Vector3(-0.12, 0.95, 0.05), StyleBuildings.whim(BLOOMS[0], 0.15), Vector3.ONE, 5, false
			)
			StyleKit.sph(
				g, 0.14, at + Vector3(0.14, 0.9, -0.05), StyleBuildings.whim(BLOOMS[1], 0.15), Vector3.ONE, 5, false
			)
	if role == Role.STACK:
		# The streak of soot on the wall becomes a flower bed under it.
		StyleKit.box(
			g,
			Vector3(0.9, 0.1, 0.5),
			Vector3(w * 0.28, 0.06, d * 0.5 + 0.35),
			StyleBuildings.whim(BED),
			Vector3.ZERO,
			false
		)
		StyleKit.box(
			g,
			Vector3(0.4, 0.12, 0.28),
			Vector3(w * 0.28, 0.1, d * 0.5 + 0.35),
			StyleBuildings.whim(BED_FLOWER, 0.1),
			Vector3.ZERO,
			false
		)
