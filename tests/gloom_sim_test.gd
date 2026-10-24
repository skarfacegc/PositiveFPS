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


func test_drain_multiplier_scales_the_drain_from_darkness() -> void:
	# Same setup twice, one second each: the top-down multiplier (0.5) drains half as much as the default (1.0).
	var full_rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var full_dark: Person = _make_person(1, Vector3(2, 0, 0), 1.0)
	var full_before: float = full_rescued.joy
	for i: int in range(60):
		GloomSim.update([full_rescued, full_dark], 1.0 / 60.0)
	var full_lost := full_before - full_rescued.joy

	var half_rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var half_dark: Person = _make_person(1, Vector3(2, 0, 0), 1.0)
	var half_before: float = half_rescued.joy
	for i: int in range(60):
		GloomSim.update([half_rescued, half_dark], 1.0 / 60.0, Config.TD_DRAIN_MULTIPLIER)
	var half_lost := half_before - half_rescued.joy

	assert_float(full_lost).is_greater(0.0)
	assert_float(half_lost).is_equal_approx(full_lost * Config.TD_DRAIN_MULTIPLIER, 0.01)


func test_gloom_still_grows_near_rescued_people_when_they_have_no_cover() -> void:
	# Round 9: there is no colour-zone heal any more. Without paint around them, a person near a rescued one grows.
	var rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var near: Person = _make_person(1, Vector3(3, 0, 0), 0.5)
	GloomSim.update([rescued, near], 1.0)
	assert_float(near.gloom).is_greater(0.5)


func test_gloom_grows_far_from_zones() -> void:
	var rescued: Person = _make_person(0, Vector3(0, 0, 0), 0.0, true)
	var far: Person = _make_person(1, Vector3(50, 0, 0), 0.2)
	GloomSim.update([rescued, far], 1.0)
	assert_float(far.gloom).is_greater(0.2)


# Round 11: with nobody rescued and no cover, a person grows at the base rate plus the far-from-zones rate
# (NO_ZONE_DISTANCE). Light grey -> grey is unchanged; grey -> dark is slowed by GLOOM_DARK_STEP_MULT.
func test_the_grey_to_dark_step_grows_slower_and_light_to_grey_does_not() -> void:
	var base := Config.GLOOM_GROWTH + Config.GLOOM_GROWTH_PER_METER * Config.NO_ZONE_DISTANCE
	var light: Person = _make_person(1, Vector3(100, 0, 0), 0.2)
	var grey: Person = _make_person(1, Vector3(-100, 0, 0), 0.5)
	GloomSim.update([light], 1.0)
	GloomSim.update([grey], 1.0)
	var light_gain := light.gloom - 0.2
	var grey_gain := grey.gloom - 0.5
	assert_float(light_gain).is_equal_approx(base, 0.0001)
	assert_float(grey_gain).is_equal_approx(base * Config.GLOOM_DARK_STEP_MULT, 0.0001)
	assert_float(Config.GLOOM_DARK_STEP_MULT).is_equal_approx(0.65, 0.0001)
	assert_float(grey_gain).is_less(light_gain)


func test_flat_dist_ignores_height() -> void:
	assert_float(GloomSim.flat_dist(Vector3(3, 5, 4), Vector3.ZERO)).is_equal_approx(5.0, 0.0001)
	assert_float(GloomSim.flat_dist(Vector3(1, 100, 1), Vector3(1, -50, 1))).is_equal_approx(0.0, 0.0001)


func test_nearest_distance_helper() -> void:
	var points := [Vector3(3, 0, 4), Vector3(10, 0, 0)]
	assert_float(GloomSim.nearest_distance(Vector3.ZERO, points)).is_equal_approx(5.0, 0.0001)
	assert_float(GloomSim.nearest_distance(Vector3.ZERO, [])).is_equal(INF)
