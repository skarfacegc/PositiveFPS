extends GdUnitTestSuite

# Round 18: more recorder tests. Same set-up as recorder_test.gd: session folders go to a throw-away
# user:// folder (Recorder.base_dir_override) and the statics are put back in after_test.

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base
	Recorder.enabled = false


func after_test() -> void:
	Recorder.enabled = false
	Recorder.base_dir_override = ""
	TopDownTestUtil.close_open_recorders(get_tree().root)
	_remove_tree(_base)
	# Removed by name through the parent's handle. The shared parent goes too once it is empty (remove fails,
	# harmlessly, while another test's folder is still in it).
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


# Loads a level with the recorder on or off, with the people parked away.
func _start(on: bool) -> Dictionary:
	Recorder.enabled = on
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# The parsed lines of the session's events file, after flushing what is buffered.
func _events(td: TopDownMain) -> Array[Dictionary]:
	td.recorder._flush()
	return _read_file(td)


func _read_file(td: TopDownMain) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	assert_object(file).is_not_null()
	while not file.eof_reached():
		var line := file.get_line()
		if line != "":
			out.append(JSON.parse_string(line))
	# Closed here: an open handle would keep the events file locked, and after_test must be able to delete it.
	file.close()
	return out


func _of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if e["type"] == type:
			out.append(e)
	return out


func test_a_shot_is_logged_and_saved_downsized_and_an_empty_one_is_ignored() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec._record_shot(null)
	rec._record_shot(Image.new())
	assert_int(rec.shots_taken).is_equal(0)
	var img := Image.create(Config.RECORD_SHOT_WIDTH * 2, 400, false, Image.FORMAT_RGB8)
	rec._record_shot(img)
	assert_int(rec.shots_taken).is_equal(1)
	var shots := _of_type(_events(td), "screenshot")
	assert_int(shots.size()).is_equal(1)
	assert_str(shots[0]["file"]).is_equal("shot_0001.png")
	var path := rec.session_dir.path_join("shot_0001.png")
	var waited := 0
	while not FileAccess.file_exists(path) and waited < 200:
		await get_tree().create_timer(0.05).timeout
		waited += 1
	assert_bool(FileAccess.file_exists(path)).is_true()


func test_saving_a_shot_shrinks_wide_pictures_and_keeps_narrow_ones() -> void:
	DirAccess.make_dir_recursive_absolute(_base)
	var wide := Image.create(Config.RECORD_SHOT_WIDTH * 2, 600, false, Image.FORMAT_RGB8)
	Recorder._save_shot(wide, _base.path_join("wide.png"))
	var got_wide := Image.load_from_file(_base.path_join("wide.png"))
	assert_int(got_wide.get_width()).is_equal(Config.RECORD_SHOT_WIDTH)
	assert_int(got_wide.get_height()).is_equal(300)
	var narrow := Image.create(100, 50, false, Image.FORMAT_RGB8)
	Recorder._save_shot(narrow, _base.path_join("narrow.png"))
	var got_narrow := Image.load_from_file(_base.path_join("narrow.png"))
	assert_int(got_narrow.get_width()).is_equal(100)
	assert_int(got_narrow.get_height()).is_equal(50)


func test_the_sample_counts_stages_rescued_shelter_guards_pressers_and_the_sealed_border() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	var rescued: Person = td.people[0]
	TopDownTestUtil.place(rescued, Vector3(0, 0, -8), 0, 0.0)
	rescued.is_rescued = true
	var shelterer: Person = td.people[1]
	TopDownTestUtil.place(shelterer, Vector3(30, 0, 30), 0, 0.2)
	shelterer.sheltered = true
	var guard: Person = td.people[2]
	TopDownTestUtil.place(guard, Vector3(-30, 0, 30), 0, 0.2)
	guard.mood_unlocked = true
	guard.mood = Person.Mood.GUARDED
	var presser: Person = td.people[3]
	TopDownTestUtil.place(presser, Vector3(1.0, 0, -8), 0, 0.9)
	presser.level = 2
	var glum: Person = td.people[4]
	TopDownTestUtil.place(glum, Vector3(-30, 0, -30), 0, 0.5)
	glum.level = 1
	# A square loop of four sides, the first one sealed by the map edge.
	td.border.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	td.border._sealed = [1.0, 0.0, 0.0, 0.0] as Array[float]
	rec._sample()
	var sample := _of_type(_events(td), "sample").back() as Dictionary
	var stages: Dictionary = sample["stages"]
	assert_float(stages["rescued"]).is_equal(1.0)
	assert_float(stages["dimmed"]).is_equal(1.0)
	assert_float(stages["gloomy"]).is_greater_equal(1.0)
	var total := 0.0
	for stage: String in stages:
		total += stages[stage]
	assert_float(total).is_equal(float(td.people.size()))
	assert_float(sample["sheltered"]).is_equal(1.0)
	assert_float(sample["guarded"]).is_equal(1.0)
	assert_float(sample["pressers"]).is_equal(1.0)
	assert_float(sample["border_sealed"]).is_equal_approx(20.0, 0.01)
	assert_float(sample["border_open"]).is_equal_approx(60.0, 0.01)


