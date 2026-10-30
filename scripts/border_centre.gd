class_name BorderCentre
extends RefCounted

# Round 19: where the border's centre is, and the spirit beacon that moves it. Split out of border.gd (near its
# line cap).
# Before the border forms, the centre is the centroid of the rescued (and snaps to it the frame the border forms). From
# then on it is ANCHORED: the player standing at the edge, a push or a shove no longer moves it. It moves only when the
# player places a beacon: the centre then walks toward the beacon at Config.BEACON_PULL_SPEED and the beacon clears when
# the centre arrives. The shape of the loop (bulges, relax, slots) is not touched by any of this.

# Where the beacon is (x, z, y = 0), or Vector3.INF when there is none.
var beacon := Vector3.INF
var b: Border


func _init(border: Border) -> void:
	b = border


func has_beacon() -> bool:
	return beacon != Vector3.INF


# Puts the beacon at `pos`, clamped inside the map. A new beacon replaces the old one.
func place(pos: Vector3) -> void:
	var lim := Config.BORDER_MAP_LIMIT
	beacon = Vector3(clampf(pos.x, -lim, lim), 0.0, clampf(pos.z, -lim, lim))


func clear() -> void:
	beacon = Vector3.INF


# Moves the centre for this frame (called from Border.update before the loop is built).
func update(rescued: Array[Person], delta: float) -> void:
	if not b.formed:
		_form(rescued, delta)
		return
	if not has_beacon():
		return
	var to := Vector3(beacon.x - b.centre.x, 0.0, beacon.z - b.centre.z)
	var step := Config.BEACON_PULL_SPEED * delta
	if to.length() <= maxf(step, Config.BEACON_ARRIVE_RADIUS):
		b.centre = Vector3(beacon.x, b.centre.y, beacon.z)
		clear()
		b.beacon_reached.emit()
		return
	b.centre += to.normalized() * step


# Before the border exists: the centre is the centroid of the rescued (a post counts like BORDER_POST_WORTH people). The
# first rescue sets it, it follows at BORDER_CENTRE_FOLLOW, and it snaps to the centroid on the frame the border forms.
func _form(rescued: Array[Person], delta: float) -> void:
	if rescued.is_empty():
		return
	var sum := Vector3.ZERO
	for p: Person in rescued:
		sum += Vector3(p.position.x, 0.0, p.position.z)
	var weight := float(rescued.size())
	for pt: Vector3 in b._post_points:
		sum += pt * float(Config.BORDER_POST_WORTH)
		weight += float(Config.BORDER_POST_WORTH)
	var target := sum / weight
	if not b._has_centre or rescued.size() >= Config.BORDER_MIN_PEOPLE:
		b.centre = target
		b._has_centre = true
		return
	var to := Vector3(target.x - b.centre.x, 0.0, target.z - b.centre.z)
	b.centre += to.normalized() * minf(to.length(), Config.BORDER_CENTRE_FOLLOW * delta)
