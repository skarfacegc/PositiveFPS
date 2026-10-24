extends GdUnitTestSuite

# Small edge cases of the border rules (degenerate loops, nobody to place, debug labels switched off again).


func _border(loop: PackedVector2Array) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = loop
	border.active = true
	return border


func test_a_loop_with_no_length_or_no_rescued_people_places_nobody() -> void:
	var flat := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	var border := _border(flat)
	border._assign_members([])
	assert_int(border.member_count).is_equal(0)
	var ring := _border(Border.circle_polygon(Vector2.ZERO, 4.0, Config.BORDER_SAMPLES))
	ring._assign_members([])
	assert_int(ring.member_count).is_equal(0)
	assert_float(ring.perimeter).is_greater(1.0)


func test_the_mean_radius_of_no_loop_is_the_minimum() -> void:
	var border := _border(PackedVector2Array())
	assert_float(border._mean_radius()).is_equal(Config.BORDER_MIN_RADIUS)


func test_someone_without_a_slot_is_left_where_they_stand() -> void:
	var border := _border(Border.circle_polygon(Vector2.ZERO, 4.0, Config.BORDER_SAMPLES))
	var p: Person = auto_free(Person.new())
	add_child(p)
	p.position = Vector3(1.0, 0.0, 2.0)
	border.members.append(p)
	border._move_members(1.0)
	assert_vector(p.position).is_equal(Vector3(1.0, 0.0, 2.0))


func test_debug_labels_hide_again_when_switched_off() -> void:
	var border := _border(Border.circle_polygon(Vector2.ZERO, 4.0, Config.BORDER_SAMPLES))
	var ring: Array[Person] = []
	for i: int in range(4):
		var p: Person = auto_free(Person.new())
		add_child(p)
		p.position = Vector3(cos(float(i)) * 4.0, 0.0, sin(float(i)) * 4.0)
		p.is_rescued = true
		ring.append(p)
	border._assign_members(ring)
	border.set_debug(true)
	assert_int(border.visible_debug_label_count()).is_greater(0)
	border.set_debug(false)
	assert_int(border.visible_debug_label_count()).is_equal(0)
