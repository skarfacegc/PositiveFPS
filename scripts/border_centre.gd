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

# Round 21: body radius by (circle radius, reach), see body_for.
static var _body_cache: Dictionary = {}

# Where the beacon is (x, z, y = 0), or Vector3.INF when there is none.
var beacon := Vector3.INF
# True from placing a beacon until the snap. The tip is where the stretch reaches now (x, z, y = 0).
var stretching: bool = false
var tip := Vector3.ZERO
# True once the tip has stopped (at the beacon or the maximum reach); hold_left counts down to the snap.
var holding: bool = false
var hold_left: float = 0.0
var b: Border
# Round 21: where the dimmed people are (x, z), set by Border.update every frame; the tip keeps clear of them.
var dimmed: Array[Vector2] = []
var _people: int = 0
var _cap_people: int = -1
var _cap_value: float = 0.0
var _clock: float = 0.0
# Round 21: the plan for the last aim asked about (see plan_toward), reused for BEACON_PLAN_SECONDS.
var _plan_key := Vector3.INF
var _plan_at: float = -1.0e9
var _plan: Dictionary = {}


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


# Where the tip is heading: toward the beacon, no farther than the plan allows (the maximum reach, and round 21 the
# dimmed people it must not swallow).
func target() -> Vector3:
	if not has_beacon():
		return tip
	var dir := _flat_dir(b.centre, beacon)
	var d: float = plan_toward(beacon)["reach"]
	return Vector3(b.centre.x + dir.x * d, 0.0, b.centre.z + dir.y * d)


# Round 21: what a stretch toward `aim` would do right now: {"reach" (how far the tip would get from the centre), "dir"
# (angle of the stretch), "radius" (the plain circle), "reason" ("" when nothing holds it back, else the plain-words
# reason it stops short), "refused" (dimmed people leave less than BEACON_MIN_GAIN to gain), "outline" (the zone it
# makes, a polygon at the loop's sample angles)}. Used for the real stretch and for the preview, so they cannot
# disagree. Reused for BEACON_PLAN_SECONDS while the aim and head count are unchanged.
func plan_toward(aim: Vector3) -> Dictionary:
	var lim := Config.BORDER_MAP_LIMIT
	var spot := Vector3(clampf(aim.x, -lim, lim), 0.0, clampf(aim.z, -lim, lim))
	var to := Vector2(spot.x - b.centre.x, spot.z - b.centre.z)
	var key := Vector3(roundf(to.angle() * 100.0), roundf(to.length() * 4.0), float(_people))
	if not _plan.is_empty() and key == _plan_key and _clock - _plan_at < Config.BEACON_PLAN_SECONDS:
		return _plan
	var radius := circle_radius(_people)
	var wanted := to.length()
	var cap := max_distance()
	var reach := minf(wanted, cap)
	var reason := ""
	if wanted > cap:
		reason = Config.BEACON_FAR_TEXT
	var clear := _clear_reach(to.angle(), radius, reach)
	var refused := false
	if clear < reach:
		reach = clear
		reason = Config.BEACON_DIM_TEXT
		refused = reach < radius + Config.BEACON_MIN_GAIN
	_plan_key = key
	_plan_at = _clock
	_plan = {
		"reach": reach,
		"dir": to.angle(),
		"radius": radius,
		"reason": reason,
		"refused": refused,
		"outline": outline(Vector2(b.centre.x, b.centre.z), radius, reach, to.angle())
	}
	return _plan


# The farthest reach up to `upto` (toward angle `ang`) whose zone, for a circle of `radius`, leaves BEACON_DIM_CLEARANCE
# round every dimmed person it would newly cover. Scans outward from the circle's edge in 24 steps and refines the
# first violation by bisection. Dimmed people already inside the loop are not counted.
func _clear_reach(ang: float, radius: float, upto: float) -> float:
	var near: Array[Vector2] = []  # x = distance from the centre, y = angle off the stretch
	var c2 := Vector2(b.centre.x, b.centre.z)
	for q: Vector2 in dimmed:
		var rel := q - c2
		var d := rel.length()
		if d > upto + Config.BEACON_DIM_CLEARANCE or Border.is_inside(b.polygon, q):
			continue
		near.append(Vector2(d, absf(wrapf(rel.angle() - ang, -PI, PI))))
	if near.is_empty() or upto <= radius:
		return upto
	var steps := 24
	var prev := radius
	for i: int in range(1, steps + 1):
		var reach := lerpf(radius, upto, float(i) / float(steps))
		if _swallows(near, radius, reach):
			var lo := prev
			var hi := reach
			for _k: int in range(6):
				var mid := (lo + hi) * 0.5
				if _swallows(near, radius, mid):
					hi = mid
				else:
					lo = mid
			return lo
		prev = reach
	return upto


