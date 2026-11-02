extends GdUnitTestSuite

# Round 21: stretch safety. The round 20 playtest lost its border after a stretch. Reproduced headless (seed 42 level,
# 24 people in a ring, midnight, two dimmed people beyond the beacon, no player): the tip swept over the dimmed, which
# put them INSIDE the border, they drained the members, the head count and the reach fell and the border collapsed (24
# people at the start, 19 after 8 s, 6 after 12 s, 2 after 16 s). With no stretch the same border kept all 24 for 28 s.
# So a stretch now keeps its tip clear of dimmed people, is refused when they leave nothing to gain, and walks back (it
# does not snap) when it can no longer be supported. The preview the guide draws is the same plan the real stretch uses.

const PEOPLE := 24
const CENTRE := Vector3(-11.7, 0.0, -6.5)


func _radius() -> float:
	return float(PEOPLE) * Config.BORDER_TARGET_SPACING / TAU


# A level with a settled border of 24 people round CENTRE at midnight, full spirit, and the dimmed people at `dimmed`
# (offsets from CENTRE) standing still beyond it.
func _setup(dimmed: Array[Vector3] = [], late: bool = false) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	var r := _radius()
	for i: int in range(PEOPLE):
		var a := TAU * float(i) / float(PEOPLE)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = 95.0
	if not late:
		await _place_dimmed(td, runner, dimmed)
	await runner.simulate_frames(900)
	if late:  # Placed after the border has settled, so they have not walked in yet.
		await _place_dimmed(td, runner, dimmed)
		await runner.simulate_frames(20)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td}


func _place_dimmed(td: TopDownMain, runner: GdUnitSceneRunner, dimmed: Array[Vector3]) -> void:
	for k: int in range(dimmed.size()):
		TopDownTestUtil.open_dim_gate(td)
		var q: Person = td.people[PEOPLE + k]
		TopDownTestUtil.place(q, CENTRE + dimmed[k], q.affinity, 1.0)
		await runner.simulate_frames(2)


