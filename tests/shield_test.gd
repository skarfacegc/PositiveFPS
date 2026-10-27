extends GdUnitTestSuite

# Round 15: the shield (the umbrella of a dimmed person) leaks joy, wears with each landing, pops on the fourth, and
# then the dimmed person cannot shelter for SHELTER_REGROW seconds. The hits belong to the dimmed person. Player-driven
# parts use real mouse input (hover targeting and joy shots). Exact shares and hit counts are checked by calling the
# rule (Person.receive_joy) with the same arguments on a sheltered person and on a control, so the ratios are exact.

# A joy amount small enough that no one is rescued by the few hits in a test.
const SMALL_JOY := 0.01
# Frames for the 8 s cooldown at the fixed 60 fps the tests run at, plus margin on each side.
const BEFORE_REGROW_FRAMES := 400
const AFTER_REGROW_FRAMES := 500


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.player.targeting_mode = Config.TargetingMode.HOVER_STICKY
	return {"runner": runner, "td": td}


# The dimmed person at (0, 0, -8), their ward 1 m away (wistful), and a control far from everyone (wistful, same
# affinity). Placed again each time a phase needs exact spots (wanderers move a little).
func _arrange(td: TopDownMain) -> void:
	TopDownTestUtil.place(td.people[0], Vector3(0, 0, -8), 0, 0.95)
	TopDownTestUtil.place(td.people[1], Vector3(1.0, 0, -8), 0, 0.2)
	TopDownTestUtil.place(td.people[2], Vector3(-25, 0, -25), 0, 0.2)


func _hover(runner: GdUnitSceneRunner, td: TopDownMain, p: Person) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, p.global_position))
	await runner.simulate_frames(3)


# Hover-fire at `target` (by mouse, the way the player does it) until `hits_wanted` joy landings have reached it.
# Returns the frames it took; gives up after a generous cap so a broken test fails instead of hanging.
func _fire_until_landed(runner: GdUnitSceneRunner, landed: Array, hits_wanted: int) -> int:
	var frames := 0
	while landed[0] < hits_wanted and frames < 1500:
		await runner.simulate_frames(1)
		frames += 1
	return frames


# Counts joy landings on a person (one per Person.joy_landed emission), so a test can wait for an exact number of hits.
func _count_landings(p: Person, landed: Array) -> void:
	p.joy_landed.connect(func() -> void: landed[0] += 1)


func _icon_for(td: TopDownMain, p: Person, kind: int) -> Dictionary:
	for ic: Dictionary in td.feedback.icons:
		if ic["person"] == p and ic["kind"] == kind:
			return ic
	return {}


# Lands `count` small hits on `p` by calling the rule directly (no frames run between them).
func _hit(p: Person, count: int) -> void:
	for i: int in range(count):
		p.receive_joy(Config.Element.MUSIC, SMALL_JOY, 0.0, Vector3.INF)


# --- Leak -----------------------------------------------------------------------------------------------------------


# A sheltered person gets exactly SHELTER_LEAK of the joy an unsheltered person gets from the same hit.
func test_the_shield_lets_a_quarter_of_the_joy_through() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var ward := td.people[1]
	var control := td.people[2]
	assert_bool(ward.sheltered).is_true()
	assert_bool(control.sheltered).is_false()
	var ward_before := ward.joy
	var control_before := control.joy
	ward.receive_joy(Config.Element.MUSIC, 0.1, 0.0, Vector3.INF)
	control.receive_joy(Config.Element.MUSIC, 0.1, 0.0, Vector3.INF)
	var ward_gain := ward.joy - ward_before
	var control_gain := control.joy - control_before
	assert_float(control_gain).is_greater(0.0)
	assert_float(ward_gain / control_gain).is_equal_approx(Config.SHELTER_LEAK, 0.0001)
	assert_float(Config.SHELTER_LEAK).is_equal(0.25)
	await TopDownTestUtil.leave_loaded_scene(td)


