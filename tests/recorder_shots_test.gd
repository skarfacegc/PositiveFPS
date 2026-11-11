extends GdUnitTestSuite

# The recorder's frame grabs when a window exists (#73). The suites run headless, so a recorder whose _headless() says
# "no" stands in for a real window; the grab then returns whatever the (dummy) viewport holds, and the recorder must
# cope with an empty picture.

const SOURCE := "extends Recorder\nfunc _headless() -> bool:\n\treturn false\n"

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base


func after_test() -> void:
	Recorder.base_dir_override = ""
	_remove_tree(_base)
	var rec_dir := DirAccess.open("user://rec_tests")
	if rec_dir != null:
		rec_dir.remove(_base.get_file())
		DirAccess.remove_absolute("user://rec_tests")


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
		dir.remove(sub)
	for f: String in dir.get_files():
		dir.remove(f)


func _windowed_recorder() -> Recorder:
	var script := GDScript.new()
	script.source_code = SOURCE
	script.reload()
	var rec: Recorder = auto_free(script.new())
	add_child(rec)
	return rec


func test_a_windowed_recorder_grabs_the_frame_for_timer_and_event_shots() -> void:
	var rec := _windowed_recorder()
	assert_bool(rec._open_session()).is_true()
	rec._screenshot()
	var shots := rec.shots_taken
	var saved := rec._event_shot("take")
	# Whether the dummy viewport yields a picture or not, both calls return without error and agree with the count.
	assert_bool(saved).is_equal(rec.shots_taken > shots)
	rec._file.close()
	rec._file = null  # Nothing to wrap up: there is no level behind this recorder.
