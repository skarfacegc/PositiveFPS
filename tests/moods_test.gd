extends GdUnitTestSuite

# Round 12b, read the person: the moods (guarded, skittish, glum) of wistful and gloomy people, and sheltering by dimmed
# people. Level tests drive real keys (WASD, Shift) and the mouse (hover targeting fires at what the pointer is over).
# Rules that need an exact moment (the joy x3 of a glum look-up, the arc of a guarded person) also have direct checks.


# The level with everyone parked away and the player standing at the origin. Hover targeting is the default.
func _start(park: bool = true) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	if park:
		TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	return {"runner": runner, "td": td}


# A wistful person with a mood, placed at `spot`.
func _mooded(td: TopDownMain, index: int, spot: Vector3, mood: int, gloom: float = 0.2) -> Person:
	var p: Person = td.people[index]
	TopDownTestUtil.place(p, spot, 0, gloom)
	p.mood = mood
	return p


# Points the mouse at `p`, so hover targeting picks them and the player fires.
func _hover(runner: GdUnitSceneRunner, td: TopDownMain, p: Person) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, p.global_position))
	await runner.simulate_frames(3)


# True when the feedback layer shows an icon of `kind` over `p`.
func _has_icon(td: TopDownMain, p: Person, kind: int) -> bool:
	for ic: Dictionary in td.feedback.icons:
		if ic["person"] == p and ic["kind"] == kind:
			return true
	return false


# --- The split ---------------------------------------------------------------------------------------------------


func test_moods_are_split_roughly_evenly_and_the_same_every_run() -> void:
	var s: Dictionary = await _start(false)
	var td: TopDownMain = s["td"]
	var counts := [0, 0, 0, 0]
	for p: Person in td.people:
		counts[p.mood] += 1
	assert_int(counts[Person.Mood.NONE]).is_equal(0)
	for m: int in [Person.Mood.GUARDED, Person.Mood.SKITTISH, Person.Mood.GLUM]:
		assert_int(counts[m]).is_equal(Config.TD_PEOPLE_COUNT / 3)
	# Seeded: assigning again with the same seed gives the same moods.
	var before: Array[int] = []
	for p: Person in td.people:
		before.append(p.mood)
	Moods.assign(td.people, Config.RNG_SEED + 3)
	for i: int in range(td.people.size()):
		assert_int(td.people[i].mood).is_equal(before[i])
	# The mood does not follow the element (affinity is i % 3).
	var same := 0
	for i: int in range(td.people.size()):
		if td.people[i].mood == 1 + td.people[i].affinity:
			same += 1
	assert_int(same).is_less(Config.TD_PEOPLE_COUNT)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_and_rescued_people_have_no_active_mood() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED, 0.2)
	assert_int(p.active_mood()).is_equal(Person.Mood.GUARDED)
	p.gloom = 0.45
	assert_int(p.active_mood()).is_equal(Person.Mood.GUARDED)  # gloomy still has one
	p.gloom = 0.8
	assert_int(p.active_mood()).is_equal(Person.Mood.NONE)  # dimmed
	p.gloom = 0.2
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	assert_bool(p.is_rescued).is_true()
	assert_int(p.active_mood()).is_equal(Person.Mood.NONE)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Guarded -----------------------------------------------------------------------------------------------------


