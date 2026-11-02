extends GdUnitTestSuite

# Round 23 follow-up: real reach, the second arm, and the pull-in when a zone loses its people.

const CENTRE := Vector3(-11.7, 0.0, -6.5)


func after_test() -> void:
	Config.intro_override = -1


func _setup(people: int) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	var r := BorderCentre.circle_radius(people)
	for i: int in range(people):
		var a := TAU * float(i) / float(people)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(600)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td}


func _stretch(td: TopDownMain, runner: GdUnitSceneRunner, spot: Vector3) -> void:
	td.border.place_beacon(spot)
	var guard := 0
	while td.border.stretch_info()["on"] and guard < 60:
		await runner.simulate_frames(60)
		guard += 1
	await runner.simulate_frames(240)


func _lose_one(td: TopDownMain, i: int) -> void:
	var p: Person = td.people[i]
	p.grace_left = 0.0
	p.drain_joy(1.0e6)


func _lose(td: TopDownMain, count: int) -> void:
	for i: int in range(count):
		var p: Person = td.people[i]
		p.grace_left = 0.0
		p.drain_joy(1.0e6)


func test_real_reach_gains_at_12_24_and_40_people() -> void:
	# Before (BEACON_BODY_MIN 0.6): 14.4, 28.7 and 47.9 m. At 40 people the people formula, not the loop, is the limit.
	var before := {12: 14.4, 24: 28.7, 40: 47.9}
	for n: int in [12, 24, 40]:
		var r := BorderCentre.circle_radius(n)
		var cap := minf(r + BorderCentre.reach_beyond(n), BorderCentre.feasible_distance(r))
		print("PROBE reach at %d people: %.1f m (was %.1f)" % [n, cap, before[n]])
		var was: float = before[n]
		assert_float(cap).is_greater(was * 1.14)
	# The body stays a usable shape: at least 0.4 of the plain radius (5.7 m across the radius at 24 people).
	assert_float(Config.BEACON_BODY_MIN).is_greater_equal(0.4)
	assert_float(BorderCentre.circle_radius(24) * Config.BEACON_BODY_MIN).is_greater(5.5)


func test_the_planned_reach_matches_the_gain_in_a_real_level() -> void:
	var s: Dictionary = await _setup(24)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var east: Dictionary = td.border.plan_stretch(CENTRE + Vector3(200, 0, 0))
	var east_reach: float = east["reach"]
	assert_float(east_reach).is_greater(33.0)
	assert_str(east["reason"]).is_empty()
	await _stretch(td, runner, CENTRE + Vector3(200, 0, 0))
	# The second arm: the first takes the spare length, so west is short and says why (kept on purpose: sharing the
	# length would give back the reach gained above). Round 23 numbers: east 34.2 m fresh, west 7.3 m after it.
	var west: Dictionary = td.border.plan_stretch(CENTRE + Vector3(-200, 0, 0))
	var west_reach: float = west["reach"]
	assert_float(west_reach).is_less(east_reach)
	assert_str(west["reason"]).is_equal(Config.BEACON_FULL_TEXT)
	await TopDownTestUtil.leave_loaded_scene(td)


# The size factor never goes under BorderShape.SCALE_FLOOR, so with few people left min_scale is below it and the old
# pull-in test (scale <= min_scale x 1.03) could never be true: the arms stayed and the loop stayed 2 x too long.
func test_a_zone_that_loses_its_people_one_by_one_draws_in() -> void:
	var s: Dictionary = await _setup(44)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var pulled: Array[int] = [0]
	td.border.zone_pulling_in.connect(func() -> void: pulled[0] += 1)
	await _stretch(td, runner, CENTRE + Vector3(0, 0, 60))
	assert_bool(td.border._centre_ctl.has_arms()).is_true()
	var reach0 := 0.0
	for pt: Vector2 in td.border.polygon:
		reach0 = maxf(reach0, pt.distance_to(Vector2(CENTRE.x, CENTRE.z)))
	for i: int in range(24):
		_lose_one(td, i)
		await runner.simulate_frames(60)
		if i == 17:
			assert_int(pulled[0]).is_greater_equal(1)
	await runner.simulate_frames(60 * 5)
	var n: int = td.rescued_count
	var budget := BorderCentre.budget_of(BorderCentre.circle_radius(n))
	var perimeter := BorderShape.perimeter_of(td.border.polygon)
	var spacing := perimeter / maxf(float(td.border.member_count), 1.0)
	var line := "PROBE after losing 24 of 44: n=%d loop %.1f of %.1f m, spacing %.2f m, notices %d"
	print(line % [n, perimeter, budget, spacing, pulled[0]])
	assert_float(perimeter).is_less_equal(budget * (1.0 + Config.BEACON_PULL_IN_TOLERANCE + 0.02))
	assert_float(spacing).is_less_equal(Config.BORDER_MAX_GAP)
	# One notice per quiet spell, not one per person lost.
	assert_int(pulled[0]).is_less_equal(4)
	await TopDownTestUtil.leave_loaded_scene(td)


# The landmark pointers are worked out about 5 times a second, not every frame (0.18 ms each); a call without a delta
# always works them out (the landmark_pointers_test suite relies on that).
func test_the_landmark_pointers_refresh_a_few_times_a_second() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	var lp: LandmarkPointers = td.landmark_pointers
	lp.update_from(td)
	assert_float(lp._since).is_equal(0.0)
	lp.update_from(td, 0.05)
	lp.update_from(td, 0.05)
	assert_float(lp._since).is_equal_approx(0.1, 0.001)  # skipped twice
	lp.update_from(td, 0.05)
	lp.update_from(td, 0.05)
	assert_float(lp._since).is_equal(0.0)  # worked out on reaching LANDMARK_POINTER_REFRESH
	# A pointer that has changed since is not shown until the next refresh.
	td.landmarks.items[Landmarks.BANDSTAND].update(Config.BORDER_LANDMARK_HOLD, true)
	lp.update_from(td, 0.01)
	assert_float(lp._since).is_equal_approx(0.01, 0.001)
	lp.update_from(td)
	assert_bool(lp.pointer_for("Bandstand").is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
