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
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0


# --- The constants -----------------------------------------------------------------------------------------------


func test_the_plaza_is_the_town_span_and_the_ground_grid_matches() -> void:
	assert_float(Config.WORLD_SCALE).is_equal_approx(100.0 / 70.0, 0.00001)
	assert_int(Config.TD_PLAZA_SIZE).is_equal(114)  # Grid fixes: 4 x 12 + 18 + 4 x 12 (was 100).
	assert_int(Config.TD_PEOPLE_COUNT).is_equal(60)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	# One-metre tiles: a 114 x 114 grid.
	assert_int(td.ground._size).is_equal(114)
	assert_int(td.ground._colors.size()).is_equal(114 * 114)
	assert_float(td.ground.paint_radius).is_equal_approx(6.0 * Config.WORLD_SCALE, 0.0001)
	# Every block and the landmark are inside the walls, and the start area stays clear of them.
	var half := Config.TD_PLAZA_SIZE / 2.0
	for pos: Vector3 in Plaza.BLOCK_POSITIONS:
		assert_float(absf(pos.x)).is_less_equal(half - 6.0)  # 0.4: a 12 m block fills its cell, flush with the wall.
		assert_float(absf(pos.z)).is_less_equal(half - 6.0)
		assert_float(Vector2(pos.x, pos.z).length()).is_greater(12.0)
	for lm: Vector3 in LandmarkConfig.LANDMARK_POSITIONS:
		assert_float(Vector2(lm.x, lm.z).length()).is_greater(12.0)
	for p: Person in td.people:
		assert_float(absf(p.global_position.x)).is_less(half)
		assert_float(absf(p.global_position.z)).is_less(half)
		assert_float(Vector2(p.global_position.x, p.global_position.z).length()).is_greater(
			PeopleConfig.TD_SPAWN_CENTRE_CLEAR - 0.01
		)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_territory_constants_scale_and_interaction_constants_do_not() -> void:
	var s := Config.WORLD_SCALE
	# Territory: the old (round 12) value times WORLD_SCALE.
	var territory: Dictionary = {
		"BORDER_TARGET_SPACING": [BorderConfig.BORDER_TARGET_SPACING, 2.6],
		"BORDER_EDGE_BAND": [BorderConfig.BORDER_EDGE_BAND, 1.0],
		"BORDER_OUTWARD_STEP": [BorderConfig.BORDER_OUTWARD_STEP, 1.0],
		"TD_COVER_RADIUS": [GroundConfig.TD_COVER_RADIUS, 3.0],
		"TD_ERODE_RADIUS": [GroundConfig.TD_ERODE_RADIUS, 2.0],
		"ZONE_RADIUS": [PeopleConfig.ZONE_RADIUS, 6.0],
		"SPREAD_RADIUS": [PeopleConfig.SPREAD_RADIUS, 6.0],
		"NO_ZONE_DISTANCE": [PeopleConfig.NO_ZONE_DISTANCE, 20.0],
		"TD_SPAWN_EDGE": [PeopleConfig.TD_SPAWN_EDGE, 3.0],
		"TD_SPAWN_CENTRE_CLEAR": [PeopleConfig.TD_SPAWN_CENTRE_CLEAR, 5.0],
		"TD_SPAWN_SPACING": [PeopleConfig.TD_SPAWN_SPACING, 2.5],
		"TD_PURSUIT_SEARCH_RADIUS": [PeopleConfig.TD_PURSUIT_SEARCH_RADIUS, 25.0],
		"EDGE_PRESSURE_REACH": [BorderConfig.EDGE_PRESSURE_REACH, 12.0],
	}
	for key: String in territory.keys():
		var pair: Array = territory[key]
		var now: float = pair[0]
		var old: float = pair[1]
		assert_float(now / (old * s)).override_failure_message(key).is_equal_approx(1.0, 0.001)
	# 0.4: landmarks and blocks are placed in metres on the town grid (not scaled): 12 m cells, 18 m start, 12 m streets.
	assert_float(LandmarkConfig.LANDMARK_POSITIONS[0].x).is_equal_approx(27.0, 0.0001)
	assert_float(LandmarkConfig.LANDMARK_POSITIONS[0].z).is_equal_approx(-27.0, 0.0001)
	# A per-metre rate shrinks by the same factor, so the same fraction of the way gives the same rate.
	assert_float(PeopleConfig.GLOOM_GROWTH_PER_METER * s).is_equal_approx(0.0008, 0.000001)
	# Round numbers from the brief.
	assert_float(BorderConfig.BORDER_TARGET_SPACING).is_equal_approx(3.71, 0.01)

	# Interaction and bodies: exactly the round 12 values.
	assert_float(PlayerConfig.TD_AUTO_RANGE).is_equal(10.0)
	assert_float(SpiritConfig.GRAB_RANGE).is_equal(2.0)
	assert_float(SpiritConfig.GRAB_HIT_RANGE).is_equal(1.3)
	assert_float(SpiritConfig.GRAB_NOTICE_RANGE).is_equal(7.0)
	assert_float(MoodConfig.SHELTER_RADIUS).is_equal(2.0)
	assert_float(MoodConfig.SKITTISH_RADIUS).is_equal(5.0)
	assert_float(ProjectileConfig.TD_PROJECTILE_HIT_RADIUS).is_equal(0.7)
	assert_float(ProjectileConfig.TD_NOTE_SPEED).is_equal(15.0)
	assert_float(ProjectileConfig.TD_FLOWER_SPEED).is_equal(9.0)
	assert_float(SpiritConfig.TD_BURST_RADIUS).is_equal(5.5)
	assert_float(BorderConfig.BORDER_PRESS_RANGE).is_equal(1.5)
	assert_float(PeopleConfig.TD_DIMMED_STOP_DISTANCE).is_equal(2.5)
	assert_vector(Plaza.BLOCK_SIZE).is_equal(Vector3(12, 3, 12))
	assert_vector(LandmarkConfig.BORDER_LANDMARK_SIZE).is_equal(Vector3(4, 3.5, 4))

	# Speeds: about 10% faster, not scaled by 1.43.
	assert_float(PlayerConfig.TD_MOVE_SPEED / 6.9).is_equal_approx(1.1, 0.01)
	assert_float(PlayerConfig.TD_RUN_SPEED / 10.9).is_equal_approx(1.1, 0.01)
	assert_float(PeopleConfig.TD_DIMMED_DRIFT_SPEED / 0.92).is_equal_approx(1.1, 0.01)
	assert_float(NightConfig.NIGHT_LENGTH).is_equal(180.0)


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
		var spot := centre + Vector3(cos(a) * PlayerConfig.TD_AUTO_RANGE, 0, sin(a) * PlayerConfig.TD_AUTO_RANGE)
		assert_bool(rect.has_point(td.camera.unproject_position(spot))).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The rules behave the same, bigger ----------------------------------------------------------------------------