func test_a_guarded_person_turns_their_back_and_shots_from_behind_glance_off() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var guarded := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	guarded.rotation.y = 0.0  # Already facing away (north), the player is south.
	await _hover(runner, td, guarded)
	assert_object(td.player.target).is_same(guarded)
	await runner.simulate_frames(240)
	# They keep their back to the player: they face away (north, local forward -Z).
	assert_float(guarded.facing_dir().z).is_less(-0.7)
	# Round 13b: the shield icon over their head says "guarded" (the crossed-arms bar is gone).
	assert_bool(_has_icon(td, guarded, MoodIcons.Kind.SHIELD)).is_true()
	# Shots keep arriving from behind: they glance off and no joy lands.
	var glances := guarded.glance_count
	await runner.simulate_frames(120)
	assert_float(guarded.joy).is_equal(0.0)
	assert_int(guarded.glance_count).is_greater(glances)
	assert_int(guarded.glance_count).is_greater(3)
	assert_str(td.hud.element_label.text).contains("guarded")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_shots_from_the_front_or_side_land_and_the_player_can_run_round_to_the_front() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var guarded := _mooded(td, 0, Vector3(4, 0, -6), Person.Mood.GUARDED)
	guarded.rotation.y = atan2(-4.0, 6.0)  # Already facing away from the player.
	await _hover(runner, td, guarded)
	await runner.simulate_frames(90)
	assert_float(guarded.joy).is_equal(0.0)  # still behind them
	assert_int(guarded.glance_count).is_greater(0)

	# Run north past them with WASD: they turn slowly (0.8 rad/s), so the player ends up at their front or side.
	runner.simulate_key_press(KEY_SHIFT)
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(66)
	runner.simulate_key_release(KEY_W)
	runner.simulate_key_release(KEY_SHIFT)
	assert_float(td.player.global_position.z).is_less(-9.0)
	await _hover(runner, td, guarded)
	var glances := guarded.glance_count
	await runner.simulate_frames(30)
	assert_float(guarded.joy).is_greater(0.0)
	# Eventually they turn their back again and shots glance off.
	await runner.simulate_frames(200)
	assert_int(guarded.glance_count).is_greater(glances)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_guarded_arc_is_a_hundred_and_ten_degrees_either_side_of_their_facing() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	p.rotation.y = 0.0  # Facing north (-Z).
	var here := p.global_position
	assert_bool(p.is_open_to(here + Vector3(0, 0, -5))).is_true()  # in front
	assert_bool(p.is_open_to(here + Vector3(5, 0, 0))).is_true()  # to the side (90 degrees)
	# Angles measured from the facing direction (north, -Z).
	var at_105 := Vector3(sin(deg_to_rad(105.0)), 0, -cos(deg_to_rad(105.0)))
	var at_115 := Vector3(sin(deg_to_rad(115.0)), 0, -cos(deg_to_rad(115.0)))
	assert_bool(p.is_open_to(here + at_105 * 5.0)).is_true()
	assert_bool(p.is_open_to(here + at_115 * 5.0)).is_false()
	assert_bool(p.is_open_to(here + Vector3(0, 0, 5))).is_false()  # behind
	# Behind: a shot glances (no joy, a puff); from the front it lands.
	p.receive_joy(0, 100.0, 0.0, here + Vector3(0, 0, 5))
	assert_float(p.joy).is_equal(0.0)
	assert_int(p.glance_count).is_equal(1)
	p.receive_joy(0, 100.0, 0.0, here + Vector3(0, 0, -5))
	assert_float(p.joy).is_greater(0.0)
	# A rescued person is never turned away.
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Skittish ----------------------------------------------------------------------------------------------------


