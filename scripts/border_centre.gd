class_name BorderCentre
extends RefCounted

# Round 19 / 20: where the border's centre is, and the spirit beacon that stretches it. Split out of border.gd (near its
# line cap).
# Before the border forms, the centre is the centroid of the rescued (and snaps to it the frame the border forms). From
# then on it is ANCHORED: the player standing at the edge, a push or a shove no longer moves it.
# Round 20: a beacon no longer walks the centre. It STRETCHES the zone: the body stays round the old centre and a tip
# reaches toward the beacon at Config.BEACON_PULL_SPEED (the loop becomes the hull of the body circle and a smaller tip
# circle, a teardrop; see hull_radius). The tip stops at the beacon or at the maximum reach (BEACON_REACH_BASE +
# BEACON_REACH_PER_PERSON x people rescued, past the circle's edge), holds there for BEACON_STRETCH_HOLD seconds, then
# the zone snaps back to a circle centred at the tip and the beacon clears. A new beacon replaces the old one: the tip
# keeps its place and turns toward the new one. Border._organic_polygon asks stretch_radius() for each ray, so the
# territory, ground, landmarks and slots all follow the stretched polygon.

# Where the beacon is (x, z, y = 0), or Vector3.INF when there is none.
var beacon := Vector3.INF
# True from placing a beacon until the snap. The tip is where the stretch reaches now (x, z, y = 0).
var stretching: bool = false
var tip := Vector3.ZERO
# True once the tip has stopped (at the beacon or the maximum reach); hold_left counts down to the snap.
var holding: bool = false
var hold_left: float = 0.0
var b: Border
var _people: int = 0
var _cap_people: int = -1
var _cap_value: float = 0.0


func _init(border: Border) -> void:
	b = border


func has_beacon() -> bool:
	return beacon != Vector3.INF


# The radius of the plain circle for `people` rescued (the size the loop settles at without a stretch).
static func circle_radius(people: int) -> float:
	return maxf(float(people) * Config.BORDER_TARGET_SPACING / TAU, Config.BORDER_MIN_RADIUS)


# How far past the circle's edge the tip can reach with `people` rescued.
static func reach_beyond(people: int) -> float:
	return Config.BEACON_REACH_BASE + Config.BEACON_REACH_PER_PERSON * float(people)


# The farthest the tip can be from the centre now: past the circle's edge by reach_beyond(), but never so far that the
# loop (whose length is fixed by the people, see Border._organic_polygon) would have to squeeze the body below
# BEACON_BODY_MIN of its plain radius.
func max_distance() -> float:
	if _cap_people != _people:
		_cap_people = _people
		_cap_value = feasible_distance(circle_radius(_people))
	return minf(circle_radius(_people) + reach_beyond(_people), _cap_value)


# The farthest tip distance whose teardrop, with a body of BEACON_BODY_MIN x `radius`, is no longer than the circle of
# `radius` (the length the people can make). Found by bisection; the hull grows steadily with the distance.
static func feasible_distance(radius: float) -> float:
	var body := radius * Config.BEACON_BODY_MIN
	var budget := TAU * radius
	var lo := body
	var hi := radius * 4.0
	for _i: int in range(30):
		var mid := (lo + hi) * 0.5
		if hull_perimeter(body, Config.BEACON_TIP_WIDTH * body, mid) <= budget:
			lo = mid
		else:
			hi = mid
	return lo


# The length of the teardrop's outline (just the circle when the tip does not pass the body).
static func hull_perimeter(body: float, width: float, reach: float) -> float:
	var c := reach - width
	if c <= body - width + 0.001:
		return TAU * body
	var beta := acos((body - width) / c)
	return 2.0 * sqrt(c * c - (body - width) * (body - width)) + 2.0 * (PI - beta) * body + 2.0 * beta * width


# Puts the beacon at `pos`, clamped inside the map, and starts (or redirects) the stretch. A new beacon replaces the
# old one.
func place(pos: Vector3) -> void:
	var lim := Config.BORDER_MAP_LIMIT
	beacon = Vector3(clampf(pos.x, -lim, lim), 0.0, clampf(pos.z, -lim, lim))
	holding = false
	if not stretching:
		var dir := _flat_dir(b.centre, beacon)
		var start := minf(minf(b._mean_radius(), max_distance()), _flat_dist(b.centre, beacon))
		tip = Vector3(b.centre.x + dir.x * start, 0.0, b.centre.z + dir.y * start)
		stretching = true
	b.stretch_started.emit(beacon, target())


