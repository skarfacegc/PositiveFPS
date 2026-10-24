extends GdUnitTestSuite

# Painted ground. MultiMesh colour readback returns zeros under the headless renderer, so these tests
# assert on PaintedGround's CPU-side colour array (_colors), which is the same data sent to the MultiMesh.


func test_rescued_person_paints_nearby_tiles_and_leaves_far_corner_grey() -> void:
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(10)

	var p: Person = auto_free(Person.new())
	p.affinity = 0
	add_child(p)
	p.global_position = Vector3.ZERO
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	assert_bool(p.is_rescued).is_true()

	var people := [p]
	for i: int in range(80):
		ground.update_paint(people, 0.11)

	# Tile (ix=4, iz=4) is centred at (-0.5, 0, -0.5): next to the origin, full strength.
	var expected: Color = Config.GROUND_GREY.lerp(Config.ELEMENT_COLORS[0], Config.GROUND_PAINT_STRENGTH)
	var near: Color = ground._colors[4 * 10 + 4]
	assert_float(near.r).is_equal_approx(expected.r, 0.01)
	assert_float(near.g).is_equal_approx(expected.g, 0.01)
	assert_float(near.b).is_equal_approx(expected.b, 0.01)

	# Tile (ix=0, iz=0) is about 6.4 m away: outside the paint radius, so still grey.
	var far: Color = ground._colors[0]
	assert_float(far.r).is_equal_approx(Config.GROUND_GREY.r, 0.001)
	assert_float(far.g).is_equal_approx(Config.GROUND_GREY.g, 0.001)
	assert_float(far.b).is_equal_approx(Config.GROUND_GREY.b, 0.001)


# Round 10: the minimap reads the colour each tile is showing. Off the grid it is grey.
func test_paint_colour_at_shows_the_tile_colour_and_grey_off_the_grid() -> void:
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(10)
	assert_bool(ground.paint_colour_at(Vector3.ZERO).is_equal_approx(Config.GROUND_GREY)).is_true()
	assert_bool(ground.paint_colour_at(Vector3(50.0, 0.0, 0.0)).is_equal_approx(Config.GROUND_GREY)).is_true()
