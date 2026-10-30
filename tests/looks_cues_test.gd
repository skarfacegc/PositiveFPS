extends GdUnitTestSuite

# Graphics checkpoint 2: the styled look of the round 12a-17 cues (wedge, grab ring, glint, ripple, the sealed map
# edge, the pixel icons and the screen-space overlays). Same approach as looks_test.gd: headless uses a dummy renderer,
# so these check the wiring and that every styled drawing path runs; the screenshots (tools/checkpoint_shots.py) check
# the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _start(styled: bool = false) -> Dictionary:
	Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(30)
	return {"runner": runner, "td": runner.scene()}


func _rescue_ring(runner: GdUnitSceneRunner, td: TopDownMain, count: int) -> void:
	TopDownTestUtil.send_everyone_away(td)
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p := td.people[i]
		TopDownTestUtil.place(p, Vector3(12.0 + cos(a) * 4.0, 0.0, -12.0 + sin(a) * 4.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	await runner.simulate_frames(240)


# ---- Graphics checkpoint 2: the styled cues of rounds 12a-17 (purely visual: the rules never read them) -------------


# A Control that runs `fn` (given itself) in its _draw, so the drawing helpers can be called where Godot allows it.
class DrawProbe:
	extends Control
	var fn: Callable
	var drew: int = 0

	func _draw() -> void:
		fn.call(self)
		drew += 1


func _probe(fn: Callable) -> DrawProbe:
	var probe: DrawProbe = auto_free(DrawProbe.new())
	probe.fn = fn
	probe.size = Vector2(400, 300)
	add_child(probe)
	return probe


func test_the_styled_guarded_wedge_follows_the_rule_and_hides() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	td.running = false
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -6), 0, 0.2)
	p.mood = Person.Mood.GUARDED
	p.rotation.y = PI  # facing +z, toward the player at the origin
	td.player.global_position = Vector3.ZERO
	p.shooter_pos = Vector3.ZERO
	p._update_visuals()
	var look := p.look as PersonLookStyled
	var mat := look.guard_wedge.material_override as ShaderMaterial
	assert_object(mat).is_not_null()
	assert_bool(look.guard_wedge.visible).is_true()
	assert_bool(look.wedge_open).is_true()
	var open_density: float = mat.get_shader_parameter("density")
	# Turned away: the wedge stays but dims (less dither).
	p.rotation.y = 0.0
	p._update_visuals()
	assert_bool(look.wedge_open).is_false()
	var closed_density: float = mat.get_shader_parameter("density")
	assert_float(open_density).is_greater(closed_density)
	var half: float = mat.get_shader_parameter("half_angle")
	var radius: float = mat.get_shader_parameter("radius")
	assert_float(half).is_equal_approx(deg_to_rad(Config.GUARDED_ARC_DEG), 0.001)
	assert_float(radius).is_equal_approx(Config.GUARDED_WEDGE_RADIUS, 0.001)
	# Not guarded: gone. And it is no longer listed as a placeholder.
	p.mood = Person.Mood.GLUM
	p._update_visuals()
	assert_bool(look.guard_wedge.visible).is_false()
	assert_str(Looks.fallback_summary()).not_contains("wedge")
	assert_str(Looks.fallback_summary()).not_contains("ripple")
	assert_str(Looks.fallback_summary()).not_contains("glint")
	assert_str(Looks.fallback_summary()).not_contains("grab")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_styled_grab_ring_glint_and_ripple() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var dimmed: Person = auto_free(Person.new())
	dimmed.gloom = 0.95
	add_child(dimmed)
	dimmed.grab_frac = 0.2
	dimmed.tick(0.016)
	var look := dimmed.look as PersonLookStyled
	var ring := look.grab_ring.material_override as ShaderMaterial
	assert_bool(look.grab_ring.visible).is_true()
	var early: float = ring.get_shader_parameter("density")
	dimmed.grab_frac = 0.9
	dimmed.tick(0.016)
	var late: float = ring.get_shader_parameter("density")
	assert_float(late).is_greater(early)
	dimmed.grab_frac = 0.0
	dimmed.tick(0.016)
	assert_bool(look.grab_ring.visible).is_false()
	# The glum glint is a sparkle of two diamonds, shown only while they look up.
	assert_object(look.glint.mesh).is_null()
	assert_int(look.glint.get_child_count()).is_equal(2)
	# The stage ripple is a dithered ring that spreads and frees itself.
	look.play_ripple(Config.STAGE_SINK_COLOUR)
	var ripples := get_tree().get_nodes_in_group("stage_ripple")
	assert_int(ripples.size()).is_greater(0)
	var node := ripples[0] as MeshInstance3D
	assert_bool(node.material_override is ShaderMaterial).is_true()
	node.queue_free()


