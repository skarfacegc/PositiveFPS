extends GdUnitTestSuite

# Round 20: landmark clarity. The boost lines say what each boost does, a claim or a loss raises a notice on the HUD
# that names the landmark and its boost (and fits the 1280 x 720 window), the landmark itself pulses, and the minimap
# marks a held landmark apart from one not held.


func _landmark(index: int) -> Landmark:
	var lm: Landmark = auto_free(Landmark.new())
	lm.index = index
	return lm


# --- The words ------------------------------------------------------------------------------------------------------


func test_the_boost_lines_say_what_each_boost_does_in_short_words() -> void:
	assert_array(LandmarkConfig.LANDMARK_BOOST_TEXT).is_equal(
		["music x2", "nature x2", "gloom slowed x0.4 nearby", "art (no boost yet)"]
	)
	for text: String in LandmarkConfig.LANDMARK_BOOST_TEXT:
		assert_int(text.length()).is_less_equal(26)


func test_the_claim_and_loss_texts_name_the_landmark_and_its_boost() -> void:
	assert_str(_landmark(Landmarks.BANDSTAND).claim_text()).is_equal("Claimed the Bandstand: music x2")
	assert_str(_landmark(Landmarks.GARDEN).loss_text()).is_equal("Lost the Garden boost: nature x2")
	assert_str(_landmark(Landmarks.BELL_TOWER).claim_text()).is_equal(
		"Claimed the Bell tower: gloom slowed x0.4 nearby"
	)


func test_the_held_panel_line_reads_name_colon_boost() -> void:
	var lms: Landmarks = auto_free(Landmarks.new())
	add_child(lms)
	lms.build()
	lms.items[Landmarks.BANDSTAND].update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	assert_array(lms.held_lines()).is_equal(["Bandstand: music x2"])


# --- In the level ---------------------------------------------------------------------------------------------------


func test_a_claim_and_a_loss_each_raise_a_notice_on_the_hud() -> void:
	# Clean HUD (#92): both go through the one slim banner (the intro's event), not a centre alert line.
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	var garden := td.landmarks.items[Landmarks.GARDEN]
	garden.update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	assert_str(td.intro.current_text()).is_equal("Claimed the Garden: nature x2")
	assert_that(td.intro.tint).is_equal(LandmarkConfig.LANDMARK_CLAIM_COLOUR)
	garden.update(0.1, false)
	assert_str(td.intro.current_text()).is_equal("Lost the Garden boost: nature x2")
	assert_that(td.intro.tint).is_equal(LandmarkConfig.LANDMARK_LOSS_COLOUR)
	assert_int(td.intro.current).is_equal(Intro.Prompt.EVENT)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_notices_and_the_panel_lines_fit_the_banner_and_the_panel() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	# The notice: one line in the banner at its full size (the banner's text shrinks to fit, but not below 11 px).
	var font := ThemeDB.fallback_font
	for lm: Landmark in td.landmarks.items:
		for text: String in [lm.claim_text(), lm.loss_text()]:
			assert_float(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x).is_less(
				HudConfig.CP6_BANNER_MAX_WIDTH - 62.0
			)
	# The panel: the widest held line fits its 340 px box, and the header plus three lines fit its 104 px height.
	var panel_font := td.hud.landmark_label.get_theme_font("font")
	var panel_size := td.hud.landmark_label.get_theme_font_size("font_size")
	for lm: Landmark in td.landmarks.items:
		var line := "%s: %s" % [lm.landmark_name(), lm.boost_text()]
		assert_float(panel_font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, panel_size).x).is_less(340.0)
	assert_float(float(panel_font.get_height(panel_size)) * 4.0).is_less_equal(104.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_landmark_pulses_when_it_is_claimed_and_when_it_is_lost() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	var garden := td.landmarks.items[Landmarks.GARDEN]
	assert_bool(garden.look is LandmarkLookPlaceholder).is_true()
	var look := garden.look as LandmarkLookPlaceholder
	assert_bool(look.pulse_running()).is_false()
	garden.update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	assert_bool(look.pulse_running()).is_true()
	await runner.simulate_frames(2)
	assert_bool(look.pulse_running()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The minimap and the looks --------------------------------------------------------------------------------------


func test_the_placeholder_minimap_marks_a_held_landmark_apart_from_one_not_held() -> void:
	var look := MinimapLookPlaceholder.new()
	assert_bool(look.landmark_state_colour(true).is_equal_approx(look.landmark_colour())).is_true()
	assert_bool(look.landmark_state_colour(false).is_equal_approx(look.landmark_colour())).is_false()
	(
		assert_bool(look.landmark_state_colour(false).is_equal_approx(HudConfig.TD_MINIMAP_LANDMARK_UNHELD_COLOUR))
		. is_true()
	)


func test_the_base_minimap_look_draws_held_and_unheld_landmarks_in_one_colour() -> void:
	var look := MinimapLook.new()
	assert_bool(look.landmark_state_colour(true).is_equal_approx(look.landmark_colour())).is_true()
	assert_bool(look.landmark_state_colour(false).is_equal_approx(look.landmark_colour())).is_true()
	assert_bool(look.landmark_state_colour(false).is_equal_approx(Color.WHITE)).is_true()


func test_a_landmark_look_that_is_not_built_yet_ignores_a_claim_and_a_sync() -> void:
	var look: LandmarkLookPlaceholder = auto_free(LandmarkLookPlaceholder.new())
	look.play_change(true)
	look.play_change(false)
	look.sync()
	assert_bool(look.pulse_running()).is_false()


func test_the_base_look_draws_no_clouds_and_the_styled_look_keeps_its_own_landmark_marks() -> void:
	assert_float(MinimapLook.new().cloud_colour().a).is_equal(0.0)
	assert_float(MinimapLookStyled.new().cloud_colour().a).is_equal(1.0)
	assert_float(MinimapLookPlaceholder.new().cloud_colour().a).is_equal(1.0)
