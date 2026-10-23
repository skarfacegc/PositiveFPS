class_name GloomSim
extends RefCounted

# Shared gloom rules, used by both first-person and top-down mode.
# Gloom: unrescued people darken over time (faster far from colour zones), heal inside a zone,
# and dark people spread darkness to neighbours (and drain joy from rescued ones).


# `drain_multiplier` scales how fast dark people drain rescued joy. First person leaves it at 1.0; top-down passes
# Config.TD_DRAIN_MULTIPLIER.
static func update(people: Array, delta: float, drain_multiplier: float = 1.0) -> void:
	var zones: Array = []
	for p: Person in people:
		if p.is_rescued:
			zones.append(p.global_position)

	for p: Person in people:
		if p.is_rescued:
			continue
		var nearest := Config.NO_ZONE_DISTANCE
		if not zones.is_empty():
			nearest = nearest_distance(p.global_position, zones)
		if nearest <= Config.ZONE_RADIUS:
			p.gloom -= Config.ZONE_HEAL * delta
		else:
			p.gloom += (Config.GLOOM_GROWTH + Config.GLOOM_GROWTH_PER_METER * nearest) * delta
		p.gloom = clampf(p.gloom, 0.0, 1.0)

	for p: Person in people:
		if p.is_rescued or Config.gloom_level(p.gloom) < Config.SPREAD_LEVEL:
			continue
		for q: Person in people:
			if q == p:
				continue
			if flat_dist(p.global_position, q.global_position) > Config.SPREAD_RADIUS:
				continue
			if q.is_rescued:
				q.drain_joy(Config.SPREAD_DRAIN_RATE * delta * drain_multiplier)
			else:
				q.gloom = clampf(q.gloom + Config.SPREAD_GLOOM_RATE * delta, 0.0, 1.0)


# Distance between two points, ignoring height.
static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# Smallest flat distance from `pos` to any point in `points`.
static func nearest_distance(pos: Vector3, points: Array) -> float:
	var best := INF
	for other: Vector3 in points:
		best = minf(best, flat_dist(pos, other))
	return best
