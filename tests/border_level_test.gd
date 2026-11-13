# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# The living border in the real top-down level (round 9), on the town grid since 0.4 (#55, #56): forming on the start
# square, members on gates, holding gloom, relapse, painting inside, buildings and the landmark. Most rescues are direct
# (receive_joy) so the rules are checked quickly. The rescue and the F3 key go through real input, as a player would.
# Unit-level checks use the Border and Building classes.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# Rescues `p` directly at `spot` (a joy hit that is always enough).
func _rescue(p: Person, spot: Vector3) -> void:
	TopDownTestUtil.place(p, spot, p.affinity, 0.0)
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# Rescues the first `count` people, standing on a ring of radius `r` around `c`. Returns them.
func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int) -> Array[Person]:
	var out: Array[Person] = []
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		_rescue(td.people[i], c + Vector3(cos(a) * r, 0.0, sin(a) * r))
		out.append(td.people[i])
	return out


# Lock on to `person` with a real click on the floor under them (lock-on mode).
func _click_to_lock(runner: GdUnitSceneRunner, td: TopDownMain, person: Person) -> void:
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, person.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


# A Border with no level around it, for the unit-level checks: the zone as given (the start square when no cells), the
# line traced and drawn as its own polygon.
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


# Unrescued/rescued people with no level (only their positions matter to the border rules).
func _people(count: int) -> Array[Person]:
	var out: Array[Person] = []
	for i: int in range(count):
		var p: Person = auto_free(Person.new())
		p.affinity = i % 3
		add_child(p)
		out.append(p)
	return out


# --- Forming, centre and gates ------------------------------------------------------------------------------


func test_no_border_until_three_are_rescued() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(0, 0, 0), 2.0, 2)
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(30)
	assert_bool(td.border.active).is_false()
	assert_bool(td.border.formed).is_false()
	assert_int(td.border.polygon.size()).is_equal(0)


func test_the_border_forms_on_the_start_square_after_three_rescues() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(4, 0, -4), 1.5, 3)
	await runner.simulate_frames(120)
	assert_bool(td.border.active).is_true()
	assert_int(td.border.zone.held.size()).is_equal(1)
	assert_vector(td.border.centre).is_equal(Vector3.ZERO)
	# The line is the start square's outline: a point every 2 m along four 18 m gates.
	assert_int(td.border.polygon.size()).is_equal(36)
	assert_float(td.border.perimeter).is_equal(72.0)
	for pt: Vector2 in td.border.polygon:
		assert_float(maxf(absf(pt.x), absf(pt.y))).is_equal_approx(9.0, 0.001)


func test_members_walk_to_their_places_on_the_gates() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(0, 0, 0), 3.0, 8)
	await runner.simulate_frames(300)
	var border: Border = td.border
	assert_int(border.member_count).is_equal(8)
	assert_int(border.inner_count).is_equal(0)
	var per_gate: Dictionary = {}
	for p: Person in border.members:
		var target: Vector3 = border._targets[p]
		assert_float(Vector2(p.position.x - target.x, p.position.z - target.z).length()).is_less(0.15)
		# On the line: the square's outline is the box |x| = 9 or |z| = 9.
		assert_float(maxf(absf(p.position.x), absf(p.position.z))).is_equal_approx(9.0, 0.2)
		var gate: int = border.zone.nearest_gate(Vector2(p.position.x, p.position.z))["id"]
		per_gate[gate] = (per_gate.get(gate, 0) as int) + 1
	assert_int(per_gate.size()).is_equal(4)  # Shared out: two to each of the four gates.
	for gate: int in per_gate:
		assert_int(per_gate[gate] as int).is_equal(2)


func test_members_beyond_what_the_gates_need_stand_inside_on_open_ground() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(0, 0, 0), 3.0, 24)
	await runner.simulate_frames(400)
	var border: Border = td.border
	assert_int(border.required_members()).is_equal(12)  # Loop tuning (#93): was 20.
	assert_int(border.member_count).is_equal(12)
	assert_int(border.inner_count).is_equal(12)  # 24 rescued: 12 spare stand inside (was 4).
	for p: Person in border.inner:
		assert_bool(BorderShape.is_inside(border.polygon, Vector2(p.position.x, p.position.z))).is_true()
		assert_float(maxf(absf(p.position.x), absf(p.position.z))).is_less(9.0 - BorderConfig.GATE_INNER_INSET + 0.3)


