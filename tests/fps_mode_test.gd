extends GdUnitTestSuite

# First-person mode (main.tscn). Player-driven behaviour goes through the scene runner's simulated
# keys, mouse buttons and mouse motion, so it exercises the same InputEvents a real player sends.

const MAIN_SCENE := "res://main.tscn"
const MENU_SCENE := "res://menu.tscn"
const PITCH_LIMIT := 1.4835298642  # 85 degrees in radians


# Settles the player onto the floor and returns the scene.
func _start_fps() -> Dictionary:
	var runner := scene_runner(MAIN_SCENE)
	await runner.simulate_frames(60, 16)
	return {"runner": runner, "main": runner.scene()}


# Moves all people out of the way except `keep`, puts `keep` 6 m straight ahead of the player and
# looks down at its chest with real mouse motion. Returns the kept person.
func _stage_target(runner, main, affinity: int) -> Node:
	var keep = main.people[0]
	for p in main.people:
		if p != keep:
			p.global_position = Vector3(15, 0, 15)
	keep.affinity = affinity
	keep.gloom = 0.0
	keep.global_position = Vector3(0, 0, -6)
	# Camera sits 2.6 m up; aim down at the person's chest (1.0 m) 6 m ahead. About -0.26 rad.
	await runner.simulate_mouse_move(Vector2(0, 0))
	await runner.simulate_mouse_move_relative(Vector2(0, 104), 0.05)
	await runner.simulate_frames(5, 16)
	return keep


# Holds the fire button until the target is rescued. Returns the number of frames it took, or -1.
func _hold_fire_until_rescued(runner, target, cap: int) -> int:
	runner.simulate_mouse_button_press(MOUSE_BUTTON_LEFT)
	var frames := 0
	while not target.is_rescued and frames < cap:
		await runner.simulate_frames(1, 16)
		frames += 1
	runner.simulate_mouse_button_release(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2, 16)
	return frames if target.is_rescued else -1


func test_w_moves_player_forward() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var player = s["main"].player
	var start: Vector3 = player.global_position
	var forward: Vector3 = -player.global_transform.basis.z

	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(30, 16)
	runner.simulate_key_release(KEY_W)

	var moved: Vector3 = player.global_position - start
	assert_float(moved.dot(forward)).is_greater(1.0)
	assert_float(Vector2(moved.x, moved.z).length()).is_greater(1.0)


func test_shift_w_runs_further_than_w() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var player = s["main"].player

	var start: Vector3 = player.global_position
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(30, 16)
	runner.simulate_key_release(KEY_W)
	var walked := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()

	# Put the player back at the start, then run with Shift held.
	player.global_position = start
	await runner.simulate_frames(10, 16)
	runner.simulate_key_press(KEY_SHIFT)
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(30, 16)
	runner.simulate_key_release(KEY_W)
	runner.simulate_key_release(KEY_SHIFT)
	var ran := Vector2(player.global_position.x - start.x, player.global_position.z - start.z).length()

	assert_float(walked).is_greater(1.0)
	assert_float(ran).is_greater(walked * 1.3)


func test_space_jumps() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var player = s["main"].player
	var ground_y: float = player.global_position.y

	runner.simulate_key_press(KEY_SPACE)
	var highest := ground_y
	for i in range(20):
		await runner.simulate_frames(1, 16)
		highest = maxf(highest, player.global_position.y)
	runner.simulate_key_release(KEY_SPACE)

	assert_float(highest).is_greater(ground_y + 0.3)


func test_mouse_motion_turns_view_and_clamps_pitch() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var player = s["main"].player
	var camera = player.camera
	var yaw_before: float = player.rotation.y

	# Sideways motion turns the body (yaw).
	await runner.simulate_mouse_move(Vector2(300, 100))
	await runner.simulate_frames(2, 16)
	assert_float(absf(player.rotation.y - yaw_before)).is_greater(0.5)

	# Large vertical motion pushes pitch past the limit; it must clamp at 85 degrees (both ways).
	await runner.simulate_mouse_move_relative(Vector2(0, -3000), 0.3)
	await runner.simulate_frames(2, 16)
	assert_float(camera.rotation.x).is_between(PITCH_LIMIT - 0.002, PITCH_LIMIT + 0.002)
	await runner.simulate_mouse_move_relative(Vector2(0, 6000), 0.3)
	await runner.simulate_frames(2, 16)
	assert_float(camera.rotation.x).is_between(-PITCH_LIMIT - 0.002, -PITCH_LIMIT + 0.002)


func test_number_keys_and_wheel_change_element() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var main = s["main"]
	var player = main.player

	runner.simulate_key_pressed(KEY_2)
	await runner.simulate_frames(2, 16)
	assert_int(player.current_element).is_equal(Config.Element.ART)
	assert_str(main.hud.element_label.text).is_equal("Element: Art")

	runner.simulate_key_pressed(KEY_3)
	await runner.simulate_frames(2, 16)
	assert_str(main.hud.element_label.text).is_equal("Element: Nature")

	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(2, 16)
	assert_int(player.current_element).is_equal(Config.Element.MUSIC)
	assert_str(main.hud.element_label.text).is_equal("Element: Music")

	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(2, 16)
	assert_str(main.hud.element_label.text).is_equal("Element: Nature")

	runner.simulate_key_pressed(KEY_1)
	await runner.simulate_frames(2, 16)
	assert_str(main.hud.element_label.text).is_equal("Element: Music")


