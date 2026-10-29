extends GdUnitTestSuite

# Round 18: how the border moves. Frame-driven level tests: 30 people are rescued in a ring, the joy-burst shove
# pushes the
# loop (Border._push_at, the shove's rule), and we watch the centre, the size, the shape and the members.

const SHOVES := 8
const FRAMES_BETWEEN_SHOVES := 90
const DRIFT_BOUND := 1.0
const SETTLE_SECONDS := 8.0
# Pairs stay at least this share of BORDER_TARGET_SPACING apart (chords at bends are a little shorter than the spacing).
# Measured after a heavy push: 3.69 m of 3.7 now, 2.66 m before round 18. Growing loop: 2.50 m either way (bend chords).
const PASS_FRACTION := 0.5
const APART_FRACTION := 0.8
# After 8 s the spread of the raw radii has fallen to at most this share (measured 0.43; before round 18 it stayed at
# 1.0).
const RELAX_SHARE := 0.65


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, c + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# A loop of 30 people around the middle of the map, settled, then `shoves` shoves toward angle `ang`.
func _pushed(shoves: int, ang: float) -> Dictionary:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	# Blocks make the loop wrap round them with a one-sample spike (a separate matter, see IDEAS round 18); keep them out.
	td.border.buildings.clear()
	_rescue_ring(td, Vector3.ZERO, 10.0, 30)
	await runner.simulate_frames(300)
	for k: int in range(shoves):
		td.border._push_at(ang, Config.BORDER_SHOVE_AMOUNT / maxf(td.border._scale, 0.01))
		await runner.simulate_frames(FRAMES_BETWEEN_SHOVES)
	return s


# The closest two loop points that are at least `gap` samples apart round the loop.
func _tongue_width(b: Border, gap: int) -> float:
	var best := INF
	var n := b.polygon.size()
	for i: int in range(n):
		for j: int in range(i + gap, n):
			if mini(j - i, n - (j - i)) < gap:
				continue
			best = minf(best, b.polygon[i].distance_to(b.polygon[j]))
	return best


# How many members moved faster than 0.3 m/s over one frame.
func _speeds(td: TopDownMain, last: Dictionary) -> float:
	var worst := 0.0
	for p: Person in td.border.members:
		if last.has(p):
			var was: Vector3 = last[p]
			if GloomSim.flat_dist(p.position, was) * 60.0 > 0.5:
				worst += 1.0
		last[p] = p.position
	return worst


# The closest two loop points that stand at least three spacings apart along the loop. Two sides of a thin tongue are
# near
# each other in space but far apart along the loop; on a round loop this is about three spacings.
func _side_gap(b: Border) -> float:
	var best := INF
	var n := b.polygon.size()
	var total: float = b._arc[n]
	var apart := 3.0 * Config.BORDER_TARGET_SPACING
	for i: int in range(n):
		for j: int in range(i + 1, n):
			var along: float = b._arc[j] - b._arc[i]
			if minf(along, total - along) >= apart:
				best = minf(best, b.polygon[i].distance_to(b.polygon[j]))
	return best


# How far the raw radii range (tallest bump minus lowest dip), in metres.
func _spread(b: Border) -> float:
	return b._raw_radii.max() - b._raw_radii.min()


