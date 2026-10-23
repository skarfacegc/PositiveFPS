extends GdUnitTestSuite

# HUD text and panels, set directly (the HUD only displays what the modes tell it).


func _make_hud() -> Hud:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	return hud


func test_timer_text() -> void:
	var hud: Hud = _make_hud()
	hud.set_time(125.0)
	assert_str(hud.timer_label.text).is_equal("2:05")
	hud.set_time(-3.0)
	assert_str(hud.timer_label.text).is_equal("0:00")


func test_element_and_rescued_text() -> void:
	var hud: Hud = _make_hud()
	for e: int in range(3):
		hud.set_element(e)
		assert_str(hud.element_label.text).is_equal("Element: " + Config.ELEMENT_NAMES[e])
	hud.set_rescued(3, 20)
	assert_str(hud.rescued_label.text).is_equal("Rescued: 3 / 20")


func test_hint_and_crosshair() -> void:
	var hud: Hud = _make_hud()
	hud.set_hint("hello hint")
	assert_str(hud.hint_label.text).is_equal("hello hint")
	hud.set_crosshair_visible(false)
	assert_bool(hud.crosshair.visible).is_false()


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


func test_end_screen_with_and_without_buildings() -> void:
	var hud: Hud = _make_hud()
	hud.show_end([], "Time's up!")
	assert_bool(hud.end_panel.visible).is_true()
	assert_str(hud.end_label.text).contains("Time's up!")
	assert_str(hud.end_label.text).contains("None yet")
	hud.show_end(["Cafe", "Music Shop"], "Everyone's happy!")
	assert_str(hud.end_label.text).contains("Music Shop")
	assert_str(hud.end_label.text).not_contains("None yet")
