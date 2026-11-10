class_name GapTracker
extends RefCounted

# Round 13b: how long each open gap of the border has been open. The border hands over its gap middles every update (one
# per break); a gap seen again within GAP_TRACK_RADIUS of where an old one was last frame is that gap and keeps its age
# (plus the time since), and a new one starts at zero. (Plain arrays, no per-gap objects: it runs every frame.)

# How urgent each gap is, 0 (just opened) to 1 (open GAP_URGENCY_SECONDS or more), in the border's gap order.
var urgencies: Array[float] = []
# Last frame's gap middles and their ages in seconds (parallel arrays).
var positions: Array[Vector3] = []
var ages := PackedFloat32Array()


# Carries the ages over by `delta`. `mids` are the border's gap middles.
func update(mids: Array[Vector3], delta: float) -> void:
	var new_ages := PackedFloat32Array()
	var urgent: Array[float] = []
	var taken: Dictionary = {}
	for mid: Vector3 in mids:
		var age := _nearest_old_age(mid, taken, delta)
		new_ages.append(age)
		urgent.append(clampf(age / BorderConfig.GAP_URGENCY_SECONDS, 0.0, 1.0))
	ages = new_ages
	positions = mids
	urgencies = urgent


# The age (plus `delta`) of the old gap nearest to `mid` within GAP_TRACK_RADIUS that is not `taken` yet, else 0.
func _nearest_old_age(mid: Vector3, taken: Dictionary, delta: float) -> float:
	var best := -1
	var best_d := BorderConfig.GAP_TRACK_RADIUS
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
