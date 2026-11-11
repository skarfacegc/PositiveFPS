extends GdUnitTestSuite

# 0.4 (#56): members on gates, the traced line's accessors, and dimmed people heading for the nearest gate along the
# streets. Unit checks use a bare Border holding the start square; the level checks settle 16 rescued people on it.

const EAST_BLOCK := Vector2i(3, 2)


func _bare_border(cells: Array[Vector2i] = []) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	for c: Vector2i in cells:
		border.zone.take(c)
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border._mark_gaps()
	return border


func _rescued(count: int) -> Array[Person]:
	var out: Array[Person] = []
	for i: int in range(count):
		var p: Person = auto_free(Person.new())
		add_child(p)
		p.is_rescued = true
		p.position = Vector3(float(i % 5) - 2.0, 0.0, floorf(float(i) / 5.0) - 1.0)
		out.append(p)
	return out


func test_members_are_shared_out_between_gates_in_proportion() -> void:
	assert_array(BorderSlots.share_out([4, 4, 4, 4], 16)).is_equal([4, 4, 4, 4])
	assert_array(BorderSlots.share_out([4, 4, 4, 4], 3)).is_equal([1, 1, 1, 0])
	assert_array(BorderSlots.share_out([4, 4, 4, 4], 0)).is_equal([0, 0, 0, 0])
	assert_array(BorderSlots.share_out([4, 4, 4, 4], 99)).is_equal([4, 4, 4, 4])  # Never more than a gate needs.
	assert_array(BorderSlots.share_out([4, 3, 3], 5)).is_equal([2, 2, 1])
	var uneven := BorderSlots.share_out([6, 3, 3, 4, 4], 10)
	var sum := 0
	for k: int in uneven:
		sum += k
	assert_int(sum).is_equal(10)


func test_a_gates_points_and_places_follow_its_length() -> void:
	var border := _bare_border()
	for g: Dictionary in border.zone.gates:
		var id: int = g["id"]
		var mid: Vector2 = g["mid"]
		assert_vector(border.gate_point(id, 0.5)).is_equal_approx(mid, Vector2(0.001, 0.001))
		var a: Vector2 = g["a"]
		assert_vector(border.gate_point(id, 0.0)).is_equal_approx(a, Vector2(0.001, 0.001))
		assert_int(border.point_gate(border.nearest_point(border.gate_point(id, 0.25)))).is_equal(id)
	# Nothing to stand on: the middle of the zone.
	assert_vector(border.gate_point(99, 0.5)).is_equal(Vector2.ZERO)


func test_walls_and_gates_are_told_apart_segment_by_segment() -> void:
	var border := _bare_border([EAST_BLOCK])
	var walls := 0
	for j: int in range(border.polygon.size()):
		if border.is_wall(j):
			walls += 1
			assert_int(border.segment_gate(j)).is_equal(-1)
		else:
			assert_int(border.segment_gate(j)).is_greater_equal(0)
	assert_int(walls).is_equal(3)  # The block's three faces: each is one segment (a wall needs no points).
	var near_wall := border.nearest_point(Vector2(33.0, 0.0))
	assert_bool(border.point_dentable(near_wall)).is_false()
	assert_int(border.point_gate(near_wall)).is_equal(-1)
	assert_bool(border.is_wall(-1)).is_false()
	assert_bool(border.is_wall(500)).is_false()
	assert_int(border.segment_gate(500)).is_equal(-1)
	assert_int(border.point_gate(500)).is_equal(-1)
	assert_bool(border.point_dentable(500)).is_false()


func test_the_way_out_of_the_zone_is_the_nearest_gates_normal() -> void:
	var border := _bare_border()
	assert_vector(border.out_at(Vector3(8, 0, 0))).is_equal(Vector2(1, 0))
	assert_vector(border.out_at(Vector3(-8, 0, 1))).is_equal(Vector2(-1, 0))
	assert_vector(border.out_at(Vector3(1, 0, -8))).is_equal(Vector2(0, -1))
	assert_vector(border.out_at(Vector3(0, 0, 8))).is_equal(Vector2(0, 1))


