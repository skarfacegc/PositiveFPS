extends GdUnitTestSuite

# Walls and gates: Pressure (#12, #13, #14), the balance check. Real level runs with set-up people (bot nights do not
# exist yet): nobody dimmed anywhere (the unrescued are parked and kept calm), so the night's one surge is the only
# push. A compact zone (the start square and one cell, fully staffed) must keep every cell through the surge; an
# over-reached zone (five or more cells, far short of people) must lose at least one. If either fails at the plan's
# defaults, the numbers go in the report: nothing here is tuned to pass.

const SETTLE_FRAMES := 480
const COMPACT_CELLS: Array[Vector2i] = [Vector2i(3, 2)]
const WIDE_CELLS: Array[Vector2i] = [Vector2i(3, 2), Vector2i(4, 2), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 3)]
const WIDE_PEOPLE := 12


func before_test() -> void:
	Config.tides_override = 1  # The surge runs in the game and not under automated tests unless a test turns it on.


func after_test() -> void:
	Config.tides_override = -1


# The level with `cells` taken beyond the start square and `count` people rescued on the start square (all walking to
# their places on the gates), everyone else parked far away and kept calm. Returns {"runner", "td", "need"}.
func _scenario(cells: Array[Vector2i], count: int) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3(-33.0, 0.0, 0.0)  # Far from the action: a dimmed person near the player grabs.
	td.spirit_warmth.pool = 0.0
	for c: Vector2i in cells:
		td.border.zone.take(c)
	var need := td.border.zone.members_needed()
	var rescue_count := need if count < 0 else count
	assert_int(td.people.size()).is_greater_equal(rescue_count)
	for i: int in range(rescue_count):
		var a := TAU * float(i) / float(maxi(rescue_count, 1))
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = 5.0
	for frame: int in range(SETTLE_FRAMES):
		_keep_calm(td)
		await runner.simulate_frames(1)
	return {"runner": runner, "td": td, "need": need}


# Nobody outside the line sinks: the surge must be the only thing that pushes.
func _keep_calm(td: TopDownMain) -> void:
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0


# Plays the surge from its warning to the end of its push (or until `stop` says so) and returns what happened:
# {"frames", "held_min", "lost" (cells lost), "deepest", "broken_most" (longest a gate stayed broken), "breaks"}.
func _play(s: Dictionary, stop: Callable = Callable()) -> Dictionary:
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var start: float = td.gloom_tide.surge["start"]
	var frames := 0
	var held_min := td.border.zone.held.size()
	var deepest := 0.0
	var broken_most := 0.0
	var breaks := 0
	var lost_cells: Array[Vector2i] = []
	td.border.cells_lost.connect(func(cells: Array[Vector2i], _gate: int) -> void: lost_cells.append_array(cells))
	td.night.elapsed = start - NightConfig.SURGE_WARN_SECONDS - 0.5
	await runner.simulate_frames(3)  # The warning (and its street) is chosen here.
	td.night.elapsed = start - 1.0
	var horizon := int((NightConfig.SURGE_SECONDS + 4.0) * 60.0) + 120
	for frame: int in range(horizon):
		_keep_calm(td)
		await runner.simulate_frames(1)
		frames = frame + 1
		held_min = mini(held_min, td.border.zone.held.size())
		deepest = maxf(deepest, td.border.push.deepest)
		breaks = maxi(breaks, td.border.push.breaks.size())
		for g: int in range(td.border.zone.gates.size()):
			broken_most = maxf(broken_most, td.border.broken_seconds(g))
		if td.gloom_tide.phase() == GloomTide.Phase.AFTERMATH:
			break
		if stop.is_valid() and stop.call():
			break
	return {
		"frames": frames,
		"held_min": held_min,
		"lost": lost_cells.size(),
		"deepest": deepest,
		"broken_most": broken_most,
		"breaks": breaks
	}


func _report(label: String, s: Dictionary, stats: Dictionary) -> String:
	var td: TopDownMain = s["td"]
	var surge: Dictionary = td.gloom_tide.surge
	var gate: int = surge.get("gate", -1)
	return (
		(
			"%s: street %s, gate %d, need %d, members %d, fill %.2f, break depth %.2f, deepest dent %.2f, "
			+ "breaks %d, longest broken %.1f s, cells %d -> %d (%d lost), %d frames"
		)
		% [
			label,
			surge.get("street_name", "?"),
			gate,
			s["need"],
			td.border.member_count,
			td.border.gate_fill(gate),
			td.border.break_depth(gate),
			stats["deepest"],
			stats["breaks"],
			stats["broken_most"],
			1 + (COMPACT_CELLS.size() if label == "compact" else WIDE_CELLS.size()),
			stats["held_min"],
			stats["lost"],
			stats["frames"],
		]
	)


func test_a_compact_fully_staffed_zone_keeps_its_cells_through_the_surge() -> void:
	var s: Dictionary = await _scenario(COMPACT_CELLS, -1)
	var td: TopDownMain = s["td"]
	assert_int(td.border.member_count).is_equal(s["need"])  # Every gate has everyone it needs.
	var stats: Dictionary = await _play(s)
	print(_report("compact", s, stats))
	# Measured at the plan's defaults (2026-11-11): street south, need 23 of 23, break depth 2.40, deepest dent 2.23,
	# no break, cells 2 -> 2, 3061 frames.
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.AFTERMATH)  # The whole surge was played.
	assert_int(stats["held_min"]).is_equal(1 + COMPACT_CELLS.size())
	assert_int(stats["lost"]).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_an_over_reached_zone_short_of_people_loses_a_cell_during_the_surge() -> void:
	var s: Dictionary = await _scenario(WIDE_CELLS, WIDE_PEOPLE)
	var td: TopDownMain = s["td"]
	assert_int(td.border.zone.held.size()).is_greater_equal(5)
	assert_int(s["need"]).is_greater_equal(WIDE_PEOPLE * 3)  # Well short of people.
	var lost: Callable = func() -> bool: return td.border.zone.held.size() < 1 + WIDE_CELLS.size()
	var stats: Dictionary = await _play(s, lost)
	print(_report("wide", s, stats))
	# Measured at the plan's defaults (2026-11-11): street south, need 40 with 12 members (break depth 1.20), deepest
	# dent 2.23, one break open for 12.0 s, cells 6 -> 5, 1815 frames.
	assert_int(stats["lost"]).is_greater_equal(1)
	assert_int(td.border.zone.held.size()).is_less(1 + WIDE_CELLS.size())
	assert_bool(td.border.zone.has(TownGrid.start_cell())).is_true()  # The start square is never lost.
	await TopDownTestUtil.leave_loaded_scene(td)
