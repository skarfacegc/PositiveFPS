class_name BorderSlots
extends RefCounted
# The slot code of the living border, split out of border.gd (round 18): where the slots lie on the loop (open length,
# sealed stretches), who stands in which slot, and the gaps that follow. It reads and writes the state of the Border
# that owns it (`b`); the loop polygon itself is built in border.gd.

var b: Border


func _init(border: Border) -> void:
	b = border


# Splits the rescued people into border members (the outermost, one per free slot) and inner members, works out the
# slots and the gaps. Round 10: beautified buildings on the line are posts. Each post claims BORDER_POST_WORTH
# consecutive slots, so the loop needs that many fewer people, and the segments beside a post are never gaps. Everyone
# gets a target position (see Border._move_members).
func assign_members(rescued: Array[Person]) -> void:
	var prev_targets: Dictionary = b._targets.duplicate()
	b.members.clear()
	b.inner.clear()
	b.segment_gap.clear()
	b._targets.clear()
	b.member_count = 0
	b.inner_count = 0
	b.post_count = 0
	b.spacing = 0.0
	b.perimeter = 0.0
	b._sample_gap.clear()
	b._arc.clear()
	b._open.clear()
	var held: Array[Building] = []  # Round 18: last frame's posts keep their hold a little further out (see _find_posts).
	for bld: Building in b.buildings:
		if bld.post:
			held.append(bld)
		bld.set_post(false)
	b._post_points.clear()
	var n := b.polygon.size()
	for j: int in range(n):
		b._sample_gap.append(false)
	if not b.active or n < 3:
		b.slot_count = 0
		return
	if b._sealed.size() != n:  # A loop set by hand (or before the first update) has no map edge.
		b._sealed.clear()
		for j: int in range(n):
			b._sealed.append(0.0)
	var acc := 0.0
	var open_acc := 0.0
	for j: int in range(n):
		b._arc.append(acc)
		b._open.append(open_acc)
		var seg_len := b.polygon[j].distance_to(b.polygon[(j + 1) % n])
		acc += seg_len
		open_acc += seg_len * (1.0 - b._sealed[j])
	b._arc.append(acc)
	b._open.append(open_acc)
	b.perimeter = open_acc  # Round 16: the open length (the whole loop unless the map edge seals part of it).
	if b.perimeter < 0.01:
		b.slot_count = 0
		return

	b.slot_count = BorderShape.held_slot_count(b.perimeter, b.slot_count)
	var posts := b._find_posts(b.slot_count, held)
	b.post_count = posts.size()
	var m := mini(rescued.size(), b.required_members())
	if m < 1:
		return
	# The slot grid: m member slots plus BORDER_POST_WORTH slots per post, evenly spaced around the loop.
	var k_total := m + Config.BORDER_POST_WORTH * b.post_count
	b.spacing = b.perimeter / float(k_total)
	var slot_taken: Array[bool] = []
	var post_slot: Array[bool] = []
	for k: int in range(k_total):
		slot_taken.append(false)
		post_slot.append(false)
	# The outermost m rescued people are border members; the rest are inner members. (Round 26: a faltering member no
	# longer steps back or opens a gap; the line only breaks where it is pushed too far.)
	var remaining: Array[Person] = rescued.duplicate()
	var border_list: Array[Person] = []
	while border_list.size() < m and not remaining.is_empty():
		border_list.append(_take_outermost(remaining))
	b.inner = remaining
	# Round 16: where the slot grid starts. Where the map edge seals part of the loop, the open length has no fixed
	# starting point (the first open point jumps along the edge as the loop changes), so the grid rides with the
	# members: its phase is the circular mean of where they stand, measured along the open length.
	b._phase = grid_phase(border_list)
	var placed := 0
	for entry: Dictionary in posts:
		var bld: Building = entry["building"]
		var arc: float = entry["arc"]
		var c := roundi((open_of_arc(arc) - b._phase) / b.spacing)
		for off: int in range(k_total):
			var s := posmod(c - 1 + off, k_total)
			if run_free(slot_taken, s):
				for t: int in range(Config.BORDER_POST_WORTH):
					slot_taken[posmod(s + t, k_total)] = true
					post_slot[posmod(s + t, k_total)] = true
				bld.set_post(true)
				placed += 1
				var at2 := point_at_arc(arc)
				b._post_points.append(Vector3(at2.x, 0.0, at2.y))
				break
	b.post_count = placed

	var slots: Array[Vector2] = []
	for k: int in range(k_total):
		slots.append(point_at_open(b._phase + float(k) * b.spacing))

	# Round 16: members keep their order around the loop. Sorted by angle round the centre, they take the free slots in
	# loop order, turned by whichever whole-slot offset costs the least walking (ordered_slots). Nobody crosses anybody,
	# so there is no convoy, and everyone slides along the wall toward the empty stretches. When a post could not be
	# placed there are spare slots; then each member takes the nearest free slot, in the order they were chosen.
	var chosen := ordered_slots(border_list, slots, slot_taken, prev_targets)
	for i: int in range(border_list.size()):
		var p: Person = border_list[i]
		var best_k := -1
		if chosen.size() == border_list.size():
			best_k = chosen[i]
		else:
			best_k = nearest_free_slot(Vector2(p.position.x, p.position.z), slots, slot_taken)
		slot_taken[best_k] = true
		var slot_at := BorderShape.clear_of_blocks(
			b.boxes(), slots[best_k], Config.ZONE_BLOCK_CLEAR, Vector2(b.centre.x, b.centre.z)
		)
		b._targets[p] = Vector3(slot_at.x, 0.0, slot_at.y)
		b.members.append(p)

	var spiral_cap := 0.6 * b._mean_radius()
	for j: int in range(b.inner.size()):
		var ang := float(j) * Border.GOLDEN_ANGLE
		var r := minf(Config.BORDER_INNER_SPACING * sqrt(float(j) + 1.0), spiral_cap)
		var rest := BorderShape.clear_of_blocks(
			b.boxes(),
			Vector2(b.centre.x + cos(ang) * r, b.centre.z + sin(ang) * r),
			Config.ZONE_BLOCK_CLEAR,
			Vector2(b.centre.x, b.centre.z)
		)
		b._targets[b.inner[j]] = Vector3(rest.x, 0.0, rest.y)

	b.member_count = b.members.size()
	b.inner_count = b.inner.size()
	var anchored: Array[bool] = []
	for k: int in range(k_total):
		anchored.append(post_slot[k] or post_slot[(k + 1) % k_total])
	b.segment_gap = BorderShape.gap_flags(b.spacing, slot_taken, anchored)
	# Round 26: a break (the line pushed past its limit) is a gap too: the slot stretches it lies in are open.
	for j: int in range(n):
		if b.push.segment_broken(j) and not b.is_sealed(j):
			b.segment_gap[mini(k_total - 1, int(fposmod(b._open[j] - b._phase, b.perimeter) / b.spacing))] = true
	for j: int in range(n):
		var k := mini(k_total - 1, int(fposmod(b._open[j] - b._phase, b.perimeter) / b.spacing))
		b._sample_gap[j] = b.segment_gap[k] and not b.is_sealed(j)


