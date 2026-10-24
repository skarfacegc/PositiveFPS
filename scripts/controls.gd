class_name Controls
extends RefCounted

# Registers every input action the game uses. Each action is only added if it does not exist yet,
# so it is safe to call from the menu and the level.


static func setup() -> void:
	if Config.is_automated_test():
		DisplayServer.window_set_title("PositiveFPS — AUTOMATED TEST (not for playing)")
	_add_action("move_forward", [_key(KEY_W)])
	_add_action("move_back", [_key(KEY_S)])
	_add_action("move_left", [_key(KEY_A)])
	_add_action("move_right", [_key(KEY_D)])
	_add_action("run", [_key(KEY_SHIFT)])
	# Left click: lock on to a person (lock-on mode). Read as "fire" in the level.
	_add_action("fire", [_mouse(MOUSE_BUTTON_LEFT)])
	# Menu: Play, with key 1 or Enter.
	_add_action("play", [_key(KEY_1), _key(KEY_ENTER)])
	# Joy burst: G is the grenade-style key by convention, Q is a second option.
	_add_action("burst", [_key(KEY_G), _key(KEY_Q)])
	# Cycles the targeting mode (lock-on, hover, auto).
	_add_action("cycle_targeting", [_key(KEY_F2)])
	# Shows cover and protection above each person, and a hint in the HUD (off by default).
	_add_action("toggle_debug", [_key(KEY_F3)])
	# Flips between the placeholder and the styled look (graphics checkpoint 1).
	_add_action("toggle_look", [_key(KEY_F4)])
	_add_action("restart", [_key(KEY_R)])
	_add_action("menu", [_key(KEY_M)])


# Gamepad-ready: no joypad events are bound yet (no device to test with). All gameplay code reads these
# actions, never raw keys, so a future gamepad mapping only needs joypad events added to the actions above:
#   move_forward, move_back, move_left, move_right  -> left stick
#   run                                             -> left stick click
#   burst                                           -> top face button
#   fire (lock on to a person)                      -> right trigger
#   cycle_targeting                                 -> left shoulder button
#   restart, menu                                   -> start or back
# Aiming uses the mouse position on the floor, so a gamepad would also need a right-stick aim point.


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
