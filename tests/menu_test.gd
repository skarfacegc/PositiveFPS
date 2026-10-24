extends GdUnitTestSuite

# Menu (menu.tscn), driven by real input: keys 1, 2 and 3, and clicks on the buttons. Each choice starts the level with
# that border variant (Config.border_variant).

const MENU := "res://menu.tscn"
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


func test_menu_has_three_variant_buttons_each_with_a_description() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var buttons: Array = []
	_find_buttons(runner.scene(), buttons)
	assert_int(buttons.size()).is_equal(3)
	assert_str(buttons[0].text).is_equal("A — Circle")
	assert_str(buttons[1].text).is_equal("B — Organic push (recommended)")
	assert_str(buttons[2].text).is_equal("C — Paint edge")
	var labels: Array = []
	_find_labels(runner.scene(), labels)
	var descriptions := 0
	for lbl: Label in labels:
		if lbl.text.length() > 30 and not lbl.text.contains("In game"):
			descriptions += 1
	assert_int(descriptions).is_equal(3)


func test_hint_line_names_the_keys() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var labels: Array = []
	_find_labels(runner.scene(), labels)
	var found := false
	for lbl: Label in labels:
		if lbl.text == "In game: R restart, M menu, F2 targeting, F3 debug":
			found = true
	assert_bool(found).is_true()


func test_key_1_starts_the_circle_variant() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_1)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	assert_int(Config.border_variant).is_equal(Config.BorderVariant.CIRCLE)
	await _leave_loaded_scene()


func test_key_2_starts_the_organic_variant() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_2)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	assert_int(Config.border_variant).is_equal(Config.BorderVariant.ORGANIC)
	await _leave_loaded_scene()


func test_key_3_starts_the_paint_edge_variant() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	runner.simulate_key_pressed(KEY_3)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	assert_int(Config.border_variant).is_equal(Config.BorderVariant.PAINT_EDGE)
	var td: TopDownMain = get_tree().current_scene as TopDownMain
	assert_int(td.border.variant).is_equal(Config.BorderVariant.PAINT_EDGE)
	await _leave_loaded_scene()


func test_clicking_the_third_button_starts_the_paint_edge_variant() -> void:
	var runner: GdUnitSceneRunner = await _start_menu()
	var buttons: Array = []
	_find_buttons(runner.scene(), buttons)
	var third: Button = buttons[2]
	runner.simulate_mouse_move(third.get_global_rect().get_center())
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(10)
	assert_str(_current_scene_path()).is_equal(TOP_DOWN)
	assert_int(Config.border_variant).is_equal(Config.BorderVariant.PAINT_EDGE)
	await _leave_loaded_scene()