func _aim(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(4)


func _press_e(runner: GdUnitSceneRunner) -> void:
	runner.simulate_key_pressed(KEY_E)
	await runner.simulate_frames(2)


func _dimmed_inside(td: TopDownMain, first: int, count: int) -> int:
	var inside := 0
	for k: int in range(count):
		var q: Person = td.people[first + k]
		if BorderShape.is_inside(td.border.polygon, Vector2(q.position.x, q.position.z)):
			inside += 1
	return inside


func test_the_seeded_collapse_is_refused_and_the_border_keeps_its_people() -> void:
	var dimmed: Array[Vector3] = [Vector3(-6, 0, 31), Vector3(0, 0, 31)]
	var s: Dictionary = await _setup(dimmed)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var before := td.player.spirit
	await _aim(runner, td, CENTRE + Vector3(0, 0, 25))
	var plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	assert_bool(plan["refused"]).is_true()
	await _press_e(runner)
	assert_bool(td.border.has_beacon()).is_false()
	assert_float(td.player.spirit).is_equal(before)
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_BLOCKED)
	await runner.simulate_frames(900)
	print("PROBE after 15 s: %d of %d rescued" % [td.rescued_count, PEOPLE])
	assert_int(td.rescued_count).is_greater_equal(PEOPLE - 2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_stretch_stops_short_of_a_dimmed_person_and_never_swallows_them() -> void:
	var dimmed: Array[Vector3] = [Vector3(2, 0, 22)]
	var s: Dictionary = await _setup(dimmed, true)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _aim(runner, td, CENTRE + Vector3(0, 0, 26))
	var plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	var why: String = plan["reason"]
	assert_str(why).is_equal(Config.BEACON_DIM_TEXT)
	assert_bool(plan["refused"]).is_false()
	var reach: float = plan["reach"]
	assert_float(reach).is_less(22.0 - Config.BEACON_DIM_CLEARANCE + 0.5)
	assert_float(reach).is_greater(_radius() + Config.BEACON_MIN_GAIN)
	await _press_e(runner)
	assert_bool(td.border.has_beacon()).is_true()
	var worst_inside := 0
	var farthest := 0.0
	# Round 22: the arm now stays. The stretch itself (about 3 s) must not swallow the dimmed person; later, one pressing
	# on the border can drain a member and slip through the gap it opens, as with any border, so watch 9 s.
	for k: int in range(9 * 6):
		await runner.simulate_frames(10)
		worst_inside = maxi(worst_inside, _dimmed_inside(td, PEOPLE, 1))
		var tip: Vector3 = td.border.stretch_info()["tip"]
		farthest = maxf(farthest, GloomSim.flat_dist(tip, CENTRE))
	assert_int(worst_inside).is_equal(0)
	assert_float(farthest).is_less(22.0 - Config.BEACON_DIM_CLEARANCE + 1.5)
	assert_int(td.rescued_count).is_greater_equal(PEOPLE - 2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_clear_path_still_stretches_the_whole_way() -> void:
	var dimmed: Array[Vector3] = [Vector3(0, 0, -34)]  # behind the border, not in the way
	var s: Dictionary = await _setup(dimmed)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _aim(runner, td, CENTRE + Vector3(0, 0, 24))
	var plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	var why: String = plan["reason"]
	assert_str(why).is_equal("")
	assert_float(plan["reach"]).is_equal_approx(24.0, 0.3)
	await _press_e(runner)
	await runner.simulate_frames(1200)
	var tip: Vector3 = td.border.stretch_info()["tip"]
	assert_float(GloomSim.flat_dist(tip, CENTRE)).is_equal_approx(24.0, 0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_stretch_the_dimmed_make_impossible_falls_back_and_keeps_no_arm() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var snaps: Array[int] = [0]
	var reasons: Array[String] = []
	td.border.zone_grew.connect(func(_g: float, _t: Vector3, _a: float) -> void: snaps[0] += 1)
	td.border.stretch_ended.connect(func(why: String) -> void: reasons.append(why))
	var c0 := td.border.centre
	# A dimmed person right outside the border where the stretch would go (placed by hand, so E's own refusal is skipped).
	TopDownTestUtil.open_dim_gate(td)
	var q: Person = td.people[PEOPLE]
	TopDownTestUtil.place(q, CENTRE + Vector3(0, 0, _radius() + 1.0), q.affinity, 1.0)
	await runner.simulate_frames(4)
	td.border.place_beacon(CENTRE + Vector3(0, 0, 25))
	await runner.simulate_frames(10)
	assert_bool(td.border.stretch_info()["on"]).is_false()
	assert_bool(td.border.has_beacon()).is_false()
	assert_int(snaps[0]).is_equal(0)
	assert_int(reasons.size()).is_equal(1)
	assert_str(reasons[0]).is_equal(Config.BEACON_DIM_TEXT)
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_FELL_BACK)
	assert_float(GloomSim.flat_dist(td.border.centre, c0)).is_less(0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_losing_people_walks_the_tip_back_and_the_arm_lands_where_the_tip_is() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var landed: Array[Vector3] = []
	td.border.zone_grew.connect(func(_g: float, tip: Vector3, _a: float) -> void: landed.append(tip))
	td.border.place_beacon(CENTRE + Vector3(0, 0, 26))
	await runner.simulate_frames(200)
	assert_bool(td.border.stretch_info()["on"]).is_true()
	var tip0: Vector3 = td.border.stretch_info()["tip"]
	var far0 := GloomSim.flat_dist(tip0, CENTRE)
	# Ten people are lost.
	for i: int in range(10):
		var p: Person = td.people[i]
		TopDownTestUtil.lose_now(p)
	await runner.simulate_frames(2)
	assert_int(td.rescued_count).is_equal(PEOPLE - 10)
	var limit: float = td.border.stretch_info()["max"]
	assert_float(limit).is_less(far0 + 4.0)
	# One frame later the tip has not jumped: it moves at no more than the pull speed.
	var tip1: Vector3 = td.border.stretch_info()["tip"]
	assert_float(GloomSim.flat_dist(tip0, tip1)).is_less(Config.BEACON_PULL_SPEED / 60.0 * 4.0 + 0.01)
	await runner.simulate_frames(1500)
	if not landed.is_empty():
		assert_float(GloomSim.flat_dist(landed[0], CENTRE)).is_less_equal(limit + 0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_outline_is_a_teardrop_the_length_of_the_circle() -> void:
	var r := _radius()
	var c := Vector2(3.0, -4.0)
	var short := BorderCentre.outline(c, r, r * 0.8, 0.0)
	assert_int(short.size()).is_equal(Config.BORDER_SAMPLES)
	for pt: Vector2 in short:
		assert_float(pt.distance_to(c)).is_equal_approx(r, 0.01)
	for reach: float in [r + 4.0, r + 8.0, BorderCentre.feasible_distance(r)]:
		var ang := 1.1
		var out := BorderCentre.outline(c, r, reach, ang)
		var far := 0.0
		var near := INF
		for pt: Vector2 in out:
			far = maxf(far, pt.distance_to(c))
			near = minf(near, pt.distance_to(c))
		# The tip reaches (to the sampling), the body does not shrink below the minimum, the length stays the circle's.
		assert_float(far).is_equal_approx(reach, reach * 0.04)
		assert_float(near).is_greater_equal(r * Config.BEACON_BODY_MIN - 0.01)
		assert_float(BorderShape.perimeter_of(out)).is_equal_approx(TAU * r, TAU * r * 0.04)


func test_the_preview_matches_the_zone_the_stretch_really_makes() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var aim := CENTRE + Vector3(0, 0, 22)
	var plan: Dictionary = td.border.plan_stretch(aim)
	var outline: PackedVector2Array = plan["outline"]
	var reach: float = plan["reach"]
	var landed: Array[Vector3] = []
	td.border.zone_grew.connect(func(_g: float, tip: Vector3, _a: float) -> void: landed.append(tip))
	td.border.place_beacon(aim)
	await runner.simulate_frames(1000)
	assert_bool(td.border.stretch_info()["on"]).is_false()
	assert_int(landed.size()).is_equal(1)
	assert_float(GloomSim.flat_dist(landed[0], CENTRE)).is_equal_approx(reach, 0.3)
	# Compare the real loop with the preview, ray by ray (both are sampled at the same angles).
	var c2 := Vector2(CENTRE.x, CENTRE.z)
	var poly := td.border.polygon
	assert_int(poly.size()).is_equal(outline.size())
	var total := 0.0
	var worst := 0.0
	for i: int in range(poly.size()):
		var d := absf(poly[i].distance_to(c2) - outline[i].distance_to(c2))
		total += d
		worst = maxf(worst, d)
	var mean := total / float(poly.size())
	print("PROBE preview vs real: mean %.2f m, worst %.2f m (reach %.1f)" % [mean, worst, reach])
	assert_float(mean).is_less(1.0)
	assert_float(worst).is_less(3.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_guide_shows_the_zone_without_words_and_says_stretching_during_a_stretch() -> void:
	var dimmed: Array[Vector3] = [Vector3(2, 0, 22)]
	var s: Dictionary = await _setup(dimmed, true)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	# Round 24: no words while hovering, whether or not something holds the stretch back.
	await _aim(runner, td, CENTRE + Vector3(0, 0, -20))
	await runner.simulate_frames(2)
	assert_bool(td.reach_guide._label == null or not td.reach_guide._label.visible).is_true()
	await _aim(runner, td, CENTRE + Vector3(0, 0, 26))
	await runner.simulate_frames(2)
	var plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	assert_str(plan["reason"]).is_equal(Config.BEACON_DIM_TEXT)
	assert_bool(td.reach_guide._label == null or not td.reach_guide._label.visible).is_true()
	# During a stretch the guide says so.
	await _aim(runner, td, CENTRE + Vector3(0, 0, -20))
	await _press_e(runner)
	await runner.simulate_frames(30)
	assert_bool(td.border.stretch_info()["on"]).is_true()
	assert_str(td.reach_guide._label.text).is_equal("Stretching")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_plan_is_reused_for_a_moment_so_it_costs_little_per_frame() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var aim := CENTRE + Vector3(0, 0, 20)
	var a: Dictionary = td.border.plan_stretch(aim)
	var b: Dictionary = td.border.plan_stretch(aim)
	assert_bool(is_same(a, b)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_reach_guide_draws_nothing_with_a_settled_border_and_no_aim() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	# The level's mouse picks an aim point even with no mouse motion, so clear it: this is the cursor-off-the-ground case.
	td.player._has_aim = false
	assert_bool(td.player.has_aim()).is_false()
	assert_bool(td.border.active).is_true()
	assert_bool(td.border.stretch_info()["on"]).is_false()
	td.reach_guide.sync(td.border, td.player)
	assert_int(td.reach_guide._mesh.get_surface_count()).is_equal(0)
	var label: Label3D = td.reach_guide._label
	assert_bool(label == null or not label.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_zero_length_line_adds_no_geometry_to_the_guide() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var mesh: ImmediateMesh = td.reach_guide._mesh
	# No frame runs between these calls, so the per-frame sync does not touch the mesh under the test.
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	td.reach_guide._line(Vector2(5.0, 5.0), Vector2(5.0, 5.0), 0.3, Color.WHITE)
	td.reach_guide._line(Vector2(0.0, 0.0), Vector2(1.0, 0.0), 0.3, Color.WHITE)
	mesh.surface_end()
	assert_int(mesh.get_surface_count()).is_equal(1)
	# Only the real line is in the bounds: the degenerate one at (5, 5) added nothing.
	assert_float(mesh.get_aabb().end.x).is_less(2.0)
	await TopDownTestUtil.leave_loaded_scene(td)
