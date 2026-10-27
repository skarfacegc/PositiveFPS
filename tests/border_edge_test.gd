extends GdUnitTestSuite

# Round 16: the border near the map edge under heavy push. Before this round the loop could run off the map: its slots
# lay beyond the edge, members chased slots that were handed out by "nearest free slot" every frame, and they bunched
# into convoys (three or four people on one spot) with gaps elsewhere. Now the map edge seals the territory (the loop is
# clamped to the map and the stretch along the edge needs no members) and members keep their order around the loop.
# Frame-driven level tests: people are rescued directly (receive_joy), the push is the joy-burst shove the player makes.

const SHOVES := 14
const FRAMES_BETWEEN_SHOVES := 90
const SETTLE_FRAMES := 1800
# A pair nearer than this share of BORDER_TARGET_SPACING counts as bunched (chords at bends and a member walking past a
# neighbour are shorter than the spacing, so this is well under 1).
const CLUSTER_FRACTION := 0.5
# Bunched samples tolerated: a swap of two members passing each other takes under a second; 5% of the samples.
const MAX_CLOSE_SHARE := 0.05
const MAX_REVERSALS := 4


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


# The nearest-neighbour distance of the closest pair of border members.
func _min_pair(td: TopDownMain) -> float:
	var best := INF
	var ms: Array[Person] = td.border.members
	for i: int in range(ms.size()):
		for j: int in range(i + 1, ms.size()):
			best = minf(best, GloomSim.flat_dist(ms[i].position, ms[j].position))
	return best


func _off_map(td: TopDownMain) -> int:
	var n := 0
	var lim := Config.TD_PLAZA_SIZE / 2.0
	for p: Person in td.border.members:
		if absf(p.position.x) > lim or absf(p.position.z) > lim:
			n += 1
	return n


# Heavy push toward `ang` for SHOVES shoves, then SETTLE_FRAMES with no push. Returns the sampled facts:
#   close_samples: samples (every 10 frames, from 2 s after the last push) where the closest pair stood nearer than
#                  CLUSTER_FRACTION of the border spacing; samples: how many samples there were;
#   gap_samples: samples with any gap open; reversals: the most direction reversals any member made over the last
#   120 frames (a member shuffling to and fro, or the wall jittering, shows up here; a steady glide does not).
func _run(centre: Vector3, ang: float) -> Dictionary:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, centre, 10.0, 30)
	await runner.simulate_frames(300)
	for k: int in range(SHOVES):
		td.border._push_at(ang, Config.BORDER_SHOVE_AMOUNT / maxf(td.border._scale, 0.01))
		await runner.simulate_frames(FRAMES_BETWEEN_SHOVES)
	var close_samples := 0
	var gap_samples := 0
	var samples := 0
	for f: int in range(SETTLE_FRAMES / 10 - 12):
		await runner.simulate_frames(10)
		if f >= 12:  # Two seconds after the last push.
			samples += 1
			if _min_pair(td) < CLUSTER_FRACTION * Config.BORDER_TARGET_SPACING:
				close_samples += 1
			if td.border.gap_count() > 0:
				gap_samples += 1
	var last: Dictionary = {}
	var steps: Dictionary = {}
	var reversals: Dictionary = {}
	for f: int in range(120):
		await runner.simulate_frames(1)
		for p: Person in td.border.members:
			if last.has(p):
				var was: Vector3 = last[p]
				var step := Vector3(p.position.x - was.x, 0.0, p.position.z - was.z)
				if step.length() > 1.0e-4:
					if steps.has(p):
						var prev: Vector3 = steps[p]
						if prev.dot(step) < 0.0:
							var had: int = reversals.get(p, 0)
							reversals[p] = had + 1
					steps[p] = step
			last[p] = p.position
	var most := 0
	for p: Person in reversals:
		var cnt: int = reversals[p]
		most = maxi(most, cnt)
	return {"td": td, "close": close_samples, "samples": samples, "gap_samples": gap_samples, "reversals": most}


func _check(r: Dictionary) -> void:
	var samples: int = r["samples"]
	assert_int(r["close"]).is_less_equal(int(float(samples) * MAX_CLOSE_SHARE))
	assert_int(r["gap_samples"]).is_equal(0)
	assert_int(r["reversals"]).is_less_equal(MAX_REVERSALS)


