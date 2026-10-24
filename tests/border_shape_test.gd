extends GdUnitTestSuite

# Pure border rules (round 9, organic push only from round 10): the slot count, gap flags and the loop helpers, plus the
# organic bump and wrap. The loop is set directly where a scene is not needed. No scene is loaded.


func test_circle_polygon_has_the_samples_on_the_circle() -> void:
	var pts := Border.circle_polygon(Vector2(1.0, -2.0), 4.0, Config.BORDER_SAMPLES)
	assert_int(pts.size()).is_equal(Config.BORDER_SAMPLES)
	for p: Vector2 in pts:
		assert_float(p.distance_to(Vector2(1.0, -2.0))).is_equal_approx(4.0, 0.0001)
	assert_float(Border.perimeter_of(pts)).is_equal_approx(TAU * 4.0, 0.05)


func test_slot_count_is_the_perimeter_over_the_spacing_rounded_up() -> void:
	assert_int(Border.slot_count_for(Config.BORDER_TARGET_SPACING * 9.0)).is_equal(9)
	assert_int(Border.slot_count_for(Config.BORDER_TARGET_SPACING * 9.0 + 0.5)).is_equal(10)


func test_perimeter_of_a_unit_square_is_four() -> void:
	var square := PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	assert_float(Border.perimeter_of(square)).is_equal_approx(4.0, 0.0001)


func test_spacing_under_the_limit_is_not_a_gap() -> void:
	var filled: Array[bool] = [true, true, true]
	var gaps := Border.gap_flags(Config.BORDER_MAX_GAP - 0.5, filled)
	assert_array(gaps).is_equal([false, false, false])


func test_spacing_over_the_limit_is_a_gap_on_every_segment() -> void:
	var filled: Array[bool] = [true, true, true]
	var gaps := Border.gap_flags(Config.BORDER_MAX_GAP + 0.5, filled)
	assert_array(gaps).is_equal([true, true, true])


func test_an_empty_slot_marks_the_two_segments_next_to_it_as_gaps() -> void:
	# Spacing is fine, but slot 1 has nobody on it: the stretches either side of it are gaps, the rest is intact.
	var filled: Array[bool] = [true, false, true, true]
	var gaps := Border.gap_flags(1.0, filled)
	assert_array(gaps).is_equal([true, true, false, false])


func test_is_inside_follows_the_loop() -> void:
	var square := PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 2), Vector2(-2, 2)])
	assert_bool(Border.is_inside(square, Vector2.ZERO)).is_true()
	assert_bool(Border.is_inside(square, Vector2(3, 0))).is_false()
	assert_bool(Border.is_inside(PackedVector2Array(), Vector2.ZERO)).is_false()


func test_a_ray_hits_a_box_in_front_of_the_centre() -> void:
	var hit := Border._ray_box(Vector2.ZERO, Vector2.RIGHT, Vector2(3, -1), Vector2(5, 1))
	assert_float(hit.x).is_equal_approx(3.0, 0.0001)
	assert_float(hit.y).is_equal_approx(5.0, 0.0001)
	# A ray pointing away misses.
	var miss := Border._ray_box(Vector2.ZERO, Vector2.LEFT, Vector2(3, -1), Vector2(5, 1))
	assert_bool(miss.x == INF).is_true()


func test_darkness_outside_an_intact_line_cannot_drain_someone_inside() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	border.active = true
	var ring: Array[Person] = []
	for i: int in range(14):
		var a := TAU * float(i) / 14.0
		var m: Person = auto_free(Person.new())
		add_child(m)
		m.position = Vector3(cos(a) * 5.0, 0.0, sin(a) * 5.0)
		m.is_rescued = true
		ring.append(m)
	border._assign_members(ring)
	var inside: Person = auto_free(Person.new())
	add_child(inside)
	inside.position = Vector3(4.5, 0.0, 0.33)
	inside.receive_joy(0, Config.JOY_MAX, 0.0)
	var dark: Person = auto_free(Person.new())
	add_child(dark)
	dark.position = Vector3(6.0, 0.0, 0.33)
	dark.gloom = 1.0
	var people: Array[Person] = [inside, dark]
	var before := inside.joy
	GloomSim.update(people, 0.5, Config.TD_DRAIN_MULTIPLIER, 1.0, border)
	assert_float(inside.joy).is_equal(before)
	# The same pair with no border in the way is drained.
	GloomSim.update(people, 0.5, Config.TD_DRAIN_MULTIPLIER, 1.0)
	assert_float(inside.joy).is_less(before)


# --- Organic push and wrap (scene-free: the border is built directly) -----------------------------------------------


func _organic_border() -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	return border


# A rescued person standing at `pos` (the border only counts rescued people).
func _person_at(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.position = pos
	p.is_rescued = true
	return p


func test_rescue_pushes_the_border_outward_at_its_angle() -> void:
	var border := _organic_border()
	border._has_centre = true
	border.centre = Vector3.ZERO
	var before_at_rescue: float = border._raw_radii[0]
	var before_opposite: float = border._raw_radii[24]
	var rescued := _person_at(Vector3(5.0, 0.0, 0.0))
	border.on_rescue(rescued)
	var people: Array[Person] = [rescued]
	border.update(people, 0.0, 1.0)
	# The peak push is BORDER_PUSH at the rescue angle (angle 0 is index 0) and almost nothing half a turn away.
	assert_float(border._raw_radii[0]).is_equal_approx(before_at_rescue + Config.BORDER_PUSH, 0.001)
	assert_float(border._raw_radii[24]).is_less(before_opposite + 0.01)
	assert_float(border._raw_radii[1]).is_greater(border._raw_radii[24])


func test_organic_border_wraps_a_block_it_reaches_so_the_block_is_enclosed() -> void:
	var border := _organic_border()
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


func test_a_rescue_standing_on_the_centre_waits_until_the_centre_moves_off_it() -> void:
	var border := _organic_border()
	var alone := _person_at(Vector3.ZERO)
	border.on_rescue(alone)
	var people: Array[Person] = [alone]
	border.update(people, 0.0, 1.0)
	# The lone first person is the centre, so there is no direction to push in yet: no push, and it stays pending.
	assert_float(border._raw_radii[0]).is_equal_approx(Config.BORDER_MIN_RADIUS, 0.001)
	assert_int(border._pending_pushes.size()).is_equal(1)


func test_a_rescue_that_relapses_before_its_push_is_applied_gets_no_push() -> void:
	var border := _organic_border()
	border._has_centre = true
	border.centre = Vector3.ZERO
	var p := _person_at(Vector3(5.0, 0.0, 0.0))
	border.on_rescue(p)
	p.is_rescued = false
	var people: Array[Person] = [p]
	border.update(people, 0.0, 1.0)
	assert_float(border._raw_radii[0]).is_equal_approx(Config.BORDER_MIN_RADIUS, 0.001)
	assert_int(border._pending_pushes.size()).is_equal(0)


func test_no_cover_without_a_loop_and_the_debug_labels_hide_again() -> void:
	var border := _organic_border()
	assert_float(border.cover_at(Vector3.ZERO)).is_equal(0.0)
	border.active = true
	border.polygon = Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	border.set_debug(true)
	border.set_debug(false)
	assert_int(border.visible_debug_label_count()).is_equal(0)