# Input-driven: hover-fire at the sheltered person and at a control, the same number of landings each. Per landing, the
# sheltered person gains about a quarter of what the control does (their distances to the player match).
func test_hover_fire_at_a_sheltered_person_gains_about_a_quarter_of_a_control_per_landing() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	# Both targets are about 8.5 m from the player, mirrored, inside hover reach even after they wander: the dimmed person
	# shelters the one on the left only.
	TopDownTestUtil.place(td.people[0], Vector3(-6, 0, -7.5), 0, 0.95)
	TopDownTestUtil.place(td.people[1], Vector3(-6, 0, -6), 0, 0.2)
	TopDownTestUtil.place(td.people[2], Vector3(6, 0, -6), 0, 0.2)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	var control := td.people[2]
	assert_object(dimmed.shelter_ward).is_same(ward)
	var ward_landed: Array = [0]
	_count_landings(ward, ward_landed)
	await _hover(runner, td, ward)
	assert_object(td.player.target).is_same(ward)
	await _fire_until_landed(runner, ward_landed, 3)
	# Read the totals now: the held target keeps taking shots (some already in the air) while the test moves on.
	var ward_joy: float = ward.joy
	var ward_count: int = ward_landed[0]
	assert_float(ward_joy).is_greater(0.0)
	# Each sheltered landing wore the shield once, and none has popped it yet (three of four).
	assert_int(dimmed.shield_hits).is_equal(3)
	assert_bool(ward.sheltered).is_true()

	# The control: same number of landings, with the mouse moved off everyone and the targeting cycled (hover is sticky).
	var control_landed: Array = [0]
	_count_landings(control, control_landed)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, TopDownTestUtil.clear_spot(td)))
	await runner.simulate_frames(3)
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.HOVER_STICKY)
	await _hover(runner, td, control)
	assert_object(td.player.target).is_same(control)
	await _fire_until_landed(runner, control_landed, 3)
	assert_bool(control.sheltered).is_false()
	var control_joy: float = control.joy
	var control_count: int = control_landed[0]
	var per_landing_ward := ward_joy / float(ward_count)
	var per_landing_control := control_joy / float(control_count)
	assert_float(per_landing_control).is_greater(0.0)
	# About a quarter: the wanderers move a little, which moves the falloff a little, so the band is not exact.
	var ratio := per_landing_ward / per_landing_control
	assert_float(ratio).is_greater(0.2)
	assert_float(ratio).is_less(0.3)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Wear and pop ---------------------------------------------------------------------------------------------------


