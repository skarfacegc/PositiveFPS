extends GdUnitTestSuite

# Round 10 border rules (scene-free): posts and the slots they hold, anchored gaps, push-back at intact lines, the
# joy burst shove, and the spacing that the loop settles to.


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


# --- Round 10: posts, anchored gaps, push-back and shove -------------------------------------------------------------


# A block whose footprint is centred on `pos` (half-size `half`), registered with the border. Beautified or not.
func _block(border: Border, pos: Vector2, half: Vector2, beautified: bool, landmark: bool = false) -> Building:
	var body: StaticBody3D = auto_free(StaticBody3D.new())
	body.position = Vector3(pos.x, 0.0, pos.y)
	add_child(body)
	border.register_building(body, half, landmark)
	var b: Building = border.buildings[border.buildings.size() - 1]
	b.beautified = beautified
	return b


# `n` rescued people spread evenly on a circle of radius `r`.
func _ring_people(n: int, r: float) -> Array[Person]:
	var out: Array[Person] = []
	for i: int in range(n):
		var a := TAU * float(i) / float(n)
		out.append(_person_at(Vector3(cos(a) * r, 0.0, sin(a) * r)))
	return out


func test_a_beautified_building_on_the_line_is_a_post_that_needs_three_fewer_members() -> void:
	var border := _organic_border()
	border.polygon = Border.circle_polygon(Vector2.ZERO, 6.0, Config.BORDER_SAMPLES)
	border.active = true
	var rescued := _ring_people(20, 6.0)
	_block(border, Vector2(5.5, 0.0), Vector2(0.5, 0.5), false)
	border._assign_members(rescued)
	assert_int(border.post_count).is_equal(0)
	assert_int(border.member_count).is_equal(13)
	# The same block, now beautified and on the line: it is a post, and the loop needs three fewer members.
	border.buildings[0].beautified = true
	border._assign_members(rescued)
	assert_int(border.post_count).is_equal(1)
	assert_int(border.required_members()).is_equal(10)
	assert_int(border.member_count).is_equal(10)
	# With the post standing, the segments beside it (and the whole loop, with enough people) are not gaps.
	assert_int(border.gap_count()).is_equal(0)
	assert_bool(border.buildings[0].post).is_true()


func test_a_block_far_from_the_line_is_not_a_post() -> void:
	var border := _organic_border()
	border.polygon = Border.circle_polygon(Vector2.ZERO, 6.0, Config.BORDER_SAMPLES)
	border.active = true
	_block(border, Vector2(0.0, 0.0), Vector2(0.5, 0.5), true)
	border._assign_members(_ring_people(20, 6.0))
	assert_int(border.post_count).is_equal(0)


func test_the_landmark_counts_as_a_post_once_beautified() -> void:
	var border := _organic_border()
	border.polygon = Border.circle_polygon(Vector2.ZERO, 6.0, Config.BORDER_SAMPLES)
	border.active = true
	_block(border, Vector2(5.5, 0.0), Vector2(0.5, 0.5), true, true)
	border._assign_members(_ring_people(20, 6.0))
	assert_int(border.post_count).is_equal(1)


func test_a_segment_beside_a_post_is_never_a_gap() -> void:
	# Five slots at spacing 5 m are all gaps, except the two beside the anchored slot.
	var flags := Border.gap_flags(5.0, [true, true, true, true], [false, true, false, false])
	assert_array(flags).is_equal([false, false, true, true])


func test_a_dark_person_pressing_an_intact_line_is_pushed_out_and_drains_nobody() -> void:
	var border := _organic_border()
	border.polygon = Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	border.active = true
	var ring := _ring_people(14, 5.0)
	border._assign_members(ring)
	for m: Person in border.members:
		m.joy = 900.0
	var dark: Person = auto_free(Person.new())
	add_child(dark)
	dark.position = Vector3(5.8, 0.0, 0.33)
	dark.gloom = 1.0
	var people: Array[Person] = [dark]
	var before_x := dark.position.x
	border._press_darkness(people, 1.0, 1.0)
	assert_float(dark.position.x - before_x).is_equal_approx(Config.BORDER_PUSHBACK_SPEED, 0.02)
	for m: Person in border.members:
		assert_float(m.joy).is_equal(900.0)


func test_a_dark_person_pressing_a_gap_drains_the_nearest_member() -> void:
	var border := _organic_border()
	border.polygon = Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	border.active = true
	# Three members on a radius 5 loop are 10.5 m apart: every stretch is a gap.
	var ring: Array[Person] = []
	for i: int in range(3):
		var a := TAU * float(i) / 3.0
		var m: Person = _person_at(Vector3(cos(a) * 5.0, 0.0, sin(a) * 5.0))
		m.joy = 900.0
		ring.append(m)
	border._assign_members(ring)
	var dark: Person = auto_free(Person.new())
	add_child(dark)
	dark.position = Vector3(5.8, 0.0, 0.33)
	dark.gloom = 1.0
	var people: Array[Person] = [dark]
	border._press_darkness(people, 1.0, 1.0)
	assert_float(dark.position.x).is_equal_approx(5.8, 0.0001)
	var nearest: Person = ring[0]
	assert_float(nearest.joy).is_less(900.0)


func test_shove_bulges_the_line_toward_a_player_within_range_and_ignores_one_far_away() -> void:
	var border := _organic_border()
	border.polygon = Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	border.active = true
	var before: float = border._raw_radii[0]
	border.shove(Vector3(7.0, 0.0, 0.0))
	assert_float(border._raw_radii[0]).is_equal_approx(before + Config.BORDER_SHOVE_AMOUNT, 0.001)
	# Standing on the centre has no direction to shove in.
	border.polygon = Border.circle_polygon(Vector2.ZERO, 3.0, Config.BORDER_SAMPLES)
	border.shove(Vector3.ZERO)
	assert_float(border._raw_radii[0]).is_equal_approx(before + Config.BORDER_SHOVE_AMOUNT, 0.001)
	# Twenty metres away is out of range.
	border.shove(Vector3(20.0, 0.0, 0.0))
	assert_float(border._raw_radii[0]).is_equal_approx(before + Config.BORDER_SHOVE_AMOUNT, 0.001)


func test_the_loop_keeps_the_perimeter_at_three_metres_per_person_once_it_settles() -> void:
	var border := _organic_border()
	border._has_centre = true
	border.centre = Vector3.ZERO
	var rescued := _ring_people(10, 4.0)
	border.update(rescued, 1.0 / 60.0, 1.0)
	for i: int in range(300):
		border.update(rescued, 1.0 / 60.0, 1.0)
	assert_float(border.perimeter).is_greater(28.5)
	assert_float(border.perimeter).is_less(31.5)
