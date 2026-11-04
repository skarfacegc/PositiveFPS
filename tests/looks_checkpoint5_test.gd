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
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	return s


func test_the_styled_fight_marks_are_dithered_pieces_and_follow_the_look() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var fx := td.gap_patch.fx
	var warnings: Array[Dictionary] = [{"pos": Vector3(3, 0, 3), "urgency": 0.8, "person": null}]
	var patches: Array[Dictionary] = [{"pos": Vector3(-4, 0, 2), "left": 10.0}]
	td.set_look(Looks.Mode.STYLED)
	fx.sync(0.016, warnings, patches)
	assert_bool(fx.is_styled_built()).is_true()
	assert_int(fx.warning_ring_count()).is_equal(1)
	assert_int(fx.warning_ping_count()).is_equal(1)
	assert_int(fx.patch_disc_count()).is_equal(1)
	assert_int(fx.patch_post_count()).is_equal(Config.CP5_PATCH_POSTS)
	# A mild strain has no ping. A patch about to run out flickers its posts (only some show at a time).
	warnings[0]["urgency"] = 0.2
	patches[0]["left"] = 1.0
	fx.sync(0.016, warnings, patches)
	assert_int(fx.warning_ping_count()).is_equal(0)
	assert_int(fx.patch_post_count()).is_less(Config.CP5_PATCH_POSTS)
	# Results: a halo and a column on each lifted person, a pulse and a count for a patch, a streak for the burst.
	var cleared: Array = [{"person": td.people[0], "from": Vector3(1, 0, 1), "to": Vector3(5, 0, 1)}]
	fx.add_burst(cleared)
	fx.add_lift_result(cleared)
	fx.add_patch_result(Vector3(-4, 0, 2), 3)
	fx.sync(0.016, warnings, patches)
	assert_int(fx.streak_count()).is_equal(1)
	assert_int(fx.halo_count()).is_equal(1)
	assert_bool(fx._halo_beams[0].visible).is_true()
	assert_int(fx.pulse_count()).is_equal(1)
	assert_int(fx.result_text_count()).is_equal(2)
	# A wobbling member has its own closing ring, so its strain ring is left out.
	var wobbler: Person = td.people[1]
	wobbler.wobbling = true
	var strained: Array[Dictionary] = [{"pos": Vector3.ZERO, "urgency": 1.0, "person": wobbler}]
	fx.sync(0.016, strained, patches)
	assert_int(fx.warning_ring_count()).is_equal(0)
	# Fewer warnings and patches than before: the spare pings and posts are hidden.
	var two_patches: Array[Dictionary] = [patches[0], {"pos": Vector3(4, 0, 4), "left": 10.0}]
	var two_warnings: Array[Dictionary] = [
		{"pos": Vector3(3, 0, 3), "urgency": 0.9, "person": null},
		{"pos": Vector3(5, 0, 3), "urgency": 0.9, "person": null}
	]
	fx.sync(0.016, two_warnings, two_patches)
	assert_int(fx.warning_ping_count()).is_equal(2)
	fx.sync(0.016, [], [])
	assert_int(fx.warning_ping_count()).is_equal(0)
	assert_int(fx.patch_post_count()).is_equal(0)
	# Back to the placeholder look: the pools are rebuilt with the plain shapes.
	td.set_look(Looks.Mode.PLACEHOLDER)
	fx.sync(0.016, warnings, patches)
	assert_bool(fx.is_styled_built()).is_false()
	assert_int(fx.warning_ring_count()).is_equal(1)
	assert_int(fx.warning_ping_count()).is_equal(0)
	assert_int(fx.patch_post_count()).is_equal(0)
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
	m.react(Person.React.LIFT, Config.REACT_LIFT_SECONDS)
	var top := 0.0
	var lit := false
	var ringed := false
	for _i: int in range(int(Config.REACT_LIFT_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, look.visual.position.y)
		lit = lit or look._react_amount > 0.2
		ringed = ringed or (look._react_ring != null and look._react_ring.visible)
	assert_float(top).is_greater(Config.REACT_LIFT_HOP_HEIGHT * 0.5)
	assert_bool(lit).is_true()
	assert_bool(ringed).is_true()
	await runner.simulate_frames(20)
	assert_float(look.visual.position.y).is_equal(0.0)
	assert_bool(look._react_ring.visible).is_false()
	# The body took the tint: a toon mesh of the shown body carries it while lit, and none afterwards.
	assert_object(look._light_meshes[PersonLook.Kind.JOYFUL]).is_not_null()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_wobble_greys_shakes_and_closes_a_ring() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var m: Person = td.border.members[4]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var look := m.look as PersonLookStyled
	assert_object(look._wobble_ring).is_null()
	m.joy = 0.0
	m._start_wobble()
	m.wobble_left = m.wobble_total * 0.9
	m._update_visuals()
	await runner.simulate_frames(1)
	assert_bool(look.wobbling).is_true()
	assert_bool(look._wobble_ring.visible).is_true()
	var early := look._wobble_ring.scale.x
	# A wobble keeps the joyful body (no flicker to the grey one) and its holder shakes.
	assert_int(look.shown_kind()).is_equal(PersonLook.Kind.JOYFUL)
	m.wobble_left = m.wobble_total * 0.1
	m._update_visuals()
	assert_float(look._wobble_ring.scale.x).is_less(early)
	# Saved: the ring goes.
	m.joy = m.joy_needed()
	m.wobbling = false
	m._update_visuals()
	assert_bool(look._wobble_ring.visible).is_false()
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
	td.night.elapsed = Config.NIGHT_LENGTH - Config.FIRST_LIGHT_SECONDS * 0.5
	td.first_light.step(0.0)
	var ground := td.ground.look as GroundLookStyled
	assert_float(ground.dawn_front()).is_equal_approx(td.first_light.edge(), 0.001)
	assert_int(td.first_light.tint_visible_count()).is_equal(0)
	assert_int(td.first_light._styled.mote_count()).is_greater(0)
	var sky := td.environment().background_color
	assert_bool(sky.is_equal_approx(ViewPipeline.STYLED_BACKGROUND)).is_false()
	assert_bool(sky.is_equal_approx(StyleFirstLight.sky_at(0.5))).is_true()
	# The placeholder look shows its strips again and the motes go.
	td.set_look(Looks.Mode.PLACEHOLDER)
	td.first_light.step(0.0)
	assert_int(td.first_light.tint_visible_count()).is_equal(4)
	assert_int(td.first_light._styled.mote_count()).is_equal(0)
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_cue_is_a_panel_that_lights_when_ready() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player.add_spirit(100.0)
	td.gap_patch.burst_targets = 3
	td.set_look(Looks.Mode.STYLED)
	td.gap_patch._update_label()
	assert_bool(td.gap_patch.cue_panel.visible).is_true()
	assert_bool(td.gap_patch.patch_label.visible).is_false()
	assert_bool(td.gap_patch.cue_panel.cue_ready).is_true()
	assert_str(td.gap_patch.cue_panel.cue_text).is_equal(Config.CUE_BURST_TEXT % 3)
	assert_float(td.gap_patch.cue_panel.size.x).is_greater(StyleDawn.cue_size("").x)
	td.set_look(Looks.Mode.PLACEHOLDER)
	td.gap_patch._update_label()
	assert_bool(td.gap_patch.cue_panel.visible).is_false()
	assert_bool(td.gap_patch.patch_label.visible).is_true()
	td.gap_patch.burst_targets = 0
	td.gap_patch._update_label()
	assert_bool(td.gap_patch.patch_label.visible).is_false()
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_minimap_warms_and_dithers_the_lit_ground() -> void:
	var plain := MinimapLookPlaceholder.new()
	var styled := MinimapLookStyled.new()
	var base := Color(0.5, 0.5, 0.5)
	assert_bool(plain.first_light("ink", base, 0, 0).a == 0.0).is_true()
	assert_bool(styled.first_light("ink", base, 0, 0).a == 1.0).is_true()
	var strong := styled.first_light("ground", base, 0, 0)
	var weak := styled.first_light("ground", base, 1, 0)
	assert_bool(strong.is_equal_approx(weak)).is_false()
	assert_bool(plain.first_light("line", base, 0, 0).is_equal_approx(Config.FIRST_LIGHT_MINIMAP_COLOUR)).is_true()
	assert_bool(styled.first_light("line", base, 0, 0).is_equal_approx(Config.FIRST_LIGHT_MINIMAP_COLOUR)).is_false()


func test_the_styled_reach_preview_marks_a_limited_zone_and_tags_a_stretch() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.player.add_spirit(100.0)
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var guide: StyleReach = td.reach_guide._styled
	# Aimed at a spot already inside the zone the plan has a reason: the preview is coral with a cross and the hatching.
	var dir := Vector3(1, 0, 0)
	var edge: float = td.border.stretch_info()["radius"]
	td.player._aim_point = td.border.centre + dir * (edge * 0.5)
	td.player._has_aim = true
	td.reach_guide.sync(td.border, td.player)
	assert_bool(guide.showing_preview).is_true()
	assert_bool(guide.showing_limited).is_true()
	assert_bool(guide._cross.visible).is_true()
	# Only "already inside the zone": the outline and the cross, no hatching over the whole zone.
	assert_bool(guide._fill.visible).is_false()
	# A finished stretch draws the wave and the ring until the pulse ends, and then hides them.
	td.reach_guide._on_zone_grew(30.0, td.border.centre + dir * 9.0, 0.0)
	td.reach_guide.sync(td.border, td.player)
	assert_bool(guide._pulse_ring.visible).is_true()
	assert_bool(guide._wave.visible).is_true()
	guide.end_pulse()
	assert_bool(guide._pulse_ring.visible).is_false()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_notice_and_the_burst_ring_are_built_without_the_placeholder_marks() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	td.intro.enabled = true
	td.intro.notice(Intro.Prompt.PATCH_NONE)
	td.intro.time_left = td.intro.duration
	await runner.simulate_frames(10)
	assert_bool(td.prompts.big).is_true()
	assert_float(td.prompts.alpha).is_greater(0.0)
	# The styled burst is two dithered rings in the level (the placeholder disc registers a "burst ring" fallback).
	var before := Looks.placeholder_fallback_count()
	td.player.look.play_burst(Config.BURST_CLEAR_RADIUS, Config.TD_BURST_TIME)
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


func test_the_reach_ribbons_skip_degenerate_segments() -> void:
	var guide := StyleReach.new()
	var root: Node3D = auto_free(Node3D.new())
	guide.build(root)
	var mesh := ImmediateMesh.new()
	guide._ribbon(mesh, PackedVector2Array([Vector2.ZERO]), false, 0.5, 0.0)
	assert_int(mesh.get_surface_count()).is_equal(0)
	guide._ribbon(mesh, PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2(2, 0)]), false, 0.5, 0.0)
	assert_int(mesh.get_surface_count()).is_equal(1)
	var pairs: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO, Vector2(1, 1), Vector2(3, 1)]
	guide._ribbon_pairs(mesh, pairs, 0.5, 0.0)
	assert_int(mesh.get_surface_count()).is_equal(1)


