extends GdUnitTestSuite

# Round 19: the landmarks (bandstand, garden, bell tower; 0.3.3: and the gallery) and the boosts they give while held.


func _landmarks() -> Landmarks:
	var lms: Landmarks = auto_free(Landmarks.new())
	add_child(lms)
	lms.build()
	return lms


func _person(affinity: int = 0) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = affinity
	return p


# Holds landmark `index` (its block beautified for the whole claim hold).
func _hold(lms: Landmarks, index: int) -> void:
	lms.items[index].update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)


# --- Where they stand -----------------------------------------------------------------------------------------------


func test_there_are_four_landmarks_with_names_boosts_and_a_short_hold() -> void:
	assert_int(LandmarkConfig.LANDMARK_NAMES.size()).is_equal(4)
	assert_int(LandmarkConfig.LANDMARK_POSITIONS.size()).is_equal(4)
	assert_int(LandmarkConfig.LANDMARK_SIZES.size()).is_equal(4)
	assert_int(LandmarkConfig.LANDMARK_COLOURS.size()).is_equal(4)
	assert_int(LandmarkConfig.LANDMARK_BOOST_TEXT.size()).is_equal(4)
	assert_str(LandmarkConfig.LANDMARK_NAMES[Landmarks.GALLERY]).is_equal("Gallery")
	assert_float(LandmarkConfig.BORDER_LANDMARK_HOLD).is_between(2.0, 4.0)
	assert_float(LandmarkConfig.LANDMARK_MUSIC_MULT).is_equal(2.0)
	assert_float(LandmarkConfig.LANDMARK_NATURE_MULT).is_equal(2.0)
	assert_float(LandmarkConfig.LANDMARK_BELL_LOSS_MULT).is_equal(0.4)


func test_landmarks_are_inside_the_map_clear_of_blocks_and_each_other_and_near_the_start() -> void:
	var lim := BorderConfig.BORDER_MAP_LIMIT
	var count := LandmarkConfig.LANDMARK_POSITIONS.size()
	for i: int in range(count):
		var at := LandmarkConfig.LANDMARK_POSITIONS[i]
		var half := LandmarkConfig.LANDMARK_SIZES[i].x * 0.5
		# Inside the map, with the whole block on the floor.
		assert_float(absf(at.x) + half).is_less(lim)
		assert_float(absf(at.z) + half).is_less(lim)
		# 0.4 (#55): every landmark stands in the middle of a square on a diagonal next to the start, about 31 m away.
		var d := Vector2(at.x, at.z).length()
		assert_float(d).is_between(30.0, 32.0)
		# Clear of every ordinary block (a block is 12 wide and stands in its own cell) and of each other.
		for block: Vector3 in Plaza.BLOCK_POSITIONS:
			assert_float(Vector2(at.x - block.x, at.z - block.z).length()).is_greater_equal(22.0 - 0.001)
		for j: int in range(i + 1, count):
			var other := LandmarkConfig.LANDMARK_POSITIONS[j]
			assert_float(Vector2(at.x - other.x, at.z - other.z).length()).is_greater_equal(44.0 - 0.001)


func test_the_landmarks_stand_in_their_own_squares_one_on_each_diagonal_of_the_start() -> void:
	var sides := {}
	for at: Vector3 in LandmarkConfig.LANDMARK_POSITIONS:
		# In the middle of a square, off every street.
		assert_bool(TownLayout.on_street(at)).is_false()
		assert_bool(TownGrid.is_block(TownGrid.cell_of(at))).is_false()
		sides[Vector2i(int(signf(at.x)), int(signf(at.z)))] = true
	assert_int(sides.size()).is_equal(4)


func test_the_level_builds_a_block_and_a_building_for_each_landmark() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	assert_int(td.landmarks.items.size()).is_equal(4)
	assert_int(td.border.landmark_buildings.size()).is_equal(4)
	for i: int in range(4):
		var at := LandmarkConfig.LANDMARK_POSITIONS[i]
		assert_vector(td.border.landmark_buildings[i].centre).is_equal(Vector2(at.x, at.z))
		assert_vector(td.landmarks.items[i].position).is_equal(at)
		assert_str(td.landmarks.items[i].landmark_name()).is_equal(LandmarkConfig.LANDMARK_NAMES[i])
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Claiming and losing --------------------------------------------------------------------------------------------


func test_a_landmark_is_claimed_after_the_hold_and_lost_the_moment_the_border_drops_it() -> void:
	var lms := _landmarks()
	for i: int in range(4):
		var lm := lms.items[i]
		var log: Array[String] = []
		lm.claimed.connect(func() -> void: log.append("claimed"))
		lm.lost.connect(func() -> void: log.append("lost"))
		lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD - 0.1, true)
		assert_bool(lm.is_held()).is_false()
		lm.update(0.2, true)
		assert_bool(lm.is_held()).is_true()
		lm.update(1.0, true)
		lm.update(0.1, false)
		assert_bool(lm.is_held()).is_false()
		assert_array(log).is_equal(["claimed", "lost"])


func test_the_panel_lists_only_held_landmarks_with_their_boosts() -> void:
	var lms := _landmarks()
	assert_array(lms.held_lines()).is_empty()
	_hold(lms, Landmarks.GARDEN)
	assert_array(lms.held_lines()).is_equal(["Garden: nature x2"])
	_hold(lms, Landmarks.BANDSTAND)
	assert_array(lms.held_lines()).is_equal(["Bandstand: music x2", "Garden: nature x2"])
	assert_int(lms.held_count()).is_equal(2)
	assert_array(lms.held_flags()).is_equal([true, true, false, false])


