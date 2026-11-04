class_name BorderShape
extends RefCounted

# Round 23: the smallest size factor the loop's ease will aim for (Border._organic_polygon).
const SCALE_FLOOR := 0.2
# Round 21: the pure map-edge rules of the border loop, split out of border.gd (which was at the 1000-line cap).
# BorderShape.clamp_to_map / BorderShape.drop_short_seals call these; the behaviour is unchanged.


# Round 16: pulls every point onto the map (within BORDER_MAP_LIMIT of the middle) and returns, per segment (point j to
# point j + 1), whether the segment runs along the map edge: both ends sit on the same side.
static func clamp_to_map(pts: PackedVector2Array) -> Array[float]:
	var lim := Config.BORDER_MAP_LIMIT
	var band := Config.BORDER_SEAL_BAND
	var n := pts.size()
	for i: int in range(n):
		pts[i] = Vector2(clampf(pts[i].x, -lim, lim), clampf(pts[i].y, -lim, lim))
	var out: Array[float] = []
	for j: int in range(n):
		var a := pts[j]
		var b := pts[(j + 1) % n]
		var near := INF  # The largest distance of the two ends from the closest edge they share.
		near = minf(near, maxf(lim + a.x, lim + b.x))
		near = minf(near, maxf(lim - a.x, lim - b.x))
		near = minf(near, maxf(lim + a.y, lim + b.y))
		near = minf(near, maxf(lim - a.y, lim - b.y))
		out.append(clampf(1.0 - near / band, 0.0, 1.0))
	return out


# Round 18: a sealed stretch (a run of neighbouring segments with a seal weight above 0) shorter than `min_len` metres
# is
# opened again: the members on either side of it would stand nearer than the spacing. Sets those weights to 0. A loop
# that is sealed all the way round is left alone.
static func drop_short_seals(pts: PackedVector2Array, sealed: Array[float], min_len: float) -> void:
	var n := pts.size()
	var start := -1
	for j: int in range(n):
		if sealed[j] <= 0.0:
			start = j  # A segment with no seal: runs are counted from just after it.
			break
	if start < 0:
		return
	var run: Array[int] = []
	var run_len := 0.0
	for off: int in range(1, n + 1):
		var j := (start + off) % n
		if sealed[j] > 0.0:
			run.append(j)
			run_len += pts[j].distance_to(pts[(j + 1) % n])
		if sealed[j] <= 0.0 or off == n:
			if run_len < min_len:
				for q: int in run:
					sealed[q] = 0.0
			run.clear()
			run_len = 0.0


# Round 23: the pure loop rules split out of border.gd (it was at the line cap). Border keeps the
# state and calls these with it; the behaviour is unchanged.


