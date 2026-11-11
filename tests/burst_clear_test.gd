extends GdUnitTestSuite

# Round 24: the joy burst pushes a dimmed person who stands within BURST_BORDER_BAND of the border line away from it.
# 0.4: they are pushed out through the nearest gate (its outward normal). This suite pins that with a standalone border
# (as border_shape_test.gd does) holding the start square.


# A dimmed person at `pos` (only dimmed people are lifted by the burst), in the tree so global_position works.
func _dimmed_at(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = 0
	p.gloom = 0.95
	add_child(p)
	p.global_position = pos
	return p


func test_a_dimmed_person_inside_by_a_gate_is_pushed_out_through_it() -> void:
	var border := TopDownTestUtil.bare_border(self)
	# A metre inside the east gate (x = 9): within the 3.5 m band.
	var spot := Vector3(8.0, 0.0, 0.0)
	assert_float(BurstClear.distance_to_line(border, spot)).is_less_equal(SpiritConfig.BURST_BORDER_BAND)
	var person := _dimmed_at(spot)
	assert_bool(BurstClear.is_at_border(border, person.global_position)).is_true()
	var people: Array[Person] = [person]
	var report := BurstClear.run(people, spot, border)
	assert_int(report["lifted"]).is_equal(1)
	var moved: Dictionary = report["cleared"][0]
	var to: Vector3 = moved["to"]
	# Along +X only (the gate's normal), and out past the line: the push distance plus the depth inside it (1 m).
	assert_float(to.z).is_equal_approx(0.0, 0.001)
	assert_float(to.x).is_equal_approx(8.0 + SpiritConfig.BURST_PUSH_DISTANCE + 1.0, 0.05)
	assert_vector(person.global_position).is_equal_approx(to, Vector3(0.001, 0.001, 0.001))
	# And lifted like any other target: no longer dimmed.
	assert_bool(GloomSim.is_dimmed(person)).is_false()


func test_a_dimmed_person_outside_a_gate_is_pushed_further_out() -> void:
	var border := TopDownTestUtil.bare_border(self)
	var outside := _dimmed_at(Vector3(-10.0, 0.0, 2.0))
	var far := _dimmed_at(Vector3(1.0, 0.0, 0.0))  # The middle of the square: far from every gate, so not moved.
	var people: Array[Person] = [outside, far]
	var report := BurstClear.run(people, Vector3(-10.0, 0.0, 2.0), border)
	var moved: Dictionary = report["cleared"][0]
	var to: Vector3 = moved["to"]
	assert_float(to.x).is_equal_approx(-10.0 - SpiritConfig.BURST_PUSH_DISTANCE, 0.05)  # Out of the west gate.
	assert_float(to.z).is_equal_approx(2.0, 0.001)
	assert_vector(far.global_position).is_equal(Vector3(1.0, 0.0, 0.0))
