# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Round 26, physical push (BorderPush): dimmed people leaning on the line and the tide's wave push it inward, the dent
# deepens and springs back, joy and the burst calm a spot, past a depth the line breaks, and a break mends. Scene-free:
# a bare Border with a circular loop, a few members and pushers, and no frames.

const R := 10.0
const DT := 1.0 / 60.0


func _border() -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = BorderShape.circle_polygon(Vector2.ZERO, R, Config.BORDER_SAMPLES)
	border.active = true
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


func test_a_dimmed_person_leaning_on_the_line_dents_it_there_and_nowhere_else() -> void:
	var border := _border()
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 2.0)
	assert_int(border.push.pushers).is_equal(1)
	assert_float(border.push.dent[_east(border)]).is_greater(0.5)
	assert_float(border.push.dent[_west(border)]).is_equal(0.0)


func test_people_inside_far_away_or_not_dimmed_do_not_push() -> void:
	var border := _border()
	var inside := _pusher(Vector3(R - 2.0, 0.0, 0.0))
	var far := _pusher(Vector3(R + Config.PUSH_LEAN_RANGE + 2.0, 0.0, 0.0))
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
	one[0].push_mult = Config.PUSH_WEAKEN_MIN
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
	assert_float(border.push.dent[_east(border)]).is_less_equal(Config.PUSH_GIVE_SPEED * 1.0 + 0.01)
	assert_float(border.push.dent[_east(border)]).is_greater(Config.PUSH_GIVE_SPEED * 0.9)


func test_the_line_springs_back_when_nothing_pushes() -> void:
	var border := _border()
	var i := _east(border)
	border.push.dent[i] = 1.5
	var nobody: Array[Person] = []
	_run(border, nobody, 1.0)
	assert_float(border.push.dent[i]).is_equal_approx(1.5 - Config.PUSH_SPRING_SPEED, 0.05)
	_run(border, nobody, 3.0)
	assert_float(border.push.dent[i]).is_equal(0.0)


func test_joy_at_a_bending_member_calms_the_spot_and_the_line_springs_back_faster() -> void:
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
	border.push.dent[_east(border)] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.1)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_bool(border.push.breaks[0]["joyed"]).is_false()
	member.joy_hits += 1
	_run(border, nobody, 0.1)
	assert_bool(border.push.breaks.is_empty() or border.push.breaks[0]["joyed"]).is_true()


func test_past_the_depth_limit_the_line_snaps_once_and_tells_the_border() -> void:
	var border := _border()
	var seen: Array = []
	border.line_broke.connect(func(pos: Vector3) -> void: seen.append(pos))
	var nobody: Array[Person] = []
	var i := _east(border)
	border.push.dent[i] = Config.PUSH_BREAK_DEPTH - 0.2
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(0)
	border.push.dent[i] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_int(seen.size()).is_equal(1)
	assert_bool(border.push.segment_broken(i)).is_true()
	assert_bool(border.push.segment_broken(i + Config.PUSH_BREAK_HALF)).is_true()
	assert_bool(border.push.segment_broken(i + Config.PUSH_BREAK_HALF + 3)).is_false()
	# The deep dent beside it does not open a second break.
	border.push.dent[i + 1] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.05)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_int(border.push.break_points().size()).is_equal(1)
	assert_float(border.push.break_points()[0].x).is_greater(R * 0.8)


func test_a_break_mends_when_nobody_dimmed_is_near_and_a_member_by_it_has_had_joy() -> void:
	var border := _border()
	var member := _member(border, Vector3(R, 0.0, 0.0))
	var mended: Array = []
	border.line_mended.connect(func(_pos: Vector3, seconds: float) -> void: mended.append(seconds))
	var pusher := _pusher(Vector3(R + 2.0, 0.0, 0.0))
	var people: Array[Person] = [pusher]
	border.push.dent[_east(border)] = Config.PUSH_BREAK_DEPTH + 0.3
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
	border.push.dent[_east(border)] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.2)
	assert_int(border.push.breaks.size()).is_equal(1)
	_run(border, nobody, Config.PUSH_MEND_AUTO - 1.0)
	assert_int(border.push.breaks.size()).is_equal(1)
	_run(border, nobody, 2.0)
	assert_int(border.push.breaks.size()).is_equal(0)


func test_pushers_walk_through_a_break_and_push_nothing_there() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	border.push.dent[_east(border)] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.1)
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 0.5)
	assert_int(border.push.pushers).is_equal(0)