func test_three_locked_rescues_by_real_clicks_form_the_border() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var spots: Array[Vector3] = [Vector3(-3, 0, -4), Vector3(0, 0, -5), Vector3(3, 0, -4)]
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


# --- Gates and gaps (unit-level: the line is traced directly) -----------------------------------------------------


func test_few_people_spread_over_the_gates_and_the_line_is_still_intact() -> void:
	var border := _bare_border()
	var people := _people(3)
	var rescued: Array[Person] = []
	for i: int in range(3):
		people[i].position = Vector3(float(i), 0.0, 0.0)
		people[i].is_rescued = true
		rescued.append(people[i])
	border._assign_members(rescued)
	assert_int(border.member_count).is_equal(3)
	assert_int(border.slot_count).is_equal(12)  # Loop tuning (#93): was 20.
	assert_int(border.gap_count()).is_equal(0)  # A thin line is not a broken one (the next pass makes it dent sooner).
	assert_bool(border.segment_is_gap(0)).is_false()
	assert_bool(border.segment_colour(0).is_equal_approx(BorderConfig.BORDER_INTACT_COLOUR)).is_true()
	assert_float(border.spacing).is_equal_approx(72.0 / 3.0, 0.001)


# --- Holding gloom ---------------------------------------------------------------------------------------


func test_a_dimmed_person_outside_is_stopped_at_an_intact_gate() -> void:
	var border := _bare_border()
	# Walk from outside (x = 12) toward the middle along a line through the east gate (x = 9).
	var from := Vector3(12.0, 0.0, 0.33)
	var to := Vector3(3.0, 0.0, 0.33)
	var stopped := border.clip_move(from, to)
	assert_float(stopped.x).is_greater(8.9)
	assert_float(stopped.x).is_less(9.1)
	assert_bool(border.line_blocks(from, to)).is_true()


func test_a_dimmed_person_outside_is_stopped_at_a_wall_too() -> void:
	var border := _bare_border([Vector2i(3, 2)])
	var from := Vector3(36.0, 0.0, 0.33)  # Outside the block's east face (x = 33).
	var to := Vector3(30.0, 0.0, 0.33)
	assert_bool(border.line_blocks(from, to)).is_true()
	assert_float(border.clip_move(from, to).x).is_greater(32.9)


func test_a_dimmed_person_passes_through_a_break() -> void:
	var border := _bare_border()
	var east := border.push.sample_of(Vector3(9.0, 0.0, 0.0))
	border.push.dent[east] = PushConfig.PUSH_BREAK_DEPTH + 0.3
	var nobody: Array[Person] = []
	border.push.update(nobody, 0.02, 1.0)
	border._mark_gaps()
	assert_int(border.gap_count()).is_equal(1)
	var from := Vector3(12.0, 0.0, 0.33)
	var to := Vector3(3.0, 0.0, 0.33)
	assert_bool(border.clip_move(from, to).is_equal_approx(to)).is_true()
	assert_bool(border.line_blocks(from, to)).is_false()
	# Beside the break the gate still holds.
	assert_bool(border.line_blocks(Vector3(12.0, 0.0, -6.0), Vector3(3.0, 0.0, -6.0))).is_true()


func test_a_dimmed_person_inside_the_line_is_not_held() -> void:
	var border := _bare_border()
	var from := Vector3(1.0, 0.0, 0.0)
	var to := Vector3(2.0, 0.0, 0.0)
	assert_bool(border.clip_move(from, to).is_equal_approx(to)).is_true()


func test_gloom_pressing_on_a_gate_drains_the_nearest_member_and_a_wall_is_not_pressed() -> void:
	var border := _bare_border([Vector2i(3, 2)])
	var people := _people(2)
	var member: Person = people[0]
	member.is_rescued = true
	member.joy = Config.JOY_MAX
	member.position = Vector3(-9.0, 0.0, 0.0)
	border.members.append(member)
	var pusher: Person = people[1]
	pusher.gloom = 1.0
	pusher.position = Vector3(-9.8, 0.0, 0.0)  # Outside the start square's west gate.
	var list: Array[Person] = [member, pusher]
	var before := member.joy
	border._press_gloom(list, 0.5, 1.0)
	assert_float(member.joy).is_less(before)  # An intact gate: the drain is a fraction of the gap rate.
	assert_float(pusher.position.x).is_less(-9.8)  # And the pusher is held off outward.
	member.joy = before
	pusher.position = Vector3(33.8, 0.0, 0.0)  # Outside the block's east face (a wall).
	border._press_gloom(list, 0.5, 1.0)
	assert_float(member.joy).is_equal(before)
	assert_float(pusher.position.x).is_equal_approx(33.8, 0.001)


