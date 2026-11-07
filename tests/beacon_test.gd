extends GdUnitTestSuite

# Round 19: the spirit beacon. Without a beacon the border's centre stays anchored; E places a beacon for spirit and the
# zone stretches toward it (round 20: a tip reaches out, holds, then snaps back).

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


# Moves the cursor over the ground point `spot`, then presses and releases E (hold to aim, release to place: the
# beacon goes down on the release). simulate_key_pressed sends the press and the release.
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
	# One press and one release: one beacon, one charge.
	assert_float(before - td.player.spirit).is_equal_approx(Config.BEACON_SPIRIT_COST, 0.5)
	assert_bool(td.beacon_marker.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_tip_stretches_toward_the_beacon_at_the_pull_speed_and_the_centre_stays() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var c0 := td.border.centre
	td.border.place_beacon(Vector3(30, 0, 4))
	var tip0: Vector3 = td.border.stretch_info()["tip"]
	await runner.simulate_frames(30)
	var info: Dictionary = td.border.stretch_info()
	var tip1: Vector3 = info["tip"]
	var moved := GloomSim.flat_dist(tip1, tip0)
	print("PROBE tip travel in 0.5 s = %.2f m (speed %.2f m/s)" % [moved, Config.BEACON_PULL_SPEED])
	assert_float(moved).is_equal_approx(Config.BEACON_PULL_SPEED * 0.5, 0.06)
	assert_bool(td.border.has_beacon()).is_true()
	assert_float(GloomSim.flat_dist(td.border.centre, c0)).is_less(0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


# Merged: covers "the zone covers ground toward the tip that the circle did not" (checked at 900 frames) and "the reach
# never squeezes the body below its minimum and the loop keeps its length" (pure checks first, the body radius at 1000
# frames). Both place the same beacon after the same 180 frames.
func test_the_zone_covers_ground_toward_the_tip_without_squeezing_the_body_below_its_minimum() -> void:
	for people: int in [3, 6, 12, 30, 52]:
		var radius := BorderCentre.circle_radius(people)
		var far_reach := BorderCentre.feasible_distance(radius)
		var body_min := radius * Config.BEACON_BODY_MIN
		var hull := BorderCentre.hull_perimeter(body_min, Config.BEACON_TIP_WIDTH * body_min, far_reach)
		assert_float(hull).is_equal_approx(TAU * radius, TAU * radius * 0.01)
		assert_float(far_reach).is_greater(radius)
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(180)
	var c := td.border.centre
	var far := c + Vector3(1.0, 0.0, 0.0) * (BorderCentre.circle_radius(6) + 3.0)
	assert_float(td.border.cover_at(far)).is_equal(0.0)
	var r0 := td.border._mean_radius()
	td.border.place_beacon(c + Vector3(60, 0, 0))
	await runner.simulate_frames(900)
	assert_bool(td.border.polygon.is_empty()).is_false()
	assert_float(td.border.cover_at(far)).is_greater(0.0)
	var tip: Vector3 = td.border.stretch_info()["tip"]
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(tip.x - 1.0, tip.z), td.border.polygon)).is_true()
	# The body stays round the old centre: the point just behind the centre is still inside.
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(c.x - 1.0, c.z), td.border.polygon)).is_true()
	await runner.simulate_frames(100)
	var cx := Vector2(td.border.centre.x, td.border.centre.z)
	var back := INF
	for pt: Vector2 in td.border.polygon:
		back = minf(back, pt.distance_to(cx))
	print("PROBE body radius before %.2f m, smallest during the stretch %.2f m" % [r0, back])
	# Round 23: was * 0.5, with BEACON_BODY_MIN at 0.6.
	assert_float(back).is_greater(BorderCentre.circle_radius(6) * Config.BEACON_BODY_MIN)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_tip_stops_at_the_maximum_reach_and_its_arm_stays_with_no_snap() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var grown: Array[float] = []
	var reached: Array[int] = [0]
	td.border.zone_grew.connect(func(gain: float, _tip: Vector3, _ang: float) -> void: grown.append(gain))
	td.border.beacon_reached.connect(func() -> void: reached[0] += 1)
	var c0 := td.border.centre
	td.border.place_beacon(c0 + Vector3(60, 0, 0))
	var limit: float = td.border.stretch_info()["max"]
	await runner.simulate_frames(1200)  # 20 s: the tip has arrived
	assert_int(reached[0]).is_equal(1)
	assert_int(grown.size()).is_equal(1)
	assert_float(grown[0]).is_greater(0.0)
	assert_bool(td.border.has_beacon()).is_false()
	assert_bool(td.border.stretch_info()["on"]).is_false()
	assert_bool(td.border.stretch_info()["arms"]).is_true()
	assert_bool(td.beacon_marker.visible).is_false()
	# The centre never moves, and 30 s later the arm is still part of the zone (no snap to a circle).
	await runner.simulate_frames(1800)
	assert_float(GloomSim.flat_dist(td.border.centre, c0)).is_less(0.01)
	var cx := Vector2(td.border.centre.x, td.border.centre.z)
	var hi := 0.0
	for pt: Vector2 in td.border.polygon:
		hi = maxf(hi, pt.distance_to(cx))
	assert_float(hi).is_equal_approx(limit, 1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_beacon_nearer_than_the_reach_stops_the_tip_at_the_beacon() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var c0 := td.border.centre
	var arrived: Array[Vector3] = []
	td.border.zone_grew.connect(func(_g: float, tip: Vector3, _a: float) -> void: arrived.append(tip))
	td.border.place_beacon(c0 + Vector3(0, 0, 9))
	await runner.simulate_frames(600)
	assert_int(arrived.size()).is_equal(1)
	assert_float(GloomSim.flat_dist(arrived[0], c0 + Vector3(0, 0, 9))).is_less(0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_reach_grows_with_the_people_rescued() -> void:
	assert_float(BorderCentre.reach_beyond(20)).is_greater(BorderCentre.reach_beyond(10))
	assert_float(BorderCentre.reach_beyond(10) - BorderCentre.reach_beyond(5)).is_equal_approx(
		Config.BEACON_REACH_PER_PERSON * 5.0, 0.001
	)
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.border.place_beacon(td.border.centre + Vector3(60, 0, 0))
	var few: float = td.border.stretch_info()["max"]
	for j: int in range(6):
		var p: Person = td.people[20 + j]
		TopDownTestUtil.place(p, td.border.centre + Vector3(2.0 + float(j), 0.0, -3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(10)
	var many: float = td.border.stretch_info()["max"]
	print("PROBE max reach with 6 people %.1f m, with 12 people %.1f m" % [few, many])
	assert_float(many).is_greater(few + 3.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_new_beacon_during_a_stretch_turns_the_tip_from_where_it_is() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var starts: Array[int] = [0]
	td.border.stretch_started.connect(func(_b: Vector3, _t: Vector3) -> void: starts[0] += 1)
	var c0 := td.border.centre
	td.border.place_beacon(c0 + Vector3(60, 0, 0))
	await runner.simulate_frames(30)
	var before: Vector3 = td.border.stretch_info()["tip"]
	td.border.place_beacon(c0 + Vector3(0, 0, 60))
	assert_int(starts[0]).is_equal(2)
	var now: Vector3 = td.border.stretch_info()["tip"]
	assert_float(GloomSim.flat_dist(now, before)).is_less(0.01)
	await runner.simulate_frames(120)
	var after: Vector3 = td.border.stretch_info()["tip"]
	assert_float(after.z - c0.z).is_greater(0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_hull_is_a_teardrop_from_the_tip_to_the_body() -> void:
	var body := 10.0
	var width := 4.0
	var reach := 25.0
	assert_float(BorderCentre.hull_radius(body, width, reach, 0.0)).is_equal_approx(reach, 0.001)
	assert_float(BorderCentre.hull_radius(body, width, reach, PI)).is_equal(0.0)
	var last := reach
	for k: int in range(1, 40):
		var r := BorderCentre.hull_radius(body, width, reach, float(k) * 0.02)
		if r == 0.0:
			break
		assert_float(r).is_less_equal(last + 0.0001)
		assert_float(r).is_greater_equal(body - 0.001)
		last = r
	# No tip beyond the body: no stretch.
	assert_float(BorderCentre.hull_radius(body, width, 9.0, 0.0)).is_equal(0.0)


func test_the_reach_guide_draws_in_the_placeholder_look_and_hides_in_the_styled_look() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.border.place_beacon(td.border.centre + Vector3(60, 0, 0))
	await runner.simulate_frames(30)
	var mesh: ImmediateMesh = td.reach_guide._mesh
	assert_int(mesh.get_surface_count()).is_equal(1)
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	assert_int(mesh.get_surface_count()).is_equal(0)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(3)
	assert_int(mesh.get_surface_count()).is_equal(1)
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


func test_a_beacon_is_refused_once_the_round_is_over() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var before := td.player.spirit
	td.running = false
	assert_bool(td.try_place_beacon()).is_false()
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal(before)
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
