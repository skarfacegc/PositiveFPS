extends GdUnitTestSuite

# Menu (menu.tscn), driven by real input: number keys, and clicks on the buttons.

const MENU := "res://menu.tscn"
const MAIN := "res://main.tscn"
const TOP_DOWN := "res://topdown.tscn"


# The gdUnit4 CLI shrinks the window to 64x64, and the menu lays out against that size. Give the window and
# the menu the project's real size so the button positions are the ones a player sees.
func _start_menu() -> GdUnitSceneRunner:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var runner := scene_runner(MENU)
	(runner.scene() as Control).size = Vector2(1280, 720)
	await runner.simulate_frames(10)
	return runner


func _find_buttons(node: Node, out: Array) -> void:
	if node is Button:
		out.append(node)
	for child: Node in node.get_children():
		_find_buttons(child, out)


func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


# Frees the level a test loaded through the menu. Those levels are not owned by the scene runner, so without this a
# later suite would start with a level still running and taking its input (see fps_mode_test).
func _leave_loaded_scene() -> void:
	get_tree().current_scene.queue_free()
	await get_tree().process_frame


func test_menu_has_two_mode_buttons() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var buttons: Array = []
	_find_buttons(runner.scene(), buttons)
	assert_int(buttons.size()).is_equal(2)
	assert_str(buttons[0].text).contains("First person")
	assert_str(buttons[1].text).contains("Top-down")


func test_key_1_loads_first_person() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_1)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(MAIN)
	await _leave_loaded_scene()


func test_key_2_loads_top_down() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_2)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	await _leave_loaded_scene()


func test_clicking_first_button_loads_first_person() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var buttons: Array = []
	_find_buttons(runner.scene(), buttons)
	var first: Button = buttons[0]
	runner.simulate_mouse_move(first.get_global_rect().get_center())
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(MAIN)
	await _leave_loaded_scene()
