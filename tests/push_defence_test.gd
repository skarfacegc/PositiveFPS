extends GdUnitTestSuite

# Round 26 goal check, small scenarios; on gates since 0.4 (#56). 16 rescued people stand four to a gate on the start
# square, and two dimmed people lean on the east gate from outside at midnight: the gate bends and snaps, once. Joy at
# the pushers weakens them, joy at the broken ends and lifting the pushers mends it, and the pushers walk in through the
# break.

const RING := 16
const HORIZON_FRAMES := 2400


# The settled square at midnight, with two dimmed pushers outside the east member nearest the middle of the gate.
func _scenario() -> Dictionary:
	# Slowest tests (#88): only the ring and the two pushers are kept; the parked crowd costs a frame's work each.
	var s: Dictionary = await TopDownTestUtil.settled_level(self, RING, 600, RING + 2, true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.spirit_warmth.pool = 0.0
	# The player stands far off in the west street: a dimmed person within GRAB_NOTICE_RANGE of the player reaches for them
	# (and a grab ignores the line), and the east gate is only 6 m from the start.
	td.player.global_position = Vector3(-33.0, 0.0, 0.0)
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	# The member standing nearest the east gate's middle (6, 0): the street runs on that side, so no block is in the way.
	var target: Person = td.border.members[0]
	for cand: Person in td.border.members:
		if cand.position.distance_to(Vector3(6, 0, 0)) < target.position.distance_to(Vector3(6, 0, 0)):
			target = cand
	var out := Vector3(1.0, 0.0, 0.0)
	var side := Vector3(0.0, 0.0, 1.0)
	TopDownTestUtil.place(td.people[RING], target.position + out * 1.2, 1, 0.95)
	TopDownTestUtil.place(td.people[RING + 1], target.position + out * 1.2 + side * 0.6, 2, 0.95)
	for k: int in [RING, RING + 1]:
		td.people[k].level = 2  # Both dimmed at once, so they lean together (the midnight stagger would space them).
	return {"runner": runner, "td": td, "target": target, "out": out}


# Runs frames until `done` is true or the horizon passes; returns the frames it took (or -1).
func _until(s: Dictionary, done: Callable) -> int:
	var runner: GdUnitSceneRunner = s["runner"]
	for frame: int in range(HORIZON_FRAMES):
		if done.call():
			return frame
		await runner.simulate_frames(1)
	return -1


func test_two_pushers_bend_the_gate_and_snap_it_once_in_a_reasonable_time() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	assert_int(border.gap_count()).is_equal(0)
	var bent: Callable = func() -> bool: return border.push.deepest > PushConfig.PUSH_BREAK_DEPTH * 0.3
	var frames_bent: int = await _until(s, bent)
	assert_int(frames_bent).is_greater_equal(0)
	assert_int(border.gap_count()).is_equal(0)  # It bends before it breaks.
	var broke: Callable = func() -> bool: return border.gap_region_count() > 0
	var frames_broke: int = await _until(s, broke)
	assert_int(frames_broke).is_greater_equal(0)
	assert_int(frames_bent + frames_broke).is_less(1500)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_int(border.gap_region_count()).is_equal(1)
	assert_int(border.segment_gap.count(true)).is_between(1, 5)
	assert_int(td.rescued_count).is_greater(8)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_pushers_weakened_by_joy_do_not_break_the_gate() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var border: Border = td.border
	var held := true
	for frame: int in range(1200):
		for k: int in [RING, RING + 1]:
			td.people[k].push_mult = PushConfig.PUSH_WEAKEN_MIN  # What steady joy at them keeps them at.
		await runner.simulate_frames(1)
		if not border.push.breaks.is_empty():
			held = false
	assert_bool(held).is_true()
	assert_float(border.push.deepest).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pushers_walk_in_through_the_break_and_not_through_the_gate() -> void:
	var s: Dictionary = await _scenario()
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var out: Vector3 = s["out"]
	var broke: Callable = func() -> bool: return border.gap_region_count() > 0
	assert_int(await _until(s, broke)).is_greater_equal(0)
	var mid: Vector3 = border.gap_midpoints()[0]
	assert_bool(border.line_blocks(mid + out * 3.0, mid - out * 3.0)).is_false()
	# Elsewhere on the line (the west gate) the same move is still stopped.
	var back: Person = border.members[0]
	for m: Person in border.members:
		if m.position.x < back.position.x:
			back = m
	var back_out := border.out_at(back.position)
	var way := Vector3(back_out.x, 0.0, back_out.y)
	assert_bool(border.line_blocks(back.position + way * 3.0, back.position - way * 3.0)).is_true()
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
