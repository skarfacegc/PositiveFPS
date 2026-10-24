extends GdUnitTestSuite

# Round 7 grace cue, in the real top-down level: a rescue is made by locked fire (real clicks). A warm ring on the
# ground pulses under the rescued person and their body glows, both fading out over the last second of grace.
# Also measures how many frames each element takes to rescue a light-grey person 3 m away (locked fire).


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Moves the mouse over the floor under `spot` and clicks there (lock-on).
func _click_at(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


# Locks onto `target` and holds fire until it is rescued. Returns the frames it took (or `cap` if it never was).
func _frames_to_rescue(runner: GdUnitSceneRunner, td: TopDownMain, target: Person, cap: int) -> int:
	await _click_at(runner, td, target.global_position)
	var frames := 0
	while not target.is_rescued and frames < cap:
		await runner.simulate_frames(1)
		frames += 1
	return frames


func test_rescue_shows_a_pulsing_ring_and_glow_that_end_with_the_grace() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	await _frames_to_rescue(runner, td, target, 600)
	assert_bool(target.is_rescued).is_true()

	# During the grace period the ring is visible and the body glows.
	await runner.simulate_frames(1)
	assert_bool(target.grace_ring.visible).is_true()
	assert_bool(target.body_mat.emission_enabled).is_true()

	# The ring pulses: its scale moves between about 0.9 and 1.15 times its size, changing frame to frame.
	var lo := INF
	var hi := -INF
	var changes := 0
	var last := -1.0
	for i: int in range(60):
		await runner.simulate_frames(1)
		var sx: float = target.grace_ring.scale.x
		lo = minf(lo, sx)
		hi = maxf(hi, sx)
		if not is_equal_approx(sx, last):
			changes += 1
		last = sx
	assert_float(hi - lo).is_greater(0.2)
	assert_float(lo).is_greater_equal(0.89)
	assert_float(hi).is_less_equal(1.16)
	assert_int(changes).is_greater(30)

	# Past the grace period, the ring and the glow are gone.
	await runner.simulate_frames(int((Config.TD_RESCUE_GRACE_SECONDS + 0.5) * 60.0))
	assert_bool(target.grace_ring.visible).is_false()
	assert_bool(target.body_mat.emission_enabled).is_false()


func test_grace_ring_and_glow_fade_over_the_last_second() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	await _frames_to_rescue(runner, td, target, 600)
	assert_bool(target.is_rescued).is_true()

	# Plenty of grace left: full strength.
	target.grace_left = 3.0
	await runner.simulate_frames(1)
	var full_alpha: float = target._grace_mat.albedo_color.a
	var full_glow: float = target.body_mat.emission_energy_multiplier
	# Half a second left: within the fade, so both are weaker.
	target.grace_left = 0.5
	await runner.simulate_frames(1)
	assert_float(target._grace_mat.albedo_color.a).is_less(full_alpha * 0.7)
	assert_float(target.body_mat.emission_energy_multiplier).is_less(full_glow * 0.7)


func test_light_person_three_metres_away_is_rescued_quickly_by_each_element() -> void:
	# Frames to rescue a light-grey person 3 m from the player, by locked fire, for each element. One level, one fresh
	# person per element. The numbers are printed so tuning can be compared between rounds.
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var results: Array[int] = []
	for affinity: int in range(3):
		TopDownTestUtil.send_everyone_away(td)
		var target: Person = td.people[affinity]
		TopDownTestUtil.place(target, Vector3(0, 0, -3), affinity, 0.0)
		var frames: int = await _frames_to_rescue(runner, td, target, 600)
		print("ROUND7 frames to rescue at 3 m: %s = %d" % [Config.ELEMENT_NAMES[affinity], frames])
		results.append(frames)
		# Let the shots in the air finish before the next element.
		await runner.simulate_frames(120)
	for frames: int in results:
		assert_int(frames).is_less(150)
