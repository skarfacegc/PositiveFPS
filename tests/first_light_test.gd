extends GdUnitTestSuite

# Round 24: first light. Over the last FIRST_LIGHT_SECONDS of the night a front of dawn (a circle since checkpoint 6)
# moves in from beyond the map edge and lifts gloom behind it: pure rules (NightCycle, the front), the lift, the calm,
# the joy drain, the look, the minimap and the recorder events.

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/fl_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base
	Recorder.enabled = false


func after_test() -> void:
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


func _start_of_light() -> float:
	return Config.NIGHT_LENGTH - Config.FIRST_LIGHT_SECONDS


# A level with everyone parked away, at `elapsed` seconds into the night.
func _level(elapsed: float, record: bool = false) -> Dictionary:
	Recorder.enabled = record
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	for p: Person in td.people:
		p.gloom = 0.0
		p.level = 0
	td.night.elapsed = elapsed
	return {"runner": runner, "td": td}


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


# --- The night clock ---------------------------------------------------------------------------------------------


func test_first_light_progress_is_zero_until_the_last_45_seconds_then_rises_to_one_at_dawn() -> void:
	var night := NightCycle.new()
	night.elapsed = 10.0
	assert_float(night.first_light_progress()).is_equal(0.0)
	assert_bool(night.first_light_active()).is_false()
	night.elapsed = _start_of_light()
	assert_float(night.first_light_progress()).is_equal(0.0)
	assert_bool(night.first_light_active()).is_true()
	night.elapsed = _start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5
	assert_float(night.first_light_progress()).is_equal_approx(0.5, 0.001)
	night.elapsed = Config.NIGHT_LENGTH
	assert_float(night.first_light_progress()).is_equal(1.0)


# --- The front ---------------------------------------------------------------------------------------------------


