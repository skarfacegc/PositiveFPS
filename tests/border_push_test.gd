# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Round 26, physical push (BorderPush), on gates since 0.4 (#56): dimmed people leaning on a gate and the tide's wave
# push it inward, the dent deepens and springs back, joy and the burst calm a spot, past a depth the gate breaks, and a
# break mends. Walls hold firm. Scene-free: a bare Border holding the start square (four 18 m gates, a point every
# 2 m, so the east gate is the line x = 9) and no frames.

const R := 9.0
const DT := 1.0 / 60.0
const EAST_BLOCK := Vector2i(3, 2)


# A bare Border with the line traced (and drawn as its own polygon), the way Border.update would on its first frame.
func _border(cells: Array[Vector2i] = []) -> Border:
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


func _member(border: Border, pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.is_rescued = true
	p.joy = Config.JOY_MAX
	p.position = pos
	border.members.append(p)
	return p


func _pusher(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.gloom = 1.0
	p.position = pos
	return p


func _run(border: Border, people: Array[Person], seconds: float, strength: float = 1.0) -> void:
	for i: int in range(int(seconds * 60.0)):
		border.push.update(people, DT, strength)


func _east(border: Border) -> int:
	return border.push.sample_of(Vector3(R, 0.0, 0.0))


func _west(border: Border) -> int:
	return border.push.sample_of(Vector3(-R, 0.0, 0.0))


func test_the_traced_line_has_a_point_every_two_metres_along_each_gate() -> void:
	var border := _border()
	assert_int(border.point_count()).is_equal(36)
	assert_int(border.polygon.size()).is_equal(36)
	assert_float(border.perimeter).is_equal(72.0)
	assert_bool(border.point_dentable(_east(border))).is_true()
	assert_bool(border.is_wall(_east(border))).is_false()
	assert_int(border.segment_gate(_east(border))).is_greater_equal(0)


func test_a_dimmed_person_leaning_on_a_gate_dents_it_there_and_nowhere_else() -> void:
	var border := _border()
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 2.0)
	assert_int(border.push.pushers).is_equal(1)
	assert_float(border.push.dent[_east(border)]).is_greater(0.5)
	assert_float(border.push.dent[_west(border)]).is_equal(0.0)


func test_a_push_does_not_spread_onto_the_next_gate_round_the_corner() -> void:
	var border := _border()
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 5.6))]  # Near the south end of the east gate.
	_run(border, people, 3.0)
	var south := border.push.sample_of(Vector3(2.0, 0.0, R))
	assert_float(border.push.dent[border.push.sample_of(Vector3(R, 0.0, 5.0))]).is_greater(0.3)
	assert_float(border.push.dent[south]).is_equal(0.0)


func test_people_inside_far_away_or_not_dimmed_do_not_push() -> void:
	var border := _border()
	var inside := _pusher(Vector3(R - 2.0, 0.0, 0.0))
	var far := _pusher(Vector3(R + PushConfig.PUSH_LEAN_RANGE + 2.0, 0.0, 0.0))
	var light := _pusher(Vector3(R + 0.8, 0.0, 3.0))
	light.gloom = 0.1
	var rescued := _pusher(Vector3(R + 0.8, 0.0, -3.0))
	rescued.is_rescued = true
	var people: Array[Person] = [inside, far, light, rescued]
	_run(border, people, 1.0)
	assert_int(border.push.pushers).is_equal(0)
	assert_float(border.push.deepest).is_equal(0.0)


func test_a_stronger_night_and_more_pushers_dent_deeper_and_a_weakened_pusher_less() -> void:
	var border := _border()
	var one: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, one, 3.0, 1.0)
	var plain: float = border.push.dent[_east(border)]
	assert_float(plain).is_greater(0.3)
	border.push.reset()
	_run(border, one, 3.0, 2.0)
	assert_float(border.push.dent[_east(border)]).is_greater(plain + 0.2)
	border.push.reset()
	one[0].push_mult = PushConfig.PUSH_WEAKEN_MIN
	_run(border, one, 3.0, 1.0)
	assert_float(border.push.dent[_east(border)]).is_less(plain - 0.2)
	border.push.reset()
	var two: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0)), _pusher(Vector3(R + 0.8, 0.0, 0.4))]
	_run(border, two, 3.0, 1.0)
	assert_float(border.push.dent[_east(border)]).is_greater(plain + 0.2)


