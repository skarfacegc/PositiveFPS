extends GdUnitTestSuite

# Round 13a: the world scale-up (WORLD_SCALE, 70 m -> 100 m plaza). The rule: territory constants scale, interaction and
# body constants do not. Also: the border rules behave the same at the new size, and the bigger grid stays cheap.


func _rescue_ring(td: TopDownMain, count: int, r: float) -> void:
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0


func _organic_border() -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	return border


func _ring(n: int, r: float) -> Array[Person]:
	var out: Array[Person] = []
	for i: int in range(n):
		var a := TAU * float(i) / float(n)
		var p: Person = auto_free(Person.new())
		p.position = Vector3(cos(a) * r, 0.0, sin(a) * r)
		p.is_rescued = true
		p.joy = Config.JOY_MAX
		out.append(p)
	return out


# The area inside a settled loop of `n` people (centre fixed at the origin), in square metres.
func _settled_area(n: int, r: float) -> float:
	var border := _organic_border()
	border._has_centre = true
	border.centre = Vector3.ZERO
	var rescued := _ring(n, r)
	for i: int in range(400):
		border.update(rescued, 1.0 / 60.0, 1.0)
	return absf(_polygon_area(border.polygon))


func _polygon_area(pts: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in range(pts.size()):
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


# --- The constants -----------------------------------------------------------------------------------------------


func test_the_plaza_is_a_hundred_metres_and_the_ground_grid_matches() -> void:
	assert_float(Config.WORLD_SCALE).is_equal_approx(100.0 / 70.0, 0.00001)
	assert_int(Config.TD_PLAZA_SIZE).is_equal(100)
	assert_int(Config.TD_PEOPLE_COUNT).is_equal(60)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	# One-metre tiles: a 100 x 100 grid.
	assert_int(td.ground._size).is_equal(100)
	assert_int(td.ground._colors.size()).is_equal(100 * 100)
	assert_float(td.ground.paint_radius).is_equal_approx(6.0 * Config.WORLD_SCALE, 0.0001)
	# Every block and the landmark are inside the walls, and the start area stays clear of them.
	var half := Config.TD_PLAZA_SIZE / 2.0
	for pos: Vector3 in TopDownMain.BLOCK_POSITIONS:
		assert_float(absf(pos.x)).is_less(half - 6.0)
		assert_float(absf(pos.z)).is_less(half - 6.0)
		assert_float(Vector2(pos.x, pos.z).length()).is_greater(12.0)
	assert_float(Vector2(Config.BORDER_LANDMARK_POS.x, Config.BORDER_LANDMARK_POS.z).length()).is_greater(12.0)
	for p: Person in td.people:
		assert_float(absf(p.global_position.x)).is_less(half)
		assert_float(absf(p.global_position.z)).is_less(half)
		assert_float(Vector2(p.global_position.x, p.global_position.z).length()).is_greater(
			Config.TD_SPAWN_CENTRE_CLEAR - 0.01
		)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_territory_constants_scale_and_interaction_constants_do_not() -> void:
	var s := Config.WORLD_SCALE
	# Territory: the old (round 12) value times WORLD_SCALE.
	var territory: Dictionary = {
		"BORDER_TARGET_SPACING": [Config.BORDER_TARGET_SPACING, 2.6],
		"BORDER_MAX_GAP": [Config.BORDER_MAX_GAP, 3.5],
		"BORDER_PUSH": [Config.BORDER_PUSH, 2.4],
		"BORDER_MIN_RADIUS": [Config.BORDER_MIN_RADIUS, 3.0],
		"BORDER_POST_REACH": [Config.BORDER_POST_REACH, 2.0],
		"BORDER_EDGE_BAND": [Config.BORDER_EDGE_BAND, 1.0],
		"BORDER_OUTWARD_STEP": [Config.BORDER_OUTWARD_STEP, 1.0],
		"BORDER_INNER_SPACING": [Config.BORDER_INNER_SPACING, 0.7],
		"BORDER_SHOVE_AMOUNT": [Config.BORDER_SHOVE_AMOUNT, 1.5],
		"TD_COVER_RADIUS": [Config.TD_COVER_RADIUS, 3.0],
		"TD_ERODE_RADIUS": [Config.TD_ERODE_RADIUS, 2.0],
		"ZONE_RADIUS": [Config.ZONE_RADIUS, 6.0],
		"SPREAD_RADIUS": [Config.SPREAD_RADIUS, 6.0],
		"NO_ZONE_DISTANCE": [Config.NO_ZONE_DISTANCE, 20.0],
		"TD_SPAWN_EDGE": [Config.TD_SPAWN_EDGE, 3.0],
		"TD_SPAWN_CENTRE_CLEAR": [Config.TD_SPAWN_CENTRE_CLEAR, 5.0],
		"TD_SPAWN_SPACING": [Config.TD_SPAWN_SPACING, 2.5],
		"TD_PURSUIT_SEARCH_RADIUS": [Config.TD_PURSUIT_SEARCH_RADIUS, 25.0],
		"EDGE_PRESSURE_REACH": [Config.EDGE_PRESSURE_REACH, 12.0],
	}
	for key: String in territory.keys():
		var pair: Array = territory[key]
		var now: float = pair[0]
		var old: float = pair[1]
		assert_float(now / (old * s)).override_failure_message(key).is_equal_approx(1.0, 0.001)
	assert_float(Config.BORDER_LANDMARK_POS.x).is_equal_approx(18.0 * s, 0.0001)
	assert_float(Config.BORDER_LANDMARK_POS.z).is_equal_approx(-16.0 * s, 0.0001)
	# A per-metre rate shrinks by the same factor, so the same fraction of the way gives the same rate.
	assert_float(Config.GLOOM_GROWTH_PER_METER * s).is_equal_approx(0.0008, 0.000001)
	# Round numbers from the brief.
	assert_float(Config.BORDER_TARGET_SPACING).is_equal_approx(3.71, 0.01)
	assert_float(Config.BORDER_MAX_GAP).is_equal_approx(5.0, 0.01)
	assert_float(Config.BORDER_PUSH).is_equal_approx(3.43, 0.01)

	# Interaction and bodies: exactly the round 12 values.
	assert_float(Config.TD_AUTO_RANGE).is_equal(10.0)
	assert_float(Config.GRAB_RANGE).is_equal(2.0)
	assert_float(Config.GRAB_HIT_RANGE).is_equal(1.3)
	assert_float(Config.GRAB_NOTICE_RANGE).is_equal(7.0)
	assert_float(Config.SHELTER_RADIUS).is_equal(2.0)
	assert_float(Config.SKITTISH_RADIUS).is_equal(5.0)
	assert_float(Config.TD_PROJECTILE_HIT_RADIUS).is_equal(0.7)
	assert_float(Config.TD_NOTE_SPEED).is_equal(15.0)
	assert_float(Config.TD_FLOWER_SPEED).is_equal(9.0)
	assert_float(Config.TD_BURST_RADIUS).is_equal(5.5)
	assert_float(Config.BORDER_PRESS_RANGE).is_equal(1.5)
	assert_float(Config.BORDER_PUSH_WIDTH).is_equal(0.5)
	assert_float(Config.BORDER_SHOVE_RANGE).is_equal(4.0)
	assert_float(Config.TD_DARK_STOP_DISTANCE).is_equal(2.5)
	assert_vector(TopDownMain.BLOCK_SIZE).is_equal(Vector3(4, 2, 4))
	assert_vector(Config.BORDER_LANDMARK_SIZE).is_equal(Vector3(4, 3.5, 4))

	# Speeds: about 10% faster, not scaled by 1.43.
	assert_float(Config.TD_MOVE_SPEED / 6.9).is_equal_approx(1.1, 0.01)
	assert_float(Config.TD_RUN_SPEED / 10.9).is_equal_approx(1.1, 0.01)
	assert_float(Config.TD_DARK_DRIFT_SPEED / 0.92).is_equal_approx(1.1, 0.01)
	assert_float(Config.NIGHT_LENGTH).is_equal(180.0)


# Round 14: the default zoom is 19.5 m tall (was 18). The ring must still fit at the default zoom.
func test_the_camera_is_nineteen_and_a_half_metres_tall_and_the_ten_metre_ring_fits_on_a_720p_screen() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	assert_float(td.camera.size).is_equal_approx(19.5, 0.0001)
	var rect := td.get_viewport().get_visible_rect()
	var centre := td.player.global_position
	for i: int in range(24):
		var a := TAU * float(i) / 24.0
		var spot := centre + Vector3(cos(a) * Config.TD_AUTO_RANGE, 0, sin(a) * Config.TD_AUTO_RANGE)
		assert_bool(rect.has_point(td.camera.unproject_position(spot))).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The rules behave the same, bigger ----------------------------------------------------------------------------


# n people hold a loop of about n x spacing, so the area it encloses goes with spacing squared: WORLD_SCALE squared
# (about 2.04) times the area at the round 12 spacing.
func test_the_same_people_enclose_about_twice_the_area() -> void:
	var s := Config.WORLD_SCALE
	for n: int in [8, 12, 20]:
		var old_perimeter := float(n) * 2.6
		var old_area := old_perimeter * old_perimeter / (4.0 * PI)
		var ratio := _settled_area(n, 4.0 * s) / old_area
		assert_float(ratio).override_failure_message("n=%d ratio %f" % [n, ratio]).is_between(
			s * s * 0.85, s * s * 1.15
		)


func test_overextending_at_the_new_scale_opens_gaps_everywhere() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	_rescue_ring(td, 4, 2.0 * Config.WORLD_SCALE)
	await runner.simulate_frames(600)
	assert_bool(td.border.active).is_true()
	assert_int(td.border.gap_count()).is_equal(td.border.segment_gap.size())
	assert_int(td.border.gap_region_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# Two dimmed people press one member of a healthy border: exactly one local gap opens, within a reasonable time. The
# time in frames is printed so the round notes can quote it.
func test_two_pressers_open_exactly_one_local_gap_at_the_new_scale() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	_rescue_ring(td, 20, 7.0 * Config.WORLD_SCALE)
	await runner.simulate_frames(600)
	var border: Border = td.border
	assert_bool(border.active).is_true()
	assert_int(border.member_count).is_equal(20)
	assert_int(border.gap_count()).is_equal(0)

	var target: Person = border.members[7]
	var out := Vector3(target.position.x - border.centre.x, 0.0, target.position.z - border.centre.z).normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	TopDownTestUtil.place(td.people[20], target.position + out * 1.2, 1, 0.95)
	TopDownTestUtil.place(td.people[21], target.position + out * 1.2 + side * 0.6, 2, 0.95)
	var frames := 0
	while border.gap_region_count() == 0 and frames < 1800:
		await runner.simulate_frames(1)
		frames += 1
	print("WORLD_SCALE local gap opened after %d frames (%.1f s)" % [frames, float(frames) / 60.0])
	assert_int(border.gap_region_count()).is_equal(1)
	# Round 14: the second presser waits DIM_ARRIVAL_MIN_GAP (6 s) for the midnight stagger, so the gap comes later.
	assert_int(frames).is_less(1500)
	assert_int(border.gap_count()).is_between(1, 3)
	assert_int(border.gap_count()).is_less(border.segment_gap.size() / 2)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Performance --------------------------------------------------------------------------------------------------


# A full border of all 60 people on the 100 x 100 grid: the whole per-frame update (border, cover, paint, people, HUD)
# (best of three 40-frame batches) stays under a budget. Headless, so this is the simulation cost, not drawing.
func test_a_full_border_of_sixty_people_updates_within_the_frame_budget() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	_rescue_ring(td, Config.TD_PEOPLE_COUNT, 30.0)
	await runner.simulate_frames(600)
	assert_bool(td.border.active).is_true()
	assert_int(td.rescued_count).is_equal(Config.TD_PEOPLE_COUNT)
	# Best of three batches of 40 frames, so a busy machine does not fail the check.
	var per_frame_ms := 1.0e9
	for batch: int in range(3):
		var start := Time.get_ticks_usec()
		for i: int in range(40):
			td._process(1.0 / 60.0)
		per_frame_ms = minf(per_frame_ms, float(Time.get_ticks_usec() - start) / 1000.0 / 40.0)
	print("WORLD_SCALE sim update with 60 people, full border: %.3f ms per frame" % per_frame_ms)
	# Round 13b: 5 ms (was 4): the communication overlays add about 0.5 ms when the suite runs instrumented for coverage
	# (about 0.1 ms plain); the plain simulation is about 2 ms.
	# Round 14: 7 ms (was 5). Instrumented for coverage the frame measured 4.5-4.8 ms before this round and 5.5-5.9 ms
	# after it (one run under parallel load reached 6.9 ms). Bisecting (sheltering pass, camera zoom, dimmed rings,
	# camera and UI constants) did not find one cause: the new per-frame statements add about 1 ms only when the coverage
	# probes count them. Plain it moved from about 2.65 ms to 2.75 ms, so the game itself is not measurably slower.
	assert_float(per_frame_ms).is_less(7.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# Spawn rules at the new scale: the centre stays clear, blocks and neighbours are kept away from, and a round that has
# ended does not end again.
func test_spawn_spots_keep_clear_of_the_centre_blocks_and_each_other() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	var none: Array[Vector3] = []
	assert_bool(td._spot_ok(Vector3(Config.TD_SPAWN_CENTRE_CLEAR - 0.5, 0, 0), none)).is_false()
	assert_bool(td._spot_ok(TopDownMain.BLOCK_POSITIONS[0] * Vector3(1, 0, 1), none)).is_false()
	var near: Array[Vector3] = [Vector3(20, 0, 0)]
	assert_bool(td._spot_ok(Vector3(20 + Config.TD_SPAWN_SPACING - 0.5, 0, 0), near)).is_false()
	assert_bool(td._spot_ok(Vector3(20 + Config.TD_SPAWN_SPACING + 0.5, 0, 0), near)).is_true()
	td._end_round("Test")
	assert_bool(td.running).is_false()
	td._end_round("Again")
	assert_bool(td.running).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)
