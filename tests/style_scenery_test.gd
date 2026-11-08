extends GdUnitTestSuite

# Checkpoint 7: the styled street props (StyleProps) and ambient life (StyleAmbient). Headless uses a dummy renderer, so
# these check state and the instance counts the MultiMeshes were given; the screenshots check the look. The pieces are
# stepped by hand (refresh / step) so no game frames change the state between a setup and its check.


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


func _count_live(list: Array[StyleAmbient.Flyer]) -> int:
	var n := 0
	for f: StyleAmbient.Flyer in list:
		if f.live:
			n += 1
	return n


func test_layout_gives_each_block_its_props_and_lines_without_repeats() -> void:
	var centres: Array[Vector3] = []
	for c: Vector3 in TopDownMain.BLOCK_POSITIONS:
		centres.append(c)
	var props := StyleProps.layout_props(centres)
	assert_int(props.size()).is_equal(centres.size() * 4)
	var lines := StyleProps.layout_lines(centres, Config.C7_LINE_MAX_DIST)
	assert_bool(lines.size() > 0).is_true()
	var seen := {}
	for l: StyleProps.Line in lines:
		var key := Vector2i(mini(l.block_a, l.block_b), maxi(l.block_a, l.block_b))
		assert_bool(seen.has(key)).is_false()
		seen[key] = true
	assert_int(StyleProps.layout_lines(centres, 0.5).size()).is_equal(0)


func test_lines_are_strung_at_roof_height_from_posts_and_never_bare_in_gloom() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sp := td.style_props
	for l: StyleProps.Line in sp.lines:
		assert_float(l.a.y).is_equal_approx(Config.L31_LINE_POST_HEIGHT, 0.001)
		assert_float(l.b.y).is_equal_approx(Config.L31_LINE_POST_HEIGHT, 0.001)
	assert_bool(StyleProps.line_shown(0.0)).is_false()
	assert_bool(StyleProps.line_shown(Config.L31_LINE_SHOW - 0.01)).is_false()
	assert_bool(StyleProps.line_shown(Config.L31_LINE_SHOW)).is_true()
	# In gloom no line is drawn at all: the drawing is the props alone.
	_paint_all(td, 0.0)
	for b: Building in td.border.buildings:
		b.tint = 0.0
	sp.refresh(Config.C7_BLOOM_SECONDS * 2.0)
	for l: StyleProps.Line in sp.lines:
		assert_float(l.unfurl).is_equal(0.0)
	var bare_boxes := sp.layers.box_count()
	var lines := sp.lines.duplicate()
	sp.lines.clear()
	sp.refresh(0.0)
	assert_int(sp.layers.box_count()).is_equal(bare_boxes)
	# Inside the zone every line stands on two posts: at least a post pair, the rope and its flags more than without.
	sp.lines.assign(lines)
	_paint_all(td, 1.0)
	sp.refresh(Config.C7_BLOOM_SECONDS * 2.0)
	var with_lines := sp.layers.box_count()
	assert_bool(with_lines - bare_boxes >= sp.lines.size() * (2 + StyleProps.LINE_PIECES)).is_true()


func test_a_line_rises_on_its_posts_as_the_paint_reaches_it() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sp := td.style_props
	var l: StyleProps.Line = sp.lines[0]
	sp.layers.begin()
	l.unfurl = Config.L31_LINE_SHOW
	sp._draw_line(l, 0)
	assert_bool(sp.layers.box_count() > 0).is_true()
	# Just shown the posts are still on the ground; unfurled they stand at roof height (and draw a taller line).
	assert_float(StyleProps.post_growth(Config.L31_LINE_SHOW)).is_equal(0.0)
	assert_float(StyleProps.post_growth(Config.L31_LINE_SHOW + 0.15)).is_between(0.1, 0.9)
	assert_float(StyleProps.post_growth(1.0)).is_equal(1.0)
	sp.layers.begin()
	l.unfurl = 1.0
	sp._draw_line(l, 0)
	assert_bool(sp.layers.box_count() > 0).is_true()
	sp.layers.begin()
	l.unfurl = Config.L31_LINE_SHOW * 0.5
	sp._draw_line(l, 0)
	assert_int(sp.layers.box_count()).is_equal(0)


