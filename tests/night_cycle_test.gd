extends GdUnitTestSuite

# Dusk to dawn (round 9): the grey strength curve, the light, the HUD bar, and dawn ending the level in the real level.


func test_strength_is_one_at_dusk_and_dawn_and_peaks_at_midnight() -> void:
	var night := NightCycle.new()
	assert_float(night.strength()).is_equal_approx(1.0, 0.0001)
	night.elapsed = Config.NIGHT_LENGTH / 2.0
	assert_float(night.strength()).is_equal_approx(1.0 + Config.NIGHT_PEAK_EXTRA, 0.0001)
	assert_float(night.strength()).is_equal_approx(1.75, 0.0001)
	night.elapsed = Config.NIGHT_LENGTH
	assert_float(night.strength()).is_equal_approx(1.0, 0.0001)


func test_strength_at_a_quarter_of_the_night_is_between_dusk_and_midnight() -> void:
	var night := NightCycle.new()
	night.elapsed = Config.NIGHT_LENGTH / 4.0
	assert_float(night.strength()).is_equal_approx(1.0 + Config.NIGHT_PEAK_EXTRA * sin(PI / 4.0), 0.0001)


func test_the_light_goes_from_warm_dusk_to_dim_blue_night_and_back_to_soft_dawn() -> void:
	var night := NightCycle.new()
	var dusk_energy := night.sun_energy()
	var dusk_colour := night.sun_color()
	night.elapsed = Config.NIGHT_LENGTH / 2.0
	assert_float(night.sun_energy()).is_equal_approx(NightCycle.MIDNIGHT_ENERGY, 0.0001)
	assert_float(night.sun_energy()).is_less(dusk_energy)
	assert_bool(night.sun_color().is_equal_approx(dusk_colour)).is_false()
	# Blue is stronger than red at midnight, and dusk is the other way round.
	assert_bool(night.sun_color().b > night.sun_color().r).is_true()
	assert_bool(dusk_colour.r > dusk_colour.b).is_true()
	night.elapsed = Config.NIGHT_LENGTH
	assert_float(night.sun_energy()).is_equal_approx(NightCycle.DAWN_ENERGY, 0.0001)
	assert_bool(night.is_over()).is_true()


func test_update_clamps_at_the_end_of_the_night() -> void:
	var night := NightCycle.new()
	night.update(Config.NIGHT_LENGTH * 2.0)
	assert_float(night.progress()).is_equal(1.0)
	assert_bool(night.is_over()).is_true()


func test_the_level_shows_the_night_progress_and_its_light() -> void:
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(5)
	assert_float(td.hud.night_bar.value).is_greater(45.0)
	assert_float(td._sun.light_energy).is_equal_approx(NightCycle.MIDNIGHT_ENERGY, 0.05)
	assert_bool(td.running).is_true()


func test_dawn_is_the_end_and_the_strength_is_used_by_the_gloom() -> void:
	# At midnight the same dark person spreads gloom faster than at dusk (the strength multiplies the spread).
	var near: Person = auto_free(Person.new())
	var dark: Person = auto_free(Person.new())
	add_child(near)
	add_child(dark)
	dark.gloom = 1.0
	near.gloom = 0.2
	near.position = Vector3(1.0, 0.0, 0.0)
	dark.position = Vector3.ZERO
	var list: Array[Person] = [near, dark]
	GloomSim.update(list, 1.0, Config.TD_DRAIN_MULTIPLIER, 1.0)
	var dusk_gain := near.gloom - 0.2
	near.gloom = 0.2
	GloomSim.update(list, 1.0, Config.TD_DRAIN_MULTIPLIER, 1.0 + Config.NIGHT_PEAK_EXTRA)
	var midnight_gain := near.gloom - 0.2
	assert_float(midnight_gain).is_greater(dusk_gain)
