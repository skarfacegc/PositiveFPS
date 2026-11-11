extends GdUnitTestSuite

# Small direct checks of Border's edge cases (#73): the look rebuilt in place, answers before the border forms, the
# flicker when the player is dim, and a dimmed person standing exactly on the line.


func _border(cells: Array[Vector2i] = []) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	for c: Vector2i in cells:
		border.zone.take(c)
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border._mark_gaps()
	return border


func test_the_look_is_rebuilt_in_place() -> void:
	var border := _border()
	border.rebuild_look()
	var first: Node = border.look
	assert_object(first).is_not_null()
	border.rebuild_look()
	assert_object(border.look).is_not_null()
	assert_bool(border.look == first).is_false()


func test_a_border_that_has_not_formed_answers_plainly() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.active = false
	assert_int(border.gate_member_count(-1)).is_equal(0)
	assert_int(border.gate_member_count(9999)).is_equal(0)
	assert_object(border._crossing(Vector2(-50.0, 0.0), Vector2(50.0, 0.0))).is_null()
	assert_str(border.debug_summary()).is_equal("border: none yet")


func test_the_line_flickers_only_while_the_player_is_dim() -> void:
	var border := _border()
	border.player_dim = false
	assert_float(border.flicker()).is_equal(1.0)
	border.player_dim = true
	border._time = SpiritConfig.DIM_FLICKER_SECONDS * 0.75
	assert_float(border.flicker()).is_equal_approx(SpiritConfig.DIM_FLICKER_MIN, 0.001)


func test_a_dimmed_person_exactly_on_the_line_is_not_pushed() -> void:
	var border := _border()
	var p: Person = auto_free(Person.new())
	add_child(p)
	p.gloom = 1.0
	var on_line := Vector2.ZERO
	var found := false
	# An intact (non-wall, non-gap) segment's midpoint, nudged just outside the polygon if the test says it is inside.
	for i: int in range(border.polygon.size()):
		if border.is_wall(i) or border.segment_is_gap(i):
			continue
		var a: Vector2 = border.polygon[i]
		var b: Vector2 = border.polygon[(i + 1) % border.polygon.size()]
		var mid := (a + b) * 0.5
		var normal := (b - a).orthogonal().normalized() * 0.0005
		for candidate: Vector2 in [mid + normal, mid - normal]:
			if not Geometry2D.is_point_in_polygon(candidate, border.polygon):
				on_line = candidate
				found = true
				break
		if found:
			break
	assert_bool(found).is_true()
	p.position = Vector3(on_line.x, 0.0, on_line.y)
	var list: Array[Person] = [p]
	border._press_gloom(list, 0.5, 1.0)
	assert_float(p.position.x).is_equal_approx(on_line.x, 0.001)
	assert_float(p.position.z).is_equal_approx(on_line.y, 0.001)
