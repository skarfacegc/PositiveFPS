extends GdUnitTestSuite

# Checkpoint 5 follow-up: E is hold to aim, release to place, and right-click cancels. The zone preview shows only while
# E is held (both looks) and follows the cursor; releasing E places the beacon exactly as a press did before; a
# right-click while held spends nothing. The stretch's travel shows whether or not E is held. These tests press real
# keys and buttons through the scene runner, so the level's own input handling is what runs.


# A level with a formed border of six people round (-6, 4), settled, and the player with full spirit.
func _formed() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	for i: int in range(6):
		var a := TAU * float(i) / 6.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(-6, 0, 4) + Vector3(cos(a) * 4.0, 0.0, sin(a) * 4.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(60)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td}


# Moves the cursor over the ground point `spot` and lets a few frames run (the aim follows the cursor).
func _aim(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(4)


# Whether the zone preview is drawn this frame, in whichever look is on (the stretch's travel does not count).
func _preview_shown(td: TopDownMain) -> bool:
	if Looks.is_styled():
		return td.reach_guide._styled.showing_preview
	return td.reach_guide._mesh.get_surface_count() == 1 and not td.border.stretch_info()["on"]


# Whether the stretch's travel is drawn this frame, in whichever look is on.
func _travel_shown(td: TopDownMain) -> bool:
	if Looks.is_styled():
		return td.reach_guide._styled.showing_travel
	# Checkpoint 7: the placeholder travel is only the word "Stretching" (no line, disc or dashes, so no mesh surface).
	var label: Label3D = td.reach_guide._label
	return (
		label != null and label.visible and label.text == "Stretching" and td.reach_guide._mesh.get_surface_count() == 0
	)


func test_no_preview_shows_unless_e_is_held() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _aim(runner, td, Vector3(8, 0, 6))
	await runner.simulate_frames(3)
	assert_bool(td.reach_guide.held).is_false()
	assert_bool(_preview_shown(td)).is_false()
	assert_bool(td.border.has_beacon()).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_holding_e_shows_the_preview_and_it_follows_the_cursor() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	runner.simulate_key_press(KEY_E)
	await _aim(runner, td, Vector3(8, 0, 6))
	assert_bool(td.reach_guide.held).is_true()
	assert_bool(_preview_shown(td)).is_true()
	var east: float = td.border.plan_stretch(td.player.aim_point())["dir"]
	await _aim(runner, td, Vector3(-6, 0, -14))
	await runner.simulate_frames(2)
	var north: float = td.border.plan_stretch(td.player.aim_point())["dir"]
	assert_float(absf(wrapf(north - east, -PI, PI))).is_greater(1.0)
	assert_bool(_preview_shown(td)).is_true()
	# Nothing is placed while E is still held.
	assert_bool(td.border.has_beacon()).is_false()
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_releasing_e_places_the_beacon_and_costs_what_a_press_did() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var placed: Array[int] = [0]
	td.beacon_placed.connect(func(_p: Vector3, _c: float, _s: float) -> void: placed[0] += 1)
	var before := td.player.spirit
	runner.simulate_key_press(KEY_E)
	await _aim(runner, td, Vector3(8, 0, 6))
	assert_int(placed[0]).is_equal(0)
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(2)
	assert_int(placed[0]).is_equal(1)
	assert_bool(td.border.has_beacon()).is_true()
	assert_float(td.border.beacon_pos().x).is_equal_approx(8.0, 0.6)
	assert_float(td.border.beacon_pos().z).is_equal_approx(6.0, 0.6)
	assert_float(before - td.player.spirit).is_equal_approx(Config.BEACON_SPIRIT_COST, 0.5)
	assert_bool(td.reach_guide.held).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_second_release_places_nothing() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	runner.simulate_key_press(KEY_E)
	await _aim(runner, td, Vector3(8, 0, 6))
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(2)
	var after := td.player.spirit
	# A release that arrives with no press before it (a second delivery of the key) changes nothing.
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(2)
	assert_float(td.player.spirit).is_equal(after)
	assert_float(before - after).is_equal_approx(Config.BEACON_SPIRIT_COST, 0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_refused_release_shows_the_same_notice_and_spends_nothing() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player.lose_spirit(td.player.spirit - (Config.BEACON_SPIRIT_COST - 5.0))
	var before := td.player.spirit
	runner.simulate_key_press(KEY_E)
	await _aim(runner, td, Vector3(8, 0, 6))
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(2)
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal_approx(before, 0.3)
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_SPIRIT)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_right_click_while_held_cancels_with_nothing_spent_and_the_preview_hides() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	runner.simulate_key_press(KEY_E)
	await _aim(runner, td, Vector3(8, 0, 6))
	assert_bool(_preview_shown(td)).is_true()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(2)
	assert_bool(td.reach_guide.held).is_false()
	assert_bool(_preview_shown(td)).is_false()
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal(before)
	# E is still physically down: moving the cursor shows nothing, and releasing it places nothing.
	await _aim(runner, td, Vector3(-6, 0, -14))
	assert_bool(_preview_shown(td)).is_false()
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(2)
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal(before)
	# Pressing E again starts a new aim.
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(2)
	assert_bool(_preview_shown(td)).is_true()
	runner.simulate_key_release(KEY_E)
	await TopDownTestUtil.leave_loaded_scene(td)


# Snag round: the window losing focus while E is held cancels the aim like a right-click: the preview hides and nothing
# is spent, and the release that follows (E let go in another window) places nothing.
func test_losing_focus_while_e_is_held_cancels_the_aim_with_nothing_spent() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	TopDownTestUtil.press_e(td)
	await _aim(runner, td, Vector3(8, 0, 6))
	assert_bool(_preview_shown(td)).is_true()
	td.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await runner.simulate_frames(2)
	assert_bool(td.reach_guide.held).is_false()
	assert_bool(_preview_shown(td)).is_false()
	assert_float(td.player.spirit).is_equal(before)
	TopDownTestUtil.release_e(td)
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal(before)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_helpers_drive_the_same_press_release_and_cancel_path() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _aim(runner, td, Vector3(8, 0, 6))
	TopDownTestUtil.press_e(td)
	assert_bool(td.reach_guide.held).is_true()
	TopDownTestUtil.cancel_aim(td)
	assert_bool(td.reach_guide.held).is_false()
	TopDownTestUtil.press_e(td)
	TopDownTestUtil.release_e(td)
	assert_bool(td.reach_guide.held).is_false()
	assert_bool(td.border.has_beacon()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_stretch_travel_shows_with_e_up_in_both_looks() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.border.place_beacon(td.border.centre + Vector3(60, 0, 0))
	await runner.simulate_frames(10)
	assert_bool(td.reach_guide.held).is_false()
	assert_bool(_travel_shown(td)).is_true()
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	assert_bool(_travel_shown(td)).is_true()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_preview_obeys_the_same_hold_rule() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var guide: StyleReach = td.reach_guide._styled
	await _aim(runner, td, Vector3(8, 0, 6))
	assert_bool(guide.showing_preview).is_false()
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	assert_bool(guide.showing_preview).is_true()
	assert_bool(guide.showing_limited).is_false()
	assert_bool(guide._cross.visible).is_false()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(3)
	assert_bool(guide.showing_preview).is_false()
	runner.simulate_key_release(KEY_E)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_limited_preview_is_a_thin_outline_with_a_cross_and_no_fill() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	# Aim at ground the zone already covers: the plan is refused, so the preview is limited.
	var centre := td.border.centre
	var edge: float = td.border.stretch_info()["radius"]
	runner.simulate_key_press(KEY_E)
	await _aim(runner, td, centre + Vector3(edge * 0.5, 0.0, 0.0))
	await runner.simulate_frames(2)
	assert_bool(td.border.plan_stretch(td.player.aim_point())["reason"] != "").is_true()
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var guide: StyleReach = td.reach_guide._styled
	assert_bool(guide.showing_limited).is_true()
	assert_bool(guide._cross.visible).is_true()
	assert_bool(guide._tip_disc.visible).is_false()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(3)
	assert_bool(td.reach_guide._mesh.get_surface_count() == 1).is_true()
	runner.simulate_key_release(KEY_E)
	await TopDownTestUtil.leave_loaded_scene(td)
