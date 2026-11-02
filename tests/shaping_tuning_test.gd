extends GdUnitTestSuite

# Round 23: shaping tuning and quieter feedback. Reach is about 30% further and the beacon walks about 50% faster than
# in round 22 (the values are checked against the round 22 numbers written here). A far-away aim is no longer refused
# with a red "too far" notice: the zone goes as far as the people allow and the preview stays calm. The notices and the
# growth text are smaller and quieter.

const PEOPLE := 24
const CENTRE := Vector3(-11.7, 0.0, -6.5)


func after_test() -> void:
	Config.intro_override = -1


# Round 22 values, for the comparison.
func _round_22_reach_base() -> float:
	return 3.0 * Config.WORLD_SCALE


func _round_22_reach_per_person() -> float:
	return 0.35 * Config.WORLD_SCALE


func _round_22_pull_speed() -> float:
	return 0.8 * Config.WORLD_SCALE


func _radius() -> float:
	return BorderCentre.circle_radius(PEOPLE)


# A level with a settled border of 24 people round CENTRE, full spirit and nobody else about (as shaped_zone_test).
func _setup() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	var r := _radius()
	for i: int in range(PEOPLE):
		var a := TAU * float(i) / float(PEOPLE)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(600)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td}


func test_reach_is_about_thirty_percent_further_than_round_22() -> void:
	for people: int in [0, 12, 24, 40]:
		var old_reach := _round_22_reach_base() + _round_22_reach_per_person() * float(people)
		assert_float(BorderCentre.reach_beyond(people)).is_equal_approx(old_reach * 1.3, 0.001)


func test_the_beacon_walks_about_fifty_percent_faster_than_round_22() -> void:
	assert_float(Config.BEACON_PULL_SPEED).is_equal_approx(_round_22_pull_speed() * 1.5, 0.001)


func test_notices_and_growth_text_are_smaller_and_quieter() -> void:
	assert_int(Config.NOTICE_FONT_SIZE).is_less_equal(20)
	assert_float(Config.NOTICE_HEIGHT).is_less(56.0)
	assert_float(Config.BEACON_LIMITED_LABEL_SIZE).is_less(0.05)
	assert_float(Config.BEACON_GUIDE_LABEL_SIZE).is_less_equal(0.03)
	assert_float(Config.BEACON_GAIN_LABEL_SIZE).is_less(0.05)
	assert_float(Config.BEACON_PULSE_COLOUR.a).is_less(0.95)


func test_a_far_aim_is_not_refused_and_the_stretch_goes_as_far_as_the_people_allow() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player._has_aim = true
	td.player._aim_point = CENTRE + Vector3(0, 0, 80)
	var plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	var reach: float = plan["reach"]
	var max_reach: float = td.border.stretch_info()["max"]
	assert_bool(plan["refused"]).is_false()
	assert_str(plan["reason"]).is_equal("")
	assert_float(reach).is_equal_approx(max_reach, 0.05)
	assert_float(reach).is_greater(_radius() + 5.0)
	# Pressing E is not refused and no red notice shows.
	assert_bool(td.try_place_beacon()).is_true()
	assert_int(td.intro.current).is_not_equal(Intro.Prompt.BEACON_BLOCKED)
	var guard := 0
	while td.border.stretch_info()["on"] and guard < 60:
		await runner.simulate_frames(60)
		guard += 1
	await runner.simulate_frames(120)
	assert_bool(td.border.stretch_info()["on"]).is_false()
	assert_int(td.intro.current).is_not_equal(Intro.Prompt.BEACON_FELL_BACK)
	assert_bool(td.border._centre_ctl.arms.is_empty()).is_false()
	assert_float(td.border._centre_ctl.arms[0].y).is_greater(_radius() + 5.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_tip_walks_at_the_new_pull_speed_on_a_long_stretch() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	# Far enough that the tip is still walking after a second.
	td.border.place_beacon(CENTRE + Vector3(0, 0, 80))
	var tip0: Vector3 = td.border.stretch_info()["tip"]
	await runner.simulate_frames(60)
	var tip1: Vector3 = td.border.stretch_info()["tip"]
	assert_bool(td.border.stretch_info()["on"]).is_true()
	assert_float(GloomSim.flat_dist(tip1, tip0)).is_equal_approx(Config.BEACON_PULL_SPEED, 0.05)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_preview_of_a_far_aim_is_the_calm_preview_and_the_growth_text_is_small() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(2)
	td.player._has_aim = true
	td.player._aim_point = CENTRE + Vector3(0, 0, 80)
	td.reach_guide.sync(td.border, td.player)
	var label: Label3D = td.reach_guide._label
	assert_bool(label.visible).is_true()
	assert_str(label.text).is_equal("E: stretch here")
	assert_float(label.pixel_size).is_equal_approx(Config.BEACON_GUIDE_LABEL_SIZE, 0.0001)
	# After the arm grows the "+N sq m of ground" text uses the quieter size.
	assert_bool(td.try_place_beacon()).is_true()
	var guard := 0
	while td.reach_guide._pulse_left <= 0.0 and guard < 60:
		await runner.simulate_frames(30)
		guard += 1
	await runner.simulate_frames(5)
	assert_object(td.reach_guide._gain_label).is_not_null()
	assert_float(td.reach_guide._gain_label.pixel_size).is_equal_approx(Config.BEACON_GAIN_LABEL_SIZE, 0.0001)
	await TopDownTestUtil.leave_loaded_scene(td)
