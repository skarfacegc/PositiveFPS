extends GdUnitTestSuite

# Graphics checkpoint 6: the styled HUD. The edge pointers keep clear of the HUD in both looks, notices are slim banners
# under the Dusk to Dawn bar, and the styled look has its own target highlight and HUD text lines (the placeholder look
# keeps its Labels and its disc). Headless has a dummy renderer, so these check state and geometry; the screenshots
# (tools/checkpoint_shots.py --set round24) check the look.

const SCREEN := Vector2(1280, 720)


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	Config.intro_override = -1


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"td": td, "runner": runner}


func _look(s: Dictionary, mode: int) -> void:
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(mode)
	await runner.simulate_frames(4)


# Gap middles 120 m from the player in eight directions (all well off screen).
func _far_gaps(td: TopDownMain) -> Array[Vector3]:
	var gaps: Array[Vector3] = []
	for k: int in range(8):
		var a := TAU * float(k) / 8.0 + 0.2
		gaps.append(td.player.global_position + Vector3(cos(a), 0.0, sin(a)) * 120.0)
	return gaps


func _check_arrows_clear(td: TopDownMain) -> void:
	var safe := HudSafeArea.current(td, SCREEN)
	assert_bool(safe.has_area()).is_true()
	var avoid := HudSafeArea.avoid_rects(td.hud, td.minimap, td)
	assert_int(avoid.size()).is_greater(4)
	var arrows := GapArrows.off_screen_arrows(
		td.camera,
		Rect2(Vector2.ZERO, SCREEN),
		_far_gaps(td),
		td.minimap.get_global_rect(),
		td.pipeline.view_scale(),
		[],
		safe
	)
	assert_int(arrows.size()).is_equal(8)
	for a: Dictionary in arrows:
		var pos: Vector2 = a["pos"]
		var box := Rect2(pos, Vector2.ZERO).grow(HudConfig.CP6_GAP_ARROW_REACH)
		assert_bool(safe.grow(0.01).encloses(box)).is_true()
		for r: Rect2 in avoid:
			assert_bool(box.intersects(r)).is_false()


