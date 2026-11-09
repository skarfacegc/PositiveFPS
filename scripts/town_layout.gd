class_name TownLayout
extends RefCounted

# 0.3.3 (#52): the shape of the town. A main street along x (z = 0) and a cross street along z (x = 0) cross at the
# player's start (the small square). The blocks (TopDownMain.BLOCK_POSITIONS) stand in rows on both sides of the two
# streets and face them; the landmarks stand at the street ends. This script answers questions about that plan for the
# props (lamps along the kerbs, benches and planters in front of the blocks, stalls on the square) and for the tests.
# It only reads positions: it adds no rules.


# The two streets as ground rectangles (x, z; the second is the cross street).
static func street_rects() -> Array[Rect2]:
	var w := TownConfig.TOWN_STREET_HALF_WIDTH
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	return [Rect2(-half, -w, half * 2.0, w * 2.0), Rect2(-w, -half, w * 2.0, half * 2.0)]


# True when the ground point `at` lies on a street, or within `margin` metres of one.
static func on_street(at: Vector3, margin: float = 0.0) -> bool:
	for r: Rect2 in street_rects():
		if r.grow(margin).has_point(Vector2(at.x, at.z)):
			return true
	return false


# True when `at` is on the small square: the crossing and the four corners round it where the stalls stand.
static func on_square(at: Vector3) -> bool:
	var reach := TownConfig.TOWN_STALL_OFFSET + 2.0
	return absf(at.x) <= reach and absf(at.z) <= reach


# The unit direction (on the ground) from a block toward the street it faces: the nearer street's centre line.
static func facing(block: Vector3) -> Vector3:
	if absf(block.z) <= absf(block.x):
		return Vector3(0.0, 0.0, -signf(block.z) if block.z != 0.0 else 1.0)
	return Vector3(-signf(block.x), 0.0, 0.0)


# The turn (radians about the vertical axis) that points a prop's local +z along `dir`.
static func yaw_toward(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


# The lamp spots: along both kerbs of both streets, TOWN_LAMP_SPACING apart, the first TOWN_LAMP_FIRST from the
# crossing and none within TOWN_EDGE_CLEAR of the plaza's edge.
static func lamp_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	var reach := float(Config.TD_PLAZA_SIZE) * 0.5 - TownConfig.TOWN_EDGE_CLEAR
	var k := TownConfig.TOWN_LAMP_FIRST
	while k <= reach:
		for s: float in [-1.0, 1.0]:
			for side: float in [-1.0, 1.0]:
				out.append(Vector3(s * k, 0.0, side * TownConfig.TOWN_KERB_OFFSET))  # main street
				out.append(Vector3(side * TownConfig.TOWN_KERB_OFFSET, 0.0, s * k))  # cross street
		k += TownConfig.TOWN_LAMP_SPACING
	return out


# The stall spots on the small square: its four corners, each turned toward the start.
static func stall_spots() -> Array[Vector3]:
	var d := TownConfig.TOWN_STALL_OFFSET
	return [Vector3(d, 0.0, d), Vector3(-d, 0.0, d), Vector3(d, 0.0, -d), Vector3(-d, 0.0, -d)]


# Where a block's bench and planter stand: in front of the block, toward its street. Returns {"bench": Vector3,
# "planter": Vector3, "yaw": float}.
static func block_front(block: Vector3) -> Dictionary:
	var c := Vector3(block.x, 0.0, block.z)
	var f := facing(block)
	var side := Vector3(f.z, 0.0, -f.x)
	return {
		"bench": c + f * TownConfig.TOWN_BENCH_OFFSET,
		"planter": c + f * TownConfig.TOWN_PLANTER_OFFSET.x + side * -TownConfig.TOWN_PLANTER_OFFSET.y,
		"yaw": yaw_toward(f),
	}