func test_gloom_at_a_break_drains_the_nearest_member_at_the_full_rate() -> void:
	var border := _bare_border()
	var people := _people(2)
	var member: Person = people[0]
	member.is_rescued = true
	member.joy = Config.JOY_MAX
	member.position = Vector3(9.0, 0.0, 0.0)
	border.members.append(member)
	var pusher: Person = people[1]
	pusher.gloom = 1.0
	pusher.position = Vector3(9.8, 0.0, 0.0)
	var list: Array[Person] = [member, pusher]
	border._press_gloom(list, 0.5, 1.0)
	var intact_loss := Config.JOY_MAX - member.joy
	member.joy = Config.JOY_MAX
	pusher.position = Vector3(9.8, 0.0, 0.0)
	var east := border.push.sample_of(Vector3(9.0, 0.0, 0.0))
	border.push.broken[east] = true
	border.push.broken[east - 1] = true
	border._mark_gaps()
	border._press_gloom(list, 0.5, 1.0)
	var break_loss := Config.JOY_MAX - member.joy
	assert_float(intact_loss).is_greater(0.0)
	assert_float(break_loss).is_greater(intact_loss * 3.0)  # The full rate, not the intact fraction of it.
	assert_float(pusher.position.x).is_equal_approx(9.8, 0.001)  # And at a break nobody is pushed back.


func test_a_gate_that_springs_back_sweeps_a_pusher_out_but_not_a_wall_or_a_break_or_someone_far_in() -> void:
	var border := _bare_border([Vector2i(3, 2)])
	var people := _people(3)
	var near_gate: Person = people[0]
	near_gate.gloom = 1.0
	near_gate.position = Vector3(-8.9, 0.0, 0.0)  # A little inside the west gate.
	var far_in: Person = people[1]
	far_in.gloom = 1.0
	far_in.position = Vector3(-1.0, 0.0, 0.0)
	var by_wall: Person = people[2]
	by_wall.gloom = 1.0
	by_wall.position = Vector3(32.8, 0.0, 0.0)  # A little inside the block's east face, a wall.
	var list: Array[Person] = [near_gate, far_in, by_wall]
	border._press_gloom(list, 0.1, 1.0)
	assert_float(near_gate.position.x).is_less(-9.0)
	assert_vector(far_in.position).is_equal(Vector3(-1.0, 0.0, 0.0))
	assert_vector(by_wall.position).is_equal(Vector3(32.8, 0.0, 0.0))
	# Inside beside a break, a person stays where they are.
	var inside_break: Person = people[2]
	inside_break.position = Vector3(-8.9, 0.0, 3.0)
	var at := border.push.sample_of(Vector3(-9.0, 0.0, 3.0))
	border.push.broken[at] = true
	border.push.broken[at - 1] = true
	border._mark_gaps()
	border._press_gloom(list, 0.1, 1.0)
	assert_float(inside_break.position.x).is_equal_approx(-8.9, 0.001)


# --- Relapse and too few people -----------------------------------------------------------------------------


func test_a_relapsed_member_leaves_and_the_others_reshuffle() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var made := _rescue_ring(td, Vector3(0, 0, 0), 3.0, 5)
	await runner.simulate_frames(120)
	assert_int(td.border.member_count).is_equal(5)
	var leaver: Person = made[0]
	leaver.grace_left = 0.0
	leaver.drain_joy(Config.JOY_MAX)
	# Round 24: the relapse follows the wobble (up to WOBBLE_SECONDS plus its jitter), then the others reshuffle.
	await runner.simulate_frames(int((PeopleConfig.WOBBLE_SECONDS * (1.0 + PeopleConfig.WOBBLE_JITTER) + 2.0) * 60.0))
	assert_bool(leaver.is_rescued).is_false()
	assert_int(td.border.member_count).is_equal(4)
	assert_bool(td.border.members.has(leaver)).is_false()


func test_losing_the_border_by_relapse_below_three_ends_the_level() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var made := _rescue_ring(td, Vector3(0, 0, 0), 3.0, 3)
	await runner.simulate_frames(60)
	assert_bool(td.border.formed).is_true()
	made[0].grace_left = 0.0
	made[0].drain_joy(Config.JOY_MAX)
	# Round 24
	await runner.simulate_frames(int((PeopleConfig.WOBBLE_SECONDS * (1.0 + PeopleConfig.WOBBLE_JITTER) + 1.0) * 60.0))
	assert_bool(td.running).is_false()
	assert_str(td.hud.end_label.text).contains("The border fell")


