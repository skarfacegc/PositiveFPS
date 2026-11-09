extends GdUnitTestSuite

# 0.3.2 Prop styling (#42, #49, #50): the lamps' light and vines, the benches' shape change and the wires above the
# player's head. Headless uses a dummy renderer, so these check state, instance counts and transforms; the screenshots
# (design/renders/v0.3.2/) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# A StyleProps with its own layers (light shapes too), not in the tree.
func _props() -> Dictionary:
	var parent := Node3D.new()
	var sp := StyleProps.new()
	sp.layers = StyleProps.make_layers(parent, true)
	sp.layers.watch = true
	return {"sp": sp, "parent": parent}


func _free(s: Dictionary) -> void:
	(s["sp"] as StyleProps).free()
	(s["parent"] as Node3D).free()


func _draw_one(sp: StyleProps, kind: int, bloom: float, night: float = 1.0) -> void:
	var p := StyleProps._prop(kind, Vector3(4.0, 0.0, -3.0), 0.0, 0)
	p.bloom = bloom
	sp.layers.begin()
	if kind == StyleProps.Kind.LAMP:
		sp._draw_lamp(p, night)
	else:
		sp._draw_bench(p)
	sp.layers.finish()


func _saturation(c: Color) -> float:
	return c.s


# ---- Lamps (#49) ----


func test_the_lamp_light_is_cool_in_gloom_and_warm_in_bloom() -> void:
	var cool := StyleProps.lamp_light_colour(0.0)
	var warm := StyleProps.lamp_light_colour(1.0)
	assert_bool(cool.is_equal_approx(Config.L32_LIGHT_COOL)).is_true()
	assert_bool(warm.is_equal_approx(Config.L32_LIGHT_WARM)).is_true()
	# Pale blue-white: blue is the strongest channel. Cheery amber: red the strongest, blue the weakest.
	assert_bool(cool.b >= cool.g and cool.g >= cool.r).is_true()
	assert_bool(warm.r > warm.g and warm.g > warm.b).is_true()
	# It warms steadily as the bloom rises.
	var last := -1.0
	for i: int in range(11):
		var c := StyleProps.lamp_light_colour(float(i) / 10.0)
		assert_float(c.r).is_greater_equal(last)
		last = c.r
	assert_float(StyleProps.lamp_light_colour(0.5).b).is_less(cool.b)
	assert_float(StyleProps.lamp_light_colour(0.5).r).is_greater(cool.r)


func test_the_lamp_light_is_strong_at_night_and_faint_by_day() -> void:
	for bloom: float in [0.0, 0.5, 1.0]:
		assert_float(StyleProps.lamp_light_strength(bloom, 1.0)).is_greater(StyleProps.lamp_light_strength(bloom, 0.0))
		assert_float(StyleProps.lamp_light_strength(bloom, 0.0)).is_less_equal(Config.L32_LIGHT_DAY + 0.001)
	assert_float(StyleProps.lamp_light_strength(1.0, 1.0)).is_equal_approx(1.0, 0.001)
	assert_float(StyleProps.lamp_light_strength(0.0, 1.0)).is_equal_approx(Config.L32_LIGHT_GLOOM, 0.001)
	assert_float(StyleProps.lamp_light_strength(1.0, 5.0)).is_equal_approx(1.0, 0.001)
	# The light never hides a person or a gap: every shape stays see-through, even at its strongest.
	for a: float in [Config.L32_CONE_ALPHA, Config.L32_POOL_ALPHA, Config.L32_HEAD_ALPHA]:
		assert_float(a).is_less_equal(Config.L32_MAX_LIGHT_ALPHA)
		assert_float(a).is_greater(0.0)


