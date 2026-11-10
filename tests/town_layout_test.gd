extends GdUnitTestSuite

# 0.4 (#55): the town is a 5 x 5 grid of 12 m cells with 10 m streets between them (TownGrid). The middle cell is the
# start square, the four diagonal cells next to it are the landmark squares and the other twenty are solid built blocks.
# Everything can be walked to, and the grid has loops. TownLayout answers the props' questions (lamps, benches, stalls).


func _blocks() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(Plaza.BLOCK_POSITIONS)
	return out


func test_the_grid_fills_the_plaza_and_has_twenty_blocks_five_squares() -> void:
	assert_float(TownGrid.span()).is_equal(float(Config.TD_PLAZA_SIZE))
	assert_int(TownGrid.all_cells().size()).is_equal(25)
	assert_int(TownGrid.block_cells().size()).is_equal(20)
	assert_int(TownGrid.tiles()).is_equal(9)
	assert_that(TownGrid.start_cell()).is_equal(Vector2i(2, 2))
	assert_int(TownGrid.kind_of(Vector2i(2, 2))).is_equal(TownGrid.Kind.START)
	assert_bool(TownGrid.is_block(Vector2i(2, 2))).is_false()
	var squares := 0
	for c: Vector2i in TownGrid.all_cells():
		if not TownGrid.is_block(c):
			squares += 1
	assert_int(squares).is_equal(5)


func test_cells_are_twelve_metres_with_ten_metre_streets_between() -> void:
	var a := TownGrid.cell_rect(Vector2i(0, 0))
	var b := TownGrid.cell_rect(Vector2i(1, 0))
	assert_vector(a.size).is_equal(Vector2(12.0, 12.0))
	assert_float(b.position.x - (a.position.x + a.size.x)).is_equal(10.0)
	assert_float(a.position.x).is_equal(-50.0)
	assert_float(TownGrid.cell_rect(Vector2i(4, 4)).end.x).is_equal(50.0)
	assert_vector(TownGrid.cell_centre(Vector2i(2, 2))).is_equal(Vector3.ZERO)


func test_the_landmark_squares_are_the_diagonals_next_to_the_start() -> void:
	assert_int(TownConfig.TOWN_LANDMARK_CELLS.size()).is_equal(LandmarkConfig.LANDMARK_NAMES.size())
	for k: int in range(TownConfig.TOWN_LANDMARK_CELLS.size()):
		var c := TownConfig.TOWN_LANDMARK_CELLS[k]
		assert_int(absi(c.x - 2)).is_equal(1)
		assert_int(absi(c.y - 2)).is_equal(1)
		assert_int(TownGrid.landmark_index(c)).is_equal(k)
		assert_vector(LandmarkConfig.LANDMARK_POSITIONS[k]).is_equal(TownGrid.cell_centre(c))
		assert_float(TownGrid.cell_centre(c).length()).is_equal_approx(31.1, 0.1)


func test_the_block_list_is_the_grid_and_blocks_stand_apart_inside_the_walls() -> void:
	var blocks := _blocks()
	var cells := TownGrid.block_cells()
	assert_int(blocks.size()).is_equal(cells.size())
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	for i: int in range(cells.size()):
		var c := TownGrid.cell_centre(cells[i])
		assert_float(blocks[i].x).is_equal(c.x)
		assert_float(blocks[i].z).is_equal(c.z)
		assert_float(absf(blocks[i].x) + Plaza.BLOCK_SIZE.x * 0.5).is_less_equal(half)
		for j: int in range(i + 1, cells.size()):
			var dx := absf(blocks[i].x - blocks[j].x)
			var dz := absf(blocks[i].z - blocks[j].z)
			# A 10 m street between two blocks, on one axis or the other.
			assert_bool(dx >= Plaza.BLOCK_SIZE.x + 10.0 - 0.01 or dz >= Plaza.BLOCK_SIZE.z + 10.0 - 0.01).is_true()