func test_the_styled_border_marks_the_sealed_map_edge() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 8)
	td.running = false
	var look := td.border.look as BorderLookStyled
	assert_int(look._seal_w.size()).is_greater(0)
	for w: float in look._seal_w:
		assert_float(w).is_equal(0.0)
	# Seal the whole loop by hand (the rule: Border.is_sealed) and rebuild: every point is sealed in the haze mesh.
	var n := td.border.polygon.size()
	td.border._sealed.clear()
	for j: int in range(n):
		td.border._sealed.append(1.0)
	look._last_frame = -100000
	look.refresh()
	for w: float in look._seal_w:
		assert_float(w).is_equal(1.0)
	assert_object(look._haze.mesh).is_not_null()
	# The minimap draws sealed stretches in the look's seal colour: the same as an intact stretch in the placeholder.
	td.minimap.refresh_from(td.ground, td.border, td.people, Vector3.ZERO, Vector3.ZERO, Vector2(10, 10))
	assert_int(td.minimap.seal_flags.size()).is_equal(td.minimap.border_pts.size())
	assert_bool(td.minimap.seal_flags[0]).is_true()
	var plain := MinimapLookPlaceholder.new()
	var styled := MinimapLookStyled.new()
	assert_bool(plain.seal_colour().is_equal_approx(plain.line_colour(false))).is_true()
	assert_int(plain.seal_width()).is_equal(1)
	assert_bool(styled.seal_colour().is_equal_approx(styled.line_colour(false))).is_false()
	assert_int(styled.seal_width()).is_greater(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_styled_icon_bitmaps_are_whole_and_the_umbrella_wears() -> void:
	for kind: int in range(1, 6):
		var rows := StyleUi.glyph_rows(kind)
		assert_int(rows.size()).is_equal(StyleUi.GLYPH_SIZE + 2)
		for r: String in rows:
			assert_int(r.length()).is_equal(StyleUi.GLYPH_SIZE + 2)
		assert_bool("".join(rows).contains("o")).is_true()
	var fresh := "".join(StyleUi.glyph_rows(MoodIcons.Kind.UMBRELLA, 0))
	var worn := "".join(StyleUi.glyph_rows(MoodIcons.Kind.UMBRELLA, 3))
	assert_str(worn).is_not_equal(fresh)
	assert_int(StyleUi.tatter_for(1.0)).is_equal(0)
	assert_int(StyleUi.tatter_for(0.25)).is_equal(3)
	# Other icons do not tatter.
	assert_array(StyleUi.glyph_rows(MoodIcons.Kind.SHIELD, 3)).is_equal(StyleUi.glyph_rows(MoodIcons.Kind.SHIELD, 0))


func test_the_styled_drawing_helpers_run() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var fn := func(ci: Control) -> void:
		var c := StyleUi.cell(ci)
		StyleUi.rect(ci, Rect2(3, 3, 40, 20), c, Color.WHITE)
		StyleUi.cut_rect(ci, Rect2(3, 3, 40, 20), c, Color.WHITE)
		StyleUi.panel(ci, Rect2(10, 10, 100, 40), c, Color.WHITE)
		StyleUi.ring(ci, Vector2(100, 100), 30.0, c, Color.WHITE, 3)
		StyleUi.ring(ci, Vector2(100, 100), 30.0, c, Color.WHITE, 3, 0.55)
		StyleUi.ring(ci, Vector2(100, 100), 30.0, c, Color.WHITE, 3, 1.0, -1.5, 1.0)
		StyleUi.ring(ci, Vector2(100, 100), 30.0, c, Color.WHITE, 3, 1.0, 0.0, TAU, true)
		StyleUi.ring(ci, Vector2(100, 100), 2.0, c, Color.WHITE, 5)
		StyleUi.line(ci, Vector2(0, 0), Vector2(80, 30), c, Color.WHITE, 2)
		StyleUi.poly(ci, PackedVector2Array([Vector2(5, 5), Vector2(60, 20), Vector2(20, 60)]), c, Color.WHITE)
		StyleUi.sparkle(ci, Vector2(30, 30), 2, c, Color.WHITE)
		for kind: int in range(0, 6):
			MoodIcons.draw(ci, kind, Vector2(200, 100), Config.MOOD_ICON_SIZE, Color(0.6, 0.7, 1.0), 0.3)
		MoodIcons.draw(ci, MoodIcons.Kind.UMBRELLA, Vector2(250, 100), Config.MOOD_ICON_SIZE * 1.8, Color.WHITE, 0.3)
	var probe := _probe(fn)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(probe.drew).is_greater(0)


func test_the_styled_overlays_draw_every_cue_and_swap_with_f4() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 8)
	var dimmed: Person = td.people[20]
	var ward: Person = td.people[21]
	TopDownTestUtil.place(dimmed, td.player.global_position + Vector3(4, 0, 4), 0, 0.95)
	TopDownTestUtil.place(ward, td.player.global_position + Vector3(5, 0, 4), 0, 0.3)
	dimmed.level = 2
	dimmed.shelter_ward = ward
	ward.shielder = dimmed
	ward.sheltered = true
	dimmed.shield_hits = 2
	var guarded: Person = td.people[22]
	TopDownTestUtil.place(guarded, td.player.global_position + Vector3(-4, 0, 3), 0, 0.3)
	guarded.mood = Person.Mood.GUARDED
	td.running = false
	td.set_look(Looks.Mode.STYLED)
	var faller: Person = td.border.members[0]
	faller.joy = faller.joy_needed() * 0.4
	td.border.faltering.append(faller)
	td.feedback.on_blocked(ward, Person.Block.SHELTERED)
	td.feedback.on_blocked(guarded, Person.Block.GUARDED)
	td.feedback.on_dim_joy(dimmed)
	td.feedback.pulse_player(SpiritMeter.Moment.GAIN)
	td.feedback.pulse_player(SpiritMeter.Moment.SPEND)
	td.feedback.pulse_player(SpiritMeter.Moment.LOSS)
	td.feedback.closes.append({"pos": faller.global_position, "left": 0.4, "links": [td.player.global_position]})
	td.feedback.snaps.append({"a": dimmed.chest_position(), "b": ward.chest_position(), "left": 0.2})
	td.feedback.motes.append({"pos": td.player.global_position, "vel": Vector3.ZERO, "age": 0.5, "life": 1.0})
	td.spirit_meter.moment(20.0, SpiritMeter.Moment.GAIN)
	td.spirit_meter.set_values(30.0, true)
	td.intro.enabled = true
	td.intro.current = Intro.Prompt.GUARDED
	td.intro.time_left = 2.0
	await runner.simulate_frames(12)
	assert_bool(Looks.is_styled()).is_true()
	assert_int(td.feedback.icons.size()).is_greater(0)
	assert_int(td.feedback.markers.size()).is_greater(0)
	assert_int(td.feedback.tethers.size()).is_greater(0)
	assert_int(td.feedback.sparks.size()).is_greater(0)
	assert_int(td.feedback.dim_rings.size()).is_greater(0)
	assert_float(td.prompts.alpha).is_greater(0.0)
	td.spirit_meter.set_values(80.0, false)
	await runner.simulate_frames(4)
	# The placeholder look restores the prompt bar's own drawing.
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(6)
	assert_float(td.prompts.self_modulate.a).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# Graphics checkpoint 3 coverage: an empty spirit meter in the styled look has no fill to draw (StyleHud._fill returns
# before it). Whether the empty frame looks right is for the screenshot checkpoint; this checks the path runs.
func test_an_empty_spirit_meter_draws_its_frame_in_the_styled_look() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.lose_spirit(td.player.spirit)
	td.spirit_meter.queue_redraw()
	await runner.simulate_frames(3)
	assert_bool(Looks.is_styled()).is_true()
	assert_float(td.spirit_meter.spirit).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_gap_arrow_draws() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var arrows: GapArrows = auto_free(GapArrows.new())
	add_child(arrows)
	arrows.size = Vector2(400, 300)
	arrows.arrows = [{"pos": Vector2(100, 100), "angle": 0.5, "urgency": 0.5}]
	arrows.queue_redraw()
	await get_tree().process_frame
	arrows.rebuild_look()
	await get_tree().process_frame
	assert_int(arrows.arrows.size()).is_equal(1)
