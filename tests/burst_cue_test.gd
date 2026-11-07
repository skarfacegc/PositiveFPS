extends GdUnitTestSuite

# Round 22 (as gap_patch_test), round 26: the burst (G/Q) as rules and through real input, its cue and count, and the
# F patch being gone. The push model itself is in border_push_test.gd.


# A ring of `count` rescued people at radius `r` around the origin, settled at midnight.
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


func test_the_f_patch_is_gone_from_the_keys_the_hint_and_the_menu() -> void:
	assert_bool(InputMap.has_action("patch_gap")).is_false()
	assert_str(TopDownMain.HINT_PLAY).not_contains("patch")
	var menu_text: String = (load("res://scripts/menu.gd") as GDScript).get_script_constant_map()["HOW_TO_PLAY_TEXT"]
	assert_str(menu_text).not_contains("patch")
	assert_str(menu_text).contains("spring back")


func test_the_burst_pushes_back_and_lifts_dimmed_people_at_the_border() -> void:
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
	var near: Person = td.people[20]
	var far: Person = td.people[21]
	TopDownTestUtil.place(near, m.position + out * 1.2, 1, 0.95)
	# Out of the lift radius (dimmed people anywhere inside it are lifted), so not a target.
	td.player.global_position = m.position - out * 2.0
	TopDownTestUtil.place(far, td.player.global_position + out * (Config.BURST_LIFT_RADIUS + 2.0), 2, 0.95)
	await runner.simulate_frames(2)
	near.gloom = 0.95
	far.gloom = 0.95
	assert_bool(BurstClear.is_target(near, td.player.global_position, border)).is_true()
	assert_bool(BurstClear.is_target(far, td.player.global_position, border)).is_false()
	td.player.add_spirit(100.0)
	var spirit := td.player.spirit
	var start := near.global_position
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	assert_float(td.player.spirit).is_equal_approx(spirit - Config.BURST_SPIRIT_COST, 1.0)
	# Pushed away from the line and lifted a stage; the streak shows.
	assert_float(near.global_position.distance_to(start)).is_greater(Config.BURST_PUSH_DISTANCE - 0.5)
	assert_float(near.global_position.length()).is_greater(start.length() + 2.0)
	assert_int(Config.gloom_level(near.gloom)).is_equal(1)
	assert_bool(GloomSim.is_dimmed(near)).is_false()
	assert_int(td.burst_cue.fx.streak_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_hud_says_how_many_dimmed_people_the_burst_would_clear() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	var out := Vector3(m.position.x - td.border.centre.x, 0.0, m.position.z - td.border.centre.z).normalized()
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	td.player.add_spirit(100.0)
	td.player.burst_cooldown = 0.0
	td.player.global_position = m.position - out * 2.0
	await runner.simulate_frames(20)
	assert_str(td.hud.burst_label.text).is_equal("Joy burst [G]: READY")
	TopDownTestUtil.place(td.people[20], m.position + out * 1.2, 1, 0.95)
	await runner.simulate_frames(20)
	assert_int(td.burst_cue.burst_targets).is_equal(1)
	assert_str(td.burst_cue.cue_text()).is_equal(Config.CUE_BURST_TEXT % 1)
	assert_str(td.hud.burst_label.text).contains("1")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_burst_near_a_bent_line_lets_it_spring_back() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	var i: int = td.border.push.sample_of(m.position)
	td.border.push.dent[i] = 1.5
	td.player.add_spirit(100.0)
	td.player.burst_cooldown = 0.0
	td.player.global_position = m.position
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(30)
	# Half a second on: it has sprung back by more than the plain spring would have taken (0.9 m/s).
	assert_float(td.border.push.dent[i]).is_less(1.5 - Config.PUSH_SPRING_SPEED * 0.5 - 0.1)
	await TopDownTestUtil.leave_loaded_scene(td)