func test_the_stretching_tag_shows_hides_and_ignores_repeats() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var tag: StyleReachTag = auto_free(StyleReachTag.new())
	add_child(tag)
	tag.show_at("", Vector2(10, 10))
	assert_bool(tag.visible).is_false()
	tag.show_at(StyleReach.WORDS, Vector2(100, 100))
	assert_bool(tag.visible).is_true()
	tag.show_at(StyleReach.WORDS, Vector2(100, 100))
	assert_str(tag.text).is_equal(StyleReach.WORDS)
	await await_idle_frame()
	tag.show_at("", Vector2.ZERO)
	assert_bool(tag.visible).is_false()
	tag.hide_tag()
	assert_str(tag.text).is_equal("")


func test_a_styled_border_hides_its_gap_marks_when_it_is_not_live() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	td.border.segment_gap[0] = true
	await runner.simulate_frames(12)
	var look := td.border.look as BorderLookStyled
	td.border.segment_gap[0] = true
	look._last_frame = -100000
	look.refresh()
	assert_int(look._gap_beams.size()).is_greater(0)
	td.border.active = false
	look.refresh()
	for beam: MeshInstance3D in look._gap_beams:
		assert_bool(beam.visible).is_false()
	for ring: MeshInstance3D in look._gap_rings:
		assert_bool(ring.visible).is_false()
	td.border.active = true
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_burst_with_no_parent_is_ignored_and_the_beacon_colour_is_teal() -> void:
	var look := PlayerLookStyled.new()
	var player: TopDownPlayer = auto_free(TopDownPlayer.new())
	look.subject = player
	look.play_burst(5.0, 0.3)
	look.free()
	assert_bool(MinimapLookStyled.new().beacon_colour().is_equal_approx(Color("#9cf0dc"))).is_true()
