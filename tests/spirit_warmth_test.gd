extends GdUnitTestSuite

# Checkpoint 5: spare spirit warms the border. What a gain would have added past a full meter goes into a pool that
# pours, slowly and at a fixed rate, into the most strained border members, who glow softly.

const CENTRE := Vector3(-11.7, 0.0, -6.5)

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


func _start(recording: bool = false) -> Dictionary:
	Recorder.enabled = recording
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# `count` rescued people standing in a ring (they form the border), each with `joy_share` of the joy they need.
func _ring(td: TopDownMain, runner: GdUnitSceneRunner, count: int, joy_share: float) -> void:
	var r := 3.0  # Inside the start square (0.4): they walk out to its gates and form the line there.
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(300)
	for i: int in range(count):
		td.people[i].joy = td.people[i].joy_needed() * joy_share


# A rescued person set up by hand and listed as a border member (for the rules that do not need a moving border).
func _member(td: TopDownMain, i: int, share: float) -> Person:
	var p: Person = td.people[i]
	TopDownTestUtil.place(p, CENTRE + Vector3(float(i), 0.0, 0.0), p.affinity, 0.0)
	p.is_rescued = true
	p.joy = p.joy_needed() * share
	td.border.members.append(p)
	return p


func test_a_gain_that_fits_adds_no_spare_and_one_that_does_not_spills_the_rest() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var spilled: Array[float] = []
	td.player.spirit_spilled.connect(func(a: float) -> void: spilled.append(a))
	td.player.spirit = 50.0
	td.player.add_spirit(20.0)
	assert_int(spilled.size()).is_equal(0)
	assert_float(td.spirit_warmth.pool).is_equal(0.0)
	td.player.spirit = 90.0
	td.player.add_spirit(20.0)  # 10 fit, 10 do not
	assert_float(td.player.spirit).is_equal(SpiritConfig.SPIRIT_MAX)
	assert_float(spilled[0]).is_equal_approx(10.0, 0.001)
	assert_float(td.spirit_warmth.pool).is_equal_approx(10.0, 0.001)
	td.player.add_spirit(20.0)  # full: all of it spills
	assert_float(td.spirit_warmth.pool).is_equal_approx(30.0, 0.001)
	td.player.add_spirit(-5.0)  # a loss is not a spill
	assert_int(spilled.size()).is_equal(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pool_is_capped() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.spirit_warmth.add_spare(1000.0)
	assert_float(td.spirit_warmth.pool).is_equal(SpiritConfig.SPARE_POOL_MAX)
	td.spirit_warmth.add_spare(-5.0)
	assert_float(td.spirit_warmth.pool).is_equal(SpiritConfig.SPARE_POOL_MAX)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_most_strained_member_is_warmed_first_and_the_content_are_left_alone() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var mid := _member(td, 0, 0.6)
	var low := _member(td, 1, 0.3)
	var fine := _member(td, 2, 0.95)  # over the ceiling
	var inner: Person = td.people[3]  # rescued but not on the line
	inner.is_rescued = true
	inner.joy = 0.1
	var gone: Person = td.people[4]  # still listed as a member for a moment, but no longer rescued
	gone.joy = 0.0
	td.border.members.append(gone)
	td.spirit_warmth.add_spare(10.0)
	assert_object(td.spirit_warmth.most_strained()).is_same(low)
	var before := low.joy
	var gave := td.spirit_warmth.pour()
	assert_float(gave).is_equal_approx(SpiritConfig.SPARE_WARM_RATE * SpiritConfig.SPARE_WARM_INTERVAL, 0.001)
	assert_float(low.joy - before).is_equal_approx(gave, 0.001)
	assert_float(td.spirit_warmth.pool).is_equal_approx(10.0 - gave / SpiritConfig.SPARE_JOY_PER_SPIRIT, 0.001)
	assert_float(inner.joy).is_equal(0.1)
	assert_float(fine.joy).is_equal_approx(fine.joy_needed() * 0.95, 0.001)
	assert_float(mid.joy).is_equal_approx(mid.joy_needed() * 0.6, 0.001)
	# Once the lowest has caught up with the next, the next is warmed.
	low.joy = mid.joy_needed() * 0.7
	assert_object(td.spirit_warmth.most_strained()).is_same(mid)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_nobody_under_the_ceiling_means_nothing_is_poured_and_the_pool_is_kept() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	_member(td, 0, SpiritConfig.SPARE_WARM_CEILING + 0.02)
	td.spirit_warmth.add_spare(10.0)
	assert_object(td.spirit_warmth.most_strained()).is_null()
	assert_float(td.spirit_warmth.pour()).is_equal(0.0)
	assert_float(td.spirit_warmth.pool).is_equal(10.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pour_runs_at_a_fixed_rate_and_ends_when_the_pool_is_empty() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var low := _member(td, 0, 0.1)
	low.joy = 0.0
	td.spirit_warmth.add_spare(4.0)  # 100 joy
	var start := low.joy
	var given := 0.0
	# 1 s of steps (quarter seconds, exact in floating point): two gifts of 40 joy, not more.
	for i: int in range(4):
		given += td.spirit_warmth.step(0.25)
	assert_float(given).is_equal_approx(SpiritConfig.SPARE_WARM_RATE * 1.0, 0.001)
	assert_float(low.joy - start).is_equal_approx(given, 0.001)
	# The rest: 20 joy, then it is over.
	for i: int in range(8):
		given += td.spirit_warmth.step(0.25)
	assert_float(given).is_equal_approx(100.0, 0.001)
	assert_float(td.spirit_warmth.pool).is_equal_approx(0.0, 0.0001)
	assert_float(td.spirit_warmth.step(1.0)).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_it_waits_while_the_round_is_not_running() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	_member(td, 0, 0.3)
	td.spirit_warmth.add_spare(10.0)
	td.running = false
	assert_float(td.spirit_warmth.step(5.0)).is_equal(0.0)
	assert_float(td.spirit_warmth.pool).is_equal(10.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_warm_tops_up_never_past_what_is_needed_and_skips_the_unrescued() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	p.is_rescued = true
	p.joy = p.joy_needed() - 10.0
	assert_float(SpiritWarmth.warm(p, 50.0)).is_equal_approx(10.0, 0.001)
	assert_float(p.joy).is_equal_approx(p.joy_needed(), 0.001)
	assert_float(SpiritWarmth.warm(p, 50.0)).is_equal(0.0)
	assert_int(p.react_kind).is_equal(Person.React.WARM)
	var q: Person = td.people[1]
	q.joy = 0.0
	assert_float(SpiritWarmth.warm(q, 50.0)).is_equal(0.0)
	assert_float(q.joy).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_warm_does_not_cut_short_a_patch_or_a_lift() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	p.is_rescued = true
	p.joy = 10.0
	p.react(Person.React.LIFT, 1.0)
	SpiritWarmth.warm(p, 20.0)
	assert_int(p.react_kind).is_equal(Person.React.LIFT)
	assert_float(p.joy).is_equal_approx(30.0, 0.001)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_warm_gift_is_a_glow_on_the_person_in_both_looks_and_goes_when_it_ends() -> void:
	# Round 25: the warm disc under the person is gone; round 26: so are the trouble markers. The gift is the person's
	# own warm reaction (a glow and a hop), which runs for SPARE_GLOW_SECONDS.
	for styled: bool in [false, true]:
		Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
		var s: Dictionary = await _start()
		var td: TopDownMain = s["td"]
		var p: Person = td.people[0]
		p.is_rescued = true
		p.joy = 10.0
		SpiritWarmth.warm(p, 20.0)
		assert_int(p.react_kind).is_equal(Person.React.WARM)
		p.tick(SpiritConfig.SPARE_GLOW_SECONDS * 0.5)
		assert_int(p.react_kind).is_equal(Person.React.WARM)
		p.tick(SpiritConfig.SPARE_GLOW_SECONDS)
		assert_int(p.react_kind).is_equal(Person.React.NONE)
		await TopDownTestUtil.leave_loaded_scene(td)


func test_spare_spirit_from_rescues_at_full_spirit_warms_a_strained_border_in_the_level() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _ring(td, runner, 24, 0.7)
	# Loop tuning (#93): a gate now asks for fewer people, so the 24-person ring has fewer members; the most strained
	# one is a member (people[5] may now stand inside the line).
	var weakest: Person = td.border.members[0]
	weakest.joy = weakest.joy_needed() * 0.4
	td.player.spirit = SpiritConfig.SPIRIT_MAX
	td.spirit_warmth.pool = 0.0  # the rescues that built the ring spilled some already
	var before := weakest.joy
	td.player.add_spirit(SpiritConfig.SPIRIT_PER_RESCUE)  # as a rescue would, with the meter full
	assert_float(td.spirit_warmth.pool).is_equal_approx(SpiritConfig.SPIRIT_PER_RESCUE, 0.001)
	await runner.simulate_frames(60 * 4)
	assert_bool(td.border.members.has(weakest)).is_true()
	assert_float(weakest.joy).is_greater(before + 100.0)
	assert_float(td.spirit_warmth.pool).is_less(SpiritConfig.SPIRIT_PER_RESCUE)
	# It is the most strained that got it, not everyone: most of the ring is untouched.
	var touched := 0
	for i: int in range(24):
		if td.people[i].joy > td.people[i].joy_needed() * 0.7 + 1.0:
			touched += 1
	assert_int(touched).is_less_equal(6)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_recorder_notes_each_gift() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var p := _member(td, 0, 0.3)
	td.spirit_warmth.add_spare(10.0)
	td.spirit_warmth.pour()
	td.recorder._flush()
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	assert_object(file).is_not_null()
	var found: Array[Dictionary] = []
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary and (parsed as Dictionary)["type"] == "spirit_warm":
			found.append(parsed)
	assert_int(found.size()).is_equal(1)
	assert_float(found[0]["joy"]).is_equal_approx(SpiritConfig.SPARE_WARM_RATE * SpiritConfig.SPARE_WARM_INTERVAL, 0.1)
	assert_float(found[0]["id"]).is_equal(float(td.people.find(p)))
	assert_float(found[0]["amount"]).is_greater(0.0)
	assert_float(found[0]["pool"]).is_less(10.0)
	await TopDownTestUtil.leave_loaded_scene(td)