func test_the_tide_wave_pushes_the_side_it_comes_from() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	border.push.set_wave(0.0, Config.TIDE_HALF_WIDTH, Config.TIDE_PUSH)
	assert_float(border.push.wave[_east(border)]).is_equal_approx(Config.TIDE_PUSH, 0.001)
	assert_float(border.push.wave[_west(border)]).is_equal(0.0)
	_run(border, nobody, 1.0)
	assert_float(border.push.dent[_east(border)]).is_greater(0.3)
	assert_float(border.push.dent[_west(border)]).is_equal(0.0)
	border.push.clear_wave()
	assert_float(border.push.wave[_east(border)]).is_equal(0.0)


func test_a_burst_relieves_only_the_line_near_it_and_does_nothing_without_a_border() -> void:
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


func test_members_brace_against_the_dent_and_pushers_lean_into_the_line() -> void:
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
	assert_float(presser.brace_dir.x).is_less(-0.9)  # Into the line.
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
	border.push.dent[_east(border)] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 1.0)
	assert_float(member.brace).is_equal(1.0)


func test_a_sealed_stretch_takes_no_dent() -> void:
	var border := _border()
	border._sealed.clear()
	for i: int in range(Config.BORDER_SAMPLES):
		border._sealed.append(1.0)
	border.push.set_wave(0.0, Config.TIDE_HALF_WIDTH, Config.TIDE_PUSH)
	var nobody: Array[Person] = []
	_run(border, nobody, 1.0)
	assert_float(border.push.deepest).is_equal(0.0)


func test_a_pusher_far_from_everything_and_a_border_with_no_members_are_safe() -> void:
	var border := _border()
	var people: Array[Person] = [_pusher(Vector3(R + 0.8, 0.0, 0.0))]
	_run(border, people, 0.2)
	assert_int(border.push.pushers).is_equal(1)
	assert_float(border.push.deepest).is_greater(0.0)


func test_the_border_bends_its_loop_inward_where_it_is_dented_and_a_flat_line_is_unchanged() -> void:
	var border := _border()
	var rescued: Array[Person] = []
	for i: int in range(12):
		var a := TAU * float(i) / 12.0
		var p := _member(border, Vector3(cos(a), 0.0, sin(a)) * R)
		rescued.append(p)
	border.members.clear()
	border.update(rescued, DT, 1.0)
	var flat := border.polygon.duplicate()
	assert_int(flat.size()).is_equal(Config.BORDER_SAMPLES)
	var i := border.push.sample_of(Vector3(R, 0.0, 0.0))
	border.push.dent[i] = 1.0
	border.update(rescued, DT, 1.0)
	var centre := Vector2(border.centre.x, border.centre.z)
	assert_float(border.polygon[i].distance_to(centre)).is_less(flat[i].distance_to(centre) - 0.5)
	var far := border.push.sample_of(Vector3(-R, 0.0, 0.0))
	assert_float(border.polygon[far].distance_to(flat[far])).is_less(0.2)


func test_a_bent_loop_keeps_its_perimeter_target_so_the_size_does_not_cancel_the_dent() -> void:
	var border := _border()
	var rescued: Array[Person] = []
	for i: int in range(12):
		var a := TAU * float(i) / 12.0
		rescued.append(_member(border, Vector3(cos(a), 0.0, sin(a)) * R))
	border.members.clear()
	for f: int in range(900):
		border.update(rescued, DT, 1.0)
	var scale_before: float = border._scale
	var i := border.push.sample_of(Vector3(R, 0.0, 0.0))
	for f: int in range(300):
		border.push.dent[i] = 1.2
		border.update(rescued, DT, 1.0)
	assert_float(border._scale).is_equal_approx(scale_before, 0.03)


func test_a_deep_dent_just_beside_a_break_does_not_open_a_second_one() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	var i := _east(border)
	border.push.dent[i] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.02)
	var beside := i + 2 * Config.PUSH_BREAK_HALF + 1
	border.push.dent[beside] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.02)
	assert_int(border.push.breaks.size()).is_equal(1)


func test_a_break_with_no_loop_to_stand_on_is_placed_at_the_centre() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	var nobody: Array[Person] = []
	border.push.dent[5] = Config.PUSH_BREAK_DEPTH + 0.3
	_run(border, nobody, 0.02)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_vector(border.push.break_points()[0]).is_equal(border.centre)
