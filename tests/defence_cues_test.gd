extends GdUnitTestSuite

# Round 23: when and did it work. The patch and burst cue shows only when F or G/Q can be acted on; a patch and a burst
# leave a visible mark and a small count; the landmark boosts are stronger and one landmark gives the third light.


func _border_level(count: int, r: float) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	return {"runner": runner, "td": td}


func _aim_at(s: Dictionary, spot: Vector3) -> void:
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.global_position = Vector3.ZERO
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(3)


func test_the_cue_is_hidden_on_a_calm_border() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	await (s["runner"] as GdUnitSceneRunner).simulate_frames(10)
	assert_str(td.burst_cue.cue_text()).is_equal("")
	assert_bool(td.burst_cue.cue_label.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_burst_cue_and_the_lift_mark() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var m: Person = border.members[3]
	var out := Vector3(m.position.x - border.centre.x, 0.0, m.position.z - border.centre.z).normalized()
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	td.player.add_spirit(100.0)
	td.player.burst_cooldown = 0.0
	td.player.global_position = m.position - out * 2.0
	await runner.simulate_frames(10)
	assert_bool(td.burst_cue.cue_text().contains("G:")).is_false()
	var near: Person = td.people[20]
	TopDownTestUtil.place(near, m.position + out * 1.2, 1, 0.95)
	await runner.simulate_frames(10)
	assert_str(td.burst_cue.cue_text()).contains(HudConfig.CUE_BURST_TEXT % 1)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	assert_int(td.burst_cue.fx.halo_count()).is_equal(1)
	assert_int(td.burst_cue.fx.result_text_count()).is_equal(1)
	await runner.simulate_frames(int(SpiritConfig.FX_HALO_SECONDS * 60.0) + 20)
	assert_int(td.burst_cue.fx.halo_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_landmark_boosts_are_stronger_and_two_landmarks_give_the_third_light() -> void:
	assert_float(LandmarkConfig.LANDMARK_MUSIC_MULT).is_equal(2.0)
	assert_float(LandmarkConfig.LANDMARK_NATURE_MULT).is_equal(2.0)
	assert_float(LandmarkConfig.LANDMARK_BELL_LOSS_MULT).is_equal(0.4)
	# Checkpoint 5: the third light needs 2 landmarks and 75% rescued (was 1 and 60%).
	assert_int(LandmarkConfig.DAWN_LANDMARKS_HIGH).is_equal(2)
	assert_int(DawnRating.rate(45, 60, 0.3, 2)["lights"]).is_equal(3)
	assert_int(DawnRating.rate(45, 60, 0.3, 1)["lights"]).is_less(3)