func test_neighbours_tiles_and_the_nearest_cell() -> void:
	assert_int(TownGrid.neighbours(Vector2i(0, 0)).size()).is_equal(2)
	assert_int(TownGrid.neighbours(Vector2i(2, 0)).size()).is_equal(3)
	assert_int(TownGrid.neighbours(Vector2i(2, 2)).size()).is_equal(4)
	assert_bool(TownGrid.in_grid(Vector2i(5, 0))).is_false()
	assert_that(TownGrid.cell_of(Vector3(0, 0, 0))).is_equal(Vector2i(2, 2))
	assert_that(TownGrid.cell_of(Vector3(-40, 0, 45))).is_equal(Vector2i(0, 4))
	assert_that(TownGrid.cell_of(Vector3(60, 0, -60))).is_equal(Vector2i(4, 0))
	assert_that(TownGrid.tile_of(Vector3(0, 0, 0))).is_equal(Vector2i(4, 4))
	assert_that(TownGrid.tile_of(Vector3(-33, 0, 0))).is_equal(Vector2i(1, 4))
	assert_bool(TownGrid.tile_walkable(0, 0)).is_false()  # A built block.
	assert_bool(TownGrid.tile_walkable(4, 4)).is_true()  # The start square.
	assert_bool(TownGrid.tile_walkable(1, 0)).is_true()  # A street piece.
	assert_bool(TownGrid.tile_walkable(-1, 0)).is_false()
	assert_vector(TownGrid.tile_centre(1, 1)).is_equal(Vector3(-33, 0, -33))
	assert_that(TownGrid.tile_of(Vector3(60, 0, 70))).is_equal(Vector2i(8, 8))  # Off the town: the last tile.


# A flood fill over the walkable tiles: every one is reached from the start, and the grid has loops everywhere (more
# tile-to-tile links than a tree would have), so there is no out and back through the middle.
func test_every_walkable_tile_can_be_walked_to_and_the_streets_have_loops() -> void:
	var seen := {Vector2i(4, 4): true}
	var queue: Array[Vector2i] = [Vector2i(4, 4)]
	var head := 0
	var links := 0
	while head < queue.size():
		var cur := queue[head]
		head += 1
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cur + step
			if not TownGrid.tile_walkable(next.x, next.y):
				continue
			links += 1
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	var walkable := 0
	for tx: int in range(TownGrid.tiles()):
		for tz: int in range(TownGrid.tiles()):
			if TownGrid.tile_walkable(tx, tz):
				walkable += 1
	assert_int(seen.size()).is_equal(walkable)
	assert_float(float(links) / 2.0).is_greater(float(walkable - 1 + 10))


func test_streets_and_the_start_square_are_where_the_props_expect() -> void:
	assert_int(TownLayout.street_rects().size()).is_equal(8)
	assert_bool(TownLayout.on_street(Vector3(-33, 0, 7))).is_true()
	assert_bool(TownLayout.on_street(Vector3(-44, 0, 0))).is_false()
	assert_bool(TownLayout.on_street(Vector3(-44, 0, 0), 12.0)).is_true()
	assert_bool(TownLayout.on_square(Vector3.ZERO)).is_true()
	assert_bool(TownLayout.on_square(Vector3(20, 0, 0))).is_false()
	for c: Vector3 in TownLayout.stall_spots():
		assert_bool(TownLayout.on_square(c)).is_true()


func test_the_facing_turns_each_block_toward_the_start_along_its_far_axis() -> void:
	assert_vector(TownLayout.facing(Vector3(22, 1, -44))).is_equal(Vector3(0, 0, 1))
	assert_vector(TownLayout.facing(Vector3(0, 1, 44))).is_equal(Vector3(0, 0, -1))
	assert_vector(TownLayout.facing(Vector3(44, 1, 0))).is_equal(Vector3(-1, 0, 0))
	assert_vector(TownLayout.facing(Vector3(-22, 1, 0))).is_equal(Vector3(1, 0, 0))
	assert_float(TownLayout.yaw_toward(Vector3(0, 0, 1))).is_equal_approx(0.0, 0.001)
	assert_float(TownLayout.yaw_toward(Vector3(1, 0, 0))).is_equal_approx(PI / 2.0, 0.001)
	assert_vector(TownLayout.facing(Vector3(0, 1, 0))).is_equal(Vector3(0, 0, 1))


func test_benches_planters_and_lamps_stand_against_block_faces_not_in_the_street_middle() -> void:
	for c: Vector3 in _blocks():
		var front := TownLayout.block_front(c)
		for key: String in ["bench", "planter"]:
			var at: Vector3 = front[key]
			assert_bool(absf(at.x - c.x) < 6.0 and absf(at.z - c.z) < 6.0).is_false()  # Outside the block itself.
			assert_bool(TownLayout.on_street(at, 0.5)).is_true()
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	var spots := TownLayout.lamp_spots()
	assert_int(spots.size()).is_equal(80)
	for at: Vector3 in spots:
		assert_float(absf(at.x)).is_less(half)
		assert_float(absf(at.z)).is_less(half)
		assert_bool(TownLayout.on_street(at)).is_true()
		for c: Vector3 in _blocks():
			assert_bool(absf(at.x - c.x) < 6.0 and absf(at.z - c.z) < 6.0).is_false()
