class_name TopDownTestUtil
extends RefCounted

# Helpers shared by the top-down test suites. It has no test_ functions, so gdUnit does not run it as a suite.

const SCENE := "res://topdown.tscn"
# Where people are parked while a test is not using them: far from the player and out of the way.
const FAR := Vector3(30, 0, -30) * Config.WORLD_SCALE  # Round 13a: scaled with the plaza (still inside the walls).
# The window size every level test runs at. The gdUnit4 CLI shrinks the window to 64x64, which puts the player and the
# test spots off screen, so a suite must not rely on another suite having set the size first (suites run in separate
# processes in tools/run_tests.py).
const WINDOW_SIZE := Vector2i(1280, 720)


# Sets the window to WINDOW_SIZE, then loads the level into a scene runner owned by `suite`.
#
# The minimap redraws its 128x128 picture about ten times a second, which costs more than everything else the level
# does in a frame (about 8 ms per redraw, headless). Almost no test looks at it, so by default the automatic redraw is
# switched off here; the minimap's own data model and drawing are still tested in readability_test.gd, which passes
# `minimap_refresh = true`. Nothing else about the level changes.
static func level_runner(suite: GdUnitTestSuite, minimap_refresh: bool = false) -> GdUnitSceneRunner:
	suite.get_window().size = WINDOW_SIZE
	await suite.get_tree().process_frame
	var runner := suite.scene_runner(SCENE)
	if not minimap_refresh:
		(runner.scene() as TopDownMain).minimap._timer = -1.0e12
	return runner


# Parks every person far away, so only the people a test places can take part.
static func send_everyone_away(td: TopDownMain) -> void:
	for p: Person in td.people:
		p.mood = Person.Mood.NONE
		p.global_position = FAR


# Puts a person on the floor at `spot` with the given affinity (0 music, 1 art, 2 nature) and gloom level.
static func place(p: Person, spot: Vector3, affinity: int, gloom: float) -> void:
	p.affinity = affinity
	p.gloom = gloom
	p.joy = 0.0
	# Round 12b: placed people have no mood unless a test gives them one, so older tests see plain people.
	p.mood = Person.Mood.NONE
	p.global_position = Vector3(spot.x, 0.0, spot.z)


# The screen position of the floor point under `spot`. A mouse there aims (or clicks) that spot.
static func screen_of(td: TopDownMain, spot: Vector3) -> Vector2:
	return td.world_to_screen(Vector3(spot.x, 0.0, spot.z))


# Round 14: the midnight stagger lets one person sink to dimmed at a time (see TopDownMain._try_dim_sink). A test
# that places several dimmed people in one go opens that gate first, so each one may sink at once (stagger_test.gd
# checks the gate itself).
static func open_dim_gate(td: TopDownMain) -> void:
	td._last_dim_sink = -INF


# Round 24: a drained rescued person wobbles before they relapse, and one relapse goes through the shared gate per
# RELAPSE_GATE_GAP. A test that only needs the person gone (to see what the border or the zone does) calls this: it
# drains them and lets the wobble end at once, past the gate, so they relapse on the next tick.
static func lose_now(p: Person) -> void:
	p.grace_left = 0.0
	p.drain_joy(1.0e6)
	p.relapse_gate = Callable()
	p.wobble_left = 0.0


# Every joy projectile currently in the level.
static func projectiles(td: TopDownMain) -> Array[JoyProjectile]:
	var out: Array[JoyProjectile] = []
	for child: Node in td.get_children():
		if child is JoyProjectile:
			out.append(child as JoyProjectile)
	return out


# Closes every recorder still open under `node`. A test that did not leave its level keeps the session file open until
# the level is freed, which is after after_test, and Windows will not delete an open file. Recorder.end only writes the
# last line and closes the file; the level is freed later, as before.
static func close_open_recorders(node: Node) -> void:
	if node is Recorder:
		(node as Recorder).end("test")
	for child: Node in node.get_children():
		close_open_recorders(child)


# Frees a level a test loaded through the menu, so a later suite does not inherit it (see menu_test.gd).
static func leave_loaded_scene(td: TopDownMain) -> void:
	td.queue_free()
	await td.get_tree().process_frame


# Presses F2 (real key presses) until the player is in `mode`. The default mode is hover, so tests that need lock-on
# or auto call this first rather than relying on the default.
static func select_mode(runner: GdUnitSceneRunner, td: TopDownMain, mode: int) -> void:
	var presses := 0
	while td.player.targeting_mode != mode and presses < 3:
		runner.simulate_key_pressed(KEY_F2)
		await runner.simulate_frames(2)
		presses += 1


# A spot on the floor a few metres from the player, in view and with nobody on it. Clicking it clears a lock.
static func clear_spot(td: TopDownMain) -> Vector3:
	return td.player.global_position + Vector3(-6, 0, 6)


# Every bloom currently in the level.
static func blooms(td: TopDownMain) -> Array[Bloom]:
	var out: Array[Bloom] = []
	for child: Node in td.get_children():
		if child is Bloom:
			out.append(child as Bloom)
	return out


# Checkpoint 5 follow-up: E is hold to aim, release to place, and right-click cancels. These send the event through
# TopDownMain's own input handler (the same mapped actions a key or button press would reach), so tests that
# drive the level without a scene runner use the game's own code. Tests that press real keys use the runner.
static func press_e(td: TopDownMain) -> void:
	td._unhandled_input(_key_event(KEY_E, true))


static func release_e(td: TopDownMain) -> void:
	td._unhandled_input(_key_event(KEY_E, false))


static func cancel_aim(td: TopDownMain) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	td._unhandled_input(ev)


static func _key_event(code: Key, pressed: bool) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.pressed = pressed
	return ev
