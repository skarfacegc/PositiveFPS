extends GdUnitTestSuite

# Round 25: gloom tides. Two a night (rising and midnight), each from a seeded side; a warning TIDE_WARN_SECONDS
# before; while it passes a wave of fog with figures in it rolls in and shoves the side it comes from (round 26;
# nobody drains by itself any more). The warning shows the minimap's fog edge, one edge pointer inside the safe
# rectangle and a notice; the recorder logs tide_warn / tide_start / tide_end. Times are set on the night's clock
# (night.elapsed) and update() is called directly, so nothing waits on frames. The recorder is pointed at a throw-away
# folder (as in recorder_test).

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base
	Recorder.enabled = false
	Config.tides_override = 1  # Tides are off under automated tests unless a test turns them on (see Config.tides_on).


func after_test() -> void:
	Config.tides_override = -1
	Recorder.enabled = false
	Recorder.base_dir_override = ""
	TopDownTestUtil.close_open_recorders(get_tree().root)
	_remove_tree(_base)
	var rec_dir := DirAccess.open("user://rec_tests")
	if rec_dir != null:
		rec_dir.remove(_base.get_file())
	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		user_dir.remove("rec_tests")


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
		dir.remove(sub)
	for f: String in dir.get_files():
		dir.remove(f)


# A level with everyone parked far away (so only what a test places can take part).
func _level() -> Array:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return [runner, td]


# Makes person `index` a rescued border member standing at `pos` (on the ground), with joy to spare and no grace.
func _member_at(td: TopDownMain, pos: Vector3, index: int) -> Person:
	var p: Person = td.people[index]
	p.is_rescued = true
	p.grace_left = 0.0
	p.mood = Person.Mood.NONE
	p.global_position = Vector3(pos.x, 0.0, pos.z)
	p.joy = p.joy_needed()
	return p


# Puts the night clock at `seconds` and runs the tides' update once (no frames, so nothing else moves).
func _at(td: TopDownMain, seconds: float) -> void:
	td.night.elapsed = seconds
	td.gloom_tide.update(0.0)


# --- The schedule ---------------------------------------------------------------------------------------------------


func test_two_tides_start_in_the_rising_phase_and_at_midnight() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var tides: Array[Dictionary] = td.gloom_tide.tides
	assert_int(tides.size()).is_equal(2)
	var rising: float = tides[0]["start"] / NightConfig.NIGHT_LENGTH
	var midnight: float = tides[1]["start"] / NightConfig.NIGHT_LENGTH
	assert_float(rising).is_greater_equal(NightConfig.TIDE_RISING_FROM)
	assert_float(rising).is_less_equal(NightConfig.TIDE_RISING_TO)
	assert_str(Recorder.phase_for(rising)).is_equal("rising")
	assert_float(midnight).is_greater_equal(NightConfig.TIDE_MIDNIGHT_FROM)
	assert_float(midnight).is_less_equal(NightConfig.TIDE_MIDNIGHT_TO)
	assert_str(Recorder.phase_for(midnight)).is_equal("midnight")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_same_seed_gives_the_same_tides() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var first: Array = td.gloom_tide.tides.duplicate(true)
	await TopDownTestUtil.leave_loaded_scene(td)
	parts = await _level()
	td = parts[1]
	var second: Array[Dictionary] = td.gloom_tide.tides
	for i: int in range(2):
		var start_a: float = first[i]["start"]
		var start_b: float = second[i]["start"]
		var angle_a: float = first[i]["angle"]
		var angle_b: float = second[i]["angle"]
		assert_float(start_b).is_equal_approx(start_a, 0.0001)
		assert_float(angle_b).is_equal_approx(angle_a, 0.0001)
		assert_str(second[i]["side"]).is_equal(first[i]["side"])
	await TopDownTestUtil.leave_loaded_scene(td)