func test_gap_arrows_stay_inside_the_safe_rectangle_clear_of_the_hud_in_both_looks() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	_check_arrows_clear(td)
	await _look(s, Looks.Mode.STYLED)
	_check_arrows_clear(td)
	await _look(s, Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_level_hands_the_safe_rectangle_to_the_gap_arrows_and_the_wobble_alert_shares_it() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(5)
	assert_that(td.wobble_alert.safe_rect(SCREEN)).is_equal(
		HudSafeArea.safe_rect(SCREEN, HudSafeArea.avoid_rects(td.hud, td.minimap, td))
	)
	assert_bool(HudSafeArea.usable(Vector2(64, 64))).is_false()
	assert_bool(HudSafeArea.usable(SCREEN)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Notices ----------------------------------------------------------------------------------------------------------


func _check_banner(td: TopDownMain, bar_bottom: float) -> void:
	var bar: PromptBar = td.prompts
	assert_bool(bar.big).is_true()
	assert_float(bar.alpha).is_greater(0.0)
	var r: Rect2 = bar._rect
	assert_float(r.position.y).is_greater_equal(bar_bottom)
	assert_float(r.size.y).is_equal(HudConfig.NOTICE_HEIGHT)
	assert_float(r.size.x).is_less_equal(HudConfig.CP6_BANNER_MAX_WIDTH)
	assert_float(r.get_center().x).is_equal_approx(SCREEN.x * 0.5, 2.0)
	assert_bool(Rect2(Vector2.ZERO, SCREEN).encloses(r)).is_true()
	# It sits above the people: nowhere near the middle of the window.
	assert_float(r.end.y).is_less(SCREEN.y * 0.25)


func _check_banner_clear_of_hud(td: TopDownMain) -> void:
	var r: Rect2 = td.prompts._rect
	for c: Control in td.hud.layout_controls():
		if not c.is_visible_in_tree() or c.modulate.a <= 0.0:
			continue
		assert_bool(r.intersects(c.get_global_rect())).is_false()
	assert_bool(r.intersects(td.minimap.get_global_rect())).is_false()


func test_a_notice_is_a_slim_banner_under_the_top_bar_in_both_looks_and_keeps_its_timing() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		await _look(s, mode)
		td.intro.notice(Intro.Prompt.FIRST_LIGHT, "First light: the ring is closing")
		assert_float(td.intro.time_left).is_equal(HudConfig.NOTICE_SECONDS)
		await runner.simulate_frames(30)
		_check_banner(td, td.hud.night_bar.get_global_rect().end.y)
		_check_banner_clear_of_hud(td)
		# Its timing is the notice's: still up at 3.5 s, gone by NOTICE_SECONDS.
		await runner.simulate_frames(int(3.4 * 60.0))
		assert_int(td.intro.current).is_equal(Intro.Prompt.FIRST_LIGHT)
		await runner.simulate_frames(60)
		assert_int(td.intro.current).is_equal(-1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_long_notice_shrinks_its_text_to_fit_the_banner() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.intro.notice(Intro.Prompt.SPIRIT_LOW, "A very long reason for a refusal, " + "word ".repeat(30))
	await runner.simulate_frames(20)
	assert_float(td.prompts._rect.size.x).is_less_equal(HudConfig.CP6_BANNER_MAX_WIDTH)
	assert_int(td.prompts.font_px).is_less(HudConfig.NOTICE_FONT_SIZE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_an_event_and_a_notice_share_the_one_banner_in_both_looks() -> void:
	# Clean HUD (#92): the HUD's own alert line is gone, so an event (a lost joy) and a notice can never stack.
	Config.intro_override = 1
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	assert_object(td.hud.get("alert_label")).is_null()
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		await _look(s, mode)
		td.intro.event_notice("Someone lost their joy!")
		td.intro.notice(Intro.Prompt.SPIRIT_LOW, "Not enough spirit to take a block.")
		await runner.simulate_frames(10)
		assert_str(td.intro.current_text()).is_equal("Not enough spirit to take a block.")
		assert_float(td.prompts._rect.position.y).is_equal(HudConfig.CP6_BANNER_TOP)
		assert_float(td.prompts._rect.position.y).is_greater_equal(td.hud.night_bar.get_global_rect().end.y)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The styled pieces ------------------------------------------------------------------------------------------------


func _lines(td: TopDownMain) -> Array[StyledPanel]:
	return [td.hud.rescued_panel, td.hud.burst_panel, td.hud.key_panel]


func _labels(td: TopDownMain) -> Array[Label]:
	return [td.hud.rescued_label, td.hud.burst_label, td.hud.hint_label]


func test_the_styled_look_has_its_own_hud_lines_and_the_placeholder_look_keeps_its_labels() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var panels := _lines(td)
	var labels := _labels(td)
	for k: int in range(panels.size()):
		assert_bool(labels[k].visible).is_true()
		assert_bool(panels[k].visible).is_false()
	await _look(s, Looks.Mode.STYLED)
	td.hud.set_burst(0.0, true, 3)  # (The level sets it every frame; this is the line with the most words.)
	for k: int in range(panels.size()):
		assert_bool(labels[k].visible).is_false()
		assert_bool(panels[k].visible).is_true()
		assert_str(panels[k].line_text).is_equal(labels[k].text)
		assert_bool(panels[k].size.x > 40.0 and panels[k].size.y == HudConfig.CP6_LINE_HEIGHT).is_true()
	assert_str(td.hud.burst_panel.line_text).is_equal("Joy burst [G]: READY - clears 3 dimmed")
	assert_int(td.hud.burst_panel.line_state).is_equal(StyleHudText.READY)
	assert_str(td.hud.key_panel.line_text).contains("[F4] look")
	assert_str(td.hud.rescued_panel.line_text).contains("Rescued:")
	# The burst line's state follows the rules text: a wait is dim, a need is a warning.
	td.hud.set_burst(2.5, true, 0)
	assert_int(td.hud.burst_panel.line_state).is_equal(StyleHudText.DIM)
	td.hud.set_burst(0.0, false, 0)
	assert_int(td.hud.burst_panel.line_state).is_equal(StyleHudText.WARN)
	await _look(s, Looks.Mode.PLACEHOLDER)
	for k: int in range(panels.size()):
		assert_bool(labels[k].visible).is_true()
		assert_bool(panels[k].visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_lines_draw_without_errors_and_are_sized_to_their_words() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	await _look(s, Looks.Mode.STYLED)
	for p: StyledPanel in _lines(td):
		p._draw()
	var short := StyleHudText.line_width(StyledPanel.Kind.BURST, "Joy burst [G]: READY")
	var long := StyleHudText.line_width(StyledPanel.Kind.BURST, "Joy burst [G]: READY - clears 3 dimmed")
	assert_float(long).is_greater(short)
	assert_bool(StyleHudText.is_key("WASD")).is_true()
	assert_bool(StyleHudText.is_key("[F4]")).is_true()
	assert_bool(StyleHudText.is_key("G/Q")).is_true()
	assert_bool(StyleHudText.is_key("move")).is_false()
	assert_bool(StyleHudText.is_key("aim,")).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_no_two_styled_hud_panels_overlap_and_all_stay_in_the_window() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	await _look(s, Looks.Mode.STYLED)
	td.hud.set_burst(0.0, true, 99)  # The longest burst line (the level sets it every frame; no frame runs after this).
	var rects: Array[Rect2] = HudSafeArea.avoid_rects(td.hud, td.minimap, td)
	assert_int(rects.size()).is_greater_equal(8)
	var window := Rect2(Vector2.ZERO, SCREEN)
	for i: int in range(rects.size()):
		assert_bool(window.encloses(rects[i])).is_true()
		for j: int in range(i + 1, rects.size()):
			(
				assert_bool(rects[i].intersects(rects[j]))
				. override_failure_message("HUD rectangles %s and %s overlap" % [rects[i], rects[j]])
				. is_false()
			)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_target_highlight_is_a_flat_ring_in_the_styled_look_and_the_warm_disc_in_the_placeholder() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	assert_bool(td.highlight.mesh is CylinderMesh).is_true()
	assert_int(td.highlight.get_child_count()).is_equal(0)
	await _look(s, Looks.Mode.STYLED)
	assert_bool(td.highlight.mesh is PlaneMesh).is_true()
	assert_bool(td.highlight.material_override is ShaderMaterial).is_true()
	var disc := td.highlight.get_node_or_null("TintDisc") as MeshInstance3D
	assert_object(disc).is_not_null()
	# Lock on to a person: the ring follows them and the disc takes their element's colour.
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, td.player.global_position + Vector3(2, 0, 2), Config.Element.NATURE, 0.0)
	td.player.target = p
	td.highlight.sync(0.016)
	assert_bool(td.highlight.visible).is_true()
	var tint: Color = (disc.material_override as ShaderMaterial).get_shader_parameter("fill_color")
	assert_bool(tint.is_equal_approx(Config.ELEMENT_COLORS[Config.Element.NATURE])).is_true()
	assert_str(Looks.fallback_summary()).not_contains("target highlight")
	await _look(s, Looks.Mode.PLACEHOLDER)
	assert_bool(td.highlight.mesh is CylinderMesh).is_true()
	assert_int(td.highlight.get_child_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