# Input-driven: hover-fire until the shield pops, which takes exactly SHELTER_HITS landings. Afterwards the ward is no
# longer sheltered, no umbrella shows over them, the dimmed person shelters no one, and the hit count is back to zero.
func test_hover_fire_pops_the_shield_on_the_fourth_landing() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	var landed: Array = [0]
	_count_landings(ward, landed)
	await _hover(runner, td, ward)
	assert_object(td.player.target).is_same(ward)
	var frames := 0
	while dimmed.shield_down_left <= 0.0 and frames < 1500:
		await runner.simulate_frames(1)
		frames += 1
	assert_float(dimmed.shield_down_left).is_greater(0.0)
	# The pop came on the fourth landing (the shield took a hit each time, and the fourth one popped it).
	var landings: int = landed[0]
	assert_int(landings).is_equal(Config.SHELTER_HITS)
	assert_int(ward.glance_count).is_equal(Config.SHELTER_HITS)
	assert_bool(ward.sheltered).is_false()
	assert_object(dimmed.shelter_ward).is_null()
	assert_int(dimmed.shield_hits).is_equal(0)
	# The umbrella icon is rebuilt every other frame, so give it a couple of frames to go.
	await runner.simulate_frames(2)
	assert_bool(_icon_for(td, ward, MoodIcons.Kind.UMBRELLA).is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# Rule: the fifth landing lands at full strength (the shield is down), the same as a control's.
func test_the_fifth_landing_lands_at_full_strength() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var ward := td.people[1]
	var control := td.people[2]
	_hit(ward, Config.SHELTER_HITS)
	assert_bool(ward.sheltered).is_false()
	var ward_before := ward.joy
	var control_before := control.joy
	ward.receive_joy(Config.Element.MUSIC, 0.1, 0.0, Vector3.INF)
	control.receive_joy(Config.Element.MUSIC, 0.1, 0.0, Vector3.INF)
	assert_float((ward.joy - ward_before) / (control.joy - control_before)).is_equal_approx(1.0, 0.0001)
	await TopDownTestUtil.leave_loaded_scene(td)


# The umbrella steps down with each hit: its icon's wear goes 1, 0.75, 0.5, 0.25 and it is gone when the shield pops.
func test_the_umbrella_steps_down_with_each_hit_and_goes_when_the_shield_pops() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var ward := td.people[1]
	var last_wear := 2.0
	for hit: int in range(Config.SHELTER_HITS - 1):
		var icon := _icon_for(td, ward, MoodIcons.Kind.UMBRELLA)
		assert_bool(icon.is_empty()).is_false()
		var wear: float = icon["wear"]
		assert_float(wear).is_less(last_wear)
		assert_float(wear).is_equal_approx(1.0 - float(hit) / float(Config.SHELTER_HITS), 0.0001)
		last_wear = wear
		_hit(ward, 1)
		await runner.simulate_frames(2)
	# The last landing pops it: no umbrella over the ward any more.
	_hit(ward, 1)
	await runner.simulate_frames(2)
	assert_bool(_icon_for(td, ward, MoodIcons.Kind.UMBRELLA).is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Cooldown -------------------------------------------------------------------------------------------------------


# After a pop the dimmed person shelters no one for SHELTER_REGROW seconds; then, still dimmed, they shelter again
# with a fresh four-hit shield.
func test_after_a_pop_the_dimmed_person_shelters_again_only_after_the_regrow_time_with_a_fresh_shield() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	_hit(ward, Config.SHELTER_HITS)
	assert_float(dimmed.shield_down_left).is_equal_approx(Config.SHELTER_REGROW, 0.0001)
	# Everyone is put back on the spots: the ward is still in range, but no shielding happens during the cooldown.
	_arrange(td)
	await runner.simulate_frames(BEFORE_REGROW_FRAMES)
	assert_object(dimmed.shelter_ward).is_null()
	assert_bool(ward.sheltered).is_false()
	assert_float(dimmed.shield_down_left).is_greater(0.0)
	# Past the regrow time, still dimmed and the ward in range: a new shield, all four hits left.
	_arrange(td)
	await runner.simulate_frames(AFTER_REGROW_FRAMES)
	assert_float(dimmed.shield_down_left).is_equal(0.0)
	_arrange(td)
	await runner.simulate_frames(3)
	assert_object(dimmed.shelter_ward).is_same(ward)
	assert_bool(ward.sheltered).is_true()
	assert_int(dimmed.shield_hits).is_equal(0)
	assert_float(dimmed.shield_left_frac()).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# A dimmed person helped out of dimmed during the cooldown does not shelter after it, even once the time has passed. If
# they dim again later, they shelter with a fresh shield (their hits were reset when they were helped).
func test_a_popped_shielder_helped_out_of_dimmed_does_not_shelter_and_starts_fresh_if_dimmed_again() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	_hit(ward, Config.SHELTER_HITS - 1)
	assert_int(dimmed.shield_hits).is_equal(Config.SHELTER_HITS - 1)
	_hit(ward, 1)
	# Helped out of dimmed (wistful now) during the cooldown.
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.2)
	TopDownTestUtil.place(ward, Vector3(1.0, 0, -8), 0, 0.2)
	await runner.simulate_frames(AFTER_REGROW_FRAMES)
	assert_float(dimmed.shield_down_left).is_equal(0.0)
	assert_object(dimmed.shelter_ward).is_null()
	assert_bool(ward.sheltered).is_false()
	# Dimmed again: sheltering resumes with a fresh shield.
	_arrange(td)
	await runner.simulate_frames(3)
	assert_object(dimmed.shelter_ward).is_same(ward)
	assert_int(dimmed.shield_hits).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Shield health stays with the shielder --------------------------------------------------------------------------


# The hits are the dimmed person's: when the nearest ward changes, the count carries over, and the pop still comes on
# the fourth landing, whoever it lands on.
func test_shield_health_stays_with_the_shielder_when_the_ward_changes() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var first := td.people[1]
	var second := td.people[2]
	_hit(first, 2)
	assert_int(dimmed.shield_hits).is_equal(2)
	# The first ward steps out of range and the second one steps in, nearer: the second is the ward now.
	TopDownTestUtil.place(first, Vector3(-30, 0, -30), 0, 0.2)
	TopDownTestUtil.place(second, Vector3(-1.0, 0, -8), 0, 0.2)
	await runner.simulate_frames(3)
	assert_object(dimmed.shelter_ward).is_same(second)
	assert_int(dimmed.shield_hits).is_equal(2)
	var icon := _icon_for(td, second, MoodIcons.Kind.UMBRELLA)
	assert_float(icon["wear"]).is_equal_approx(0.5, 0.0001)
	# The next landing, on the new ward, is the third hit (the umbrella is at a quarter after it).
	_hit(second, 1)
	assert_int(dimmed.shield_hits).is_equal(3)
	assert_bool(second.sheltered).is_true()
	# And the fourth, on the same new ward, pops it.
	_hit(second, 1)
	assert_bool(second.sheltered).is_false()
	assert_object(dimmed.shelter_ward).is_null()
	assert_int(dimmed.shield_hits).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# Round 15 follow-up: continuous joy (a bloom's per-tick pulse) leaks like any joy but is not a landing, so it does not
# wear the shield. Several seconds of pulses beside a sheltered person: the shield is intact and the joy is a quarter.
func test_a_bloom_pulsing_beside_a_sheltered_person_leaks_joy_but_does_not_wear_the_shield() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	var control := td.people[2]
	var ward_before := ward.joy
	var control_before := control.joy
	# Five seconds of small pulses, the way Bloom._soak calls them (not discrete landings).
	for i: int in range(300):
		ward.receive_joy(Config.Element.NATURE, 0.002, 0.0, Vector3.INF, false)
		control.receive_joy(Config.Element.NATURE, 0.002, 0.0, Vector3.INF, false)
	assert_float(control.joy - control_before).is_greater(0.0)
	assert_float((ward.joy - ward_before) / (control.joy - control_before)).is_equal_approx(Config.SHELTER_LEAK, 0.0001)
	assert_int(dimmed.shield_hits).is_equal(0)
	assert_bool(ward.sheltered).is_true()
	assert_int(ward.glance_count).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# Round 15 follow-up: a ward has at most one shielder. Two dimmed people are both within reach of the same wistful
# person; the first (in array order) takes them, and the second takes its own next-nearest wistful person in reach.
func test_two_dimmed_people_never_shelter_the_same_ward() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.place(td.people[0], Vector3(0, 0, -8), 0, 0.95)
	TopDownTestUtil.place(td.people[2], Vector3(1.0, 0, -8), 0, 0.2)
	TopDownTestUtil.place(td.people[3], Vector3(3.2, 0, -8), 0, 0.2)
	await runner.simulate_frames(3)
	# The midnight stagger holds back a second dimmed person until the gate is open again (see topdown_test_util).
	TopDownTestUtil.open_dim_gate(td)
	TopDownTestUtil.place(td.people[1], Vector3(2.0, 0, -8), 0, 0.95)
	await runner.simulate_frames(3)
	var first := td.people[0]
	var second := td.people[1]
	var shared := td.people[2]
	var own := td.people[3]
	assert_object(first.shelter_ward).is_same(shared)
	assert_object(shared.shielder).is_same(first)
	# The second dimmed person would have picked the shared one (nearer to it), but it is claimed: it takes the other.
	assert_object(second.shelter_ward).is_same(own)
	assert_object(own.shielder).is_same(second)
	await TopDownTestUtil.leave_loaded_scene(td)


# A dimmed person who is helped out of dimmed loses their shield's hits: lifted with two hits taken, their count is back
# to zero on the next frame (Moods resets it), so a later re-dimming starts with a fresh shield.
func test_a_shielder_lifted_out_of_dimmed_loses_the_hits_taken() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	_hit(ward, 2)
	assert_int(dimmed.shield_hits).is_equal(2)
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -8), 0, 0.2)
	await runner.simulate_frames(3)
	assert_int(dimmed.shield_hits).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