func test_the_line_is_traced_again_when_the_zone_changes_and_members_keep_to_the_gates() -> void:
	var border := _bare_border()
	var people := _rescued(16)
	border.update(people, 1.0 / 60.0, 1.0)
	assert_int(border.member_count).is_equal(16)  # 16 people for the start square's 20 places: shared out.
	var before := border.polygon.size()
	border.zone.take(EAST_BLOCK)
	border.update(people, 1.0 / 60.0, 1.0)
	assert_int(border.polygon.size()).is_not_equal(before)
	assert_int(border.slot_count).is_equal(23)
	assert_int(border.member_count).is_equal(16)  # 16 people for 23 places: shared out, none left over.
	assert_int(border.inner_count).is_equal(0)
	for m: Person in border.members:
		var target: Vector3 = border._targets[m]
		assert_float(BorderShape.distance_to_line(border.polygon, Vector2(target.x, target.z))).is_less(0.01)
		assert_bool(border.is_wall(border.nearest_point(Vector2(target.x, target.z)))).is_false()
	# More people than places: the rest are inner and inside.
	var many := _rescued(26)
	border.update(many, 1.0 / 60.0, 1.0)
	assert_int(border.member_count).is_equal(23)
	assert_int(border.inner_count).is_equal(3)
	assert_float(border.perimeter).is_equal(78.0)  # Three 18 m gates and two 12 m street mouths.


func test_a_dimmed_person_outside_heads_round_the_blocks_toward_the_nearest_gate() -> void:
	var border := _bare_border()
	# In the street west of the square, with a block between them and the west gate: the way is round, by the south.
	var go := border.route_to_gate(Vector3(-39.0, 0.0, 0.0))
	assert_float(go.length()).is_equal_approx(1.0, 0.001)
	assert_float(go.z).is_greater(0.9)
	# Walk the route: each step moves toward the next tile's middle, and it ends at the gate's mouth.
	var pos := Vector3(-39.0, 0.0, 0.0)
	for i: int in range(400):
		var dir := border.route_to_gate(pos)
		if dir == Vector3.ZERO:
			break
		pos += dir * 0.5
		assert_bool(TownGrid.tile_walkable(TownGrid.tile_of(pos).x, TownGrid.tile_of(pos).y)).is_true()
	# It ends within reach of a gate's mouth, where the walk goes straight on.
	var at := Vector2(pos.x, pos.z)
	var gate := border.zone.nearest_gate(at)
	var closest := Geometry2D.get_closest_point_to_segment(at, gate["a"] as Vector2, gate["b"] as Vector2)
	assert_float(closest.distance_to(at)).is_less_equal(BorderConfig.GATE_MOUTH_REACH + 3.0)  # Or in the mouth's tile.
	assert_vector(border.route_to_gate(pos)).is_equal(Vector3.ZERO)
	# Inside the line, or with no border, there is no way to go.
	assert_vector(border.route_to_gate(Vector3(1, 0, 1))).is_equal(Vector3.ZERO)
	border.active = false
	assert_vector(border.route_to_gate(Vector3(-39.0, 0.0, 0.0))).is_equal(Vector3.ZERO)


