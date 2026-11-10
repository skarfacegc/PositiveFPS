class_name TownLayout
extends RefCounted

# 0.4 (#55): the props' view of the town grid (TownGrid). Four streets run along x and four along z between the five
# rows and columns of cells; the middle cell is the start square (stalls on it), the four diagonal cells next to it are
# the landmark squares, and the other twenty are built blocks (Plaza.BLOCK_POSITIONS) that face the start. This script
# answers questions about that plan for the props (lamps along the block faces, benches and planters in front of the
# blocks, stalls on the start square) and for the tests. It only reads positions: it adds no rules.


# The eight streets as ground rectangles (x, z): the four running along x first, then the four running along z.
static func street_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var span := TownGrid.span()
	for k: int in range(TownConfig.TOWN_GRID_CELLS - 1):
		var tile := 2 * k + 1
		var r := TownGrid.tile_rect(tile, 0)
		out.append(Rect2(-span * 0.5, r.position.x, span, r.size.x))
	for k: int in range(TownConfig.TOWN_GRID_CELLS - 1):
		var tile := 2 * k + 1
		var r := TownGrid.tile_rect(tile, 0)
		out.append(Rect2(r.position.x, -span * 0.5, r.size.x, span))
	return out


# True when the ground point `at` lies on a street, or within `margin` metres of one.
static func on_street(at: Vector3, margin: float = 0.0) -> bool:
	for r: Rect2 in street_rects():
		if r.grow(margin).has_point(Vector2(at.x, at.z)):
			return true
	return false


# True when `at` is on the start square.
static func on_square(at: Vector3) -> bool:
	return TownGrid.cell_rect(TownGrid.start_cell()).has_point(Vector2(at.x, at.z))


# The unit direction (on the ground) from a block toward the start along the axis it is farther from: the face a
# bench and a planter stand against.
static func facing(block: Vector3) -> Vector3:
	if absf(block.z) >= absf(block.x) and block.z != 0.0:
		return Vector3(0.0, 0.0, -signf(block.z))
	if block.x != 0.0:
		return Vector3(-signf(block.x), 0.0, 0.0)
	return Vector3(0.0, 0.0, 1.0)


# The turn (radians about the vertical axis) that points a prop's local +z along `dir`.
static func yaw_toward(dir: Vector3) -> float:
	return atan2(dir.x, dir.z)


# The lamp spots: against the block faces, in the kerb strip of every street, one per face of each street piece, at the
# middle of the cell the piece runs along (TOWN_KERB_OFFSET from the street's centre line).
static func lamp_spots() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k: int in range(TownConfig.TOWN_GRID_CELLS - 1):
		var line := TownGrid.tile_rect(2 * k + 1, 0).get_center().x
		for j: int in range(TownConfig.TOWN_GRID_CELLS):
			var along := TownGrid.cell_centre(Vector2i(j, j)).x
			for side: float in [-1.0, 1.0]:
				out.append(Vector3(line + side * TownConfig.TOWN_KERB_OFFSET, 0.0, along))  # street running along z
				out.append(Vector3(along, 0.0, line + side * TownConfig.TOWN_KERB_OFFSET))  # street running along x
	return out


# The stall spots on the start square: its four corners, each turned toward the start.
static func stall_spots() -> Array[Vector3]:
	var d := TownConfig.TOWN_STALL_OFFSET
	return [Vector3(d, 0.0, d), Vector3(-d, 0.0, d), Vector3(d, 0.0, -d), Vector3(-d, 0.0, -d)]


# Where a block's bench and planter stand: in front of the block, against its face toward the start. Returns {"bench":
# Vector3, "planter": Vector3, "yaw": float}.
static func block_front(block: Vector3) -> Dictionary:
	var c := Vector3(block.x, 0.0, block.z)
	var f := facing(block)
	var side := Vector3(f.z, 0.0, -f.x)
	return {
		"bench": c + f * TownConfig.TOWN_BENCH_OFFSET,
		"planter": c + f * TownConfig.TOWN_PLANTER_OFFSET.x + side * -TownConfig.TOWN_PLANTER_OFFSET.y,
		"yaw": yaw_toward(f),
	}
