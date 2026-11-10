class_name BorderShape
extends RefCounted

# Pure rules for the line and for walking round blocks, split out of border.gd. 0.4 (Walls and gates) removed the
# round loop's rules (radii, seals, slot counts); what stays is geometry: is a point inside the line, how far is it
# from a box, where does a move cross the line, and the block-footprint walks (a person slides round a block's face,
# not through it).


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


# 0.3.3 (#53): block footprints as a flat list, four numbers per block (centre x, centre z, half x, half z): the form
# the zone-control walks use because they run for every person every frame (Border.zone_boxes).
static func footprints(buildings: Array[Building]) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for b: Building in buildings:
		out.append_array(PackedFloat32Array([b.centre.x, b.centre.y, b.half.x, b.half.y]))
	return out


# 0.3.3 (#53): the offset (in the list) of the footprint, grown by `clear` on every side, that strictly contains `p`,
# or -1.
static func block_at(boxes: PackedFloat32Array, p: Vector2, clear: float) -> int:
	for i: int in range(0, boxes.size(), 4):
		if absf(p.x - boxes[i]) < boxes[i + 2] + clear and absf(p.y - boxes[i + 1]) < boxes[i + 3] + clear:
			return i
	return -1


# 0.3.3 (#53): `p` moved out of every block footprint grown by `clear`: onto the nearest face of the grown box (a point
# that is already clear is returned as it is). Blocks stand apart, so a few passes settle it. With `origin` a point is
# moved out along the ray from the origin instead, to just past the box's far face.
static func clear_of_blocks(
	boxes: PackedFloat32Array, p: Vector2, clear: float, origin: Vector2 = Vector2.INF
) -> Vector2:
	var q := p
	for _pass: int in range(3):
		var i := block_at(boxes, q, clear)
		if i < 0:
			break
		var local := q - Vector2(boxes[i], boxes[i + 1])
		var ext := Vector2(boxes[i + 2], boxes[i + 3]) + Vector2(clear + 0.001, clear + 0.001)
		if origin != Vector2.INF and q.distance_to(origin) > 0.01:
			var c := Vector2(boxes[i], boxes[i + 1])
			var ray := (q - origin).normalized()
			var hit := ray_box(q, ray, c - ext, c + ext)
			if hit.y > 0.0:
				q += ray * (hit.y + 0.001)
				continue
		if ext.x - absf(local.x) < ext.y - absf(local.y):
			q.x = boxes[i] + (ext.x if local.x >= 0.0 else -ext.x)
		else:
			q.y = boxes[i + 1] + (ext.y if local.y >= 0.0 else -ext.y)
	return q


# 0.3.3 (#53): true when the straight walk from `a` to `b` crosses a block footprint grown by `clear`.
static func walk_blocked(boxes: PackedFloat32Array, a: Vector2, b: Vector2, clear: float) -> bool:
	var to := b - a
	var len := to.length()
	if len < 0.001:
		return false
	var dir := to / len
	for i: int in range(0, boxes.size(), 4):
		var ext := Vector2(boxes[i + 2], boxes[i + 3]) + Vector2(clear, clear)
		var c := Vector2(boxes[i], boxes[i + 1])
		var hit := ray_box(a, dir, c - ext, c + ext)
		if hit.x < hit.y and hit.y > 0.0 and hit.x < len:
			return true
	return false


# 0.3.3 (#53): one walking step from `from` toward `target` of at most `step` metres that does not go through a block.
# A free step is just taken. A step that would enter a grown footprint instead heads for the corner of that footprint
# (the corner with the shortest way round that can be reached in a straight line), and keeps that `waypoint` until it is
# reached or the straight walk to the target is clear again (Vector2.INF means no waypoint). Returns
# {"pos": Vector2, "waypoint": Vector2}.
static func step_around(
	boxes: PackedFloat32Array, from: Vector2, target: Vector2, step: float, clear: float, waypoint: Vector2
) -> Dictionary:
	var to := target - from
	var d := to.length()
	if d < 0.001:
		return {"pos": from, "waypoint": Vector2.INF}
	var dir := to / d
	var go := minf(step, d)
	var reached := false
	if waypoint != Vector2.INF:
		reached = from.distance_to(waypoint) < BorderConfig.ZONE_CORNER_REACHED
		if reached or not walk_blocked(boxes, from, target, clear - BorderConfig.ZONE_CORNER_SLACK):
			waypoint = Vector2.INF
	if waypoint == Vector2.INF and not reached and block_at(boxes, from + dir * go, clear) < 0:
		return {"pos": from + dir * go, "waypoint": Vector2.INF}  # The usual case: a free step.
	var q := clear_of_blocks(boxes, from, clear)
	if waypoint == Vector2.INF:
		var i := first_blocker(boxes, q, target, clear - BorderConfig.ZONE_CORNER_SLACK)
		if i < 0:  # Only skimming a footprint's edge: the step stays out of the grown box.
			return {"pos": clear_of_blocks(boxes, q + dir * go, clear), "waypoint": Vector2.INF}
		waypoint = _best_corner(boxes, i, q, target, clear)
		if waypoint == Vector2.INF:
			return {"pos": q, "waypoint": Vector2.INF}
	var way := waypoint - q
	var way_len := way.length()
	var moved := q + way / maxf(way_len, 0.001) * minf(step, way_len)
	return {"pos": clear_of_blocks(boxes, moved, clear), "waypoint": waypoint}


# The offset of the footprint (grown by `clear`) that the straight walk from `a` to `b` meets first, or -1.
static func first_blocker(boxes: PackedFloat32Array, a: Vector2, b: Vector2, clear: float) -> int:
	var to := b - a
	var len := to.length()
	if len < 0.001:
		return -1
	var dir := to / len
	var best := -1
	var best_t := INF
	for i: int in range(0, boxes.size(), 4):
		var ext := Vector2(boxes[i + 2], boxes[i + 3]) + Vector2(clear, clear)
		var c := Vector2(boxes[i], boxes[i + 1])
		var hit := ray_box(a, dir, c - ext, c + ext)
		if hit.x < hit.y and hit.y > 0.0 and hit.x < len and hit.x < best_t:
			best_t = hit.x
			best = i
	return best


# The corner of block `i` (grown by `clear`, a little out) that is the shortest way from `q` to `target` and can be
# walked to in a straight line; Vector2.INF when there is none.
static func _best_corner(boxes: PackedFloat32Array, i: int, q: Vector2, target: Vector2, clear: float) -> Vector2:
	var best := Vector2.INF
	var best_len := INF
	# A lane (0 to ZONE_CORNER_LANE metres, from the target so it is the same each time) keeps people who go round the same
	# corner from stacking up on one point.
	var lane := (
		fposmod(target.x * 3.7 + target.y * 1.9, 1.0) * BorderConfig.ZONE_CORNER_LANE + BorderConfig.ZONE_CORNER_OUT
	)
	var ext := Vector2(boxes[i + 2] + clear + lane, boxes[i + 3] + clear + lane)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var c := Vector2(boxes[i] + sx * ext.x, boxes[i + 1] + sz * ext.y)
			if (
				q.distance_to(c) < BorderConfig.ZONE_CORNER_REACHED
				or walk_blocked(boxes, q, c, clear - BorderConfig.ZONE_CORNER_SLACK)
			):
				continue
			var len := q.distance_to(c) + c.distance_to(target)
			if len < best_len:
				best_len = len
				best = c
	return best
