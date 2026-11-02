extends GdUnitTestSuite

# Round 24: the joy burst pushes a dimmed person who stands within BURST_BORDER_BAND of the border line away from it.
# A person exactly on the border's centre has no direction to be pushed in, so BurstClear falls back to +X. This suite
# pins that fallback with a standalone border (as border_shape_test.gd does): a real level's centre sits about 6 m
# from its line, outside the band, so the centre case cannot be reached through a level.


# A border whose loop is a circle of `radius` around the origin, active, with no level around it.
func _border(radius: float) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = BorderShape.circle_polygon(Vector2.ZERO, radius, Config.BORDER_SAMPLES)
	border.active = true
	return border


# A dimmed person at `pos` (only dimmed people are lifted by the burst), in the tree so global_position works.
func _dimmed_at(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = 0
	p.gloom = 0.95
	add_child(p)
	p.global_position = pos
	return p


func test_a_dimmed_person_on_the_border_centre_is_pushed_along_plus_x() -> void:
	# A 2 m circle: the centre is inside the loop and about 2 m from the line, well within the 3.5 m band.
	var border := _border(2.0)
	assert_float(BurstClear.distance_to_line(border, Vector3.ZERO)).is_less_equal(Config.BURST_BORDER_BAND)
	var centre := _dimmed_at(Vector3.ZERO)
	assert_bool(BurstClear.is_at_border(border, centre.global_position)).is_true()
	var people: Array[Person] = [centre]
	var report := BurstClear.run(people, Vector3.ZERO, border)
	assert_int(report["lifted"]).is_equal(1)
	var moved: Dictionary = report["cleared"][0]
	var to: Vector3 = moved["to"]
	# Along +X only, and out past the line: the push distance plus the depth inside the 2 m loop (about 2 m).
	assert_float(to.z).is_equal_approx(0.0, 0.001)
	assert_float(to.x).is_greater(0.0)
	assert_float(to.x).is_equal_approx(Config.BURST_PUSH_DISTANCE + 2.0, 0.05)
	assert_vector(centre.global_position).is_equal_approx(to, Vector3(0.001, 0.001, 0.001))
	# And lifted like any other target: no longer dimmed.
	assert_bool(GloomSim.is_dimmed(centre)).is_false()
