extends GdUnitTestSuite

# Round 17, hover targeting: input-driven (real mouse motion through the scene runner). A held target is kept for at
# most HOVER_STICK_SECONDS (0.2 s, 12 frames at 60 Hz) after the cursor stops being over or nearest to it. A
# person directly under the cursor takes over at once. The frame counts below leave one or two frames of slack.


# The level with everyone parked away and the player at the origin, in hover mode.
func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.HOVER_STICKY)
	return {"runner": runner, "td": td}


# Moves the real mouse to `spot` on the floor.
func _point(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))


func test_moving_the_cursor_onto_another_person_switches_at_once() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var a: Person = td.people[0]
	var b: Person = td.people[1]
	TopDownTestUtil.place(a, Vector3(0, 0, -8), 0, 0.0)
	TopDownTestUtil.place(b, Vector3(4, 0, -5), 1, 0.0)
	_point(runner, td, a.global_position)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(a)
	# Directly over B: no wait (within two frames, far less than HOVER_STICK_SECONDS).
	_point(runner, td, b.global_position)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(b)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_empty_ground_nearer_another_person_switches_after_the_stick_time_not_before() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var a: Person = td.people[0]
	var b: Person = td.people[1]
	TopDownTestUtil.place(a, Vector3(0, 0, -8), 0, 0.0)
	TopDownTestUtil.place(b, Vector3(4, 0, -5), 1, 0.0)
	_point(runner, td, a.global_position)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(a)
	# (4, -2) is 3 m from B (in hover reach, not under the cursor) and 7.2 m from A (out of reach): B is the nearest.
	_point(runner, td, Vector3(4, 0, -2))
	await runner.simulate_frames(10)  # 0.17 s: still inside the stick time.
	assert_object(td.player.target).is_same(a)
	await runner.simulate_frames(6)  # 0.27 s: past HOVER_STICK_SECONDS.
	assert_object(td.player.target).is_same(b)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_wobble_off_the_target_and_back_within_the_stick_time_keeps_it() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var a: Person = td.people[0]
	TopDownTestUtil.place(a, Vector3(0, 0, -8), 0, 0.0)
	_point(runner, td, a.global_position)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(a)
	# Off to empty ground (nobody within reach) for 0.1 s, then back on A.
	_point(runner, td, Vector3(-6, 0, 6))
	await runner.simulate_frames(6)
	assert_object(td.player.target).is_same(a)
	_point(runner, td, a.global_position)
	await runner.simulate_frames(30)
	assert_object(td.player.target).is_same(a)
	# Off again for longer than the stick time, with nobody under the cursor: the target clears.
	_point(runner, td, Vector3(-6, 0, 6))
	await runner.simulate_frames(18)  # 0.3 s
	assert_object(td.player.target).is_null()
	await TopDownTestUtil.leave_loaded_scene(td)
