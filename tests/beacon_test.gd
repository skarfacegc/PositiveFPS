extends GdUnitTestSuite

# Round 19: the spirit beacon. Without a beacon the border's centre stays anchored; E places a beacon for spirit and the
# centre walks to it slowly.

const ANCHOR_DRIFT_BOUND := 0.05


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	return {"runner": runner, "td": td}


func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int, first: int = 0) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[first + i]
		TopDownTestUtil.place(p, c + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# A loop of 12 people, then the player stands at the edge and rescues pile up on one side for ten seconds, with pushes.
# Returns how far the centre moved from where it settled.
func _drift_with_pushing(td: TopDownMain, runner: GdUnitSceneRunner) -> float:
	_rescue_ring(td, Vector3(-6, 0, 4), 6.0, 12)
	await runner.simulate_frames(240)
	var c0 := td.border.centre
	var worst := 0.0
	for k: int in range(6):
		var edge := Vector3(td.border.centre.x + 9.0, 0.0, td.border.centre.z)
		td.player.global_position = edge
		# Three more people rescued out on the pushed side drag the centroid east.
		for j: int in range(3):
			var p: Person = td.people[12 + k * 3 + j]
			TopDownTestUtil.place(p, edge + Vector3(1.0 + j, 0.0, float(j)), p.affinity, 0.0)
			p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
		td.border.shove(edge)
		await runner.simulate_frames(120)
		worst = maxf(worst, GloomSim.flat_dist(td.border.centre, c0))
	return worst


func test_the_centre_stays_put_when_the_player_stands_at_and_pushes_the_edge() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var drift: float = await _drift_with_pushing(td, runner)
	print("PROBE centre drift with pushing, no beacon = %.2f m" % drift)
	assert_float(drift).is_less(ANCHOR_DRIFT_BOUND)
	await TopDownTestUtil.leave_loaded_scene(td)


# A level with a formed border of six people round (-6, 4), settled; the player has full spirit.
func _formed() -> Dictionary:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	_rescue_ring(td, Vector3(-6, 0, 4), 4.0, 6)
	await runner.simulate_frames(60)
	td.player.add_spirit(100.0)
	return s


# Moves the cursor over the ground point `spot` and presses E.
func _press_e(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(4)
	runner.simulate_key_pressed(KEY_E)
	await runner.simulate_frames(2)


func test_e_places_a_beacon_at_the_cursor_and_costs_spirit() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	await _press_e(runner, td, Vector3(8, 0, 6))
	assert_bool(td.border.has_beacon()).is_true()
	assert_float(td.border.beacon_pos().x).is_equal_approx(8.0, 0.6)
	assert_float(td.border.beacon_pos().z).is_equal_approx(6.0, 0.6)
	# The key is delivered twice by gdUnit: one beacon, one charge.
	assert_float(before - td.player.spirit).is_equal_approx(Config.BEACON_SPIRIT_COST, 0.5)
	assert_bool(td.beacon_marker.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_centre_walks_to_the_beacon_at_the_pull_speed_then_the_beacon_clears() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var reached: Array[int] = [0]
	td.border.beacon_reached.connect(func() -> void: reached[0] += 1)
	td.border.place_beacon(Vector3(30, 0, 4))
	var c0 := td.border.centre
	await runner.simulate_frames(120)
	var walked := GloomSim.flat_dist(td.border.centre, c0)
	print("PROBE beacon walk in 2 s = %.2f m (speed %.2f m/s)" % [walked, Config.BEACON_PULL_SPEED])
	assert_float(walked).is_equal_approx(Config.BEACON_PULL_SPEED * 2.0, 0.15)
	assert_bool(td.border.has_beacon()).is_true()
	var left := GloomSim.flat_dist(td.border.centre, td.border.beacon_pos())
	await runner.simulate_frames(int(left / Config.BEACON_PULL_SPEED * 60.0) + 60)
	assert_bool(td.border.has_beacon()).is_false()
	assert_int(reached[0]).is_equal(1)
	assert_float(GloomSim.flat_dist(td.border.centre, Vector3(30, 0, 4))).is_less(0.5)
	assert_bool(td.beacon_marker.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_beacon_is_refused_without_enough_spirit() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player.lose_spirit(td.player.spirit - (Config.BEACON_SPIRIT_COST - 5.0))
	var before := td.player.spirit
	await _press_e(runner, td, Vector3(8, 0, 6))
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal_approx(before, 0.3)
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_SPIRIT)
	assert_str(Intro.text_for(td.intro.current)).is_equal("Not enough spirit")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_beacon_is_refused_before_the_border_forms() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	await _press_e(runner, td, Vector3(8, 0, 6))
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal_approx(before, 0.3)
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_BORDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_second_beacon_replaces_the_first_and_costs_again() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	await _press_e(runner, td, Vector3(8, 0, 6))
	await runner.simulate_frames(2)
	await _press_e(runner, td, Vector3(-20, 0, -8))
	assert_float(td.border.beacon_pos().x).is_equal_approx(-20.0, 0.6)
	assert_float(before - td.player.spirit).is_equal_approx(2.0 * Config.BEACON_SPIRIT_COST, 1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_beacon_is_clamped_inside_the_map() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	td.border.place_beacon(Vector3(500, 0, -500))
	var lim := Config.BORDER_MAP_LIMIT
	assert_float(td.border.beacon_pos().x).is_equal(lim)
	assert_float(td.border.beacon_pos().z).is_equal(-lim)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_shows_the_beacon() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	td.border.place_beacon(Vector3(10, 0, -10))
	td.minimap.refresh_from(td.ground, td.border, td.people, td.player.global_position, Vector3.ZERO, Vector2(10, 10))
	assert_vector(td.minimap.beacon_pos).is_equal(Vector2(10, -10))
	td.border.beacon_reached.emit()
	td.border._centre_ctl.clear()
	td.minimap.refresh_from(td.ground, td.border, td.people, td.player.global_position, Vector3.ZERO, Vector2(10, 10))
	assert_vector(td.minimap.beacon_pos).is_equal(Vector2.INF)
	await TopDownTestUtil.leave_loaded_scene(td)
