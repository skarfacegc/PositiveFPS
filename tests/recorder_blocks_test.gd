# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Walls and gates: Recorder catch-up (#59, #60, #61). The take, refusal, pip, cell-ready, auto-join, gate break and hold
# events, the sample's new fields, the mark key with its "Marked" flash, and the event screenshots with their throttle.
# Same set-up as recorder_test.gd: session folders go to a throw-away user:// folder (Recorder.base_dir_override).

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


# Loads a level with the recorder on, with the people parked away.
func _start() -> Dictionary:
	Recorder.enabled = true
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# Rescues `p` directly at `spot` (a joy hit that is always enough).
func _rescue(p: Person, spot: Vector3) -> void:
	TopDownTestUtil.place(p, spot, p.affinity, 0.0)
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# Rescues the first `count` people on a ring of radius `r` around `c`.
func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		_rescue(td.people[i], c + Vector3(cos(a) * r, 0.0, sin(a) * r))


func _neighbour() -> Vector2i:
	return TownGrid.neighbours(TownGrid.start_cell())[0]


func _point_at(runner: GdUnitSceneRunner, td: TopDownMain, c: Vector2i) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, TownGrid.cell_centre(c)))
	await runner.simulate_frames(3)


# The session's events so far (flushed), with the file closed again.
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
	file.close()
	return out


func _of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if e["type"] == type:
			out.append(e)
	return out


# A small picture to stand in for the viewport's frame.
func _picture() -> Image:
	return Image.create(8, 8, false, Image.FORMAT_RGB8)


# Waits (briefly) for a shot the worker thread is saving, so the folder can be removed afterwards.
func _await_file(path: String) -> void:
	var waited := 0
	while not FileAccess.file_exists(path) and waited < 200:
		OS.delay_msec(20)
		waited += 1


func test_a_take_by_e_is_logged_with_its_spirit_gates_and_people() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 30)
	await runner.simulate_frames(120)
	var c := _neighbour()
	td.player.spirit = 80.0
	await _point_at(runner, td, c)
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(3)
	assert_bool(td.border.zone.has(c)).is_true()
	var takes := _of_type(_events(td), "take")
	assert_int(takes.size()).is_equal(1)
	var take: Dictionary = takes[0]
	assert_array(take["cell"]).is_equal([float(c.x), float(c.y)])
	assert_bool(take["free"]).is_false()  # Its pips were not full: a paid take.
	assert_float(take["spirit_paid"]).is_equal_approx(BorderConfig.TAKE_SPIRIT_COST, 0.01)
	assert_float(take["spirit"]).is_equal_approx(80.0 - BorderConfig.TAKE_SPIRIT_COST, 0.1)
	assert_bool(take["gates_after"] > take["gates_before"]).is_true()
	assert_float(take["people_free"]).is_equal(30.0)
	assert_float(take["people_needed"]).is_greater(0.0)
	assert_int(_of_type(_events(td), "take_refused").size()).is_equal(0)


func test_a_take_refused_for_spirit_is_logged_with_its_reason() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 20)
	await runner.simulate_frames(120)
	td.player.spirit = BorderConfig.TAKE_SPIRIT_COST - 1.0
	td.take_block.take_now(_neighbour())
	var refused := _of_type(_events(td), "take_refused")
	assert_int(refused.size()).is_equal(1)
	assert_str(refused[0]["reason"]).is_equal("spirit_short")
	assert_float(refused[0]["spirit"]).is_equal_approx(BorderConfig.TAKE_SPIRIT_COST - 1.0, 0.1)


func test_a_take_with_too_few_people_is_not_refused_and_logs_the_shortfall() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	assert_bool(td.take_block.take_now(_neighbour())).is_true()
	var events := _events(td)
	assert_int(_of_type(events, "take_refused").size()).is_equal(0)
	var takes := _of_type(events, "take")
	assert_int(takes.size()).is_equal(1)
	assert_float(takes[0]["people_free"]).is_equal(0.0)
	assert_float(takes[0]["people_needed"]).is_greater(0.0)


