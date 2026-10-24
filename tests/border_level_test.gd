extends GdUnitTestSuite

# The living border in the real top-down level (round 9): forming, slots, gaps, holding darkness, relapse, painting
# inside, buildings and the landmark. Most rescues are direct (receive_joy) so the rules are checked quickly. The
# rescue and the F3 key go through real input, as a player would. Unit-level checks use the Border and Building classes.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# Rescues `p` directly at `spot` (a joy hit that is always enough).
func _rescue(p: Person, spot: Vector3) -> void:
	TopDownTestUtil.place(p, spot, p.affinity, 0.0)
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# `n` spots evenly spaced on a circle of radius `r` around `c`.
func _ring(c: Vector3, r: float, n: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in range(n):
		var a := TAU * float(i) / float(n)
		out.append(c + Vector3(cos(a) * r, 0.0, sin(a) * r))
	return out


# Rescues the first `count` people, standing on a ring of radius `r` around `c`. Returns them.
func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int) -> Array[Person]:
	var spots := _ring(c, r, count)
	var out: Array[Person] = []
	for i: int in range(count):
		_rescue(td.people[i], spots[i])
		out.append(td.people[i])
	return out


# Lock on to `person` with a real click on the floor under them (lock-on mode).
func _click_to_lock(runner: GdUnitSceneRunner, td: TopDownMain, person: Person) -> void:
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, person.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


# A Border with no level around it, for the unit-level checks. The loop is set by the test.
func _bare_border(loop: PackedVector2Array) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = loop
	border.active = true
	return border


# Unrescued/rescued people with no level (only their positions matter to the border rules).
func _people(count: int) -> Array[Person]:
	var out: Array[Person] = []
	for i: int in range(count):
		var p: Person = auto_free(Person.new())
		p.affinity = i % 3
		add_child(p)
		out.append(p)
	return out


# --- Forming, centre and slots ------------------------------------------------------------------------------


func test_no_border_until_three_are_rescued() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(0, 0, 0), 2.0, 2)
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(30)
	assert_bool(td.border.active).is_false()
	assert_bool(td.border.formed).is_false()
	assert_int(td.border.polygon.size()).is_equal(0)


func test_border_forms_after_three_rescues_and_the_centre_is_their_centroid() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var made := _rescue_ring(td, Vector3(4, 0, -4), 2.0, 3)
	await runner.simulate_frames(120)
	assert_bool(td.border.active).is_true()
	var sum := Vector3.ZERO
	for p: Person in made:
		sum += Vector3(p.position.x, 0.0, p.position.z)
	var centroid := sum / 3.0
	assert_float(Vector2(td.border.centre.x - centroid.x, td.border.centre.z - centroid.z).length()).is_less(0.6)


func test_members_walk_to_their_slots_and_the_loop_is_closed() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(0, 0, 0), 4.0, 6)
	await runner.simulate_frames(240)
	var border: Border = td.border
	assert_int(border.member_count).is_equal(6)
	assert_int(border.inner_count).is_equal(0)
	for p: Person in border.members:
		var target: Vector3 = border._targets[p]
		assert_float(Vector2(p.position.x - target.x, p.position.z - target.z).length()).is_less(0.15)
	assert_float(Border.perimeter_of(border.polygon)).is_greater(0.0)


func test_three_locked_rescues_by_real_clicks_form_the_border() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var spots: Array[Vector3] = [Vector3(-3, 0, -6), Vector3(0, 0, -7), Vector3(3, 0, -6)]
	for i: int in range(3):
		TopDownTestUtil.place(td.people[i], spots[i], td.people[i].affinity, 0.0)
	for i: int in range(3):
		var target: Person = td.people[i]
		await _click_to_lock(runner, td, target)
		var frames := 0
		while not target.is_rescued and frames < 600:
			await runner.simulate_frames(1)
			frames += 1
		assert_bool(target.is_rescued).is_true()
	await runner.simulate_frames(60)
	assert_bool(td.border.active).is_true()
	assert_int(td.border.member_count).is_equal(3)


# --- Slots, inner members and gaps (unit-level: the loop is set directly) -----------------------------------