func test_a_lamp_draws_a_cone_a_pool_and_a_head_glow_at_every_bloom() -> void:
	var s := _props()
	var sp: StyleProps = s["sp"]
	for bloom: float in [0.0, 0.5, 1.0]:
		_draw_one(sp, StyleProps.Kind.LAMP, bloom)
		assert_int(sp.layers.cone_count()).is_equal(1)
		assert_int(sp.layers.pool_count()).is_equal(1)
		assert_bool(sp.layers.ball_count() >= 2).is_true()
		assert_int(sp.layers.cones.visible_instance_count).is_equal(1)
		assert_int(sp.layers.pools.visible_instance_count).is_equal(1)
	# The cone runs from the head down to the ground and is as wide as the pool; the pool lies on the ground.
	_draw_one(sp, StyleProps.Kind.LAMP, 1.0)
	var cone := sp.layers.last_cone
	var pool := sp.layers.last_pool
	assert_float(cone.origin.y + cone.basis.y.length() * 0.5).is_equal_approx(StyleProps.lamp_head_height(), 0.01)
	assert_float(cone.origin.y - cone.basis.y.length() * 0.5).is_less(0.1)
	assert_float(cone.origin.x).is_equal_approx(4.0, 0.001)
	assert_float(cone.origin.z).is_equal_approx(-3.0, 0.001)
	assert_float(pool.origin.y).is_between(0.0, 0.2)
	assert_float(pool.basis.x.length()).is_equal_approx(cone.basis.x.length(), 0.001)
	assert_float(pool.basis.x.length()).is_equal_approx(Config.L32_POOL_RADIUS * 2.0, 0.001)
	# A full pool of the light does not run past a lamp's neighbours on the plaza lattice.
	assert_float(Config.L32_POOL_RADIUS).is_less(Config.TOWN_LAMP_SPACING * 0.5)
	_free(s)


func test_the_light_shapes_draw_after_the_post_process_quad_and_a_layer_can_be_left_out() -> void:
	var s := _props()
	var sp: StyleProps = s["sp"]
	for i: int in [2, 3]:
		var mi: MultiMeshInstance3D = (s["parent"] as Node3D).get_child(i)
		var mat := mi.material_override as ShaderMaterial
		assert_int(mat.render_priority).is_equal(Config.L31_SOFT_PRIORITY)
		assert_object(mat.shader).is_not_null()
	# Layers made without the light (the ambient life's) simply ignore a cone or a pool.
	var parent := Node3D.new()
	var plain := StyleProps.make_layers(parent)
	plain.begin()
	plain.cone(Vector3(0, 3, 0), 0.0, 2.0, Color.WHITE)
	plain.pool(Vector3.ZERO, 2.0, Color.WHITE)
	plain.finish()
	assert_int(plain.cone_count()).is_equal(0)
	assert_int(plain.pool_count()).is_equal(0)
	# A cone with no height or no width is skipped.
	sp.layers.begin()
	sp.layers.cone(Vector3(0, 0.0, 0), 0.0, 2.0, Color.WHITE)
	sp.layers.cone(Vector3(0, 3.0, 0), 0.0, 0.0, Color.WHITE)
	sp.layers.pool(Vector3.ZERO, 0.0, Color.WHITE)
	assert_int(sp.layers.cone_count()).is_equal(0)
	assert_int(sp.layers.pool_count()).is_equal(0)
	parent.free()
	_free(s)


func test_a_lamp_grows_vines_and_flowers_as_it_blooms() -> void:
	assert_int(StyleProps.vine_steps(0.0)).is_equal(0)
	assert_int(StyleProps.vine_steps(1.0)).is_equal(StyleProps.VINE_STEPS)
	assert_int(StyleProps.vine_steps(0.6)).is_between(1, StyleProps.VINE_STEPS - 1)
	var s := _props()
	var sp: StyleProps = s["sp"]
	_draw_one(sp, StyleProps.Kind.LAMP, 0.0)
	var bare_boxes := sp.layers.box_count()
	var bare_balls := sp.layers.ball_count()
	_draw_one(sp, StyleProps.Kind.LAMP, 0.5)
	var half_boxes := sp.layers.box_count()
	assert_bool(half_boxes > bare_boxes).is_true()
	assert_int(sp.layers.ball_count()).is_equal(bare_balls)  # Leaves only: no flowers yet.
	_draw_one(sp, StyleProps.Kind.LAMP, 1.0)
	assert_bool(sp.layers.box_count() > half_boxes).is_true()
	assert_bool(sp.layers.ball_count() > bare_balls).is_true()  # A few small flowers near full bloom.
	assert_bool(sp.layers.box_count() < 40).is_true()
	_free(s)


