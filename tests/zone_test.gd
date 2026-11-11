extends GdUnitTestSuite

# 0.4 (#55, #56): the zone is the set of held town cells and its line is the zone's outline, split into walls (the face
# of a held built block, the map's edge) and gates (an open side of a held square, a street mouth). Scene-free: Zone is
# pure rules over TownGrid.

const EAST_BLOCK := Vector2i(3, 2)


func _wall_length(z: Zone) -> float:
	var total := 0.0
	for run: Dictionary in z.runs:
		if not run["gate"]:
			var a: Vector2 = run["a"]
			var b: Vector2 = run["b"]
			total += a.distance_to(b)
	return total


func _gate_length(z: Zone) -> float:
	var total := 0.0
	for g: Dictionary in z.gates:
		total += g["length"] as float
	return total


func _grown(cells: Array[Vector2i]) -> Zone:
	var z := Zone.new()
	for c: Vector2i in cells:
		z.take(c)
	return z


func test_the_zone_starts_as_the_start_square_with_four_open_sides() -> void:
	var z := Zone.new()
	assert_int(z.held.size()).is_equal(1)
	assert_bool(z.has(TownGrid.start_cell())).is_true()
	assert_int(z.runs.size()).is_equal(4)
	assert_int(z.gates.size()).is_equal(4)
	assert_float(_wall_length(z)).is_equal(0.0)
	for g: Dictionary in z.gates:
		assert_float(g["length"] as float).is_equal(18.0)
		assert_int(g["need"] as int).is_equal(5)  # 18 m over 3.7 m: the start square's side asks for 5.
	assert_int(z.members_needed()).is_equal(20)
	assert_vector(z.centre()).is_equal(Vector3.ZERO)
	assert_bool(z.contains(Vector3(5, 0, 5))).is_true()
	assert_bool(z.contains(Vector3(12, 0, 0))).is_false()


func test_gate_normals_point_out_of_the_zone() -> void:
	var z := Zone.new()
	for g: Dictionary in z.gates:
		var mid: Vector2 = g["mid"]
		var out: Vector2 = g["out"]
		assert_float(out.length()).is_equal_approx(1.0, 0.001)
		assert_bool(z.contains(Vector3(mid.x - out.x, 0.0, mid.y - out.y))).is_true()
		assert_bool(z.contains(Vector3(mid.x + out.x, 0.0, mid.y + out.y))).is_false()


func test_a_cell_can_be_taken_only_next_to_the_zone() -> void:
	var z := Zone.new()
	assert_bool(z.can_take(EAST_BLOCK)).is_true()
	assert_bool(z.can_take(Vector2i(2, 1))).is_true()
	assert_bool(z.can_take(Vector2i(3, 3))).is_false()  # Only touching at a corner.
	assert_bool(z.can_take(Vector2i(0, 0))).is_false()
	assert_bool(z.can_take(Vector2i(2, 2))).is_false()  # Held already.
	assert_bool(z.can_take(Vector2i(9, 9))).is_false()
	assert_int(z.take(Vector2i(0, 0)).size()).is_equal(0)
	assert_int(z.held.size()).is_equal(1)


func test_taking_a_block_adds_walls_a_street_between_and_two_street_mouths() -> void:
	var z := Zone.new()
	var before := z.version
	var added := z.take(EAST_BLOCK)
	assert_int(added.size()).is_equal(1)
	assert_int(z.version).is_greater(before)
	assert_int(z.held.size()).is_equal(2)
	assert_bool(z.contains(Vector3(15, 0, 0))).is_true()  # The street piece between the two held cells.
	assert_bool(z.contains(Vector3(27, 0, 0))).is_true()
	# Gates: the start square's west, north and south sides (18 m), and the street's north and south mouths (12 m).
	assert_int(z.gates.size()).is_equal(5)
	assert_float(_gate_length(z)).is_equal(18.0 + 18.0 + 18.0 + 12.0 + 12.0)
	assert_int(z.members_needed()).is_equal(5 + 5 + 5 + 4 + 4)  # The street mouths ask for 4, a start side 5.
	# Walls: the block's three outer faces (12 + 18 + 12 m).
	assert_float(_wall_length(z)).is_equal(42.0)
	for run: Dictionary in z.runs:
		if not run["gate"]:
			var a: Vector2 = run["a"]
			assert_float(a.x).is_greater_equal(21.0 - 0.001)  # Only the block's faces are wall.


