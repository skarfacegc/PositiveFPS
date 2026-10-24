extends GdUnitTestSuite

# Pure border rules (round 9): the circle radius, the slot count, gap flags and the loop helpers. No scene is loaded.


func test_circle_radius_follows_the_count_and_is_clamped() -> void:
	# n x spacing / (2 pi), clamped between BORDER_MIN_RADIUS and BORDER_MAX_RADIUS.
	assert_float(Border.circle_radius_for(20)).is_equal_approx(20.0 * Config.BORDER_TARGET_SPACING / TAU, 0.0001)
	assert_float(Border.circle_radius_for(1)).is_equal(Config.BORDER_MIN_RADIUS)
	assert_float(Border.circle_radius_for(500)).is_equal(Config.BORDER_MAX_RADIUS)


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
	border.setup(null, Config.BorderVariant.CIRCLE)
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
