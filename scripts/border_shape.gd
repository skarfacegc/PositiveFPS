class_name BorderShape
extends RefCounted
# Round 21: the pure map-edge rules of the border loop, split out of border.gd (which was at the 1000-line cap).
# Border.clamp_to_map / Border.drop_short_seals call these; the behaviour is unchanged.


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
