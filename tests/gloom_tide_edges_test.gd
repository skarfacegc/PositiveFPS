extends GdUnitTestSuite

# Pressure (#14): the small edges of the surge (see gloom_tide_test.gd for the schedule, the warning and the push).


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


func test_the_surge_does_nothing_while_tides_are_off() -> void:
	Config.tides_override = 0
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.surge["start"]
	_at(td, start + 5.0)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.IDLE)
	assert_float(td.night.chill).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_hides_with_no_warning_and_when_the_window_is_too_small() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	td.gloom_tide.refresh_pointer()
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	var start: float = td.gloom_tide.surge["start"]
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	td.get_window().size = Vector2i(200, 150)
	await runner.simulate_frames(3)
	td.gloom_tide.refresh_pointer()
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_is_worked_out_again_every_refresh_interval() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.surge["start"]
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	td.gloom_tide.pointer.hide_pointer()
	td.gloom_tide._show(NightConfig.TIDE_POINTER_REFRESH + 0.01)
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_surge_reads_as_nothing_before_its_warning_and_with_no_schedule() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var tide := td.gloom_tide
	assert_dict(tide.pushed_gates()).is_empty()  # Scheduled, not warned: no street, no gate yet.
	assert_float(tide.front_distance()).is_equal(NightConfig.TIDE_FOG_DEPTH)
	assert_float(tide.fog_density()).is_equal(0.0)
	var saved := tide.surge.duplicate(true)
	tide.surge = {}
	assert_dict(tide.pushed_gates()).is_empty()
	assert_float(tide.progress()).is_equal(0.0)
	assert_int(tide.phase()).is_equal(GloomTide.Phase.IDLE)
	assert_float(tide.front_distance()).is_equal(NightConfig.TIDE_FOG_DEPTH)
	tide.surge = saved
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_surge_stops_when_the_level_is_not_running() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.surge["start"]
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	td.running = false
	td.gloom_tide.update(0.0)
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	assert_bool(td.minimap.surge_from == Vector2.INF).is_true()
	assert_bool(td.gloom_tide.fog.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)
