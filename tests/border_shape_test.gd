extends GdUnitTestSuite

# The pure geometry of the line (BorderShape): inside, boxes, crossings, and the block walks. The round loop's rules
# (radii, seals, slot counts, wrap round blocks) went in 0.4 with the loop itself; the grid's own rules are in
# zone_test.gd and border_gates_test.gd.

const SQUARE_LOOP := [Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)]


func _square() -> PackedVector2Array:
	return PackedVector2Array(SQUARE_LOOP)


func _boxes() -> PackedFloat32Array:
	return PackedFloat32Array([0.0, 0.0, 6.0, 6.0])  # One 12 m block at the origin.


func test_is_inside_follows_the_loop() -> void:
	assert_bool(BorderShape.is_inside(_square(), Vector2.ZERO)).is_true()
	assert_bool(BorderShape.is_inside(_square(), Vector2(3, 0))).is_false()
	assert_bool(BorderShape.is_inside(PackedVector2Array(), Vector2.ZERO)).is_false()


func test_a_ray_hits_a_box_in_front_of_the_centre() -> void:
	var hit := BorderShape.ray_box(Vector2.ZERO, Vector2.RIGHT, Vector2(3, -1), Vector2(5, 1))
	assert_float(hit.x).is_equal_approx(3.0, 0.0001)
	assert_float(hit.y).is_equal_approx(5.0, 0.0001)
	# A ray pointing away misses, and so does one running beside the box.
	var miss := BorderShape.ray_box(Vector2.ZERO, Vector2.LEFT, Vector2(3, -1), Vector2(5, 1))
	assert_bool(miss.x == INF).is_true()
	assert_bool(BorderShape.ray_box(Vector2(0, 3), Vector2.RIGHT, Vector2(3, -1), Vector2(5, 1)).x == INF).is_true()
	assert_bool(BorderShape.ray_box(Vector2(4, 3), Vector2.UP, Vector2(3, -1), Vector2(5, 1)).x != INF).is_true()


func test_box_distance_is_zero_inside_and_the_gap_outside() -> void:
	assert_float(BorderShape.box_distance(Vector2(1, 1), Vector2.ZERO, Vector2(2, 2))).is_equal(0.0)
	assert_float(BorderShape.box_distance(Vector2(5, 0), Vector2.ZERO, Vector2(2, 2))).is_equal(3.0)
	assert_float(BorderShape.box_distance(Vector2(5, 6), Vector2.ZERO, Vector2(2, 2))).is_equal_approx(5.0, 0.001)


func test_distance_to_line_is_to_the_nearest_edge() -> void:
	assert_float(BorderShape.distance_to_line(_square(), Vector2.ZERO)).is_equal(2.0)
	assert_float(BorderShape.distance_to_line(_square(), Vector2(5, 0))).is_equal(3.0)


func test_first_crossing_finds_an_intact_stretch_and_ignores_a_mismatched_loop() -> void:
	var intact: Array[bool] = [false, false, false, false]
	var hit: Variant = BorderShape.first_crossing(_square(), intact, Vector2.ZERO, Vector2(9.0, 0.0))
	assert_bool(hit != null).is_true()
	assert_float((hit as Vector2).x).is_equal_approx(2.0, 0.001)
	var short: Array[bool] = [false]
	assert_object(BorderShape.first_crossing(_square(), short, Vector2.ZERO, Vector2(9.0, 0.0))).is_null()
	# A broken stretch (a gap) is not a crossing: the move goes through.
	var open: Array[bool] = [false, true, false, false]  # Segment 1 runs along x = 2.
	assert_object(BorderShape.first_crossing(_square(), open, Vector2.ZERO, Vector2(9.0, 0.0))).is_null()


func test_gloom_outside_an_intact_line_cannot_drain_someone_inside() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border._mark_gaps()
	var inside: Person = auto_free(Person.new())
	add_child(inside)
	inside.position = Vector3(5.0, 0.0, 0.33)
	inside.receive_joy(0, Config.JOY_MAX, 0.0)
	var dimmed: Person = auto_free(Person.new())
	add_child(dimmed)
	dimmed.position = Vector3(7.5, 0.0, 0.33)
	dimmed.gloom = 1.0
	var people: Array[Person] = [inside, dimmed]
	var before := inside.joy
	GloomSim.update(people, 0.5, PeopleConfig.TD_DRAIN_MULTIPLIER, 1.0, border)
	assert_float(inside.joy).is_equal(before)
	# The same pair with no border in the way is drained.
	GloomSim.update(people, 0.5, PeopleConfig.TD_DRAIN_MULTIPLIER, 1.0)
	assert_float(inside.joy).is_less(before)


