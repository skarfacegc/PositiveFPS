extends GdUnitTestSuite

# Round 14: dimmed people are the counter to the midnight surge. They need 1.6 times the joy of a wistful person; joy
# that lands on one shows their progress ring; the one-time prompt says they can be helped too; and hover and auto
# targeting pick them. The intro flag is on here (so the prompt can show); the others run as usual.


func before_test() -> void:
	Config.intro_override = 1


func after_test() -> void:
	Config.intro_override = -1


# The level at midnight (dimmed people may sink), everyone parked, the player at the origin, hover targeting.
func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.player.targeting_mode = Config.TargetingMode.HOVER_STICKY
	td.night.elapsed = Config.NIGHT_LENGTH * 0.5
	return {"runner": runner, "td": td}


func _hover(runner: GdUnitSceneRunner, td: TopDownMain, p: Person) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, p.global_position))
	await runner.simulate_frames(3)


func test_dimmed_people_need_one_point_six_times_the_joy_and_joy_shows_their_progress_ring() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.95)
	assert_float(dimmed.joy_needed()).is_equal_approx(Config.JOY_MAX * 1.6, 0.001)
	await runner.simulate_frames(3)
	assert_bool(GloomSim.is_dark(dimmed)).is_true()
	assert_bool(td.feedback.dim_rings.is_empty()).is_true()

	# Hover-fire at the dimmed person: their ring appears and fills with the joy they take.
	await _hover(runner, td, dimmed)
	assert_object(td.player.target).is_same(dimmed)
	await runner.simulate_frames(90)
	assert_float(dimmed.joy).is_greater(0.0)
	assert_int(td.feedback.dim_rings.size()).is_equal(1)
	var ring: Dictionary = td.feedback.dim_rings[0]
	assert_object(ring["person"]).is_same(dimmed)
	assert_float(ring["progress"]).is_greater(0.0)
	assert_float(ring["progress"]).is_equal_approx(dimmed.joy / dimmed.joy_needed(), 0.05)

	# Stop shooting: the ring fades away after DIM_RING_SECONDS with no more joy.
	td.player.active = false
	await runner.simulate_frames(240)
	assert_bool(td.feedback.dim_rings.is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_hover_targets_a_dimmed_person_and_auto_targets_the_darkest_in_range() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	var wistful := td.people[1]
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.95)
	TopDownTestUtil.place(wistful, Vector3(-2.0, 0, -3.0), 1, 0.2)
	await runner.simulate_frames(3)
	await _hover(runner, td, dimmed)
	assert_object(td.player.target).is_same(dimmed)

	# Auto: the most urgent person in range is the darkest, even though the wistful one is nearer.
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.AUTO)
	await runner.simulate_frames(3)
	assert_object(td.player.target).is_same(dimmed)
	await runner.simulate_frames(60)
	assert_float(dimmed.joy).is_greater(0.0)
	assert_float(wistful.joy).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_dimmed_help_prompt_shows_once_when_a_dimmed_person_is_first_in_view() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.95)
	await runner.simulate_frames(20)
	assert_bool(td.intro.shown.has(Intro.Prompt.DIM_HELP)).is_true()
	assert_int(td.intro.current).is_equal(Intro.Prompt.DIM_HELP)
	assert_str(td.prompts.text).is_equal("Dimmed folk can be helped too — it takes longer")

	# It does not come back: not after it ends, and not when joy lands on them afterwards.
	await runner.simulate_frames(int(Config.PROMPT_SECONDS * 60.0) + 30)
	assert_int(td.intro.current).is_not_equal(Intro.Prompt.DIM_HELP)
	await _hover(runner, td, dimmed)
	await runner.simulate_frames(60)
	assert_float(dimmed.joy).is_greater(0.0)
	assert_bool(td.intro.queue.has(Intro.Prompt.DIM_HELP)).is_false()
	assert_int(td.intro.current).is_not_equal(Intro.Prompt.DIM_HELP)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_dimmed_help_prompt_also_shows_the_first_time_joy_lands_on_one_out_of_view() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	# Far outside the screen: nothing asks for the prompt while it is not in view.
	TopDownTestUtil.place(dimmed, Vector3(-30, 0, -30), 0, 0.95)
	await runner.simulate_frames(20)
	assert_bool(td.intro.shown.has(Intro.Prompt.DIM_HELP)).is_false()
	# Joy landing on it (a direct hit on the person, not a shot through the screen) asks for it.
	dimmed.receive_joy(0, 50.0, 0.0)
	assert_bool(td.intro.shown.has(Intro.Prompt.DIM_HELP)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
