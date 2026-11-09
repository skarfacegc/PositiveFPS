extends GdUnitTestSuite

# Round 18: the umbrella is readable. The pips under it count the shield's hits left (filled) and used (hollow); the
# icon stays nearly opaque however worn it is; the tether is a steady line from the dimmed person to the one they
# shelter; a pop bursts once; and a dimmed person whose shield is cooling down shows a regrow ring until the cooldown
# is over. Hits are driven by real mouse input (hover targeting and joy shots) where the test is about the umbrella on
# screen, and by calling the rule (Person.receive_joy) where the test only needs the hits to land.

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
	TopDownTestUtil.open_dim_gate(td)
	TopDownTestUtil.place(td.people[0], Vector3(0, 0, -8), 0, 0.95)
	TopDownTestUtil.place(td.people[1], Vector3(1.0, 0, -8), 0, 0.2)
	TopDownTestUtil.place(td.people[2], Vector3(-25, 0, -25), 0, 0.2)


func _hover(runner: GdUnitSceneRunner, td: TopDownMain, p: Person) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, p.global_position))
	await runner.simulate_frames(3)


# Hover-fire at the held target until `hits_wanted` joy landings have reached it (gives up after a cap).
func _fire_until_landed(runner: GdUnitSceneRunner, landed: Array, hits_wanted: int) -> void:
	var frames := 0
	while landed[0] < hits_wanted and frames < 1500:
		await runner.simulate_frames(1)
		frames += 1


func _count_landings(p: Person, landed: Array) -> void:
	p.joy_landed.connect(func() -> void: landed[0] += 1)


func _icon_for(td: TopDownMain, p: Person, kind: int) -> Dictionary:
	for ic: Dictionary in td.feedback.icons:
		if ic["person"] == p and ic["kind"] == kind:
			return ic
	return {}


func _hit(p: Person, count: int) -> void:
	for i: int in range(count):
		p.receive_joy(Config.Element.MUSIC, SMALL_JOY, 0.0, Vector3.INF)


# The person whose chest is nearest to `at` (world space).
func _nearest_person(td: TopDownMain, at: Vector3) -> Person:
	var best: Person = null
	var best_d := INF
	for p: Person in td.people:
		var d := p.chest_position().distance_to(at)
		if d < best_d:
			best_d = d
			best = p
	return best


# Filled pips in a list of pip states.
static func _filled(states: Array[bool]) -> int:
	var n := 0
	for s: bool in states:
		if s:
			n += 1
	return n


# --- Pips -----------------------------------------------------------------------------------------------------------


# Input-driven: hover-fire at the sheltered person. After each landing the umbrella's pips show the hits left (4, 3, 2,
# 1), then the fourth landing pops the shield and the pips are empty.
func test_pips_count_the_hits_left_through_four_hits_and_the_pop() -> void:
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
	for hit: int in range(1, MoodConfig.SHELTER_HITS):
		await _fire_until_landed(runner, landed, hit)
		# The icon is rebuilt every other frame: give it a couple of frames.
		await runner.simulate_frames(2)
		var icon := _icon_for(td, ward, MoodIcons.Kind.UMBRELLA)
		assert_bool(icon.is_empty()).is_false()
		var left := MoodConfig.SHELTER_HITS - hit
		assert_int(icon["pips"]).is_equal(left)
		var shown: int = icon["pips"]
		assert_int(_filled(FeedbackLayer.pip_states(shown))).is_equal(left)
	assert_int(td.feedback.pop_count).is_equal(0)
	# The fourth landing pops the shield: no umbrella and no pips over the ward, one pop recorded.
	await _fire_until_landed(runner, landed, MoodConfig.SHELTER_HITS)
	await runner.simulate_frames(2)
	assert_float(dimmed.shield_down_left).is_greater(0.0)
	assert_bool(_icon_for(td, ward, MoodIcons.Kind.UMBRELLA).is_empty()).is_true()
	assert_int(td.feedback.pop_count).is_equal(1)
	assert_int(_filled(FeedbackLayer.pip_states(0))).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# The pips are the same count the rule gives (SHELTER_HITS minus the shield's hits), through every hit and the pop.
func test_pips_match_the_shields_hits_taken_for_each_hit_by_the_rule() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	for _step: int in range(MoodConfig.SHELTER_HITS):
		await runner.simulate_frames(2)
		var icon := _icon_for(td, ward, MoodIcons.Kind.UMBRELLA)
		assert_int(icon["pips"]).is_equal(MoodConfig.SHELTER_HITS - dimmed.shield_hits)
		_hit(ward, 1)
	assert_int(td.feedback.pop_count).is_equal(1)
	assert_int(FeedbackLayer.pip_states(0).size()).is_equal(MoodConfig.SHELTER_HITS)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Icon alpha -----------------------------------------------------------------------------------------------------


# The placeholder umbrella never fades below UMBRELLA_MIN_ALPHA, at any wear from fresh to about to pop.
func test_the_umbrella_icon_never_fades_below_the_minimum_alpha() -> void:
	assert_float(MoodConfig.UMBRELLA_MIN_ALPHA).is_greater_equal(0.85)
	var wear := 0.0
	while wear <= 1.0001:
		assert_float(FeedbackLayer.umbrella_alpha(wear, false)).is_greater_equal(MoodConfig.UMBRELLA_MIN_ALPHA)
		wear += 0.05
	assert_float(FeedbackLayer.umbrella_alpha(1.0, false)).is_equal(1.0)
	assert_float(FeedbackLayer.umbrella_alpha(0.25, false)).is_greater_equal(MoodConfig.UMBRELLA_MIN_ALPHA)


