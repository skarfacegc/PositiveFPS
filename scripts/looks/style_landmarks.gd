class_name StyleLandmarks
extends RefCounted

# Graphics checkpoint 3: the three landmarks in the locked style. Each is built twice on the same footprint: a grey
# "ruin" (industrial materials, weathered, a piece missing, nothing moving) and a warm "alive" version (plaster, timber,
# bunting, flowers, a lit lamp) which dither into each other with the claim hold, like the buildings do. Distinct
# silhouettes: the bandstand is a wide low dome on posts, the garden a round tree with a flowered arch over a bed, the
# bell tower a tall narrow spire. The origin is the middle of the base on the ground; every shape fits the 4 x 4
# footprint. `build` returns the parts the look animates ("bell", "lamp"). Original designs, made of the shared
# StyleKit primitives.

const POSTS := 6
const BEADS := 12
const BLOSSOMS: Array[String] = ["#e8736a", "#f4d47a", "#f6ecd8", "#c9a0dc"]


# Builds landmark `index` (Landmarks.BANDSTAND ...) into `root`, as the grey ruin or the warm alive version.
static func build(root: Node3D, index: int, ruin: bool) -> Dictionary:
	if index == Landmarks.GARDEN:
		return _garden(root, ruin)
	if index == Landmarks.BELL_TOWER:
		return _bell_tower(root, ruin)
	return _bandstand(root, ruin)


# One material: the ruin's (industrial, weathered) or the alive version's (warm).
static func _m(ruin: bool, grey: String, warm: String, grime: float = 1.0, emit: float = 0.0, pat: int = 0) -> Material:
	if ruin:
		return StyleBuildings.ind(grey, grime, 0.0, pat)
	return StyleBuildings.whim(warm, emit, pat)


# ---- Bandstand: an eight-sided stage, six posts and a wide shallow roof ----


static func _bandstand(root: Node3D, ruin: bool) -> Dictionary:
	# Graphics checkpoint 4: the ruin's greys are lighter and less grimy than before (it was too dark to read at night).
	var step := _m(ruin, "#7a8291", "#c4b088", 0.5)
	var floor_m := _m(ruin, "#99a1ae", "#e0cfa4", 0.5)
	var post_m := _m(ruin, "#b0b7c2", "#f1dfbd", 0.5)
	var roof_m := _m(ruin, "#858d9a", "#5f86b0", 0.5, 0.0, 2)
	var rim_m := _m(ruin, "#97a0ac", "#c0604f", 0.5)
	StyleKit.cyl(root, 2.3, 0.2, Vector3(0, 0.1, 0), step, Vector3.ZERO, -1.0, 8)
	StyleKit.cyl(root, 2.0, 0.4, Vector3(0, 0.4, 0), floor_m, Vector3.ZERO, -1.0, 8)
	for k: int in range(POSTS):
		var a := TAU * float(k) / float(POSTS)
		var at := Vector3(cos(a) * 1.55, 0.0, sin(a) * 1.55)
		if ruin and (k == 2 or k == 3):
			# Two posts have fallen: stumps and a post lying on the stage.
			StyleKit.cyl(root, 0.1, 0.4, at + Vector3(0, 0.8, 0), post_m, Vector3.ZERO, -1.0, 6)
			continue
		StyleKit.cyl(root, 0.1, 1.9, at + Vector3(0, 1.55, 0), post_m, Vector3.ZERO, -1.0, 6)
	if ruin:
		StyleKit.cyl(root, 0.1, 1.5, Vector3(0.2, 0.7, -0.4), post_m, Vector3(0, 0.6, PI / 2), -1.0, 6)
		StyleKit.cyl(root, 2.3, 0.7, Vector3(0, 2.75, 0), roof_m, Vector3(0.14, 0, 0.1), 0.2, 8)
		StyleKit.box(root, Vector3(0.9, 0.5, 0.7), Vector3(-1.4, 0.55, 1.1), rim_m, Vector3(0.2, 0.5, 0.1))
		return {}
	StyleKit.cyl(root, 2.35, 0.14, Vector3(0, 2.5, 0), rim_m, Vector3.ZERO, -1.0, 8)
	StyleKit.cyl(root, 2.3, 0.9, Vector3(0, 2.95, 0), roof_m, Vector3.ZERO, 0.2, 8)
	StyleKit.sph(root, 0.2, Vector3(0, 3.55, 0), StyleBuildings.whim("#ffd466", 0.9), Vector3.ONE, 6)
	# Bunting: coloured beads round the roof's rim.
	for k: int in range(BEADS):
		var a := TAU * (float(k) + 0.5) / float(BEADS)
		var col := StyleKit.mat(StyleKit.hexc(BLOSSOMS[k % BLOSSOMS.size()]), 2)
		var bead := StyleKit.sph(root, 0.13, Vector3(cos(a) * 2.28, 2.28, sin(a) * 2.28), col, Vector3.ONE, 6, false)
		bead.scale = Vector3(1.0, 1.3, 1.0)
	# A little drum on the stage, so it reads as a place for music.
	StyleKit.cyl(root, 0.32, 0.4, Vector3(0.3, 0.8, 0.2), StyleBuildings.whim("#c0604f"), Vector3.ZERO, -1.0, 8)
	StyleKit.cyl(root, 0.34, 0.06, Vector3(0.3, 1.02, 0.2), StyleBuildings.whim("#f6ecd8"), Vector3.ZERO, -1.0, 8)
	return {}


