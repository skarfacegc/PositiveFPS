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