func test_a_tired_member_gives_more_than_a_fresh_one() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 3.0)
	var fresh: float = border.push.dent[_east(border)]
	border.push.reset()
	member.joy = member.joy_needed() * 0.3
	_run(border, people, 3.0)
	assert_float(border.push.dent[_east(border)]).is_greater(fresh + 0.1)


func test_the_dent_deepens_no_faster_than_the_give_speed() -> void:
	var border := _border()
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0)), _pusher(Vector3(R + 0.8, 0.0, 0.3))]
	_run(border, people, 1.0, 2.0)
	assert_float(border.push.dent[_east(border)]).is_less_equal(PushConfig.PUSH_GIVE_SPEED * 1.0 + 0.01)
	assert_float(border.push.dent[_east(border)]).is_greater(PushConfig.PUSH_GIVE_SPEED * 0.9)


func test_the_gate_springs_back_when_nothing_pushes() -> void:
	var border := _border()
	var i := _east(border)
	border.push.dent[i] = 1.5
	var nobody: Array[Person] = []
	_run(border, nobody, 1.0)
	assert_float(border.push.dent[i]).is_equal_approx(1.5 - PushConfig.PUSH_SPRING_SPEED, 0.05)
	_run(border, nobody, 3.0)
	assert_float(border.push.dent[i]).is_equal(0.0)


func test_joy_at_a_bending_member_calms_the_spot_and_the_gate_springs_back_faster() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 1.5)
	var i := _east(border)
	var before: float = border.push.dent[i]
	assert_float(before).is_greater(0.5)
	member.joy_hits += 1
	_run(border, people, 1.0)
	# The same pusher is still there, but the push is cut: the dent is smaller than it would have grown to.
	assert_float(border.push.dent[i]).is_less(before)


func test_a_joy_hit_on_a_member_by_the_break_counts_as_mending_its_ends() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var nobody: Array[Person] = []
	border.push.dent[_east(border)] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.1)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_bool(border.push.breaks[0]["joyed"]).is_false()
	member.joy_hits += 1
	_run(border, nobody, 0.1)
	assert_bool(border.push.breaks.is_empty() or border.push.breaks[0]["joyed"]).is_true()


func test_past_the_depth_limit_the_gate_snaps_once_and_tells_the_border() -> void:
	var border := _border()
	var seen: Array = []
	border.line_broke.connect(func(pos: Vector3) -> void: seen.append(pos))
	var nobody: Array[Person] = []
	var i := _east(border)
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH - 0.2
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(0)
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_int(seen.size()).is_equal(1)
	assert_bool(border.push.segment_broken(i)).is_true()
	assert_bool(border.push.segment_broken(i + PushConfig.PUSH_BREAK_HALF)).is_true()
	assert_bool(border.push.segment_broken(i + PushConfig.PUSH_BREAK_HALF + 3)).is_false()
	# The deep dent beside it does not open a second break.
	border.push.dent[i + 1] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_int(border.push.break_points().size()).is_equal(1)
	assert_float(border.push.break_points()[0].x).is_greater(R * 0.8)


func test_a_break_stays_on_its_own_gate_even_at_the_gates_end() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	var last := border.push.sample_of(Vector3(R, 0.0, 7.0))  # The east gate's last point (its corner is the next gate's).
	border.push.dent[last] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(1)
	var gate := border.point_gate(last)
	for j: int in range(border.point_count()):
		if border.push.segment_broken(j):
			assert_int(border.point_gate(j)).is_equal(gate)


func test_a_break_mends_when_nobody_dimmed_is_near_and_a_member_by_it_has_had_joy() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var mended: Array = []
	border.line_mended.connect(func(_pos: Vector3, seconds: float) -> void: mended.append(seconds))
	var pusher := _pusher(Vector3(R + 2.0, 0.0, 0.0))
	var people: Array[Person] = [pusher]
	border.push.dent[_east(border)] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, people, 0.2)
	assert_int(border.push.breaks.size()).is_equal(1)
	# A dimmed person still near the break: it stays, even with joy.
	member.joy_hits += 1
	_run(border, people, 0.5)
	assert_int(border.push.breaks.size()).is_equal(1)
	# They are lifted away; with the ends already joyed the break mends.
	pusher.position = Vector3(R + 40.0, 0.0, 0.0)
	_run(border, people, 0.2)
	assert_int(border.push.breaks.size()).is_equal(0)
	assert_int(mended.size()).is_equal(1)
	assert_bool(border.push.segment_broken(_east(border))).is_false()


