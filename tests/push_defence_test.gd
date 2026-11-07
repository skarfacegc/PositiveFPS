extends GdUnitTestSuite

# Round 26 goal check, small scenarios (replaces the round 22 patch scenarios). 20 rescued people on a ring, two dimmed
# people leaning on one member from outside at midnight: the line bends there and snaps, once. Joy at the pushers
# weakens them, joy at the broken ends and lifting the pushers mends it, and the pushers walk in through the break.

const RING := 20
const RADIUS := 7.0
const HORIZON_FRAMES := 2400


# Builds the ring at midnight and puts two dimmed pushers outside member 7.
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
	td.spirit_warmth.pool = 0.0
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	var target: Person = td.border.members[7]
	var out := Vector3(target.position.x - td.border.centre.x, 0.0, target.position.z - td.border.centre.z).normalized()
	var side := Vector3(-out.z, 0.0, out.x)
	TopDownTestUtil.place(td.people[20], target.position + out * 1.2, 1, 0.95)
	TopDownTestUtil.place(td.people[21], target.position + out * 1.2 + side * 0.6, 2, 0.95)
	return {"runner": runner, "td": td, "target": target, "out": out}


# Runs frames until `done` is true or the horizon passes; returns the frames it took (or -1).
func _until(s: Dictionary, done: Callable) -> int:
	var runner: GdUnitSceneRunner = s["runner"]
	for frame: int in range(HORIZON_FRAMES):
		if done.call():
			return frame
		await runner.simulate_frames(1)
	return -1


func test_two_pushers_bend_the_line_and_snap_it_once_in_a_reasonable_time() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	assert_int(border.gap_count()).is_equal(0)
	var bent: Callable = func() -> bool: return border.push.deepest > Config.PUSH_BREAK_DEPTH * 0.3
	var frames_bent: int = await _until(s, bent)
	assert_int(frames_bent).is_greater_equal(0)
	assert_int(border.gap_count()).is_equal(0)  # It bends before it breaks.
	var broke: Callable = func() -> bool: return border.gap_region_count() > 0
	var frames_broke: int = await _until(s, broke)
	assert_int(frames_broke).is_greater_equal(0)
	assert_int(frames_bent + frames_broke).is_less(1500)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_int(border.gap_region_count()).is_equal(1)
	assert_int(border.gap_count()).is_between(1, 4)
	assert_int(border.gap_count()).is_less(border.segment_gap.size() / 2)
	assert_int(td.rescued_count).is_greater(RING / 2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_pushers_weakened_by_joy_do_not_break_the_line() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var border: Border = td.border
	var held := true
	for frame: int in range(1200):
		for k: int in [20, 21]:
			td.people[k].push_mult = Config.PUSH_WEAKEN_MIN  # What steady joy at them keeps them at.
		await runner.simulate_frames(1)
		if not border.push.breaks.is_empty():
			held = false
	assert_bool(held).is_true()
	assert_float(border.push.deepest).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pushers_walk_in_through_the_break_and_not_through_the_line() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var target: Person = s["target"]
	var out: Vector3 = s["out"]
	var broke: Callable = func() -> bool: return border.gap_region_count() > 0
	assert_int(await _until(s, broke)).is_greater_equal(0)
	var mid: Vector3 = border.gap_midpoints()[0]
	var outside := mid + out * 3.0
	var inside := mid - out * 3.0
	assert_bool(border.line_blocks(outside, inside)).is_false()
	# Elsewhere on the loop the same move is still stopped.
	var back: Person = border.members[0]
	for m: Person in border.members:
		if GloomSim.flat_dist(m.position, target.position) > GloomSim.flat_dist(back.position, target.position):
			back = m
	var back_out := Vector3(back.position.x - border.centre.x, 0.0, back.position.z - border.centre.z).normalized()
	assert_bool(border.line_blocks(back.position + back_out * 3.0, back.position - back_out * 3.0)).is_true()
	assert_object(target).is_not_null()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_lifting_the_pushers_and_joy_at_the_ends_mends_the_break() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var border: Border = td.border
	var broke: Callable = func() -> bool: return border.gap_region_count() > 0
	assert_int(await _until(s, broke)).is_greater_equal(0)
	# The member standing nearest the break is its end.
	var spot: Vector3 = border.push.break_points()[0]
	var target: Person = border.members[0]
	for m: Person in border.members:
		if GloomSim.flat_dist(m.position, spot) < GloomSim.flat_dist(target.position, spot):
			target = m
	# Joy at the broken end alone is not enough while the pushers are still there.
	target.receive_joy(target.affinity, 50.0, 0.0)
	await runner.simulate_frames(30)
	assert_int(border.push.breaks.size()).is_equal(1)
	# Lift them away (a burst's job) and give the end another hit: the break mends and the gap is gone.
	# (Anyone who relapsed meanwhile is lifted too.)
	for p: Person in td.people:
		if not p.is_rescued:
			TopDownTestUtil.place(p, TopDownTestUtil.FAR, p.affinity, 0.2)
	await runner.simulate_frames(30)
	assert_int(border.push.breaks.size()).is_equal(0)
	assert_int(border.gap_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
