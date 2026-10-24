extends GdUnitTestSuite

# Menu (menu.tscn), driven by real input: the Play button (a click), key 1 and Enter. Each one starts the level.
# Round 10: the border variant picker is gone, so the menu has one button and no variant choices.

const MENU := "res://menu.tscn"
const TOP_DOWN := "res://topdown.tscn"
const HINT := "Enter or 1 to play.  In game: R restart, M menu, F2 targeting, F3 debug"


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


func _find_labels(node: Node, out: Array) -> void:
	if node is Label:
		out.append(node)
	for child: Node in node.get_children():
		_find_labels(child, out)


func _current_scene_path() -> String:
	var scene: Node = get_tree().current_scene
	return scene.scene_file_path if scene != null else ""


# Frees the level a test loaded through the menu. Those levels are not owned by the scene runner, so without this a
# later suite would start with a level still running and taking its input.
func _leave_loaded_scene() -> void:
	get_tree().current_scene.queue_free()
	await get_tree().process_frame


func test_menu_has_a_play_button_and_a_look_toggle_and_no_variant_choices() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var buttons: Array = []
	_find_buttons(runner.scene(), buttons)
	assert_int(buttons.size()).is_equal(2)
	assert_str(buttons[0].text).is_equal("Play")
	assert_str(buttons[1].text).is_equal("Look: Placeholder")


func test_the_look_button_flips_the_look_and_remembers_it() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var menu := runner.scene() as Control
	var button: Button = menu.get("look_button")
	button.pressed.emit()
	assert_int(Looks.mode).is_equal(Looks.Mode.STYLED)
	assert_str(button.text).is_equal("Look: Styled")
	button.pressed.emit()
	assert_int(Looks.mode).is_equal(Looks.Mode.PLACEHOLDER)
	assert_str(button.text).is_equal("Look: Placeholder")


func test_hint_line_names_the_keys() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var labels: Array = []
	_find_labels(runner.scene(), labels)
	var found := false
	for lbl: Label in labels:
		if lbl.text == HINT:
			found = true
	assert_bool(found).is_true()


func test_key_1_starts_the_level() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_1)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	await _leave_loaded_scene()


func test_enter_starts_the_level() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_ENTER)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	await _leave_loaded_scene()


func test_clicking_play_starts_the_level() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var buttons: Array = []
	_find_buttons(runner.scene(), buttons)
	var play: Button = buttons[0]
	runner.simulate_mouse_move(play.get_global_rect().get_center())
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	await _leave_loaded_scene()


func test_a_second_start_in_the_same_frame_is_ignored() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_1)
	runner.simulate_key_pressed(KEY_ENTER)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	await _leave_loaded_scene()