func test_a_break_nobody_helps_mends_by_itself_after_a_long_quiet_time() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	border.push.dent[_east(border)] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.2)
	assert_int(border.push.breaks.size()).is_equal(1)
	_run(border, nobody, PushConfig.PUSH_MEND_AUTO - 1.0)
	assert_int(border.push.breaks.size()).is_equal(1)
	_run(border, nobody, 2.0)
	assert_int(border.push.breaks.size()).is_equal(0)


func test_pushers_walk_through_a_break_and_push_nothing_there() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	border.push.dent[_east(border)] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.1)
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 0.5)
	assert_int(border.push.pushers).is_equal(0)


func test_the_tide_wave_pushes_the_gates_on_the_side_it_comes_from() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	# The wave is centred on the angle of the east gate's middle point (the gate has no point exactly due east).
	border.push.set_wave(border.point_angle(_east(border)), NightConfig.TIDE_HALF_WIDTH, NightConfig.TIDE_PUSH)
	assert_float(border.push.wave[_east(border)]).is_equal_approx(NightConfig.TIDE_PUSH, 0.001)
	assert_float(border.push.wave[_west(border)]).is_equal(0.0)
	_run(border, nobody, 1.0)
	assert_float(border.push.dent[_east(border)]).is_greater(0.3)
	assert_float(border.push.dent[_west(border)]).is_equal(0.0)
	border.push.clear_wave()
	assert_float(border.push.wave[_east(border)]).is_equal(0.0)


func test_walls_take_no_dent_from_the_tide_and_nobody_leans_on_them() -> void:
	var border := _border([EAST_BLOCK])
	var nobody: Array[Person] = []
	for angle: float in [0.0, PI * 0.5, PI, -PI * 0.5]:
		border.push.set_wave(angle, NightConfig.TIDE_HALF_WIDTH, NightConfig.TIDE_PUSH)
		_run(border, nobody, 1.0)
	for i: int in range(border.point_count()):
		if not border.point_dentable(i):
			assert_float(border.push.dent[i]).is_equal(0.0)
	assert_float(border.push.deepest).is_greater(0.0)  # The gates did give.
	border.push.reset()
	border.push.clear_wave()
	# Beside the block's east face (a wall): within lean range, but nothing leans.
	var people: Array[Person] = [_pusher(Vector3(33.8, 0.0, 0.0))]
	_run(border, people, 2.0)
	assert_int(border.push.pushers).is_equal(0)
	assert_float(border.push.deepest).is_equal(0.0)


func test_a_burst_relieves_only_the_gate_near_it_and_does_nothing_without_a_border() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0)), _pusher(Vector3(-R - 0.8, 0.0, 0.0))]
	_run(border, people, 1.5)
	var east: float = border.push.dent[_east(border)]
	var west: float = border.push.dent[_west(border)]
	border.push.relieve(Vector3(R, 0.0, 0.0))
	_run(border, nobody, 0.5)
	assert_float(east - border.push.dent[_east(border)]).is_greater(west - border.push.dent[_west(border)] + 0.1)
	var bare: Border = auto_free(Border.new())
	bare.push.relieve(Vector3.ZERO)
	assert_float(bare.push.deepest).is_equal(0.0)


func test_members_brace_against_the_dent_and_pushers_lean_into_the_gate() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var inner := _member(border, Vector3(1.0, 0.0, 1.0))
	border.inner.append(inner)
	var presser := _pusher(Vector3(R + 0.8, 0.0, 0.0))
	var people: Array[Person] = [presser]
	_run(border, people, 2.0)
	assert_float(member.brace).is_greater(0.2)
	assert_float(member.brace_dir.x).is_greater(0.9)  # Outward, against the push.
	assert_float(presser.brace).is_greater(0.2)
	assert_float(presser.brace_dir.x).is_less(-0.9)  # Into the gate.
	assert_float(inner.brace).is_equal(0.0)
	# Pressure off (the pusher steps away): both ease back to standing.
	presser.position = Vector3(R + 40.0, 0.0, 0.0)
	_run(border, people, 3.0)
	assert_float(member.brace).is_equal(0.0)
	assert_float(presser.brace).is_equal(0.0)


func test_a_member_at_a_break_braces_fully() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var nobody: Array[Person] = []
	border.push.dent[_east(border)] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 1.0)
	assert_float(member.brace).is_equal(1.0)