func test_a_free_take_of_a_ready_cell_is_logged_free_with_no_spirit_paid() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	td.player.spirit = 3.0
	td.border.pips.counts[c] = BorderConfig.TAKE_RESCUES
	assert_bool(td.take_block.take_now(c)).is_true()
	var takes := _of_type(_events(td), "take")
	assert_bool(takes[0]["free"]).is_true()
	assert_float(takes[0]["spirit_paid"]).is_equal(0.0)
	assert_float(takes[0]["spirit"]).is_equal_approx(3.0, 0.1)


func test_a_cell_already_held_is_refused_as_already_held_not_not_next() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	assert_bool(td.take_block.take_now(TownGrid.start_cell())).is_false()
	var refused := _of_type(_events(td), "take_refused")
	assert_int(refused.size()).is_equal(1)
	assert_str(refused[0]["reason"]).is_equal("already_held")


func test_a_cell_not_beside_the_zone_is_refused_as_not_next() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	var far := Vector2i(-99, -99)
	assert_bool(td.take_block.take_now(far)).is_false()
	var refused := _of_type(_events(td), "take_refused")
	assert_int(refused.size()).is_equal(1)
	assert_str(refused[0]["reason"]).is_equal("not_next")


func test_right_click_while_holding_e_is_logged_as_cancelled() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 20)
	await runner.simulate_frames(120)
	td.player.spirit = 80.0
	await _point_at(runner, td, _neighbour())
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(2)
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(3)
	var refused := _of_type(_events(td), "take_refused")
	assert_int(refused.size()).is_equal(1)
	assert_str(refused[0]["reason"]).is_equal("cancelled")
	assert_int(_of_type(_events(td), "take").size()).is_equal(0)


func test_rescues_log_pips_and_a_ready_cell_and_nothing_joins_by_itself() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	var spot := TownGrid.cell_centre(c)
	for i: int in range(BorderConfig.TAKE_RESCUES):
		_rescue(td.people[i], spot)
		await runner.simulate_frames(2)
	assert_bool(td.border.zone.has(c)).is_false()  # Ready, waiting for E.
	var events := _events(td)
	var pips := _of_type(events, "pip")
	assert_int(pips.size()).is_equal(BorderConfig.TAKE_RESCUES)
	assert_float(pips[0]["pips"]).is_equal(1.0)
	assert_array(pips[0]["cell"]).is_equal([float(c.x), float(c.y)])
	assert_int(_of_type(events, "cell_ready").size()).is_equal(1)
	assert_int(_of_type(events, "auto_join").size()).is_equal(0)  # Gone with auto-join.
	assert_int(_of_type(events, "take").size()).is_equal(0)


func test_the_sample_counts_pips_ready_cells_and_empty_gate_slots() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	var c := _neighbour()
	td.border.pips.counts[c] = BorderConfig.TAKE_RESCUES  # ready: full pips, not joined
	rec._sample()
	var sample := _of_type(_events(td), "sample").back() as Dictionary
	assert_float(sample["pips_total"]).is_equal(float(BorderConfig.TAKE_RESCUES))
	assert_float(sample["ready_cells"]).is_equal(1.0)
	assert_float(sample["members_short"]).is_equal(0.0)  # no border yet: no slots to be short of
	td.border.pips.counts.clear()
	rec._sample()
	sample = _of_type(_events(td), "sample").back() as Dictionary
	assert_float(sample["pips_total"]).is_equal(0.0)
	assert_float(sample["ready_cells"]).is_equal(0.0)


func test_a_push_that_breaks_a_gate_is_logged_as_a_break_with_its_seconds() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	_rescue_ring(td, Vector3.ZERO, 3.0, 30)
	await runner.simulate_frames(60)
	var i := _gate_point(td)
	assert_int(i).is_greater_equal(0)
	var gid: int = td.border.zone.gates[td.border.point_gate(i)].get("id", -1)
	td.border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH + 0.1
	rec._poll_pushes()  # The push starts now...
	rec.t += 2.0  # ...and the line snaps two seconds later.
	var p: Vector2 = td.border.polygon[i]
	td.border.line_broke.emit(Vector3(p.x, 0.0, p.y))
	var breaks := _of_type(_events(td), "gate_break")
	assert_int(breaks.size()).is_equal(1)
	assert_float(breaks[0]["gate"]).is_equal(float(gid))
	assert_float(breaks[0]["seconds"]).is_equal_approx(2.0, 0.01)
	assert_float(breaks[0]["pushers"]).is_equal(float(td.border.push.pushers))
	# The push ends, but the gate broke: no hold is logged for it.
	td.border.push.dent[i] = 0.0
	rec._poll_pushes()
	assert_int(_of_type(_events(td), "gate_hold").size()).is_equal(0)


