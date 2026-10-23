extends GdUnitTestSuite

# Top-down mode (topdown.tscn), driven by real input: WASD, mouse aim, element keys and wheel, G and Q.
# Auto-fire, projectiles and the burst are checked through their results (joy, cooldowns, nodes).

const TD := "res://topdown.tscn"


func _start_td() -> Dictionary:
	var runner: GdUnitSceneRunner = scene_runner(TD)
	await runner.simulate_frames(60, 16)
	return {"runner": runner, "td": runner.scene()}


# Moves every person far from the action except the target (index 0) and the near one (index 1).
# Places the near person 3 m east of the player and the target 8 m north (-Z). Both are Music.
func _stage(td: TopDownMain) -> Array:
	for p: Person in td.people:
		p.global_position = Vector3(30, 0, -30)
	var target: Person = td.people[0]
	var near: Person = td.people[1]
	td.player.global_position = Vector3.ZERO
	target.affinity = 0
	target.gloom = 0.0
	target.global_position = Vector3(0, 0, -8)
	near.affinity = 0
	near.gloom = 0.0
	near.global_position = Vector3(3, 0, 0)
	target.joy = 0.0
	near.joy = 0.0
	return [target, near]


# The screen position where the mouse must be for the aim to land on `world_pos` on the floor.
func _screen_of(td: TopDownMain, world_pos: Vector3) -> Vector2:
	return td.camera.unproject_position(world_pos)


func _projectile_count(td: TopDownMain) -> int:
	var n := 0
	for child: Node in td.get_children():
		if child.get_script() == JoyProjectile:
			n += 1
	return n


func test_wasd_moves_in_world_space() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	var start: Vector3 = player.global_position

	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(30, 16)
	runner.simulate_key_release(KEY_W)
	var after_w: Vector3 = player.global_position
	assert_float(start.z - after_w.z).is_greater(1.0)  # W is world north (-Z)

	runner.simulate_key_press(KEY_D)
	await runner.simulate_frames(30, 16)
	runner.simulate_key_release(KEY_D)
	assert_float(player.global_position.x - after_w.x).is_greater(1.0)  # D is world east (+X)


func test_mouse_over_person_makes_auto_fire_target_that_person() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var staged: Array = _stage(td)
	var target: Person = staged[0]
	var near: Person = staged[1]
	# Aim before any frame runs, or auto-fire would pick a default aim point first.
	runner.simulate_mouse_move(_screen_of(td, target.chest_position()))
	await runner.simulate_frames(30, 16)

	# The aim point is on the target, so aim assist picks it even though the other person is closer.
	assert_float(target.joy).is_greater(0.0)
	assert_float(near.joy).is_equal_approx(0.0, 0.001)


func test_without_mouse_target_nearest_person_is_targeted() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var staged: Array = _stage(td)
	var target: Person = staged[0]
	var near: Person = staged[1]
	# Aim far from everyone (no one within the aim-assist radius), so the nearest person is chosen.
	runner.simulate_mouse_move(_screen_of(td, Vector3(-20, 0, 20)))
	await runner.simulate_frames(30, 16)

	assert_float(near.joy).is_greater(0.0)
	assert_float(target.joy).is_equal_approx(0.0, 0.001)


func test_projectiles_spawn_and_free_themselves() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var staged: Array = _stage(td)
	var target: Person = staged[0]
	runner.simulate_mouse_move(_screen_of(td, target.chest_position()))

	var tracked: Node = null
	for i: int in range(30):
		await runner.simulate_frames(1, 16)
		for child: Node in td.get_children():
			if tracked == null and child.get_script() == JoyProjectile:
				tracked = child
	assert_object(tracked).is_not_null()

	# A projectile lasts a fraction of a second; wait for this one to be freed.
	for i: int in range(120):
		if not is_instance_valid(tracked) or not tracked.is_inside_tree():
			break
		await runner.simulate_frames(1, 16)
	assert_bool(is_instance_valid(tracked) and tracked.is_inside_tree()).is_false()