func test_gaps_still_open_when_the_session_ends_are_closed_as_cut_short() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	td.border._mids_cache = [Vector3(5, 0, 5)]
	rec._poll_gaps()
	rec.t += 4.0
	rec.end("quit")
	var closed := _of_type(_read_file(td), "gap_close")
	assert_int(closed.size()).is_equal(1)
	assert_bool(closed[0]["ended"]).is_true()
	assert_float(closed[0]["duration"]).is_equal_approx(4.0, 0.01)


func test_an_umbrella_pop_is_logged_when_the_shield_down_time_jumps() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	var p: Person = td.people[6]
	rec._poll_shields()
	p.shield_down_left = Config.SHELTER_REGROW
	rec._poll_shields()
	var pops := _of_type(_events(td), "umbrella_pop")
	assert_int(pops.size()).is_equal(1)
	assert_float(pops[0]["id"]).is_equal(6.0)
	# Counting down again is not a pop.
	p.shield_down_left = Config.SHELTER_REGROW * 0.5
	rec._poll_shields()
	assert_int(_of_type(_events(td), "umbrella_pop").size()).is_equal(1)


func test_relapses_and_avoided_grabs_are_logged_and_rescued_people_do_not_log_stage_changes() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td.people[2].relapsed.emit()
	td.grabs.grab_avoided.emit(td.people[3])
	td.people[4].is_rescued = true
	td.people[4].stage_changed.emit(0, 1)
	var events := _events(td)
	var relapses := _of_type(events, "relapse")
	assert_int(relapses.size()).is_equal(1)
	assert_float(relapses[0]["id"]).is_equal(2.0)
	var avoided := _of_type(events, "grab_avoided")
	assert_int(avoided.size()).is_equal(1)
	assert_float(avoided[0]["id"]).is_equal(3.0)
	for e: Dictionary in _of_type(events, "sink"):
		assert_float(e["id"]).is_not_equal(4.0)


func test_winning_and_dawn_are_logged_and_a_finished_session_ignores_more() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td.recorder.on_round_end("The landmark is ours!")
	var events := _read_file(td)
	assert_int(_of_type(events, "win").size()).is_equal(1)
	assert_str(events.back()["outcome"]).is_equal("win")
	var lines := FileAccess.get_file_as_string(td.recorder.events_path).count("\n")
	td.recorder.on_round_end("Dawn")
	td.recorder.emit_event("late")
	td.recorder._flush()
	assert_int(FileAccess.get_file_as_string(td.recorder.events_path).count("\n")).is_equal(lines)
	var s2: Dictionary = await _start(true)
	var td2: TopDownMain = s2["td"]
	td2.recorder.on_round_end("Dawn")
	assert_int(_of_type(_read_file(td2), "dawn").size()).is_equal(1)
	assert_str(_read_file(td2).back()["outcome"]).is_equal("dawn")


func test_the_restart_and_menu_keys_tell_the_recorder_why_and_ask_for_the_right_scene() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var asked: Array[String] = []
	td.scene_switch = func(path: String) -> void: asked.append(path)
	var restart := InputEventAction.new()
	restart.action = "restart"
	restart.pressed = true
	td._unhandled_input(restart)
	assert_str(td.recorder._exit_reason).is_equal("restart")
	var menu := InputEventAction.new()
	menu.action = "menu"
	menu.pressed = true
	td._unhandled_input(menu)
	assert_str(td.recorder._exit_reason).is_equal("menu")
	assert_array(asked).is_equal(["", "res://menu.tscn"])
