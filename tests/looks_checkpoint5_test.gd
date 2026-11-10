extends GdUnitTestSuite

# Graphics checkpoint 5: the styled look of what was added since round 20 (the fight marks, the reactions, the wobble, a
# dimmed person warming, first light, the cue panel, the minimap's dawn edge, the notice panel). Headless uses a dummy
# renderer, so these check state and geometry; the screenshots (tools/checkpoint_shots.py --set round24) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	return {"td": td, "runner": runner}


# A settled ring of rescued people round the origin (a border).
func _ring_level(count: int, r: float) -> Dictionary:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	return s


func test_the_styled_fight_marks_are_flat_pieces_and_follow_the_look() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var fx := td.burst_cue.fx
	td.set_look(Looks.Mode.STYLED)
	fx.sync(0.016)
	assert_bool(fx.is_styled_built()).is_true()
	# Results: a halo on each lifted person, a streak for the burst, a count where they landed.
	var cleared: Array = [{"person": td.people[0], "from": Vector3(1, 0, 1), "to": Vector3(5, 0, 1)}]
	fx.add_burst(cleared)
	fx.add_lift_result(cleared)
	fx.sync(0.016)
	assert_int(fx.streak_count()).is_equal(1)
	assert_int(fx.halo_count()).is_equal(1)
	assert_int(fx.result_text_count()).is_equal(1)
	# Back to the placeholder look: the pools are rebuilt with the plain shapes.
	td.set_look(Looks.Mode.PLACEHOLDER)
	fx.sync(0.016)
	assert_bool(fx.is_styled_built()).is_false()
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_person_glows_hops_and_opens_a_ring_in_a_reaction() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[2]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var look := m.look as PersonLookStyled
	m.react(Person.React.LIFT, PeopleConfig.REACT_LIFT_SECONDS)
	var top := 0.0
	var lit := false
	var ringed := false
	for _i: int in range(int(PeopleConfig.REACT_LIFT_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, look.visual.position.y)
		lit = lit or look._react_amount > 0.2
		ringed = ringed or (look._react_ring != null and look._react_ring.visible)
	assert_float(top).is_greater(PeopleConfig.REACT_LIFT_HOP_HEIGHT * 0.5)
	assert_bool(lit).is_true()
	assert_bool(ringed).is_true()
	await runner.simulate_frames(20)
	assert_float(look.visual.position.y).is_equal(0.0)
	assert_bool(look._react_ring.visible).is_false()
	# The body took the tint: a toon mesh of the shown body carries it while lit, and none afterwards.
	assert_object(look._light_meshes[PersonLook.Kind.JOYFUL]).is_not_null()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_wobble_greys_and_shakes() -> void:
	# Round 25: the wobble's closing ring at the feet is gone; round 26: so are the wobble markers (the edge pointers
	# and the minimap blip carry the warning).
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var look := m.look as PersonLookStyled
	m.joy = 0.0
	m._start_wobble()
	m.wobble_left = m.wobble_total * 0.9
	m._update_visuals()
	await runner.simulate_frames(1)
	assert_bool(look.wobbling).is_true()
	# A wobble keeps the joyful body (no flicker to the grey one).
	assert_int(look.shown_kind()).is_equal(PersonLook.Kind.JOYFUL)
	# Saved: the wobble ends.
	m.joy = m.joy_needed()
	m.wobbling = false
	m._update_visuals()
	assert_bool(look.wobbling).is_false()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_dimmed_person_warms_as_joy_builds() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(10, 0, 10), p.affinity, 0.95)
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var look := p.look as PersonLookStyled
	var haze: Node3D = look._parts[PersonLook.Kind.DIMMED]["haze"]
	assert_float(haze.scale.x).is_equal_approx(1.0, 0.01)
	p.joy = p.joy_needed() * 0.9
	p._update_visuals()
	assert_float(haze.scale.x).is_less(0.6)
	assert_object(look._light_meshes[PersonLook.Kind.DIMMED]).is_not_null()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_styled_first_light_lights_the_ground_the_motes_and_the_sky() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	td.running = false
	td.night.elapsed = NightConfig.NIGHT_LENGTH - NightConfig.FIRST_LIGHT_SECONDS * 0.5
	td.first_light.step(0.0)
	var ground := td.ground.look as GroundLookStyled
	assert_float(ground.dawn_front()).is_equal_approx(td.first_light.edge(), 0.001)
	assert_int(td.first_light.tint_visible_count()).is_equal(0)
	assert_int(td.first_light._styled.mote_count()).is_greater(0)
	var sky := td.environment().background_color
	assert_bool(sky.is_equal_approx(ViewPipeline.STYLED_BACKGROUND)).is_false()
	assert_bool(sky.is_equal_approx(StyleFirstLight.sky_at(0.5))).is_true()
	# The motes ride the round front: each one is at the front's radius or a little outside it.
	var e := td.first_light.edge()
	var motes: PackedVector3Array = td.first_light._styled.mote_positions()
	assert_int(motes.size()).is_equal(td.first_light._styled.mote_count())
	for o: Vector3 in motes:
		assert_float(Vector2(o.x, o.z).length()).is_between(e - 0.01, e + 2.5)
	# The placeholder look shows its ring again and the motes go.
	td.set_look(Looks.Mode.PLACEHOLDER)
	td.first_light.step(0.0)
	assert_int(td.first_light.tint_visible_count()).is_equal(1)
	assert_int(td.first_light._styled.mote_count()).is_equal(0)
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_cue_is_a_panel_that_lights_when_ready() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player.add_spirit(100.0)
	td.burst_cue.burst_targets = 3
	td.set_look(Looks.Mode.STYLED)
	td.burst_cue._update_label()
	assert_bool(td.burst_cue.cue_panel.visible).is_true()
	assert_bool(td.burst_cue.cue_label.visible).is_false()
	assert_bool(td.burst_cue.cue_panel.cue_ready).is_true()
	assert_str(td.burst_cue.cue_panel.cue_text).is_equal(HudConfig.CUE_BURST_TEXT % 3)
	assert_float(td.burst_cue.cue_panel.size.x).is_greater(StyleDawn.cue_size("").x)
	td.set_look(Looks.Mode.PLACEHOLDER)
	td.burst_cue._update_label()
	assert_bool(td.burst_cue.cue_panel.visible).is_false()
	assert_bool(td.burst_cue.cue_label.visible).is_true()
	td.burst_cue.burst_targets = 0
	td.burst_cue._update_label()
	assert_bool(td.burst_cue.cue_label.visible).is_false()
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_minimap_warms_the_lit_ground() -> void:
	var plain := MinimapLookPlaceholder.new()
	var styled := MinimapLookStyled.new()
	var base := Color(0.5, 0.5, 0.5)
	assert_bool(plain.first_light("ink", base, 0, 0).a == 0.0).is_true()
	assert_bool(styled.first_light("ink", base, 0, 0).a == 1.0).is_true()
	var strong := styled.first_light("ground", base, 0, 0)
	var weak := styled.first_light("ground", base, 1, 0)
	assert_bool(strong.is_equal_approx(weak)).is_false()
	assert_bool(plain.first_light("line", base, 0, 0).is_equal_approx(NightConfig.FIRST_LIGHT_MINIMAP_COLOUR)).is_true()
	(
		assert_bool(styled.first_light("line", base, 0, 0).is_equal_approx(NightConfig.FIRST_LIGHT_MINIMAP_COLOUR))
		. is_false()
	)


