class_name StyleHouses
extends RefCounted

# 0.4 pass 2b (#58): the styled built block. A town cell is not one building but a tight group of small houses that
# fills it: a back row and a front row with a thin alley between, every door opening onto the alley. The same pixel-
# diorama look as the older blocks (the toon materials of StyleBuildings): a grey industrial version (flat roof, vent,
# steel door) and a whimsical version (plaster, gable roof, coloured door, a lit window) that the block dissolves
# between as it is beautified. Cheap on purpose: INDUSTRIAL_MESHES and WHIMSICAL_MESHES per house, five houses a block.

const ROOFS: Array[String] = ["#ad6249", "#5f86b0", "#c0604f", "#7f9d62"]
const DOORS: Array[String] = ["#5f86b0", "#c0604f", "#7f9d62", "#c0604f"]
const PLASTERS: Array[String] = ["#f1dfbd", "#f3e6cf", "#ecd3b0", "#f0e0c8"]
const GAP := 0.45
const ALLEY := 1.0
const MIN_HEIGHT := 2.4
const HEIGHT_SPREAD := 1.1
const ROOF_RISE := 1.0
const INDUSTRIAL_MESHES := 4
const WHIMSICAL_MESHES := 5


# The houses of one block: five Dictionaries {"pos": Vector3 (x, 0, z), "w", "d", "h", "yaw", "idx"}, filling a
# footprint of `width` x `depth` metres about the origin. One row has three houses and the other two (which one is
# picked by `seed_idx`), the alley runs along x, and each house faces the alley. A pure function: the same seed gives
# the same group.
static func layout(width: float, depth: float, seed_idx: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var row_d := (depth - ALLEY) * 0.5
	var three_in_back := seed_idx % 2 == 0
	var counts: Array[int] = []
	counts.append(3 if three_in_back else 2)
	counts.append(2 if three_in_back else 3)
	for row: int in range(2):
		var n := counts[row]
		var w := (width - GAP * float(n - 1)) / float(n)
		var z := -(ALLEY * 0.5 + row_d * 0.5) if row == 0 else (ALLEY * 0.5 + row_d * 0.5)
		for i: int in range(n):
			var x := -width * 0.5 + w * 0.5 + float(i) * (w + GAP)
			var k := row * 3 + i
			(
				out
				. append(
					{
						"pos": Vector3(x, 0.0, z),
						"w": w,
						"d": row_d,
						"h": MIN_HEIGHT + unit_hash(seed_idx * 31 + k) * HEIGHT_SPREAD,
						"yaw": 0.0 if row == 0 else PI,
						"idx": (seed_idx + k) % 4,
						# Walls and gates: Style update (#94): which piece of dressing the house wears (StyleDress).
						"role": StyleDress.role_of(out.size(), seed_idx)
					}
				)
			)
	return out


# A steady 0..1 number for `k` (the same on every run).
static func unit_hash(k: int) -> float:
	return fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)


# How many meshes a version of a block holds (tests and the budget read this).
static func mesh_count(industrial: bool, houses: int = 5) -> int:
	var dress := 0
	if houses >= 5:  # Style update (#94): a whole block wears its dressing (StyleDress).
		dress = StyleDress.INDUSTRIAL_MESHES if industrial else StyleDress.WHIMSICAL_MESHES
	return houses * (INDUSTRIAL_MESHES if industrial else WHIMSICAL_MESHES) + dress


# Builds the grey industrial group under `p` (origin at the middle of the base).
static func build_industrial(p: Node3D, houses: Array[Dictionary]) -> void:
	var wall := StyleBuildings.ind("#8d95a1", 1.0)
	var roof := StyleBuildings.ind("#4c525d", 1.0, 0.0, 2)
	var vent := StyleBuildings.ind("#8b94a0", 1.0)
	var steel := StyleBuildings.ind("#a2aab5", 0.8)
	for h: Dictionary in houses:
		var g := _house_node(p, h)
		var w: float = h["w"]
		var d: float = h["d"]
		var ht: float = h["h"]
		StyleKit.box(g, Vector3(w, ht, d), Vector3(0.0, ht * 0.5, 0.0), wall)
		StyleKit.box(g, Vector3(w + 0.2, 0.25, d + 0.2), Vector3(0.0, ht + 0.12, 0.0), roof)
		StyleKit.box(g, Vector3(0.9, 0.5, 0.7), Vector3(w * 0.2, ht + 0.5, -d * 0.15), vent)
		StyleKit.box(g, Vector3(0.9, 1.9, 0.12), Vector3(-w * 0.25, 0.95, d * 0.5 + 0.05), steel)
		var role: int = h["role"]
		StyleDress.industrial(g, role, w, d, ht)


# Builds the whimsical group under `p`: plaster, a gable roof, a coloured door and a lit window on every house.
static func build_whimsical(p: Node3D, houses: Array[Dictionary]) -> void:
	var timber := StyleBuildings.whim("#7d5438")
	var glow := StyleBuildings.whim("#ffd88a", 0.7)
	for h: Dictionary in houses:
		var g := _house_node(p, h)
		var idx: int = h["idx"]
		var w: float = h["w"]
		var d: float = h["d"]
		var ht: float = h["h"]
		var roof := StyleBuildings.whim(ROOFS[idx], 0.0, 1)
		StyleKit.box(g, Vector3(w, ht, d), Vector3(0.0, ht * 0.5, 0.0), StyleBuildings.whim(PLASTERS[idx]))
		StyleKit.box(g, Vector3(w + 0.05, 0.2, d + 0.05), Vector3(0.0, ht - 0.1, 0.0), timber)
		StyleKit.prism(
			g,
			Vector3(d + 0.3, ROOF_RISE, w + 0.3),
			Vector3(0.0, ht + ROOF_RISE * 0.5, 0.0),
			roof,
			Vector3(0.0, PI / 2, 0.0)
		)
		StyleKit.box(
			g, Vector3(0.9, 1.9, 0.12), Vector3(-w * 0.25, 0.95, d * 0.5 + 0.05), StyleBuildings.whim(DOORS[idx])
		)
		StyleKit.box(g, Vector3(0.9, 0.7, 0.1), Vector3(w * 0.22, ht * 0.55, d * 0.5 + 0.04), glow)
		var role: int = h["role"]
		StyleDress.whimsical(g, role, w, d, ht)


# A node for one house, at its place in the block and turned to face the alley.
static func _house_node(p: Node3D, h: Dictionary) -> Node3D:
	var at: Vector3 = h["pos"]
	var yaw: float = h["yaw"]
	var g := Node3D.new()
	g.position = at
	g.rotation.y = yaw
	p.add_child(g)
	return g
