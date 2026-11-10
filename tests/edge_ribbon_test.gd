extends GdUnitTestSuite

# Round 25 (edge cleanup), round 26 (physical push), 0.4 (#56): the border drawn as ribbons that follow the traced
# line point by point (a wall honey, a gate gold), a real break at every gap, coloured and thinned by how far the gate
# is bent (BorderPush.bend_of_point). The ribbon has no dents of its own: the line really moves, and the ribbon follows.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# A settled start square: 16 rescued people, four to a gate, at midnight.
func _level() -> Dictionary:
	return await TopDownTestUtil.settled_level(self, 16)


func _nearest(strips: Array[EdgeStrip], at: Vector2) -> float:
	var best := INF
	for s: EdgeStrip in strips:
		for p: Vector2 in s.pts:
			best = minf(best, p.distance_to(at))
	return best


func test_the_ribbon_is_one_closed_loop_along_the_line_through_every_member() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.border.member_count).is_equal(16)
	var strips := EdgeRibbon.build(td.border)
	assert_int(strips.size()).is_equal(1)
	assert_bool(strips[0].closed).is_true()
	for m: Person in td.border.members:
		assert_float(_nearest(strips, Vector2(m.position.x, m.position.z))).is_less(BorderConfig.EDGE_RIBBON_STEP + 0.5)
	for p: Vector2 in strips[0].pts:
		assert_float(BorderShape.distance_to_line(td.border.polygon, p)).is_less(0.05)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_ribbon_points_are_close_together_and_run_one_way_round() -> void:
	var s: Dictionary = await _level()
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


func test_the_ribbon_breaks_where_the_gate_broke() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	td.border.push.dent[td.border.push.sample_of(m.position)] = PushConfig.PUSH_BREAK_DEPTH + 0.4
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
	# A wall leans toward honey when it is not strained.
	assert_bool(EdgeRibbon.colour_for(0.0, 1.0).is_equal_approx(BorderConfig.EDGE_RIBBON_HONEY)).is_true()


func test_the_strain_of_a_member_is_how_far_the_gate_is_bent_there() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[4]
	var far: Person = td.border.members[0]
	for cand: Person in td.border.members:
		if cand.position.distance_to(m.position) > far.position.distance_to(m.position):
			far = cand
	td.border.push.dent[td.border.push.sample_of(m.position)] = PushConfig.PUSH_BREAK_DEPTH * 0.5
	var strain := EdgeRibbon.strain_map(td.border)
	assert_float(strain[m]).is_equal_approx(0.5, 0.01)
	assert_float(strain[far]).is_equal(0.0)
	m.wobbling = true
	assert_float(EdgeRibbon.strain_map(td.border)[m]).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_bent_stretch_colours_the_mesh() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	var idx := td.border.push.sample_of(m.position)
	td.border.push.dent[idx] = PushConfig.PUSH_BREAK_DEPTH * 0.8
	await runner.simulate_frames(3)
	var strips := EdgeRibbon.build(td.border)
	var best := 0.0
	var healthy := 1.0
	var at := td.border.polygon[idx]  # The bent point has moved in; the strip passes through it there.
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


func test_a_wall_is_drawn_honey_and_a_gate_gold() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.zone.take(Vector2i(3, 2))
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border._mark_gaps()
	var strips := EdgeRibbon.build(border)
	assert_int(strips.size()).is_equal(1)
	var most_wall := 0.0
	var least_wall := 1.0
	for i: int in range(strips[0].size()):
		most_wall = maxf(most_wall, strips[0].seal[i])
		least_wall = minf(least_wall, strips[0].seal[i])
	assert_float(most_wall).is_equal(1.0)
	assert_float(least_wall).is_equal(0.0)
	# The middle of the block's far face is wall, the middle of the start square's west side is gate.
	var east_face := Vector2(28.0, 0.0)
	var west_gate := Vector2(-6.0, 0.0)
	for i: int in range(strips[0].size()):
		if strips[0].pts[i].distance_to(east_face) < 0.5:
			assert_float(strips[0].seal[i]).is_equal(1.0)
		if strips[0].pts[i].distance_to(west_gate) < 0.5:
			assert_float(strips[0].seal[i]).is_equal(0.0)


func test_a_ribbon_with_nothing_to_join_has_no_strips() -> void:
	var border: Border = auto_free(Border.new())
	assert_int(EdgeRibbon.build(border).size()).is_equal(0)
	assert_int(EdgeRibbon.mesh_arrays(EdgeRibbon.build(border), 0.1, 1.0).size()).is_equal(0)


func test_both_looks_draw_the_ribbon() -> void:
	for styled: bool in [false, true]:
		Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
		var s: Dictionary = await _level()
		var td: TopDownMain = s["td"]
		var look := td.border.look
		assert_bool(look.is_styled()).is_equal(styled)
		assert_int(look.strips.size()).is_equal(1)
		var mesh: ArrayMesh = look.get("_mesh")
		assert_int(mesh.get_surface_count()).is_equal(1)
		await TopDownTestUtil.leave_loaded_scene(td)


func test_a_strip_of_one_point_draws_nothing() -> void:
	var s := EdgeStrip.new()
	s.add(Vector2.ZERO, 0.0, 0.0, 1.0)
	var strips: Array[EdgeStrip] = [s]
	assert_int(EdgeRibbon.mesh_arrays(strips, 0.1, 1.0).size()).is_equal(0)