func test_edge_push_keeps_members_spaced() -> void:
	var r: Dictionary = await _run(Vector3(32, 0, 0), 0.0)
	var td: TopDownMain = r["td"]
	assert_int(_off_map(td)).is_equal(0)
	_check(r)


func test_corner_push_keeps_members_spaced() -> void:
	var r: Dictionary = await _run(Vector3(32, 0, 32), PI / 4.0)
	var td: TopDownMain = r["td"]
	assert_int(_off_map(td)).is_equal(0)
	_check(r)


func test_mid_map_push_keeps_members_spaced() -> void:
	_check(await _run(Vector3(0, 0, 0), 0.0))


# --- Rule-level (scene-free) checks of the new pieces ---------------------------------------------------------


func _bare_border() -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	return border


func _person_at(pos: Vector3) -> Person:
	var p: Person = auto_free(Person.new())
	add_child(p)
	p.position = pos
	p.is_rescued = true
	p.joy = Config.JOY_MAX
	return p


func test_the_loop_is_pulled_onto_the_map_and_the_edge_stretch_is_sealed() -> void:
	var lim := Config.BORDER_MAP_LIMIT
	var pts := PackedVector2Array(
		[Vector2(lim + 20.0, -10.0), Vector2(lim + 30.0, 0.0), Vector2(lim + 25.0, 10.0), Vector2(0.0, 0.0)]
	)
	var sealed := Border.clamp_to_map(pts)
	for q: Vector2 in pts:
		assert_float(q.x).is_less_equal(lim)
	# The two segments between points beyond the east edge run along it; the others cross the map.
	assert_float(sealed[0]).is_equal(1.0)
	assert_float(sealed[1]).is_equal(1.0)
	assert_float(sealed[2]).is_equal(0.0)
	assert_float(sealed[3]).is_equal(0.0)
	assert_float(Border.open_perimeter_of(pts, sealed)).is_less(Border.perimeter_of(pts))
	# A loop well inside the map is not sealed anywhere.
	var inside := Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	var none := Border.clamp_to_map(inside)
	assert_float(none.max()).is_equal(0.0)


func test_a_sealed_stretch_takes_no_members_and_is_never_a_gap() -> void:
	var lim := Config.BORDER_MAP_LIMIT
	var border := _bare_border()
	var loop := Border.circle_polygon(Vector2(lim - 10.0, 0.0), 30.0, Config.BORDER_SAMPLES)
	border._sealed = Border.clamp_to_map(loop)
	border.polygon = loop
	border.active = true
	var full := Border.perimeter_of(loop)
	var rescued: Array[Person] = []
	for i: int in range(40):
		var a := TAU * float(i) / 40.0
		rescued.append(_person_at(Vector3(lim - 10.0 + cos(a) * 28.0, 0.0, sin(a) * 28.0)))
	border._assign_members(rescued)
	assert_float(border.perimeter).is_less(full - 5.0)
	assert_bool(border.is_sealed(border._sealed.find(1.0))).is_true()
	for j: int in range(loop.size()):
		if border.is_sealed(j):
			assert_bool(border.segment_is_gap(j)).is_false()
	# The slots are spaced evenly along the open length, none of them inside the sealed stretch.
	assert_float(border.spacing).is_equal_approx(border.perimeter / float(border.member_count), 0.01)
	for p: Person in border.members:
		var t: Vector3 = border._targets[p]
		assert_float(absf(t.x)).is_less_equal(lim + 0.001)


func test_members_keep_their_order_round_the_loop() -> void:
	var border := _bare_border()
	border.centre = Vector3.ZERO
	var slots: Array[Vector2] = []
	var taken: Array[bool] = []
	var who: Array[Person] = []
	for i: int in range(4):
		var a := TAU * float(i) / 4.0
		slots.append(Vector2(cos(a), sin(a)) * 10.0)
		taken.append(false)
	# People one place round from their nearest slots, in a shuffled list: the order round the loop is kept, so the
	# nearest-first crossing (two people swapping places) cannot happen.
	var spots: Array[float] = [3.0, 0.2, 4.4, 1.6]
	for a: float in spots:
		who.append(_person_at(Vector3(cos(a) * 9.0, 0.0, sin(a) * 9.0)))
	var chosen := border._ordered_slots(who, slots, taken)
	assert_int(chosen.size()).is_equal(4)
	var angle_order: Array[int] = [1, 3, 0, 2]
	for i: int in range(4):
		var next := angle_order[(i + 1) % 4]
		var here := angle_order[i]
		assert_int(posmod(chosen[next] - chosen[here], 4)).is_equal(1)
	# With a different number of free slots than people it declines (the caller then takes the nearest free slot).
	taken[0] = true
	assert_int(border._ordered_slots(who, slots, taken).size()).is_equal(0)


