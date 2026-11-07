extends GdUnitTestSuite

# Round 26: the burst's report reaches the recorder as a burst_clear event (BurstCue._on_burst_cleared).

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base
	Recorder.enabled = true


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


func test_the_burst_is_noted_by_the_recorder() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	assert_object(td.recorder).is_not_null()
	var lifted: Person = td.people[3]
	var cleared: Array[Dictionary] = [{"person": lifted, "from": lifted.position, "to": lifted.position}]
	td.burst_cue._on_burst_cleared({"cleared": cleared, "lifted": 1, "joy_hits": 0})
	td.recorder._flush()
	var found := false
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	while not file.eof_reached():
		if file.get_line().contains("burst_clear"):
			found = true
	file.close()
	assert_bool(found).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
