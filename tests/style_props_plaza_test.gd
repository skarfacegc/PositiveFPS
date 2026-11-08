extends GdUnitTestSuite

# 0.3.1 (#48): the plaza props (StyleProps.layout_plaza), the bigger and warmer lamps and benches, and the soft balls
# drawn after the post-process quad. Headless uses a dummy renderer, so these check state and instance counts; the
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
	out.assign(Config.LANDMARK_POSITIONS)
	return out


func _plaza() -> Array[StyleProps.Prop]:
	return StyleProps.layout_plaza(_blocks(), _landmarks(), float(Config.TD_PLAZA_SIZE) * 0.5)


# Props inside the play-zoom frame (34.7 m wide, about 15 m either side deep) round `at`.
func _in_frame(list: Array[StyleProps.Prop], at: Vector3) -> int:
	var n := 0
	for p: StyleProps.Prop in list:
		if absf(p.pos.x - at.x) <= 17.3 and absf(p.pos.z - at.z) <= 15.0:
			n += 1
	return n


func test_the_open_plaza_has_props_where_the_night_is_played() -> void:
	var block_props := StyleProps.layout_props(_blocks())
	var plaza := _plaza()
	assert_bool(plaza.size() >= 20).is_true()
	# Diagnosis (#48): the block props alone leave the middle bare; the plaza props fill the frame.
	assert_int(_in_frame(block_props, Vector3.ZERO)).is_equal(0)
	for at: Vector3 in [Vector3.ZERO, Vector3(14.5, 0.0, -14.0), Vector3(-15.0, 0.0, 10.0), Vector3(10.0, 0.0, 15.0)]:
		assert_bool(_in_frame(plaza, at) >= 4).is_true()
	# Lamps and benches both stand in the plaza, away from the buildings, as scenery that blooms by the paint alone.
	var kinds := {}
	for p: StyleProps.Prop in plaza:
		kinds[p.kind] = true
		assert_bool(p.plaza).is_true()
		assert_float(p.pos.y).is_equal(0.0)
	assert_bool(kinds.has(StyleProps.Kind.LAMP) and kinds.has(StyleProps.Kind.BENCH)).is_true()


func test_plaza_props_keep_clear_of_blocks_landmarks_the_start_and_the_edge() -> void:
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	for p: StyleProps.Prop in _plaza():
		for c: Vector3 in _blocks():
			assert_float(Vector2(p.pos.x - c.x, p.pos.z - c.z).length()).is_greater_equal(Config.L31_PLAZA_CLEAR)
		for lm: Vector3 in _landmarks():
			assert_float(Vector2(p.pos.x - lm.x, p.pos.z - lm.z).length()).is_greater_equal(Config.L31_PLAZA_CLEAR)
		assert_float(p.pos.length()).is_greater_equal(Config.L31_PLAZA_START_CLEAR)
		assert_float(absf(p.pos.x)).is_less_equal(half - Config.L31_PLAZA_EDGE)
		assert_float(absf(p.pos.z)).is_less_equal(half - Config.L31_PLAZA_EDGE)


func test_the_plaza_layout_is_the_same_every_time() -> void:
	var a := _plaza()
	var b := _plaza()
	assert_int(a.size()).is_equal(b.size())
	for i: int in range(a.size()):
		assert_vector(a[i].pos).is_equal(b[i].pos)
		assert_int(a[i].kind).is_equal(b[i].kind)
		assert_float(a[i].yaw).is_equal(b[i].yaw)
	assert_int(StyleProps.layout_plaza(_blocks(), _landmarks(), 0.0).size()).is_equal(0)
	# A tight lattice (every 4 m) would put spots on the start and at the plaza's edge: those are left out.
	var none: Array[Vector3] = []
	var tight := StyleProps.layout_plaza(none, none, 20.0, 4.0)
	assert_bool(tight.size() > 0).is_true()
	for p: StyleProps.Prop in tight:
		assert_float(p.pos.length()).is_greater_equal(Config.L31_PLAZA_START_CLEAR)
		assert_float(absf(p.pos.x)).is_less_equal(20.0 - Config.L31_PLAZA_EDGE)
		assert_float(absf(p.pos.z)).is_less_equal(20.0 - Config.L31_PLAZA_EDGE)
	assert_bool(tight.size() < 10 * 10).is_true()


func test_plaza_props_are_part_of_the_scene_but_not_its_bench_list() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sp := td.style_props
	var plaza_n := 0
	for p: StyleProps.Prop in sp.props:
		if p.plaza:
			plaza_n += 1
	assert_int(plaza_n).is_equal(_plaza().size())
	assert_int(sp.props.size()).is_equal(TopDownMain.BLOCK_POSITIONS.size() * 4 + plaza_n)
	assert_int(sp.bench_positions().size()).is_equal(TopDownMain.BLOCK_POSITIONS.size())
	# A bare plaza lamp still glows warm (never dark in gloom) and the drawing stays inside the layers' capacity.
	_paint_all(td, 0.0)
	sp.refresh(Config.C7_PROPS_INTERVAL)
	assert_bool(sp.layers.ball_count() >= int(plaza_n * 0.25)).is_true()
	assert_bool(sp.layers.box_count() < StyleProps.BOX_CAPACITY).is_true()
	_paint_all(td, 1.0)
	sp.refresh(Config.C7_BLOOM_SECONDS * 2.0)
	assert_bool(sp.layers.box_count() < StyleProps.BOX_CAPACITY).is_true()
	assert_bool(sp.layers.ball_count() < StyleProps.BALL_CAPACITY).is_true()


func test_lamps_and_benches_are_drawn_bigger_and_warmer_than_the_other_props() -> void:
	assert_float(Config.L31_LAMP_SCALE).is_greater(1.0)
	assert_float(Config.L31_BENCH_SCALE).is_greater(1.0)
	var big := Vector3.ONE * Config.L31_PROP_SCALE * Config.L31_BENCH_SCALE
	assert_vector(StyleProps.bench_big(Vector3.ONE)).is_equal(big)
	var bare := StyleProps.WOOD_BARE
	var warm := StyleProps.WOOD_WARM
	var lifted := StyleProps.tone(bare, warm, 0.0, Config.L31_BENCH_LIFT)
	assert_bool(lifted.r > StyleProps.tone(bare, warm, 0.0).r).is_true()
	assert_float(Config.L31_LAMP_MIN_GLOW).is_greater(0.0)


func test_a_lamp_glows_in_gloom_and_the_soft_balls_draw_after_the_post_process_quad() -> void:
	var parent := Node3D.new()
	var layers := StyleProps.make_layers(parent)
	var sp := StyleProps.new()
	sp.layers = layers
	var lamp := StyleProps._prop(StyleProps.Kind.LAMP, Vector3.ZERO, 0.0, 0)
	layers.begin()
	sp._draw_lamp(lamp, 0.0)
	layers.finish()
	assert_int(layers.box_count()).is_equal(2)
	# The head and the halo are both drawn at bloom 0.
	assert_int(layers.ball_count()).is_equal(2)
	# The soft balls draw after the post-process quad (priority 0), or they are painted over and never seen.
	var ball_mi: MultiMeshInstance3D = parent.get_child(1)
	var ball_mat: BaseMaterial3D = ball_mi.material_override
	assert_int(ball_mat.render_priority).is_equal(Config.L31_SOFT_PRIORITY)
	var box_mi: MultiMeshInstance3D = parent.get_child(0)
	var box_mat: BaseMaterial3D = box_mi.material_override
	assert_int(box_mat.render_priority).is_equal(0)
	sp.free()
	parent.free()