func test_side_names_and_the_facing_rule_are_pure() -> void:
	assert_str(GloomTide.side_name(0.0)).is_equal("east")
	assert_str(GloomTide.side_name(PI)).is_equal("west")
	assert_str(GloomTide.side_name(-PI / 2.0)).is_equal("north")
	assert_str(GloomTide.side_name(PI / 2.0)).is_equal("south")
	assert_bool(GloomTide.faces(Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 0.0)).is_true()
	assert_bool(GloomTide.faces(Vector3(0.0, 0.0, 10.0), Vector3.ZERO, 0.0)).is_false()
	assert_bool(GloomTide.faces(Vector3(-10.0, 0.0, 0.0), Vector3.ZERO, PI)).is_true()
	# Just inside and just outside the half-width (TIDE_HALF_WIDTH is 45 degrees).
	var inside := Vector3(cos(NightConfig.TIDE_HALF_WIDTH - 0.05), 0.0, sin(NightConfig.TIDE_HALF_WIDTH - 0.05)) * 10.0
	var outside := Vector3(cos(NightConfig.TIDE_HALF_WIDTH + 0.05), 0.0, sin(NightConfig.TIDE_HALF_WIDTH + 0.05)) * 10.0
	assert_bool(GloomTide.faces(inside, Vector3.ZERO, 0.0)).is_true()
	assert_bool(GloomTide.faces(outside, Vector3.ZERO, 0.0)).is_false()


# --- The warning and the passing ------------------------------------------------------------------------------------