func test_g_and_q_burst_only_when_ready() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player

	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(2, 16)
	assert_float(player.burst_cooldown).is_greater(Config.TD_BURST_COOLDOWN - 0.5)
	assert_str(td.hud.burst_label.text).contains("s")  # cooldown shown, not READY

	await runner.simulate_frames(30, 16)
	var before_q: float = player.burst_cooldown
	runner.simulate_key_pressed(KEY_Q)
	await runner.simulate_frames(2, 16)
	# Pressing Q during the cooldown must not restart it: the cooldown keeps running down.
	assert_float(player.burst_cooldown).is_less(before_q)

	# Once the cooldown is ready (set directly, so the test does not wait 8 s), Q bursts again.
	player.burst_cooldown = 0.0
	runner.simulate_key_pressed(KEY_Q)
	await runner.simulate_frames(2, 16)
	assert_float(player.burst_cooldown).is_greater(Config.TD_BURST_COOLDOWN - 0.5)


func test_element_keys_and_wheel_change_ring_colour() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player

	runner.simulate_key_pressed(KEY_2)
	await runner.simulate_frames(2, 16)
	assert_str(td.hud.element_label.text).is_equal("Element: Art")
	assert_bool(player._ring_mat.albedo_color.is_equal_approx(Config.ELEMENT_COLORS[1])).is_true()

	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(2, 16)
	assert_bool(player._ring_mat.albedo_color.is_equal_approx(Config.ELEMENT_COLORS[2])).is_true()

	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(2, 16)
	assert_bool(player._ring_mat.albedo_color.is_equal_approx(Config.ELEMENT_COLORS[1])).is_true()


func test_timer_expiry_shows_end_screen_with_buildings() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.rescued_count = 15
	td.hud.set_rescued(15, Config.TD_PEOPLE_COUNT)
	td.time_left = 0.05
	await runner.simulate_frames(10, 16)

	assert_bool(td.running).is_false()
	assert_bool(td.hud.end_panel.visible).is_true()
	assert_str(td.hud.end_label.text).contains("Cafe")
	assert_str(td.hud.end_label.text).not_contains("Music Shop")


func test_rescuing_everyone_by_auto_fire_shows_happy_end_screen() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var staged: Array = _stage(td)
	var target: Person = staged[0]
	# Remove everyone else and pretend the rest are already happy; auto-fire rescues the last one.
	for p: Person in td.people.duplicate():
		if p != target:
			td.people.erase(p)
			p.queue_free()
	td.player.people = td.people
	td.rescued_count = Config.TD_PEOPLE_COUNT - 1
	runner.simulate_mouse_move(_screen_of(td, target.chest_position()))

	var frames := 0
	while not target.is_rescued and frames < 600:
		await runner.simulate_frames(1, 16)
		frames += 1

	assert_bool(target.is_rescued).is_true()
	assert_bool(td.running).is_false()
	assert_str(td.hud.end_label.text).contains("Everyone's happy!")


func test_crowd_wanders_and_paints_for_several_hundred_frames() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var before: Vector3 = td.people[5].global_position
	await runner.simulate_frames(300, 16)
	assert_int(td.people.size()).is_equal(Config.TD_PEOPLE_COUNT)
	assert_float(td.people[5].global_position.distance_to(before)).is_greater(0.05)
	assert_bool(td.running).is_true()


func test_dark_person_drifts_to_rescued_and_relapse_alerts() -> void:
	var s: Dictionary = await _start_td()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var staged: Array = _stage(td)
	var target: Person = staged[0]
	var dark: Person = staged[1]
	# Rescue the target with real aim first.
	runner.simulate_mouse_move(_screen_of(td, target.chest_position()))
	var frames := 0
	while not target.is_rescued and frames < 600:
		await runner.simulate_frames(1, 16)
		frames += 1
	assert_bool(target.is_rescued).is_true()

	# Walk the player out of auto-fire range, so nothing tops the rescued person back up.
	td.player.global_position = Vector3(-25, 0, 25)
	# A fully dark person 6 m away drifts toward the rescued one and drains its joy.
	dark.gloom = 1.0
	dark.global_position = Vector3(6, 0, -8)

	frames = 0
	while target.is_rescued and frames < 800:
		await runner.simulate_frames(10, 16)
		frames += 10

	assert_bool(target.is_rescued).is_false()
	assert_str(td.hud.alert_label.text).is_equal("Someone lost their joy!")
	assert_int(td.rescued_count).is_equal(0)