# The index of the free slot nearest to `pos2` (-1 when none is free).
static func nearest_free_slot(pos2: Vector2, slots: Array[Vector2], taken: Array[bool]) -> int:
	var best_k := -1
	var best_d2 := INF
	for k: int in range(slots.size()):
		if taken[k]:
			continue
		var d2 := pos2.distance_squared_to(slots[k])
		if d2 < best_d2:
			best_d2 = d2
			best_k = k
	return best_k


# Round 16: the start of the slot grid, in open length. 0 when nothing is sealed (the grid then starts at the first loop
# point, as before). Where the map edge seals part of the loop it has no fixed first point, so the grid rides with the
# members instead: the circular mean of their places along the open length, taken modulo spacing, blended in by the
# largest seal weight so it fades in as the loop meets the edge.
func grid_phase(list: Array[Person]) -> float:
	var seal := 0.0
	for w: float in b._sealed:
		seal = maxf(seal, w)
	if seal <= 0.0 or list.is_empty() or b.spacing <= 0.0:
		return 0.0
	var sum_s := 0.0
	var sum_c := 0.0
	for p: Person in list:
		var a := TAU * fposmod(open_of_point(Vector2(p.position.x, p.position.z)), b.spacing) / b.spacing
		sum_s += sin(a)
		sum_c += cos(a)
	if absf(sum_s) + absf(sum_c) < 1e-6:
		return 0.0
	return fposmod(atan2(sum_s, sum_c) * seal, TAU) / TAU * b.spacing


# Round 16: the open length at the point of the open loop nearest to `p2`.
func open_of_point(p2: Vector2) -> float:
	var best_d := INF
	var best_s := 0.0
	var n := b.polygon.size()
	for j: int in range(n):
		if b.is_sealed(j):
			continue
		var c := Geometry2D.get_closest_point_to_segment(p2, b.polygon[j], b.polygon[(j + 1) % n])
		var d := c.distance_squared_to(p2)
		if d < best_d:
			best_d = d
			best_s = b._open[j] + b.polygon[j].distance_to(c) * (1.0 - b._sealed[j])
	return best_s