func test_slot_and_inner_counts_follow_the_formula() -> void:
	# A circle of radius 3 (perimeter about 18.85) has 7 slots at 3.0 m (round 10). Twelve people: seven border members,
	# five inner.
	var loop := Border.circle_polygon(Vector2.ZERO, 3.0, Config.BORDER_SAMPLES)
	var border := _bare_border(loop)
	var people := _people(12)
	var rescued: Array[Person] = []
	for i: int in range(12):
		people[i].position = Vector3(cos(float(i)) * 3.0, 0.0, sin(float(i)) * 3.0)
		rescued.append(people[i])
	border._assign_members(rescued)
	assert_int(border.member_count).is_equal(7)
	assert_int(border.inner_count).is_equal(5)
	assert_float(border.spacing).is_equal_approx(Border.perimeter_of(loop) / 7.0, 0.001)
	assert_int(border.gap_count()).is_equal(0)


func test_fewer_people_than_slots_spread_out_and_leave_gaps() -> void:
	# Four people on a radius 3 loop: all four are border members, spaced about 4.7 m apart (over the 3.5 m limit).
	var border := _bare_border(Border.circle_polygon(Vector2.ZERO, 3.0, Config.BORDER_SAMPLES))
	var people := _people(4)
	var rescued: Array[Person] = []
	for i: int in range(4):
		people[i].position = Vector3(cos(float(i)) * 3.0, 0.0, sin(float(i)) * 3.0)
		rescued.append(people[i])
	border._assign_members(rescued)
	assert_int(border.member_count).is_equal(4)
	assert_int(border.inner_count).is_equal(0)
	assert_float(border.spacing).is_equal_approx(Border.perimeter_of(border.polygon) / 4.0, 0.001)
	assert_int(border.gap_count()).is_equal(4)


func test_gaps_are_drawn_in_their_own_colour() -> void:
	var border := _bare_border(Border.circle_polygon(Vector2.ZERO, 3.0, Config.BORDER_SAMPLES))
	var people := _people(4)
	var rescued: Array[Person] = []
	for i: int in range(4):
		people[i].position = Vector3(cos(float(i)) * 3.0, 0.0, sin(float(i)) * 3.0)
		rescued.append(people[i])
	border._assign_members(rescued)
	assert_bool(border.segment_is_gap(0)).is_true()
	assert_bool(border.segment_colour(0).is_equal_approx(Config.BORDER_INTACT_COLOUR)).is_false()

	var intact := _bare_border(Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES))
	var more := _people(14)
	var more_rescued: Array[Person] = []
	for i: int in range(14):
		more[i].position = Vector3(cos(float(i)) * 5.0, 0.0, sin(float(i)) * 5.0)
		more_rescued.append(more[i])
	intact._assign_members(more_rescued)
	assert_bool(intact.segment_is_gap(0)).is_false()
	assert_bool(intact.segment_colour(0).is_equal_approx(Config.BORDER_INTACT_COLOUR)).is_true()


# --- Holding darkness ---------------------------------------------------------------------------------------


func test_a_dark_person_outside_is_stopped_at_an_intact_line() -> void:
	var border := _bare_border(Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES))
	var people := _people(14)
	var rescued: Array[Person] = []
	for i: int in range(14):
		people[i].position = Vector3(cos(float(i)) * 5.0, 0.0, sin(float(i)) * 5.0)
		rescued.append(people[i])
	border._assign_members(rescued)
	# Walk from outside (x = 8) toward the centre along a line through the middle of one stretch.
	var from := Vector3(8.0, 0.0, 0.33)
	var to := Vector3(3.0, 0.0, 0.33)
	var stopped := border.clip_move(from, to)
	assert_float(stopped.x).is_greater(4.8)
	assert_float(stopped.x).is_less(5.05)
	assert_bool(border.line_blocks(from, to)).is_true()


func test_a_dark_person_passes_through_a_gap() -> void:
	# Three members on a radius 5 loop are 10.5 m apart: every stretch is a gap, so nothing holds the dark person back.
	var border := _bare_border(Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES))
	var people := _people(3)
	var rescued: Array[Person] = []
	for i: int in range(3):
		people[i].position = Vector3(cos(float(i) * 2.0) * 5.0, 0.0, sin(float(i) * 2.0) * 5.0)
		rescued.append(people[i])
	border._assign_members(rescued)
	var from := Vector3(8.0, 0.0, 0.33)
	var to := Vector3(3.0, 0.0, 0.33)
	assert_bool(border.clip_move(from, to).is_equal_approx(to)).is_true()
	assert_bool(border.line_blocks(from, to)).is_false()


