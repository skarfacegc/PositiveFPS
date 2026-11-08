extends GdUnitTestSuite

# Graphics checkpoint 7, part B: the living ground, the gloom atmosphere (mist, night sky, skyline) and no dithering on
# the ground. Headless uses a dummy renderer, so these check state and the shader sources; the checkpoint shots check
# the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	return {"td": td, "runner": runner}


func _leave(s: Dictionary) -> void:
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func _source(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_object(f).is_not_null()
	return f.get_as_text()


# --- No dithering ---------------------------------------------------------------------------------------------------


func test_the_ground_shader_has_no_dithering() -> void:
	var src := _source("res://shaders/style_ground.gdshader")
	assert_bool(src.contains("bayer4(")).is_false()
	assert_bool(src.contains("dither_k")).is_false()
	assert_bool(src.contains("joy_dither")).is_false()


func test_the_mist_shader_has_no_dithering() -> void:
	var src := _source("res://shaders/style_mist.gdshader")
	assert_bool(src.contains("bayer")).is_false()
	assert_bool(src.contains("dither_k")).is_false()


func test_the_ground_material_is_dither_free_and_carries_the_living_ground_settings() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var look := td.ground.look as GroundLookStyled
	var mat: ShaderMaterial = look._mat
	assert_object(mat.get_shader_parameter("dither_amt")).is_null()
	assert_float(mat.get_shader_parameter("gloom_amt")).is_equal(Config.CP7_GROUND_GLOOM)
	assert_float(mat.get_shader_parameter("life_amt")).is_equal(Config.CP7_GROUND_LIFE)
	# 0.3.1: the tufts, flowers and moss are drawn bigger and bolder so they read at play zoom.
	assert_float(mat.get_shader_parameter("life_size")).is_equal(Config.L31_GROUND_SIZE)
	assert_float(mat.get_shader_parameter("life_bold")).is_equal(Config.L31_GROUND_CONTRAST)
	assert_object(look.weights_texture()).is_not_null()
	await _leave(s)


# --- The mist ------------------------------------------------------------------------------------------------------


func test_the_styled_view_has_two_mist_layers_that_read_the_paint_weights() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var atm := td.pipeline._atmosphere
	assert_object(atm).is_not_null()
	assert_int(atm.mist_layer_count()).is_equal(2)
	var look := td.ground.look as GroundLookStyled
	for i: int in range(atm.mist_layer_count()):
		assert_object(atm.mist_material(i).get_shader_parameter("weights")).is_same(look.weights_texture())
	assert_float(atm.mist_material(0).get_shader_parameter("strength")).is_equal(Config.CP7_MIST_STRENGTH)
	await _leave(s)


func test_the_atmosphere_is_only_there_in_the_styled_look() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(2)
	assert_object(td.pipeline._atmosphere).is_null()
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(2)
	assert_object(td.pipeline._atmosphere).is_not_null()
	await _leave(s)


func test_an_unbuilt_atmosphere_does_nothing_on_sync() -> void:
	var atm := auto_free(StyleAtmosphere.new()) as StyleAtmosphere
	atm.sync(1.0)
	assert_int(atm.mist_layer_count()).is_equal(0)


# --- The sky -------------------------------------------------------------------------------------------------------


func test_the_sky_cools_toward_midnight_and_returns_by_first_light() -> void:
	var dusk := StyleAtmosphere.sky_for(0.0)
	var midnight := StyleAtmosphere.sky_for(0.5 * (1.0 - Config.FIRST_LIGHT_SECONDS / Config.NIGHT_LENGTH))
	var before_dawn := StyleAtmosphere.sky_for(1.0 - Config.FIRST_LIGHT_SECONDS / Config.NIGHT_LENGTH)
	assert_bool(dusk.is_equal_approx(ViewPipeline.STYLED_BACKGROUND)).is_true()
	assert_float(midnight.v).is_less(dusk.v)
	assert_bool(before_dawn.is_equal_approx(ViewPipeline.STYLED_BACKGROUND)).is_true()


func test_the_view_follows_the_night_clock_and_leaves_first_light_to_its_own_sky() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.night.elapsed = Config.NIGHT_LENGTH * 0.4
	await runner.simulate_frames(3)
	var want := StyleAtmosphere.sky_for(td.night.progress())
	assert_bool(td.environment().background_color.is_equal_approx(want)).is_true()
	td.night.elapsed = Config.NIGHT_LENGTH - Config.FIRST_LIGHT_SECONDS * 0.5
	assert_bool(td.night.first_light_active()).is_true()
	var marker := Color(0.9, 0.1, 0.2)
	td.environment().background_color = marker
	td.pipeline._atmosphere.sync(0.0)
	assert_bool(td.environment().background_color.is_equal_approx(marker)).is_true()
	await _leave(s)


# --- The skyline ---------------------------------------------------------------------------------------------------


func test_a_skyline_sector_lights_up_when_its_landmark_is_held_and_goes_grey_when_lost() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var atm := td.pipeline._atmosphere
	assert_float(atm.skyline_lit(1)).is_equal(0.0)
	assert_int(atm.skyline_roof_count(1)).is_equal(Config.CP7_SKYLINE_ROOFS)
	var lm: Landmark = td.landmarks.items[1]
	lm.hold = Config.BORDER_LANDMARK_HOLD
	atm.sync(0.5)
	assert_float(atm.skyline_lit(1)).is_between(0.1, 0.9)
	assert_float(atm.skyline_lit(0)).is_equal(0.0)
	atm.sync(10.0)
	assert_float(atm.skyline_lit(1)).is_equal(1.0)
	lm.hold = 0.0
	atm.sync(10.0)
	assert_float(atm.skyline_lit(1)).is_equal(0.0)
	await _leave(s)