func test_the_warning_comes_about_15_seconds_before_the_tide() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.tides[0]["start"]
	_at(td, start - NightConfig.TIDE_WARN_SECONDS - 0.5)
	assert_int(td.gloom_tide.warning_index()).is_equal(-1)
	assert_bool(td.minimap.tide_fog == Vector2.INF).is_true()
	_at(td, start - NightConfig.TIDE_WARN_SECONDS + 0.1)
	assert_int(td.gloom_tide.warning_index()).is_equal(0)
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	assert_int(td.intro.current).is_equal(Intro.Prompt.TIDE)
	assert_bool(td.gloom_tide.fog.visible).is_false()
	_at(td, start - 0.1)
	assert_int(td.gloom_tide.passing_index()).is_equal(-1)
	_at(td, start + 0.1)
	assert_int(td.gloom_tide.passing_index()).is_equal(0)
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	assert_bool(td.gloom_tide.fog.visible).is_true()
	_at(td, start + NightConfig.TIDE_SECONDS + 0.1)
	assert_int(td.gloom_tide.passing_index()).is_equal(-1)
	assert_bool(td.gloom_tide.fog.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# A border that exists only as far as the tide cares: active, centred on the origin, with a body radius of 10 m.
func _pretend_border(td: TopDownMain) -> void:
	td.border.active = true
	td.border._trace()  # The start square's line, so the push has points for the wave to shove.
	td.border.polygon = td.border._base.duplicate()
	td.border.body_radius = 10.0


# The dentable point of the line whose direction from the centre is nearest `angle` (or, with `away`, farthest from it).
func _gate_point_toward(td: TopDownMain, angle: float, away: bool = false) -> int:
	var best := -1
	var best_d := INF
	for i: int in range(td.border.point_count()):
		if not td.border.point_dentable(i):
			continue
		var d := absf(angle_difference(td.border.point_angle(i), angle + (PI if away else 0.0)))
		if d < best_d:
			best_d = d
			best = i
	return best


func test_a_passing_tide_does_not_drain_anyone_by_itself() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.tides[0]["start"]
	var angle: float = td.gloom_tide.tides[0]["angle"]
	var dir := Vector2.from_angle(angle)
	var facing := _member_at(td, td.border.centre + Vector3(dir.x, 0.0, dir.y) * 10.0, 0)
	_at(td, start + 4.0)
	var before := facing.joy
	facing.drain_joy(10.0)
	assert_float(before - facing.joy).is_equal_approx(10.0, 0.0001)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_front_of_the_wave_arrives_and_holds_just_past_the_line() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	_pretend_border(td)
	var start: float = td.gloom_tide.tides[0]["start"]
	_at(td, start)
	var far: float = td.gloom_tide.front_distance(0)
	assert_float(far).is_equal_approx(NightConfig.TIDE_FOG_FAR - NightConfig.TIDE_FOG_DEPTH * 0.5, 0.01)
	_at(td, start + NightConfig.TIDE_SECONDS * NightConfig.TIDE_ARRIVE)
	assert_float(td.gloom_tide.front_distance(0)).is_equal_approx(10.0 - NightConfig.TIDE_SHOVE_DEPTH, 0.01)
	_at(td, start + NightConfig.TIDE_SECONDS * 0.8)
	assert_float(td.gloom_tide.front_distance(0)).is_equal_approx(10.0 - NightConfig.TIDE_SHOVE_DEPTH, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wave_shoves_only_the_side_it_comes_from_and_only_while_it_passes() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	_pretend_border(td)
	var tide: Dictionary = td.gloom_tide.tides[0]
	var start: float = tide["start"]
	var angle: float = tide["angle"]
	var facing_sample := _gate_point_toward(td, angle)
	var away_sample := _gate_point_toward(td, angle, true)
	_at(td, start - 60.0)
	assert_float(td.border.push.wave[facing_sample]).is_equal(0.0)
	_at(td, start + 0.5)  # The front is still far out: no shove yet.
	assert_float(td.gloom_tide.wave_force).is_equal(0.0)
	_at(td, start + NightConfig.TIDE_SECONDS * 0.6)
	assert_float(td.gloom_tide.wave_force).is_equal_approx(NightConfig.TIDE_PUSH, 0.001)
	assert_float(td.border.push.wave[facing_sample]).is_between(NightConfig.TIDE_PUSH * 0.8, NightConfig.TIDE_PUSH)
	assert_float(td.border.push.wave[away_sample]).is_equal(0.0)
	_at(td, start + NightConfig.TIDE_SECONDS + 1.0)
	assert_float(td.border.push.wave[facing_sample]).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wave_comes_with_dark_figures_in_the_fog() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	assert_int(td.gloom_tide.figures.size()).is_equal(NightConfig.TIDE_FIGURES)
	var start: float = td.gloom_tide.tides[0]["start"]
	_at(td, start + 3.0)
	var a := td.gloom_tide.figures[0].position
	_at(td, start + 3.4)
	assert_bool(td.gloom_tide.figures[0].position.is_equal_approx(a)).is_false()
	assert_bool(td.gloom_tide.figures[0].get_parent() == td.gloom_tide.fog).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_facing_count_is_the_members_on_that_side() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var tide: Dictionary = td.gloom_tide.tides[0]
	var angle: float = tide["angle"]
	var dir := Vector2.from_angle(angle)
	td.border.members.clear()
	td.border.members.append(_member_at(td, td.border.centre + Vector3(dir.x, 0.0, dir.y) * 8.0, 0))
	td.border.members.append(_member_at(td, td.border.centre + Vector3(dir.x, 0.0, dir.y) * 12.0, 1))
	td.border.members.append(_member_at(td, td.border.centre - Vector3(dir.x, 0.0, dir.y) * 8.0, 2))
	assert_int(td.gloom_tide.count_facing(angle)).is_equal(2)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The pointer, the minimap and the fog ---------------------------------------------------------------------------


func test_the_pointer_stays_inside_the_safe_rect() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start: float = td.gloom_tide.tides[0]["start"]
	_at(td, start - NightConfig.TIDE_WARN_SECONDS + 0.1)
	td.gloom_tide.refresh_pointer()
	var screen := td.get_viewport().get_visible_rect().size
	var safe: Rect2 = HudSafeArea.current(td, screen)
	assert_bool(safe.size.x > 0.0).is_true()
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	var tip: Vector2 = td.gloom_tide.pointer.tip
	# The tip sits on the edge of the shrunk rectangle (the ray leaves it there), and Rect2.has_point leaves out the far
	# edge, so the check allows a hair's breadth either side.
	var tips := safe.grow(-HudConfig.WOBBLE_ALERT_REACH).grow(0.01)
	assert_bool(safe.grow(0.01).has_point(tip)).is_true()
	assert_bool(tips.has_point(tip)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_fog_edge_shows_on_the_side_of_the_tide() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var tide: Dictionary = td.gloom_tide.tides[0]
	var start: float = tide["start"]
	var angle: float = tide["angle"]
	_at(td, start - NightConfig.TIDE_WARN_SECONDS - 1.0)
	assert_bool(td.minimap.tide_fog == Vector2.INF).is_true()
	_at(td, start - 1.0)
	assert_float(td.minimap.tide_fog.distance_to(Vector2.from_angle(angle))).is_less(0.0001)
	assert_str(td.intro.current_text()).is_equal(NightConfig.TIDE_TEXT % tide["side"])
	# Once this tide has ended the edge shows the next tide only if that one is already warned (the midnight tide can be).
	_at(td, start + NightConfig.TIDE_SECONDS + 1.0)
	var showing: int = td.gloom_tide.showing_index()
	assert_int(showing).is_not_equal(0)
	if showing < 0:
		assert_bool(td.minimap.tide_fog == Vector2.INF).is_true()
	else:
		var next_angle: float = td.gloom_tide.tides[showing]["angle"]
		assert_float(td.minimap.tide_fog.distance_to(Vector2.from_angle(next_angle))).is_less(0.0001)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fog_band_drifts_in_from_that_side() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var tide: Dictionary = td.gloom_tide.tides[0]
	var start: float = tide["start"]
	var angle: float = tide["angle"]
	_at(td, start + 0.5)
	var early := Vector2(td.gloom_tide.fog.position.x, td.gloom_tide.fog.position.z)
	_at(td, start + NightConfig.TIDE_SECONDS - 0.5)
	var late := Vector2(td.gloom_tide.fog.position.x, td.gloom_tide.fog.position.z)
	assert_float(early.normalized().distance_to(Vector2.from_angle(angle))).is_less(0.0001)
	assert_float(late.length()).is_less(early.length())
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The recorder ---------------------------------------------------------------------------------------------------


func test_the_tide_events_go_to_the_recorder() -> void:
	Recorder.enabled = true
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	assert_object(td.recorder).is_not_null()
	var tide: Dictionary = td.gloom_tide.tides[0]
	var start: float = tide["start"]
	_at(td, start - 1.0)
	_at(td, start + 1.0)
	_at(td, start + NightConfig.TIDE_SECONDS + 1.0)
	# The midnight tide may also warn during this walk through the rising one, so only the rising tide's events count.
	var events := _events(td)
	var angle_true: float = tide["angle"]
	var warns := _with_angle(events, "tide_warn", angle_true)
	var starts := _with_angle(events, "tide_start", angle_true)
	var ends := _with_angle(events, "tide_end", angle_true)
	assert_int(warns.size()).is_equal(1)
	assert_int(starts.size()).is_equal(1)
	assert_int(ends.size()).is_equal(1)
	assert_str(warns[0]["side"]).is_equal(tide["side"])
	assert_bool(starts[0].has("members")).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# The parsed lines of the session's events file, after flushing what is buffered.
func _events(td: TopDownMain) -> Array[Dictionary]:
	td.recorder._flush()
	var out: Array[Dictionary] = []
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	assert_object(file).is_not_null()
	while not file.eof_reached():
		var line := file.get_line()
		if line != "":
			out.append(JSON.parse_string(line))
	file.close()
	return out


func _of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if e["type"] == type:
			out.append(e)
	return out


# The events of `type` for the tide at `angle` (the recorder rounds angles to 0.01, so the match allows that much).
func _with_angle(events: Array[Dictionary], type: String, angle: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in _of_type(events, type):
		var logged: float = e["angle"]
		if absf(logged - angle) < 0.006:
			out.append(e)
	return out
