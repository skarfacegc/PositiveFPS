class_name BorderSlots
extends RefCounted
# The member code of the living border, split out of border.gd. 0.4 (#56): members stand only on gates. Each gate
# wants its width over BORDER_TARGET_SPACING members (Zone gates' "need"); with fewer rescued people than that the
# members are shared out between the gates in proportion and spread wider. The people who do not stand on a gate are
# inner members and stand on the zone's open ground. It reads and writes the state of the Border that owns it (`b`).

var b: Border
# Grid fixes (#56): the members each gate has now (gate order); each gate's need is zone.gates[g]["need"].
var gate_counts: Array[int] = []
# Person -> {"g": gate index, "s": slot, "c": members on that gate}, kept while the rescued and the zone stay the same.
var _assigned: Dictionary = {}
var _signature := PackedInt64Array()


func _init(border: Border) -> void:
	b = border


# Splits the rescued people into gate members and inner members and gives everyone a target position (see
# Border._move_members).
func assign_members(rescued: Array[Person]) -> void:
	b.members.clear()
	b.inner.clear()
	b._targets.clear()
	b.member_count = 0
	b.inner_count = 0
	b.spacing = 0.0
	b.slot_count = 0
	gate_counts.clear()
	if not b.active or b.polygon.size() < 3:
		_assigned.clear()
		_signature = PackedInt64Array()
		return
	var gates: Array[Dictionary] = b.zone.gates
	var needs: Array[int] = []
	for g: Dictionary in gates:
		needs.append(g["need"])
	b.slot_count = b.zone.members_needed()
	var m := mini(rescued.size(), b.slot_count)
	var counts := share_out(needs, m)
	gate_counts = counts
	var sig := PackedInt64Array([b.zone.version, m])
	for p: Person in rescued:
		sig.append(p.get_instance_id())
	if sig != _signature:
		_signature = sig
		_match(rescued, counts)
	var placed: Dictionary = {}
	for p: Person in rescued:
		if not _assigned.has(p):
			continue
		var slot: Dictionary = _assigned[p]
		var g: int = slot["g"]
		var s: int = slot["s"]
		var c: int = slot["c"]
		var at := b.gate_point(g, (float(s) + 0.5) / float(c))
		b._targets[p] = Vector3(at.x, 0.0, at.y)
		b.members.append(p)
		placed[p] = true
	for p: Person in rescued:
		if not placed.has(p):
			b.inner.append(p)
	var rects := b.zone.open_rects()
	for j: int in range(b.inner.size()):
		var spot := _inner_spot(rects, j)
		b._targets[b.inner[j]] = Vector3(spot.x, 0.0, spot.y)
	b.member_count = b.members.size()
	b.inner_count = b.inner.size()
	if b.member_count > 0:
		b.spacing = b.perimeter / float(b.member_count)


# How many members each gate gets when `m` people share out gates that need `needs`: all of them in full when there are
# enough, otherwise in proportion (the remainders go to the largest fractions, the first gate on a tie).
static func share_out(needs: Array[int], m: int) -> Array[int]:
	var total := 0
	for k: int in needs:
		total += k
	var out: Array[int] = []
	if m >= total:
		out.assign(needs)
		return out
	var left := m
	var fractions: Array[float] = []
	for k: int in needs:
		var exact := float(k) * float(m) / float(maxi(total, 1))
		out.append(floori(exact))
		fractions.append(exact - floorf(exact))
		left -= out[out.size() - 1]
	while left > 0:
		var best := 0
		for i: int in range(fractions.size()):
			if fractions[i] > fractions[best]:
				best = i
		out[best] += 1
		fractions[best] = -1.0
		left -= 1
	return out


# Gives each gate its members: all the (person, slot) pairs by distance, nearest first, so everyone takes a slot near
# where they stand and nobody crosses the town to a far gate.
func _match(rescued: Array[Person], counts: Array[int]) -> void:
	_assigned.clear()
	var slots: Array[Dictionary] = []
	for g: int in range(counts.size()):
		for s: int in range(counts[g]):
			var at := b.gate_point(g, (float(s) + 0.5) / float(counts[g]))
			slots.append({"g": g, "s": s, "c": counts[g], "at": at})
	var pairs: Array[Vector3] = []
	for pi: int in range(rescued.size()):
		var here := Vector2(rescued[pi].position.x, rescued[pi].position.z)
		for si: int in range(slots.size()):
			var at: Vector2 = slots[si]["at"]
			pairs.append(Vector3(here.distance_squared_to(at), float(pi), float(si)))
	pairs.sort_custom(_nearer)
	var person_taken: Dictionary = {}
	var slot_taken: Dictionary = {}
	for pr: Vector3 in pairs:
		if slot_taken.size() >= slots.size():
			break
		var pi := roundi(pr.y)
		var si := roundi(pr.z)
		if person_taken.has(pi) or slot_taken.has(si):
			continue
		person_taken[pi] = true
		slot_taken[si] = true
		var slot: Dictionary = slots[si]
		_assigned[rescued[pi]] = {"g": slot["g"], "s": slot["s"], "c": slot["c"]}


static func _nearer(x: Vector3, y: Vector3) -> bool:
	if x.x != y.x:
		return x.x < y.x
	if x.y != y.y:
		return x.y < y.y
	return x.z < y.z


# Where inner person `j` stands: the open ground the zone holds is dealt out rectangle by rectangle, and within a
# rectangle people fill it on a low-discrepancy sequence, GATE_INNER_INSET metres in from its edges.
func _inner_spot(rects: Array[Rect2], j: int) -> Vector2:
	if rects.is_empty():
		return Vector2(b.centre.x, b.centre.z)
	var r := rects[j % rects.size()]
	var q := float(floori(float(j) / float(rects.size())) + 1)
	var inner := r.grow(-BorderConfig.GATE_INNER_INSET)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return r.get_center()
	return (
		inner.position + Vector2(fposmod(0.618034 * q, 1.0) * inner.size.x, fposmod(0.754878 * q, 1.0) * inner.size.y)
	)
