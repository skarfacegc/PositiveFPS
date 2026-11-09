extends GdUnitTestSuite

# Round 12b: edge pressure (dimmed people prefer the newest, outermost stretch of the border) and the slot gap rules.
# Round 26: a faltering member no longer opens a gap, so the benching and step-back tests are gone (BorderShape still
# knows the faltering flag). A break made by pushing is in border_push_test.gd and push_defence_test.gd.


# Rescues `count` people on a ring of radius `r` around the origin and lets the border settle (night at midnight).
func _border_level(count: int, r: float, settle_frames: int = 600) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(settle_frames)
	return {"runner": runner, "td": td}


# The unit vector from the border centre out to `p`.
func _outward(td: TopDownMain, p: Person) -> Vector3:
	var out := Vector3(p.position.x - td.border.centre.x, 0.0, p.position.z - td.border.centre.z)
	return out.normalized()


# --- Pure rules --------------------------------------------------------------------------------------------------


func test_a_faltering_slot_makes_the_two_segments_beside_it_gaps_and_no_others() -> void:
	var filled: Array[bool] = [true, true, true, true, true, true]
	var anchored: Array[bool] = []
	var faltering: Array[bool] = [false, false, true, false, false, false]
	var flags := BorderShape.gap_flags(2.6, filled, anchored, faltering)
	assert_array(flags).is_equal([false, true, true, false, false, false])


func test_a_loop_that_is_stretched_too_wide_is_still_one_big_gap_everywhere() -> void:
	var filled: Array[bool] = [true, true, true]
	var faltering: Array[bool] = [false, false, false]
	var flags := BorderShape.gap_flags(Config.BORDER_MAX_GAP + 0.5, filled, [], faltering)
	assert_array(flags).is_equal([true, true, true])


func test_a_post_still_holds_the_segments_beside_it_even_when_a_member_falters() -> void:
	var filled: Array[bool] = [true, true, true, true]
	var anchored: Array[bool] = [false, true, false, false]
	var faltering: Array[bool] = [true, false, false, false]
	var flags := BorderShape.gap_flags(2.6, filled, anchored, faltering)
	# Slot 0 falters: segments 3 and 0 are gaps, but the segments touching the anchored slot 1 (0 and 1) stay intact.
	assert_array(flags).is_equal([false, false, false, true])


func test_a_member_below_the_falter_fraction_of_their_joy_falters() -> void:
	var p: Person = auto_free(Person.new())
	p.is_rescued = true
	p.joy = Config.JOY_MAX
	assert_bool(p.is_faltering()).is_false()
	p.joy = Config.JOY_MAX * Config.MEMBER_FALTER_FRACTION + 1.0
	assert_bool(p.is_faltering()).is_false()
	p.joy = Config.JOY_MAX * Config.MEMBER_FALTER_FRACTION - 1.0
	assert_bool(p.is_faltering()).is_true()
	p.is_rescued = false
	assert_bool(p.is_faltering()).is_false()


# --- Edge pressure -----------------------------------------------------------------------------------------------