func test_the_front_starts_covering_the_whole_play_area_and_reaches_the_centre_at_dawn() -> void:
	var s: Dictionary = await _level(_start_of_light())
	var td: TopDownMain = s["td"]
	var start := Config.FIRST_LIGHT_START_RADIUS
	assert_float(td.first_light.edge()).is_equal_approx(start, 0.01)
	# The plaza's corner is the furthest point of the play area, and the start radius reaches it.
	var corner := Config.TD_PLAZA_SIZE * 0.5 * sqrt(2.0)
	assert_float(start).is_greater_equal(corner)
	td.night.elapsed = _start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5
	assert_float(td.first_light.edge()).is_equal_approx(start * 0.5, 0.01)
	td.night.elapsed = Config.NIGHT_LENGTH
	assert_float(td.first_light.edge()).is_equal_approx(0.0, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_person_is_passed_once_the_front_is_at_or_inside_their_round_distance() -> void:
	var s: Dictionary = await _level(_start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5)
	var td: TopDownMain = s["td"]
	td.first_light.started = true
	var e := td.first_light.edge()
	assert_bool(td.first_light.has_passed(Vector3(e + 1.0, 0.0, 0.0))).is_true()
	assert_bool(td.first_light.has_passed(Vector3(0.0, 0.0, -(e + 1.0)))).is_true()
	assert_bool(td.first_light.has_passed(Vector3.ZERO)).is_false()
	# The round distance counts, whatever the direction: just inside is not passed and just outside is, on the axes and
	# on the diagonals alike (the old square front passed the diagonal point much sooner).
	for deg: float in [0.0, 30.0, 45.0, 90.0, 135.0, 200.0, 315.0]:
		var dir := Vector3(cos(deg_to_rad(deg)), 0.0, sin(deg_to_rad(deg)))
		assert_bool(td.first_light.has_passed(dir * (e - 0.5))).is_false()
		assert_bool(td.first_light.has_passed(dir * (e + 0.5))).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_front_reaches_the_centre_at_dawn_so_everyone_is_passed() -> void:
	var s: Dictionary = await _level(Config.NIGHT_LENGTH)
	var td: TopDownMain = s["td"]
	td.first_light.started = true
	assert_bool(td.first_light.has_passed(Vector3(0.0, 0.0, 0.0))).is_true()
	assert_bool(td.first_light.has_passed(Vector3(0.1, 0.0, -0.1))).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Nothing before the last 45 seconds ---------------------------------------------------------------------------


func test_nothing_happens_before_the_last_45_seconds() -> void:
	var s: Dictionary = await _level(_start_of_light() - 5.0)
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(48.0, 0.0, 0.0), p.affinity, 0.9)
	td.first_light.step(1.0)
	assert_bool(td.first_light.started).is_false()
	assert_float(p.gloom).is_equal(0.9)
	assert_bool(p.dawn_lit).is_false()
	assert_float(p.calm_left).is_equal(0.0)
	assert_float(td.minimap.first_light_edge).is_less(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Lifting gloom -----------------------------------------------------------------------------------------------


func test_people_behind_the_front_lose_gloom_and_people_ahead_do_not() -> void:
	var s: Dictionary = await _level(_start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5)
	var td: TopDownMain = s["td"]
	var behind: Person = td.people[0]
	var ahead: Person = td.people[1]
	TopDownTestUtil.place(behind, Vector3(40.0, 0.0, 10.0), behind.affinity, 0.9)
	TopDownTestUtil.place(ahead, Vector3(5.0, 0.0, 5.0), ahead.affinity, 0.9)
	td.first_light.step(2.0)
	assert_float(behind.gloom).is_equal_approx(0.9 - 2.0 * Config.FIRST_LIGHT_LIFT_RATE, 0.0001)
	assert_float(ahead.gloom).is_equal(0.9)
	assert_bool(behind.dawn_lit).is_true()
	assert_bool(ahead.dawn_lit).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_lifts_to_gloomy_and_then_to_wistful() -> void:
	var s: Dictionary = await _level(_start_of_light() + 10.0)
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(40.0, 0.0, 40.0), p.affinity, 0.69)
	assert_int(Config.gloom_level(p.gloom)).is_equal(2)
	for i: int in range(20):
		td.first_light.step(0.5)
	assert_int(Config.gloom_level(p.gloom)).is_equal(1)
	for i: int in range(60):
		td.first_light.step(0.5)
	assert_int(Config.gloom_level(p.gloom)).is_equal(0)
	assert_float(p.gloom).is_greater_equal(0.0)
	assert_int(td.first_light.people_lifted).is_equal(1)
	assert_int(td.first_light.stages_lifted).is_equal(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_person_behind_the_front_does_not_sink_but_one_ahead_can() -> void:
	var s: Dictionary = await _level(_start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5)
	var td: TopDownMain = s["td"]
	var behind: Person = td.people[0]
	var ahead: Person = td.people[1]
	TopDownTestUtil.place(behind, Vector3(45.0, 0.0, 0.0), behind.affinity, 0.1)
	TopDownTestUtil.place(ahead, Vector3(0.0, 0.0, 3.0), ahead.affinity, 0.1)
	td.first_light.step(0.1)
	assert_float(behind.calm_left).is_greater(0.0)
	assert_float(ahead.calm_left).is_equal(0.0)
	# GloomSim adds nothing to a calm person, so the behind one holds while the ahead one grows.
	GloomSim.update(td.people, 1.0, 1.0, 1.4, td.border)
	assert_float(behind.gloom).is_less_equal(0.1)
	assert_float(ahead.gloom).is_greater(0.1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Rescued people ----------------------------------------------------------------------------------------------


func test_rescued_people_behind_the_front_stop_draining_and_those_ahead_still_do() -> void:
	var s: Dictionary = await _level(_start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5)
	var td: TopDownMain = s["td"]
	var behind: Person = td.people[0]
	var ahead: Person = td.people[1]
	for p: Person in [behind, ahead]:
		p.is_rescued = true
		p.grace_left = 0.0
		p.joy = Config.JOY_MAX
	behind.global_position = Vector3(44.0, 0.0, 0.0)
	ahead.global_position = Vector3(2.0, 0.0, 0.0)
	td.first_light.step(0.1)
	behind.drain_joy(10.0)
	ahead.drain_joy(10.0)
	assert_float(behind.joy).is_equal(Config.JOY_MAX)
	assert_float(ahead.joy).is_less(Config.JOY_MAX)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_front_does_not_touch_rescued_gloom_or_unrescued_joy() -> void:
	var s: Dictionary = await _level(_start_of_light() + 20.0)
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	p.is_rescued = true
	p.gloom = 0.0
	p.global_position = Vector3(40.0, 0.0, 40.0)
	td.first_light.step(1.0)
	assert_float(p.gloom).is_equal(0.0)
	assert_int(td.first_light.people_lifted).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- It runs in the level ----------------------------------------------------------------------------------------


func test_in_the_level_a_dimmed_person_at_the_edge_is_lifted_over_real_frames() -> void:
	var s: Dictionary = await _level(_start_of_light() + 10.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(40.0, 0.0, 40.0), p.affinity, 0.9)
	await runner.simulate_frames(120)
	assert_bool(td.first_light.started).is_true()
	assert_float(p.gloom).is_less(0.9)
	assert_bool(p.dawn_lit).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The look ----------------------------------------------------------------------------------------------------


# Snag round: the start line is an Intro notice (the helper both looks use for short notices). It shows when first
# light starts, and it goes away NOTICE_SECONDS later (Intro.update counts it down).
func test_a_first_light_notice_shows_when_it_begins_and_goes_away() -> void:
	var s: Dictionary = await _level(_start_of_light() - 1.0)
	var td: TopDownMain = s["td"]
	assert_bool(td.intro.current == Intro.Prompt.FIRST_LIGHT).is_false()
	td.night.elapsed = _start_of_light()
	td.first_light.step(0.1)
	assert_bool(td.intro.current == Intro.Prompt.FIRST_LIGHT).is_true()
	assert_str(td.intro.current_text()).is_equal("First light: dawn is coming in from the edges")
	td.intro.update(Config.NOTICE_SECONDS - 0.5)
	assert_bool(td.intro.current == Intro.Prompt.FIRST_LIGHT).is_true()
	td.intro.update(1.0)
	assert_int(td.intro.current).is_equal(-1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_ground_ring_closes_inward_and_covers_everything_at_dawn() -> void:
	var s: Dictionary = await _level(_start_of_light() + 10.0)
	var td: TopDownMain = s["td"]
	td.first_light.step(0.1)
	assert_int(td.first_light.tint_visible_count()).is_equal(1)
	td.night.elapsed = Config.NIGHT_LENGTH
	td.first_light.step(0.1)
	# At dawn the front is at the centre: the whole ground is lit, a ring from radius 0 out to the start radius.
	assert_int(td.first_light.tint_visible_count()).is_equal(1)
	td.night.elapsed = _start_of_light() + 0.0
	td.first_light.step(0.1)
	# At the very start the front covers the whole play area, so there is no lit ground yet.
	assert_int(td.first_light.tint_visible_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The minimap -------------------------------------------------------------------------------------------------


func test_the_minimap_gets_the_front_and_tints_the_lit_ground() -> void:
	var s: Dictionary = await _level(_start_of_light() + Config.FIRST_LIGHT_SECONDS * 0.5)
	var td: TopDownMain = s["td"]
	td.first_light.step(0.1)
	assert_float(td.minimap.first_light_edge).is_equal_approx(td.first_light.edge(), 0.001)
	td.minimap.refresh_from(
		td.ground, td.border, td.people, td.player.global_position, Vector3.ZERO, td.view_half_extents()
	)
	var img: Image = td.minimap._image
	var res := Minimap.RESOLUTION
	# A pixel in the lit part and one in the unlit centre; then the same map redrawn without the front.
	var lit_at := Vector2i(int(res * 0.12), res / 2)
	var unlit_at := Vector2i(res / 2, res / 2 + 3)
	var lit := img.get_pixelv(lit_at)
	var unlit := img.get_pixelv(unlit_at)
	td.minimap.first_light_edge = -1.0
	td.minimap._render()
	img = td.minimap._image
	assert_bool(img.get_pixelv(lit_at).is_equal_approx(lit)).is_false()
	assert_bool(img.get_pixelv(unlit_at).is_equal_approx(unlit)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The recorder ------------------------------------------------------------------------------------------------


func test_the_recorder_gets_a_start_event_and_an_end_event_with_the_lifted_count() -> void:
	var s: Dictionary = await _level(_start_of_light() - 1.0, true)
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(40.0, 0.0, 40.0), p.affinity, 0.69)
	td.night.elapsed = _start_of_light()
	td.first_light.step(0.1)
	assert_int(_of_type(_events(td), "first_light_start").size()).is_equal(1)
	assert_int(_of_type(_events(td), "first_light_end").size()).is_equal(0)
	for i: int in range(80):
		td.night.elapsed += 0.5
		td.first_light.step(0.5)
	# The last frame of the night writes the end event once.
	td.night.elapsed = Config.NIGHT_LENGTH - 0.01
	td.first_light.step(0.1)
	td.first_light.step(0.1)
	var events := _events(td)
	assert_int(_of_type(events, "first_light_start").size()).is_equal(1)
	var ends := _of_type(events, "first_light_end")
	assert_int(ends.size()).is_equal(1)
	var end: Dictionary = ends[0]
	var people: int = end["people_lifted"]
	var stages: int = end["stages_lifted"]
	assert_int(people).is_equal(1)
	assert_int(stages).is_equal(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_finish_does_nothing_before_it_has_started() -> void:
	var s: Dictionary = await _level(10.0, true)
	var td: TopDownMain = s["td"]
	td.first_light.finish()
	assert_bool(td.first_light.finished).is_false()
	assert_int(_of_type(_events(td), "first_light_end").size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
