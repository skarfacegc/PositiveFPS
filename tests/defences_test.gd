# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Walls and gates: Defences (F, #15 and #16) and the people line (#75). Hold F, point at a gate, release to plant a
# defence staffed by the nearest free member; a type is unlocked by claiming its landmark; the wheel picks the type
# while F is held; a defence whose gate closes is handed back. What the modifiers do to the push belongs to the border
# (the tests here check that the right modifiers are set). The key, wheel and right-click inputs are real events.


func _level(people: int = 30) -> Dictionary:
	return await TopDownTestUtil.settled_level(self, people, 200)


# The middle of gate `g` as a ground point.
func _mid(td: TopDownMain, g: int) -> Vector3:
	var mid: Vector2 = td.border.zone.gates[g]["mid"]
	return Vector3(mid.x, 0.0, mid.y)


func _point_at_gate(runner: GdUnitSceneRunner, td: TopDownMain, g: int) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, _mid(td, g)))
	await runner.simulate_frames(3)


func _reasons(td: TopDownMain) -> Array[String]:
	var out: Array[String] = []
	td.defences.refused.connect(func(reason: String, _info: Dictionary) -> void: out.append(reason))
	return out


# ---- the people numbers -------------------------------------------------------------------------------------------


func test_the_people_numbers_say_short_spare_and_staffed_plainly() -> void:
	var short := Defences.count_people(31, 0, 54)
	assert_int(short["on_line"]).is_equal(31)
	assert_int(short["short"]).is_equal(23)
	assert_int(short["spare"]).is_equal(0)
	assert_str(Defences.people_text(short)).is_equal("People: 31 on the line, 23 short")
	var spare := Defences.count_people(60, 0, 54)
	assert_str(Defences.people_text(spare)).is_equal("People: 54 on the line, 6 spare")
	var exact := Defences.count_people(54, 0, 54)
	assert_str(Defences.people_text(exact)).is_equal("People: 54 on the line, none spare")
	var staffed := Defences.count_people(60, 2, 54)
	assert_int(staffed["available"]).is_equal(58)
	assert_str(Defences.people_text(staffed)).is_equal("People: 54 on the line, 4 spare, 2 on defences")
	assert_int(Defences.count_people(1, 3, 5)["available"]).is_equal(0)


