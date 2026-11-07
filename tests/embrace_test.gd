extends GdUnitTestSuite

# Round 25 part S: embrace. An unrescued person inside the border loop is lifted a stage every EMBRACE_STEP_SECONDS and
# rescued at the end through the ordinary rescue; outside does nothing; leaving pauses and slowly fades the step; the
# nearest members drain a little faster meanwhile; the recorder notes it. The loop is a square set by hand and Embrace
# is stepped directly (no frames pass between the setup and the checks, so Border.update never redraws the loop).

const CENTRE := Vector3(-11.7, 0.0, -6.5)
const HALF := 12.0
const DT := 1.0 / 60.0

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base
	Recorder.enabled = false


func after_test() -> void:
	Recorder.enabled = false
	Recorder.base_dir_override = ""
	Config.intro_override = -1
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
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


func _start(recording: bool = false) -> TopDownMain:
	Recorder.enabled = recording
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.polygon = PackedVector2Array(
		[
			Vector2(CENTRE.x - HALF, CENTRE.z - HALF),
			Vector2(CENTRE.x + HALF, CENTRE.z - HALF),
			Vector2(CENTRE.x + HALF, CENTRE.z + HALF),
			Vector2(CENTRE.x - HALF, CENTRE.z + HALF)
		]
	)
	return td


# An unrescued person at `offset` from the loop's centre with `gloom`.
func _person(td: TopDownMain, i: int, offset: Vector3, gloom: float) -> Person:
	var p: Person = td.people[i]
	TopDownTestUtil.place(p, CENTRE + offset, p.affinity, gloom)
	return p


# A rescued border member at `offset` with `share` of the joy they need and no grace.
func _member(td: TopDownMain, i: int, offset: Vector3, share: float) -> Person:
	var p: Person = td.people[i]
	TopDownTestUtil.place(p, CENTRE + offset, p.affinity, 0.0)
	p.is_rescued = true
	p.grace_left = 0.0
	p.joy = p.joy_needed() * share
	td.border.members.append(p)
	return p


func _run(td: TopDownMain, seconds: float) -> void:
	for i: int in range(roundi(seconds / DT)):
		td.embrace.step(DT)


func _events(td: TopDownMain, type: String) -> Array[Dictionary]:
	td.recorder._flush()
	var out: Array[Dictionary] = []
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary and (parsed as Dictionary)["type"] == type:
			out.append(parsed)
	return out