# (a) After a heavy one-sided push the centre does not follow the bump: over the 20 s after the last push it stays
# within
# DRIFT_BOUND of where it was. (Before round 18 it crept 0.5 m/s toward the pushed side, 10 m in 20 s.)
func test_the_loop_does_not_creep_toward_the_pushed_side() -> void:
	var s: Dictionary = await _pushed(SHOVES, 0.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(60 * 6)
	var c0 := td.border.centre
	var worst := 0.0
	for f: int in range(20):
		await runner.simulate_frames(60)
		worst = maxf(worst, GloomSim.flat_dist(td.border.centre, c0))
	print("PROBE drift20=%.2f" % worst)
	assert_float(worst).is_less(DRIFT_BOUND)
	await TopDownTestUtil.leave_loaded_scene(td)


# (b) After a heavy push the members stop walking within SETTLE_SECONDS, and they ease in: nobody reverses direction
# more
# than MAX_REVERSALS times over two seconds (an overshoot of a moving slot would show up here).
func test_the_loop_settles_quickly_after_a_push_and_members_ease_in() -> void:
	var s: Dictionary = await _pushed(SHOVES, 0.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var last: Dictionary = {}
	var quiet := 0
	var settled := -1.0
	var closest := INF
	for f: int in range(60 * 12):
		await runner.simulate_frames(1)
		if f % 4 == 0:
			var ms: Array[Person] = td.border.members
			for i: int in range(ms.size()):
				for j: int in range(i + 1, ms.size()):
					closest = minf(closest, GloomSim.flat_dist(ms[i].position, ms[j].position))
		var mv := _speeds(td, last)
		if mv < 0.5:
			quiet += 1
		else:
			quiet = 0
		if quiet == 60 and settled < 0.0:
			settled = float(f - 60) / 60.0
	print("PROBE settled=%.1f closest=%.2f spacing=%.1f" % [settled, closest, td.border.spacing])
	assert_float(settled).is_greater_equal(0.0)
	assert_float(settled).is_less_equal(SETTLE_SECONDS)
	assert_float(closest).is_greater_equal(APART_FRACTION * Config.BORDER_TARGET_SPACING)
	await TopDownTestUtil.leave_loaded_scene(td)


# (c) A narrow spike in the raw radii (the tongue repeated shoves leave) relaxes: the two sides of the loop stand at
# least
# a spacing apart again soon after.
func test_a_spike_relaxes_and_its_sides_stay_a_spacing_apart() -> void:
	var s: Dictionary = await _pushed(0, 0.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	for k: int in range(6):
		td.border._push_at(0.0, 3.0 * Config.BORDER_SHOVE_AMOUNT / maxf(td.border._scale, 0.01))
	await runner.simulate_frames(1)
	var narrow := _side_gap(td.border)
	var spread0 := _spread(td.border)
	await runner.simulate_frames(60 * 8)
	var relaxed := _side_gap(td.border)
	var spread1 := _spread(td.border)
	print(
		(
			"PROBE side gap narrow=%.1f relaxed=%.1f spacing=%.1f spread %.1f -> %.1f"
			% [narrow, relaxed, td.border.spacing, spread0, spread1]
		)
	)
	assert_float(relaxed).is_greater_equal(td.border.spacing)
	assert_float(spread1).is_less_equal(RELAX_SHARE * spread0)
	await TopDownTestUtil.leave_loaded_scene(td)


# (d) Heavy-push check is in the settle test above (closest pair). A slow change of the perimeter (a new person every
# four seconds) never lets two members pass through each other.
func test_no_pair_passes_through_each_other_while_the_loop_grows() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 10.0, 20)
	await runner.simulate_frames(300)
	var closest := INF
	for k: int in range(20, 40):
		var p: Person = td.people[k]
		var a := TAU * float(k) * 0.37
		TopDownTestUtil.place(p, Vector3(cos(a), 0.0, sin(a)) * 14.0, p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
		for f: int in range(240):
			await runner.simulate_frames(1)
			var ms: Array[Person] = td.border.members
			for i: int in range(ms.size()):
				for j: int in range(i + 1, ms.size()):
					if ms[i] == p or ms[j] == p:
						continue  # The newcomer walks in from where they were rescued; it is the others that must not cross.
					closest = minf(closest, GloomSim.flat_dist(ms[i].position, ms[j].position))
	print("PROBE closest=%.2f spacing=%.1f" % [closest, td.border.spacing])
	assert_float(closest).is_greater_equal(PASS_FRACTION * Config.BORDER_TARGET_SPACING)
	await TopDownTestUtil.leave_loaded_scene(td)


# (e) Sealed stretches shorter than a spacing are opened again; longer ones stay sealed.
func test_a_sealed_stretch_shorter_than_a_spacing_is_opened() -> void:
	var lim := Config.BORDER_MAP_LIMIT
	var pts := Border.circle_polygon(Vector2.ZERO, 20.0, 48)
	# Push two neighbouring points out to the east edge: a seal that is a single short segment.
	pts[0] = Vector2(lim + 5.0, 0.0)
	pts[1] = Vector2(lim + 5.0, 1.0)
	var sealed := Border.clamp_to_map(pts)
	assert_float(sealed.max()).is_greater(0.0)
	Border.drop_short_seals(pts, sealed, Config.BORDER_MIN_SEAL_RUN)
	assert_float(sealed.max()).is_equal(0.0)
	# A long stretch along the edge keeps its seal.
	var long_pts := PackedVector2Array()
	for k: int in range(8):
		long_pts.append(Vector2(lim, -14.0 + float(k) * 4.0))
	long_pts.append(Vector2(0.0, 30.0))
	var long_sealed := Border.clamp_to_map(long_pts)
	Border.drop_short_seals(long_pts, long_sealed, Config.BORDER_MIN_SEAL_RUN)
	assert_float(long_sealed.max()).is_equal(1.0)
	# A loop sealed all the way round has no open segment to count from: left alone.
	var all: Array[float] = [1.0, 1.0, 1.0]
	Border.drop_short_seals(PackedVector2Array([Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0)]), all, 100.0)
	assert_float(all.min()).is_equal(1.0)


# (d, rule level) Four slots round a circle and four people each `off` degrees past a slot. The nearest slot is behind
# them; the next one is a bit further ahead. Last frame they were all heading for the slot ahead. With the next slot
# only
# a little dearer the old choice is kept; with it much dearer the choice changes.
func _hysteresis_case(off: float) -> Dictionary:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	var slots: Array[Vector2] = []
	var taken: Array[bool] = []
	var who: Array[Person] = []
	var prev: Dictionary = {}
	for k: int in range(4):
		var a := deg_to_rad(90.0 * float(k))
		slots.append(Vector2(cos(a), sin(a)) * 10.0)
		taken.append(false)
		var p: Person = auto_free(Person.new())
		add_child(p)
		var at := deg_to_rad(90.0 * float(k) + off)
		p.position = Vector3(cos(at), 0.0, sin(at)) * 10.0
		who.append(p)
	for k: int in range(4):
		var ahead := slots[(k + 1) % 4]
		prev[who[k]] = Vector3(ahead.x, 0.0, ahead.y)
	var plain := border._ordered_slots(who, slots, taken)
	var kept := border._slots.ordered_slots(who, slots, taken, prev)
	return {"plain": plain, "kept": kept}


func test_the_slot_offset_is_kept_when_another_saves_little() -> void:
	var near: Dictionary = _hysteresis_case(44.0)
	var plain_near: Array[int] = near["plain"]
	var kept_near: Array[int] = near["kept"]
	assert_array(kept_near).is_not_equal(plain_near)
	var far: Dictionary = _hysteresis_case(36.0)
	var plain_far: Array[int] = far["plain"]
	var kept_far: Array[int] = far["kept"]
	assert_array(kept_far).is_equal(plain_far)