func test_the_hud_line_under_the_spirit_meter_shows_the_numbers_in_red_when_short() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	await runner.simulate_frames(5)
	var need := td.border.zone.members_needed()
	assert_str(td.hud.people_label.text).is_equal("People: 0 on the line, %d short" % need)
	assert_object(td.hud.people_label.get_theme_color("font_color")).is_equal(BorderConfig.GATE_COUNT_SHORT_COLOUR)
	assert_bool(td.hud.layout_controls().has(td.hud.people_label)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_hud_line_counts_spare_people_once_the_line_is_full() -> void:
	var s: Dictionary = await _level(60)
	var td: TopDownMain = s["td"]
	var need := td.border.zone.members_needed()
	await (s["runner"] as GdUnitSceneRunner).simulate_frames(5)
	var text := td.hud.people_label.text
	assert_str(text).is_equal(Defences.people_text(td.defences.people_numbers()))
	assert_bool(60 > need).is_equal(text.contains("spare"))
	assert_object(td.hud.people_label.get_theme_color("font_color")).is_equal(
		BorderConfig.GATE_COUNT_SHORT_COLOUR if 60 < need else BorderConfig.GATE_COUNT_OK_COLOUR
	)
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- the border's gate modifiers (the minimal version Defences needs) ----------------------------------------------


func test_gate_modifiers_default_to_plain_are_kept_by_gate_and_go_when_the_gate_closes() -> void:
	var border := TopDownTestUtil.bare_border(self)
	var plain := {"strength_mult": 1.0, "cannot_break": false, "cannot_lose": false}
	assert_dict(border.gate_modifiers(0)).is_equal(plain)
	assert_dict(border.gate_modifiers(99)).is_equal(plain)
	border.set_gate_modifiers(99, {"cannot_break": true})  # No such gate: ignored.
	border.set_gate_modifiers(0, {"cannot_break": true, "strength_mult": 1.5})
	assert_bool(border.gate_modifiers(0)["cannot_break"] as bool).is_true()
	assert_float(border.gate_modifiers(0)["strength_mult"] as float).is_equal(1.5)
	assert_dict(border.gate_modifiers(1)).is_equal(plain)
	border.set_gate_modifiers(0, {})
	assert_dict(border.gate_modifiers(0)).is_equal(plain)
	# A modifier goes with its gate when the gate closes, and the border says which id it had.
	var cell := TownGrid.neighbours(TownGrid.start_cell())[0]
	var closing: Array = border.zone.preview(cell, true)["closed"]
	var key: String = (closing[0] as Dictionary)["key"]
	var id := -1
	for g: int in range(border.zone.gates.size()):
		if border.zone.gates[g]["key"] == key:
			id = g
	border.set_gate_modifiers(id, {"cannot_lose": true})
	var closed: Array[int] = []
	border.gate_closed.connect(func(g: int) -> void: closed.append(g))
	border.zone.take(cell)
	border._trace()
	assert_array(closed).is_equal([id])
	for g: int in range(border.zone.gates.size()):
		assert_bool(border.gate_modifiers(g)["cannot_lose"] as bool).is_false()


# ---- unlocking ----------------------------------------------------------------------------------------------------


func test_claiming_a_landmark_unlocks_its_defence_for_the_night_and_the_latest_is_the_default() -> void:
	var s: Dictionary = await _level(5)
	var td: TopDownMain = s["td"]
	var seen: Array[int] = []
	td.landmarks.defence_unlocked.connect(func(i: int) -> void: seen.append(i))
	assert_array(td.landmarks.unlocked_types()).is_empty()
	assert_int(td.landmarks.last_unlocked()).is_equal(-1)
	# Hold the garden's block beautified for the whole claim hold: the claim unlocks the Garden.
	td.border.landmark_buildings[Landmarks.GARDEN].beautified = true
	td.landmarks.update(LandmarkConfig.BORDER_LANDMARK_HOLD, td.border)
	assert_bool(td.landmarks.is_unlocked(Landmarks.GARDEN)).is_true()
	assert_int(td.landmarks.last_unlocked()).is_equal(Landmarks.GARDEN)
	# Losing it again keeps the defence for the rest of the night.
	td.border.landmark_buildings[Landmarks.GARDEN].beautified = false
	td.landmarks.update(0.1, td.border)
	assert_bool(td.landmarks.is_held(Landmarks.GARDEN)).is_false()
	assert_bool(td.landmarks.is_unlocked(Landmarks.GARDEN)).is_true()
	assert_bool(td.landmarks.unlock(Landmarks.GARDEN)).is_false()  # Once only.
	assert_bool(td.landmarks.unlock(Landmarks.BANDSTAND)).is_true()
	assert_bool(td.landmarks.unlock(9)).is_false()
	assert_array(td.landmarks.unlocked_types()).is_equal([Landmarks.BANDSTAND, Landmarks.GARDEN])
	assert_int(td.landmarks.last_unlocked()).is_equal(Landmarks.BANDSTAND)
	assert_array(seen).is_equal([Landmarks.GARDEN, Landmarks.BANDSTAND])
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- planting ------------------------------------------------------------------------------------------------------


func test_a_plant_needs_an_unlocked_type_a_gate_a_free_gate_and_a_free_member() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	var reasons := _reasons(td)
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_false()  # Nothing unlocked.
	assert_str(td.intro.current_text()).is_equal(DefenceConfig.REFUSE_NO_TYPE)
	assert_bool(td.intro.coral).is_true()
	td.landmarks.unlock(Landmarks.GARDEN)
	assert_bool(td.defences.plant_now(-1, Landmarks.GARDEN)).is_false()  # No gate pointed at.
	assert_bool(td.defences.plant_now(0, -1)).is_false()
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_false()  # Nobody is rescued: no free member.
	assert_str(td.intro.current_text()).is_equal(DefenceConfig.REFUSE_NO_MEMBER)
	assert_array(reasons).is_equal(["no_type", "no_gate", "no_type", "no_member"])
	assert_int(td.defences.posts.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_defence_is_staffed_by_the_nearest_free_member_who_leaves_the_line() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	var expect := td.defences.free_member_for(1)
	assert_object(expect).is_not_null()
	for m: Person in td.border.members:  # Nobody on the line is nearer to gate 1's middle.
		var mid := _mid(td, 1)
		assert_float(m.position.distance_to(mid)).is_greater_equal(expect.position.distance_to(mid) - 0.001)
	var planted: Array[Dictionary] = []
	td.defences.planted.connect(func(info: Dictionary) -> void: planted.append(info))
	var members_before := td.border.members.size()
	assert_bool(td.defences.plant_now(1, Landmarks.GARDEN)).is_true()
	assert_array(planted).has_size(1)
	assert_str(planted[0]["kind"] as String).is_equal("Garden")
	assert_int(planted[0]["staff"] as int).is_equal(td.people.find(expect))
	assert_bool(td.intro.coral).is_false()
	assert_str(td.intro.current_text()).contains("Garden")
	await runner.simulate_frames(240)
	assert_bool(td.border.members.has(expect)).is_false()
	assert_bool(td.border.inner.has(expect)).is_false()
	# A spare person takes the staff's place on the line when there is one.
	assert_int(td.border.members.size()).is_equal(mini(members_before, 29))
	# The staff stand at the post (just inside the middle of the gate).
	assert_float(expect.position.distance_to(td.defences.staff_position(1))).is_less(0.5)
	# The people line counts them apart.
	assert_int(td.defences.people_numbers()["staffed"] as int).is_equal(1)
	assert_str(td.hud.people_label.text).ends_with("1 on defences")
	# One per gate.
	var reasons := _reasons(td)
	assert_bool(td.defences.plant_now(1, Landmarks.GARDEN)).is_false()
	assert_array(reasons).is_equal(["gate_defended"])
	assert_str(td.intro.current_text()).is_equal(DefenceConfig.REFUSE_DEFENDED)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_each_type_sets_its_modifiers_on_its_gate_only() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	for i: int in range(4):
		td.landmarks.unlock(i)
	assert_bool(td.defences.plant_now(0, Landmarks.BANDSTAND)).is_true()
	assert_bool(td.defences.plant_now(1, Landmarks.GARDEN)).is_true()
	assert_bool(td.defences.plant_now(2, Landmarks.GALLERY)).is_true()
	assert_bool(td.defences.plant_now(3, Landmarks.BELL_TOWER)).is_true()
	await runner.simulate_frames(5)
	var border := td.border
	assert_float(border.gate_modifiers(0)["strength_mult"] as float).is_equal(DefenceConfig.DEFENCE_BANDSTAND_MULT)
	assert_bool(border.gate_modifiers(0)["cannot_break"] as bool).is_false()
	assert_bool(border.gate_modifiers(1)["cannot_break"] as bool).is_true()
	assert_float(border.gate_modifiers(1)["strength_mult"] as float).is_equal(1.0)
	assert_bool(border.gate_modifiers(2)["cannot_lose"] as bool).is_true()
	assert_bool(border.gate_modifiers(2)["cannot_break"] as bool).is_false()
	assert_bool(border.gate_modifiers(3)["cannot_lose"] as bool).is_false()  # The bell rings; it sets nothing.
	assert_float(border.gate_modifiers(3)["strength_mult"] as float).is_equal(1.0)
	assert_dict(Defences.modifiers_of({})).is_empty()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_four_defences_in_all() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.border.zone.take(TownGrid.neighbours(TownGrid.start_cell())[0])  # More gates than four.
	await runner.simulate_frames(5)
	assert_int(td.border.zone.gates.size()).is_greater(DefenceConfig.DEFENCE_MAX)
	td.landmarks.unlock(Landmarks.GARDEN)
	for g: int in range(DefenceConfig.DEFENCE_MAX):
		assert_bool(td.defences.plant_now(g, Landmarks.GARDEN)).is_true()
	var reasons := _reasons(td)
	assert_bool(td.defences.plant_now(DefenceConfig.DEFENCE_MAX, Landmarks.GARDEN)).is_false()
	assert_array(reasons).is_equal(["all_used"])
	assert_str(td.intro.current_text()).contains("4")
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- handing back ---------------------------------------------------------------------------------------------------


func test_a_defence_whose_gate_closes_is_handed_back_and_its_staff_rejoin_the_line() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	var cell := TownGrid.neighbours(TownGrid.start_cell())[0]
	var closing: Array = td.border.zone.preview(cell, true)["closed"]
	var closing_key: String = (closing[0] as Dictionary)["key"]
	var closed_gate := -1
	var other_gate := -1
	for g: int in range(td.border.zone.gates.size()):
		if td.border.zone.gates[g]["key"] == closing_key:
			closed_gate = g
		elif other_gate < 0:
			other_gate = g
	assert_bool(td.defences.plant_now(closed_gate, Landmarks.GARDEN)).is_true()
	assert_bool(td.defences.plant_now(other_gate, Landmarks.GARDEN)).is_true()
	var returned: Array[Dictionary] = []
	td.defences.returned.connect(func(info: Dictionary) -> void: returned.append(info))
	var closed_ids: Array[int] = []
	td.border.gate_closed.connect(func(g: int) -> void: closed_ids.append(g))
	var staff: Person = td.defences.post_at(closed_gate)["staff"]
	await runner.simulate_frames(30)
	td.border.zone.take(cell)
	await runner.simulate_frames(10)
	assert_array(closed_ids).contains([closed_gate])
	assert_array(returned).has_size(1)
	assert_str(returned[0]["reason"] as String).is_equal("gate_closed")
	assert_str(returned[0]["kind"] as String).is_equal("Garden")
	assert_int(td.defences.posts.size()).is_equal(1)
	assert_bool(td.border.staffed.has(staff)).is_false()
	# The other defence kept its gate by key although the ids shifted, and its modifiers followed it.
	var kept_gate: int = td.defences.posts[0]["gate"]
	assert_bool(td.border.gate_modifiers(kept_gate)["cannot_break"] as bool).is_true()
	var plain := 0
	for g: int in range(td.border.zone.gates.size()):
		if not (td.border.gate_modifiers(g)["cannot_break"] as bool):
			plain += 1
	assert_int(plain).is_equal(td.border.zone.gates.size() - 1)
	# The handed-back member is on the line (or a spare) again.
	await runner.simulate_frames(10)
	assert_bool(td.border.members.has(staff) or td.border.inner.has(staff)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_defence_whose_staff_is_lost_is_handed_back() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GALLERY)
	assert_bool(td.defences.plant_now(0, Landmarks.GALLERY)).is_true()
	var returned: Array[Dictionary] = []
	td.defences.returned.connect(func(info: Dictionary) -> void: returned.append(info))
	var staff: Person = td.defences.posts[0]["staff"]
	staff.is_rescued = false
	await runner.simulate_frames(3)
	assert_array(returned).has_size(1)
	assert_str(returned[0]["reason"] as String).is_equal("staff_lost")
	assert_bool(td.defences.hand_back(0, "again")).is_false()  # Nothing left to hand back.
	assert_bool(td.border.gate_modifiers(0)["cannot_lose"] as bool).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- the bell ------------------------------------------------------------------------------------------------------


func test_the_bell_rings_a_free_burst_when_its_gate_is_pressed_past_half_and_waits_twenty_seconds() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.BELL_TOWER)
	assert_bool(td.defences.plant_now(0, Landmarks.BELL_TOWER)).is_true()
	await runner.simulate_frames(3)
	var rings: Array[Dictionary] = []
	td.defences.bell_rang.connect(func(info: Dictionary) -> void: rings.append(info))
	var bursts: Array[Dictionary] = []
	td.player.burst_cleared.connect(func(report: Dictionary) -> void: bursts.append(report))
	var spirit := td.player.spirit
	var first: int = td.border._gate_first[0]
	td.border.push.dent[first + 1] = PushConfig.PUSH_BREAK_DEPTH * 0.3
	td.defences._tick_bells(0.0)
	assert_array(rings).is_empty()  # Not pressed past half.
	td.border.push.dent[first + 1] = PushConfig.PUSH_BREAK_DEPTH * 0.6
	td.defences._tick_bells(0.0)
	assert_array(rings).has_size(1)
	assert_array(bursts).has_size(1)
	assert_int(rings[0]["gate"] as int).is_equal(0)
	assert_float(td.player.spirit).is_equal(spirit)  # Free.
	td.defences._tick_bells(DefenceConfig.DEFENCE_BELL_COOLDOWN - 1.0)
	assert_array(rings).has_size(1)  # Still cooling down.
	td.defences._tick_bells(1.5)
	assert_array(rings).has_size(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_bell_burst_lifts_a_dimmed_person_leaning_on_the_gate() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.BELL_TOWER)
	assert_bool(td.defences.plant_now(0, Landmarks.BELL_TOWER)).is_true()
	var post := td.defences.post_at(0)
	var out: Vector2 = td.border.zone.gates[0]["out"]
	var at := _mid(td, 0)
	var pusher := td.people[40]
	TopDownTestUtil.place(pusher, at + Vector3(out.x, 0.0, out.y) * 1.5, pusher.affinity, 1.0)
	var report := td.defences.ring_bell(post, at, 0.7)
	assert_int(report["lifted"] as int).is_greater_equal(0)
	assert_float(post["bell_wait"] as float).is_equal(DefenceConfig.DEFENCE_BELL_COOLDOWN)
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- F, the wheel and right-click -----------------------------------------------------------------------------------


func test_holding_f_at_a_gate_and_releasing_plants_a_defence() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.BANDSTAND)
	await _point_at_gate(runner, td, 0)
	runner.simulate_key_press(KEY_F)
	await runner.simulate_frames(3)
	assert_bool(td.defences.holding).is_true()
	assert_int(td.defences.target_gate).is_equal(0)
	assert_int(td.defences.aim_type).is_equal(Landmarks.BANDSTAND)
	assert_str(td.defences._aim_text()).contains("Bandstand")
	assert_int(td.defences._root.get_child_count()).is_equal(1)  # The ghost.
	runner.simulate_key_release(KEY_F)
	await runner.simulate_frames(3)
	assert_bool(td.defences.holding).is_false()
	assert_int(td.defences.posts.size()).is_equal(1)
	assert_int(td.defences.posts[0]["type"] as int).is_equal(Landmarks.BANDSTAND)
	assert_int(td.defences._root.get_child_count()).is_equal(1)  # The post.
	assert_str(td.defences._aim_text()).is_equal("")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_releasing_f_with_nothing_unlocked_says_so_in_the_banner() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var reasons := _reasons(td)
	await _point_at_gate(runner, td, 0)
	runner.simulate_key_press(KEY_F)
	await runner.simulate_frames(3)
	assert_str(td.defences._aim_text()).is_equal("No defence unlocked")
	runner.simulate_key_release(KEY_F)
	await runner.simulate_frames(3)
	assert_array(reasons).is_equal(["no_type"])
	assert_int(td.defences.posts.size()).is_equal(0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.SPIRIT_LOW)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_pointing_away_from_every_gate_plants_nothing() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	var reasons := _reasons(td)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, Vector3.ZERO))  # The middle of the start square.
	await runner.simulate_frames(3)
	runner.simulate_key_press(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.defences.target_gate).is_equal(Defences.NO_GATE)
	runner.simulate_key_release(KEY_F)
	await runner.simulate_frames(3)
	assert_array(reasons).is_equal(["no_gate"])
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wheel_changes_the_type_while_f_is_held_and_does_not_zoom() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.BANDSTAND)
	td.landmarks.unlock(Landmarks.GARDEN)  # The latest: the default.
	var zoom := td.camera.size
	await _point_at_gate(runner, td, 0)
	runner.simulate_key_press(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.defences.aim_type).is_equal(Landmarks.GARDEN)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_DOWN)
	await runner.simulate_frames(2)
	assert_int(td.defences.aim_type).is_equal(Landmarks.BANDSTAND)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(2)
	assert_int(td.defences.aim_type).is_equal(Landmarks.GARDEN)
	await runner.simulate_frames(120)
	assert_float(td.camera.size).is_equal_approx(zoom, 0.001)
	runner.simulate_key_release(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.defences.posts[0]["type"] as int).is_equal(Landmarks.GARDEN)
	# With F up the wheel zooms again.
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_WHEEL_UP)
	await runner.simulate_frames(120)
	assert_float(td.camera.size).is_less(zoom)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_cycling_with_one_or_no_type_unlocked() -> void:
	var s: Dictionary = await _level(5)
	var td: TopDownMain = s["td"]
	td.defences.aim_type = Landmarks.GARDEN
	td.defences.cycle_type(1)
	assert_int(td.defences.aim_type).is_equal(-1)  # Nothing unlocked.
	td.landmarks.unlock(Landmarks.GARDEN)
	td.defences.cycle_type(1)
	assert_int(td.defences.aim_type).is_equal(Landmarks.GARDEN)
	td.defences.cycle_type(-1)
	assert_int(td.defences.aim_type).is_equal(Landmarks.GARDEN)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_right_click_cancels_a_plant() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	var reasons := _reasons(td)
	await _point_at_gate(runner, td, 0)
	runner.simulate_key_press(KEY_F)
	await runner.simulate_frames(3)
	assert_bool(td.defences.holding).is_true()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(2)
	runner.simulate_key_release(KEY_F)
	await runner.simulate_frames(3)
	assert_bool(td.defences.holding).is_false()
	assert_array(reasons).is_equal(["cancelled"])
	assert_int(td.defences.posts.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- both looks -----------------------------------------------------------------------------------------------------


func test_the_posts_the_ghost_and_the_labels_draw_in_both_looks() -> void:
	var s: Dictionary = await _level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	for i: int in range(4):
		td.landmarks.unlock(i)
	for i: int in range(4):
		assert_bool(td.defences.plant_now(i, i)).is_true()
	await runner.simulate_frames(3)
	assert_int(td.defences._root.get_child_count()).is_equal(4)
	var shapes: Dictionary = {}
	for child: Node in td.defences._root.get_children():
		shapes[(child as MeshInstance3D).mesh.get_class()] = true
	assert_int(shapes.size()).is_equal(3)  # A box (twice: bandstand and gallery differ in size), a ball and a cone.
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(10)
	assert_int(td.defences._root.get_child_count()).is_equal(4)
	assert_str(td.hud.people_label.text).starts_with("People:")
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(5)
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- guards and odd states (coverage of the refusal and hand-back corners) -----------------------------------------


func test_a_defences_node_with_no_level_ignores_input_and_frames() -> void:
	var node: Defences = auto_free(Defences.new())
	node._unhandled_input(InputEventKey.new())
	node._process(0.1)
	assert_bool(node.holding).is_false()


func test_a_gate_that_does_not_exist_has_no_free_member_and_no_post_position() -> void:
	var s: Dictionary = await _level(10)
	var td: TopDownMain = s["td"]
	assert_object(td.defences.free_member_for(-1)).is_null()
	assert_object(td.defences.free_member_for(td.border.zone.gates.size())).is_null()
	assert_object(td.defences.post_position(-1)).is_equal(Vector3.ZERO)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_post_whose_gate_id_shifted_follows_its_gate_by_key() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_true()
	td.defences.posts[0]["gate"] = 99  # Stale id: the key still finds gate 0.
	td.defences._resync()
	assert_int(td.defences.posts[0]["gate"] as int).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_post_with_no_staff_node_is_skipped_when_staff_move() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_true()
	td.defences.posts[0]["staff"] = null
	td.defences._move_staff(0.1)
	assert_int(td.defences.posts.size()).is_equal(1)
	td.defences.posts.clear()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_aiming_falls_back_when_the_type_is_locked_or_nothing_is_pointed_at() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	td.defences.aim_type = Landmarks.BELL_TOWER  # Not unlocked.
	td.defences._refresh()
	assert_int(td.defences.aim_type).is_equal(Landmarks.GARDEN)
	# No aim point at all.
	td.player._has_aim = false
	assert_int(td.defences._gate_at_aim()).is_equal(Defences.NO_GATE)
	# An aim point but a zone with no gates.
	td.player._has_aim = true
	var saved: Array[Dictionary] = td.border.zone.gates.duplicate()
	td.border.zone.gates.clear()
	assert_int(td.defences._gate_at_aim()).is_equal(Defences.NO_GATE)
	td.border.zone.gates.append_array(saved)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_label_says_a_gate_is_already_defended() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.landmarks.unlock(Landmarks.GARDEN)
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_true()
	td.defences.holding = true
	td.defences.target_gate = 0
	td.defences.aim_type = Landmarks.GARDEN
	assert_str(td.defences._aim_text()).is_equal("Already defended")
	td.defences.holding = false
	await TopDownTestUtil.leave_loaded_scene(td)
