class_name GloomSim
extends RefCounted

# Shared gloom rules, used by both first-person and top-down mode.
# Gloom: unrescued people darken over time (faster far from colour zones), heal inside a zone,
# and dark people spread darkness to neighbours (and drain joy from rescued ones).
#
# Top-down passes use_cover = true (round 7). Then the rules depend on each person's protection (0..1, from
# the paint around them, see Person.protection): darkness only creeps in at the edges of painted ground, the
# zone heal is not used, and people with enough cover have their gloom lowered by joy contagion.


# `drain_multiplier` scales how fast dark people drain rescued joy. First person leaves it at 1.0; top-down passes
# Config.TD_DRAIN_MULTIPLIER. `use_cover` switches on the cover rules (top-down only); first person leaves it off.
static func update(people: Array, delta: float, drain_multiplier: float = 1.0, use_cover: bool = false) -> void:
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
		if use_cover:
			_update_covered(p, nearest, delta)
		elif nearest <= Config.ZONE_RADIUS:
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
			# With cover, a person's own protection scales what reaches them (1 deep inside painted ground, 0 at edges).
			var exposure := (1.0 - q.protection) if use_cover else 1.0
			if q.is_rescued:
				q.drain_joy(Config.SPREAD_DRAIN_RATE * delta * drain_multiplier * exposure)
			else:
				q.gloom = clampf(q.gloom + Config.SPREAD_GLOOM_RATE * delta * exposure, 0.0, 1.0)


# Cover rules for one unrescued person (top-down only). Growth is scaled by (1 - protection), so it only happens at
# the edges. Contagion lowers gloom when the cover is high enough, scaled by protection. It never touches joy.
static func _update_covered(p: Person, nearest: float, delta: float) -> void:
	p.gloom += (Config.GLOOM_GROWTH + Config.GLOOM_GROWTH_PER_METER * nearest) * delta * (1.0 - p.protection)
	if p.cover >= Config.TD_CONTAGION_THRESHOLD:
		p.gloom -= Config.TD_CONTAGION_RATE * delta * p.protection


# Protection for a cover value (0..1): 0 at the edge of painted ground, 1 well inside it. Smooth between the two.
static func protection_for(cover: float) -> float:
	return smoothstep(Config.TD_COVER_EDGE, Config.TD_COVER_FULL, cover)


# Distance between two points, ignoring height.
static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# Smallest flat distance from `pos` to any point in `points`.
static func nearest_distance(pos: Vector3, points: Array) -> float:
	var best := INF
	for other: Vector3 in points:
		best = minf(best, flat_dist(pos, other))
	return best
