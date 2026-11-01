extends GdUnitTestSuite

# Round 22 goal check. The seeded scenario (20 rescued people on a ring, two dimmed people pressing one member from
# outside at midnight) always ends the same way when the player does nothing: the member is drained, falters, and a gap
# opens. With a timely patch (F) or burst (G) the same run does not open that gap in the same time, and the warning
# fires before the gap does. The game is still losable: a patch runs out, and the pressers are still there afterwards.

const RING := 20
const RADIUS := 7.0
const HORIZON_FRAMES := 3000

# The unhelped run, measured once per process: {"gap": frame of the first gap, "warn": frame of the first ring,
# "strain": frame of the first joy-based warning (urgency over 0.3)}.
static var _control: Dictionary = {}


# Builds the scenario, ready for frame 0 of the pressure (pressers placed).
func _scenario() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	for i: int in range(RING):
		var a := TAU * float(i) / float(RING)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * RADIUS, 0.0, sin(a) * RADIUS), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	var target: Person = td.border.members[7]
	var out := Vector3(target.position.x - td.border.centre.x, 0.0, target.position.z - td.border.centre.z).normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	TopDownTestUtil.place(td.people[20], target.position + out * 1.2, 1, 0.95)
	TopDownTestUtil.place(td.people[21], target.position + out * 1.2 + side * 0.6, 2, 0.95)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td, "target": target, "out": out}


# Runs frames until `done` is true or the horizon passes; returns the frame it became true (or -1).
func _until(s: Dictionary, done: Callable, from_frame: int = 0) -> int:
	var runner: GdUnitSceneRunner = s["runner"]
	var frame := from_frame
	while frame < HORIZON_FRAMES:
		if done.call():
			return frame
		await runner.simulate_frames(1)
		frame += 1
	return -1


# The control: no help. Measured once.
func _measure_control() -> Dictionary:
	if not _control.is_empty():
		return _control
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var result := {"gap": -1, "warn": -1, "strain": -1}
	for frame: int in range(HORIZON_FRAMES):
		if result["warn"] < 0 and not td.gap_patch.warnings.is_empty():
			result["warn"] = frame
		if result["strain"] < 0 and _strained(td) != null:
			result["strain"] = frame
		if td.border.gap_count() > 0:
			result["gap"] = frame
			break
		await runner.simulate_frames(1)
	_control = result
	await TopDownTestUtil.leave_loaded_scene(td)
	return result


# A border member with a joy-based warning over 0.3 (the strain a patch can answer), or null.
func _strained(td: TopDownMain) -> Person:
	for w: Dictionary in td.gap_patch.warnings:
		var m: Person = w["person"]
		if BorderWarning.joy_urgency(m) > 0.3:
			return m
	return null


func test_without_help_the_pressed_member_falters_and_the_warning_fires_first() -> void:
	var c: Dictionary = await _measure_control()
	var gap: int = c["gap"]
	var warn: int = c["warn"]
	var strain: int = c["strain"]
	assert_int(gap).is_greater(0)
	# A ring was on screen from the first moment a dimmed person pressed a member, and a joy-based warning (the member
	# really draining) showed well before the gap opened: at least two seconds of notice.
	assert_int(warn).is_greater_equal(0)
	assert_int(warn).is_less(gap)
	assert_int(strain).is_greater_equal(0)
	assert_int(strain).is_less(gap - 120)


func test_a_timely_patch_holds_the_gap_shut_while_it_lasts() -> void:
	var c: Dictionary = await _measure_control()
	var gap: int = c["gap"]
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var strained: Callable = func() -> bool: return _strained(td) != null
	var frame: int = await _until(s, strained)
	assert_int(frame).is_greater_equal(0)
	var member := _strained(td)
	assert_int(frame).is_less(gap)
	# Real input: aim at the strained member and press F.
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, member.position))
	await runner.simulate_frames(3)
	frame += 3
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(2)
	frame += 2
	assert_int(td.gap_patch.patches.size()).is_equal(1)
	var patched_at := frame
	# Past the frame where the unhelped run opened its gap, and a good way on: still no gap, nobody lost.
	var rescued := td.rescued_count
	var horizon := maxi(gap + 300, patched_at + 600)
	while frame < mini(horizon, patched_at + int(Config.PATCH_SECONDS * 60.0) - 30):
		await runner.simulate_frames(1)
		frame += 1
		assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.rescued_count).is_equal(rescued)
	assert_float(member.patch_mult).is_equal(Config.PATCH_DRAIN_MULT)
	# It is a pause, not a cure: the pressers are still there, so once the patch runs out the border gives way again.
	var gave_way: Callable = func() -> bool: return td.border.gap_count() > 0 or td.rescued_count < rescued
	var later: int = await _until(s, gave_way, frame)
	assert_int(later).is_greater(patched_at + int(Config.PATCH_SECONDS * 60.0) - 60)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_timely_burst_clears_the_pressers_and_delays_the_gap() -> void:
	var c: Dictionary = await _measure_control()
	var gap: int = c["gap"]
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var target: Person = s["target"]
	var out: Vector3 = s["out"]
	var strained: Callable = func() -> bool: return _strained(td) != null
	var frame: int = await _until(s, strained)
	assert_int(frame).is_greater_equal(0)
	assert_int(frame).is_less(gap)
	# The player steps up to the border and bursts.
	td.player.global_position = target.position - out * 2.0
	await runner.simulate_frames(8)
	frame += 8
	var dimmed_before := 0
	for p: Person in td.people:
		if GloomSim.is_dimmed(p):
			dimmed_before += 1
	assert_int(dimmed_before).is_greater(0)
	assert_int(td.gap_patch.burst_targets).is_greater(0)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	frame += 3
	for p: Person in td.people:
		if not p.is_rescued:
			assert_bool(GloomSim.is_dimmed(p)).is_false()
	# Past the frame the unhelped run opened a gap, plus ten seconds: the border holds.
	var rescued := td.rescued_count
	while frame < gap + 3000:
		await runner.simulate_frames(1)
		frame += 1
		if td.border.gap_count() > 0:
			break
	assert_int(td.rescued_count).is_equal(rescued)
	await TopDownTestUtil.leave_loaded_scene(td)
