extends GdUnitTestSuite

# Top-down targeting, driven by real input: mouse moves and clicks, and the F2 key.
# Modes: LOCK_ON (click to lock, the default), HOVER_STICKY (the mouse picks when there is no target) and
# AUTO (the most urgent person in range). Also covers the target highlight and the auto-chosen element.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Moves the mouse over the floor under `spot` and clicks there.
func _click_at(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


func test_click_locks_person_shows_highlight_and_element_label() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	await runner.simulate_frames(2)
	assert_bool(td.highlight.visible).is_false()
	assert_str(td.hud.element_label.text).is_equal("No target")

	await _click_at(runner, td, target.global_position)

	assert_object(td.player.target).is_same(target)
	assert_bool(td.highlight.visible).is_true()
	(
		assert_float(
			Vector2(td.highlight.global_position.x, td.highlight.global_position.z).distance_to(
				Vector2(target.global_position.x, target.global_position.z)
			)
		)
		. is_less(0.05)
	)
	assert_str(td.hud.element_label.text).is_equal("Target: Music")

	# The highlight follows the target when it moves.
	target.global_position = Vector3(2, 0, -8)
	await runner.simulate_frames(2)
	assert_float(td.highlight.global_position.x).is_equal_approx(2.0, 0.05)


func test_firing_happens_only_while_locked() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)

	await runner.simulate_frames(40)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)
	assert_float(target.joy).is_equal(0.0)

	await _click_at(runner, td, target.global_position)
	await runner.simulate_frames(60)
	assert_float(target.joy).is_greater(0.0)


func test_clicking_empty_ground_clears_the_lock() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	await _click_at(runner, td, target.global_position)
	assert_object(td.player.target).is_same(target)

	await _click_at(runner, td, Vector3(-25, 0, 25))

	assert_object(td.player.target).is_null()
	assert_bool(td.highlight.visible).is_false()
	assert_str(td.hud.element_label.text).is_equal("No target")


func test_lock_clears_when_the_target_is_rescued() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	await _click_at(runner, td, target.global_position)

	var frames := 0
	while not target.is_rescued and frames < 600:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(target.is_rescued).is_true()
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_null()


func test_lock_breaks_when_the_player_moves_beyond_break_range() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	# A dark person needs the most joy, so the walk-away below cannot end with a rescue.
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.9)
	await _click_at(runner, td, target.global_position)
	assert_object(td.player.target).is_same(target)

	# Walk south (+Z), away from the target, until it is beyond the break range.
	runner.simulate_key_press(KEY_S)
	var frames := 0
	while td.player.target != null and frames < 300:
		await runner.simulate_frames(2)
		frames += 2
	runner.simulate_key_release(KEY_S)

	assert_object(td.player.target).is_null()
	(
		assert_float(
			(
				Vector2(
					td.player.global_position.x - target.global_position.x,
					td.player.global_position.z - target.global_position.z
				)
				. length()
			)
		)
		. is_greater(Config.TD_LOCK_BREAK_RANGE)
	)


func test_f2_cycles_targeting_modes_and_updates_the_hud() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_bool(td.hud.targeting_label.visible).is_true()
	assert_str(td.hud.targeting_label.text).contains("Targeting: Lock-on")

	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)
	assert_int(td.player.targeting_mode).is_equal(Config.TargetingMode.HOVER_STICKY)
	assert_str(td.hud.targeting_label.text).contains("Targeting: Hover")

	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)
	assert_int(td.player.targeting_mode).is_equal(Config.TargetingMode.AUTO)
	assert_str(td.hud.targeting_label.text).contains("Targeting: Auto")

	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)
	assert_int(td.player.targeting_mode).is_equal(Config.TargetingMode.LOCK_ON)
	assert_str(td.hud.targeting_label.text).contains("Targeting: Lock-on")


func test_hover_target_follows_mouse_only_when_there_is_no_target() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var first: Person = td.people[0]
	var second: Person = td.people[1]
	TopDownTestUtil.place(first, Vector3(0, 0, -8), 0, 0.0)
	TopDownTestUtil.place(second, Vector3(-5, 0, -4), 1, 0.0)
	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)

	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, first.global_position))
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(first)

	# Moving the mouse to the other person does not change a target that is still held.
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, second.global_position))
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(first)

	# Once the held target is rescued, the person under the mouse is picked.
	first.receive_joy(first.affinity, Config.JOY_MAX * 3.0, 0.0)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(second)


func test_auto_prefers_a_rescued_person_about_to_relapse_over_a_grey_one() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var rescued: Person = td.people[0]
	var dark: Person = td.people[1]
	TopDownTestUtil.place(rescued, Vector3(0, 0, -9), 0, 0.0)
	TopDownTestUtil.place(dark, Vector3(4, 0, 0), 0, 0.9)
	# Rescue one person, then drop their joy into the warning zone (below 85% of what a rescue needs).
	rescued.receive_joy(rescued.affinity, Config.JOY_MAX * 2.0, 0.0)
	rescued.joy = 800.0
	assert_bool(rescued.is_warning()).is_true()

	runner.simulate_key_pressed(KEY_F2)
	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)
	assert_int(td.player.targeting_mode).is_equal(Config.TargetingMode.AUTO)
	assert_object(td.player.target).is_same(rescued)


func test_auto_prefers_the_darkest_person_when_nobody_is_rescued() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var near_grey: Person = td.people[0]
	var far_dark: Person = td.people[1]
	TopDownTestUtil.place(near_grey, Vector3(0, 0, -6), 0, 0.5)
	TopDownTestUtil.place(far_dark, Vector3(-9, 0, 0), 0, 0.9)

	runner.simulate_key_pressed(KEY_F2)
	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(far_dark)


func test_shots_use_the_target_element_and_the_ring_matches() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 1, 0.0)  # Art
	await runner.simulate_frames(2)
	assert_bool(td.player._ring_mat.albedo_color.is_equal_approx(Config.TD_NO_TARGET_COLOR)).is_true()

	await _click_at(runner, td, target.global_position)
	await runner.simulate_frames(3)

	assert_bool(td.player._ring_mat.albedo_color.is_equal_approx(Config.ELEMENT_COLORS[1])).is_true()
	assert_str(td.hud.element_label.text).is_equal("Target: Art")
	var shots := TopDownTestUtil.projectiles(td)
	assert_int(shots.size()).is_greater(0)
	for shot: JoyProjectile in shots:
		assert_int(shot.element).is_equal(target.affinity)