func test_a_dark_person_inside_the_loop_is_not_held() -> void:
	var border := _bare_border(Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES))
	var from := Vector3(1.0, 0.0, 0.0)
	var to := Vector3(2.0, 0.0, 0.0)
	assert_bool(border.clip_move(from, to).is_equal_approx(to)).is_true()


# --- Relapse and too few people -----------------------------------------------------------------------------


func test_a_relapsed_member_leaves_and_the_others_reshuffle() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var made := _rescue_ring(td, Vector3(0, 0, 0), 4.0, 5)
	await runner.simulate_frames(120)
	assert_int(td.border.member_count).is_equal(5)
	var leaver: Person = made[0]
	leaver.grace_left = 0.0
	leaver.drain_joy(Config.JOY_MAX)
	await runner.simulate_frames(120)
	assert_bool(leaver.is_rescued).is_false()
	assert_int(td.border.member_count).is_equal(4)
	assert_bool(td.border.members.has(leaver)).is_false()


func test_too_few_people_for_the_loop_leave_gaps_and_the_gaps_persist() -> void:
	# Four people on the smallest circle (radius 3, perimeter 18.85) are 4.7 m apart: over the limit, so gaps.
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var made := _rescue_ring(td, Vector3(0, 0, 0), 4.0, 4)
	await runner.simulate_frames(120)
	assert_int(td.border.member_count).is_equal(4)
	assert_int(td.border.gap_count()).is_greater(0)
	# With one fewer person the gaps are still there.
	made[0].grace_left = 0.0
	made[0].drain_joy(Config.JOY_MAX)
	await runner.simulate_frames(120)
	assert_bool(td.border.active).is_true()
	assert_int(td.border.gap_count()).is_greater(0)


func test_losing_the_border_by_relapse_below_three_ends_the_level() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var made := _rescue_ring(td, Vector3(0, 0, 0), 3.0, 3)
	await runner.simulate_frames(60)
	assert_bool(td.border.formed).is_true()
	made[0].grace_left = 0.0
	made[0].drain_joy(Config.JOY_MAX)
	await runner.simulate_frames(2)
	assert_bool(td.running).is_false()
	assert_str(td.hud.end_label.text).contains("The border fell")


# --- Inside the border --------------------------------------------------------------------------------------


func test_tiles_inside_the_loop_paint_in_over_time_and_outside_stays_grey() -> void:
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(40, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)
	ground.set_region(Border.circle_polygon(Vector2.ZERO, 6.0, Config.BORDER_SAMPLES))
	var none: Array[Person] = []
	for i: int in range(10):
		ground.update_paint(none, 0.11)
	# One second in, the inside has only partly painted in (it lags), and the outside has not started.
	var inside := ground.paint_weight_at(Vector3(0.0, 0.0, 0.0))
	assert_float(inside).is_greater(0.25)
	assert_float(inside).is_less(0.6)
	assert_float(ground.paint_weight_at(Vector3(15.0, 0.0, 0.0))).is_equal(0.0)


func test_a_grey_person_inside_the_loop_lightens_and_one_outside_darkens() -> void:
	var border := _bare_border(Border.circle_polygon(Vector2.ZERO, 6.0, Config.BORDER_SAMPLES))
	var people := _people(2)
	var inside: Person = people[0]
	inside.position = Vector3(0.0, 0.0, 0.0)
	inside.gloom = 0.5
	inside.cover = border.cover_at(inside.position)
	inside.protection = inside.cover
	var outside: Person = people[1]
	outside.position = Vector3(20.0, 0.0, 0.0)
	outside.gloom = 0.5
	outside.cover = border.cover_at(outside.position)
	outside.protection = outside.cover
	var list: Array[Person] = [inside, outside]
	GloomSim.update(list, 1.0)
	assert_float(inside.cover).is_equal(1.0)
	assert_float(inside.gloom).is_less(0.5)
	assert_float(outside.gloom).is_greater(0.5)
	assert_bool(inside.is_rescued).is_false()


