extends GdUnitTestSuite

# 0.3.1 (#48), 0.3.3 (#52): the street props (StyleProps.layout_streets: lamps along the kerbs, stalls on the square;
# layout_props: a bench and planter in front of each block), the bigger and warmer lamps and benches, and the soft
# balls drawn after the post-process quad. Headless uses a dummy renderer, so these check state and instance counts; the
# screenshots check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.set_look(Looks.Mode.STYLED)
	return {"td": td, "runner": runner}


func _paint_all(td: TopDownMain, weight: float) -> void:
	for i: int in range(td.ground._weights.size()):
		td.ground._weights[i] = weight


func _blocks() -> Array[Vector3]:
	var centres: Array[Vector3] = []
	for c: Vector3 in TopDownMain.BLOCK_POSITIONS:
		centres.append(c)
	return centres


func _landmarks() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(LandmarkConfig.LANDMARK_POSITIONS)
	return out


func _plaza() -> Array[StyleProps.Prop]:
	return StyleProps.layout_streets()


# Props inside the play-zoom frame (34.7 m wide, about 15 m either side deep) round `at`.
func _in_frame(list: Array[StyleProps.Prop], at: Vector3) -> int:
	var n := 0
	for p: StyleProps.Prop in list:
		if absf(p.pos.x - at.x) <= 17.3 and absf(p.pos.z - at.z) <= 15.0:
			n += 1
	return n


func test_the_streets_have_props_where_the_night_is_played() -> void:
	var block_props := StyleProps.layout_props(_blocks())
	var plaza := _plaza()
	assert_bool(plaza.size() >= 20).is_true()
	# The lamps along the kerbs and the stalls on the square fill the frame wherever the night is played.
	assert_bool(_in_frame(plaza, Vector3.ZERO) >= 8).is_true()
	assert_bool(_in_frame(block_props, Vector3.ZERO) > 0).is_true()
	for at: Vector3 in [Vector3.ZERO, Vector3(14.5, 0.0, 0.0), Vector3(-15.0, 0.0, 0.0), Vector3(0.0, 0.0, 15.0)]:
		assert_bool(_in_frame(plaza, at) >= 4).is_true()
	# Lamps and stalls stand on the streets, as scenery that blooms by the paint alone.
	var kinds := {}
	for p: StyleProps.Prop in plaza:
		kinds[p.kind] = true
		assert_bool(p.plaza).is_true()
		assert_float(p.pos.y).is_equal(0.0)
	assert_bool(kinds.has(StyleProps.Kind.LAMP) and kinds.has(StyleProps.Kind.STALL)).is_true()


func test_street_props_stand_on_the_streets_clear_of_blocks_landmarks_the_start_and_the_edge() -> void:
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	for p: StyleProps.Prop in _plaza():
		assert_bool(TownLayout.on_street(p.pos, 1.0) or TownLayout.on_square(p.pos)).is_true()
		for c: Vector3 in _blocks():
			var over := absf(p.pos.x - c.x) < 2.0 and absf(p.pos.z - c.z) < 2.0
			assert_bool(over).is_false()
		for lm: Vector3 in _landmarks():
			var on_it := absf(p.pos.x - lm.x) < 2.0 and absf(p.pos.z - lm.z) < 2.0
			assert_bool(on_it).is_false()
		assert_float(p.pos.length()).is_greater_equal(TownConfig.TOWN_STALL_OFFSET)
		assert_float(absf(p.pos.x)).is_less_equal(half - TownConfig.TOWN_EDGE_CLEAR)
		assert_float(absf(p.pos.z)).is_less_equal(half - TownConfig.TOWN_EDGE_CLEAR)


func test_lamps_stand_at_regular_spacing_along_the_kerbs_and_stalls_ring_the_square() -> void:
	var lamps := 0
	var stalls := 0
	var along_main: Array[float] = []
	for p: StyleProps.Prop in _plaza():
		if p.kind == StyleProps.Kind.LAMP:
			lamps += 1
			var on_main := is_equal_approx(absf(p.pos.z), TownConfig.TOWN_KERB_OFFSET)
			var on_cross := is_equal_approx(absf(p.pos.x), TownConfig.TOWN_KERB_OFFSET)
			assert_bool(on_main or on_cross).is_true()
			if on_main and p.pos.z > 0.0 and p.pos.x > 0.0:
				along_main.append(p.pos.x)
		else:
			stalls += 1
			# A stall turns toward the start: its local +z points at the middle.
			var toward := Vector3(sin(p.yaw), 0.0, cos(p.yaw))
			assert_float(toward.dot(-p.pos.normalized())).is_greater(0.99)
	assert_int(stalls).is_equal(4)
	assert_int(lamps).is_equal(TownLayout.lamp_spots().size())
	along_main.sort()
	assert_bool(along_main.size() >= 3).is_true()
	for i: int in range(1, along_main.size()):
		assert_float(along_main[i] - along_main[i - 1]).is_equal_approx(TownConfig.TOWN_LAMP_SPACING, 0.001)


