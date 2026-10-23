extends GdUnitTestSuite

# Person rules: joy, rescue, relapse, warnings and visual moments. Created directly (no player input).


func _make_person(affinity: int, pos: Vector3 = Vector3.ZERO, gloom: float = 0.0) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = affinity
	p.gloom = gloom
	add_child(p)
	p.global_position = pos
	return p


func _shots_to_rescue(p: Person, element: int, cap: int = 200) -> int:
	for i: int in range(cap):
		p.receive_joy(element, Config.JOY_PER_SHOT, 0.0)
		if p.is_rescued:
			return i + 1
	return -1


func test_matched_element_rescues_in_fewer_shots_than_weak() -> void:
	var matched: Person = _make_person(0)
	var weak: Person = _make_person(0)
	var n_matched := _shots_to_rescue(matched, 0)
	var n_weak := _shots_to_rescue(weak, 1)  # Art is weak against Music.
	assert_int(n_matched).is_greater(0)
	assert_int(n_weak).is_greater(n_matched)


func test_rescued_signal_fires_once() -> void:
	var p: Person = _make_person(1)
	var count := [0]
	p.rescued.connect(func() -> void: count[0] += 1)
	for i: int in range(60):
		p.receive_joy(1, Config.JOY_PER_SHOT, 0.0)
	assert_bool(p.is_rescued).is_true()
	assert_int(count[0]).is_equal(1)


func test_darker_level_needs_more_joy() -> void:
	assert_float(_make_person(0, Vector3.ZERO, 0.0).joy_needed()).is_equal_approx(Config.JOY_MAX, 0.001)
	assert_float(_make_person(0, Vector3.ZERO, 0.5).joy_needed()).is_equal_approx(Config.JOY_MAX * 1.5, 0.001)
	assert_float(_make_person(0, Vector3.ZERO, 0.9).joy_needed()).is_equal_approx(Config.JOY_MAX * 2.0, 0.001)


func test_joy_fades_only_after_delay() -> void:
	var p: Person = _make_person(0)
	p.joy = 500.0
	p.receive_joy(0, 0.0, 0.0)  # Zero-gain hit: resets the time since last hit.
	var t := 0.0
	while t < Config.JOY_FADE_DELAY - 0.2:
		p.tick(0.1)
		t += 0.1
	assert_float(p.joy).is_equal_approx(500.0, 0.001)
	for i: int in range(30):
		p.tick(0.1)
	assert_float(p.joy).is_less(500.0)


func test_drain_relapses_rescued_person() -> void:
	var p: Person = _make_person(2)
	p.receive_joy(2, Config.JOY_MAX, 0.0)
	assert_bool(p.is_rescued).is_true()
	var relapses := [0]
	p.relapsed.connect(func() -> void: relapses[0] += 1)
	p.drain_joy(Config.JOY_MAX * 0.7)
	assert_int(relapses[0]).is_equal(1)
	assert_bool(p.is_rescued).is_false()


func test_warning_between_relapse_and_warn_fractions() -> void:
	var p: Person = _make_person(0)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	assert_bool(p.is_warning()).is_false()
	p.drain_joy(300.0)  # 700 left: below WARN (850), above RELAPSE (500).
	assert_bool(p.is_rescued).is_true()
	assert_bool(p.is_warning()).is_true()


func test_rescued_person_can_be_topped_up() -> void:
	var p: Person = _make_person(0)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	p.drain_joy(300.0)
	var before: float = p.joy
	p.receive_joy(0, Config.JOY_PER_SHOT, 0.0)
	assert_float(p.joy).is_greater(before)
	assert_bool(p.is_rescued).is_true()


func test_level_changes_run_without_errors() -> void:
	var p: Person = _make_person(1, Vector3.ZERO, 0.1)
	p.gloom = 0.7
	p.tick(0.1)
	assert_int(p.level).is_equal(2)
	p.gloom = 0.1
	p.tick(0.1)
	assert_int(p.level).is_equal(0)
	await get_tree().process_frame


func test_each_hit_tier_adds_joy_and_numbers() -> void:
	# Affinity Music: Music matches, Nature is strong against it, Art is weak.
	var p: Person = _make_person(0)
	p.receive_joy(0, Config.JOY_PER_SHOT, 0.0)
	var after_match: float = p.joy
	p.receive_joy(2, Config.JOY_PER_SHOT, 0.0)
	var after_strong: float = p.joy
	p.receive_joy(1, Config.JOY_PER_SHOT, 0.0)
	assert_float(after_match).is_greater(0.0)
	assert_float(after_strong).is_greater(after_match)
	assert_float(p.joy).is_greater(after_strong)
	await get_tree().process_frame
