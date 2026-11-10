extends GdUnitTestSuite

# Round 24 (part H): things react. A patch makes the border people at that spot hop, turn toward it and glow; a burst
# makes each lifted person hop and glow; the F and G cues sit on the HUD beside the spirit meter and glow when ready.
# (0.4 removed the beacon's reach preview, the stretch and the pull-in, and their tests here.)


func after_test() -> void:
	Config.intro_override = -1


# The settled start square: `count` rescued people, at midnight, with nobody else about.
func _border_level(count: int) -> Dictionary:
	return await TopDownTestUtil.settled_level(self, count)


# --- A patch makes people react -------------------------------------------------------------------------------------


func test_a_person_who_is_not_reacting_has_no_progress() -> void:
	var s: Dictionary = await _border_level(16)
	var td: TopDownMain = s["td"]
	for p: Person in td.people:
		assert_int(p.react_kind).is_equal(Person.React.NONE)
		assert_float(p.react_progress()).is_equal(-1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_reacting_person_hops_turns_toward_the_spot_glows_then_settles() -> void:
	var s: Dictionary = await _border_level(16)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	var m: Person = td.border.members[4]
	var look := m.look as PersonLookPlaceholder
	# Something off to one side to turn toward.
	var spot := m.position + Vector3(0.0, 0.0, 2.0)
	m.react(Person.React.PATCH, PeopleConfig.REACT_PATCH_SECONDS, spot)
	var top := 0.0
	var turned := 0.0
	var glowed := false
	for _i: int in range(int(PeopleConfig.REACT_PATCH_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, look.visual.position.y)
		turned = maxf(turned, absf(look.visual.rotation.y))
		glowed = glowed or look.body_mat.emission_enabled
	assert_float(top).is_greater(PeopleConfig.REACT_PATCH_HOP_HEIGHT * 0.5)
	assert_float(turned).is_greater(0.2)
	assert_bool(glowed).is_true()
	# Afterwards the body is put back.
	await runner.simulate_frames(20)
	assert_int(m.react_kind).is_equal(Person.React.NONE)
	assert_float(look.visual.position.y).is_equal(0.0)
	assert_float(look.visual.rotation.y).is_equal(0.0)
	assert_bool(look.body_mat.emission_enabled).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_waiting_reaction_does_not_pose_the_body_until_its_turn() -> void:
	var s: Dictionary = await _border_level(16)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[2]
	m.react(Person.React.PATCH, 1.0, m.position + Vector3.RIGHT, 0.5)
	assert_float(m.react_progress()).is_equal(-1.0)
	await runner.simulate_frames(10)
	assert_float(m.look.visual.position.y).is_equal(0.0)
	await runner.simulate_frames(40)
	assert_float(m.react_progress()).is_greater_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- A burst makes the lifted people perk up ------------------------------------------------------------------------


# Merged: covers "the grace glow still works when no one is reacting" (no frames, so it goes first) and "a burst makes
# each lifted person hop and glow warm" (same border level).
func test_the_grace_glow_works_when_no_one_reacts_and_a_burst_makes_each_lifted_person_hop_and_glow_warm() -> void:
	var s: Dictionary = await _border_level(16)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var glow_look := td.people[20].look as PersonLookPlaceholder
	glow_look._set_glow(1.0)
	assert_bool(glow_look.body_mat.emission_enabled).is_true()
	assert_float(glow_look.body_mat.emission_energy_multiplier).is_equal_approx(PeopleConfig.GRACE_GLOW_ENERGY, 0.001)
	glow_look._set_react_glow(PeopleConfig.PATCH_COLOUR, 1.0)
	assert_bool(glow_look.body_mat.emission.is_equal_approx(PeopleConfig.PATCH_COLOUR)).is_true()
	glow_look._set_react_glow(Color.WHITE, 0.0)
	assert_bool(glow_look.body_mat.emission.is_equal_approx(PeopleConfig.GRACE_GLOW_COLOR)).is_true()
	glow_look._set_glow(0.0)
	assert_bool(glow_look.body_mat.emission_enabled).is_false()
	var lifted: Person = td.people[20]
	var other: Person = td.people[21]
	var cleared: Array[Dictionary] = [{"person": lifted, "from": lifted.position, "to": lifted.position}]
	td.burst_cue._on_burst_cleared({"cleared": cleared, "lifted": 1, "joy_hits": 0})
	assert_int(lifted.react_kind).is_equal(Person.React.LIFT)
	assert_int(other.react_kind).is_equal(Person.React.NONE)
	var look := lifted.look as PersonLookPlaceholder
	var top := 0.0
	var warm := false
	for _i: int in range(int(PeopleConfig.REACT_LIFT_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, look.visual.position.y)
		warm = (
			warm
			or (look.body_mat.emission_enabled and look.body_mat.emission.is_equal_approx(SpiritConfig.BURST_FX_COLOUR))
		)
	assert_float(top).is_greater(PeopleConfig.REACT_LIFT_HOP_HEIGHT * 0.5)
	assert_bool(warm).is_true()
	await runner.simulate_frames(20)
	assert_float(look.visual.position.y).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_look_hops_and_turns_in_a_reaction_and_settles() -> void:
	# Graphics checkpoint 5: the styled look reacts too (its bodies face the other way, so the turn is added to PI).
	var s: Dictionary = await _border_level(16)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	m.react(Person.React.PATCH, PeopleConfig.REACT_PATCH_SECONDS, m.position + Vector3.RIGHT * 3.0)
	var top := 0.0
	var turned := 0.0
	for _i: int in range(int(PeopleConfig.REACT_PATCH_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, m.look.visual.position.y)
		turned = maxf(turned, absf(m.look.visual.rotation.y - PI))
	assert_float(top).is_greater(PeopleConfig.REACT_PATCH_HOP_HEIGHT * 0.5)
	assert_float(turned).is_greater(0.2)
	await runner.simulate_frames(20)
	assert_float(m.look.visual.position.y).is_equal(0.0)
	assert_float(m.look.visual.rotation.y).is_equal_approx(PI, 0.0001)
	# The base look's glow hook does nothing (only the placeholder and styled looks glow).
	var base: PersonLook = auto_free(PersonLook.new())
	base._set_react_glow(PeopleConfig.PATCH_COLOUR, 1.0)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The cues are on the HUD beside the spirit meter ----------------------------------------------------------------


func test_the_cue_sits_right_of_the_spirit_meter_and_glows_when_it_is_ready() -> void:
	var s: Dictionary = await _border_level(16)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	td.player.burst_cooldown = 0.0
	td.burst_cue.burst_targets = 2
	td.burst_cue._update_label()
	var label := td.burst_cue.cue_label
	var screen := td.get_viewport().get_visible_rect().size
	assert_bool(label.visible).is_true()
	assert_bool(td.burst_cue.cue_ready).is_true()
	assert_str(label.text).is_equal(HudConfig.CUE_BURST_TEXT % 2)
	assert_float(label.position.x).is_greater(screen.x * 0.5 + HudConfig.SPIRIT_METER_WIDTH * 0.5)
	assert_float(label.position.y).is_greater(screen.y * 0.7)
	var ready_edge := (label.get_theme_stylebox("normal") as StyleBoxFlat).border_color
	assert_float(ready_edge.a).is_greater(0.5)
	# Nobody to lift: the cue goes (and stops glowing).
	td.burst_cue.burst_targets = 0
	td.burst_cue._update_label()
	assert_bool(label.visible).is_false()
	assert_bool(td.burst_cue.cue_ready).is_false()
	await runner.simulate_frames(1)
	await TopDownTestUtil.leave_loaded_scene(td)