func test_inside_lifts_a_stage_per_step_and_rescues_at_the_end() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.8)
	td.player.spirit = 10.0
	var rescued_before := td.rescued_count
	_run(td, Config.EMBRACE_STEP_SECONDS + 0.2)
	assert_int(Config.gloom_level(p.gloom)).is_equal(1)
	assert_bool(p.is_rescued).is_false()
	_run(td, Config.EMBRACE_STEP_SECONDS)
	assert_int(Config.gloom_level(p.gloom)).is_equal(0)
	assert_bool(p.is_rescued).is_false()
	_run(td, Config.EMBRACE_STEP_SECONDS)
	assert_bool(p.is_rescued).is_true()
	assert_int(td.rescued_count).is_equal(rescued_before + 1)
	assert_float(td.player.spirit).is_equal_approx(10.0 + Config.SPIRIT_PER_RESCUE, 0.001)
	assert_float(p.grace_left).is_greater(0.0)  # The ordinary rescue grace.
	assert_int(td.embrace.start_count).is_equal(1)
	assert_int(td.embrace.lift_count).is_equal(2)
	assert_int(td.embrace.rescue_count).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_wistful_person_inside_is_rescued_after_one_step() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3(3, 0, 3), 0.1)
	_run(td, Config.EMBRACE_STEP_SECONDS - 1.0)
	assert_bool(p.is_rescued).is_false()
	assert_float(td.embrace.progress_of(p)).is_greater(0.8)
	_run(td, 1.2)
	assert_bool(p.is_rescued).is_true()
	assert_int(td.embrace.lift_count).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_outside_the_loop_nothing_happens_even_for_a_dimmed_person_pressing() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3(HALF + 1.0, 0, 0), 0.8)
	var q := _person(td, 1, Vector3(0, 0, -HALF - 2.0), 0.4)
	_run(td, 3.0 * Config.EMBRACE_STEP_SECONDS)
	assert_int(Config.gloom_level(p.gloom)).is_equal(2)
	assert_float(q.gloom).is_equal(0.4)
	assert_bool(p.is_rescued or q.is_rescued).is_false()
	assert_int(td.embrace.start_count).is_equal(0)
	assert_int(td.embrace.entries.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_no_loop_means_no_embrace() -> void:
	var td: TopDownMain = await _start()
	td.border.polygon = PackedVector2Array()
	var p := _person(td, 0, Vector3.ZERO, 0.1)
	_run(td, 2.0 * Config.EMBRACE_STEP_SECONDS)
	assert_bool(p.is_rescued).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_leaving_pauses_and_the_step_fades_slowly() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.1)
	_run(td, 4.0)
	assert_float(td.embrace.progress_of(p)).is_equal_approx(0.5, 0.02)
	p.global_position = CENTRE + Vector3(HALF + 3.0, 0, 0)  # Walks out.
	_run(td, 4.0)
	var expected := (4.0 - Config.EMBRACE_DECAY_RATE * 4.0) / Config.EMBRACE_STEP_SECONDS
	assert_float(td.embrace.progress_of(p)).is_equal_approx(expected, 0.02)
	assert_bool(p.is_rescued).is_false()
	p.global_position = CENTRE  # Back in: it carries on from there.
	_run(td, Config.EMBRACE_STEP_SECONDS * (1.0 - expected) + 0.2)
	assert_bool(p.is_rescued).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_long_absence_loses_the_step_and_the_cue() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.1)
	_run(td, 2.0)
	assert_bool(td.embrace.entries.has(p)).is_true()
	p.global_position = CENTRE + Vector3(HALF + 3.0, 0, 0)
	_run(td, 2.0 / Config.EMBRACE_DECAY_RATE + 1.0)
	assert_bool(td.embrace.entries.has(p)).is_false()
	assert_float(td.embrace.progress_of(p)).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_nearest_members_drain_a_little_faster_only_while_embracing() -> void:
	var td: TopDownMain = await _start()
	var members: Array[Person] = []
	for i: int in range(5):
		members.append(_member(td, 10 + i, Vector3(float(i) * 2.0 - 4.0, 0, 6), 0.9))
	var before := members[0].joy
	_run(td, 5.0)
	for m: Person in members:
		assert_float(m.joy).is_equal_approx(before, 0.001)  # Nobody embraced: no extra drain.
	var p := _person(td, 0, Vector3(0, 0, 4), 0.8)  # Nearest members: x 0 (d 2), -2 and 2 (d 2.8).
	assert_int(td.embrace.nearest_members(p, Config.EMBRACE_STRAIN_COUNT).size()).is_equal(3)
	_run(td, 5.0)
	var drain := Config.EMBRACE_STRAIN_RATE * 5.0
	for i: int in range(1, 4):
		assert_float(members[i].joy).is_equal_approx(before - drain, 0.5)
	assert_float(members[0].joy).is_equal_approx(before, 0.001)  # x -4: not among the nearest three.
	assert_float(members[4].joy).is_equal_approx(before, 0.001)
	assert_float(drain).is_less(24.0 * 5.0)  # A little: under what a dimmed person drains.
	await TopDownTestUtil.leave_loaded_scene(td)