func test_the_lamp_stands_stiff_and_its_light_does_not_depend_on_the_night_for_its_shape() -> void:
	var s := _props()
	var sp: StyleProps = s["sp"]
	_draw_one(sp, StyleProps.Kind.LAMP, 0.0, 1.0)
	var night_boxes := sp.layers.box_count()
	var gloom_post := sp.layers.spans[2]
	_draw_one(sp, StyleProps.Kind.LAMP, 0.0, 0.0)
	assert_int(sp.layers.box_count()).is_equal(night_boxes)
	# The post stands the same height at every bloom and sits on the plinth: stiff and straight (the lean is gone).
	assert_float(sp.layers.spans[2].y - sp.layers.spans[2].x).is_equal_approx(gloom_post.y - gloom_post.x, 0.001)
	_draw_one(sp, StyleProps.Kind.LAMP, 1.0, 1.0)
	assert_float(sp.layers.spans[2].y - sp.layers.spans[2].x).is_equal_approx(gloom_post.y - gloom_post.x, 0.001)
	assert_float(sp.layers.spans[2].x).is_equal_approx(gloom_post.x, 0.001)
	# The lamp's whole height fits the frame at play zoom (the head is the top of the post plus a small cap).
	assert_float(StyleProps.lamp_head_height()).is_between(2.5, 5.0)
	_free(s)


# ---- Benches (#50) ----


func test_a_bench_changes_shape_not_only_colour_as_it_blooms() -> void:
	var s := _props()
	var sp: StyleProps = s["sp"]
	_draw_one(sp, StyleProps.Kind.BENCH, 0.0)
	var gloom_boxes := sp.layers.box_count()
	var gloom_seat := sp.layers.spans[0]
	_draw_one(sp, StyleProps.Kind.BENCH, 1.0)
	var joy_boxes := sp.layers.box_count()
	var joy_seat := sp.layers.spans[0]
	assert_int(joy_boxes).is_not_equal(gloom_boxes)
	# The seat is a thick plate in gloom and thinner slats in bloom.
	assert_float(joy_seat.y - joy_seat.x).is_less(gloom_seat.y - gloom_seat.x)
	# Rivets in gloom only: the gloom bench has more small pieces than the seat, back and ends alone.
	assert_bool(gloom_boxes >= StyleProps.SEAT_SLATS + StyleProps.BACK_SLATS + 4 + 5).is_true()
	# The cushion and blanket appear with the bloom: two more boxes than a half-bloomed bench's arms and curls.
	_draw_one(sp, StyleProps.Kind.BENCH, 0.5)
	var half_boxes := sp.layers.box_count()
	assert_bool(joy_boxes >= half_boxes).is_true()
	_draw_one(sp, StyleProps.Kind.BENCH, 0.45)
	var no_cushion := sp.layers.box_count()
	_draw_one(sp, StyleProps.Kind.BENCH, 0.7)
	assert_int(sp.layers.box_count()).is_equal(no_cushion + 2)
	_free(s)


func test_no_bench_colour_stands_out_in_the_calm_opening() -> void:
	# A gloom bench is all grey (rivets a lighter grey); the bloomed palette is earthy: muted and never near white.
	for c: Color in [StyleProps.BENCH_GREY, StyleProps.BENCH_RIVET, StyleProps.BENCH_IRON]:
		assert_float(_saturation(c)).is_less(0.2)
	assert_float(_saturation(StyleProps.BENCH_WOOD)).is_less(0.55)
	for c: Color in StyleProps.CUSHIONS:
		assert_float(_saturation(c)).is_between(0.2, 0.6)
		assert_float(c.v).is_less(0.85)
	# The old orange bench: a bloom-0 bench must not lift toward the warm wood any more.
	var grey := StyleProps.BENCH_GREY.lerp(StyleProps.BENCH_WOOD, StyleProps.bench_joy(0.0))
	assert_bool(grey.is_equal_approx(StyleProps.BENCH_GREY)).is_true()
	assert_float(_saturation(grey)).is_less(0.2)
	assert_float(StyleProps.bench_joy(0.0)).is_equal(0.0)
	assert_float(StyleProps.bench_joy(1.0)).is_equal(1.0)
	assert_float(StyleProps.bench_joy(0.5)).is_between(0.1, 0.9)
	# The cushion colour is the same every run for a place and always one of the palette.
	var seen := {}
	for ix: int in range(-6, 7):
		var i := StyleProps.cushion_index(Vector3(float(ix) * 3.7, 0.0, float(ix) * 1.3 - 2.0))
		assert_int(i).is_between(0, StyleProps.CUSHIONS.size() - 1)
		seen[i] = true
	assert_int(seen.size()).is_greater(1)
	assert_int(StyleProps.cushion_index(Vector3(3, 0, 4))).is_equal(StyleProps.cushion_index(Vector3(3, 0, 4)))


