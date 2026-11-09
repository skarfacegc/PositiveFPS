extends GdUnitTestSuite

# Round 18: the gameplay recorder. Session folders go to a throw-away user:// folder (Recorder.base_dir_override), and
# the statics are always put back in after_test. Gaps are driven through the recorder poll with a hand-set gap list;
# the rest (sink, rescue, grab, round end) go through the real level.

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


func test_off_by_default_writes_nothing() -> void:
	var s: Dictionary = await _start(false)
	var td: TopDownMain = s["td"]
	await (s["runner"] as GdUnitSceneRunner).simulate_frames(120)
	assert_object(td.recorder).is_null()
	assert_bool(DirAccess.dir_exists_absolute(_base)).is_false()
	assert_bool(td.hud.rec_label == null or not td.hud.rec_label.visible).is_true()


func test_on_writes_start_samples_and_end_with_the_required_fields() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	await (s["runner"] as GdUnitSceneRunner).simulate_frames(150)
	td.recorder.end("quit")
	var events := _read_file(td)
	assert_str(events[0]["type"]).is_equal("session_start")
	for key: String in ["t", "night_phase", "night", "seed", "look", "targeting_mode", "zoom"]:
		assert_bool(events[0].has(key)).is_true()
	var samples := _of_type(events, "sample")
	assert_int(samples.size()).is_greater_equal(2)
	for key: String in [
		"t",
		"night_phase",
		"border_open",
		"border_sealed",
		"members",
		"gaps",
		"gap_ids",
		"stages",
		"spirit",
		"player_pos",
		"target",
		"target_stage",
		"joy_landed",
		"pressers",
		"sheltered",
		"guarded",
		"zoom",
	]:
		assert_bool(samples[0].has(key)).is_true()
	for stage: String in ["wistful", "gloomy", "dimmed", "rescued"]:
		assert_bool((samples[0]["stages"] as Dictionary).has(stage)).is_true()
	var last := events[events.size() - 1]
	assert_str(last["type"]).is_equal("session_end")
	assert_str(last["outcome"]).is_equal("quit")
	assert_bool(td.hud.rec_label.visible).is_false()


func test_the_rec_mark_shows_while_recording() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	assert_bool(td.hud.rec_label.visible).is_true()


func test_a_gap_opening_and_closing_is_logged_with_its_duration() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	td.border._mids_cache = [Vector3(5, 0, 5)]
	rec._poll_gaps()
	# Moved a little: still the same gap.
	rec.t += 2.0
	td.border._mids_cache = [Vector3(5.5, 0, 5)]
	rec._poll_gaps()
	rec.t += 1.5
	td.border._mids_cache = []
	rec._poll_gaps()
	var events := _events(td)
	var opened := _of_type(events, "break_open")
	var closed := _of_type(events, "break_close")
	assert_int(opened.size()).is_equal(1)
	assert_int(closed.size()).is_equal(1)
	assert_float(closed[0]["gap"]).is_equal(opened[0]["gap"])
	assert_float(closed[0]["duration"]).is_equal_approx(3.5, 0.01)


func test_a_sink_to_dimmed_and_a_lift_are_logged() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[3]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 0, 0.2)
	await runner.simulate_frames(5)
	TopDownTestUtil.open_dim_gate(td)
	p.gloom = 0.45
	await runner.simulate_frames(3)
	p.gloom = 0.9
	await runner.simulate_frames(3)
	p.gloom = 0.45
	await runner.simulate_frames(3)
	var events := _events(td)
	var sinks: Array[Dictionary] = []
	for e: Dictionary in _of_type(events, "sink"):
		var eid: float = e["id"]
		if eid == 3.0:
			sinks.append(e)
	assert_int(sinks.size()).is_greater_equal(2)
	assert_str(sinks[0]["to"]).is_equal("gloomy")
	assert_str(sinks[1]["to"]).is_equal("dimmed")
	assert_int(_of_type(events, "lift").size()).is_greater_equal(1)


func test_a_rescue_is_logged() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[1]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), p.affinity, 0.2)
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(3)
	var rescues := _of_type(_events(td), "rescue")
	assert_int(rescues.size()).is_equal(1)
	assert_float(rescues[0]["id"]).is_equal(1.0)
	assert_float(rescues[0]["total"]).is_equal(1.0)


