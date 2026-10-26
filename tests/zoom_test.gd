extends GdUnitTestSuite

# Round 14: the mouse wheel zooms the top-down camera between TD_ZOOM_MIN and TD_ZOOM_MAX, one TD_ZOOM_STEP per notch,
# eased. The default is TD_CAMERA_ORTHO_SIZE (19.5). Labels scale with the zoom so they keep their size on screen, and
# the look offset scales too, so the player keeps the same place on screen. The inputs are real wheel events.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# One wheel notch (a press and a release), then a frame, so each notch is its own frame.
func _notch(runner: GdUnitSceneRunner, button: MouseButton) -> void:
	runner.simulate_mouse_button_pressed(button)
	await runner.simulate_frames(1)


func _settle(runner: GdUnitSceneRunner) -> void:
	await runner.simulate_frames(180)


func test_the_default_zoom_is_nineteen_and_a_half_metres() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	assert_float(Config.TD_CAMERA_ORTHO_SIZE).is_equal_approx(19.5, 0.0001)
	assert_float(td.camera.size).is_equal_approx(19.5, 0.0001)
	assert_float(Config.TD_ZOOM_MIN).is_equal(14.0)
	assert_float(Config.TD_ZOOM_MAX).is_equal(26.0)
	assert_float(Config.TD_ZOOM_STEP).is_equal(1.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_wheel_up_zooms_in_one_step_and_eases_there() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _notch(runner, MOUSE_BUTTON_WHEEL_UP)
	# Eased: a frame after the notch the camera is between the start and the target (18.0), not there yet.
	assert_float(td.camera.size).is_less(19.5)
	assert_float(td.camera.size).is_greater(18.0)
	await _settle(runner)
	assert_float(td.camera.size).is_equal_approx(18.0, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_wheel_down_zooms_out_and_the_zoom_clamps_at_both_ends() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	for i: int in range(12):
		await _notch(runner, MOUSE_BUTTON_WHEEL_DOWN)
	await _settle(runner)
	assert_float(td.camera.size).is_equal_approx(Config.TD_ZOOM_MAX, 0.01)
	# A further notch does not go past the wide end.
	await _notch(runner, MOUSE_BUTTON_WHEEL_DOWN)
	await _settle(runner)
	assert_float(td.camera.size).is_equal_approx(Config.TD_ZOOM_MAX, 0.01)

	for i: int in range(20):
		await _notch(runner, MOUSE_BUTTON_WHEEL_UP)
	await _settle(runner)
	assert_float(td.camera.size).is_equal_approx(Config.TD_ZOOM_MIN, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_player_keeps_the_same_place_on_screen_and_the_labels_keep_their_size() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p := td.people[0]
	TopDownTestUtil.place(p, Vector3(4, 0, 4), 0, 0.1)
	await runner.simulate_frames(3)
	var at_default := td.world_to_screen(td.player.global_position)
	# On-screen label size: ui_scale over the view height (a larger view height makes the same label smaller).
	var label_default := p.ui_scale / td.camera.size
	for i: int in range(6):
		await _notch(runner, MOUSE_BUTTON_WHEEL_UP)
	await _settle(runner)
	var at_close := td.world_to_screen(td.player.global_position)
	assert_vector(at_close).is_equal_approx(at_default, Vector2(0.5, 0.5))
	assert_float(p.ui_scale / td.camera.size).is_equal_approx(label_default, 0.0005)
	assert_float(p.ui_scale).is_less(Config.TD_UI_SCALE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wheel_does_not_change_the_targeting_or_the_joy() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p := td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 0, 0.1)
	await runner.simulate_frames(2)
	await _notch(runner, MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(10)
	assert_object(td.player.target).is_null()
	assert_float(p.joy).is_equal(0.0)
	assert_int(td.player.targeting_mode).is_equal(Config.TD_TARGETING_MODE)
	await TopDownTestUtil.leave_loaded_scene(td)