func test_running_at_a_skittish_person_scares_them_away_but_walking_does_not() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var shy := _mooded(td, 0, Vector3(0, 0, -4.5), Person.Mood.SKITTISH)
	# Walking up: slower than walk speed x 1.1, so no scare.
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(20)
	runner.simulate_key_release(KEY_W)
	assert_float(shy.flee_left).is_equal(0.0)
	var walked_at := shy.global_position
	assert_float(Vector2(walked_at.x, walked_at.z).distance_to(Vector2(0, -4.5))).is_less(0.6)
	assert_bool(td.moods.is_fleeing(shy)).is_false()

	# Back to the start and run at them: they back away for about 1.5 s at 2.5 m/s.
	td.player.global_position = Vector3.ZERO
	await runner.simulate_frames(5)
	TopDownTestUtil.place(shy, Vector3(0, 0, -4.5), 0, 0.2)
	shy.mood = Person.Mood.SKITTISH
	runner.simulate_key_press(KEY_SHIFT)
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(4)
	assert_float(shy.flee_left).is_greater(0.0)
	assert_bool(td.moods.is_fleeing(shy)).is_true()
	runner.simulate_key_release(KEY_W)
	runner.simulate_key_release(KEY_SHIFT)
	var from_z := shy.global_position.z
	await runner.simulate_frames(60)
	# Moving away from the player (north, to smaller z) at about the flee speed.
	assert_float(from_z - shy.global_position.z).is_greater(Config.SKITTISH_FLEE_SPEED * 0.6)
	await runner.simulate_frames(60)
	assert_float(shy.flee_left).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_skittish_person_is_not_scared_from_far_away_or_by_running_the_other_way() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var shy := _mooded(td, 0, Vector3(0, 0, -9), Person.Mood.SKITTISH)
	runner.simulate_key_press(KEY_SHIFT)
	runner.simulate_key_press(KEY_S)  # Running south, away from them.
	await runner.simulate_frames(20)
	runner.simulate_key_release(KEY_S)
	runner.simulate_key_release(KEY_SHIFT)
	assert_float(shy.flee_left).is_equal(0.0)
	# Close by, but running past or away from them (south, with them to the north): no scare either.
	td.player.global_position = Vector3.ZERO
	TopDownTestUtil.place(shy, Vector3(0, 0, -3), 0, 0.2)
	shy.mood = Person.Mood.SKITTISH
	runner.simulate_key_press(KEY_SHIFT)
	runner.simulate_key_press(KEY_S)
	await runner.simulate_frames(10)
	runner.simulate_key_release(KEY_S)
	runner.simulate_key_release(KEY_SHIFT)
	assert_float(shy.flee_left).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_degenerate_cases_do_not_turn_or_flee_in_a_strange_direction() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	# A point on the person counts as their front.
	assert_bool(p.is_open_to(p.global_position)).is_true()
	# A guarded person with the player standing on them does not spin.
	td.player.global_position = p.global_position
	var yaw := p.rotation.y
	td.moods._turn_away(p, td.player, 0.5)
	assert_float(p.rotation.y).is_equal(yaw)
	# Fleeing from the very spot they stand on goes east rather than nowhere.
	p.flee_from = p.global_position
	assert_float(td.moods.flee_dir(p).x).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Glum --------------------------------------------------------------------------------------------------------