func test_strain_stops_when_the_embrace_ends() -> void:
	var td: TopDownMain = await _start()
	var m := _member(td, 10, Vector3(0, 0, 6), 0.9)
	var p := _person(td, 0, Vector3(0, 0, 4), 0.1)
	_run(td, Config.EMBRACE_STEP_SECONDS + 0.5)  # Rescued at 8 s.
	assert_bool(p.is_rescued).is_true()
	var after := m.joy
	_run(td, 3.0)
	assert_float(m.joy).is_equal_approx(after, 0.001)
	assert_float(m.joy).is_less(m.joy_needed() * 0.9)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_rescued_members_grace_still_protects_them() -> void:
	var td: TopDownMain = await _start()
	var m := _member(td, 10, Vector3(0, 0, 6), 0.9)
	m.grace_left = 100.0
	var before := m.joy
	_person(td, 0, Vector3(0, 0, 4), 0.8)
	_run(td, 5.0)
	assert_float(m.joy).is_equal(before)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_works_from_the_current_stage_so_first_light_saves_steps() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.5)  # Gloomy: two steps on their own.
	_run(td, 2.0)
	p.gloom = 0.1  # First light's lift took them to wistful.
	_run(td, Config.EMBRACE_STEP_SECONDS)
	assert_bool(p.is_rescued).is_true()
	assert_int(td.embrace.lift_count).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_gloom_does_not_grow_on_an_embraced_person() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.8)
	_run(td, 1.0)
	assert_float(p.calm_left).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_person_who_just_relapsed_is_left_alone_for_a_while() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.6)
	_run(td, 2.0)
	assert_bool(td.embrace.entries.has(p)).is_true()
	p.relapsed.emit()
	assert_bool(td.embrace.entries.has(p)).is_false()
	_run(td, Config.EMBRACE_RELAPSE_PAUSE - 1.0)
	assert_bool(td.embrace.entries.has(p)).is_false()
	_run(td, 2.0)
	assert_bool(td.embrace.entries.has(p)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_cue_shows_a_glow_and_a_ring_that_fills_and_goes_when_rescued() -> void:
	var td: TopDownMain = await _start()
	var p := _person(td, 0, Vector3.ZERO, 0.1)
	_run(td, 1.0)
	var cue: EmbraceCue = td.embrace.entries[p].cue
	assert_object(cue).is_not_null()
	assert_object(cue.get_parent()).is_same(p)
	var early := cue.segments()
	_run(td, 4.0)
	assert_int(cue.segments()).is_greater(early)
	assert_int(cue.segments()).is_less_equal(Config.EMBRACE_RING_SEGMENTS)
	_run(td, 4.0)
	assert_bool(p.is_rescued).is_true()
	assert_bool(cue.is_queued_for_deletion()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_through_the_real_frames_a_wistful_person_in_a_real_loop_is_rescued() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	var count := 12
	var r := BorderCentre.circle_radius(count)
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var m: Person = td.people[i]
		TopDownTestUtil.place(m, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), m.affinity, 0.0)
		m.receive_joy(m.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(300)
	var p: Person = td.people[count]
	TopDownTestUtil.place(p, CENTRE, p.affinity, 0.1)
	var before := td.rescued_count
	await runner.simulate_frames(roundi((Config.EMBRACE_STEP_SECONDS + 1.0) * 60.0))
	assert_bool(p.is_rescued).is_true()
	assert_int(td.rescued_count).is_equal(before + 1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_recorder_notes_start_lift_and_rescue() -> void:
	var td: TopDownMain = await _start(true)
	var p := _person(td, 0, Vector3.ZERO, 0.5)
	_run(td, 2.0 * Config.EMBRACE_STEP_SECONDS + 0.5)
	var starts := _events(td, "embrace_start")
	var lifts := _events(td, "embrace_lift")
	var rescues := _events(td, "embrace_rescue")
	assert_int(starts.size()).is_equal(1)
	assert_str(starts[0]["stage"]).is_equal("gloomy")
	assert_int(lifts.size()).is_equal(1)
	assert_str(lifts[0]["from"]).is_equal("gloomy")
	assert_str(lifts[0]["to"]).is_equal("wistful")
	assert_int(rescues.size()).is_equal(1)
	assert_float(rescues[0]["seconds"]).is_equal_approx(2.0 * Config.EMBRACE_STEP_SECONDS, 0.1)
	assert_float(rescues[0]["id"]).is_equal(float(td.people.find(p)))
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_count_of_embraced_people_and_a_rescue_by_other_means_drops_the_entry() -> void:
	var td: TopDownMain = await _start()
	var inside := _person(td, 0, Vector3.ZERO, 0.1)
	var outside := _person(td, 1, Vector3(HALF * 3.0, 0.0, 0.0), 0.1)
	_run(td, 1.0)
	assert_int(td.embrace.embraced_count()).is_equal(1)
	assert_bool(td.embrace.entries.has(outside)).is_false()
	# Rescued some other way (a joy hit): the next step drops them.
	inside.is_rescued = true
	td.embrace.step(DT)
	assert_bool(td.embrace.entries.has(inside)).is_false()
	assert_int(td.embrace.embraced_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_cue_not_yet_built_shows_nothing() -> void:
	var cue: EmbraceCue = auto_free(EmbraceCue.new())
	cue.show_progress(0.5, true, 1.0)
	assert_object(cue.get_child(0) if cue.get_child_count() > 0 else null).is_null()
