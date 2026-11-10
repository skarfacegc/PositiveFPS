class_name TownGrid
extends RefCounted

# Walls and gates: Grid (0.4, #55). The plan of the town: TownConfig.TOWN_GRID_CELLS squared cells (built blocks, the
# start square and the landmark squares) with streets between them. It is a lattice of 2 x cells - 1 tiles on each
# axis: an even tile is a cell column (or row), an odd tile a street. A tile (tx, tz) is a cell when both are even, an
# intersection when both are odd and a street piece otherwise. A cell is a Vector2i (column, row), 0 .. cells - 1,
# column along x and row along z; the tile of cell (c, r) is (2c, 2r). Pure functions of the config: no state.

enum Kind { BLOCK, START, LANDMARK }  # A START or LANDMARK cell is an open square.


# The number of tiles along one axis.
static func tiles() -> int:
	return 2 * TownConfig.TOWN_GRID_CELLS - 1


# The side of the whole town in metres (it is the plaza: 5 x 12 + 4 x 10 = 100).
static func span() -> float:
	var n := float(TownConfig.TOWN_GRID_CELLS)
	return n * TownConfig.TOWN_CELL_SIZE + (n - 1.0) * TownConfig.TOWN_STREET_WIDTH


# The coordinate where tile `i` starts along an axis (the town is centred on the origin).
static func tile_lo(i: int) -> float:
	var at := -span() * 0.5
	for k: int in range(i):
		at += TownConfig.TOWN_CELL_SIZE if k % 2 == 0 else TownConfig.TOWN_STREET_WIDTH
	return at


static func tile_hi(i: int) -> float:
	return tile_lo(i) + (TownConfig.TOWN_CELL_SIZE if i % 2 == 0 else TownConfig.TOWN_STREET_WIDTH)


# The ground rectangle (x, z) of tile (tx, tz).
static func tile_rect(tx: int, tz: int) -> Rect2:
	var x0 := tile_lo(tx)
	var z0 := tile_lo(tz)
	return Rect2(x0, z0, tile_hi(tx) - x0, tile_hi(tz) - z0)


static func in_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < TownConfig.TOWN_GRID_CELLS and c.y < TownConfig.TOWN_GRID_CELLS


static func start_cell() -> Vector2i:
	var mid := TownConfig.TOWN_GRID_CELLS >> 1
	return Vector2i(mid, mid)


# Which landmark (LandmarkConfig.LANDMARK_NAMES order) stands on the square `c`, or -1.
static func landmark_index(c: Vector2i) -> int:
	return TownConfig.TOWN_LANDMARK_CELLS.find(c)


static func kind_of(c: Vector2i) -> Kind:
	if c == start_cell():
		return Kind.START
	if landmark_index(c) >= 0:
		return Kind.LANDMARK
	return Kind.BLOCK


# True for a built block (solid); false for the start square and the landmark squares (open ground).
static func is_block(c: Vector2i) -> bool:
	return kind_of(c) == Kind.BLOCK


# The ground rectangle of cell `c`.
static func cell_rect(c: Vector2i) -> Rect2:
	return tile_rect(2 * c.x, 2 * c.y)


# The middle of cell `c` on the ground (y = 0).
static func cell_centre(c: Vector2i) -> Vector3:
	var r := cell_rect(c)
	var mid := r.get_center()
	return Vector3(mid.x, 0.0, mid.y)


# The cells that share a street with `c`, east, west, south (+z), north; only those inside the grid.
static func neighbours(c: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if in_grid(c + step):
			out.append(c + step)
	return out


# Every cell, row by row.
static func all_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r: int in range(TownConfig.TOWN_GRID_CELLS):
		for c: int in range(TownConfig.TOWN_GRID_CELLS):
			out.append(Vector2i(c, r))
	return out


# The built blocks' cells, row by row.
static func block_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for c: Vector2i in all_cells():
		if is_block(c):
			out.append(c)
	return out


# The cell whose middle is nearest to a ground point (an unrescued person belongs to it).
static func cell_of(pos: Vector3) -> Vector2i:
	var period := TownConfig.TOWN_CELL_SIZE + TownConfig.TOWN_STREET_WIDTH
	var shift := span() * 0.5 + TownConfig.TOWN_STREET_WIDTH * 0.5
	var col := clampi(floori((pos.x + shift) / period), 0, TownConfig.TOWN_GRID_CELLS - 1)
	var row := clampi(floori((pos.z + shift) / period), 0, TownConfig.TOWN_GRID_CELLS - 1)
	return Vector2i(col, row)


# The tile a ground point lies in (clamped onto the town).
static func tile_of(pos: Vector3) -> Vector2i:
	return Vector2i(_tile_along(pos.x), _tile_along(pos.z))


static func _tile_along(v: float) -> int:
	for i: int in range(tiles()):
		if v < tile_hi(i):
			return i
	return tiles() - 1


# True when tile (tx, tz) can be walked on: everything but a built block.
static func tile_walkable(tx: int, tz: int) -> bool:
	if tx < 0 or tz < 0 or tx >= tiles() or tz >= tiles():
		return false
	if tx % 2 == 0 and tz % 2 == 0:
		return not is_block(Vector2i(tx >> 1, tz >> 1))
	return true


# The middle of tile (tx, tz) on the ground.
static func tile_centre(tx: int, tz: int) -> Vector3:
	var mid := tile_rect(tx, tz).get_center()
	return Vector3(mid.x, 0.0, mid.y)