func test_dimmed_people_pick_the_newest_stretch_of_the_border() -> void:
	var s: Dictionary = await _border_level(8, 5.0)
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	assert_bool(border.active).is_true()
	# One member on the east side of the loop, one on the west; a dimmed person exactly between them to the north.
	var east: Person = null
	var west: Person = null
	for m: Person in border.members:
		if east == null or m.position.x > east.position.x:
			east = m
		if west == null or m.position.x < west.position.x:
			west = m
	var dimmed := td.people[20]
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -(border.centre.z + 14.0)), 1, 0.95)
	# Make both targets equally exposed and the same distance away.
	east.protection = 0.0
	west.protection = 0.0
	for i: int in range(border._pushed_at.size()):
		border._pushed_at[i] = -1.0e9  # Nothing has advanced for a long time.
	dimmed.global_position = Vector3(border.centre.x, 0.0, border.centre.z - 14.0)

	# The east stretch advances (a rescue pushes outward there): the dimmed person goes east.
	var east_angle := atan2(east.position.z - border.centre.z, east.position.x - border.centre.x)
	border._push_at(east_angle, Config.BORDER_PUSH)
	assert_float(border.edge_pressure(east.position)).is_greater(border.edge_pressure(west.position))
	var pick: Dictionary = td.pursuit_assignments(td.people)
	assert_object(pick[dimmed]).is_same(east)

	# Now the west stretch is the newest: they switch.
	for i: int in range(border._pushed_at.size()):
		border._pushed_at[i] = -1.0e9
	var west_angle := atan2(west.position.z - border.centre.z, west.position.x - border.centre.x)
	border._push_at(west_angle, Config.BORDER_PUSH)
	pick = td.pursuit_assignments(td.people)
	assert_object(pick[dimmed]).is_same(west)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_how_recently_a_stretch_advanced_fades_over_time() -> void:
	var s: Dictionary = await _border_level(8, 5.0)
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var m: Person = border.members[0]
	var angle := atan2(m.position.z - border.centre.z, m.position.x - border.centre.x)
	border._push_at(angle, Config.BORDER_PUSH)
	var fresh := border.edge_pressure(m.position)
	border._time += Config.EDGE_RECENT_SECONDS * 0.5
	var older := border.edge_pressure(m.position)
	border._time += Config.EDGE_RECENT_SECONDS
	var old := border.edge_pressure(m.position)
	assert_float(older).is_less(fresh)
	assert_float(old).is_less(older)
	# With no border there is no pressure.
	var bare: Border = auto_free(Border.new())
	assert_float(bare.edge_pressure(Vector3.ZERO)).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_dimmed_person_outside_the_border_walks_up_to_the_line_and_presses_it() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	# A member with open ground outside it (0.3.3: blocks stand in rows, so not every direction is clear).
	var m: Person = td.border.members[3]
	for cand: Person in td.border.members:
		var o := _outward(td, cand)
		if not td._near_block(cand.position + o * 2.0, 3.0) and not td._near_block(cand.position + o * 4.0, 3.0):
			m = cand
			break
	var dimmed := td.people[20]
	# Round 14: the midnight stagger lets one person sink at a time, and the others here would sink too (and take the
	# gate). Everyone else starts light, and the gate is open for this one dimmed person.
	for p: Person in td.people:
		if p != dimmed and not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	TopDownTestUtil.place(dimmed, m.position + _outward(td, m) * 4.0, 1, 0.95)
	await runner.simulate_frames(480)
	var near: Dictionary = td.border._nearest_on_loop(Vector2(dimmed.position.x, dimmed.position.z))
	var dist: float = near["dist"]
	assert_float(dist).is_less(Config.BORDER_PRESS_RANGE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_overextending_still_opens_gaps_everywhere() -> void:
	# Four people on the smallest circle are over the spacing limit: every stretch is a gap, not only one.
	var s: Dictionary = await _border_level(4, 2.0)
	var td: TopDownMain = s["td"]
	assert_int(td.border.gap_count()).is_equal(td.border.segment_gap.size())
	assert_int(td.border.gap_region_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_faltering_member_no_longer_steps_back_or_opens_a_gap() -> void:
	var s: Dictionary = await _border_level(20, 7.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var weak: Person = border.members[4]
	td.spirit_warmth.pool = 0.0
	weak.joy = Config.JOY_MAX * 0.6
	await runner.simulate_frames(int(3.0 * 60.0))
	assert_bool(border.is_faltering(weak)).is_true()
	assert_bool(border.members.has(weak)).is_true()
	assert_int(border.gap_count()).is_equal(0)
	var spot: Vector3 = border._targets[weak]
	var out := Vector2(spot.x - border.centre.x, spot.z - border.centre.z).length()
	assert_float(out).is_greater(border._mean_radius() * 0.9)  # Still on the line, not stepped back.
	await TopDownTestUtil.leave_loaded_scene(td)