func test_a_push_that_ends_without_a_break_is_logged_as_a_hold() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	_rescue_ring(td, Vector3.ZERO, 3.0, 30)
	await runner.simulate_frames(60)
	var i := _gate_point(td)
	var gid: int = td.border.zone.gates[td.border.point_gate(i)].get("id", -1)
	td.border.push.dent[i] = RecorderConfig.RECORD_PUSH_DENT + 0.05  # pushed, but short of a break
	rec.t += 1.0
	rec._poll_pushes()
	rec.t += 1.5
	td.border.push.dent[i] = 0.0
	rec._poll_pushes()
	var holds := _of_type(_events(td), "gate_hold")
	assert_int(holds.size()).is_equal(1)
	assert_float(holds[0]["gate"]).is_equal(float(gid))
	assert_float(holds[0]["seconds"]).is_equal_approx(1.5, 0.01)
	assert_int(_of_type(_events(td), "gate_break").size()).is_equal(0)


func test_a_gate_that_is_barely_dented_is_not_being_pushed() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	_rescue_ring(td, Vector3.ZERO, 3.0, 30)
	await runner.simulate_frames(60)
	td.border.push.dent[_gate_point(td)] = RecorderConfig.RECORD_PUSH_DENT * 0.5
	rec._poll_pushes()
	assert_bool(rec._pushes.is_empty()).is_true()


# A point on a gate (the first one the border has), for the push tests.
func _gate_point(td: TopDownMain) -> int:
	for i: int in range(td.border.push.dent.size()):
		if td.border.point_gate(i) >= 0:
			return i
	return -1


func test_the_mark_key_is_bound_to_the_f8_key() -> void:
	var keys: Array[int] = []
	for ev: InputEvent in InputMap.action_get_events("mark_moment"):
		if ev is InputEventKey:
			keys.append((ev as InputEventKey).physical_keycode)
	assert_array(keys).is_equal([KEY_F8])


func test_the_mark_key_logs_a_mark_and_flashes_marked_while_recording() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	var press := InputEventAction.new()
	press.action = "mark_moment"
	press.pressed = true
	rec._unhandled_input(press)
	assert_int(rec.marks_made).is_equal(1)
	var marks := _of_type(_events(td), "mark")
	assert_int(marks.size()).is_equal(1)
	assert_float(marks[0]["n"]).is_equal(1.0)
	assert_bool(td.hud.mark_label.visible).is_true()
	# Releasing the key is not a mark.
	var release := InputEventAction.new()
	release.action = "mark_moment"
	release.pressed = false
	rec._unhandled_input(release)
	assert_int(rec.marks_made).is_equal(1)
	# The flash is hidden again with the REC mark when recording stops.
	td.hud.set_recording(false)
	assert_bool(td.hud.mark_label.visible).is_false()


func test_a_mark_after_the_session_ended_is_ignored() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec.end("quit")
	rec.mark()
	assert_int(rec.marks_made).is_equal(0)


func test_the_hud_does_not_flash_marked_when_not_recording() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.hud.set_recording(false)
	td.hud.flash_marked()
	assert_bool(td.hud.mark_label.visible).is_false()


func test_a_mark_takes_a_screenshot_at_once_even_inside_the_throttle() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	assert_bool(rec._event_shot("take", _picture())).is_true()
	rec.mark()  # Headless: there is no frame to grab, so this mark logs with no shot.
	assert_bool(rec._event_shot("mark", _picture(), true)).is_true()  # The forced mark shot, inside the 3 s gap.
	var shots := _of_type(_events(td), "screenshot")
	assert_str(shots.back()["cause"]).is_equal("mark")
	await _await_file(rec.session_dir.path_join("shot_0002_mark.png"))