# ---- Garden: a round bed, a tree and a flowered arch ----


static func _garden(root: Node3D, ruin: bool) -> Dictionary:
	var wall := _m(ruin, "#6c7380", "#bba88c")
	var soil := _m(ruin, "#6e6a62", "#6b4a35")
	var wood := _m(ruin, "#5d5a58", "#7d5438")
	StyleKit.cyl(root, 1.95, 0.35, Vector3(0, 0.17, 0), soil, Vector3.ZERO, -1.0, 12)
	var ring := StyleKit.torus(root, 1.75, 2.1, Vector3(0, 0.3, 0), wall)
	ring.scale = Vector3(1.0, 0.9, 1.0)
	if ruin:
		# A dead tree with two bare boughs, a leaning arch with no top, and a few fallen stones.
		StyleKit.cyl(root, 0.2, 1.6, Vector3(0, 1.15, 0), wood, Vector3.ZERO, 0.12, 6)
		StyleKit.seg(root, Vector3(0, 1.7, 0), Vector3(0.7, 2.4, 0.1), 0.07, wood)
		StyleKit.seg(root, Vector3(0, 1.5, 0), Vector3(-0.6, 2.2, -0.2), 0.07, wood)
		StyleKit.cyl(root, 0.1, 1.3, Vector3(-1.1, 0.8, 1.95), wood, Vector3(0, 0, 0.15), -1.0, 6)
		StyleKit.cyl(root, 0.1, 1.2, Vector3(1.1, 0.8, 1.95), wood, Vector3(0, 0, -0.1), -1.0, 6)
		StyleKit.box(root, Vector3(0.7, 0.35, 0.5), Vector3(1.4, 0.4, -1.0), wall, Vector3(0.1, 0.6, 0.15))
		StyleKit.box(root, Vector3(0.5, 0.3, 0.4), Vector3(-1.5, 0.35, -0.7), wall, Vector3(0.0, 0.2, 0.2))
		return {}
	var leaf_a := StyleBuildings.whim("#6f9552")
	var leaf_b := StyleBuildings.whim("#8aa55a")
	var leaf_c := StyleBuildings.whim("#56753f")
	StyleKit.cyl(root, 0.22, 1.9, Vector3(0, 1.3, 0), wood, Vector3.ZERO, 0.14, 6)
	StyleKit.sph(root, 1.25, Vector3(0, 2.7, 0), leaf_a, Vector3(1.0, 0.85, 1.0), 10)
	StyleKit.sph(root, 0.85, Vector3(0.85, 2.35, 0.25), leaf_b, Vector3.ONE, 8)
	StyleKit.sph(root, 0.8, Vector3(-0.8, 2.4, -0.2), leaf_c, Vector3.ONE, 8)
	# Shrubs and flowers round the bed.
	for k: int in range(8):
		var a := TAU * float(k) / 8.0 + 0.3
		var at := Vector3(cos(a) * 1.45, 0.62, sin(a) * 1.45)
		StyleKit.sph(root, 0.42, at, leaf_b if k % 2 == 0 else leaf_a, Vector3(1.0, 0.8, 1.0), 6)
		var col := StyleKit.mat(StyleKit.hexc(BLOSSOMS[k % BLOSSOMS.size()]), 2)
		StyleKit.sph(root, 0.14, at + Vector3(0, 0.38, 0), col, Vector3.ONE, 6, false)
	# The arch: a thin upright ring, half sunk in the ground, with blossoms along it.
	StyleKit.torus(root, 1.0, 1.14, Vector3(0, 0.0, 2.05), wood, Vector3(PI / 2, 0, 0))
	for k: int in range(7):
		var a := PI * float(k + 1) / 8.0
		var col := StyleKit.mat(StyleKit.hexc(BLOSSOMS[(k + 1) % BLOSSOMS.size()]), 2)
		StyleKit.sph(root, 0.15, Vector3(cos(a) * 1.07, sin(a) * 1.07, 2.05), col, Vector3.ONE, 6, false)
	return {}


