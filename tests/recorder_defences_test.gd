extends GdUnitTestSuite

# Walls and gates: Defences (#15). The recorder writes defence_plant, defence_refused, defence_returned and bell_ring.
# Same set-up as recorder_blocks_test.gd: session folders go to a throw-away user:// folder.

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


func test_plants_refusals_hand_backs_and_bells_are_recorded() -> void:
	Recorder.enabled = true
	var s: Dictionary = await TopDownTestUtil.settled_level(self, 30, 200)
	var td: TopDownMain = s["td"]
	for i: int in range(4):
		td.landmarks.unlock(i)
	assert_bool(td.defences.plant_now(0, Landmarks.BELL_TOWER)).is_true()
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_false()
	assert_bool(td.defences.plant_now(1, Landmarks.GARDEN)).is_true()
	var post := td.defences.post_at(0)
	td.defences.ring_bell(post, Vector3.ZERO, 0.6)
	assert_bool(td.defences.hand_back(1, "gate_closed")).is_true()
	var events := _events(td)
	var plants := _of_type(events, "defence_plant")
	assert_int(plants.size()).is_equal(2)
	assert_str(plants[0]["kind"] as String).is_equal("Bell tower")
	assert_int(plants[0]["gate"] as int).is_equal(0)
	assert_int(plants[0]["defences"] as int).is_equal(1)
	var refusals := _of_type(events, "defence_refused")
	assert_int(refusals.size()).is_equal(1)
	assert_str(refusals[0]["reason"] as String).is_equal("gate_defended")
	var returned := _of_type(events, "defence_returned")
	assert_int(returned.size()).is_equal(1)
	assert_str(returned[0]["reason"] as String).is_equal("gate_closed")
	assert_str(returned[0]["kind"] as String).is_equal("Garden")
	var bells := _of_type(events, "bell_ring")
	assert_int(bells.size()).is_equal(1)
	assert_float(bells[0]["bend"] as float).is_equal_approx(0.6, 0.001)
	await TopDownTestUtil.leave_loaded_scene(td)