func test_a_glum_person_looks_up_now_and_then_and_shows_a_glint() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var glum := _mooded(td, 0, Vector3(0, 0, -40), Person.Mood.GLUM)
	glum.global_position = Vector3(30, 0, -30)
	var up_frames := 0
	var starts := 0
	var was_up := false
	var slumped_seen := false
	var glint_seen := false
	for i: int in range(600):
		await runner.simulate_frames(1)
		if glum.glum_up:
			up_frames += 1
			glint_seen = glint_seen or glum.look.glint.visible
		else:
			slumped_seen = slumped_seen or glum.look.visual.rotation.x > 0.2
		if glum.glum_up and not was_up:
			starts += 1
		was_up = glum.glum_up
	# Ten seconds: about three look-ups of about 0.8 s (48 frames) each.
	assert_int(starts).is_between(2, 5)
	assert_int(up_frames).is_between(starts * 40, starts * 56)
	assert_bool(slumped_seen).is_true()
	assert_bool(glint_seen).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_joy_counts_triple_during_a_glum_look_up_and_normal_outside_it() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var glum := _mooded(td, 0, Vector3(0, 0, -5), Person.Mood.GLUM)
	glum.glum_up = false
	glum.receive_joy(0, 100.0, 0.0)
	var normal := glum.joy
	glum.joy = 0.0
	glum.glum_up = true
	glum.receive_joy(0, 100.0, 0.0)
	assert_float(glum.joy).is_equal_approx(normal * Config.GLUM_LOOKUP_MULT, 0.01)
	# Another mood's flag does nothing.
	var other := _mooded(td, 1, Vector3(3, 0, -5), Person.Mood.GUARDED)
	other.glum_up = true
	other.receive_joy(0, 100.0, 0.0)
	assert_float(other.joy).is_equal_approx(normal, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_shots_that_land_in_the_look_up_are_triple_when_the_player_fires() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var glum := _mooded(td, 0, Vector3(0, 0, -3), Person.Mood.GLUM)
	await _hover(runner, td, glum)
	var singles: Array[float] = []
	var triples: Array[float] = []
	for i: int in range(420):
		glum.joy = 0.0  # Never rescued: each frame's gain is read, then reset.
		var up_before := glum.glum_up
		await runner.simulate_frames(1)
		if glum.joy > 0.0:
			if up_before:
				triples.append(glum.joy)
			else:
				singles.append(glum.joy)
	assert_int(singles.size()).is_greater(3)
	assert_int(triples.size()).is_greater(0)
	assert_float(triples[0]).is_equal_approx(singles[0] * Config.GLUM_LOOKUP_MULT, singles[0] * 0.05)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Skittish jitter and the HUD ---------------------------------------------------------------------------------


func test_a_skittish_person_jitters_and_the_hud_names_the_target_mood() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var shy := _mooded(td, 0, Vector3(0, 0, -7), Person.Mood.SKITTISH)
	await _hover(runner, td, shy)
	var xs := {}
	for i: int in range(20):
		await runner.simulate_frames(1)
		xs[snappedf(shy.look.visual.position.x, 0.001)] = true
	assert_int(xs.size()).is_greater(3)
	assert_str(td.hud.element_label.text).contains("skittish")
	TopDownTestUtil.send_everyone_away(td)
	await runner.simulate_frames(5)
	assert_str(td.hud.element_label.text).not_contains("skittish")
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Sheltering --------------------------------------------------------------------------------------------------


func test_no_joy_lands_on_a_person_while_a_dimmed_person_is_within_two_metres() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var wistful := _mooded(td, 0, Vector3(0, 0, -8), Person.Mood.NONE)
	var dimmed := td.people[1]
	TopDownTestUtil.place(dimmed, Vector3(1.6, 0, -8), 1, 0.95)
	await _hover(runner, td, wistful)
	assert_object(td.player.target).is_same(wistful)
	await runner.simulate_frames(90)
	assert_bool(wistful.sheltered).is_true()
	assert_float(wistful.joy).is_equal(0.0)
	assert_int(wistful.glance_count).is_greater(2)

	# Draw the dimmed person away (here: they leave): joy lands again.
	TopDownTestUtil.place(dimmed, Vector3(-25, 0, -25), 1, 0.95)
	var glances := wistful.glance_count
	await runner.simulate_frames(30)
	assert_bool(wistful.sheltered).is_false()
	assert_float(wistful.joy).is_greater(0.0)
	assert_int(wistful.glance_count).is_equal(glances)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_dimmed_person_further_than_the_shelter_radius_does_not_shelter() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var wistful := _mooded(td, 0, Vector3(0, 0, -8), Person.Mood.NONE)
	var dimmed := td.people[1]
	TopDownTestUtil.place(dimmed, Vector3(Config.SHELTER_RADIUS + 0.5, 0, -8), 1, 0.95)
	await runner.simulate_frames(3)
	assert_bool(wistful.sheltered).is_false()
	TopDownTestUtil.place(dimmed, Vector3(Config.SHELTER_RADIUS - 0.2, 0, -8), 1, 0.95)
	await runner.simulate_frames(3)
	assert_bool(wistful.sheltered).is_true()
	# A dimmed person does not shelter themselves, and a gloomy (not dimmed) neighbour does not shelter anyone.
	assert_bool(dimmed.sheltered).is_false()
	TopDownTestUtil.place(dimmed, Vector3(1.0, 0, -8), 1, 0.5)
	await runner.simulate_frames(3)
	assert_bool(wistful.sheltered).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)