func test_event_shots_are_at_most_one_per_the_minimum_gap() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	assert_float(RecorderConfig.RECORD_EVENT_SHOT_MIN_GAP).is_equal(3.0)
	assert_bool(rec._event_shot("take", _picture())).is_true()
	assert_bool(rec._event_shot("auto_join", _picture())).is_false()  # Within the gap.
	rec.t += RecorderConfig.RECORD_EVENT_SHOT_MIN_GAP - 0.1
	assert_bool(rec._event_shot("break_open", _picture())).is_false()
	rec.t += 0.2
	assert_bool(rec._event_shot("auto_join", _picture())).is_true()
	assert_int(rec.shots_taken).is_equal(2)
	var shots := _of_type(_events(td), "screenshot")
	var files: Array[String] = []
	var causes: Array[String] = []
	for e: Dictionary in shots:
		files.append(e["file"])
		causes.append(e["cause"])
	assert_array(files).is_equal(["shot_0001_take.png", "shot_0002_auto_join.png"])
	assert_array(causes).is_equal(["take", "auto_join"])
	await _await_file(rec.session_dir.path_join("shot_0002_auto_join.png"))


func test_the_first_break_of_a_phase_is_shot_and_later_ones_in_that_phase_are_not() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec._first_break_shot(_picture())
	assert_int(rec._break_shot_phases.size()).is_equal(1)
	rec.t += RecorderConfig.RECORD_EVENT_SHOT_MIN_GAP + 1.0  # Past the throttle: only the phase stops it.
	rec._first_break_shot(_picture())
	assert_int(rec.shots_taken).is_equal(1)
	var shots := _of_type(_events(td), "screenshot")
	assert_str(shots[0]["cause"]).is_equal("break_open")
	await _await_file(rec.session_dir.path_join("shot_0001_break_open.png"))


func test_a_gate_index_outside_the_zone_has_no_id() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	assert_int(td.recorder._gate_id_of(-1)).is_equal(-1)
	assert_int(td.recorder._gate_id_of(9999)).is_equal(-1)


func test_an_event_shot_after_the_session_ended_or_with_an_empty_picture_is_not_taken() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	assert_bool(rec._event_shot("take", Image.new())).is_false()  # An empty picture: nothing saved.
	assert_int(rec.shots_taken).is_equal(0)
	rec.end("quit")
	assert_bool(rec._event_shot("take", _picture())).is_false()


func test_flashing_marked_twice_restarts_the_flash() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.hud.flash_marked()
	td.hud.flash_marked()
	assert_bool(td.hud.mark_label.visible).is_true()


func test_the_hud_debug_and_floor_text_setters_show_their_text() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.hud.set_debug_on(true)
	assert_bool(td.hud.debug_hint_label.visible).is_true()
	assert_bool(td.hud.floor_label.visible).is_true()
	td.hud.set_debug_on(false)
	assert_bool(td.hud.floor_label.visible).is_false()
	td.hud.set_floor_text("Floor 3")
	td.hud.set_debug_text("F3 hint")
	assert_str(td.hud.floor_label.text).is_equal("Floor 3")
	assert_str(td.hud.debug_hint_label.text).is_equal("F3 hint")
	# Nothing is being announced at the start of a level (no alert up or fading).
	assert_bool(td.hud.alert_showing()).is_false()


func test_a_headless_event_shot_asks_for_no_picture_and_takes_none() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	assert_bool(rec._event_shot("take")).is_false()
	rec._first_break_shot()
	assert_bool(rec._break_shot_phases.is_empty()).is_true()
	assert_int(rec.shots_taken).is_equal(0)


func test_a_timer_shot_is_named_without_a_cause_and_the_event_says_so() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	assert_bool(rec._record_shot(_picture())).is_true()
	var shots := _of_type(_events(td), "screenshot")
	assert_str(shots[0]["file"]).is_equal("shot_0001.png")
	assert_str(shots[0]["cause"]).is_equal("timer")
	await _await_file(rec.session_dir.path_join("shot_0001.png"))


func test_a_player_going_dim_asks_for_an_event_shot() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rec: Recorder = td.recorder
	rec._on_player_dim(true)
	rec._on_player_dim(false)
	var events := _events(td)
	assert_int(_of_type(events, "player_dim").size()).is_equal(2)
	assert_int(_of_type(events, "screenshot").size()).is_equal(0)  # headless: nothing to grab
