extends GdUnitTestSuite

# Round 12b: edge pressure (dimmed people prefer the newest, outermost stretch of the border) and local gaps (a member
# drained below MEMBER_FALTER_FRACTION falters, steps back and opens a gap on both sides of them; the gap is local,
# does not smooth away at once, and closes when the player re-joys the member). The scripted scenario builds a healthy
# border of rescued people, then sends two dimmed people to press one member.


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
	var flags := Border.gap_flags(2.6, filled, anchored, faltering)
	assert_array(flags).is_equal([false, true, true, false, false, false])


func test_a_loop_that_is_stretched_too_wide_is_still_one_big_gap_everywhere() -> void:
	var filled: Array[bool] = [true, true, true]
	var faltering: Array[bool] = [false, false, false]
	var flags := Border.gap_flags(Config.BORDER_MAX_GAP + 0.5, filled, [], faltering)
	assert_array(flags).is_equal([true, true, true])


func test_a_post_still_holds_the_segments_beside_it_even_when_a_member_falters() -> void:
	var filled: Array[bool] = [true, true, true, true]
	var anchored: Array[bool] = [false, true, false, false]
	var faltering: Array[bool] = [true, false, false, false]
	var flags := Border.gap_flags(2.6, filled, anchored, faltering)
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
	var m: Person = td.border.members[3]
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


# --- Local gaps --------------------------------------------------------------------------------------------------


func test_a_focused_push_opens_one_local_gap_and_re_joying_the_member_closes_it() -> void:
	var s: Dictionary = await _border_level(20, 7.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	# A healthy border has no gap at all.
	assert_bool(border.active).is_true()
	assert_int(border.member_count).is_equal(20)
	assert_int(border.gap_count()).is_equal(0)
	assert_int(border.gap_region_count()).is_equal(0)

	# Two dimmed people press the same member from outside.
	var target: Person = border.members[7]
	var out := _outward(td, target)
	var side := Vector3(-out.z, 0.0, out.x)
	TopDownTestUtil.place(td.people[20], target.position + out * 1.2, 1, 0.95)
	TopDownTestUtil.place(td.people[21], target.position + out * 1.2 + side * 0.6, 2, 0.95)

	# Round 14: the second presser sinks only DIM_ARRIVAL_MIN_GAP (6 s) after the first (the midnight stagger), so the
	# member falters later than before. Exactly one stretch opens, not the whole border, within about 25 seconds.
	var frames := 0
	while border.gap_region_count() == 0 and frames < 2400:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(border.gap_region_count()).is_equal(1)
	assert_int(frames).is_less(1500)
	assert_int(border.gap_count()).is_between(1, 3)
	assert_int(border.gap_count()).is_less(border.segment_gap.size() / 2)
	var faltering: Person = null
	for m: Person in border.members:
		if border.is_faltering(m):
			faltering = m
	assert_object(faltering).is_not_null()
	(
		assert_float(
			Vector2(faltering.position.x, faltering.position.z).distance_to(
				Vector2(target.position.x, target.position.z)
			)
		)
		. is_less(5.5)
	)
	# Its stretch of the line is a gap (and the other side of the loop is not).
	assert_int(border.gap_midpoints().size()).is_equal(border.gap_count())

	# The pressers leave, so the member stops losing joy. The neighbours do not shuffle to smooth the gap away: nobody is
	# spare, and the member stays where they are for at least GAP_HEAL_DELAY.
	TopDownTestUtil.place(td.people[20], Vector3(-25, 0, 25), 1, 0.95)
	TopDownTestUtil.place(td.people[21], Vector3(-25, 0, 24), 2, 0.95)
	await runner.simulate_frames(int(Config.GAP_HEAL_DELAY * 60.0) + 30)
	assert_int(border.gap_region_count()).is_equal(1)
	assert_bool(border.is_faltering(faltering)).is_true()
	# The faltering member stepped back from the line.
	var target_spot: Vector3 = border._targets[faltering]
	assert_float(Vector2(target_spot.x, target_spot.z).distance_to(Vector2(border.centre.x, border.centre.z))).is_less(
		Vector2(target.position.x, target.position.z).distance_to(Vector2(border.centre.x, border.centre.z)) + 0.1
	)

	# Re-joying them with real input (hover and fire) restores them and the gap closes.
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, faltering.global_position))
	var waited := 0
	while border.gap_count() > 0 and waited < 600:
		await runner.simulate_frames(1)
		waited += 1
	assert_int(border.gap_count()).is_equal(0)
	assert_bool(faltering.is_faltering()).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# Scene-free: a radius 6 loop holds 15 slots, a post on it three of them, so 12 members are needed and 8 of the 20