func test_props_and_ambient_are_drawn_bigger_so_they_read_at_play_zoom() -> void:
	# The tone helper lifts a bare colour toward the warm one even at bloom 0, and reaches it at full bloom.
	var bare := Color(0.1, 0.1, 0.1)
	var warm := Color(0.9, 0.5, 0.2)
	assert_bool(StyleProps.tone(bare, warm, 0.0).r > bare.r).is_true()
	assert_bool(StyleProps.tone(bare, warm, 0.0).r < warm.r).is_true()
	assert_bool(StyleProps.tone(bare, warm, 1.0).is_equal_approx(warm)).is_true()
	assert_vector(StyleProps.big(Vector3.ONE)).is_equal(Vector3.ONE * Config.L31_PROP_SCALE)
	assert_float(Config.L31_AMBIENT_SCALE).is_greater(1.0)


func test_day_factor_runs_from_night_to_day() -> void:
	assert_float(StyleProps.day_factor(0.35)).is_equal(0.0)
	assert_float(StyleProps.day_factor(1.0)).is_equal(1.0)
	var mid := StyleProps.day_factor(Config.C7_DAY_ENERGY_LOW + Config.C7_DAY_ENERGY_RANGE * 0.5)
	assert_float(mid).is_equal_approx(0.5, 0.001)


func test_props_are_bare_in_gloom_and_bloom_where_the_paint_is() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sp := td.style_props
	_paint_all(td, 0.0)
	for b: Building in td.border.buildings:
		b.tint = 0.0
	sp.refresh(Config.C7_PROPS_INTERVAL)
	for p: StyleProps.Prop in sp.props:
		assert_float(p.bloom).is_equal(0.0)
	var bare_balls := sp.layers.ball_count()
	var bare_boxes := sp.layers.box_count()
	assert_bool(bare_boxes > 0).is_true()
	_paint_all(td, 1.0)
	sp.refresh(Config.C7_BLOOM_SECONDS * 2.0)
	for p: StyleProps.Prop in sp.props:
		assert_float(p.bloom).is_equal(1.0)
	for l: StyleProps.Line in sp.lines:
		assert_float(l.unfurl).is_equal(1.0)
	assert_bool(sp.layers.ball_count() > bare_balls).is_true()
	assert_bool(sp.layers.box_count() > bare_boxes).is_true()
	# Losing the ground takes the bloom away again.
	_paint_all(td, 0.0)
	sp.refresh(Config.C7_BLOOM_SECONDS * 2.0)
	assert_float(sp.props[0].bloom).is_equal(0.0)


func test_a_beautified_block_blooms_its_own_props_first() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sp := td.style_props
	_paint_all(td, 0.0)
	var target := td.border.buildings[0]
	for b: Building in td.border.buildings:
		b.tint = 1.0 if b == target else 0.0
	sp.refresh(Config.C7_BLOOM_SECONDS * 2.0)
	var lit := 0
	for p: StyleProps.Prop in sp.props:
		if p.bloom > 0.99:
			lit += 1
	assert_int(lit).is_equal(4)
	assert_int(sp.bench_positions().size()).is_equal(TopDownMain.BLOCK_POSITIONS.size())


func test_props_and_ambient_are_hidden_and_idle_in_the_placeholder_look() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(12)
	assert_bool(td.style_props.visible).is_true()
	assert_bool(td.style_ambient.visible).is_true()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(3)
	assert_bool(td.style_props.visible).is_false()
	assert_bool(td.style_ambient.visible).is_false()
	var before := td.style_props.time
	await runner.simulate_frames(10)
	assert_float(td.style_props.time).is_equal(before)