# ---- Wires (#42) ----


# The highest point (metres) of the styled player's model, measured from its meshes.
func _player_height() -> float:
	var root := Node3D.new()
	var parts := {}
	StylePeople.build_player(root, parts)
	var top := _top_of(root, Transform3D.IDENTITY)
	root.free()
	return top


func _top_of(node: Node, parent_t: Transform3D) -> float:
	var t := parent_t
	if node is Node3D:
		t = parent_t * (node as Node3D).transform
	var top := -INF
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var box: AABB = t * (node as MeshInstance3D).get_aabb()
		top = box.end.y
	for child: Node in node.get_children():
		top = maxf(top, _top_of(child, t))
	return top


func test_the_player_height_constant_is_the_measured_styled_height() -> void:
	var h := _player_height()
	assert_float(h).is_less_equal(Config.L32_PLAYER_HEIGHT)
	assert_float(h).is_greater(Config.L32_PLAYER_HEIGHT - 0.4)


func test_bunting_posts_and_wires_stay_above_the_players_head_everywhere() -> void:
	var h := _player_height()
	assert_float(Config.L32_LINE_POST_HEIGHT).is_greater(h + Config.L32_LINE_CLEARANCE)
	# The rope's lowest point and the longest flag, at every unfurl from just shown to full, for bunting and washing.
	for washing: bool in [false, true]:
		for i: int in range(0, 15):
			var u := lerpf(Config.L31_LINE_SHOW + Config.L32_LINE_RISE, 1.0, float(i) / 14.0)
			assert_float(StyleProps.line_low_point(u, washing)).is_greater_equal(h + Config.L32_LINE_CLEARANCE)
	var centres: Array[Vector3] = []
	for c: Vector3 in TopDownMain.BLOCK_POSITIONS:
		centres.append(c)
	for l: StyleProps.Line in StyleProps.layout_lines(centres, Config.C7_LINE_MAX_DIST):
		assert_float(l.a.y).is_greater(h + Config.L32_LINE_CLEARANCE)
		assert_float(l.b.y).is_greater(h + Config.L32_LINE_CLEARANCE)


func test_every_drawn_piece_of_a_risen_line_is_above_the_players_head() -> void:
	var h := _player_height()
	var s := _props()
	var sp: StyleProps = s["sp"]
	for washing: bool in [false, true]:
		for u: float in [Config.L31_LINE_SHOW + Config.L32_LINE_RISE, 0.5, 0.8, 1.0]:
			var l := StyleProps.Line.new()
			l.a = Vector3(0, Config.L32_LINE_POST_HEIGHT, 0)
			l.b = Vector3(10, Config.L32_LINE_POST_HEIGHT, 4)
			l.washing = washing
			l.unfurl = u
			sp.layers.begin()
			sp._draw_line(l, 0)
			sp.layers.finish()
			var lowest := INF
			var posts := 0
			for span: Vector2 in sp.layers.spans:
				if span.x < 0.01:
					posts += 1  # A post: it stands on the ground and reaches up to the line.
					assert_float(span.y).is_greater_equal(Config.L32_LINE_POST_HEIGHT - 0.01)
					continue
				lowest = minf(lowest, span.x)
			assert_int(posts).is_equal(2)
			assert_float(lowest).is_greater_equal(h)
	_free(s)