# ---- Bell tower: a tall narrow tower, an open belfry, a spire ----


static func _bell_tower(root: Node3D, ruin: bool) -> Dictionary:
	var plinth := _m(ruin, "#565d69", "#bba88c")
	var shaft := _m(ruin, "#8d95a1", "#f1dfbd", 1.0, 0.0, 1 if ruin else 0)
	var band := _m(ruin, "#6f7884", "#7d5438")
	var post_m := _m(ruin, "#6f7884", "#7d5438")
	StyleKit.box(root, Vector3(2.5, 0.5, 2.5), Vector3(0, 0.25, 0), plinth)
	var shaft_h := 4.4 if not ruin else 3.8
	StyleKit.box(root, Vector3(1.6, shaft_h, 1.6), Vector3(0, 0.5 + shaft_h * 0.5, 0), shaft)
	for fy: float in [1.7, 3.2]:
		StyleKit.box(root, Vector3(1.74, 0.14, 1.74), Vector3(0, fy, 0), band)
	var slit := StyleBuildings.ind("#1d2129") if ruin else StyleBuildings.whim("#ffcf70", 1.2)
	StyleKit.box(root, Vector3(0.26, 0.8, 0.1), Vector3(0, 2.4, 0.82), slit)
	var top := 0.5 + shaft_h
	StyleKit.box(root, Vector3(1.9, 0.2, 1.9), Vector3(0, top + 0.1, 0), band)
	if ruin:
		# The belfry is broken: three posts of different heights, a fallen beam, the bell lying on the ground.
		StyleKit.cyl(root, 0.1, 1.3, Vector3(0.7, top + 0.85, 0.7), post_m, Vector3.ZERO, -1.0, 6)
		StyleKit.cyl(root, 0.1, 0.8, Vector3(-0.7, top + 0.6, 0.7), post_m, Vector3.ZERO, -1.0, 6)
		StyleKit.cyl(root, 0.1, 1.0, Vector3(-0.7, top + 0.7, -0.7), post_m, Vector3.ZERO, -1.0, 6)
		StyleKit.seg(root, Vector3(0.9, top + 1.4, 0.7), Vector3(-0.2, top + 1.0, 0.7), 0.09, post_m)
		var bell := StyleKit.sph(root, 0.45, Vector3(1.6, 0.4, 1.5), shaft, Vector3(1.0, 0.9, 1.0), 8)
		bell.rotation = Vector3(0, 0, 1.2)
		StyleKit.box(root, Vector3(0.8, 0.3, 0.5), Vector3(-1.5, 0.3, 1.2), plinth, Vector3(0, 0.4, 0.1))
		return {}
	for sx: float in [-0.7, 0.7]:
		for sz: float in [-0.7, 0.7]:
			StyleKit.cyl(root, 0.1, 1.5, Vector3(sx, top + 0.95, sz), post_m, Vector3.ZERO, -1.0, 6)
	StyleKit.box(root, Vector3(1.9, 0.16, 1.9), Vector3(0, top + 1.75, 0), band)
	var roof := StyleBuildings.whim("#c0604f")
	StyleKit.cyl(root, 1.45, 2.1, Vector3(0, top + 2.8, 0), roof, Vector3(0, PI / 4, 0), 0.04, 4)
	StyleKit.sph(root, 0.16, Vector3(0, top + 3.95, 0), StyleBuildings.whim("#ffd466", 0.9), Vector3.ONE, 6)
	# The bell swings from a pivot under the roof; a lamp hangs by the door.
	var pivot := Node3D.new()
	pivot.position = Vector3(0, top + 1.6, 0)
	root.add_child(pivot)
	var brass := StyleBuildings.whim("#e5b04a", 0.6)
	StyleKit.cyl(pivot, 0.5, 0.9, Vector3(0, -0.5, 0), brass, Vector3.ZERO, 0.22, 10)
	StyleKit.sph(pivot, 0.12, Vector3(0, -1.0, 0), StyleBuildings.whim("#7a5538"), Vector3.ONE, 6, false)
	var lamp := StyleKit.sph(root, 0.18, Vector3(1.0, 1.9, 0.9), StyleBuildings.whim("#ffcf70", 1.3), Vector3.ONE, 6)
	return {"bell": pivot, "lamp": lamp}
