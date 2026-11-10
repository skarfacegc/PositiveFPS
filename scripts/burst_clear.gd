class_name BurstClear
extends RefCounted

# Round 22: the joy burst's job is to clear dimmed people. Round 24: everyone dimmed within BURST_LIFT_RADIUS of the
# player is lifted to the gloomy band, calm for BURST_CALM_SECONDS (no gloom gain); those within BURST_BORDER_BAND of
# the border line (pressing it from outside, or inside through a gap) are also pushed BURST_PUSH_DISTANCE away from it.
# Everyone else in range gets the usual best-match joy hit (rescued people out to BURST_CLEAR_RADIUS, which tops up
# strained border members and saves wobbling ones; others out to TD_BURST_RADIUS). Pure rules: the player calls `run`.


# True when `p` is a dimmed person the burst would lift from `at`: dimmed, and within BURST_LIFT_RADIUS of `at`. (The
# border argument is kept so older callers still compile; it no longer matters.)
static func is_target(p: Person, at: Vector3, _border: Border = null) -> bool:
	if p.is_rescued or not GloomSim.is_dimmed(p):
		return false
	return GloomSim.flat_dist(at, p.global_position) <= SpiritConfig.BURST_LIFT_RADIUS


# True when a lifted person at `pos` is also close enough to the border line to be pushed back from it.
static func is_at_border(border: Border, pos: Vector3) -> bool:
	return border != null and border.active and distance_to_line(border, pos) <= SpiritConfig.BURST_BORDER_BAND


# The distance from `pos` to the border line, metres.
static func distance_to_line(border: Border, pos: Vector3) -> float:
	var near: Dictionary = border._nearest_on_loop(Vector2(pos.x, pos.z))
	return near["dist"]


# How many dimmed people a burst from `at` would clear right now (the HUD shows it).
static func count_targets(people: Array[Person], at: Vector3, _border: Border = null) -> int:
	var n := 0
	for p: Person in people:
		if is_target(p, at):
			n += 1
	return n


# Uses the burst at `at`. Returns a report: {"cleared": Array of {"person", "from", "to"} (position before and after),
# "lifted": int, "joy_hits": int}.
static func run(people: Array[Person], at: Vector3, border: Border) -> Dictionary:
	var cleared: Array[Dictionary] = []
	var hits := 0
	for p: Person in people:
		if is_target(p, at):
			var from := p.global_position
			var to := _pushed(border, from) if is_at_border(border, from) else from
			p.global_position = to
			p.gloom = minf(p.gloom, SpiritConfig.BURST_LIFT_GLOOM)
			p.joy = 0.0
			p.calm_left = SpiritConfig.BURST_CALM_SECONDS
			cleared.append({"person": p, "from": from, "to": to})
			continue
		var reach := SpiritConfig.BURST_CLEAR_RADIUS if p.is_rescued else SpiritConfig.TD_BURST_RADIUS
		if GloomSim.flat_dist(at, p.global_position) <= reach:
			p.receive_joy(p.affinity, SpiritConfig.TD_BURST_JOY, 0.0, at)
			hits += 1
	if border != null:
		border.push.relieve(at)  # Round 26: the line near the burst springs back and is pushed less for a while.
	return {"cleared": cleared, "lifted": cleared.size(), "joy_hits": hits}


# Where a person at `from` ends up: out through the nearest gate (its outward normal), far enough to be outside the
# line by the push.
static func _pushed(border: Border, from: Vector3) -> Vector3:
	var way := border.out_at(from)
	var out := Vector3(way.x, 0.0, way.y)
	var dist := distance_to_line(border, from)
	var inside := Geometry2D.is_point_in_polygon(Vector2(from.x, from.z), border.polygon)
	var push := SpiritConfig.BURST_PUSH_DISTANCE + (dist if inside else 0.0)
	var to := from + out.normalized() * push
	var lim := BorderConfig.BORDER_MAP_LIMIT
	return Vector3(clampf(to.x, -lim, lim), from.y, clampf(to.z, -lim, lim))
