extends GdUnitTestSuite

# Round 24: beatable dimmed people and catchable waves.
#  - A burst lifts every dimmed person within BURST_LIFT_RADIUS, not only those on the border; joy wins a dimmed person
#    back faster and their progress holds longer.
#  - A rescued person drained below the relapse line wobbles first (about WOBBLE_SECONDS); a joy hit then saves them;
#    a group drained together relapses a few at a time, not on one frame.

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


func _person(pos: Vector3, gloom: float, rescued: bool, seed_id: int = 0) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = 0
	p.gloom = gloom
	p.look_seed = seed_id
	add_child(p)
	p.global_position = pos
	if rescued:
		p.receive_joy(0, Config.JOY_MAX, 0.0)
		p.grace_left = 0.0
	return p


# Distance between two colours (the sum of the channel differences).
func _dist(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


# Runs `seconds` of ticks at 60 Hz.
func _tick(p: Person, seconds: float) -> void:
	for i: int in range(int(seconds * 60.0)):
		p.tick(1.0 / 60.0)


# Drains a rescued person just below the relapse line so they begin to wobble.
func _start_wobble(p: Person) -> void:
	p.drain_joy(p.joy - p.joy_needed() * PeopleConfig.RELAPSE_FRACTION + 1.0)


func _start(on: bool = false) -> Dictionary:
	Recorder.enabled = on
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


func _events(td: TopDownMain, type: String) -> Array[Dictionary]:
	td.recorder._flush()
	var out: Array[Dictionary] = []
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	assert_object(file).is_not_null()
	while file.get_position() < file.get_length():
		var parsed: Variant = JSON.parse_string(file.get_line())
		if parsed is Dictionary and (parsed as Dictionary).get("type", "") == type:
			out.append(parsed as Dictionary)
	return out


# --- Beatable dimmed: the burst -----------------------------------------------------------------------------------


func test_the_burst_lifts_every_dimmed_person_in_the_radius_wherever_they_stand() -> void:
	var at := Vector3.ZERO
	var near := _person(Vector3(SpiritConfig.BURST_LIFT_RADIUS - 1.0, 0, 0), 0.95, false)
	var middle := _person(Vector3(0, 0, -(SpiritConfig.BURST_CLEAR_RADIUS + 3.0)), 1.0, false)
	var far := _person(Vector3(SpiritConfig.BURST_LIFT_RADIUS + 2.0, 0, 0), 0.95, false)
	var gloomy := _person(Vector3(2, 0, 2), 0.5, false)
	var people: Array[Person] = [near, middle, far, gloomy]
	near.joy = 300.0
	var report := BurstClear.run(people, at, null)
	assert_int(report["lifted"]).is_equal(2)
	for p: Person in [near, middle]:
		assert_float(p.gloom).is_equal(SpiritConfig.BURST_LIFT_GLOOM)
		assert_float(p.joy).is_equal(0.0)
		assert_float(p.calm_left).is_equal(SpiritConfig.BURST_CALM_SECONDS)
		assert_bool(GloomSim.is_dimmed(p)).is_false()
	assert_float(far.gloom).is_equal(0.95)
	assert_bool(BurstClear.is_target(far, at)).is_false()
	assert_int(BurstClear.count_targets(people, at)).is_equal(0)  # Lifted: nobody left to lift.
	# Away from the border nobody is pushed: they are lifted where they stand.
	assert_vector(near.global_position).is_equal(Vector3(SpiritConfig.BURST_LIFT_RADIUS - 1.0, 0, 0))


func test_the_burst_counts_the_dimmed_people_it_would_lift() -> void:
	var people: Array[Person] = [
		_person(Vector3(3, 0, 0), 0.9, false),
		_person(Vector3(0, 0, 11), 0.9, false),
		_person(Vector3(0, 0, 30), 0.9, false),
		_person(Vector3(1, 0, 1), 0.2, false),
	]
	assert_int(BurstClear.count_targets(people, Vector3.ZERO)).is_equal(2)


func test_a_real_burst_lifts_a_dimmed_person_standing_far_from_the_border() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.open_dim_gate(td)
	td.player.global_position = Vector3.ZERO
	var d: Person = td.people[3]
	TopDownTestUtil.place(d, Vector3(SpiritConfig.BURST_LIFT_RADIUS - 2.0, 0, 0), 1, 0.95)
	await runner.simulate_frames(2)
	d.gloom = 0.95
	assert_bool(GloomSim.is_dimmed(d)).is_true()
	td.player.add_spirit(100.0)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	assert_bool(GloomSim.is_dimmed(d)).is_false()
	assert_int(Config.gloom_level(d.gloom)).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Beatable dimmed: joy wins them back ---------------------------------------------------------------------------


func test_joy_lands_harder_on_a_dimmed_person_and_they_need_fewer_shots() -> void:
	var dimmed := _person(Vector3.ZERO, 1.0, false)
	var gloomy := _person(Vector3(5, 0, 0), 0.5, false)
	dimmed.receive_joy(0, ProjectileConfig.TD_JOY_PER_SHOT, 0.0)
	gloomy.receive_joy(0, ProjectileConfig.TD_JOY_PER_SHOT, 0.0)
	var base := gloomy.joy
	assert_float(dimmed.joy).is_equal_approx(base * PeopleConfig.DIMMED_JOY_MULT, 0.01)
	var shots := 1
	while not dimmed.is_rescued and shots < 30:
		dimmed.receive_joy(0, ProjectileConfig.TD_JOY_PER_SHOT, 0.0)
		shots += 1
	assert_bool(dimmed.is_rescued).is_true()
	assert_int(shots).is_less_equal(6)  # Round 23: about 10 matching shots.


func test_a_dimmed_person_keeps_their_progress_longer_than_a_gloomy_one() -> void:
	var dimmed := _person(Vector3.ZERO, 1.0, false)
	var gloomy := _person(Vector3(5, 0, 0), 0.5, false)
	dimmed.joy = 600.0
	gloomy.joy = 600.0
	# Past the fade delay, three seconds of fading.
	dimmed._since_hit = PeopleConfig.JOY_FADE_DELAY + 1.0
	gloomy._since_hit = PeopleConfig.JOY_FADE_DELAY + 1.0
	_tick(dimmed, 3.0)
	_tick(gloomy, 3.0)
	var lost_dimmed := 600.0 - dimmed.joy
	var lost_gloomy := 600.0 - gloomy.joy
	assert_float(lost_gloomy).is_greater(0.0)
	assert_float(lost_dimmed).is_equal_approx(lost_gloomy * PeopleConfig.DIMMED_FADE_MULT, 2.0)


func test_a_dimmed_body_warms_to_their_colour_as_joy_builds() -> void:
	var dimmed := _person(Vector3.ZERO, 1.0, false)
	dimmed.tick(0.01)  # The level is read on a tick.
	dimmed.look.sync()
	var empty: Color = (dimmed.look as PersonLookPlaceholder).body_mat.albedo_color
	dimmed.joy = dimmed.joy_needed() * 0.8
	dimmed.look.sync()
	var warm: Color = (dimmed.look as PersonLookPlaceholder).body_mat.albedo_color
	var target: Color = Config.ELEMENT_COLORS[0]
	assert_float(_dist(warm, target)).is_less(_dist(empty, target))


# --- Catchable waves: the wobble ----------------------------------------------------------------------------------


func test_a_drained_person_wobbles_first_and_relapses_when_the_wobble_runs_out() -> void:
	var p := _person(Vector3.ZERO, 0.0, true, 3)
	var events := [0, 0, 0.0]
	p.wobbled.connect(
		func(seconds: float) -> void:
			events[0] += 1
			events[2] = seconds
	)
	p.relapsed.connect(func() -> void: events[1] += 1)
	p.drain_joy(p.joy - p.joy_needed() * PeopleConfig.RELAPSE_FRACTION + 1.0)
	assert_bool(p.wobbling).is_true()
	assert_bool(p.is_rescued).is_true()
	assert_int(events[0]).is_equal(1)
	assert_float(events[2]).is_between(
		PeopleConfig.WOBBLE_SECONDS * (1.0 - PeopleConfig.WOBBLE_JITTER),
		PeopleConfig.WOBBLE_SECONDS * (1.0 + PeopleConfig.WOBBLE_JITTER)
	)
	# More drain during the wobble does not start another one or relapse early.
	p.drain_joy(10.0)
	assert_int(events[0]).is_equal(1)
	_tick(p, p.wobble_total - 0.5)
	assert_bool(p.is_rescued).is_true()
	assert_int(events[1]).is_equal(0)
	_tick(p, 1.0)
	assert_bool(p.is_rescued).is_false()
	assert_bool(p.wobbling).is_false()
	assert_int(events[1]).is_equal(1)


func test_the_wobble_length_varies_between_people_and_between_wobbles() -> void:
	var lengths := {}
	for i: int in range(8):
		var p := _person(Vector3.ZERO, 0.0, true, i)
		lengths[snappedf(p.next_wobble_seconds(), 0.001)] = true
		assert_float(p.next_wobble_seconds()).is_between(
			PeopleConfig.WOBBLE_SECONDS * (1.0 - PeopleConfig.WOBBLE_JITTER) - 0.001,
			PeopleConfig.WOBBLE_SECONDS * (1.0 + PeopleConfig.WOBBLE_JITTER) + 0.001
		)
	assert_int(lengths.size()).is_greater(5)
	var q := _person(Vector3.ZERO, 0.0, true, 2)
	var first := q.next_wobble_seconds()
	q.wobble_count = 1
	assert_float(q.next_wobble_seconds()).is_not_equal(first)


func test_a_joy_hit_in_the_wobble_saves_the_person() -> void:
	var p := _person(Vector3.ZERO, 0.0, true, 1)
	var saves := [0, 0]
	p.saved.connect(func() -> void: saves[0] += 1)
	p.relapsed.connect(func() -> void: saves[1] += 1)
	_start_wobble(p)
	_tick(p, 2.0)
	assert_bool(p.wobbling).is_true()
	p.receive_joy(0, 1.0, 0.0)  # Even a tiny hit counts.
	assert_bool(p.wobbling).is_false()
	assert_int(saves[0]).is_equal(1)
	assert_float(p.joy).is_greater_equal(
		p.joy_needed() * (PeopleConfig.RELAPSE_FRACTION + PeopleConfig.WOBBLE_SAVE_JOY) - 0.01
	)
	assert_float(p.grace_left).is_greater(0.0)
	# Drain skips them in the grace, and the old wobble never ends in a relapse.
	var joy := p.joy
	p.drain_joy(500.0)
	assert_float(p.joy).is_equal(joy)
	_tick(p, PeopleConfig.WOBBLE_SECONDS * 2.0)
	assert_bool(p.is_rescued).is_true()
	assert_int(saves[1]).is_equal(0)


func test_a_joy_hit_after_the_relapse_is_too_late() -> void:
	var p := _person(Vector3.ZERO, 0.0, true, 1)
	_start_wobble(p)
	_tick(p, PeopleConfig.WOBBLE_SECONDS * 1.3)
	assert_bool(p.is_rescued).is_false()


func test_joy_back_above_the_line_ends_the_wobble_without_a_relapse() -> void:
	var p := _person(Vector3.ZERO, 0.0, true, 5)
	_start_wobble(p)
	p.joy = p.joy_needed() * PeopleConfig.RELAPSE_FRACTION + 50.0
	_tick(p, 0.1)
	assert_bool(p.wobbling).is_false()
	assert_bool(p.is_rescued).is_true()


func test_the_wobble_is_seen_in_the_placeholder_look_as_greying_and_sway() -> void:
	var p := _person(Vector3.ZERO, 0.0, true, 4)
	var look := p.look as PersonLookPlaceholder
	_start_wobble(p)
	p.look.sync()
	assert_bool(look.wobbling).is_true()
	var early := look.body_mat.albedo_color
	p.wobble_left = p.wobble_total * 0.05
	p.look.sync()
	var late := look.body_mat.albedo_color
	var grey: Color = PeopleConfig.LEVEL_COLORS[1]
	assert_float(_dist(late, grey)).is_less(_dist(early, grey))
	assert_float(look.wobble_prog).is_greater(0.9)
	# The body sways: over a few readings the wave is not zero.
	var swayed := false
	for i: int in range(40):
		p.look.advance(1.0 / 60.0)  # the look's own clock moves with the fixed step, not the wall clock
		p.look.sync()
		swayed = swayed or absf(look.body.rotation.y) > 0.01
	assert_bool(swayed).is_true()
	# A saved person stops swaying.
	p.receive_joy(0, 1.0, 0.0)
	p.look.sync()
	assert_bool(look.wobbling).is_false()
	assert_float(look.body.rotation.z).is_equal(0.0)


# --- Catchable waves: a group goes a few at a time ------------------------------------------------------------------


func test_the_relapse_gate_lets_one_person_through_per_gap() -> void:
	var gate := RelapseWave.new()
	assert_bool(gate.allow()).is_true()
	assert_bool(gate.allow()).is_false()
	gate.advance(PeopleConfig.RELAPSE_GATE_GAP * 0.5)
	assert_bool(gate.allow()).is_false()
	gate.advance(PeopleConfig.RELAPSE_GATE_GAP * 0.6)
	assert_bool(gate.allow()).is_true()


func test_a_group_near_a_dimmed_person_no_longer_relapses_on_one_frame() -> void:
	# The round 23 cohort: eight rescued people round one dimmed person at midnight strength. They tip into the wobble
	# together, but they relapse one at a time, over several seconds.
	var dimmed := _person(Vector3.ZERO, 1.0, false)
	var cohort: Array[Person] = []
	var wave := RelapseWave.new()
	for i: int in range(8):
		var a := TAU * float(i) / 8.0
		var p := _person(Vector3(cos(a), 0.0, sin(a)) * 4.0, 0.0, true, i)
		p.relapse_gate = wave.allow
		cohort.append(p)
	var everyone: Array = [dimmed]
	everyone.append_array(cohort)
	var wobble_frame: Array[int] = []
	var relapse_frame: Array[int] = []
	for p: Person in cohort:
		wobble_frame.append(-1)
		relapse_frame.append(-1)
	for frame: int in range(60 * 45):
		wave.advance(1.0 / 60.0)
		GloomSim.update(everyone, 1.0 / 60.0, PeopleConfig.TD_DRAIN_MULTIPLIER, 1.44)
		for p: Person in cohort:
			p.tick(1.0 / 60.0)
		for i: int in range(cohort.size()):
			if wobble_frame[i] < 0 and cohort[i].wobbling:
				wobble_frame[i] = frame
			if relapse_frame[i] < 0 and not cohort[i].is_rescued:
				relapse_frame[i] = frame
	for i: int in range(cohort.size()):
		assert_int(wobble_frame[i]).is_greater(0)
		assert_int(relapse_frame[i]).is_greater(wobble_frame[i])
		# Each one wobbled for at least the shortest wobble before relapsing.
		var wobbled_for := float(relapse_frame[i] - wobble_frame[i]) / 60.0
		assert_float(wobbled_for).is_greater_equal(
			PeopleConfig.WOBBLE_SECONDS * (1.0 - PeopleConfig.WOBBLE_JITTER) - 0.1
		)
	# No two on the same frame, and the first to last spread is several seconds.
	var seen := {}
	for f: int in relapse_frame:
		assert_bool(seen.has(f)).is_false()
		seen[f] = true
	var first: int = relapse_frame.min()
	var last: int = relapse_frame.max()
	assert_float(float(last - first) / 60.0).is_greater_equal(PeopleConfig.RELAPSE_GATE_GAP * 7.0 - 0.1)


func test_a_group_drained_together_wobbles_with_varied_lengths_even_without_the_gate() -> void:
	var group: Array[Person] = []
	for i: int in range(6):
		var p := _person(Vector3(i * 2.0, 0, 0), 0.0, true, i)
		_start_wobble(p)
		group.append(p)
	var lengths := {}
	for p: Person in group:
		lengths[snappedf(p.wobble_total, 0.001)] = true
	assert_int(lengths.size()).is_greater(3)


# --- The level: wiring, the burst saves a wobbler, the recorder ----------------------------------------------------


func test_in_the_level_everyone_asks_one_shared_relapse_gate() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	for p: Person in td.people:
		assert_bool(p.relapse_gate.is_valid()).is_true()
	assert_bool(td.people[0].relapse_gate == td.people[1].relapse_gate).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_burst_saves_the_wobbling_people_in_reach() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0
	td.player.global_position = Vector3.ZERO
	var a: Person = td.people[0]
	var b: Person = td.people[1]
	TopDownTestUtil.place(a, Vector3(3, 0, 0), 0, 0.0)
	TopDownTestUtil.place(b, Vector3(-4, 0, 3), 1, 0.0)
	for p: Person in [a, b]:
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
		p.grace_left = 0.0
		_start_wobble(p)
	assert_bool(a.wobbling and b.wobbling).is_true()
	td.player.add_spirit(100.0)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	assert_bool(a.wobbling).is_false()
	assert_bool(b.wobbling).is_false()
	assert_bool(a.is_rescued and b.is_rescued).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_recorder_logs_a_wobble_and_a_save() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var p: Person = td.people[5]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 0, 0.0)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	p.grace_left = 0.0
	_start_wobble(p)
	var wobbles := _events(td, "wobble")
	assert_int(wobbles.size()).is_equal(1)
	assert_float(wobbles[0]["id"]).is_equal(5.0)
	assert_float(wobbles[0]["seconds"]).is_greater(
		PeopleConfig.WOBBLE_SECONDS * (1.0 - PeopleConfig.WOBBLE_JITTER) - 0.01
	)
	p.receive_joy(0, 50.0, 0.0)
	var saves := _events(td, "save")
	assert_int(saves.size()).is_equal(1)
	assert_float(saves[0]["id"]).is_equal(5.0)
	await TopDownTestUtil.leave_loaded_scene(td)
