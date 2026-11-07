extends GdUnitTestSuite

# Round 25, edge cleanup: the border is one ribbon through its members (a real break at every gap), strain colours it,
# pressing dimmed people bow it inward, trouble spots get one marker each (at most four, worst first, no marker for a
# gap that has only just opened), dimmed people outside are drawn faded, and the patch, burst and lift marks replace
# each other instead of stacking. Visuals only: nothing here changes a rule.


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
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	return {"runner": runner, "td": td}


func _nearest(strips: Array[EdgeStrip], at: Vector2) -> float:
	var best := INF
	for s: EdgeStrip in strips:
		for p: Vector2 in s.pts:
			best = minf(best, p.distance_to(at))
	return best


func _none() -> PackedVector2Array:
	return PackedVector2Array()


func _marker(kind: int, x: float, severity: float) -> EdgeMarkers.Marker:
	return EdgeMarkers.Marker.new(kind, Vector3(x, 0.0, 0.0), severity)


# --- The ribbon ----------------------------------------------------------------------------------------------------


func test_the_ribbon_is_one_closed_loop_through_every_member() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	assert_int(td.border.gap_count()).is_equal(0)
	var strips := EdgeRibbon.build(td.border, _none())
	assert_int(strips.size()).is_equal(1)
	assert_bool(strips[0].closed).is_true()
	# Every member stands on the ribbon, and the ribbon keeps to the loop.
	for m: Person in td.border.members:
		assert_float(_nearest(strips, Vector2(m.position.x, m.position.z))).is_less(Config.EDGE_RIBBON_STEP)
	for p: Vector2 in strips[0].pts:
		assert_float(BorderShape.distance_to_line(td.border.polygon, p)).is_less(1.2)
	# The points are close together (a dent can bend them) and run in the loop's order: the angle round the centre only
	# ever advances one way.
	var pts := strips[0].pts
	var turned := 0.0
	var centre := Vector2(td.border.centre.x, td.border.centre.z)
	for i: int in range(pts.size()):
		var j := (i + 1) % pts.size()
		assert_float(pts[i].distance_to(pts[j])).is_less_equal(Config.EDGE_RIBBON_STEP + 0.01)
		turned += wrapf((pts[j] - centre).angle() - (pts[i] - centre).angle(), -PI, PI)
	assert_float(absf(turned)).is_equal_approx(TAU, 0.05)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_ribbon_breaks_at_a_gap() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	m.joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION - 0.05)
	await runner.simulate_frames(20)
	assert_int(td.border.gap_count()).is_greater(0)
	var strips := EdgeRibbon.build(td.border, _none())
	assert_int(strips.size()).is_greater(0)
	for strip: EdgeStrip in strips:
		assert_bool(strip.closed).is_false()
	# Nothing is drawn across the gap: the ribbon ends well short of its middle.
	for g: Vector3 in td.border.gap_midpoints():
		assert_float(_nearest(strips, Vector2(g.x, g.z))).is_greater(0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_strain_turns_the_ribbon_from_gold_to_amber_to_thin_coral() -> void:
	var gold := EdgeRibbon.colour_for(0.0)
	var amber := EdgeRibbon.colour_for(0.5)
	var coral := EdgeRibbon.colour_for(1.0)
	assert_bool(gold.is_equal_approx(Config.EDGE_RIBBON_GOLD)).is_true()
	assert_bool(amber.is_equal_approx(Config.EDGE_RIBBON_AMBER)).is_true()
	assert_bool(coral.is_equal_approx(Config.EDGE_RIBBON_CORAL)).is_true()
	assert_float(gold.g).is_greater(amber.g)
	assert_float(amber.g).is_greater(coral.g)
	assert_float(EdgeRibbon.width_for(0.0)).is_equal(Config.EDGE_RIBBON_WIDTH)
	assert_float(EdgeRibbon.width_for(1.0)).is_equal_approx(Config.EDGE_RIBBON_WIDTH * Config.EDGE_RIBBON_THIN, 0.001)
	assert_float(EdgeRibbon.width_for(0.7)).is_between(EdgeRibbon.width_for(1.0), EdgeRibbon.width_for(0.0))
	# A sealed stretch leans toward honey when it is not strained.
	assert_bool(EdgeRibbon.colour_for(0.0, 1.0).is_equal_approx(Config.EDGE_RIBBON_HONEY)).is_true()


func test_a_strained_member_colours_its_stretch_of_the_ribbon() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	m.joy = m.joy_needed() * (Config.BORDER_WARN_START + Config.MEMBER_FALTER_FRACTION) * 0.5
	await runner.simulate_frames(10)
	assert_int(td.border.gap_count()).is_equal(0)
	var strips := EdgeRibbon.build(td.border, _none())
	var best := -1.0
	var healthy := 1.0
	var at := Vector2(m.position.x, m.position.z)
	for strip: EdgeStrip in strips:
		for i: int in range(strip.size()):
			var d := strip.pts[i].distance_to(at)
			if d < 0.3:
				best = maxf(best, strip.strain[i])
			elif d > 8.0:
				healthy = minf(healthy, strip.strain[i])
	assert_float(best).is_between(0.3, 0.7)
	assert_float(healthy).is_equal(0.0)
	# The mesh carries it: some vertex is no longer gold.
	var arrays := EdgeRibbon.mesh_arrays(strips, 0.1, 1.0)
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var least_green := 1.0
	for c: Color in cols:
		least_green = minf(least_green, c.g)
	assert_float(least_green).is_less(Config.EDGE_RIBBON_GOLD.g - 0.1)
	await TopDownTestUtil.leave_loaded_scene(td)


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


# --- Dents ---------------------------------------------------------------------------------------------------------


func test_a_pressed_stretch_bows_inward_and_a_harder_push_bows_deeper() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var centre := Vector2(td.border.centre.x, td.border.centre.z)
	var flat := EdgeRibbon.build(td.border, _none())
	var m: Person = td.border.members[3]
	var member_at := m.position
	var out := (Vector2(m.position.x, m.position.z) - centre).normalized()
	var near := PackedVector2Array([Vector2(m.position.x, m.position.z) + out * 0.8])
	var far := PackedVector2Array([Vector2(m.position.x, m.position.z) + out * 2.6])
	var crowd := PackedVector2Array(
		[near[0], near[0] + out.orthogonal() * 0.7, near[0] - out.orthogonal() * 0.7, near[0] + out * 0.3]
	)
	var dented := EdgeRibbon.build(td.border, near)
	var weak := EdgeRibbon.build(td.border, far)
	var big := EdgeRibbon.build(td.border, crowd)
	var flat_pts := flat[0].pts
	assert_int(dented[0].size()).is_equal(flat_pts.size())
	var deepest := 0.0
	var deepest_weak := 0.0
	var deepest_crowd := 0.0
	var worst_outward := 0.0
	for i: int in range(flat_pts.size()):
		var before := flat_pts[i].distance_to(centre)
		var shift := before - dented[0].pts[i].distance_to(centre)
		deepest = maxf(deepest, shift)
		worst_outward = maxf(worst_outward, -shift)
		deepest_weak = maxf(deepest_weak, before - weak[0].pts[i].distance_to(centre))
		deepest_crowd = maxf(deepest_crowd, before - big[0].pts[i].distance_to(centre))
	assert_float(deepest).is_greater(0.3)
	assert_float(deepest).is_less_equal(Config.EDGE_DENT_MAX + 0.01)
	assert_float(worst_outward).is_less(0.05)  # Nothing is ever pushed outward.
	assert_float(deepest_weak).is_less(deepest)
	assert_float(deepest_crowd).is_greater(deepest)
	# The depth is kept on the strip, and drawn offset only: no member moved.
	var recorded := 0.0
	for depth: float in dented[0].dent:
		recorded = maxf(recorded, depth)
	assert_float(recorded).is_equal_approx(deepest, 0.05)
	assert_vector(m.position).is_equal(member_at)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_only_dimmed_people_outside_and_close_press_on_the_ribbon() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	TopDownTestUtil.open_dim_gate(td)
	var m: Person = td.border.members[3]
	var out := Vector3(m.position.x - td.border.centre.x, 0.0, m.position.z - td.border.centre.z).normalized()
	var outside: Person = td.people[20]
	var inside: Person = td.people[21]
	var distant: Person = td.people[22]
	TopDownTestUtil.place(outside, m.position + out * 1.2, 1, 0.95)
	TopDownTestUtil.place(inside, Vector3(0.5, 0.0, 0.5), 1, 0.95)
	TopDownTestUtil.place(distant, m.position + out * 15.0, 1, 0.95)
	var push := EdgeRibbon.pressers(td.border, td.people)
	assert_int(push.size()).is_equal(1)
	assert_float(push[0].distance_to(Vector2(outside.position.x, outside.position.z))).is_less(0.01)
	await runner.simulate_frames(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Markers -------------------------------------------------------------------------------------------------------


func test_at_most_four_markers_and_the_worst_come_first() -> void:
	var troubles: Array[EdgeMarkers.Marker] = [
		_marker(EdgeMarkers.Kind.GIFT, 0.0, 1.0),
		_marker(EdgeMarkers.Kind.STRAIN, 20.0, 0.5),
		_marker(EdgeMarkers.Kind.WOBBLE, 40.0, 0.2),
		_marker(EdgeMarkers.Kind.GAP, 60.0, 0.1),
		_marker(EdgeMarkers.Kind.STRAIN, 80.0, 0.9),
		_marker(EdgeMarkers.Kind.GAP, 100.0, 0.8),
	]
	var picked := EdgeMarkers.pick(troubles)
	assert_int(Config.EDGE_MARKER_MAX).is_equal(4)
	assert_int(picked.size()).is_equal(4)
	# Priority gap > wobble > strain > gift, and the more severe first within a kind: the gift and the milder strain go.
	var kinds: Array[int] = []
	for p: EdgeMarkers.Marker in picked:
		kinds.append(p.kind)
	assert_array(kinds).is_equal(
		[EdgeMarkers.Kind.GAP, EdgeMarkers.Kind.GAP, EdgeMarkers.Kind.WOBBLE, EdgeMarkers.Kind.STRAIN]
	)
	assert_float(picked[0].severity).is_equal(0.8)
	assert_float(picked[3].severity).is_equal(0.9)


func test_priority_order_is_gap_then_wobble_then_strain_then_gift() -> void:
	assert_bool(EdgeMarkers.Kind.GAP > EdgeMarkers.Kind.WOBBLE).is_true()
	assert_bool(EdgeMarkers.Kind.WOBBLE > EdgeMarkers.Kind.STRAIN).is_true()
	assert_bool(EdgeMarkers.Kind.STRAIN > EdgeMarkers.Kind.GIFT).is_true()
	var shuffled: Array[EdgeMarkers.Marker] = [
		_marker(EdgeMarkers.Kind.GIFT, 0.0, 1.0),
		_marker(EdgeMarkers.Kind.GAP, 30.0, 0.0),
		_marker(EdgeMarkers.Kind.STRAIN, 60.0, 1.0),
		_marker(EdgeMarkers.Kind.WOBBLE, 90.0, 0.0),
	]
	var picked := EdgeMarkers.pick(shuffled)
	assert_int(picked.size()).is_equal(4)
	assert_int(picked[0].kind).is_equal(EdgeMarkers.Kind.GAP)
	assert_int(picked[1].kind).is_equal(EdgeMarkers.Kind.WOBBLE)
	assert_int(picked[2].kind).is_equal(EdgeMarkers.Kind.STRAIN)
	assert_int(picked[3].kind).is_equal(EdgeMarkers.Kind.GIFT)


func test_troubles_on_the_same_stretch_merge_into_the_worst() -> void:
	var troubles: Array[EdgeMarkers.Marker] = [
		_marker(EdgeMarkers.Kind.STRAIN, 1.0, 0.9),
		_marker(EdgeMarkers.Kind.GAP, 0.0, 0.2),
		_marker(EdgeMarkers.Kind.GIFT, 2.5, 0.5),
		_marker(EdgeMarkers.Kind.STRAIN, Config.EDGE_MARKER_MERGE + 6.0, 0.5),
	]
	var picked := EdgeMarkers.pick(troubles)
	assert_int(picked.size()).is_equal(2)
	assert_int(picked[0].kind).is_equal(EdgeMarkers.Kind.GAP)
	assert_int(picked[0].count).is_equal(3)
	assert_vector(picked[0].pos).is_equal(Vector3.ZERO)
	assert_int(picked[1].kind).is_equal(EdgeMarkers.Kind.STRAIN)
	assert_float(EdgeMarkers.radius_of(picked[0])).is_greater(Config.EDGE_MARKER_RADIUS_GAP)


func test_a_gap_open_less_than_half_a_second_gets_no_marker() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var none: Array[Dictionary] = []
	var m: Person = td.border.members[4]
	m.joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION - 0.05)
	await runner.simulate_frames(20)
	assert_int(td.border.gap_count()).is_greater(0)
	var age: float = td.border.gap_urgencies().max() * Config.GAP_URGENCY_SECONDS
	assert_float(age).is_less(Config.EDGE_GAP_MIN_AGE)
	for t: EdgeMarkers.Marker in EdgeMarkers.choose(td.border, td.people, none):
		assert_int(t.kind).is_not_equal(EdgeMarkers.Kind.GAP)
	# It stays open: after half a second it gets its marker.
	await runner.simulate_frames(30)
	assert_int(td.border.gap_count()).is_greater(0)
	var gaps := 0
	for t: EdgeMarkers.Marker in EdgeMarkers.choose(td.border, td.people, none):
		gaps += 1 if t.kind == EdgeMarkers.Kind.GAP else 0
	assert_int(gaps).is_greater(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_markers_in_the_level_are_few_and_drawn_once_each() -> void:
	for styled: bool in [false, true]:
		Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
		var s: Dictionary = await _ring_level(16, 6.0)
		var td: TopDownMain = s["td"]
		var runner: GdUnitSceneRunner = s["runner"]
		# Six members drained at once: many troubles, at most four markers.
		for i: int in range(6):
			td.border.members[i * 2].joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION + 0.02)
		await runner.simulate_frames(30)
		var shown := td.gap_patch.markers_fx.shown_count()
		assert_int(shown).is_greater(0)
		assert_int(shown).is_less_equal(Config.EDGE_MARKER_MAX)
		assert_int(td.gap_patch.markers.size()).is_equal(shown)
		assert_bool(td.gap_patch.markers_fx.is_styled_built()).is_equal(styled)
		await TopDownTestUtil.leave_loaded_scene(td)


# --- Short effects -------------------------------------------------------------------------------------------------


func test_a_new_patch_burst_or_lift_mark_replaces_one_at_the_same_spot() -> void:
	var fx := PatchFx.new()
	add_child(fx)
	var patches: Array[Dictionary] = []
	fx.add_patch_result(Vector3(5, 0, 5), 2)
	fx.add_patch_result(Vector3(5.5, 0, 5), 3)
	assert_int(fx.pulse_count()).is_equal(1)
	assert_int(fx.result_text_count()).is_equal(1)
	fx.add_patch_result(Vector3(5, 0, 5.0 + Config.EDGE_FX_MERGE + 1.0), 4)
	assert_int(fx.pulse_count()).is_equal(2)
	assert_int(fx.result_text_count()).is_equal(2)
	var cleared: Array = [{"person": null, "from": Vector3(0, 0, 0), "to": Vector3(10, 0, 0)}]
	fx.add_lift_result(cleared)
	fx.add_lift_result(cleared)
	assert_int(fx.halo_count()).is_equal(1)
	assert_int(fx.result_text_count()).is_equal(3)
	fx.add_burst(cleared)
	fx.add_burst(cleared)
	fx.sync(0.016, patches)
	assert_int(fx.streak_count()).is_equal(1)
	# Two people of one burst that land side by side are both kept.
	var pair: Array = [
		{"person": null, "from": Vector3(0, 0, 0), "to": Vector3(30, 0, 0)},
		{"person": null, "from": Vector3(0, 0, 1), "to": Vector3(30.5, 0, 0)},
	]
	fx.add_lift_result(pair)
	fx.add_burst(pair)
	fx.sync(0.016, patches)
	assert_int(fx.halo_count()).is_equal(3)
	assert_int(fx.streak_count()).is_equal(3)
	fx.free()


func test_the_effects_are_short_and_no_light_column_is_left() -> void:
	assert_float(Config.BURST_FX_SECONDS).is_less_equal(0.6)
	assert_float(Config.FX_HALO_SECONDS).is_less_equal(1.0)
	assert_float(Config.FX_PATCH_PULSE_SECONDS).is_less_equal(0.6)
	assert_float(Config.FX_TEXT_SECONDS).is_less_equal(1.1)
	assert_float(Config.SPARE_GLOW_SECONDS).is_less_equal(1.5)
	# Styled marks are flat dithered rings: no node of the fight marks stands taller than a person.
	Looks.set_mode(Looks.Mode.STYLED)
	var fx := PatchFx.new()
	add_child(fx)
	var cleared: Array = [{"person": null, "from": Vector3(0, 0, 0), "to": Vector3(10, 0, 0)}]
	fx.add_lift_result(cleared)
	var patches: Array[Dictionary] = [{"pos": Vector3(3, 0, 3), "left": Config.PATCH_SECONDS}]
	fx.sync(0.016, patches)
	for child: Node in fx.get_children():
		if child is MeshInstance3D:
			var node := child as MeshInstance3D
			assert_float(node.mesh.get_aabb().size.y * node.scale.y).is_less(0.5)
	fx.free()


# --- Outside dimmed people -----------------------------------------------------------------------------------------


func _distance_from_ground(col: Color) -> float:
	return (
		absf(col.r - Config.EDGE_OUT_GROUND.r)
		+ absf(col.g - Config.EDGE_OUT_GROUND.g)
		+ absf(col.b - Config.EDGE_OUT_GROUND.b)
	)


func test_dimmed_people_outside_the_border_are_drawn_at_lower_contrast() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	TopDownTestUtil.open_dim_gate(td)
	var outside: Person = td.people[20]
	var inside: Person = td.people[21]
	TopDownTestUtil.place(outside, Vector3(14.0, 0.0, 0.0), 1, 0.95)
	TopDownTestUtil.place(inside, Vector3(0.5, 0.0, 0.5), 1, 0.95)
	assert_bool(EdgeDim.is_faded(td.border, outside)).is_true()
	assert_bool(EdgeDim.is_faded(td.border, inside)).is_false()
	assert_bool(EdgeDim.is_faded(td.border, td.border.members[0])).is_false()
	EdgeDim.update(td.border, td.people, Config.EDGE_OUT_FADE_SECONDS * 2.0)
	assert_float(outside.look.outside_fade).is_equal(1.0)
	assert_float(inside.look.outside_fade).is_equal(0.0)
	var look := outside.look as PersonLookPlaceholder
	look.outside_fade = 0.0
	look.sync()
	var plain := _distance_from_ground(look.body_mat.albedo_color)
	look.outside_fade = 1.0
	look.sync()
	var faded := _distance_from_ground(look.body_mat.albedo_color)
	assert_float(faded).is_less(plain)
	# It comes in over EDGE_OUT_FADE_SECONDS, not at once, and goes again when they cross the line.
	look.outside_fade = 0.0
	EdgeDim.update(td.border, td.people, Config.EDGE_OUT_FADE_SECONDS * 0.5)
	assert_float(look.outside_fade).is_equal_approx(0.5, 0.01)
	TopDownTestUtil.place(outside, Vector3(1.0, 0.0, 1.0), 1, 0.95)
	EdgeDim.update(td.border, td.people, Config.EDGE_OUT_FADE_SECONDS * 2.0)
	assert_float(look.outside_fade).is_equal(0.0)
	await runner.simulate_frames(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_look_tints_a_faded_dimmed_person_toward_the_ground() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	TopDownTestUtil.open_dim_gate(td)
	var outside: Person = td.people[20]
	TopDownTestUtil.place(outside, Vector3(14.0, 0.0, 0.0), 1, 0.95)
	outside.tick(0.016)
	var look := outside.look as PersonLookStyled
	assert_int(look.shown_kind()).is_equal(PersonLook.Kind.DIMMED)
	look.outside_fade = 1.0
	look.sync()
	var mesh: MeshInstance3D = look._light_meshes[PersonLook.Kind.DIMMED][0]
	var packed: float = mesh.get_instance_shader_parameter("tint")
	assert_int(floori(packed)).is_equal(3)
	assert_float(packed - 3.0).is_greater(0.3)
	look.outside_fade = 0.0
	look.sync()
	assert_float(mesh.get_instance_shader_parameter("tint")).is_less(3.0)
	await TopDownTestUtil.leave_loaded_scene(td)
