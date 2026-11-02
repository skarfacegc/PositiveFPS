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
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
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
	assert_str(td.gap_patch.cue_text()).is_equal("")
	assert_bool(td.gap_patch.patch_label.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_cue_says_patch_when_a_gap_is_under_the_cursor_and_hides_without_spirit() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	m.joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION - 0.05)
	await runner.simulate_frames(20)
	assert_int(td.border.gap_count()).is_greater(0)
	td.player.add_spirit(100.0)
	await _aim_at(s, m.position)
	assert_str(td.gap_patch.cue_text()).is_equal(Config.CUE_PATCH_TEXT)
	assert_bool(td.gap_patch.patch_label.visible).is_true()
	assert_int(td.gap_patch.patch_label.get_theme_font_size("font_size")).is_less_equal(18)
	# Aimed far away but the gap is near the player: the cue says to aim.
	td.player.global_position = m.position * 0.8
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, -m.position * 2.0))
	await runner.simulate_frames(3)
	assert_str(td.gap_patch.cue_text()).is_equal(Config.CUE_PATCH_AIM_TEXT)
	# No spirit to spend: no cue.
	td.player.lose_spirit(td.player.spirit)
	await runner.simulate_frames(3)
	assert_str(td.gap_patch.cue_text()).is_equal("")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_patch_pulses_and_counts_what_it_holds_then_fades() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	var m: Person = td.border.members[5]
	td.gap_patch.patch_at(m.position)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.fx.pulse_count()).is_equal(1)
	assert_int(td.gap_patch.fx.result_text_count()).is_equal(1)
	assert_int(td.gap_patch._held_near(m.position)).is_greater(0)
	await runner.simulate_frames(int(Config.FX_TEXT_SECONDS * 60.0) + 20)
	assert_int(td.gap_patch.fx.pulse_count()).is_equal(0)
	assert_int(td.gap_patch.fx.result_text_count()).is_equal(0)
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
	assert_bool(td.gap_patch.cue_text().contains("G:")).is_false()
	var near: Person = td.people[20]
	TopDownTestUtil.place(near, m.position + out * 1.2, 1, 0.95)
	await runner.simulate_frames(10)
	assert_str(td.gap_patch.cue_text()).contains(Config.CUE_BURST_TEXT % 1)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.fx.halo_count()).is_equal(1)
	assert_int(td.gap_patch.fx.result_text_count()).is_equal(1)
	await runner.simulate_frames(int(Config.FX_HALO_SECONDS * 60.0) + 20)
	assert_int(td.gap_patch.fx.halo_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_landmark_boosts_are_stronger_and_one_landmark_gives_the_third_light() -> void:
	assert_float(Config.LANDMARK_MUSIC_MULT).is_equal(2.0)
	assert_float(Config.LANDMARK_NATURE_MULT).is_equal(2.0)
	assert_float(Config.LANDMARK_BELL_LOSS_MULT).is_equal(0.4)
	assert_int(Config.DAWN_LANDMARKS_HIGH).is_equal(1)
	assert_int(DawnRating.rate(40, 60, 0.3, 1)["lights"]).is_equal(3)
	assert_int(DawnRating.rate(40, 60, 0.3, 0)["lights"]).is_less(3)