# --- Buildings and the landmark -----------------------------------------------------------------------------


func test_a_building_is_beautified_after_three_seconds_inside() -> void:
	var b := Building.new()
	b.mat = StandardMaterial3D.new()
	b.base_colour = Color(0.5, 0.5, 0.5)
	b.update(1.0, 1.0)
	b.update(1.0, 1.0)
	assert_bool(b.beautified).is_false()
	b.update(1.0, 1.0)
	assert_bool(b.beautified).is_true()
	# The tint fades in over BORDER_TINT_SECONDS (2 s), so after the first beautified second it is half way.
	assert_float(b.tint).is_equal_approx(0.5, 0.001)
	# Leaving the border resets the time, so the building stops being beautified.
	b.update(1.0, 0.0)
	assert_bool(b.beautified).is_false()


func test_landmark_hold_grows_then_resets_when_not_beautified() -> void:
	var lm: Landmark = auto_free(Landmark.new())
	add_child(lm)
	lm.update(4.0, true)
	assert_float(lm.progress()).is_equal_approx(0.4, 0.001)
	assert_bool(lm.is_held()).is_false()
	lm.update(1.0, false)
	assert_float(lm.hold).is_equal(0.0)
	lm.update(Config.BORDER_LANDMARK_HOLD, true)
	assert_bool(lm.is_held()).is_true()


func test_the_landmark_is_held_and_the_level_is_won() -> void:
	# Three people around the landmark enclose it (the loop is a radius-3 circle around its centre). After three seconds
	# inside it is beautified, and the hold runs for BORDER_LANDMARK_HOLD seconds.
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Config.BORDER_LANDMARK_POS, 2.5, 3)
	var frames := 0
	while td.running and frames < 1500:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(td.running).is_false()
	assert_bool(td.landmark.is_held()).is_true()
	assert_str(td.hud.end_label.text).contains("The landmark is ours!")
	assert_str(td.hud.end_label.text).contains("Landmark held: yes")


# --- F3 through the menu and real keys ----------------------------------------------------------------------


func test_f3_from_the_menu_shows_the_border_labels() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var menu: GdUnitSceneRunner = scene_runner("res://menu.tscn")
	(menu.scene() as Control).size = Vector2(1280, 720)
	await menu.simulate_frames(10)
	menu.simulate_key_pressed(KEY_1)
	await menu.simulate_frames(10)
	var td: TopDownMain = get_tree().current_scene as TopDownMain
	assert_object(td).is_not_null()
	TopDownTestUtil.send_everyone_away(td)
	_rescue_ring(td, Vector3(0, 0, 0), 3.0, 3)
	await menu.simulate_frames(20)
	menu.simulate_key_pressed(KEY_F3)
	await menu.simulate_frames(10)
	assert_bool(td.debug_on).is_true()
	assert_bool(td.hud.debug_hint_label.visible).is_true()
	assert_str(td.hud.debug_hint_label.text).contains("border")
	assert_int(td.border.visible_debug_label_count()).is_greater(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# Round 10: the joy burst used within BORDER_SHOVE_RANGE of the line shoves it outward toward the player.
func _radius_toward(border: Border, dir: Vector2) -> float:
	var c := Vector2(border.centre.x, border.centre.z)
	var best_r := 0.0
	var best_dot := -INF
	for p2: Vector2 in border.polygon:
		var v := p2 - c
		var d := v.normalized().dot(dir)
		if d > best_dot:
			best_dot = d
			best_r = v.length()
	return best_r


func test_the_joy_burst_near_the_border_bulges_it_toward_the_player() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 4.0, 8)
	await runner.simulate_frames(300)
	var before := _radius_toward(td.border, Vector2.RIGHT)
	# Stand 2 m outside the line, to the east, and use the joy burst (G) with real input.
	td.player.global_position = Vector3(before + 2.0, 0.0, 0.0)
	await runner.simulate_frames(2)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(120)
	var after := _radius_toward(td.border, Vector2.RIGHT)
	assert_float(after - before).is_greater(0.8)
	assert_float(after - before).is_less(1.8)