func clear() -> void:
	beacon = Vector3.INF
	stretching = false
	holding = false


# Where the tip is heading: toward the beacon, no farther than the maximum reach from the centre.
func target() -> Vector3:
	if not has_beacon():
		return tip
	var dir := _flat_dir(b.centre, beacon)
	var d := minf(_flat_dist(b.centre, beacon), max_distance())
	return Vector3(b.centre.x + dir.x * d, 0.0, b.centre.z + dir.y * d)


# Moves the tip for this frame (called from Border.update before the loop is built).
func update(rescued: Array[Person], delta: float) -> void:
	_people = rescued.size()
	if not b.formed:
		_form(rescued, delta)
		return
	if not stretching:
		return
	var goal := target()
	if not holding:
		var to := goal - tip
		var step := Config.BEACON_PULL_SPEED * delta
		if to.length() <= maxf(step, Config.BEACON_ARRIVE_RADIUS):
			tip = goal
			holding = true
			hold_left = Config.BEACON_STRETCH_HOLD
			b.beacon_reached.emit()
		else:
			tip += to.normalized() * step
		return
	if _flat_dist(b.centre, tip) > _flat_dist(b.centre, goal):
		tip = goal  # The reach shrank (people lost): the tip comes in with it.
	hold_left -= delta
	if hold_left <= 0.0:
		_snap()


# The zone returns to a circle centred at the tip; the beacon clears.
func _snap() -> void:
	var from := b.centre
	b.centre = tip
	var total := 0.0
	for r: float in b._raw_radii:
		total += r
	var flat := total / float(maxi(b._raw_radii.size(), 1))
	for i: int in range(b._raw_radii.size()):
		b._raw_radii[i] = flat
	clear()
	b.zone_snapped.emit(from, b.centre)


# How far the stretch reaches along the ray at `angle` from the centre, for a body of radius `body`, or 0 when it adds
# nothing (no stretch, or the ray falls inside the body circle).
func stretch_radius(angle: float, body: float) -> float:
	if not stretching:
		return 0.0
	var to := Vector2(tip.x - b.centre.x, tip.z - b.centre.z)
	return hull_radius(body, Config.BEACON_TIP_WIDTH * body, to.length(), absf(wrapf(angle - to.angle(), -PI, PI)))


# The teardrop: the convex hull of the body circle (radius `body`, round the origin) and a tip circle of radius `width`
# whose far edge is `reach` from the origin. Returns its radius along a ray `off` radians from the tip's direction, or 0
# where the hull is just the body circle.
static func hull_radius(body: float, width: float, reach: float, off: float) -> float:
	var c := reach - width  # the tip circle's centre
	if width <= 0.0 or c <= body - width + 0.001:
		return 0.0
	var beta := acos((body - width) / c)  # where the straight sides leave the body circle
	if off >= beta:
		return 0.0
	var side := body / cos(off - beta)
	var gamma := atan2(width * sin(beta), c + width * cos(beta))  # where they meet the tip circle
	if off <= gamma:
		var s := c * sin(off)
		return minf(side, c * cos(off) + sqrt(maxf(width * width - s * s, 0.0)))
	return side


static func _flat_dir(from: Vector3, to: Vector3) -> Vector2:
	var d := Vector2(to.x - from.x, to.z - from.z)
	return d.normalized() if d.length() > 0.0001 else Vector2.RIGHT


static func _flat_dist(from: Vector3, to: Vector3) -> float:
	return Vector2(to.x - from.x, to.z - from.z).length()


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
	var target_pt := sum / weight
	if not b._has_centre or rescued.size() >= Config.BORDER_MIN_PEOPLE:
		b.centre = target_pt
		b._has_centre = true
		return
	var to := Vector3(target_pt.x - b.centre.x, 0.0, target_pt.z - b.centre.z)
	b.centre += to.normalized() * minf(to.length(), Config.BORDER_CENTRE_FOLLOW * delta)