func test_escape_frees_mouse_and_click_recaptures() -> void:
	var s := await _start_fps()
	var runner = s["runner"]

	assert_bool(Controls.is_mouse_captured()).is_true()
	runner.simulate_key_pressed(KEY_ESCAPE)
	await runner.simulate_frames(2, 16)
	assert_bool(Controls.is_mouse_captured()).is_false()

	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2, 16)
	assert_bool(Controls.is_mouse_captured()).is_true()


func test_holding_fire_rescues_person_and_updates_hud() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var main = s["main"]
	var target = await _stage_target(runner, main, 0)
	assert_int(main.rescued_count).is_equal(0)

	var frames := await _hold_fire_until_rescued(runner, target, 600)

	assert_int(frames).is_greater(0)
	assert_int(main.rescued_count).is_equal(1)
	assert_str(main.hud.rescued_label.text).is_equal("Rescued: 1 / %d" % Config.PEOPLE_COUNT)


func test_matched_element_rescues_in_fewer_frames_than_weak() -> void:
	# Target affinity is Music (0). Music is a match, Art is weak against Music.
	var s := await _start_fps()
	var runner = s["runner"]
	var main = s["main"]
	var target = await _stage_target(runner, main, 0)
	runner.simulate_key_pressed(KEY_1)
	await runner.simulate_frames(2, 16)
	var matched_frames := await _hold_fire_until_rescued(runner, target, 900)
	assert_int(matched_frames).is_greater(0)

	# Fresh scene for the weak element.
	main.queue_free()
	await runner.simulate_frames(3, 16)
	s = await _start_fps()
	runner = s["runner"]
	main = s["main"]
	target = await _stage_target(runner, main, 0)
	runner.simulate_key_pressed(KEY_2)
	await runner.simulate_frames(2, 16)
	var weak_frames := await _hold_fire_until_rescued(runner, target, 900)
	assert_int(weak_frames).is_greater(0)

	assert_int(weak_frames).is_greater(matched_frames)


func test_r_restarts_the_scene() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var old_main = s["main"]
	var target = await _stage_target(runner, old_main, 0)
	await _hold_fire_until_rescued(runner, target, 600)
	assert_int(old_main.rescued_count).is_equal(1)

	# reload_current_scene needs the scene to be the tree's current scene. The R key is sent as a real
	# InputEvent straight to the engine: the scene runner cannot dispatch it, because the scene is replaced.
	get_tree().current_scene = old_main
	var key := InputEventKey.new()
	key.physical_keycode = KEY_R
	key.keycode = KEY_R
	key.pressed = true
	Input.parse_input_event(key)
	await runner.simulate_frames(5, 16)

	var new_main = get_tree().current_scene
	assert_bool(is_instance_valid(old_main)).is_false()
	assert_bool(new_main == null).is_false()
	assert_int(new_main.rescued_count).is_equal(0)
	assert_int(new_main.people.size()).is_equal(Config.PEOPLE_COUNT)


func test_m_returns_to_menu() -> void:
	var s := await _start_fps()
	var runner = s["runner"]

	runner.simulate_key_pressed(KEY_M)
	await runner.simulate_frames(5, 16)

	assert_str(get_tree().current_scene.scene_file_path).is_equal(MENU_SCENE)


func test_timer_expiry_shows_end_screen_with_buildings() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var main = s["main"]
	# Ten rescued people unlocks Cafe and Music Shop.
	main.rescued_count = 10
	main.hud.set_rescued(10, Config.PEOPLE_COUNT)
	main.time_left = 0.05

	await runner.simulate_frames(10, 16)

	assert_bool(main.running).is_false()
	assert_bool(main.hud.end_panel.visible).is_true()
	assert_str(main.hud.end_label.text).contains("Time's up!")
	assert_str(main.hud.end_label.text).contains("Cafe")
	assert_str(main.hud.end_label.text).contains("Music Shop")
	assert_str(main.hud.end_label.text).not_contains("Community Garden")


func test_rescuing_everyone_shows_happy_end_screen() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var main = s["main"]
	var target = await _stage_target(runner, main, 0)

	# Stage the last rescue: remove every other person and pretend the other 19 are already happy.
	for p in main.people.duplicate():
		if p != target:
			main.people.erase(p)
			p.queue_free()
	main.rescued_count = Config.PEOPLE_COUNT - 1
	await runner.simulate_frames(2, 16)

	await _hold_fire_until_rescued(runner, target, 600)

	assert_int(main.rescued_count).is_equal(Config.PEOPLE_COUNT)
	assert_bool(main.running).is_false()
	assert_str(main.hud.end_label.text).contains("Everyone's happy!")
	assert_str(main.hud.end_label.text).contains("Plaza Fountain")


func test_dark_neighbour_causes_relapse_and_alert() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var main = s["main"]
	var target = await _stage_target(runner, main, 0)
	await _hold_fire_until_rescued(runner, target, 600)
	assert_bool(target.is_rescued).is_true()

	# A fully dark person 1.5 m from the rescued one drains its joy over time.
	var dark = main.people[1]
	dark.global_position = Vector3(1.5, 0, -6)
	dark.gloom = 1.0

	var frames := 0
	while target.is_rescued and frames < 1500:
		await runner.simulate_frames(10, 20)
		frames += 10

	assert_bool(target.is_rescued).is_false()
	assert_str(main.hud.alert_label.text).is_equal("Someone lost their joy!")
	assert_float(main.hud.alert_label.modulate.a).is_greater(0.5)
	assert_int(main.rescued_count).is_equal(0)


func test_automated_run_never_captures_real_mouse() -> void:
	var s := await _start_fps()
	var runner = s["runner"]
	var target = await _stage_target(runner, s["main"], 0)
	await _hold_fire_until_rescued(runner, target, 600)
	assert_bool(Config.is_automated_test()).is_true()
	assert_bool(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED).is_false()
