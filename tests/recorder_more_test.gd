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


func test_a_folder_that_cannot_be_made_stops_recording_without_breaking_the_level() -> void:
	# A plain file where the base folder should be: nothing can be created under it.
	DirAccess.make_dir_recursive_absolute(_base)
	var blocker := _base.path_join("blocker")
	var f := FileAccess.open(blocker, FileAccess.WRITE)
	f.store_string("x")
	f.close()
	Recorder.base_dir_override = blocker.path_join("sub")
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	assert_object(td.recorder).is_null()
	assert_bool(td.hud.rec_label == null or not td.hud.rec_label.visible).is_true()
	assert_bool(td.running).is_true()


func test_a_second_session_in_the_same_second_gets_its_own_folder() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var second := Recorder.new()
	td.add_child(second)
	assert_bool(second.attach(td)).is_true()
	assert_str(second.session_dir).is_not_equal(td.recorder.session_dir)
	assert_bool(FileAccess.file_exists(second.events_path)).is_true()
	assert_bool(FileAccess.file_exists(td.recorder.events_path)).is_true()
	assert_bool(second.is_open()).is_true()
	second.end("quit")
	assert_bool(second.is_open()).is_false()


func test_the_default_places_are_the_user_folder_and_in_the_editor_the_project_folder() -> void:
	Recorder.base_dir_override = ""
	var rec: Recorder = auto_free(Recorder.new())
	var dirs := rec._base_dirs()
	assert_str(dirs[dirs.size() - 1]).is_equal("user://recordings")
	assert_int(dirs.size()).is_equal(2 if OS.has_feature("editor") else 1)
	if OS.has_feature("editor"):
		assert_bool(dirs[0].ends_with("recordings")).is_true()
	Recorder.base_dir_override = "user://elsewhere"
	assert_array(rec._base_dirs()).is_equal(["user://elsewhere"])


func test_the_menu_choice_is_saved_and_loaded_and_keeps_other_settings() -> void:
	DirAccess.make_dir_recursive_absolute(_base)
	var path := _base.path_join("settings.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("other", "keep", 7)
	cfg.save(path)
	Recorder.enabled = true
	Recorder.save_setting_to(path)
	Recorder.enabled = false
	Recorder.load_setting_from(path)
	assert_bool(Recorder.enabled).is_true()
	var back := ConfigFile.new()
	back.load(path)
	assert_int(back.get_value("other", "keep")).is_equal(7)
	Recorder.enabled = false
	Recorder.save_setting_to(path)
	Recorder.enabled = true
	Recorder.load_setting_from(path)
	assert_bool(Recorder.enabled).is_false()
	# A missing file changes nothing.
	Recorder.enabled = true
	Recorder.load_setting_from(_base.path_join("missing.cfg"))
	assert_bool(Recorder.enabled).is_true()


func test_the_automated_test_guard_keeps_the_real_settings_untouched() -> void:
	Recorder.enabled = true
	Recorder.load_setting()
	assert_bool(Recorder.enabled).is_true()
	Recorder.save_setting()
	assert_bool(Recorder.requested()).is_true()


func test_the_record_argument_or_the_menu_turns_it_on() -> void:
	Recorder.enabled = false
	assert_bool(Recorder.requested()).is_equal("--record" in OS.get_cmdline_user_args())
	Recorder.enabled = true
	assert_bool(Recorder.requested()).is_true()


func test_time_counts_only_while_the_level_runs_and_the_session_is_open() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	var t0 := rec.t
	rec._process(0.5)
	assert_float(rec.t).is_equal_approx(t0 + 0.5, 0.0001)
	td.running = false
	rec._process(0.5)
	assert_float(rec.t).is_equal_approx(t0 + 0.5, 0.0001)
	td.running = true
	rec.end("quit")
	rec._process(0.5)
	assert_float(rec.t).is_equal_approx(t0 + 0.5, 0.0001)


func test_the_buffer_is_written_out_on_the_flush_interval() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec._flush_timer = 0.0
	rec.emit_event("custom", {"x": 1})
	rec._process(Config.RECORD_FLUSH_SECONDS * 0.5)
	assert_bool(FileAccess.get_file_as_string(rec.events_path).contains("custom")).is_false()
	rec._process(Config.RECORD_FLUSH_SECONDS * 0.6)
	assert_bool(FileAccess.get_file_as_string(rec.events_path).contains("custom")).is_true()


func test_a_sample_is_written_on_each_sample_interval() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec._sample_timer = 0.0
	var before := _of_type(_events(td), "sample").size()
	rec._process(Config.RECORD_SAMPLE_SECONDS * 0.5)
	assert_int(_of_type(_events(td), "sample").size()).is_equal(before)
	rec._process(Config.RECORD_SAMPLE_SECONDS * 0.6)
	assert_int(_of_type(_events(td), "sample").size()).is_equal(before + 1)


func test_the_screenshot_timer_asks_for_a_shot_which_is_skipped_headless() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec._shot_timer = 0.0
	rec._process(Config.RECORD_SHOT_SECONDS + 0.1)
	assert_float(rec._shot_timer).is_equal(0.0)
	if DisplayServer.get_name() == "headless":
		assert_int(rec.shots_taken).is_equal(0)
