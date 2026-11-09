extends GdUnitTestSuite

# Round 26: the small edges of the gloom tide (see gloom_tide_test.gd for the schedule, the warning and the wave).


func before_test() -> void:
	Config.tides_override = 1


func after_test() -> void:
	Config.tides_override = -1


func _level() -> Array:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return [runner, td]


func _at(td: TopDownMain, seconds: float) -> void:
	td.night.elapsed = seconds
	td.gloom_tide.update(0.0)


func test_a_point_on_the_centre_faces_no_side() -> void:
	assert_bool(GloomTide.faces(Vector3.ZERO, Vector3.ZERO, 0.0)).is_false()


func test_the_pointer_hides_with_no_warning_and_when_the_window_is_too_small() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	td.gloom_tide.refresh_pointer()
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	var start: float = td.gloom_tide.tides[0]["start"]
	_at(td, start - NightConfig.TIDE_WARN_SECONDS + 0.1)
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	td.get_window().size = Vector2i(200, 150)
	await runner.simulate_frames(3)
	td.gloom_tide.refresh_pointer()
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_is_worked_out_again_every_refresh_interval() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.tides[0]["start"]
	_at(td, start - NightConfig.TIDE_WARN_SECONDS + 0.1)
	td.gloom_tide.pointer.hide_pointer()
	td.gloom_tide._show(NightConfig.TIDE_POINTER_REFRESH + 0.01)
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