func test_the_border_bends_its_line_inward_where_a_gate_is_dented_and_a_flat_line_is_unchanged() -> void:
	var border := _border()
	var rescued: Array[Person] = []
	for i: int in range(4):
		var a := TAU * float(i) / 4.0
		rescued.append(_member(border, Vector3(cos(a), 0.0, sin(a)) * 3.0))
	border.members.clear()
	border.update(rescued, DT, 1.0)
	var flat := border.polygon.duplicate()
	assert_int(flat.size()).is_equal(36)
	var i := _east(border)
	border.push.dent[i] = 1.0
	border.update(rescued, DT, 1.0)
	assert_float(border.polygon[i].x).is_less(flat[i].x - 0.5)  # Shoved in from x = 9.
	assert_float(border.polygon[i].y).is_equal_approx(flat[i].y, 0.01)
	var far := _west(border)
	assert_float(border.polygon[far].distance_to(flat[far])).is_less(0.2)


func test_a_gates_corner_points_do_not_move_so_the_line_stays_joined_to_its_neighbours() -> void:
	var border := _border()
	var rescued: Array[Person] = []
	for i: int in range(3):
		rescued.append(_member(border, Vector3(i, 0.0, 0.0)))
	border.members.clear()
	var corner := border.push.sample_of(Vector3(R, 0.0, -R))
	assert_bool(border.point_dentable(corner)).is_false()
	border.update(rescued, DT, 1.0)
	for k: int in range(border.point_count()):
		border.push.dent[k] = 2.0
	border.update(rescued, DT, 1.0)
	assert_vector(border.polygon[corner]).is_equal(border._base[corner])


func test_a_dent_and_a_break_follow_their_gate_when_the_zone_changes_and_go_when_the_gate_does() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	var north := border.push.sample_of(Vector3(1.0, 0.0, -R))  # (The north gate has points at odd x.)
	var east := _east(border)
	border.push.dent[north] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	border.push.dent[east] = 1.0
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(1)
	border.zone.take(EAST_BLOCK)  # The east side becomes a street; the north gate stays as it is.
	border._trace()
	border.polygon = border._dented()
	border._mark_gaps()
	assert_int(border.push.breaks.size()).is_equal(1)
	# (The dented polygon has moved that point in, so find it in the traced line itself.)
	var north_after := 0
	for i: int in range(border.point_count()):
		if border._base[i].distance_to(Vector2(1.0, -R)) < 0.01:
			north_after = i
	assert_bool(border.push.segment_broken(north_after)).is_true()
	assert_float(border.push.dent[north_after]).is_greater(PushConfig.PUSH_BREAK_DEPTH - 0.5)
	# The old east gate is gone: nothing carries a dent at its former spot (and no point of the line is there now).
	for i: int in range(border.point_count()):
		if absf(border._base[i].x - R) < 0.01 and absf(border._base[i].y) < R - 0.01:
			assert_float(border.push.dent[i]).is_equal(0.0)


func test_a_second_deep_dent_a_few_points_along_the_same_gate_does_not_open_another_break() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	var start := border.push.sample_of(Vector3(R, 0.0, -R))  # The east gate's first point (its corner).
	var first := start + 1
	border.push.dent[first] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.02)
	assert_int(border.push.breaks.size()).is_equal(1)
	border.push.dent[first + 3] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.02)
	assert_int(border.push.breaks.size()).is_equal(1)


func test_the_push_copes_with_no_line_at_all() -> void:
	var bare: Border = auto_free(Border.new())
	assert_float(bare.push.bend_at(Vector3.ZERO)).is_equal(0.0)
	assert_float(bare.push.bend_of_point(-1)).is_equal(0.0)
	assert_float(bare.push.bend_of_point(99)).is_equal(0.0)
	bare.push.calm_at(Vector3.ZERO, 1.0, 2)
	var nobody: Array[Person] = []
	bare.push.update(nobody, DT, 1.0)
	assert_int(bare.push.dent.size()).is_equal(0)
	# A break recorded on a line that is gone is placed at the centre.
	bare.push.resize(8)
	bare.push.breaks.append({"at": 5, "age": 0.0, "joyed": false, "clear": 0.0})
	assert_vector(bare.push.break_points()[0]).is_equal(bare.centre)


func test_the_push_fits_itself_to_a_line_that_changed_shape() -> void:
	var border := _border()
	border.push.dent.clear()  # As if the line had been traced again under it.
	var nobody: Array[Person] = []
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.dent.size()).is_equal(border.point_count())
