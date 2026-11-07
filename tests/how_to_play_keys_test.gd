extends GdUnitTestSuite

# Every player action that Controls registers must be named in the how-to-play text (scripts/menu.gd), so a new key
# cannot ship without a line for the player. The key names are read from the registered input events, so the test
# follows the real bindings.

# Actions that are not a "key to learn", with the reason. Anything else must appear in the text.
const NOT_IN_TEXT := {
	"play": "the Play button on the menu is the prompt; 1 and Enter are shortcuts for it",
}
# Actions whose text names a group of keys or a device, not one key each.
const GROUP_TOKEN := {
	"move_forward": "WASD",
	"move_back": "WASD",
	"move_left": "WASD",
	"move_right": "WASD",
	"fire": "Mouse",
	"zoom_in": "Wheel",
	"zoom_out": "Wheel",
	"cancel_beacon": "right-click",
}


func _text() -> String:
	return (load("res://scripts/menu.gd") as GDScript).get_script_constant_map()["HOW_TO_PLAY_TEXT"]


# The names of the keys bound to an action, as the text would write them: "G", "Shift", "F2".
func _key_names(action: String) -> Array[String]:
	var names: Array[String] = []
	for ev: InputEvent in InputMap.action_get_events(action):
		if ev is InputEventKey:
			names.append(OS.get_keycode_string((ev as InputEventKey).keycode))
	return names


# True when `token` stands alone in the text (not inside a longer word, so "E" does not match "Everyone").
func _has_word(text: String, token: String) -> bool:
	var re := RegEx.new()
	re.compile("(^|[^A-Za-z0-9])" + token + "([^A-Za-z0-9]|$)")
	return re.search(text) != null


func _registered_actions() -> Array[String]:
	Controls.setup()
	var actions: Array[String] = []
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or String(action).begins_with("spatial_editor"):
			continue
		actions.append(String(action))
	return actions


func test_every_player_action_appears_in_the_how_to_play_text() -> void:
	var text := _text()
	var actions := _registered_actions()
	assert_bool(actions.size() >= 15).is_true()
	var missing: Array[String] = []
	for action: String in actions:
		if NOT_IN_TEXT.has(action):
			continue
		var found := false
		if GROUP_TOKEN.has(action):
			var token: String = GROUP_TOKEN[action]
			found = _has_word(text, token)
		else:
			for key_name: String in _key_names(action):
				found = found or _has_word(text, key_name)
		if not found:
			missing.append(action)
	assert_array(missing).is_empty()


func test_the_shape_zone_key_is_listed_with_the_other_keys() -> void:
	var keys_line := _text().split("[b]Keys:[/b]")[1]
	assert_bool(_has_word(keys_line, "E")).is_true()
	assert_bool(_has_word(keys_line, "F")).is_false()  # Round 26: the F patch is gone.
	assert_bool(_has_word(keys_line, "G")).is_true()
	assert_bool(_has_word(keys_line, "Q")).is_true()


func test_the_check_notices_an_action_that_is_not_in_the_text() -> void:
	InputMap.add_action("zz_made_up_action")
	var ev := InputEventKey.new()
	ev.keycode = KEY_J
	InputMap.action_add_event("zz_made_up_action", ev)
	assert_bool(_has_word(_text(), "J")).is_false()
	assert_array(_key_names("zz_made_up_action")).contains_exactly(["J"])
	InputMap.erase_action("zz_made_up_action")