func test_the_styled_minimap_draws_a_dark_line_just_ahead_of_the_dawn_front() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	td.minimap.rebuild_look()
	td.minimap.first_light_edge = 30.0
	td.minimap._render()
	assert_bool(td.minimap.look.first_light("ink", Color.WHITE, 0, 0).a > 0.0).is_true()
	td.set_look(Looks.Mode.PLACEHOLDER)
	td.minimap.rebuild_look()
	td.minimap.first_light_edge = -1.0
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_an_idle_cue_panel_draws_as_a_quiet_tag() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var panel: StyledPanel = auto_free(StyledPanel.new())
	panel.kind = StyledPanel.Kind.CUE
	panel.size = StyleDawn.cue_size("G: lift 2")
	add_child(panel)
	panel.set_cue("G: lift 2", false, 1)
	await await_idle_frame()
	await await_idle_frame()
	assert_bool(panel.cue_ready).is_false()
	assert_str(panel.cue_text).is_equal("G: lift 2")


func test_an_empty_cue_draws_nothing() -> void:
	var ci: Control = auto_free(Control.new())
	StyleDawn.draw_cue(ci, "", true, 0)
	assert_bool(ci.is_inside_tree()).is_false()


func test_the_styled_notice_and_the_burst_ring_are_built_without_the_placeholder_marks() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	td.intro.enabled = true
	td.intro.notice(Intro.Prompt.SPIRIT_LOW)
	td.intro.time_left = td.intro.duration
	await runner.simulate_frames(10)
	assert_bool(td.prompts.big).is_true()
	assert_float(td.prompts.alpha).is_greater(0.0)
	# The styled burst is two flat rings in the level (the placeholder disc registers a "burst ring" fallback).
	var before := Looks.placeholder_fallback_count()
	td.player.look.play_burst(SpiritConfig.BURST_CLEAR_RADIUS, SpiritConfig.TD_BURST_TIME)
	assert_int(Looks.placeholder_fallback_count()).is_equal(before)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_motes_fit_their_room_even_at_a_corner_of_the_front() -> void:
	var lights := StyleFirstLight.new()
	var root: Node3D = auto_free(Node3D.new())
	lights.build(root)
	lights.sync(50.0, Vector3(40.0, 0.0, 40.0), 1.0)
	assert_int(lights.mote_count()).is_greater(0)
	assert_int(lights.mote_count()).is_less_equal(lights._multi.instance_count)
	lights.sync(0.5, Vector3.ZERO, 2.0)
	assert_int(lights.mote_count()).is_less_equal(lights._multi.instance_count)
	lights.hide()
	assert_int(lights.mote_count()).is_equal(0)


func test_a_styled_border_hides_its_ribbon_when_it_is_not_live() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(12)
	var look := td.border.look as BorderLookStyled
	look._last_frame = -100000
	look.refresh()
	assert_bool(look._ribbon.visible).is_true()
	assert_int(look.strips.size()).is_greater(0)
	td.border.active = false
	look.refresh()
	assert_bool(look._ribbon.visible).is_false()
	assert_bool(look._gold_motes.visible).is_false()
	assert_int(look.strips.size()).is_equal(0)
	td.border.active = true
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_burst_with_no_parent_is_ignored() -> void:
	var look := PlayerLookStyled.new()
	var player: TopDownPlayer = auto_free(TopDownPlayer.new())
	look.subject = player
	look.play_burst(5.0, 0.3)
	look.free()