func test_a_member_who_relapses_steps_out_through_the_gate() -> void:
	var border := _bare_border()
	var p: Person = _people(1)[0]
	p.position = Vector3(9.0, 0.0, 0.0)
	border.on_relapse(p)
	assert_float(p.position.x).is_equal_approx(9.0 + BorderConfig.BORDER_OUTWARD_STEP, 0.001)


# --- Inside the border --------------------------------------------------------------------------------------


func test_tiles_inside_the_line_paint_in_over_time_and_outside_stays_grey() -> void:
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(40, GroundConfig.TD_GROUND_SPREAD_SPEED, GroundConfig.TD_GROUND_FADE_SPEED, true)
	ground.set_region(_bare_border().polygon)
	var none: Array[Person] = []
	for i: int in range(10):
		ground.update_paint(none, 0.11)
	# One second in, the inside has only partly painted in (it lags), and the outside has not started.
	var inside := ground.paint_weight_at(Vector3(0.0, 0.0, 0.0))
	assert_float(inside).is_greater(0.25)
	assert_float(inside).is_less(0.6)
	assert_float(ground.paint_weight_at(Vector3(15.0, 0.0, 0.0))).is_equal(0.0)


func test_a_grey_person_inside_the_line_lightens_and_one_outside_dims() -> void:
	var border := _bare_border()
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


func test_cover_is_the_depth_inside_a_gate_and_a_wall_gives_full_cover() -> void:
	var border := _bare_border([Vector2i(3, 2)])
	assert_float(border.cover_at(Vector3(-8.99, 0.0, 0.0))).is_less(0.05)  # On the west gate.
	assert_float(border.cover_at(Vector3(-8.0, 0.0, 0.0))).is_between(0.5, 0.95)  # A metre in: most of the way there.
	assert_float(border.cover_at(Vector3(0.0, 0.0, 0.0))).is_equal(1.0)
	assert_float(border.cover_at(Vector3(32.5, 0.0, 0.0))).is_equal(1.0)  # By the block's east face: a wall.
	assert_float(border.cover_at(Vector3(40.0, 0.0, 0.0))).is_equal(0.0)  # Outside.


# --- Buildings and the landmark -----------------------------------------------------------------------------


func test_a_building_is_beautified_after_three_seconds_inside() -> void:
	var b := Building.new()
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
	lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD * 0.4, true)
	assert_float(lm.progress()).is_equal_approx(0.4, 0.001)
	assert_bool(lm.is_held()).is_false()
	lm.update(1.0, false)
	assert_float(lm.hold).is_equal(0.0)
	lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	assert_bool(lm.is_held()).is_true()


func test_a_block_and_a_landmark_square_inside_the_line_are_beautified_and_held() -> void:
	# The Bandstand square (3, 1) is held through the block north of the start: once both cells are in the zone, the
	# block is beautified (its whole footprint is inside) and the landmark is claimed after the hold, and the level
	# runs on.
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3(0, 0, 0), 3.0, 16)
	td.border.zone.take(Vector2i(2, 1))
	td.border.zone.take(Vector2i(3, 1))
	var frames := 0
	while not td.landmarks.items[0].is_held() and frames < 1500:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(td.landmarks.items[0].is_held()).is_true()
	assert_int(td.border.beautified_building_count()).is_greater_equal(2)  # The block and the landmark's own.
	assert_bool(td.border.landmark_beautified(0)).is_true()
	assert_bool(td.border.landmark_beautified(1)).is_false()  # The Garden square is not in the zone.
	await runner.simulate_frames(180)
	assert_bool(td.running).is_true()
	assert_bool(td.hud.end_panel.visible).is_false()


# --- F3 through the menu and real keys ----------------------------------------------------------------------


func test_f3_from_the_menu_shows_the_gate_labels() -> void:
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
	assert_bool(td.level_hud.debug_on).is_true()
	assert_bool(td.hud.debug_hint_label.visible).is_true()
	assert_str(td.hud.debug_hint_label.text).contains("border")
	assert_int(td.border.visible_debug_label_count()).is_equal(4)
	await TopDownTestUtil.leave_loaded_scene(td)
