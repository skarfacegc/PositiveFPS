extends GdUnitTestSuite

# Top-down crowd rules from round 6: separation, the pursuit cap, the dark drift speed, and the rescue grace period
# with its grace ring. Runs in the real top-down level. Round 8 edge-pressure rules are in edge_pressure_test.gd.
# Pure rules (pursuit_assignments) are called directly.


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


# Flat (ground) distance between two people.
func _gap(a: Person, b: Person) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


func test_two_dark_people_on_the_same_spot_push_apart() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var a: Person = td.people[0]
	var b: Person = td.people[1]
	TopDownTestUtil.place(a, Vector3(0, 0, -8), 0, 1.0)
	TopDownTestUtil.place(b, Vector3(0, 0, -8), 1, 1.0)

	await runner.simulate_frames(120)
	assert_float(_gap(a, b)).is_greater_equal(Config.TD_SEPARATION_RADIUS * 0.8)


func test_at_most_two_dark_people_drift_toward_one_rescued_person() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var rescued: Person = td.people[0]
	TopDownTestUtil.place(rescued, Vector3(0, 0, -8), 0, 0.0)
	rescued.receive_joy(0, Config.JOY_MAX, 0.0)
	assert_bool(rescued.is_rescued).is_true()
	# Four dark people all nearby, so all of them would pick this rescued person if there were no cap.
	var spots: Array[Vector3] = [Vector3(6, 0, -8), Vector3(6, 0, -5), Vector3(-6, 0, -8), Vector3(-6, 0, -5)]
	for i: int in range(spots.size()):
		TopDownTestUtil.place(td.people[i + 1], spots[i], 1, 1.0)

	var pursuit: Dictionary = td.pursuit_assignments(td.people)
	var toward_rescued := 0
	for p: Person in td.people:
		if pursuit.has(p) and pursuit[p] == rescued:
			toward_rescued += 1
	assert_int(toward_rescued).is_equal(Config.TD_MAX_PURSUERS_PER_TARGET)
	# The other two dark people get no slot, so they wander.
	assert_int(pursuit.size()).is_equal(Config.TD_MAX_PURSUERS_PER_TARGET)


func test_a_dark_person_without_a_slot_takes_the_next_nearest_rescued_person() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var near: Person = td.people[0]
	var far: Person = td.people[1]
	TopDownTestUtil.place(near, Vector3(0, 0, -8), 0, 0.0)
	TopDownTestUtil.place(far, Vector3(0, 0, -14), 0, 0.0)
	near.receive_joy(0, Config.JOY_MAX, 0.0)
	far.receive_joy(0, Config.JOY_MAX, 0.0)
	var dark_people: Array[Person] = []
	for i: int in range(3):
		var d: Person = td.people[i + 2]
		TopDownTestUtil.place(d, Vector3(0, 0, -6 - i * 0.5), 0, 1.0)
		dark_people.append(d)

	var pursuit: Dictionary = td.pursuit_assignments(td.people)
	assert_object(pursuit[dark_people[0]]).is_same(near)
	assert_object(pursuit[dark_people[1]]).is_same(near)
	# The third dark person finds the nearer rescued person full, so takes the farther one.
	assert_object(pursuit[dark_people[2]]).is_same(far)


func test_dark_person_drifts_no_faster_than_the_drift_speed() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var rescued: Person = td.people[0]
	# Round 8: 15 m apart (was 25), so the dark person is well inside the pursuit search radius.
	TopDownTestUtil.place(rescued, Vector3(-5, 0, -8), 0, 0.0)
	rescued.receive_joy(0, Config.JOY_MAX, 0.0)
	var dark: Person = td.people[1]
	TopDownTestUtil.place(dark, Vector3(10, 0, -8), 0, 1.0)
	var start := dark.global_position
	var gap_before := _gap(dark, rescued)

	# One second of game time (60 frames at the fixed 60 fps).
	await runner.simulate_frames(60)
	var moved := dark.global_position.distance_to(start)
	assert_float(moved).is_less_equal(Config.TD_DARK_DRIFT_SPEED * 1.0 + 0.05)
	assert_float(moved).is_greater(Config.TD_DARK_DRIFT_SPEED * 0.5)
	assert_float(_gap(dark, rescued)).is_less(gap_before)


func test_a_person_with_no_grace_period_gets_none() -> void:
	var p: Person = auto_free(Person.new())
	add_child(p)
	assert_float(p.grace_seconds).is_equal(0.0)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	assert_bool(p.is_rescued).is_true()
	assert_float(p.grace_left).is_equal(0.0)
	assert_bool(p.grace_ring.visible).is_false()


func test_top_down_people_get_the_grace_period_on_spawn() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	for p: Person in td.people:
		assert_float(p.grace_seconds).is_equal(Config.TD_RESCUE_GRACE_SECONDS)
