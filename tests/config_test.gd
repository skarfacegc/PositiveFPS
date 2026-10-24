extends GdUnitTestSuite

# Pure rules in Config: matchups, distance falloff, gloom levels, building unlocks, and the test-mode flag.


func test_multiplier_matches_soft_cycle() -> void:
	for a: int in range(3):
		assert_float(Config.multiplier(a, a)).is_equal_approx(2.0, 0.0001)
	# Music beats Art, Art beats Nature, Nature beats Music.
	assert_float(Config.multiplier(0, 1)).is_equal_approx(1.5, 0.0001)
	assert_float(Config.multiplier(1, 2)).is_equal_approx(1.5, 0.0001)
	assert_float(Config.multiplier(2, 0)).is_equal_approx(1.5, 0.0001)
	# The losing direction gives 1.0.
	assert_float(Config.multiplier(1, 0)).is_equal_approx(1.0, 0.0001)
	assert_float(Config.multiplier(2, 1)).is_equal_approx(1.0, 0.0001)
	assert_float(Config.multiplier(0, 2)).is_equal_approx(1.0, 0.0001)


func test_falloff_curve() -> void:
	assert_float(Config.falloff(0.0)).is_equal_approx(1.0, 0.0001)
	assert_float(Config.falloff(Config.FALLOFF_NEAR)).is_equal_approx(1.0, 0.0001)
	var mid := (Config.FALLOFF_NEAR + Config.FALLOFF_FAR) / 2.0
	assert_float(Config.falloff(mid)).is_equal_approx((1.0 + Config.FALLOFF_MIN) / 2.0, 0.0001)
	assert_float(Config.falloff(Config.FALLOFF_FAR)).is_equal_approx(Config.FALLOFF_MIN, 0.0001)
	assert_float(Config.falloff(100.0)).is_equal_approx(Config.FALLOFF_MIN, 0.0001)


func test_gloom_level_steps() -> void:
	assert_int(Config.gloom_level(0.0)).is_equal(0)
	assert_int(Config.gloom_level(0.33)).is_equal(0)
	assert_int(Config.gloom_level(0.34)).is_equal(1)
	assert_int(Config.gloom_level(0.66)).is_equal(1)
	assert_int(Config.gloom_level(0.67)).is_equal(2)
	assert_int(Config.gloom_level(1.0)).is_equal(2)


func test_automated_test_flag_is_on_and_mouse_never_captured() -> void:
	assert_bool(Config.is_automated_test()).is_true()
	# Whatever the scenes do, the real OS mouse must not be captured by a test run.
	assert_bool(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED).is_false()
