extends GdUnitTestSuite

# Round 25 (edge cleanup), round 26 (physical push): the border is one ribbon through its members, a real break at
# every gap, coloured and thinned by how far the line is bent (BorderPush.bend_at). The ribbon has no dents of its own:
# the loop and the members really move. Short scenarios, one behaviour each.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# A settled ring of `count` rescued people at radius `r` round the origin (a closed border), at midnight.
func _ring_level(count: int, r: float) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	return {"runner": runner, "td": td}


func _nearest(strips: Array[EdgeStrip], at: Vector2) -> float:
	var best := INF
	for s: EdgeStrip in strips:
		for p: Vector2 in s.pts:
			best = minf(best, p.distance_to(at))
	return best


func test_the_ribbon_is_one_closed_loop_through_every_member() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	assert_int(td.border.gap_count()).is_equal(0)
	var strips := EdgeRibbon.build(td.border)
	assert_int(strips.size()).is_equal(1)
	assert_bool(strips[0].closed).is_true()
	for m: Person in td.border.members:
		assert_float(_nearest(strips, Vector2(m.position.x, m.position.z))).is_less(BorderConfig.EDGE_RIBBON_STEP)
	for p: Vector2 in strips[0].pts:
		assert_float(BorderShape.distance_to_line(td.border.polygon, p)).is_less(1.2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_ribbon_points_are_close_together_and_run_one_way_round() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var pts := EdgeRibbon.build(td.border)[0].pts
	var turned := 0.0
	var centre := Vector2(td.border.centre.x, td.border.centre.z)
	for i: int in range(pts.size()):
		var j := (i + 1) % pts.size()
		assert_float(pts[i].distance_to(pts[j])).is_less_equal(BorderConfig.EDGE_RIBBON_STEP + 0.01)
		turned += wrapf((pts[j] - centre).angle() - (pts[i] - centre).angle(), -PI, PI)
	assert_float(absf(turned)).is_equal_approx(TAU, 0.05)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_ribbon_breaks_where_the_line_broke() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.border.push.dent[td.border.push.sample_of(td.border.members[4].position)] = PushConfig.PUSH_BREAK_DEPTH + 0.4
	await runner.simulate_frames(6)
	assert_int(td.border.gap_count()).is_greater(0)
	var strips := EdgeRibbon.build(td.border)
	assert_int(strips.size()).is_greater(0)
	for strip: EdgeStrip in strips:
		assert_bool(strip.closed).is_false()
	# Nothing is drawn across the break: the ribbon ends well short of its middle.
	for g: Vector3 in td.border.gap_midpoints():
		assert_float(_nearest(strips, Vector2(g.x, g.z))).is_greater(0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_strain_turns_the_ribbon_from_gold_to_amber_to_thin_coral() -> void:
	var gold := EdgeRibbon.colour_for(0.0)
	var amber := EdgeRibbon.colour_for(0.5)
	var coral := EdgeRibbon.colour_for(1.0)
	assert_bool(gold.is_equal_approx(BorderConfig.EDGE_RIBBON_GOLD)).is_true()
	assert_bool(amber.is_equal_approx(BorderConfig.EDGE_RIBBON_AMBER)).is_true()
	assert_bool(coral.is_equal_approx(BorderConfig.EDGE_RIBBON_CORAL)).is_true()
	assert_float(gold.g).is_greater(amber.g)
	assert_float(amber.g).is_greater(coral.g)
	assert_float(EdgeRibbon.width_for(0.0)).is_equal(BorderConfig.EDGE_RIBBON_WIDTH)
	assert_float(EdgeRibbon.width_for(1.0)).is_equal_approx(
		BorderConfig.EDGE_RIBBON_WIDTH * BorderConfig.EDGE_RIBBON_THIN, 0.001
	)
	assert_float(EdgeRibbon.width_for(0.7)).is_between(EdgeRibbon.width_for(1.0), EdgeRibbon.width_for(0.0))
	# A sealed stretch leans toward honey when it is not strained.
	assert_bool(EdgeRibbon.colour_for(0.0, 1.0).is_equal_approx(BorderConfig.EDGE_RIBBON_HONEY)).is_true()


func test_the_strain_of_a_member_is_how_far_the_line_is_bent_there() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[4]
	td.border.push.dent[td.border.push.sample_of(m.position)] = PushConfig.PUSH_BREAK_DEPTH * 0.5
	var strain := EdgeRibbon.strain_map(td.border)
	assert_float(strain[m]).is_equal_approx(0.5, 0.01)
	assert_float(strain[td.border.members[12]]).is_equal(0.0)
	m.wobbling = true
	assert_float(EdgeRibbon.strain_map(td.border)[m]).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_bent_stretch_colours_the_mesh() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	td.border.push.dent[td.border.push.sample_of(m.position)] = PushConfig.PUSH_BREAK_DEPTH * 0.8
	await runner.simulate_frames(3)
	var strips := EdgeRibbon.build(td.border)
	var best := 0.0
	var healthy := 1.0
	var at := Vector2(m.position.x, m.position.z)
	for strip: EdgeStrip in strips:
		for i: int in range(strip.size()):
			var d := strip.pts[i].distance_to(at)
			if d < 0.5:
				best = maxf(best, strip.strain[i])
			elif d > 8.0:
				healthy = minf(healthy, strip.strain[i])
	assert_float(best).is_between(0.4, 1.0)
	assert_float(healthy).is_equal(0.0)
	var arrays := EdgeRibbon.mesh_arrays(strips, 0.1, 1.0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var least_green := 1.0
	for c: Color in cols:
		least_green = minf(least_green, c.g)
	assert_float(least_green).is_less(BorderConfig.EDGE_RIBBON_GOLD.g - 0.1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_ribbon_with_nothing_to_join_has_no_strips() -> void:
	var border: Border = auto_free(Border.new())
	assert_int(EdgeRibbon.build(border).size()).is_equal(0)
	assert_int(EdgeRibbon.mesh_arrays(EdgeRibbon.build(border), 0.1, 1.0).size()).is_equal(0)


func test_both_looks_draw_the_ribbon() -> void:
	for styled: bool in [false, true]:
		Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
		var s: Dictionary = await _ring_level(16, 6.0)
		var td: TopDownMain = s["td"]
		var look := td.border.look
		assert_bool(look.is_styled()).is_equal(styled)
		assert_int(look.strips.size()).is_equal(1)
		var mesh: ArrayMesh = look.get("_mesh")
		assert_int(mesh.get_surface_count()).is_equal(1)
		await TopDownTestUtil.leave_loaded_scene(td)


func test_one_member_or_a_dead_border_has_nothing_to_join() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = BorderShape.circle_polygon(Vector2.ZERO, 5.0, RoundLoopConfig.BORDER_SAMPLES)
	border.active = true
	var one: Person = auto_free(Person.new())
	one.is_rescued = true
	one.position = Vector3(5.0, 0.0, 0.0)
	border.members.append(one)
	assert_int(EdgeRibbon.build(border).size()).is_equal(0)
	# A member who is no longer rescued is left out.
	var two: Person = auto_free(Person.new())
	two.position = Vector3(-5.0, 0.0, 0.0)
	border.members.append(two)
	assert_int(EdgeRibbon._ordered(border).size()).is_equal(1)


func test_a_strip_of_one_point_draws_nothing() -> void:
	var s := EdgeStrip.new()
	s.add(Vector2.ZERO, 0.0, 0.0, 1.0)
	var strips: Array[EdgeStrip] = [s]
	assert_int(EdgeRibbon.mesh_arrays(strips, 0.1, 1.0).size()).is_equal(0)
