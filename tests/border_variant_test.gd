extends GdUnitTestSuite

# The three border variants (round 9), checked on their own: the circle radius, the organic bump and wrap, and the paint
# edge that follows the painted region. Night and light are in night_cycle_test.gd.


func _border(chosen: int) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null, chosen)
	return border


# A rescued person standing at `pos` (the border only counts rescued people).
func _person_at(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.position = pos
	p.is_rescued = true
	return p


func test_circle_border_radius_is_the_circle_formula_for_the_rescued_count() -> void:
	var border := _border(Config.BorderVariant.CIRCLE)
	var people: Array[Person] = []
	for i: int in range(5):
		var a := TAU * float(i) / 5.0
		people.append(_person_at(Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0)))
	border.update(people, 0.0, 1.0)
	assert_bool(border.active).is_true()
	var expected := Border.circle_radius_for(5)
	for p2: Vector2 in border.polygon:
		assert_float(p2.length()).is_equal_approx(expected, 0.001)


func test_organic_rescue_pushes_the_border_outward_at_its_angle() -> void:
	var border := _border(Config.BorderVariant.ORGANIC)
	border._has_centre = true
	border.centre = Vector3.ZERO
	var before_at_rescue: float = border._raw_radii[0]
	var before_opposite: float = border._raw_radii[24]
	border.on_rescue(_person_at(Vector3(5.0, 0.0, 0.0)))
	# The peak push is BORDER_PUSH at the rescue angle (angle 0 is index 0) and almost nothing half a turn away.
	assert_float(border._raw_radii[0]).is_equal_approx(before_at_rescue + Config.BORDER_PUSH, 0.001)
	assert_float(border._raw_radii[24]).is_less(before_opposite + 0.01)
	assert_float(border._raw_radii[1]).is_greater(border._raw_radii[24])


func test_organic_border_wraps_a_block_it_reaches_so_the_block_is_enclosed() -> void:
	var border := _border(Config.BorderVariant.ORGANIC)
	border._has_centre = true
	border.centre = Vector3.ZERO
	# A block footprint from x = 5 to x = 7 on the +x side. The loop reaches 5.5 m, which is past its near face.
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.position = Vector3(6.0, 0.0, 0.0)
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.material_override = StandardMaterial3D.new()
	body.add_child(mesh_inst)
	add_child(body)
	border.register_building(body, Vector2(1.0, 1.0), false)
	for i: int in range(Config.BORDER_SAMPLES):
		border._raw_radii[i] = 5.5
	var pts: PackedVector2Array = border._organic_polygon(Vector2.ZERO, 3, 0.0)
	# Sample 0 points at the block: it is pushed out to just beyond the far face (x = 7), so the block is inside.
	assert_float(pts[0].x).is_greater(7.0)
	assert_bool(Geometry2D.is_point_in_polygon(Vector2(6.0, 0.0), pts)).is_true()


func test_paint_edge_border_follows_the_painted_region() -> void:
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(40, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)
	ground.paint_radius = Config.BORDER_PAINT_RADIUS
	var painter := _person_at(Vector3.ZERO)
	painter.is_rescued = true
	var painters: Array[Person] = [painter]
	for i: int in range(300):
		ground.update_paint(painters, 0.11)
	var border := _border(Config.BorderVariant.PAINT_EDGE)
	border.setup(ground, Config.BorderVariant.PAINT_EDGE)
	var pts: PackedVector2Array = border._paint_edge_polygon(Vector2.ZERO)
	assert_int(pts.size()).is_equal(Config.BORDER_SAMPLES)
	for p2: Vector2 in pts:
		# The painted disc is about 3 to 3.5 m across the middle, so the edge sits within that band.
		assert_float(p2.length()).is_greater(2.0)
		assert_float(p2.length()).is_less(4.5)


func test_paint_edge_leaves_the_ground_to_the_paint_not_the_region() -> void:
	var border := _border(Config.BorderVariant.PAINT_EDGE)
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(40, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)
	border.setup(ground, Config.BorderVariant.PAINT_EDGE)
	var none: Array[Person] = []
	border.update(none, 0.0, 1.0)
	# With no loop the region is off, so the paint edge variant never forces tiles to paint.
	assert_bool(ground.region_active).is_false()


func test_each_variant_has_a_name_for_the_hud_and_menu() -> void:
	for i: int in range(3):
		assert_bool(Config.BORDER_VARIANT_NAMES[i].length() > 0).is_true()
