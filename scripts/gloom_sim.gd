class_name GloomSim
extends RefCounted

# Shared gloom rules for the top-down territory game. Unrescued people darken over time (faster far from colour
# zones) and dark people spread darkness to neighbours (and drain joy from rescued ones).
#
# The rules depend on each person's protection (0..1, from the paint around them, see Person.protection): darkness
# only creeps in at the edges of painted ground, and people with enough cover have their gloom lowered by joy
# contagion.


# `drain_multiplier` scales how fast dark people drain rescued joy (Config.TD_DRAIN_MULTIPLIER in the level).
# `strength` is the night strength (see NightCycle): it scales gloom growth, spread and drain. Darkness does not spread
# across an intact stretch of the border (`border`, when it has a loop).
static func update(
	people: Array, delta: float, drain_multiplier: float = 1.0, strength: float = 1.0, border: Border = null
) -> void:
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
		_update_covered(p, nearest, delta, strength)
		p.gloom = clampf(p.gloom, 0.0, 1.0)

	for p: Person in people:
		if p.is_rescued or Config.gloom_level(p.gloom) < Config.SPREAD_LEVEL:
			continue
		for q: Person in people:
			if q == p:
				continue
			if flat_dist(p.global_position, q.global_position) > Config.SPREAD_RADIUS:
				continue
			if border != null and border.line_blocks(p.global_position, q.global_position):
				continue
			# A person's own protection scales what reaches them (1 deep inside painted ground, 0 at edges).
			var exposure := 1.0 - q.protection
			if q.is_rescued:
				q.drain_joy(Config.SPREAD_DRAIN_RATE * delta * drain_multiplier * strength * exposure)
			else:
				q.gloom = clampf(q.gloom + Config.SPREAD_GLOOM_RATE * delta * strength * exposure, 0.0, 1.0)


# Cover rules for one unrescued person. Growth is scaled by (1 - protection), so it only happens at the edges.
# Contagion lowers gloom when the cover is high enough, scaled by protection. It never touches joy.
static func _update_covered(p: Person, nearest: float, delta: float, strength: float) -> void:
	p.gloom += (Config.GLOOM_GROWTH + Config.GLOOM_GROWTH_PER_METER * nearest) * delta * strength * (1.0 - p.protection)
	if p.cover >= Config.TD_CONTAGION_THRESHOLD:
		p.gloom -= Config.TD_CONTAGION_RATE * delta * p.protection


# True for an unrescued person at the dark level: they spread darkness, drain nearby joy and erode paint.
static func is_dark(p: Person) -> bool:
	return not p.is_rescued and Config.gloom_level(p.gloom) >= Config.SPREAD_LEVEL


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
