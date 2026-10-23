class_name Controls
extends RefCounted

# The player's intent for mouse capture. In automated tests the real OS mouse mode is never changed,
# so tests check this instead (see is_mouse_captured).
static var mouse_captured: bool = false


# Captures or frees the mouse. In automated tests only the intent is recorded.
static func set_mouse_captured(captured: bool) -> void:
	mouse_captured = captured
	if Config.is_automated_test():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


# True if the mouse is captured. The real game reads the OS mode; automated tests read the intent.
static func is_mouse_captured() -> bool:
	if Config.is_automated_test():
		return mouse_captured
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED


# Registers every input action the game uses. Each action is only added if it does not exist yet,
# so it is safe to call from the menu, first-person mode and top-down mode.


static func setup() -> void:
	if Config.is_automated_test():
		DisplayServer.window_set_title("PositiveFPS — AUTOMATED TEST (not for playing)")
	_add_action("move_forward", [_key(KEY_W)])
	_add_action("move_back", [_key(KEY_S)])
	_add_action("move_left", [_key(KEY_A)])
	_add_action("move_right", [_key(KEY_D)])
	_add_action("run", [_key(KEY_SHIFT)])
	_add_action("jump", [_key(KEY_SPACE)])
	_add_action("fire", [_mouse(MOUSE_BUTTON_LEFT)])
	_add_action("element_1", [_key(KEY_1)])
	_add_action("element_2", [_key(KEY_2)])
	_add_action("element_3", [_key(KEY_3)])
	_add_action("element_next", [_mouse(MOUSE_BUTTON_WHEEL_DOWN)])
	_add_action("element_prev", [_mouse(MOUSE_BUTTON_WHEEL_UP)])
	# Joy burst: G is the grenade-style key by convention, Q is a second option.
	_add_action("burst", [_key(KEY_G), _key(KEY_Q)])
	_add_action("restart", [_key(KEY_R)])
	_add_action("release_mouse", [_key(KEY_ESCAPE)])
	_add_action("menu", [_key(KEY_M)])


static func _add_action(action: String, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for ev: InputEvent in events:
		InputMap.action_add_event(action, ev)


static func _key(keycode: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	return ev


static func _mouse(button: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev
