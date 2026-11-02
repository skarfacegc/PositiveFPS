extends GdUnitTestSuite

# Round 14: a dimmed person shelters only the single nearest wistful or gloomy person within SHELTER_RADIUS. The tether
# and the umbrella follow that one person; the others nearby still take joy. Player-driven parts use real mouse input
# (hover targeting and joy shots).

# Where the test holds the three (see _hold): the dimmed person 0.7 m BEHIND the two wistful people as seen from the
# player, who stands at the origin and shoots north, so she is never between the player and a target.
const _DIMMED_SPOT := Vector3(0, 0, -8.7)
const _NEAR_SPOT := Vector3(1.0, 0, -8)
const _FAR_SPOT := Vector3(-1.6, 0, -8)


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.player.targeting_mode = Config.TargetingMode.HOVER_STICKY
	return {"runner": runner, "td": td}


# The dimmed person, the nearest wistful person about 1.2 m away and a farther one about 1.8 m away (both inside
# SHELTER_RADIUS), all music people.
func _arrange(td: TopDownMain) -> void:
	# Round 17: the midnight stagger (9 s between sinks) would hold the dimmed person back, so the gate is opened here.
	TopDownTestUtil.open_dim_gate(td)
	TopDownTestUtil.place(td.people[0], _DIMMED_SPOT, 0, 0.95)
	TopDownTestUtil.place(td.people[1], _NEAR_SPOT, 0, 0.2)
	TopDownTestUtil.place(td.people[2], _FAR_SPOT, 0, 0.2)


# Round 24: run `frames` frames with the three held on their spots. Everyone wanders (and the dimmed person walks
# toward the player). In this test that changed the nearest-ward order (a far one drifting nearer than the near one)
# and put the dimmed person in front of the person being shot: a shot lands on the FIRST person within reach of its
# path, so she was hit and rescued instead, and then nobody was sheltered. Which way each one drifts depends on the
# seeded scene (it shifted when the Garden moved), so the test holds the layout it describes. It sets positions only
# (joy and the shield keep their state).
func _hold(runner: GdUnitSceneRunner, td: TopDownMain, frames: int) -> void:
	for _i: int in range(frames):
		td.people[0].global_position = _DIMMED_SPOT
		td.people[1].global_position = _NEAR_SPOT
		td.people[2].global_position = _FAR_SPOT
		await runner.simulate_frames(1)


func _hover(runner: GdUnitSceneRunner, td: TopDownMain, p: Person) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, p.global_position))
	await _hold(runner, td, 3)


func test_only_the_nearest_wistful_person_is_sheltered_and_the_other_takes_joy() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	var near := td.people[1]
	var far := td.people[2]
	# Both wistful people are inside SHELTER_RADIUS: the one 1 m away is nearest, the one 1.6 m away is not. (Everyone
	# wanders a little, so each phase below places them again.)
	_arrange(td)
	await _hold(runner, td, 3)
	assert_object(dimmed.shelter_ward).is_same(near)
	assert_bool(near.sheltered).is_true()
	assert_bool(far.sheltered).is_false()
	# Only the nearest one is tethered and gets the umbrella.
	assert_int(td.feedback.tethers.size()).is_equal(1)
	var umbrellas := 0
	for ic: Dictionary in td.feedback.icons:
		if ic["kind"] == MoodIcons.Kind.UMBRELLA:
			umbrellas += 1
			assert_object(ic["person"]).is_same(near)
	assert_int(umbrellas).is_equal(1)

	# Hover the farther one and fire: it is not sheltered, so joy lands on it. Round 17: the pointer follows them while
	# they wander (a held target drops once the cursor is off it for 0.2 s, and the nearest other person would take over;
	# that would be the dimmed person, who must not be shot here).
	await _hover(runner, td, far)
	assert_object(td.player.target).is_same(far)
	for _i: int in range(4):
		await _hold(runner, td, 30)
		await _hover(runner, td, far)
	assert_float(far.joy).is_greater(0.0)

	# The sheltered one turns joy away with a glance, and gains nothing. Round 17: a held hover target drops once the
	# cursor has been off it for 0.2 s, so the pointer goes off everyone first, then back on the sheltered one, and
	# follows them while they wander (the old F2 cycle is no longer needed to drop the target).
	_arrange(td)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, TopDownTestUtil.clear_spot(td)))
	await _hold(runner, td, 20)
	await _hover(runner, td, near)
	assert_object(td.player.target).is_same(near)
	for _i: int in range(4):
		await _hold(runner, td, 30)
		await _hover(runner, td, near)
	# Round 15: the shield lets a quarter of the joy through (it used to block all of it), so the sheltered one gains a
	# little joy and still glances each hit. (Shield_test checks the exact share.)
	assert_float(near.joy).is_greater(0.0)
	assert_int(near.glance_count).is_greater(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_when_the_nearest_person_moves_out_the_tether_moves_to_the_next_one() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	var a := td.people[1]
	var b := td.people[2]
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.95)
	TopDownTestUtil.place(a, Vector3(1.0, 0, -8), 1, 0.2)
	TopDownTestUtil.place(b, Vector3(-1.8, 0, -8), 2, 0.2)
	await runner.simulate_frames(3)
	assert_object(dimmed.shelter_ward).is_same(a)
	# A steps out of range: B is now the only one within SHELTER_RADIUS, so B is sheltered and A is not.
	TopDownTestUtil.place(a, Vector3(-30, 0, -30), 1, 0.2)
	await runner.simulate_frames(3)
	assert_object(dimmed.shelter_ward).is_same(b)
	assert_bool(a.sheltered).is_false()
	assert_bool(b.sheltered).is_true()
	assert_int(td.feedback.tethers.size()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# A pure rule check (no frames): two people exactly as near, so the tie is exact (wanderers would move it otherwise).
func test_a_tie_goes_to_the_earlier_person_in_the_level() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var dimmed := td.people[0]
	var first := td.people[1]
	var second := td.people[2]
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.95)
	TopDownTestUtil.place(first, Vector3(1.2, 0, -8), 0, 0.2)
	TopDownTestUtil.place(second, Vector3(-1.2, 0, -8), 0, 0.2)
	assert_object(td.moods._nearest_ward(dimmed, td.people, {})).is_same(first)
	# Swapping the array order swaps the winner: the tie goes to whoever is earlier in the level.
	var swapped: Array[Person] = [td.people[0], td.people[2], td.people[1]]
	assert_object(td.moods._nearest_ward(dimmed, swapped, {})).is_same(second)
	await TopDownTestUtil.leave_loaded_scene(td)
