extends GdUnitTestSuite

# Round 26: the crowd's separation uses a spatial grid and a cached index instead of checking every person against every
# other. The answer must be exactly the same as the all-pairs version (the determinism check depends on it).


func _start() -> TopDownMain:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(2)
	return runner.scene() as TopDownMain


# A fixed, crowded layout: everyone within a 9 m square (many neighbours), every third person dimmed, every seventh
# rescued, and two pairs standing exactly on the same spot.
func _crowd_layout(td: TopDownMain) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	for i: int in range(td.people.size()):
		var p: Person = td.people[i]
		var spot := Vector3(fmod(float(i) * 1.37, 9.0) - 4.5, 0.0, fmod(float(i) * 2.11, 9.0) - 4.5)
		if i == 11 or i == 31:
			spot = spots[i - 1]
		spots.append(spot)
		p.mood = Person.Mood.NONE
		p.is_rescued = i % 7 == 0
		p.gloom = 1.0 if i % 3 == 0 else 0.0
		p.global_position = spot
	return spots


func test_grid_separation_equals_all_pairs_for_every_person() -> void:
	var td: TopDownMain = await _start()
	_crowd_layout(td)
	td._crowd.rebuild_grid()
	var same := 0
	for p: Person in td.people:
		var fast: Vector3 = td._crowd._separation(p)
		var slow: Vector3 = td._crowd.separation_brute(p)
		assert_vector(fast).is_equal(slow)
		same += 1
	assert_int(same).is_equal(td.people.size())


func test_person_alone_is_not_pushed() -> void:
	var td: TopDownMain = await _start()
	_crowd_layout(td)
	var loner: Person = td.people[5]
	loner.global_position = Vector3(40, 0, 40)
	td._crowd.rebuild_grid()
	assert_vector(td._crowd._separation(loner)).is_equal(Vector3.ZERO)


func test_standalone_call_without_a_grid_uses_the_all_pairs_version() -> void:
	var td: TopDownMain = await _start()
	_crowd_layout(td)
	td._crowd._grid_live = false
	var p: Person = td.people[3]
	assert_vector(td._crowd._separation(p)).is_equal(td._crowd.separation_brute(p))
	td._crowd.brute_force = true
	td._crowd.rebuild_grid()
	assert_vector(td._crowd._separation(p)).is_equal(td._crowd.separation_brute(p))


func _walk(td: TopDownMain, start: Array[Vector3], frames: int) -> Array[Vector3]:
	for i: int in range(td.people.size()):
		td.people[i].global_position = start[i]
	td._crowd._wander.clear()
	td.plaza.rng.seed = 7
	for f: int in range(frames):
		td._crowd.update_people(0.016)
	var out: Array[Vector3] = []
	for p: Person in td.people:
		out.append(p.global_position)
	return out


func test_moving_the_crowd_gives_the_same_positions_with_the_grid() -> void:
	var td: TopDownMain = await _start()
	var start := _crowd_layout(td)
	td._crowd.brute_force = true
	var slow := _walk(td, start, 40)
	td._crowd.brute_force = false
	var fast := _walk(td, start, 40)
	for i: int in range(slow.size()):
		assert_vector(fast[i]).is_equal(slow[i])
	assert_bool(slow[1].is_equal_approx(start[1])).is_false()  # They really moved.


func test_regridding_without_a_live_grid_or_for_a_stranger_does_nothing() -> void:
	var td: TopDownMain = await _start()
	_crowd_layout(td)
	td._crowd._grid_live = false
	td._crowd._regrid(td.people[2])
	td._crowd.rebuild_grid()
	var stranger: Person = auto_free(Person.new())
	td._crowd._regrid(stranger)
	assert_bool(td._crowd._index.has(stranger)).is_false()