# Round 16: the slot index for each person in `list`, when the free slots are exactly as many as the people (else an
# empty array). The people are ordered by angle round the centre and the free slots by their place on the loop; person i
# takes free slot (i + r) mod m, with the offset r that makes the total squared walk smallest (the first on a tie).
func ordered_slots(
	list: Array[Person], slots: Array[Vector2], taken: Array[bool], prev_targets: Dictionary = {}
) -> Array[int]:
	var free: Array[int] = []
	for k: int in range(slots.size()):
		if not taken[k]:
			free.append(k)
	var m := list.size()
	var out: Array[int] = []
	if m == 0 or free.size() != m:
		return out
	var order: Array[int] = []
	var angles: Array[float] = []
	for i: int in range(m):
		order.append(i)
		angles.append(atan2(list[i].position.z - b.centre.z, list[i].position.x - b.centre.x))
	order.sort_custom(func(x: int, y: int) -> bool: return angles[x] < angles[y] or (angles[x] == angles[y] and x < y))
	var best_r := 0
	var best_cost := INF
	var costs: Array[float] = []
	for r: int in range(m):
		var cost := 0.0
		for i: int in range(m):
			var q: Person = list[order[i]]
			cost += Vector2(q.position.x, q.position.z).distance_squared_to(slots[free[(i + r) % m]])
		costs.append(cost)
		if cost < best_cost:
			best_cost = cost
			best_r = r
	# Round 18, hysteresis: the offset that matches where everyone was heading last frame stays unless another offset
	# saves more than BORDER_SLOT_HYSTERESIS of the walking, so small changes of the loop never swap people over.
	var kept := _offset_matching(list, order, slots, free, prev_targets)
	if kept >= 0 and costs[kept] <= best_cost * (1.0 + Config.BORDER_SLOT_HYSTERESIS):
		best_r = kept
	out.resize(m)
	for i: int in range(m):
		out[order[i]] = free[(i + best_r) % m]
	return out


# Round 18: the offset whose slots lie nearest to where the people were heading last frame (-1 when most of them had no
# target yet, so there is nothing to keep).
func _offset_matching(
	list: Array[Person], order: Array[int], slots: Array[Vector2], free: Array[int], prev_targets: Dictionary
) -> int:
	var m := list.size()
	var known := 0
	for p: Person in list:
		if prev_targets.has(p):
			known += 1
	if known * 2 < m:
		return -1
	var best_r := -1
	var best_cost := INF
	for r: int in range(m):
		var cost := 0.0
		for i: int in range(m):
			var q: Person = list[order[i]]
			if prev_targets.has(q):
				var t: Vector3 = prev_targets[q]
				cost += Vector2(t.x, t.z).distance_squared_to(slots[free[(i + r) % m]])
		if cost < best_cost:
			best_cost = cost
			best_r = r
	return best_r


# Removes and returns the person farthest from the centre.
func _take_outermost(list: Array[Person]) -> Person:
	var best_i := 0
	var best_d := -1.0
	for i: int in range(list.size()):
		var d := Vector2(list[i].position.x - b.centre.x, list[i].position.z - b.centre.z).length()
		if d > best_d:
			best_d = d
			best_i = i
	var out := list[best_i]
	list.remove_at(best_i)
	return out


# True when slot `s` and the BORDER_POST_WORTH slots after it are all free (see assign_members).
static func run_free(taken: Array[bool], s: int) -> bool:
	var k := taken.size()
	for t: int in range(Config.BORDER_POST_WORTH):
		if taken[posmod(s + t, k)]:
			return false
	return true


# The point on the loop at arc length `s` from its first point.
func point_at_arc(s: float) -> Vector2:
	var total: float = b._arc[b._arc.size() - 1]
	var along := fposmod(s, total)
	var n := b.polygon.size()
	for j: int in range(n):
		if along <= b._arc[j + 1]:
			var seg: float = b._arc[j + 1] - b._arc[j]
			var t := 0.0
			if seg > 1e-9:
				t = (along - b._arc[j]) / seg
			return b.polygon[j].lerp(b.polygon[(j + 1) % n], t)
	return b.polygon[0]


# Round 16: the point at open length `s` (sealed segments take no length).
func point_at_open(s: float) -> Vector2:
	var total: float = b._open[b._open.size() - 1]
	var along := fposmod(s, total)
	var n := b.polygon.size()
	for j: int in range(n):
		if not b.is_sealed(j) and along <= b._open[j + 1]:
			var seg: float = b._open[j + 1] - b._open[j]
			var t := 0.0
			if seg > 1e-9:
				t = (along - b._open[j]) / seg
			return b.polygon[j].lerp(b.polygon[(j + 1) % n], t)
	return b.polygon[0]


# Round 16: the open length at full arc length `a`.
func open_of_arc(a: float) -> float:
	for j: int in range(b.polygon.size()):
		if a <= b._arc[j + 1]:
			return b._open[j] + (a - b._arc[j]) * (1.0 - b._sealed[j])
	return b._open[b._open.size() - 1]