# True when the zone for `reach` covers (or comes within the clearance of) any of the dimmed people in `near`.
func _swallows(near: Array[Vector2], radius: float, reach: float) -> bool:
	var body := body_for(radius, reach)
	for q: Vector2 in near:
		var r := hull_radius(body, Config.BEACON_TIP_WIDTH * body, reach, q.y)
		if r > 0.0 and r + Config.BEACON_DIM_CLEARANCE > q.x:
			return true
	return false


# The body circle's radius when the loop (whose length is fixed by the people: TAU x `radius`) is a teardrop that
# reaches `reach` from the centre. `radius` when the tip does not pass the circle; never below BEACON_BODY_MIN x
# `radius`.
static func body_for(radius: float, reach: float) -> float:
	var key := int(radius * 50.0) * 100000 + int(reach * 20.0)
	if _body_cache.has(key):
		return _body_cache[key]
	var budget := TAU * radius
	var out := radius
	if hull_perimeter(radius, Config.BEACON_TIP_WIDTH * radius, reach) > budget:
		var lo := radius * Config.BEACON_BODY_MIN
		var hi := radius
		for _i: int in range(16):
			var mid := (lo + hi) * 0.5
			if hull_perimeter(mid, Config.BEACON_TIP_WIDTH * mid, reach) > budget:
				hi = mid
			else:
				lo = mid
		out = lo
	if _body_cache.size() > 2000:
		_body_cache.clear()
	_body_cache[key] = out
	return out


# The zone a stretch of `reach` toward angle `ang` makes round `c`, as a polygon with one point at each of the loop's
# sample angles (Config.BORDER_SAMPLES), for a plain circle of `radius`: the body, or the teardrop where it is larger.
static func outline(c: Vector2, radius: float, reach: float, ang: float) -> PackedVector2Array:
	var body := body_for(radius, reach)
	var pts := PackedVector2Array()
	for i: int in range(Config.BORDER_SAMPLES):
		var a := TAU * float(i) / float(Config.BORDER_SAMPLES)
		var r := maxf(body, hull_radius(body, Config.BEACON_TIP_WIDTH * body, reach, absf(wrapf(a - ang, -PI, PI))))
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts


# Moves the tip for this frame (called from Border.update before the loop is built).
func update(rescued: Array[Person], delta: float) -> void:
	_people = rescued.size()
	_clock += delta
	if not b.formed:
		_form(rescued, delta)
		return
	if not stretching:
		return
	var goal := target()
	var step := Config.BEACON_PULL_SPEED * delta
	if _fell_back(goal, plan_toward(beacon)):
		return
	if not holding:
		var to := goal - tip
		if to.length() <= maxf(step, Config.BEACON_ARRIVE_RADIUS):
			tip = goal
			holding = true
			hold_left = Config.BEACON_STRETCH_HOLD
			b.beacon_reached.emit()
		else:
			tip += to.normalized() * step
		return
	if _flat_dist(b.centre, tip) > _flat_dist(b.centre, goal):
		# Round 21: the reach shrank (people lost, or dimmed people came near): the tip walks back, it does not jump.
		var back := goal - tip
		tip = goal if back.length() <= step else tip + back.normalized() * step
	hold_left -= delta
	if hold_left <= 0.0:
		_snap()


# Round 21: true (and the stretch ends with no snap) when a limit has pulled the goal back to within BEACON_MIN_GAIN of
# the circle's edge and the tip is there: there is no stretch left to hold. Emits Border.stretch_ended with the reason.
func _fell_back(goal: Vector3, plan: Dictionary) -> bool:
	var reason: String = plan["reason"]
	var radius: float = plan["radius"]
	if reason == "" or _flat_dist(b.centre, goal) >= radius + Config.BEACON_MIN_GAIN:
		return false
	if _flat_dist(b.centre, tip) > _flat_dist(b.centre, goal) + 0.3:
		return false  # Still walking back.
	clear()
	b.stretch_ended.emit(reason)
	return true


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
