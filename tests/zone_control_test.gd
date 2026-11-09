extends GdUnitTestSuite

# 0.3.3 (#53): zone control around buildings. People are moved directly (blocks do not stop them), so slots, rest
# places and walks must keep out of the block footprints (grown by Config.ZONE_BLOCK_CLEAR) and go round them.

const CLEAR := 0.8


func _border() -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	return border


func _block(border: Border, pos: Vector2) -> Building:
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.position = Vector3(pos.x, 0.0, pos.y)
	add_child(body)
	border.register_building(body, Vector2(2.0, 2.0), false)
	return border.buildings[border.buildings.size() - 1]


func _person_at(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.position = pos
	p.is_rescued = true
	p.joy = Config.JOY_MAX
	return p


func test_a_point_inside_a_block_is_moved_to_its_nearest_face() -> void:
	var border := _border()
	_block(border, Vector2(10.0, 0.0))
	var out := BorderShape.clear_of_blocks(border.boxes(), Vector2(11.5, 0.5), CLEAR)
	assert_bool(BorderShape.block_at(border.boxes(), out, CLEAR) < 0).is_true()
	assert_float(out.x).is_equal_approx(12.0 + CLEAR, 0.01)
	assert_float(out.y).is_equal_approx(0.5, 0.001)
	var free := Vector2(20.0, 5.0)
	assert_vector(BorderShape.clear_of_blocks(border.boxes(), free, CLEAR)).is_equal(free)


func test_a_walk_round_a_block_reaches_a_target_straight_behind_it() -> void:
	var border := _border()
	_block(border, Vector2(10.0, 0.0))
	var pos := Vector2(4.0, 0.0)
	var target := Vector2(16.0, 0.0)
	assert_bool(BorderShape.walk_blocked(border.boxes(), pos, target, CLEAR)).is_true()
	var way := Vector2.INF
	var steps := 0
	while pos.distance_to(target) > 0.05 and steps < 600:
		var res := BorderShape.step_around(border.boxes(), pos, target, 0.05, CLEAR, way)
		pos = res["pos"]
		way = res["waypoint"]
		assert_bool(BorderShape.block_at(border.boxes(), pos, CLEAR - 0.01) < 0).is_true()
		steps += 1
	assert_float(pos.distance_to(target)).is_less(0.06)
	assert_int(steps).is_less(600)


func test_a_member_and_a_rescued_person_behind_a_block_reach_their_places_in_time() -> void:
	var border := _border()
	_block(border, Vector2(10.0, 0.0))
	var member := _person_at(Vector3(4.0, 0.0, 0.0))
	var inner := _person_at(Vector3(4.0, 0.0, 0.3))
	border.members.append(member)
	border.inner.append(inner)
	border._targets[member] = Vector3(16.0, 0.0, 0.0)
	border._targets[inner] = Vector3(16.0, 0.0, 1.0)
	for _i: int in range(60 * 10):
		border._move_members(1.0 / 60.0)
		for p: Person in [member, inner]:
			var at := Vector2(p.position.x, p.position.z)
			assert_bool(BorderShape.block_at(border.boxes(), at, CLEAR - 0.01) < 0).is_true()
	assert_float(Vector2(member.position.x - 16.0, member.position.z).length()).is_less(0.1)
	assert_float(Vector2(inner.position.x - 16.0, inner.position.z - 1.0).length()).is_less(0.1)


func test_slots_and_rest_places_never_fall_inside_a_block() -> void:
	var border := _border()
	var r := 6.0 * Config.WORLD_SCALE
	border.polygon = BorderShape.circle_polygon(Vector2.ZERO, r, Config.BORDER_SAMPLES)
	border.active = true
	for k: int in range(6):
		var a := TAU * float(k) / 6.0
		_block(border, Vector2(cos(a), sin(a)) * r)
	var rescued: Array[Person] = []
	for i: int in range(30):
		var a := TAU * float(i) / 30.0
		rescued.append(_person_at(Vector3(cos(a) * r, 0.0, sin(a) * r)))
	border._assign_members(rescued)
	assert_int(border._targets.size()).is_equal(30)
	for p: Person in rescued:
		var t: Vector3 = border._targets[p]
		assert_bool(BorderShape.block_at(border.boxes(), Vector2(t.x, t.z), CLEAR - 0.01) < 0).is_true()


func test_a_walk_of_no_length_is_not_blocked_and_a_person_at_the_target_stays() -> void:
	var border := _border()
	_block(border, Vector2(10.0, 0.0))
	assert_bool(BorderShape.walk_blocked(border.boxes(), Vector2(1.0, 1.0), Vector2(1.0, 1.0), CLEAR)).is_false()
	var res := BorderShape.step_around(border.boxes(), Vector2(1.0, 1.0), Vector2(1.0, 1.0), 0.1, CLEAR, Vector2.INF)
	assert_vector(res["pos"]).is_equal(Vector2(1.0, 1.0))
	assert_vector(res["waypoint"]).is_equal(Vector2.INF)


func test_a_person_with_no_open_corner_waits_and_a_zero_length_look_ahead_finds_nothing() -> void:
	var border := _border()
	for c: Vector2 in [
		Vector2(10.0, 0.0), Vector2(7.0, 5.4), Vector2(13.0, 5.4), Vector2(7.0, -5.4), Vector2(13.0, -5.4)
	]:
		_block(border, c)
	var from := Vector2(7.19, 0.0)
	var res := BorderShape.step_around(border.boxes(), from, Vector2(16.0, 0.0), 0.05, CLEAR, Vector2.INF)
	assert_vector(res["pos"]).is_equal(from)
	assert_vector(res["waypoint"]).is_equal(Vector2.INF)
	assert_int(BorderShape.first_blocker(border.boxes(), from, from, CLEAR)).is_equal(-1)