# rescued people are spare inner members. Returns the border and the rescued people.
func _post_border() -> Dictionary:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = Border.circle_polygon(Vector2.ZERO, 6.0 * Config.WORLD_SCALE, Config.BORDER_SAMPLES)
	border.active = true
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.position = Vector3(5.5 * Config.WORLD_SCALE, 0.0, 0.0)
	add_child(body)
	border.register_building(body, Vector2(0.5, 0.5), false)
	border.buildings[0].beautified = true
	var rescued: Array[Person] = []
	for i: int in range(20):
		var a := TAU * float(i) / 20.0
		var p: Person = auto_free(Person.new())
		p.is_rescued = true
		p.joy = Config.JOY_MAX
		p.position = Vector3(cos(a) * 6.0 * Config.WORLD_SCALE, 0.0, sin(a) * 6.0 * Config.WORLD_SCALE)
		rescued.append(p)
	border._assign_members(rescued)
	assert_int(border.member_count).is_equal(12)
	assert_int(border.inner_count).is_equal(8)
	assert_int(border.gap_count()).is_equal(0)

	return {"border": border, "rescued": rescued}


func test_a_spare_inner_member_takes_a_faltering_place_only_after_the_heal_delay() -> void:
	var made := _post_border()
	var border: Border = made["border"]
	var rescued: Array[Person] = []
	var made_list: Array = made["rescued"]
	rescued.assign(made_list)
	var weak: Person = border.members[2]
	weak.joy = Config.JOY_MAX * 0.6  # Faltering, but not about to relapse (0.5).
	# Each frame: the level updates the falter clock, then the slots.
	for i: int in range(60):
		border._update_falter(rescued, 1.0 / 60.0)
		border._assign_members(rescued)
	# After a second the gap is still there and the same member holds the place.
	assert_int(border.gap_region_count()).is_equal(1)
	assert_bool(border.members.has(weak)).is_true()
	for i: int in range(int(Config.GAP_HEAL_DELAY * 60.0)):
		border._update_falter(rescued, 1.0 / 60.0)
		border._assign_members(rescued)
	# After the delay a spare inner member has stepped in and the gap is healed; the weak one waits inside.
	assert_bool(border.members.has(weak)).is_false()
	assert_bool(border.inner.has(weak)).is_true()
	assert_int(border.gap_count()).is_equal(0)
	assert_int(border.member_count).is_equal(12)
	# They stay on the bench while they falter (they do not flap back to the line), and come back when they recover.
	for i: int in range(30):
		border._update_falter(rescued, 1.0 / 60.0)
		border._assign_members(rescued)
	assert_bool(border.inner.has(weak)).is_true()
	weak.joy = Config.JOY_MAX
	border._update_falter(rescued, 1.0 / 60.0)
	assert_bool(border._benched.has(weak)).is_false()


func test_a_benched_member_comes_back_when_nobody_else_can_fill_the_line_and_is_forgotten_if_lost() -> void:
	var made := _post_border()
	var border: Border = made["border"]
	var rescued: Array[Person] = []
	var made_list: Array = made["rescued"]
	rescued.assign(made_list)
	border._assign_members(rescued)
	var weak: Person = border.members[2]
	weak.joy = Config.JOY_MAX * 0.6
	for i: int in range(int((Config.GAP_HEAL_DELAY + 1.0) * 60.0)):
		border._update_falter(rescued, 1.0 / 60.0)
		border._assign_members(rescued)
	assert_bool(border._benched.has(weak)).is_true()
	# Most of the others are lost: with exactly as many people as the line needs, the benched one goes back on it.
	var few: Array[Person] = []
	for m: Person in border.members:
		if few.size() < 11:
			few.append(m)
	few.append(weak)
	border._update_falter(few, 1.0 / 60.0)
	border._assign_members(few)
	assert_int(border.member_count).is_equal(12)
	assert_bool(border.members.has(weak)).is_true()
	# A benched person who is no longer rescued is forgotten.
	weak.is_rescued = false
	var nobody: Array[Person] = []
	border._update_falter(nobody, 1.0 / 60.0)
	assert_bool(border._benched.has(weak)).is_false()


func test_with_nobody_spare_a_faltering_member_keeps_their_place_and_the_gap_stays() -> void:
	var s: Dictionary = await _border_level(20, 7.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var weak: Person = border.members[4]
	weak.joy = Config.JOY_MAX * 0.6
	await runner.simulate_frames(int((Config.GAP_HEAL_DELAY + 2.0) * 60.0))
	assert_bool(border.members.has(weak)).is_true()
	assert_int(border.gap_region_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_overextending_still_opens_gaps_everywhere() -> void:
	# Four people on the smallest circle are over the spacing limit: every stretch is a gap, not only one.
	var s: Dictionary = await _border_level(4, 2.0)
	var td: TopDownMain = s["td"]
	assert_int(td.border.gap_count()).is_equal(td.border.segment_gap.size())
	assert_int(td.border.gap_region_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)