func test_a_built_blocks_face_is_a_wall_and_an_open_squares_face_is_a_gate() -> void:
	var landmark := Vector2i(3, 1)
	var block := Vector2i(2, 1)
	var z := _grown([block])  # The block north of the start: its three outer faces are wall, none of them a gate.
	assert_float(_wall_length(z)).is_equal(42.0)
	for g: Dictionary in z.gates:
		assert_bool(TownGrid.cell_rect(block).grow(-0.01).has_point(g["mid"] as Vector2)).is_false()
	z.take(landmark)  # The Bandstand square east of the block: its three outer sides are open, so gates.
	var square_gates := 0
	for g: Dictionary in z.gates:
		var mid: Vector2 = g["mid"]
		if TownGrid.cell_rect(landmark).grow(0.01).has_point(mid):
			square_gates += 1
	assert_int(square_gates).is_equal(3)
	assert_float(_wall_length(z)).is_equal(30.0)  # The block's north (18 m) and west (12 m) faces only.


func test_the_map_edge_is_a_wall() -> void:
	var z := _grown([Vector2i(2, 1), Vector2i(2, 0)])
	var found := false
	for run: Dictionary in z.runs:
		var a: Vector2 = run["a"]
		var b: Vector2 = run["b"]
		var edge := -TownGrid.span() * 0.5
		if is_equal_approx(a.y, edge) and is_equal_approx(b.y, edge):
			found = true
			assert_bool(run["gate"] as bool).is_false()
	assert_bool(found).is_true()


func test_gate_keys_stay_the_same_while_the_gate_does_and_split_square_side_from_street_mouth() -> void:
	var z := Zone.new()
	var north_before := ""
	for g: Dictionary in z.gates:
		if (g["mid"] as Vector2).y < -5.0:
			north_before = g["key"] as String
	z.take(EAST_BLOCK)
	var keys: Array[String] = []
	for g: Dictionary in z.gates:
		keys.append(g["key"] as String)
	assert_bool(keys.has(north_before)).is_true()
	# Five distinct gates: the square's north side and the street's north mouth do not merge into one 22 m gate.
	var seen: Dictionary = {}
	for k: String in keys:
		seen[k] = true
	assert_int(seen.size()).is_equal(5)


func test_preview_shows_the_gates_a_change_opens_and_closes_and_changes_nothing() -> void:
	var z := Zone.new()
	var version := z.version
	var p := z.preview(EAST_BLOCK)
	assert_bool(p["valid"] as bool).is_true()
	assert_int((p["opened"] as Array).size()).is_equal(2)  # The street's two mouths.
	assert_int((p["closed"] as Array).size()).is_equal(1)  # The start square's east side.
	assert_int((p["gates"] as Array).size()).is_equal(5)
	assert_int(p["members_needed"] as int).is_equal(23)
	assert_int(p["members_added"] as int).is_equal(3)
	assert_int((p["cells"] as Array).size()).is_equal(2)
	assert_int(z.version).is_equal(version)
	assert_int(z.held.size()).is_equal(1)
	var bad := z.preview(Vector2i(0, 0))
	assert_bool(bad["valid"] as bool).is_false()
	assert_int(bad["members_added"] as int).is_equal(0)
	assert_int((bad["opened"] as Array).size()).is_equal(0)


func test_a_block_taken_between_two_held_ones_closes_gates_and_asks_for_fewer_members() -> void:
	var z := _grown([Vector2i(2, 1), Vector2i(1, 2)])
	var p := z.preview(Vector2i(1, 1))  # The Garden square, between the block and the street piece.
	assert_bool(p["valid"] as bool).is_true()
	assert_int((p["closed"] as Array).size()).is_greater(0)