# Live: the real umbrella icon's wear at every hit (1, 0.75, 0.5, 0.25) keeps the placeholder alpha above the minimum.
func test_the_live_umbrella_stays_above_the_minimum_alpha_at_every_hit() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var ward := td.people[1]
	for hit: int in range(MoodConfig.SHELTER_HITS):
		await runner.simulate_frames(2)
		var icon := _icon_for(td, ward, MoodIcons.Kind.UMBRELLA)
		assert_bool(icon.is_empty()).is_false()
		var wear: float = icon["wear"]
		assert_float(FeedbackLayer.umbrella_alpha(wear, false)).is_greater_equal(MoodConfig.UMBRELLA_MIN_ALPHA)
		_hit(ward, 1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Tether ---------------------------------------------------------------------------------------------------------


# The tether exists exactly while a person is sheltered, and joins the dimmed person to the ward (not to the control).
func test_the_tether_is_there_exactly_while_sheltered_and_joins_the_right_pair() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	var control := td.people[2]
	assert_bool(ward.sheltered).is_true()
	assert_int(td.feedback.tethers.size()).is_equal(1)
	var link: Dictionary = td.feedback.tethers[0]
	var a: Vector3 = link["a"]
	var b: Vector3 = link["b"]
	assert_object(_nearest_person(td, a)).is_same(dimmed)
	assert_object(_nearest_person(td, b)).is_same(ward)
	assert_float(a.distance_to(dimmed.chest_position())).is_less(0.5)
	assert_float(b.distance_to(ward.chest_position())).is_less(0.5)
	assert_bool(control.sheltered).is_false()
	# The shield pops: the ward is no longer sheltered, so no tether.
	_hit(ward, MoodConfig.SHELTER_HITS)
	await runner.simulate_frames(2)
	assert_bool(ward.sheltered).is_false()
	assert_int(td.feedback.tethers.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# The live tether is drawn thicker than the old one and in the umbrella's colour, with full steadiness (no fade).
func test_the_live_tether_is_thicker_and_in_the_umbrella_colour() -> void:
	assert_float(MoodConfig.SHELTER_TETHER_WIDTH).is_greater(2.0)
	assert_float(MoodConfig.SHELTER_TETHER_COLOUR.a).is_greater_equal(0.8)
	assert_float(MoodConfig.SHELTER_TETHER_COLOUR.r).is_equal_approx(
		MoodConfig.MOOD_ICON_COLOURS[MoodIcons.Kind.UMBRELLA].r, 0.0001
	)
	assert_float(MoodConfig.SHELTER_TETHER_COLOUR.b).is_equal_approx(
		MoodConfig.MOOD_ICON_COLOURS[MoodIcons.Kind.UMBRELLA].b, 0.0001
	)


# --- Pop ------------------------------------------------------------------------------------------------------------


# A pop fires the feedback exactly once: later joy on the ward (no longer sheltered) does not pop it again.
func test_a_pop_fires_its_feedback_once() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var ward := td.people[1]
	_hit(ward, MoodConfig.SHELTER_HITS - 1)
	await runner.simulate_frames(2)
	assert_int(td.feedback.pop_count).is_equal(0)
	assert_int(td.feedback.pops.size()).is_equal(0)
	_hit(ward, 1)
	assert_int(td.feedback.pop_count).is_equal(1)
	assert_int(td.feedback.pops.size()).is_equal(1)
	# More joy on the ward after the pop: no shield, so no second pop.
	_hit(ward, 3)
	await runner.simulate_frames(3)
	assert_int(td.feedback.pop_count).is_equal(1)
	# The burst is short: it is gone after SHELTER_POP_SECONDS.
	await runner.simulate_frames(int(MoodConfig.SHELTER_POP_SECONDS * 60.0) + 15)
	assert_int(td.feedback.pops.size()).is_equal(0)
	assert_int(td.feedback.pop_count).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Regrow ring ----------------------------------------------------------------------------------------------------


# The regrow ring is shown only while the dimmed person's shield is cooling down: none before the pop, one during the
# cooldown (filling as it passes), none once it is over.
func test_the_regrow_ring_shows_only_during_the_cooldown() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_arrange(td)
	await runner.simulate_frames(3)
	var dimmed := td.people[0]
	var ward := td.people[1]
	assert_int(td.feedback.regrow_rings.size()).is_equal(0)
	_hit(ward, MoodConfig.SHELTER_HITS)
	await runner.simulate_frames(3)
	assert_float(dimmed.shield_down_left).is_greater(0.0)
	assert_int(td.feedback.regrow_rings.size()).is_equal(1)
	var ring: Dictionary = td.feedback.regrow_rings[0]
	assert_object(ring["person"]).is_same(dimmed)
	var first: float = ring["progress"]
	assert_float(first).is_greater_equal(0.0)
	assert_float(first).is_less(0.5)
	# Partway through the cooldown the ring has filled further.
	_arrange(td)
	await runner.simulate_frames(BEFORE_REGROW_FRAMES)
	assert_float(dimmed.shield_down_left).is_greater(0.0)
	assert_int(td.feedback.regrow_rings.size()).is_equal(1)
	var later: float = td.feedback.regrow_rings[0]["progress"]
	assert_float(later).is_greater(first)
	assert_float(later).is_less(1.0)
	# Once the cooldown is over, the ring is gone.
	_arrange(td)
	await runner.simulate_frames(AFTER_REGROW_FRAMES)
	assert_float(dimmed.shield_down_left).is_equal(0.0)
	assert_int(td.feedback.regrow_rings.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