func test_footprints_clear_of_blocks_and_block_at() -> void:
	var boxes := _boxes()
	assert_int(BorderShape.block_at(boxes, Vector2(5, 0), 0.0)).is_equal(0)
	assert_int(BorderShape.block_at(boxes, Vector2(7, 0), 0.5)).is_equal(-1)
	assert_int(BorderShape.block_at(boxes, Vector2(6.2, 0), 0.5)).is_equal(0)
	var out := BorderShape.clear_of_blocks(boxes, Vector2(5.5, 0.0), 0.8)
	assert_float(out.x).is_greater(6.7)  # Moved onto the grown block's nearest face.
	assert_vector(BorderShape.clear_of_blocks(boxes, Vector2(9, 0), 0.8)).is_equal(Vector2(9, 0))
	# With an origin it is moved out along the ray from there, to just past the far face of the grown box.
	var from_origin := BorderShape.clear_of_blocks(boxes, Vector2(5.5, 1.0), 0.8, Vector2(20, 0))
	assert_float(from_origin.x).is_less(-6.7)


func test_a_walk_through_a_block_is_blocked_and_one_beside_it_is_not() -> void:
	var boxes := _boxes()
	assert_bool(BorderShape.walk_blocked(boxes, Vector2(-9, 0), Vector2(9, 0), 0.8)).is_true()
	assert_bool(BorderShape.walk_blocked(boxes, Vector2(-9, 8), Vector2(9, 8), 0.8)).is_false()
	assert_bool(BorderShape.walk_blocked(boxes, Vector2(1, 1), Vector2(1, 1), 0.8)).is_false()
	assert_int(BorderShape.first_blocker(boxes, Vector2(-9, 0), Vector2(9, 0), 0.8)).is_equal(0)
	assert_int(BorderShape.first_blocker(boxes, Vector2(-9, 8), Vector2(9, 8), 0.8)).is_equal(-1)


func test_a_person_walks_round_a_block_and_arrives_on_the_far_side() -> void:
	var boxes := _boxes()
	var pos := Vector2(-9, 0)
	var target := Vector2(9, 0)
	var way := Vector2.INF
	for i: int in range(600):
		var res := BorderShape.step_around(boxes, pos, target, 0.1, 0.8, way)
		pos = res["pos"]
		way = res["waypoint"]
		assert_int(BorderShape.block_at(boxes, pos, 0.7)).is_equal(-1)
	assert_float(pos.distance_to(target)).is_less(0.5)
	# Already at the target: it stays.
	var stay := BorderShape.step_around(boxes, target, target, 0.1, 0.8, Vector2.INF)
	assert_vector(stay["pos"] as Vector2).is_equal(target)


func test_footprints_list_four_numbers_per_building() -> void:
	var b := Building.new()
	b.centre = Vector2(3, 4)
	b.half = Vector2(6, 6)
	var list: Array[Building] = [b]
	assert_array(Array(BorderShape.footprints(list))).is_equal([3.0, 4.0, 6.0, 6.0])


func test_no_cover_without_a_line_and_the_debug_labels_hide_again() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	assert_float(border.cover_at(Vector3.ZERO)).is_equal(0.0)
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border.set_debug(true)
	assert_int(border.visible_debug_label_count()).is_equal(4)
	border.set_debug(false)
	assert_int(border.visible_debug_label_count()).is_equal(0)


func test_a_walk_with_every_way_round_shut_stays_where_it_is() -> void:
	# A block between the walker and the target, and two thin walls across the way to each of its far corners.
	var boxes := PackedFloat32Array([0.0, 0.0, 1.0, 1.0, -3.0, 1.9, 3.0, 0.05, -3.0, -1.9, 3.0, 0.05])
	var from := Vector2(-1.85, 0.0)  # Just outside the block's grown box (1 + 0.8 each way).
	var res := BorderShape.step_around(boxes, from, Vector2(3.0, 0.0), 0.2, 0.8, Vector2.INF)
	assert_vector(res["pos"] as Vector2).is_equal(from)
	assert_bool((res["waypoint"] as Vector2) == Vector2.INF).is_true()
	assert_int(BorderShape.first_blocker(boxes, from, from, 0.8)).is_equal(-1)
