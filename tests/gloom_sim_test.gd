extends GdUnitTestSuite

# Gloom rules: spreading darkness, drained joy, zone healing and growth far from zones.


func _make_person(affinity: int, pos: Vector3, gloom: float, rescued: bool = false) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = affinity
	p.gloom = gloom
	add_child(p)
	p.global_position = pos
	if rescued:
		p.receive_joy(affinity, Config.JOY_MAX, 0.0)
	return p


func test_dark_person_raises_nearby_gloom_more_than_far() -> void:
	var dark: Person = _make_person(0, Vector3(0, 0, 0), 1.0)
	var near_light: Person = _make_person(1, Vector3(2, 0, 0), 0.0)
	var far_light: Person = _make_person(1, Vector3(40, 0, 0), 0.0)
	GloomSim.update([dark, near_light, far_light], 1.0)
	assert_float(near_light.gloom).is_greater(far_light.gloom)
	assert_float(near_light.gloom).is_greater(0.0)


func test_dark_person_drains_rescued_joy() -> void:
	var rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var dark: Person = _make_person(1, Vector3(2, 0, 0), 1.0)
	var before: float = rescued.joy
	GloomSim.update([rescued, dark], 0.1)
	assert_float(rescued.joy).is_less(before)


func test_zone_heals_nearby_gloom() -> void:
	var rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var near: Person = _make_person(1, Vector3(3, 0, 0), 0.5)
	GloomSim.update([rescued, near], 1.0)
	assert_float(near.gloom).is_less(0.5)


func test_gloom_grows_far_from_zones() -> void:
	var rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var far: Person = _make_person(1, Vector3(50, 0, 0), 0.2)
	GloomSim.update([rescued, far], 1.0)
	assert_float(far.gloom).is_greater(0.2)


func test_flat_dist_ignores_height() -> void:
	assert_float(GloomSim.flat_dist(Vector3(3, 5, 4), Vector3.ZERO)).is_equal_approx(5.0, 0.0001)
	assert_float(GloomSim.flat_dist(Vector3(1, 100, 1), Vector3(1, -50, 1))).is_equal_approx(0.0, 0.0001)


func test_nearest_distance_helper() -> void:
	var points := [Vector3(3, 0, 4), Vector3(10, 0, 0)]
	assert_float(GloomSim.nearest_distance(Vector3.ZERO, points)).is_equal_approx(5.0, 0.0001)
	assert_float(GloomSim.nearest_distance(Vector3.ZERO, [])).is_equal(INF)