func test_butterflies_drift_by_day_and_fireflies_by_night_only_inside_the_zone() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sa := td.style_ambient
	for b: Building in td.border.buildings:
		b.tint = 1.0
	# Outside the zone nothing lives.
	_paint_all(td, 0.0)
	for i: int in range(8):
		sa.step(0.6)
	assert_int(_count_live(sa.butterflies)).is_equal(0)
	assert_int(_count_live(sa.fireflies)).is_equal(0)
	assert_int(sa.layers.ball_count()).is_equal(0)
	# By day inside the zone: butterflies (wings are boxes), no fireflies.
	_paint_all(td, 1.0)
	td.night.elapsed = 0.0
	for i: int in range(10):
		sa.step(0.6)
	assert_bool(_count_live(sa.butterflies) > 0).is_true()
	assert_bool(sa.layers.box_count() > 0).is_true()
	var day_balls := sa.layers.ball_count()
	# At midnight the fireflies glow (soft balls) and the butterflies are gone from the drawing.
	td.night.elapsed = Config.NIGHT_LENGTH * 0.5
	for i: int in range(6):
		sa.step(0.6)
	assert_bool(sa.layers.ball_count() > day_balls).is_true()
	assert_float(sa.day).is_less(0.2)
	# Losing the ground sends them away.
	_paint_all(td, 0.0)
	for i: int in range(6):
		sa.step(0.6)
	assert_int(_count_live(sa.butterflies)).is_equal(0)
	assert_int(_count_live(sa.fireflies)).is_equal(0)


func test_a_bird_lands_on_a_beautified_roof_and_leaves_when_it_is_lost() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sa := td.style_ambient
	for b: Building in td.border.buildings:
		b.beautified = false
	sa.step(0.1)
	assert_int(sa.layers.box_count()).is_equal(0)
	var building := td.border.buildings[0]
	building.beautified = true
	var idx := -1
	for i: int in range(TopDownMain.BLOCK_POSITIONS.size()):
		var c := TopDownMain.BLOCK_POSITIONS[i]
		if building.centre.distance_to(Vector2(c.x, c.z)) < 1.0:
			idx = i
	assert_bool(idx >= 0).is_true()
	sa.step(Config.C7_BIRD_SECONDS * 0.5)
	assert_float(sa.birds[idx].t).is_equal_approx(0.5, 0.001)
	assert_bool(sa.layers.box_count() > 3).is_true()  # Flying: body, tail and two wings.
	sa.step(Config.C7_BIRD_SECONDS)
	assert_float(sa.birds[idx].t).is_equal(1.0)
	assert_int(sa.layers.box_count()).is_equal(2)  # Landed: body and tail.
	assert_int(sa.layers.ball_count()).is_equal(1)  # The head.
	building.beautified = false
	sa.step(Config.C7_BIRD_SECONDS * 2.0)
	assert_float(sa.birds[idx].t).is_equal(0.0)
	assert_int(sa.layers.box_count()).is_equal(0)


func test_rescued_people_idle_in_the_zone_without_moving_their_rule_position() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sa := td.style_ambient
	_paint_all(td, 1.0)
	sa.butterflies.clear()
	sa.fireflies.clear()
	var p := td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, 0), p.affinity, 0.0)
	p.is_rescued = true
	var spot := p.global_position
	var it_id := p.get_instance_id()
	# Standing: nothing yet, then the action eases in.
	sa.step(0.5)
	assert_bool(sa.idlers.has(it_id)).is_true()
	assert_float(sa.idlers[it_id].ease_in).is_equal(0.0)
	var quiet_boxes := sa.layers.box_count()
	var quiet_balls := sa.layers.ball_count()
	for action: int in [StyleAmbient.Action.SIT, StyleAmbient.Action.WAVE, StyleAmbient.Action.TEND]:
		sa.idlers[it_id].action = action
		sa.idlers[it_id].still = Config.C7_IDLE_AFTER
		sa.idlers[it_id].ease_in = 0.0
		sa.step(Config.C7_IDLE_EASE * 2.0)
		assert_float(sa.idlers[it_id].ease_in).is_equal(1.0)
		var extra := sa.layers.box_count() - quiet_boxes + sa.layers.ball_count() - quiet_balls
		assert_bool(extra > 0).is_true()
		# The rules position never moves; only the drawing sinks (sitting).
		assert_vector(p.global_position).is_equal(spot)
		if action == StyleAmbient.Action.SIT:
			assert_float(p.look.position.y).is_equal_approx(-Config.C7_SIT_DROP, 0.001)
		else:
			assert_float(p.look.position.y).is_equal(0.0)
	# Moving restarts the wait and the action eases out.
	p.global_position = spot + Vector3(1, 0, 0)
	sa.step(Config.C7_IDLE_EASE * 2.0)
	assert_float(sa.idlers[it_id].ease_in).is_equal(0.0)
	assert_float(sa.idlers[it_id].still).is_equal(0.0)
	assert_float(p.look.position.y).is_equal(0.0)