# --- The boosts -----------------------------------------------------------------------------------------------------


func _joy_gain(p: Person, element: int) -> float:
	p.joy = 0.0
	p.receive_joy(element, 10.0, 0.0)
	return p.joy


func test_the_bandstand_boosts_music_joy_only_while_held() -> void:
	var lms := _landmarks()
	var border: Border = auto_free(Border.new())
	var p := _person(0)
	var people: Array[Person] = [p]
	lms.apply_boosts(people, border)
	var base := _joy_gain(p, Config.Element.MUSIC)
	_hold(lms, Landmarks.BANDSTAND)
	lms.apply_boosts(people, border)
	assert_float(_joy_gain(p, Config.Element.MUSIC)).is_equal_approx(base * 2.0, 0.0001)
	# Other elements are not boosted.
	var art_base := _joy_gain(_person(0), Config.Element.ART)
	assert_float(_joy_gain(p, Config.Element.ART)).is_equal_approx(art_base, 0.0001)
	# Lost: back to normal.
	lms.items[Landmarks.BANDSTAND].update(0.1, false)
	lms.apply_boosts(people, border)
	assert_float(_joy_gain(p, Config.Element.MUSIC)).is_equal_approx(base, 0.0001)


func test_the_garden_boosts_nature_joy_only_while_held() -> void:
	var lms := _landmarks()
	var border: Border = auto_free(Border.new())
	var p := _person(2)
	var people: Array[Person] = [p]
	lms.apply_boosts(people, border)
	var base := _joy_gain(p, Config.Element.NATURE)
	_hold(lms, Landmarks.GARDEN)
	lms.apply_boosts(people, border)
	assert_float(_joy_gain(p, Config.Element.NATURE)).is_equal_approx(base * 2.0, 0.0001)
	# The bandstand being unheld leaves music alone.
	var music_base := _joy_gain(_person(2), Config.Element.MUSIC)
	assert_float(_joy_gain(p, Config.Element.MUSIC)).is_equal_approx(music_base, 0.0001)
	lms.items[Landmarks.GARDEN].update(0.1, false)
	lms.apply_boosts(people, border)
	assert_float(_joy_gain(p, Config.Element.NATURE)).is_equal_approx(base, 0.0001)


func test_the_bell_tower_cuts_the_loss_of_border_members_near_it_only_while_held() -> void:
	var lms := _landmarks()
	var border: Border = auto_free(Border.new())
	var bell := LandmarkConfig.LANDMARK_POSITIONS[Landmarks.BELL_TOWER]
	var near := _person()
	var far := _person()
	var outsider := _person()
	near.position = bell + Vector3(LandmarkConfig.LANDMARK_BELL_RADIUS - 1.0, 0.0, 0.0)
	far.position = bell + Vector3(LandmarkConfig.LANDMARK_BELL_RADIUS + 3.0, 0.0, 0.0)
	outsider.position = bell
	border.members = [near, far]
	var people: Array[Person] = [near, far, outsider]
	for p: Person in people:
		p.is_rescued = true
		p.joy = 900.0
	lms.apply_boosts(people, border)
	assert_float(near.loss_mult).is_equal(1.0)
	_hold(lms, Landmarks.BELL_TOWER)
	lms.apply_boosts(people, border)
	assert_float(near.loss_mult).is_equal(0.4)
	assert_float(far.loss_mult).is_equal(1.0)  # too far from the bell
	assert_float(outsider.loss_mult).is_equal(1.0)  # at the bell, but not a border member
	near.drain_joy(10.0)
	far.drain_joy(10.0)
	assert_float(near.joy).is_equal_approx(896.0, 0.001)
	assert_float(far.joy).is_equal_approx(890.0, 0.001)
	lms.items[Landmarks.BELL_TOWER].update(0.1, false)
	lms.apply_boosts(people, border)
	assert_float(near.loss_mult).is_equal(1.0)


# --- In the level ---------------------------------------------------------------------------------------------------


func test_a_dim_player_recovers_near_each_landmark_before_a_border_exists() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	for at: Vector3 in LandmarkConfig.LANDMARK_POSITIONS:
		td.player.global_position = Vector3(at.x, 0.0, at.z + 4.0)
		assert_float(td.dim_recovery.rate()).is_equal(SpiritConfig.DIM_RECOVER_RATE)
		td.player.global_position = Vector3(at.x, 0.0, at.z + SpiritConfig.LANDMARK_RECOVER_RADIUS + 6.0)
		assert_float(td.dim_recovery.rate()).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_holding_the_garden_square_claims_it_and_the_hud_panel_and_boost_follow() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	for i: int in range(3):
		var a := TAU * float(i) / 3.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	# 0.4: a landmark is held with its square: the zone takes the block west of the start, then the Garden square
	# north of it.
	td.border.zone.take(Vector2i(1, 2))
	td.border.zone.take(TownConfig.TOWN_LANDMARK_CELLS[Landmarks.GARDEN])
	var frames := 0
	while not td.landmarks.is_held(Landmarks.GARDEN) and frames < 1500:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(td.landmarks.is_held(Landmarks.GARDEN)).is_true()
	await runner.simulate_frames(3)
	assert_str(td.hud.landmark_label.text).contains("Landmarks 1 of 4")
	assert_str(td.hud.landmark_label.text).contains("Garden: nature x2")
	assert_float(td.people[10].joy_boost[Config.Element.NATURE]).is_equal(2.0)
	assert_float(td.people[10].joy_boost[Config.Element.MUSIC]).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)
