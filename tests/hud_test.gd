extends GdUnitTestSuite

# HUD text and panels, set directly (the HUD only displays what the modes tell it).


func _make_hud() -> Hud:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	return hud


func test_night_bar_shows_dusk_to_dawn_progress() -> void:
	var hud: Hud = _make_hud()
	hud.set_night_progress(0.0)
	assert_float(hud.night_bar.value).is_equal_approx(0.0, 0.001)
	hud.set_night_progress(0.5)
	assert_float(hud.night_bar.value).is_equal_approx(50.0, 0.001)
	hud.set_night_progress(2.0)
	assert_float(hud.night_bar.value).is_equal_approx(100.0, 0.001)


func test_target_and_rescued_text() -> void:
	var hud: Hud = _make_hud()
	hud.set_target(-1)
	assert_str(hud.element_label.text).is_equal("No target")
	for e: int in range(3):
		hud.set_target(e)
		assert_str(hud.element_label.text).is_equal("Target: " + Config.ELEMENT_NAMES[e])
	hud.set_rescued(3, 20)
	assert_str(hud.rescued_label.text).is_equal("Rescued: 3 / 20")


func test_hint() -> void:
	var hud: Hud = _make_hud()
	hud.set_hint("hello hint")
	assert_str(hud.hint_label.text).is_equal("hello hint")


func test_burst_text() -> void:
	var hud: Hud = _make_hud()
	hud.set_burst(0.0)
	assert_str(hud.burst_label.text).is_equal("Joy burst [G]: READY")
	hud.set_burst(3.2)
	assert_str(hud.burst_label.text).is_equal("Joy burst [G]: 3.2s")


func test_alert_starts_opaque() -> void:
	var hud: Hud = _make_hud()
	hud.show_alert("Someone lost their joy!")
	assert_str(hud.alert_label.text).is_equal("Someone lost their joy!")
	assert_float(hud.alert_label.modulate.a).is_equal_approx(1.0, 0.001)


func test_end_screen_shows_the_title_and_the_detail_lines() -> void:
	var hud: Hud = _make_hud()
	hud.show_end("Dawn", "Landmark held: no\nPlaza beautified: 40%")
	assert_bool(hud.end_panel.visible).is_true()
	assert_str(hud.end_label.text).contains("Dawn")
	assert_str(hud.end_label.text).contains("Plaza beautified: 40%")


func test_a_second_alert_restarts_the_fade() -> void:
	var hud: Hud = _make_hud()
	hud.show_alert("First")
	# Let the first alert start fading (its tween is still running), then send a second one.
	await get_tree().create_timer(0.2).timeout
	hud.show_alert("Second")
	assert_str(hud.alert_label.text).is_equal("Second")
	assert_float(hud.alert_label.modulate.a).is_equal_approx(1.0, 0.001)


func test_spirit_bar_and_label_show_spirit_and_dim() -> void:
	var hud: Hud = _make_hud()
	hud.set_spirit(65.0, false)
	assert_bool(hud.spirit_bar.visible).is_true()
	assert_float(hud.spirit_bar.value).is_equal_approx(65.0, 0.001)
	assert_str(hud.spirit_label.text).is_equal("Spirit 65 / 100")
	hud.set_spirit(0.0, true)
	assert_str(hud.spirit_label.text).contains("DIM")


func test_the_burst_text_needs_spirit_then_says_ready() -> void:
	var hud: Hud = _make_hud()
	hud.set_burst(0.0, false)
	assert_str(hud.burst_label.text).is_equal("Joy burst [G]: needs 30 spirit")
	hud.set_burst(0.0, true)
	assert_str(hud.burst_label.text).is_equal("Joy burst [G]: READY")


func test_the_rec_mark_is_built_once_shown_and_hidden() -> void:
	var hud: Hud = _make_hud()
	# Switching it off before it was ever shown builds nothing.
	hud.set_recording(false)
	assert_object(hud.rec_label).is_null()
	hud.set_recording(true)
	var mark := hud.rec_label
	assert_object(mark).is_not_null()
	assert_bool(mark.visible).is_true()
	assert_str(mark.text).contains("REC")
	hud.set_recording(false)
	assert_bool(mark.visible).is_false()
	# Showing it again reuses the same label.
	hud.set_recording(true)
	assert_object(hud.rec_label).is_same(mark)
	assert_bool(mark.visible).is_true()


# Checkpoint 5 follow-up: the burst line (bottom left) ran into the spirit label (bottom centre, left of its bar) in
# both looks. The spirit label now sits above its bar. This checks the longest burst line and the spirit label never
# overlap at the 1280x720 window, in the placeholder and the styled look (the HUD is drawn at full window size in both).
func _text_rect(label: Label, text: String) -> Rect2:
	var font_px := label.get_theme_font_size("font_size")
	var text_size := label.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px)
	return Rect2(label.get_global_position(), text_size)


func _check_no_overlap(td: TopDownMain) -> void:
	var hud: Hud = td.hud
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	# The longest burst line the game shows: READY with the most dimmed.
	var burst_rect := _text_rect(hud.burst_label, "Joy burst [G]: READY - clears 99 dimmed")
	# The spirit label's box (the bar's width): wider than either spirit text, so clear of the box means clear of the text.
	var spirit_rect := hud.spirit_label.get_global_rect()
	var bar_rect := hud.spirit_bar.get_global_rect()
	assert_bool(burst_rect.intersects(spirit_rect)).is_false()
	assert_bool(spirit_rect.intersects(bar_rect)).is_false()
	# The burst line also stops before the bar itself (the bar is the spirit meter's whole width at bottom centre).
	assert_bool(burst_rect.intersects(bar_rect)).is_false()
	assert_bool(screen.encloses(burst_rect)).is_true()
	assert_bool(screen.encloses(spirit_rect)).is_true()


func test_the_burst_line_and_the_spirit_label_never_overlap_at_1280_by_720() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	assert_bool(td.hud.spirit_label.visible).is_true()
	_check_no_overlap(td)
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	_check_no_overlap(td)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_rescued_counter_is_clear_of_the_minimap_and_inside_the_window_at_1280_by_720() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	var rescued_rect := td.hud.rescued_label.get_global_rect()
	assert_bool(td.minimap.get_global_rect().intersects(rescued_rect)).is_false()
	assert_bool(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(rescued_rect)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