func test_a_cell_the_zone_surrounds_joins_by_itself() -> void:
	var z := _grown([Vector2i(1, 2), Vector2i(0, 2), Vector2i(0, 1), Vector2i(2, 1), Vector2i(2, 0)])
	assert_bool(z.has(Vector2i(1, 1))).is_false()
	var preview := z.preview(Vector2i(1, 0))
	assert_int((preview["added"] as Array).size()).is_equal(3)
	var added := z.take(Vector2i(1, 0))
	# The Garden square is ringed on all four sides, and the corner cell on both of its.
	assert_bool(added.has(Vector2i(1, 1))).is_true()
	assert_bool(added.has(Vector2i(0, 0))).is_true()
	assert_bool(z.has(Vector2i(1, 1))).is_true()
	assert_bool(z.has(Vector2i(0, 0))).is_true()
	assert_int(z.held.size()).is_equal(9)


func test_losing_a_cell_loses_what_it_cut_off_and_never_the_start_square() -> void:
	var z := _grown([EAST_BLOCK, Vector2i(4, 2)])
	assert_int(z.held.size()).is_equal(3)
	assert_int(z.lose(TownGrid.start_cell()).size()).is_equal(0)
	assert_int(z.lose(Vector2i(0, 0)).size()).is_equal(0)  # Not held.
	var lost := z.lose(EAST_BLOCK)
	assert_int(lost.size()).is_equal(2)  # The block, and the one behind it that is cut off.
	assert_bool(lost.has(Vector2i(4, 2))).is_true()
	assert_int(z.held.size()).is_equal(1)
	assert_int(z.gates.size()).is_equal(4)
	# A loss can be previewed too.
	var z2 := _grown([EAST_BLOCK])
	var p := z2.preview(EAST_BLOCK, false)
	assert_bool(p["valid"] as bool).is_true()
	assert_int((p["cells"] as Array).size()).is_equal(1)
	assert_int(p["members_added"] as int).is_equal(20 - 23)
	assert_bool(z2.preview(TownGrid.start_cell(), false)["valid"] as bool).is_false()


func test_the_zone_does_not_contain_what_is_off_the_town_and_an_empty_zone_has_no_outline() -> void:
	assert_bool(Zone.new().contains(Vector3(60, 0, 0))).is_false()
	var none: Array[Vector2i] = []
	var traced := Zone.outline(none)
	assert_int((traced["runs"] as Array).size()).is_equal(0)
	assert_int((traced["gates"] as Array).size()).is_equal(0)


func test_losing_a_cell_keeps_the_rest_that_is_still_joined_to_the_start() -> void:
	var z := _grown([Vector2i(1, 2), Vector2i(2, 1)])
	var lost := z.lose(Vector2i(1, 2))
	assert_int(lost.size()).is_equal(1)
	assert_bool(z.has(Vector2i(2, 1))).is_true()
	assert_int(z.held.size()).is_equal(2)


func test_open_ground_is_the_squares_and_the_street_pieces_not_the_blocks() -> void:
	var z := Zone.new()
	assert_int(z.open_rects().size()).is_equal(1)
	z.take(EAST_BLOCK)
	var rects := z.open_rects()
	assert_int(rects.size()).is_equal(2)
	for r: Rect2 in rects:
		assert_bool(r.has_point(Vector2(22, 0))).is_false()  # Not inside the block.
	assert_bool(z.nearest_gate(Vector2(-7, 0)).is_empty()).is_false()
	assert_vector((z.nearest_gate(Vector2(-7, 0)))["out"] as Vector2).is_equal(Vector2(-1, 0))


func test_the_whole_town_has_no_gates_and_only_wall() -> void:
	var z := Zone.new()
	var order: Array[Vector2i] = []
	for c: Vector2i in TownGrid.all_cells():
		order.append(c)
	var guard := 0
	while z.held.size() < 25 and guard < 100:
		guard += 1
		for c: Vector2i in order:
			if z.can_take(c):
				z.take(c)
	assert_int(z.held.size()).is_equal(25)
	assert_int(z.gates.size()).is_equal(0)
	assert_float(_wall_length(z)).is_equal(456.0)  # 4 x 114 m.
	assert_int(z.members_needed()).is_equal(0)
