extends GdUnitTestSuite

# Round 14, the midnight surge is staggered: people sink to dimmed at most one at a time, DIM_ARRIVAL_MIN_GAP seconds
# apart. Everyone else waits at the top of the gloomy band (just under the dimmed line) and asks again each frame, so
# the first to ask when the gate is open (in array order) goes.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.night.elapsed = Config.NIGHT_LENGTH * 0.5
	return {"runner": runner, "td": td}


func test_many_people_ready_to_sink_at_midnight_enter_dimmed_at_least_six_seconds_apart() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	# Six people ready to sink, spread across the plaza and far from the player (so nothing else happens to them).
	var ready: Array[Person] = []
	for i: int in range(6):
		var p := td.people[i]
		TopDownTestUtil.place(p, Vector3(-30 + 12 * i, 0, 30), i % 3, 0.9)
		ready.append(p)
	var sank_at: Dictionary = {}
	var frame := 0
	for step: int in range(60 * 45):  # 45 seconds: long enough for all six to take their turn.
		await runner.simulate_frames(1)
		frame += 1
		for p: Person in ready:
			if p.level >= 2 and not sank_at.has(p):
				sank_at[p] = frame / 60.0
	assert_int(sank_at.size()).is_equal(6)

	var times: Array[float] = []
	for p: Person in ready:
		times.append(sank_at[p])
	times.sort()
	# The first one goes at once (the gate is open at the start of the night).
	assert_float(times[0]).is_less(0.2)
	# Every later one came at least DIM_ARRIVAL_MIN_GAP after the one before (one frame of slack for the timing).
	for k: int in range(1, times.size()):
		assert_float(times[k] - times[k - 1]).is_greater_equal(Config.DIM_ARRIVAL_MIN_GAP - 1.0 / 60.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_ones_who_wait_stay_gloomy_at_the_top_of_the_band_and_sink_in_array_order() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var first := td.people[0]
	var second := td.people[1]
	var third := td.people[2]
	TopDownTestUtil.place(first, Vector3(-30, 0, 30), 0, 0.9)
	TopDownTestUtil.place(second, Vector3(-18, 0, 30), 1, 0.95)
	TopDownTestUtil.place(third, Vector3(-6, 0, 30), 2, 0.92)
	await runner.simulate_frames(2)
	# The first in array order sinks; the others are held at the top of the gloomy band, not at their own gloom.
	assert_int(first.level).is_equal(2)
	# They are held in the top of the gloomy band: just under the dimmed line (and still gloomy).
	assert_int(second.level).is_equal(1)
	assert_float(second.gloom).is_greater_equal(Config.INTRO_DIM_CAP - 0.0001)
	assert_float(second.gloom).is_less(Config.GLOOM_LEVEL_STEPS[1])
	assert_int(third.level).is_equal(1)
	assert_float(third.gloom).is_less(Config.GLOOM_LEVEL_STEPS[1])
	# Waiting people never sink while the gate is shut.
	await runner.simulate_frames(int(Config.DIM_ARRIVAL_MIN_GAP * 60.0) - 30)
	assert_int(second.level).is_equal(1)
	# When the gate opens, the next in array order goes.
	await runner.simulate_frames(60)
	assert_int(second.level).is_equal(2)
	assert_int(third.level).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_stagger_does_not_lift_someone_who_is_already_dimmed() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var first := td.people[0]
	var second := td.people[1]
	TopDownTestUtil.place(first, Vector3(-30, 0, 30), 0, 0.9)
	await runner.simulate_frames(2)
	assert_int(first.level).is_equal(2)
	# A second dimmed person placed while the gate is shut is held as gloomy, and the first stays dimmed.
	TopDownTestUtil.place(second, Vector3(-18, 0, 30), 1, 0.95)
	await runner.simulate_frames(30)
	assert_int(first.level).is_equal(2)
	assert_int(second.level).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)
