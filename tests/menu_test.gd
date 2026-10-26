extends GdUnitTestSuite

# Menu (menu.tscn), driven by real input: the Play button (a click), key 1 and Enter. Each one starts the level.
# Round 10: the border variant picker is gone, so the menu has one button and no variant choices.

const MENU := "res://menu.tscn"
const TOP_DOWN := "res://topdown.tscn"
const HOW_TO_PLAY_VIEW := Vector2(1280, 720)


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


func test_the_styled_look_note_shows_only_while_styled_is_selected() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var menu := runner.scene() as Control
	var note: Label = menu.get("look_note")
	assert_bool(note.visible).is_false()
	var button: Button = menu.get("look_button")
	button.pressed.emit()
	assert_bool(note.visible).is_true()
	assert_str(note.text).contains("visual test only")
	assert_str(note.text).contains("not the current game")
	button.pressed.emit()
	assert_bool(note.visible).is_false()
	# It is a label, not a button: the menu still has just two buttons.
	var buttons: Array = []
	_find_buttons(menu, buttons)
	assert_int(buttons.size()).is_equal(2)


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


func test_how_to_play_panel_is_visible_and_names_the_sections() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var panel: RichTextLabel = (runner.scene() as Control).get("how_to_play")
	assert_object(panel).is_not_null()
	assert_bool(panel.is_visible_in_tree()).is_true()
	var text := panel.get_parsed_text()
	assert_str(text).contains("How to play")
	assert_str(text).contains("Goal")
	assert_str(text).contains("Spirit")
	assert_str(text).contains("Space twirl")


func test_every_key_named_in_the_keys_line_is_bound() -> void:
	await _start_menu()
	Controls.setup()
	for action: String in [
		"move_forward",
		"move_back",
		"move_left",
		"move_right",
		"run",
		"twirl",
		"burst",
		"cycle_targeting",
		"toggle_debug",
		"zoom_in",
		"zoom_out",
		"toggle_look",
		"restart",
		"menu",
	]:
		assert_bool(InputMap.has_action(action)).is_true()
		assert_int(InputMap.action_get_events(action).size()).is_greater(0)


func test_how_to_play_panel_does_not_overlap_the_buttons_at_1280_by_720() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var menu := runner.scene() as Control
	var panel: RichTextLabel = menu.get("how_to_play")
	var panel_rect := panel.get_global_rect()
	assert_bool(Rect2(Vector2.ZERO, HOW_TO_PLAY_VIEW).encloses(panel_rect)).is_true()
	var buttons: Array = []
	_find_buttons(menu, buttons)
	for btn: Button in buttons:
		assert_bool(panel_rect.intersects(btn.get_global_rect())).is_false()


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
