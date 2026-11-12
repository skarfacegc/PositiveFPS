extends GdUnitTestSuite

# Walls and gates: Surge warning (#14, #81). Visual only: a big fog from the first moment of the warning (tall enough to
# show over the blocks, wider than the street, already clearly visible), in both looks, and a pulse of the edge pointer
# and the banner when the warning starts and again at the "soon" mark. Times are set on the night's clock.


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


func _start(td: TopDownMain) -> float:
	return td.gloom_tide.surge["start"]


func _at(td: TopDownMain, seconds: float) -> void:
	td.night.elapsed = seconds
	td.gloom_tide.update(0.0)


func test_the_fog_is_taller_than_the_blocks_and_wider_than_the_street() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var box := td.gloom_tide.fog_volume.mesh as BoxMesh
	assert_float(box.size.y).is_equal(NightConfig.SURGE_FOG_HEIGHT)
	assert_float(box.size.y).is_greater(TownConfig.TOWN_BLOCK_HEIGHT * 1.5)
	assert_float(box.size.x).is_greater(TownConfig.TOWN_STREET_WIDTH * 2.0)
	# The volume stands on the ground, shares the band's material and goes with it.
	assert_float(td.gloom_tide.fog_volume.position.y - box.size.y * 0.5).is_less(0.0)
	assert_bool(td.gloom_tide.fog_volume.material_override == td.gloom_tide.fog.material_override).is_true()
	assert_bool(td.gloom_tide.fog_volume.get_parent() == td.gloom_tide.fog).is_true()
	var tops := StylePush.layout_puffs(26.0, NightConfig.TIDE_FOG_DEPTH, NightConfig.SURGE_FOG_HEIGHT)
	var taller := StylePush.layout_puffs(26.0, NightConfig.TIDE_FOG_DEPTH)
	var highest := 0.0
	var old_highest := 0.0
	for p: Dictionary in tops:
		var h: float = p["height"]
		highest = maxf(highest, h)
	for p: Dictionary in taller:
		var h: float = p["height"]
		old_highest = maxf(old_highest, h)
	assert_float(highest).is_greater(TownConfig.TOWN_BLOCK_HEIGHT)
	assert_float(highest).is_greater(old_highest)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fog_is_clearly_visible_from_the_start_of_the_warning() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.05)
	assert_float(td.gloom_tide.fog_density()).is_greater_equal(NightConfig.SURGE_FOG_START_DENSITY - 0.01)
	assert_bool(td.gloom_tide.fog.visible).is_true()
	var mat := td.gloom_tide.fog.material_override as StandardMaterial3D
	assert_float(mat.albedo_color.a).is_greater(0.1)
	# It still only rises, 0.3 to 0.5, through the warning.
	var early := td.gloom_tide.fog_density()
	_at(td, start - 1.0)
	assert_float(td.gloom_tide.fog_density()).is_greater(early)
	assert_float(td.gloom_tide.fog_density()).is_less_equal(0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_cloud_is_wide_tall_and_full_height_early() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	var tide := td.gloom_tide
	td.set_look(Looks.Mode.STYLED)
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.05)
	await runner.simulate_frames(2)
	assert_bool(tide.styled_fog.visible).is_true()
	assert_float(StylePush.current_length(tide.styled_fog)).is_equal_approx(NightConfig.SURGE_FOG_WIDTH, 0.3)
	assert_float(tide.styled_fog.scale.y).is_equal_approx(1.0, 0.001)
	assert_float(tide.styled_fog.get_meta("top") as float).is_equal(NightConfig.SURGE_FOG_HEIGHT)
	_at(td, _start(td) + NightConfig.SURGE_SECONDS - 0.5)
	assert_float(tide.styled_fog.scale.y).is_less(1.0)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_and_the_banner_pulse_at_the_warning_and_at_soon() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var tide := td.gloom_tide
	var start := _start(td)
	assert_int(tide.pulse_count).is_equal(0)
	assert_float(tide.pointer.pulse_amount()).is_equal(0.0)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	assert_int(tide.pulse_count).is_equal(1)
	assert_float(tide.pointer.pulse_left).is_equal(NightConfig.SURGE_PULSE_SECONDS)
	assert_float(td.intro.pulse_left).is_equal(NightConfig.SURGE_PULSE_SECONDS)
	# Both die away on their own clocks.
	tide.pointer._process(NightConfig.SURGE_PULSE_SECONDS + 1.0)
	td.intro.update(NightConfig.SURGE_PULSE_SECONDS + 1.0)
	assert_float(tide.pointer.pulse_left).is_equal(0.0)
	assert_float(td.intro.pulse_amount()).is_equal(0.0)
	_at(td, start - NightConfig.SURGE_SOON_SECONDS + 0.1)
	assert_int(tide.pulse_count).is_equal(2)
	assert_float(td.intro.pulse_left).is_equal(NightConfig.SURGE_PULSE_SECONDS)
	# Once per mark, not once per update.
	_at(td, start - NightConfig.SURGE_SOON_SECONDS + 0.5)
	assert_int(tide.pulse_count).is_equal(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_pulse_swells_the_pointer_and_the_banner() -> void:
	var peak := 0.0
	for i: int in range(1, 100):
		var left := NightConfig.SURGE_PULSE_SECONDS * float(i) / 100.0
		peak = maxf(peak, TidePointer.pulse_shape(left))
	assert_float(peak).is_greater(0.8)
	assert_float(TidePointer.pulse_shape(0.0)).is_equal(0.0)
	assert_float(TidePointer.pulse_shape(-1.0)).is_equal(0.0)
	var pointer: TidePointer = auto_free(TidePointer.new())
	pointer.show_at(Vector2(100, 100), Vector2.UP)
	pointer.pulse()
	pointer._process(NightConfig.SURGE_PULSE_SECONDS * 0.1)
	assert_float(pointer.pulse_left).is_less(NightConfig.SURGE_PULSE_SECONDS)
	pointer._process(0.0)
	pointer.pulse_left = 0.0
	pointer._process(0.1)
	pointer.hide_pointer()
	pointer.hide_pointer()
	# The banner grows while it pulses.
	var intro := Intro.new(null, false)
	var bar: PromptBar = auto_free(PromptBar.new())
	bar.intro = intro
	intro.notice(Intro.Prompt.TIDE, "words")
	bar.tick(Rect2(0, 0, 1280, 720))
	assert_float(bar.pulse).is_equal(0.0)
	var plain := bar._rect.size.x
	intro.pulse()
	intro.pulse_left = NightConfig.SURGE_PULSE_SECONDS * 5.0 / 6.0  # The top of the first beat.
	bar.tick(Rect2(0, 0, 1280, 720))
	assert_float(bar.pulse).is_greater(0.0)
	assert_float(bar._rect.size.x).is_greater(plain)
