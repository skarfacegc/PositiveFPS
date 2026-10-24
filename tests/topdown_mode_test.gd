extends GdUnitTestSuite

# Top-down mode (topdown.tscn), driven by real input: WASD, mouse aim and clicks, F2, G and Q.
# Targeting modes, lock-on and the projectile physics have their own suites (targeting_test.gd and
# projectile_physics_test.gd). Here: movement, the joy burst, the timer, the crowd, and the basic fire loop.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Lock on to `person` with a real mouse click on the floor under it (lock-on is the default mode).
func _click_to_lock(runner: GdUnitSceneRunner, td: TopDownMain, person: Person) -> void:
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, person.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


func test_wasd_moves_in_world_space() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	var start: Vector3 = player.global_position

	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(30)
	runner.simulate_key_release(KEY_W)
	var after_w: Vector3 = player.global_position
	assert_float(start.z - after_w.z).is_greater(1.0)  # W is world north (-Z)

	runner.simulate_key_press(KEY_D)
	await runner.simulate_frames(30)
	runner.simulate_key_release(KEY_D)
	assert_float(player.global_position.x - after_w.x).is_greater(1.0)  # D is world east (+X)


func test_mouse_alone_never_fires_in_lock_on_mode() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)

	# Hover right over the person, with no click: nothing is locked and nothing is fired.
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(60)
	assert_object(td.player.target).is_null()
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)
	assert_float(target.joy).is_equal(0.0)


func test_projectiles_spawn_while_locked_and_free_after_releasing() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)

	await _click_to_lock(runner, td, target)
	await runner.simulate_frames(20)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_greater(0)

	# Click empty ground to drop the lock. Shots stop, and the projectiles in the air finish and free themselves.
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, TopDownTestUtil.clear_spot(td)))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(150)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)


func test_g_and_q_burst_only_when_ready() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player

	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(2)
	assert_float(player.burst_cooldown).is_greater(Config.TD_BURST_COOLDOWN - 0.5)
	assert_str(td.hud.burst_label.text).contains("s")  # cooldown shown, not READY

	await runner.simulate_frames(30)
	var before_q: float = player.burst_cooldown
	runner.simulate_key_pressed(KEY_Q)
	await runner.simulate_frames(2)
	# Pressing Q during the cooldown must not restart it: the cooldown keeps running down.
	assert_float(player.burst_cooldown).is_less(before_q)

	# Once the cooldown is ready (set directly, so the test does not wait 8 s), Q bursts again.
	player.burst_cooldown = 0.0
	runner.simulate_key_pressed(KEY_Q)
	await runner.simulate_frames(2)
	assert_float(player.burst_cooldown).is_greater(Config.TD_BURST_COOLDOWN - 0.5)


func test_element_keys_and_wheel_do_nothing_in_top_down() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player

	# With no target the HUD says so, and the ring stays cream.
	assert_str(td.hud.element_label.text).is_equal("No target")
	runner.simulate_key_pressed(KEY_2)  # Number keys no longer switch element: nothing happens.
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(2)
	assert_str(td.hud.element_label.text).is_equal("No target")
	assert_bool(player._ring_mat.albedo_color.is_equal_approx(Config.TD_NO_TARGET_COLOR)).is_true()
	assert_object(player.target).is_null()


# Round 9: dusk to dawn replaces the timer. Dawn ends the level, and the end screen says whether the landmark was held.
func test_dawn_ends_the_level_with_the_dawn_screen() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.night.elapsed = Config.NIGHT_LENGTH - 0.05
	await runner.simulate_frames(10)

	assert_bool(td.running).is_false()
	assert_bool(td.hud.end_panel.visible).is_true()
	assert_str(td.hud.end_label.text).contains("Dawn")
	assert_str(td.hud.end_label.text).contains("Landmark held: no")


# Round 9: rescuing everyone no longer ends the level. Only dawn, the landmark, or the border falling does.
func test_rescuing_everyone_by_locked_fire_does_not_end_the_level() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	# Remove everyone else and pretend the rest are already happy; locked fire rescues the last one.
	for p: Person in td.people.duplicate():
		if p != target:
			td.people.erase(p)
			p.queue_free()
	td.player.people = td.people
	td.rescued_count = Config.TD_PEOPLE_COUNT - 1

	await _click_to_lock(runner, td, target)
	var frames := 0
	while not target.is_rescued and frames < 600:
		await runner.simulate_frames(1)
		frames += 1

	assert_bool(target.is_rescued).is_true()
	assert_bool(td.running).is_true()
	assert_bool(td.hud.end_panel.visible).is_false()


func test_crowd_wanders_and_paints_for_several_hundred_frames() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var before: Vector3 = td.people[5].global_position
	await runner.simulate_frames(300)
	assert_int(td.people.size()).is_equal(Config.TD_PEOPLE_COUNT)
	assert_float(td.people[5].global_position.distance_to(before)).is_greater(0.05)
	assert_bool(td.running).is_true()


func test_a_relapse_lowers_the_count_and_shows_the_alert() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	target.receive_joy(0, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(2)
	assert_int(td.rescued_count).is_equal(1)

	# Drain from outside the rules (no grace, no cover): the person drops below the relapse line and turns grey.
	target.grace_left = 0.0
	target.drain_joy(Config.JOY_MAX)
	await runner.simulate_frames(2)
	assert_bool(target.is_rescued).is_false()
	assert_int(td.rescued_count).is_equal(0)
	assert_str(td.hud.alert_label.text).is_equal("Someone lost their joy!")