func test_idle_sinks_are_put_back_and_the_unrescued_never_idle() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var sa := td.style_ambient
	_paint_all(td, 1.0)
	var p := td.people[0]
	var q := td.people[1]
	TopDownTestUtil.place(p, Vector3(0, 0, 0), p.affinity, 0.0)
	TopDownTestUtil.place(q, Vector3(3, 0, 0), q.affinity, 0.0)
	p.is_rescued = true
	sa.step(0.1)
	assert_bool(sa.idlers.has(q.get_instance_id())).is_false()
	var it: StyleAmbient.Idler = sa.idlers[p.get_instance_id()]
	it.action = StyleAmbient.Action.SIT
	it.still = Config.C7_IDLE_AFTER
	sa.step(Config.C7_IDLE_EASE * 2.0)
	assert_float(p.look.position.y).is_less(0.0)
	sa.release_idlers()
	assert_float(p.look.position.y).is_equal(0.0)
	assert_int(sa.idlers.size()).is_equal(0)
	# A wobbling person does not idle, and a person who leaves the zone drops out.
	p.is_rescued = true
	p.wobbling = true
	sa.step(0.1)
	assert_bool(sa.idlers.has(p.get_instance_id())).is_false()
	p.wobbling = false
	sa.step(0.1)
	assert_bool(sa.idlers.has(p.get_instance_id())).is_true()
	_paint_all(td, 0.0)
	sa.step(0.1)
	assert_bool(sa.idlers.has(p.get_instance_id())).is_false()


func _tiny_layers(boxes: int, balls: int) -> StyleProps.Layers:
	var ls := StyleProps.Layers.new()
	ls.boxes = MultiMesh.new()
	ls.boxes.transform_format = MultiMesh.TRANSFORM_3D
	ls.boxes.use_colors = true
	ls.boxes.instance_count = boxes
	ls.balls = MultiMesh.new()
	ls.balls.transform_format = MultiMesh.TRANSFORM_3D
	ls.balls.use_colors = true
	ls.balls.instance_count = balls
	return ls


func test_layers_stop_drawing_when_full_and_skip_degenerate_pieces() -> void:
	var ls := _tiny_layers(1, 1)
	ls.begin()
	ls.box(Vector3.ZERO, Vector3.ONE, Color.WHITE)
	ls.box(Vector3.ZERO, Vector3.ONE, Color.WHITE)  # Full: ignored.
	assert_int(ls.box_count()).is_equal(1)
	ls.seg(Vector3.ZERO, Vector3.UP, 0.1, Color.WHITE)  # Full: ignored.
	assert_int(ls.box_count()).is_equal(1)
	ls.begin()
	ls.seg(Vector3.ZERO, Vector3.ZERO, 0.1, Color.WHITE)  # Zero length: ignored.
	assert_int(ls.box_count()).is_equal(0)
	ls.seg(Vector3.ZERO, Vector3.UP, 0.1, Color.WHITE)
	assert_int(ls.box_count()).is_equal(1)
	ls.ball(Vector3.ZERO, 0.0, Color.WHITE)  # Too small: ignored.
	assert_int(ls.ball_count()).is_equal(0)


func test_props_and_ambient_without_a_game_fall_back_to_quiet_defaults() -> void:
	var sp := StyleProps.new()
	assert_float(sp._night_amount()).is_equal(0.5)
	sp.free()
	var sa := StyleAmbient.new()
	assert_float(sa._weight(Vector3.ZERO)).is_equal(0.0)
	assert_vector(sa._pick_anchor()).is_equal(Vector3.INF)
	assert_bool(sa._building_beautified(0)).is_false()
	sa._step_idlers(0.1)
	assert_int(sa.idlers.size()).is_equal(0)
	sa._sink(null, 1.0)  # No idler: nothing to sink.
	sa.free()


func test_a_block_with_no_building_is_not_beautified() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.border.buildings.clear()
	assert_bool(td.style_ambient._building_beautified(0)).is_false()