func test_each_blocks_bench_and_planter_stand_between_it_and_its_street() -> void:
	var props := StyleProps.layout_props(_blocks())
	assert_int(props.size()).is_equal(_blocks().size() * 2)
	for p: StyleProps.Prop in props:
		var c := _blocks()[p.block]
		var f := TownLayout.facing(c)
		assert_bool(p.kind == StyleProps.Kind.BENCH or p.kind == StyleProps.Kind.PLANTER).is_true()
		assert_bool(p.plaza).is_false()
		# In front of the block's face (toward the street) and still on the pavement side of the street's kerb.
		assert_float((p.pos - Vector3(c.x, 0.0, c.z)).dot(f)).is_greater(2.0)
		assert_bool(TownLayout.on_street(p.pos, 1.0)).is_true()
		# The prop looks toward the street.
		assert_float(Vector3(sin(p.yaw), 0.0, cos(p.yaw)).dot(f)).is_greater(0.99)


func test_the_street_layout_is_the_same_every_time() -> void:
	var a := _plaza()
	var b := _plaza()
	assert_int(a.size()).is_equal(b.size())
	for i: int in range(a.size()):
		assert_vector(a[i].pos).is_equal(b[i].pos)
		assert_int(a[i].kind).is_equal(b[i].kind)
		assert_float(a[i].yaw).is_equal(b[i].yaw)


func test_street_props_are_part_of_the_scene_but_not_its_bench_list() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sp := td.style_props
	var plaza_n := 0
	for p: StyleProps.Prop in sp.props:
		if p.plaza:
			plaza_n += 1
	assert_int(plaza_n).is_equal(_plaza().size())
	assert_int(sp.props.size()).is_equal(TopDownMain.BLOCK_POSITIONS.size() * 2 + plaza_n)
	assert_int(sp.bench_positions().size()).is_equal(TopDownMain.BLOCK_POSITIONS.size())
	# A bare plaza lamp still glows warm (never dark in gloom) and the drawing stays inside the layers' capacity.
	_paint_all(td, 0.0)
	sp.refresh(StyleConfig.C7_PROPS_INTERVAL)
	assert_bool(sp.layers.ball_count() >= int(plaza_n * 0.25)).is_true()
	assert_bool(sp.layers.box_count() < StyleProps.BOX_CAPACITY).is_true()
	_paint_all(td, 1.0)
	sp.refresh(StyleConfig.C7_BLOOM_SECONDS * 2.0)
	assert_bool(sp.layers.box_count() < StyleProps.BOX_CAPACITY).is_true()
	assert_bool(sp.layers.ball_count() < StyleProps.BALL_CAPACITY).is_true()


func test_lamps_and_benches_are_drawn_bigger_and_warmer_than_the_other_props() -> void:
	assert_float(StyleConfig.L31_LAMP_SCALE).is_greater(1.0)
	assert_float(StyleConfig.L31_BENCH_SCALE).is_greater(1.0)
	var big := Vector3.ONE * StyleConfig.L31_PROP_SCALE * StyleConfig.L31_BENCH_SCALE
	assert_vector(StyleProps.bench_big(Vector3.ONE)).is_equal(big)
	var bare := StyleProps.WOOD_BARE
	var warm := StyleProps.WOOD_WARM
	var lifted := StyleProps.tone(bare, warm, 0.0, StyleConfig.L31_BENCH_LIFT)
	assert_bool(lifted.r > StyleProps.tone(bare, warm, 0.0).r).is_true()
	assert_float(StyleConfig.L31_LAMP_MIN_GLOW).is_greater(0.0)


func test_a_lamp_glows_in_gloom_and_the_soft_balls_draw_after_the_post_process_quad() -> void:
	var parent := Node3D.new()
	var layers := StyleProps.make_layers(parent)
	var sp := StyleProps.new()
	sp.layers = layers
	var lamp := StyleProps._prop(StyleProps.Kind.LAMP, Vector3.ZERO, 0.0, 0)
	layers.begin()
	sp._draw_lamp(lamp, 0.0)
	layers.finish()
	assert_bool(layers.box_count() >= 10).is_true()
	# The glass globe and the small glow at the head are both drawn at bloom 0; the light is a cone and a pool.
	assert_int(layers.ball_count()).is_equal(2)
	assert_int(layers.cone_count()).is_equal(0)  # (these layers were made without the light shapes)
	# The soft balls draw after the post-process quad (priority 0), or they are painted over and never seen.
	var ball_mi: MultiMeshInstance3D = parent.get_child(1)
	var ball_mat: BaseMaterial3D = ball_mi.material_override
	assert_int(ball_mat.render_priority).is_equal(StyleConfig.L31_SOFT_PRIORITY)
	var box_mi: MultiMeshInstance3D = parent.get_child(0)
	var box_mat: BaseMaterial3D = box_mi.material_override
	assert_int(box_mat.render_priority).is_equal(0)
	sp.free()
	parent.free()
