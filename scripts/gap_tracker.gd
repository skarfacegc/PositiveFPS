class_name GapTracker
extends RefCounted

# Round 13b: how long each open gap of the border has been open. The border hands over its gap flags and gap middles
# every update; a gap keeps its age while its slot stays a gap (same slot count as last frame), or else is matched to
# the nearest gap of last frame within GAP_TRACK_RADIUS. New gaps start at zero. (Plain arrays, no per-gap objects: it
# runs every frame.)

# How urgent each gap is, 0 (just opened) to 1 (open GAP_URGENCY_SECONDS or more), in the border's gap order.
var urgencies: Array[float] = []
# Last frame's gap middles and their ages in seconds (parallel arrays), and each slot's age (-1 when not a gap).
var positions: Array[Vector3] = []
var ages := PackedFloat32Array()
var _slot_age := PackedFloat32Array()


# Carries the ages over by `delta`. `flags` are the border's segment_gap flags, `mids` its gap middles (one per
# true flag).
func update(flags: Array[bool], mids: Array[Vector3], delta: float) -> void:
	var same_slots := flags.size() == _slot_age.size()
	var slot_age := PackedFloat32Array()
	slot_age.resize(flags.size())
	var new_ages := PackedFloat32Array()
	var urgent: Array[float] = []
	var taken: Dictionary = {}
	var n := 0
	for k: int in range(flags.size()):
		if not flags[k]:
			slot_age[k] = -1.0
			continue
		var age := 0.0
		if same_slots:
			if _slot_age[k] >= 0.0:
				age = _slot_age[k] + delta
		else:
			age = _nearest_old_age(mids[n], taken, delta)
		slot_age[k] = age
		new_ages.append(age)
		urgent.append(clampf(age / Config.GAP_URGENCY_SECONDS, 0.0, 1.0))
		n += 1
	_slot_age = slot_age
	ages = new_ages
	positions = mids
	urgencies = urgent


# The age (plus `delta`) of the old gap nearest to `mid` within GAP_TRACK_RADIUS that is not `taken` yet, else 0.
func _nearest_old_age(mid: Vector3, taken: Dictionary, delta: float) -> float:
	var best := -1
	var best_d := Config.GAP_TRACK_RADIUS
	for i: int in range(positions.size()):
		if taken.has(i):
			continue
		var d := Vector2(mid.x - positions[i].x, mid.z - positions[i].z).length()
		if d < best_d:
			best_d = d
			best = i
	if best < 0:
		return 0.0
	taken[best] = true
	return ages[best] + delta