func test_grab_burst_and_player_dim_are_logged() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td.grabs.grab_landed.emit(td.people[2])
	td.player.burst_fired.emit(Vector3(1, 0, 2))
	td.player.dim_changed.emit(true)
	var events := _events(td)
	assert_int(_of_type(events, "grab").size()).is_equal(1)
	assert_int(_of_type(events, "burst").size()).is_equal(1)
	assert_bool(_of_type(events, "player_dim")[0]["dim"]).is_true()


func test_a_blocked_guarded_shot_is_a_guarded_glance() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td.people[4].joy_blocked.emit(Person.Block.GUARDED)
	td.people[4].joy_blocked.emit(Person.Block.SHELTERED)
	var events := _events(td)
	assert_int(_of_type(events, "guarded_glance").size()).is_equal(1)
	assert_int(_of_type(events, "shelter_block").size()).is_equal(1)


func test_target_changes_are_logged_once_each() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.target = td.people[5]
	await runner.simulate_frames(3)
	td.player.target = null
	await runner.simulate_frames(3)
	var changes := _of_type(_events(td), "target_change")
	assert_int(changes.size()).is_greater_equal(2)
	var ids: Array[int] = []
	for c: Dictionary in changes:
		var tid: int = c["target"]
		ids.append(tid)
	assert_bool(ids.has(5)).is_true()
	assert_int(ids[ids.size() - 1]).is_equal(-1)


func test_the_end_of_the_round_logs_the_outcome_and_ends_the_session() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td._end_round("The border fell")
	var events := _read_file(td)
	assert_int(_of_type(events, "loss").size()).is_equal(1)
	var last := events[events.size() - 1]
	assert_str(last["type"]).is_equal("session_end")
	assert_str(last["outcome"]).is_equal("loss")


func test_quitting_flushes_what_was_buffered() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td.recorder.emit_event("custom", {"x": 1})
	# Not flushed yet: only the start line (flushed at attach) is on disk.
	var before := FileAccess.get_file_as_string(td.recorder.events_path)
	assert_bool(before.contains("custom")).is_false()
	td.recorder._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var after := FileAccess.get_file_as_string(td.recorder.events_path)
	assert_bool(after.contains("custom")).is_true()
	assert_bool(after.contains("session_end")).is_true()
	assert_str(td.recorder.ended_reason).is_equal("quit")


func test_leaving_the_level_writes_session_end_once_with_the_reason() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td._note_exit("restart")
	td.recorder.end(td.recorder._exit_reason)
	td.recorder.end("quit")
	var text := FileAccess.get_file_as_string(td.recorder.events_path)
	assert_int(text.count("session_end")).is_equal(1)
	assert_bool(text.contains('"reason":"restart"')).is_true()


func test_screenshots_are_skipped_headless() -> void:
	if DisplayServer.get_name() != "headless":
		return
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	td.recorder._screenshot()
	assert_int(td.recorder.shots_taken).is_equal(0)
	var files := DirAccess.get_files_at(td.recorder.session_dir)
	assert_array(files).is_equal(PackedStringArray(["events.jsonl"]))


func test_phase_names_follow_the_night() -> void:
	assert_str(Recorder.phase_for(0.0)).is_equal("calm")
	assert_str(Recorder.phase_for(0.3)).is_equal("rising")
	assert_str(Recorder.phase_for(0.6)).is_equal("midnight")
	assert_str(Recorder.phase_for(0.9)).is_equal("easing")


func test_perf_recorder_sample_is_cheap() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var start := Time.get_ticks_usec()
	for i: int in range(100):
		td.recorder._sample()
		td.recorder._poll_gaps()
		td.recorder._poll_shields()
	var per_call_ms := float(Time.get_ticks_usec() - start) / 100.0 / 1000.0
	# A sample happens once a second and the polls ten times a second, so even 2 ms for all three is far under a frame.
	# (Timed only in the serial perf pass, POSITIVEFPS_PERF_ENFORCE=1; elsewhere the lines run but are not timed.)
	if OS.get_environment("POSITIVEFPS_PERF_ENFORCE") == "1":
		assert_float(per_call_ms).is_less(2.0)