func test_the_nearest_free_slot_skips_taken_ones() -> void:
	var slots: Array[Vector2] = [Vector2(0, 0), Vector2(5, 0), Vector2(10, 0)]
	var taken: Array[bool] = [false, true, false]
	assert_int(Border.nearest_free_slot(Vector2(4, 0), slots, taken)).is_equal(0)
	taken[0] = true
	assert_int(Border.nearest_free_slot(Vector2(4, 0), slots, taken)).is_equal(2)
	taken[2] = true
	assert_int(Border.nearest_free_slot(Vector2(4, 0), slots, taken)).is_equal(-1)


func test_the_slot_grid_has_no_phase_when_the_members_cancel_out() -> void:
	# Two members half a spacing apart along the open length have opposite phases: no mean, so the grid stays at 0.
	var border := _bare_border()
	var loop := Border.circle_polygon(Vector2.ZERO, 20.0, Config.BORDER_SAMPLES)
	var seal: Array[float] = []
	for j: int in range(loop.size()):
		seal.append(0.0)
	seal[0] = 0.3
	border._sealed = seal
	border.polygon = loop
	border.active = true
	var rescued: Array[Person] = []
	for i: int in range(10):
		var a := TAU * float(i) / 10.0
		rescued.append(_person_at(Vector3(cos(a) * 20.0, 0.0, sin(a) * 20.0)))
	border._assign_members(rescued)
	var a1 := border._point_at_open(1.0)
	var a2 := border._point_at_open(1.0 + border.spacing / 2.0)
	var two: Array[Person] = [_person_at(Vector3(a1.x, 0.0, a1.y)), _person_at(Vector3(a2.x, 0.0, a2.y))]
	assert_float(border._grid_phase(two)).is_equal(0.0)
	assert_float(border._grid_phase([] as Array[Person])).is_equal(0.0)


func test_a_loop_with_no_open_length_or_no_arc_falls_back_to_its_first_point() -> void:
	var border := _bare_border()
	var loop := Border.circle_polygon(Vector2(5, 5), 20.0, Config.BORDER_SAMPLES)
	var seal: Array[float] = []
	for j: int in range(loop.size()):
		seal.append(1.0)
	border._sealed = seal
	border.polygon = loop
	border.active = true
	border._assign_members([_person_at(Vector3(5, 0, 5))] as Array[Person])
	assert_float(border.perimeter).is_equal(0.0)  # Nothing is open: the whole loop is the map edge.
	assert_vector(border._point_at_open(3.0)).is_equal(loop[0])
	assert_float(border._open_of_arc(1.0e9)).is_equal(0.0)
	var flat := _bare_border()
	flat.polygon = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	flat.active = true
	flat._assign_members([_person_at(Vector3.ZERO)] as Array[Person])
	assert_vector(flat._point_at_arc(1.0)).is_equal(Vector2.ZERO)


func test_nothing_presses_on_a_sealed_stretch() -> void:
	var lim := Config.BORDER_MAP_LIMIT
	var border := _bare_border()
	var loop := Border.circle_polygon(Vector2(lim - 10.0, 0.0), 30.0, Config.BORDER_SAMPLES)
	border._sealed = Border.clamp_to_map(loop)
	border.polygon = loop
	border.active = true
	var rescued: Array[Person] = []
	for i: int in range(40):
		var a := TAU * float(i) / 40.0
		rescued.append(_person_at(Vector3(lim - 10.0 + cos(a) * 28.0, 0.0, sin(a) * 28.0)))
	border._assign_members(rescued)
	var dark := _person_at(Vector3(lim + 0.5, 0.0, 0.0))
	dark.is_rescued = false
	dark.gloom = 1.0
	var joy_before: Array[float] = []
	for m: Person in border.members:
		joy_before.append(m.joy)
	border._press_darkness([dark] as Array[Person], 1.0, 1.0)
	assert_vector(dark.position).is_equal(Vector3(lim + 0.5, 0.0, 0.0))
	for i: int in range(border.members.size()):
		assert_float(border.members[i].joy).is_equal(joy_before[i])
