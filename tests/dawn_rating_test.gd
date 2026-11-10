extends GdUnitTestSuite

# Round 19: the level is won at dawn and rated in dawn lights from people rescued, ground held and landmarks held.


func test_reaching_dawn_with_little_is_one_light() -> void:
	assert_int(DawnRating.rate(5, 60, 0.02, 0)["lights"]).is_equal(1)
	# One goal alone is not enough for two lights.
	assert_int(DawnRating.rate(30, 60, 0.0, 0)["lights"]).is_equal(1)
	assert_int(DawnRating.rate(3, 60, 0.0, 1)["lights"]).is_equal(1)
	assert_int(DawnRating.rate(3, 60, 0.5, 0)["lights"]).is_equal(1)


func test_two_of_the_three_lower_goals_give_two_lights() -> void:
	assert_int(DawnRating.rate(30, 60, 0.0, 1)["lights"]).is_equal(2)
	assert_int(DawnRating.rate(30, 60, 0.3, 0)["lights"]).is_equal(2)
	assert_int(DawnRating.rate(5, 60, 0.3, 1)["lights"]).is_equal(2)


func test_a_round_18_style_quick_push_with_one_landmark_gets_two_lights_not_three() -> void:
	# 31 of 60 rescued, the plaza mostly held and one landmark: the round 18 playtest, now rated.
	var r := DawnRating.rate(31, 60, 0.35, 1)
	assert_int(r["lights"]).is_between(1, 2)
	assert_int(r["lights"]).is_equal(2)
	# Checkpoint 5: round 23 made one landmark enough for three lights; it now takes two, however many are rescued.
	assert_int(DawnRating.rate(58, 60, 0.9, 1)["lights"]).is_equal(2)


func test_three_lights_need_75_percent_of_the_people_and_two_landmarks() -> void:
	assert_float(LandmarkConfig.DAWN_PEOPLE_HIGH).is_equal(0.75)
	assert_int(LandmarkConfig.DAWN_LANDMARKS_HIGH).is_equal(2)
	assert_int(DawnRating.rate(45, 60, 0.3, 2)["lights"]).is_equal(3)  # exactly 75%
	assert_int(DawnRating.rate(60, 60, 0.6, 3)["lights"]).is_equal(3)
	# Just under 75%, one landmark only, or no landmark: two lights.
	assert_int(DawnRating.rate(44, 60, 0.3, 2)["lights"]).is_equal(2)
	assert_int(DawnRating.rate(45, 60, 0.3, 1)["lights"]).is_equal(2)
	assert_int(DawnRating.rate(45, 60, 0.3, 0)["lights"]).is_equal(2)
	assert_int(DawnRating.rate(30, 60, 0.3, 2)["lights"]).is_equal(2)


func test_the_reasons_are_spelt_out() -> void:
	var r := DawnRating.rate(30, 60, 0.31, 2)
	var lines: Array = r["lines"]
	assert_str(lines[0]).is_equal("30 of 60 people rescued (50%)")
	assert_str(lines[1]).is_equal("31% of the plaza held")
	assert_str(lines[2]).is_equal("2 of 4 landmarks held")
	assert_str(DawnRating.lights_text(2)).is_equal("[*][*][ ]")
	assert_str(DawnRating.hint_for(3)).is_equal("")
	assert_str(DawnRating.hint_for(2)).contains("three")
	assert_str(DawnRating.hint_for(2)).contains("75%")
	assert_str(DawnRating.hint_for(2)).contains("2 landmarks")
	assert_str(DawnRating.hint_for(1)).contains("two")


# --- In the level ---------------------------------------------------------------------------------------------------


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


func test_dawn_ends_the_level_with_one_light_for_an_empty_night() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.night.elapsed = NightConfig.NIGHT_LENGTH - 0.05
	await runner.simulate_frames(10)
	assert_bool(td.running).is_false()
	assert_str(td.hud.end_label.text).contains("Dawn: 1 of 3 dawn lights")
	assert_str(td.hud.end_label.text).contains("Dawn lights: [*][ ][ ]")
	assert_str(td.hud.end_label.text).contains("0 of 60 people rescued")
	assert_str(td.hud.end_label.text).contains("0 of 4 landmarks held")
	assert_int(td.rating["lights"]).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dawn_rates_what_is_held_thirty_people_and_a_landmark_make_two_lights() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	for i: int in range(30):
		var a := TAU * float(i) / 30.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	# The zone takes the block north of the start, then the Bandstand square beside it (0.4: a landmark is held with
	# its cell).
	td.border.zone.take(Vector2i(2, 1))
	td.border.zone.take(TownConfig.TOWN_LANDMARK_CELLS[Landmarks.BANDSTAND])
	var frames := 0
	while not td.landmarks.is_held(Landmarks.BANDSTAND) and frames < 2400:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(td.landmarks.is_held(Landmarks.BANDSTAND)).is_true()
	# Holding the landmark did not end the level.
	assert_bool(td.running).is_true()
	td.night.elapsed = NightConfig.NIGHT_LENGTH - 0.05
	await runner.simulate_frames(10)
	assert_bool(td.running).is_false()
	assert_str(td.hud.end_label.text).contains("Dawn: 2 of 3 dawn lights")
	assert_str(td.hud.end_label.text).contains("1 of 4 landmarks held")
	assert_str(td.hud.end_label.text).contains("30 of 60 people rescued")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_fallen_border_is_a_loss_with_no_lights() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.border.formed = true
	await runner.simulate_frames(5)
	assert_bool(td.running).is_false()
	assert_str(td.hud.end_label.text).contains("The border fell")
	assert_str(td.hud.end_label.text).not_contains("Dawn lights")
	assert_bool(td.rating.is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
