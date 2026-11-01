class_name BurstClear
extends RefCounted

# Round 22: the joy burst's job is to clear dimmed people off the border. Everyone within BURST_CLEAR_RADIUS of the
# player who is dimmed and within BURST_BORDER_BAND of the border line (pressing it from outside, or inside through a
# gap) is pushed BURST_PUSH_DISTANCE away from the border and lifted to the gloomy band, calm for BURST_CALM_SECONDS
# (no gloom gain). Everyone else in range gets the usual best-match joy hit (rescued people out to BURST_CLEAR_RADIUS,
# which tops up strained border members; others out to TD_BURST_RADIUS). Pure rules: the player calls `run`.


# True when `p` is a dimmed person the burst would clear from `at`: in range, and close to the border line.
static func is_target(p: Person, at: Vector3, border: Border) -> bool:
	if p.is_rescued or not GloomSim.is_dimmed(p):
		return false
	if GloomSim.flat_dist(at, p.global_position) > Config.BURST_CLEAR_RADIUS:
		return false
	return border != null and border.active and distance_to_line(border, p.global_position) <= Config.BURST_BORDER_BAND


# The distance from `pos` to the border line, metres.
static func distance_to_line(border: Border, pos: Vector3) -> float:
	var near: Dictionary = border._nearest_on_loop(Vector2(pos.x, pos.z))
	return near["dist"]


# How many dimmed people a burst from `at` would clear right now (the HUD shows it).
static func count_targets(people: Array[Person], at: Vector3, border: Border) -> int:
	var n := 0
	for p: Person in people:
		if is_target(p, at, border):
			n += 1
	return n


# Uses the burst at `at`. Returns a report: {"cleared": Array of {"person", "from", "to"} (position before and after),
# "lifted": int, "joy_hits": int}.
static func run(people: Array[Person], at: Vector3, border: Border) -> Dictionary:
	var cleared: Array[Dictionary] = []
	var hits := 0
	for p: Person in people:
		if is_target(p, at, border):
			var from := p.global_position
			var to := _pushed(border, from)
			p.global_position = to
			p.gloom = minf(p.gloom, Config.BURST_LIFT_GLOOM)
			p.joy = 0.0
			p.calm_left = Config.BURST_CALM_SECONDS
			cleared.append({"person": p, "from": from, "to": to})
			continue
		var reach := Config.BURST_CLEAR_RADIUS if p.is_rescued else Config.TD_BURST_RADIUS
		if GloomSim.flat_dist(at, p.global_position) <= reach:
			p.receive_joy(p.affinity, Config.TD_BURST_JOY, 0.0, at)
			hits += 1
	return {"cleared": cleared, "lifted": cleared.size(), "joy_hits": hits}


# Where a person at `from` ends up: away from the border's centre, far enough to be outside the line by the push.
static func _pushed(border: Border, from: Vector3) -> Vector3:
	var out := Vector3(from.x - border.centre.x, 0.0, from.z - border.centre.z)
	if out.length() < 0.01:
		out = Vector3.RIGHT
	var dist := distance_to_line(border, from)
	var inside := Geometry2D.is_point_in_polygon(Vector2(from.x, from.z), border.polygon)
	var push := Config.BURST_PUSH_DISTANCE + (dist if inside else 0.0)
	var to := from + out.normalized() * push
	var lim := Config.BORDER_MAP_LIMIT
	return Vector3(clampf(to.x, -lim, lim), from.y, clampf(to.z, -lim, lim))
