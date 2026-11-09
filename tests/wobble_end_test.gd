extends GdUnitTestSuite

# Round 24: how a wobble ends when something other than a joy hit or the relapse gate ends it.
#  - First light (Person.dawn_lit) has passed the person: the wobble ends quietly, with no relapse and no counted save.
#  - The person is no longer rescued: the wobble just stops, and the look's greying (wobble_progress) goes back to 0.


func _person(seed_id: int) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = 0
	p.gloom = 0.0
	p.look_seed = seed_id
	add_child(p)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	p.grace_left = 0.0
	return p


func _tick(p: Person, seconds: float) -> void:
	for i: int in range(int(seconds * 60.0)):
		p.tick(1.0 / 60.0)


# Drains a rescued person just below the relapse line so they begin to wobble.
func _start_wobble(p: Person) -> void:
	p.drain_joy(p.joy - p.joy_needed() * PeopleConfig.RELAPSE_FRACTION + 1.0)


func test_a_wobble_ends_safely_once_first_light_has_passed_the_person() -> void:
	var p := _person(6)
	var counts := [0, 0]
	p.saved.connect(func() -> void: counts[0] += 1)
	p.relapsed.connect(func() -> void: counts[1] += 1)
	_start_wobble(p)
	assert_bool(p.wobbling).is_true()
	p.dawn_lit = true  # The dawn front passes them mid-wobble (FirstLight sets this each frame).
	_tick(p, PeopleConfig.WOBBLE_SECONDS * 2.0)
	assert_bool(p.wobbling).is_false()
	assert_bool(p.is_rescued).is_true()
	assert_int(counts[1]).is_equal(0)
	assert_int(counts[0]).is_equal(0)  # A quiet end, not a counted save.
	assert_float(p.joy).is_greater_equal(
		p.joy_needed() * (PeopleConfig.RELAPSE_FRACTION + PeopleConfig.WOBBLE_SAVE_JOY) - 0.01
	)
	# A lit person does not drain, so no new wobble starts.
	p.drain_joy(500.0)
	assert_bool(p.wobbling).is_false()


func test_a_wobble_ends_without_a_relapse_if_the_person_is_no_longer_rescued() -> void:
	var p := _person(7)
	_start_wobble(p)
	assert_bool(p.wobbling).is_true()
	assert_float(p.wobble_progress()).is_greater_equal(0.0)
	p.is_rescued = false  # Lost some other way (not through the wobble's own relapse).
	p.tick(1.0 / 60.0)
	assert_bool(p.wobbling).is_false()
	# Not wobbling: no greying.
	assert_float(p.wobble_progress()).is_equal(0.0)