# Gates need their width over the territory spacing members (an 18 m start side 5, a 12 m side or street mouth 4).
func test_a_gate_asks_for_its_width_over_the_scaled_spacing() -> void:
	var z := Zone.new()
	assert_int(z.members_needed()).is_equal(20)
	assert_int(ceili(18.0 / BorderConfig.BORDER_TARGET_SPACING)).is_equal(5)
	assert_int(ceili(12.0 / BorderConfig.BORDER_TARGET_SPACING)).is_equal(4)


# --- Performance --------------------------------------------------------------------------------------------------


# A full border of all 60 people on the 100 x 100 grid: the whole per-frame update (border, cover, paint, people, HUD)
# (best of three 40-frame batches) stays under a budget. Headless, so this is the simulation cost, not drawing.
func test_perf_a_full_border_of_sixty_people_updates_within_the_frame_budget() -> void:
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
	# Round 16: 4.5 ms (was 7). History: 4 ms, 5 ms (round 13b), 7 ms (round 14) were all loosened to absorb coverage
	# probes and parallel-gate load (the test once read 7.3 ms in a busy instrumented run). It is now measured where
	# that noise is gone: plain (no probes), alone on the machine, after the parallel batch. Eight such runs measured
	# 2.55, 2.56, 2.59, 2.65, 2.66, 2.68, 2.68, 2.94 ms (max 2.94). Budget = max x 1.5, rounded up to 4.5 ms.
	# Round 22: 6.7 ms (was 4.5), recalibrated at the user's request after the test turned flaky. The same method on
	# pre-round-22 code read 3.90, 4.00, 4.14, 4.20, 4.26, 4.28, 4.30, 4.44 ms (max 4.44), measured before any round 22
	# code was merged, so its cost is not absorbed. Budget = max x 1.5, rounded up to 6.7 ms.
	# If a real change pushes this past 6.7 ms plain, that is a real slowdown: find it before touching the number.
	# The name starts with test_perf_, so tools/run_tests.py runs it alone, plain, after the parallel batch and sets
	# POSITIVEFPS_PERF_ENFORCE=1. In the instrumented coverage run it still executes (its lines count) but is not timed.
	if OS.get_environment("POSITIVEFPS_PERF_ENFORCE") == "1":
		assert_float(per_frame_ms).is_less(6.7)
	await TopDownTestUtil.leave_loaded_scene(td)


# Spawn rules at the new scale: the centre stays clear, blocks and neighbours are kept away from, and a round that has
# ended does not end again.
func test_spawn_spots_keep_clear_of_the_centre_blocks_and_each_other() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	var none: Array[Vector3] = []
	assert_bool(td.plaza.spot_ok(Vector3(PeopleConfig.TD_SPAWN_CENTRE_CLEAR - 0.5, 0, 0), none)).is_false()
	assert_bool(td.plaza.spot_ok(Plaza.BLOCK_POSITIONS[0] * Vector3(1, 0, 1), none)).is_false()
	var near: Array[Vector3] = [Vector3(11, 0, 11)]  # A street crossing: no block within reach of the spots tried.
	assert_bool(td.plaza.spot_ok(Vector3(11 + PeopleConfig.TD_SPAWN_SPACING - 0.5, 0, 11), near)).is_false()
	assert_bool(td.plaza.spot_ok(Vector3(11 + PeopleConfig.TD_SPAWN_SPACING + 0.5, 0, 11), near)).is_true()
	td.level_end.end_round("Test")
	assert_bool(td.running).is_false()
	td.level_end.end_round("Again")
	assert_bool(td.running).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)