static func circle_polygon(c: Vector2, radius: float, samples: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(samples):
		var a := TAU * float(i) / float(samples)
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	return pts


# Total length of a closed loop of points.
static func perimeter_of(pts: PackedVector2Array) -> float:
	var total := 0.0
	var n := pts.size()
	for j: int in range(n):
		total += pts[j].distance_to(pts[(j + 1) % n])
	return total


# Round 16: the length of a closed loop of points, counting each segment by how much of it is open (see clamp_to_map).
static func open_perimeter_of(pts: PackedVector2Array, sealed: Array[float]) -> float:
	var total := 0.0
	var n := pts.size()
	for j: int in range(n):
		total += pts[j].distance_to(pts[(j + 1) % n]) * (1.0 - sealed[j])
	return total


# How many slots a loop of this perimeter holds (perimeter over the target spacing, rounded up).
static func slot_count_for(loop_perimeter: float) -> int:
	return ceili(loop_perimeter / Config.BORDER_TARGET_SPACING)


# Checkpoint 5: the slot count with hysteresis. The loop is eased to n x BORDER_TARGET_SPACING, exactly where the plain
# ceiling steps from n to n + 1, so a hair of noise flipped it (and the member count with it). The `previous` count is
# kept while perimeter / spacing is within BORDER_SLOT_COUNT_HOLD of a slot beyond its step either way; 0 means none.
static func held_slot_count(loop_perimeter: float, previous: int) -> int:
	var fresh := slot_count_for(loop_perimeter)
	if previous <= 0:
		return fresh
	var exact := loop_perimeter / Config.BORDER_TARGET_SPACING
	var hold := Config.BORDER_SLOT_COUNT_HOLD
	if exact > float(previous - 1) - hold and exact <= float(previous) + hold:
		return previous
	return fresh


# One gap flag per slot segment. A segment is a gap if the spacing is too wide, or it touches an empty slot. A segment
# that touches a post (`anchored`) is never a gap while the post stands.
static func gap_flags(
	spacing_m: float, filled: Array[bool], anchored: Array[bool] = [], faltering: Array[bool] = []
) -> Array[bool]:
	var out: Array[bool] = []
	var m := filled.size()
	for k: int in range(m):
		var gap := spacing_m > Config.BORDER_MAX_GAP or not filled[k] or not filled[(k + 1) % m]
		if faltering.size() == m and (faltering[k] or faltering[(k + 1) % m]):
			gap = true
		if anchored.size() == m and (anchored[k] or anchored[(k + 1) % m]):
			gap = false
		out.append(gap)
	return out


# True when `p` is inside the loop.
static func is_inside(pts: PackedVector2Array, p: Vector2) -> bool:
	return pts.size() >= 3 and Geometry2D.is_point_in_polygon(p, pts)


# Distance from point `p` to the box centred on `c` with half-size `half` (0 inside it).
static func box_distance(p: Vector2, c: Vector2, half: Vector2) -> float:
	var d := Vector2(maxf(absf(p.x - c.x) - half.x, 0.0), maxf(absf(p.y - c.y) - half.y, 0.0))
	return d.length()


# Ray against an axis-aligned box in 2D. Returns Vector2(entry, exit) along the ray, or Vector2(INF, -INF) for a miss.
static func ray_box(o: Vector2, d: Vector2, lo: Vector2, hi: Vector2) -> Vector2:
	var miss := Vector2(INF, -INF)
	var tmin := -INF
	var tmax := INF
	if absf(d.x) < 1e-9:
		if o.x < lo.x or o.x > hi.x:
			return miss
	else:
		var tx1 := (lo.x - o.x) / d.x
		var tx2 := (hi.x - o.x) / d.x
		tmin = maxf(tmin, minf(tx1, tx2))
		tmax = minf(tmax, maxf(tx1, tx2))
	if absf(d.y) < 1e-9:
		if o.y < lo.y or o.y > hi.y:
			return miss
	else:
		var tz1 := (lo.y - o.y) / d.y
		var tz2 := (hi.y - o.y) / d.y
		tmin = maxf(tmin, minf(tz1, tz2))
		tmax = minf(tmax, maxf(tz1, tz2))
	if tmax < tmin or tmax < 0.0:
		return miss
	return Vector2(tmin, tmax)


# Round 18: raw radii used to only grow, so a shoved side stayed a thin tongue for ever. Each radius now eases toward
# the
# mean of its four nearest neighbours at BORDER_RELAX_RATE a second: a narrow bump spreads out and flattens in seconds,
# while a wide, slow swell (the loop really reaching one way) hardly changes. The sum is kept, so the size is not lost.
static func relax_radii(raw: Array[float], sealed: Array[float], delta: float) -> Array[float]:
	var n := raw.size()
	var k := clampf(Config.BORDER_RELAX_RATE * delta, 0.0, 1.0)
	var out: Array[float] = []
	for i: int in range(n):
		var near := raw[(i - 2 + n) % n] + raw[(i - 1 + n) % n] + raw[(i + 1) % n] + raw[(i + 2) % n]
		# A side pressed against the map edge is held there (round 16): relaxing it would pull the whole pressed stretch
		# off the
		# wall in one go and send everyone walking.
		var held := 0.0
		if sealed.size() == n:
			held = maxf(sealed[i], sealed[(i - 1 + n) % n])
		out.append(lerpf(raw[i], near / 4.0, k * (1.0 - held)))
	return out


# Round 18: the part of a raw radius that reaches beyond the map edge is wasted (the loop is clamped there), but it
# used to
# stay stored, so a pressed side held still until the whole excess had relaxed away and then fell back all at once. Raw
# radii now stop BORDER_WALL_SLACK past the edge (counting the size factor), so pulling back starts at once and is
# gradual.
static func trim_to_map(raw: Array[float], centre: Vector3, size_factor: float) -> void:
	var lim := Config.BORDER_MAP_LIMIT
	var n := raw.size()
	for i: int in range(n):
		var a := TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		var reach := INF
		if absf(d.x) > 1e-6:
			reach = minf(reach, ((lim if d.x > 0.0 else -lim) - centre.x) / d.x)
		if absf(d.y) > 1e-6:
			reach = minf(reach, ((lim if d.y > 0.0 else -lim) - centre.z) / d.y)
		var cap := maxf(reach, Config.BORDER_MIN_RADIUS) * Config.BORDER_WALL_SLACK / maxf(size_factor, 0.2)
		raw[i] = minf(raw[i], cap)


# The radius per angle after a small circular blur (so one bump does not look like a spike).
static func smoothed_radii(raw: Array[float]) -> Array[float]:
	var out: Array[float] = []
	var n := raw.size()
	for i: int in range(n):
		var prev := raw[(i - 1 + n) % n]
		var nxt := raw[(i + 1) % n]
		out.append((prev + 2.0 * raw[i] + nxt) / 4.0)
	return out


# The nearest block on the ray from `o` along `d` that lies in front of `o`: Vector2(entry, exit). entry is INF if
# none.
static func first_block_along(buildings: Array[Building], o: Vector2, d: Vector2) -> Vector2:
	var best := Vector2(INF, -INF)
	for b: Building in buildings:
		var hit := ray_box(o, d, b.centre - b.half, b.centre + b.half)
		if hit.x == INF or hit.y <= 0.0:
			continue
		if hit.x < best.x:
			best = hit
	return best


# Distance from `p2` to the nearest point on the loop.
static func distance_to_line(polygon: PackedVector2Array, p2: Vector2) -> float:
	var best := INF
	var n := polygon.size()
	for j: int in range(n):
		var closest := Geometry2D.get_closest_point_to_segment(p2, polygon[j], polygon[(j + 1) % n])
		best = minf(best, closest.distance_to(p2))
	return best


# The first crossing (closest to `a2`) between the move a2 -> b2 and an intact stretch of the loop, or null.
static func first_crossing(polygon: PackedVector2Array, sample_gap: Array[bool], a2: Vector2, b2: Vector2) -> Variant:
	var n := polygon.size()
	if n < 3 or sample_gap.size() != n:
		return null
	var best: Variant = null
	var best_d := INF
	for j: int in range(n):
		if sample_gap[j]:
			continue
		var hit: Variant = Geometry2D.segment_intersects_segment(a2, b2, polygon[j], polygon[(j + 1) % n])
		if hit == null:
			continue
		var h: Vector2 = hit
		var d := a2.distance_to(h)
		if d < best_d:
			best_d = d
			best = h
	return best