func test_members_settle_on_the_gates_and_a_dimmed_person_walks_to_one() -> void:
	var s: Dictionary = await TopDownTestUtil.settled_level(self, 20)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var border: Border = td.border
	assert_int(border.member_count).is_equal(20)
	var per_gate: Dictionary = {}
	for m: Person in border.members:
		assert_float(BorderShape.distance_to_line(border.polygon, Vector2(m.position.x, m.position.z))).is_less(0.2)
		var g: int = border.zone.nearest_gate(Vector2(m.position.x, m.position.z))["id"]
		per_gate[g] = (per_gate.get(g, 0) as int) + 1
	for g: int in per_gate:
		assert_int(per_gate[g] as int).is_equal(5)
	# A dimmed person in the street west of the square goes round the block and comes up to a gate.
	td.spirit_warmth.pool = 0.0
	TopDownTestUtil.open_dim_gate(td)
	var dimmed: Person = td.people[24]
	TopDownTestUtil.place(dimmed, Vector3(-39.0, 0.0, 0.0), 1, 0.95)
	dimmed.level = 2  # Dimmed at once (the midnight stagger would take its time).
	var frames := 0
	var reached := false
	while frames < 4200 and not reached:
		await runner.simulate_frames(10)
		frames += 10
		var here := Vector2(dimmed.position.x, dimmed.position.z)
		var g: Dictionary = border.zone.nearest_gate(here)
		var mid: Vector2 = g["mid"]
		reached = here.distance_to(mid) < 9.0
	assert_bool(reached).override_failure_message("stuck at %s" % dimmed.position).is_true()
	assert_bool(td.plaza.near_block(dimmed.position, 0.0)).is_false()  # Round the blocks, never through one.
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_people_never_stand_inside_a_block_while_they_head_for_a_gate() -> void:
	var s: Dictionary = await TopDownTestUtil.settled_level(self, 20, 300)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.spirit_warmth.pool = 0.0
	var spots: Array[Vector3] = [Vector3(-39, 0, -39), Vector3(15, 0, 39), Vector3(-15, 0, 15), Vector3(39, 0, 15)]
	for i: int in range(spots.size()):
		TopDownTestUtil.place(td.people[24 + i], spots[i], 1, 0.95)
		td.people[24 + i].level = 2
	for step: int in range(60):
		await runner.simulate_frames(20)
		for i: int in range(spots.size()):
			assert_bool(td.plaza.near_block(td.people[24 + i].position, 0.0)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Corners of the line rules ------------------------------------------------------------------------------------


func test_a_zone_with_no_gates_has_no_way_out_but_east() -> void:
	var border := _bare_border()
	var all := TownGrid.all_cells()
	var guard := 0
	while border.zone.held.size() < all.size() and guard < 100:
		guard += 1
		for c: Vector2i in all:
			border.zone.take(c)
	border._trace()
	assert_int(border.zone.gates.size()).is_equal(0)
	assert_vector(border.out_at(Vector3(3, 0, 3))).is_equal(Vector2.RIGHT)
	assert_vector(border.route_to_gate(Vector3(-39, 0, 0))).is_equal(Vector3.ZERO)
	assert_float(border.perimeter).is_equal(0.0)


func test_a_move_that_slips_in_beside_a_bending_gate_is_held() -> void:
	var border := _bare_border()
	# The crossing test is given nothing to go on (as when the line changed shape under it): the move ends inside and
	# the nearest stretch is intact, so the person stays put.
	var flags: Array[bool] = []
	border.segment_gap = flags
	var from := Vector3(9.4, 0.0, 0.0)
	assert_vector(border.clip_move(from, Vector3(8.9, 0.0, 0.0))).is_equal(from)


func test_the_way_from_inside_a_block_is_toward_the_street() -> void:
	var border := _bare_border()
	var go := border.route_to_gate(Vector3(-51.0, 0.0, 0.0))
	assert_float(go.length()).is_equal_approx(1.0, 0.001)
	assert_float(go.x).is_greater(0.9)  # East, to the street piece beside the block.


func test_a_member_is_faltering_when_drained_and_a_member_with_no_place_stays_put() -> void:
	var border := _bare_border()
	var m := _rescued(1)[0]
	m.joy = Config.JOY_MAX
	border.members.append(m)
	assert_bool(border.is_faltering(m)).is_false()
	m.joy = 0.0
	assert_bool(border.is_faltering(m)).is_true()
	var at := m.position
	border._move_members(0.5)  # No place was given to them: they are not walked anywhere.
	assert_vector(m.position).is_equal(at)


func test_inner_places_fall_back_when_there_is_no_open_ground_or_too_little() -> void:
	var border := _bare_border()
	var none: Array[Rect2] = []
	assert_vector(border._slots._inner_spot(none, 0)).is_equal(Vector2.ZERO)
	var tiny: Array[Rect2] = [Rect2(10.0, 10.0, 2.0, 2.0)]
	assert_vector(border._slots._inner_spot(tiny, 3)).is_equal(Vector2(11.0, 11.0))


func test_the_gap_tracker_matches_each_old_gap_to_one_new_one_only() -> void:
	var tracker := GapTracker.new()
	var first: Array[Vector3] = [Vector3(10.0, 0.0, 0.0)]
	tracker.update(first, 1.0)
	assert_float(tracker.ages[0]).is_equal(0.0)
	tracker.update(first, 2.0)
	assert_float(tracker.ages[0]).is_equal_approx(2.0, 0.001)
	assert_float(tracker.urgencies[0]).is_equal_approx(2.0 / BorderConfig.GAP_URGENCY_SECONDS, 0.001)
	# Two gaps now stand near the old one: it carries over to the first only; the other is new.
	var two: Array[Vector3] = [Vector3(10.5, 0.0, 0.0), Vector3(11.0, 0.0, 0.0)]
	tracker.update(two, 1.0)
	assert_float(tracker.ages[0]).is_equal_approx(3.0, 0.001)
	assert_float(tracker.ages[1]).is_equal(0.0)
	var none: Array[Vector3] = []
	tracker.update(none, 1.0)
	assert_int(tracker.urgencies.size()).is_equal(0)
