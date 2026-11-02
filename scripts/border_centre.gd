class_name BorderCentre
extends RefCounted

# Round 19 / 20: where the border's centre is, and the spirit beacon that stretches it. Split out of border.gd (near
# its
# line cap).
# Before the border forms, the centre is the centroid of the rescued (and snaps to it the frame the border forms).
# From
# then on it is ANCHORED: the player standing at the edge, a push or a shove no longer moves it.
# Round 20: a beacon no longer walks the centre. It STRETCHES the zone: the body stays round the old centre and a tip
# reaches toward the beacon at Config.BEACON_PULL_SPEED (the loop becomes the hull of the body circle and a smaller
# tip
# circle, a teardrop; see hull_radius). The tip stops at the beacon or at the maximum reach (BEACON_REACH_BASE +
# BEACON_REACH_PER_PERSON x people rescued, past the circle's edge).
# Round 22 (shaped zone): there is no hold and no snap. When the tip arrives its arm is COMMITTED into `arms` (a list
# of
# (angle, reach from the centre); a stretch toward an existing arm updates it, at most BEACON_MAX_ARMS) and stays
# part of
# the zone. Each arm is drawn as the teardrop hull for the body radius of the moment (arm_ring), so when the body
# squeezes
# or grows the arms keep their reach and re-attach to it. The next stretch grows from the shaped zone (its tip starts
# at
# the existing arm). The people set how much border can be held: the loop length for them at normal spacing (a circle
# of
# circle_radius(people)). The body may squeeze to BEACON_BODY_MIN of that radius, so a stretch is limited, or refused
# with
# a reason, once the shape uses the length. When people are lost and the loop is over its length with the body at its
# minimum, pull_in() retreats the arms (the longest, thinnest tips first) until it fits.
# Border._organic_polygon takes the largest of the body, arm_ring() and stretch_radius() per ray, so the territory,
# ground, landmarks and slots all follow the shaped polygon.

# Round 21: body radius by (circle radius, reach), see body_for.
static var _body_cache: Dictionary = {}

# Where the beacon is (x, z, y = 0), or Vector3.INF when there is none.
var beacon := Vector3.INF
# True from placing a beacon until the tip arrives. The tip is where the stretch reaches now (x, z, y = 0).
var stretching: bool = false
var tip := Vector3.ZERO
# Round 22: the committed arms (x = angle, y = reach from the centre) and a counter that changes whenever they do (it
# keys the plan cache and the ring cache).
var arms: Array[Vector2] = []
var arm_version: int = 0
var b: Border
# Round 21: where the dimmed people are (x, z), set by Border.update every frame; the tip keeps clear of them.
var dimmed: Array[Vector2] = []
var _ring: Array[float] = []
var _no_ring: Array[float] = []
var _ring_key := Vector2.INF
var _radii_at_start: Array[float] = []
var _pulling: bool = false
var _pull_area0: float = 0.0
var _people: int = 0
var _cap_people: int = -1
var _cap_value: float = 0.0
var _clock: float = 0.0
# Round 24: the calm pull-in. The one arm that is retreating (its angle), the seconds it has been fading, and how far
# faded its outline is (0 to 1).
var _retreating: bool = false
var _retreat_angle: float = 0.0
var _fade_t: float = 0.0
var _fade_frac: float = 0.0
var _last_pull_notice: float = -1.0e9  # Round 23: one "pulling in" notice per quiet spell, not per person lost
# Round 21: the plan for the last aim asked about (see plan_toward), reused for BEACON_PLAN_SECONDS.
var _plan_key := Vector4.INF
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
	if not stretching:
		var dir := _flat_dir(b.centre, beacon)
		var have := maxf(b._mean_radius(), arm_reach_at(dir.angle(), b.body_radius))  # Round 22: grow from the shaped zone.
		var start := minf(minf(have, max_distance()), _flat_dist(b.centre, beacon))
		tip = Vector3(b.centre.x + dir.x * start, 0.0, b.centre.z + dir.y * start)
		stretching = true
		_radii_at_start = _polygon_radii()
	b.stretch_started.emit(beacon, target())


func clear() -> void:
	beacon = Vector3.INF
	stretching = false


# Where the tip is heading: toward the beacon, no farther than the plan allows (the maximum reach, and round 21 the
# dimmed people it must not swallow).
func target() -> Vector3:
	if not has_beacon():
		return tip
	var dir := _flat_dir(b.centre, beacon)
	var d: float = plan_toward(beacon)["reach"]
	return Vector3(b.centre.x + dir.x * d, 0.0, b.centre.z + dir.y * d)


# Round 21: what a stretch toward `aim` would do right now: {"reach" (how far the tip would get from the centre),
# "dir"
# (angle of the stretch), "radius" (the plain circle), "reason" ("" when nothing holds it back, else the plain-words
# reason it stops short), "refused" (dimmed people leave less than BEACON_MIN_GAIN to gain), "outline" (the zone it
# makes, a polygon at the loop's sample angles)}. Used for the real stretch and for the preview, so they cannot
# disagree. Reused for BEACON_PLAN_SECONDS while the aim and head count are unchanged.
func plan_toward(aim: Vector3) -> Dictionary:
	var lim := Config.BORDER_MAP_LIMIT
	var spot := Vector3(clampf(aim.x, -lim, lim), 0.0, clampf(aim.z, -lim, lim))
	var to := Vector2(spot.x - b.centre.x, spot.z - b.centre.z)
	var key := Vector4(roundf(to.angle() * 100.0), roundf(to.length() * 4.0), float(_people), float(arm_version))
	if not _plan.is_empty() and key == _plan_key and _clock - _plan_at < Config.BEACON_PLAN_SECONDS:
		return _plan
	var radius := circle_radius(_people)
	var wanted := to.length()
	var cap := max_distance()
	var acap := cap
	if not arms.is_empty():
		acap = minf(cap, arm_cap(to.angle(), radius, cap))
	var reach := minf(wanted, acap)
	var reason := ""
	# Round 23: a far aim is not refused. Past the most the people allow the zone just goes that far (no reason); only
	# a shape that has run out of length is limited, and that says what to do.
	if wanted > acap and acap < cap - 0.05:
		reason = Config.BEACON_FULL_TEXT
	var have := maxf(radius, arm_reach_at(to.angle(), radius))
	var clear := _clear_reach(to.angle(), radius, reach)
	if clear < reach:
		reach = clear
		reason = Config.BEACON_DIM_TEXT
	var refused := reach < have + Config.BEACON_MIN_GAIN
	if refused and reason == "":
		reason = Config.BEACON_INSIDE_TEXT
	_plan_key = key
	_plan_at = _clock
	_plan = {
		"reach": reach,
		"dir": to.angle(),
		"radius": radius,
		"have": have,
		"reason": reason,
		"refused": refused,
		"outline":
		outline(Vector2(b.centre.x, b.centre.z), radius, reach if reach >= have + 0.01 else 0.0, to.angle(), arms)
	}
	return _plan


# Round 22: the farthest reach toward `ang` (at most `upto`) the shaped zone can hold: the loop, with the arms already
# made, the body at BEACON_BODY_MIN and the new tip, may not be longer than the circle the people make. Bisection.
func arm_cap(ang: float, radius: float, upto: float) -> float:
	var body := radius * Config.BEACON_BODY_MIN
	var budget := budget_of(radius)
	if profile_perimeter(profile(body, arms, 0.0, ang)) > budget:
		return 0.0  # The arms alone already use the length.
	if profile_perimeter(profile(body, arms, upto, ang)) <= budget:
		return upto
	var lo := 0.0
	var hi := upto
	for _i: int in range(14):
		var mid := (lo + hi) * 0.5
		if profile_perimeter(profile(body, arms, mid, ang)) <= budget:
			lo = mid
		else:
			hi = mid
	return lo


# The loop length the people can hold (the circle of `radius`, as the sampled polygon measures it).
static func budget_of(radius: float) -> float:
	return float(Config.BORDER_SAMPLES) * 2.0 * radius * sin(PI / float(Config.BORDER_SAMPLES))


# Per ray: the largest of the body circle, the arms' teardrops and the new tip's teardrop (reach `reach` toward
# `ang`; none
# when `reach` does not pass the body), all drawn for body radius `body`.
static func profile(body: float, arm_list: Array[Vector2], reach: float, ang: float) -> Array[float]:
	var n := Config.BORDER_SAMPLES
	var out: Array[float] = []
	out.resize(n)
	out.fill(body)
	for a: Vector2 in arm_list:
		_add_hull(out, body, a.y, a.x)
	_add_hull(out, body, reach, ang)
	return out


# Raises `out` (a radius per sample ray) to the teardrop of a tip `reach` away toward `ang`, for body radius `body`.
static func _add_hull(out: Array[float], body: float, reach: float, ang: float) -> void:
	var width := Config.BEACON_TIP_WIDTH * body
	var c := reach - width
	if c <= body - width + 0.001:
		return
	var beta := acos((body - width) / c)
	var n := out.size()
	for i: int in range(n):
		var off := absf(wrapf(TAU * float(i) / float(n) - ang, -PI, PI))
		if off < beta:
			var r := hull_radius(body, width, reach, off)
			if r > out[i]:
				out[i] = r


# The length of the closed loop whose points sit at radii `radii` on the sample rays.
static func profile_perimeter(radii: Array[float]) -> float:
	var n := radii.size()
	var k := cos(TAU / float(n))
	var total := 0.0
	for i: int in range(n):
		var r0 := radii[i]
		var r1 := radii[(i + 1) % n]
		total += sqrt(maxf(r0 * r0 + r1 * r1 - 2.0 * r0 * r1 * k, 0.0))
	return total


# The body radius for the shaped zone: `radius` when the loop fits, else squeezed (never below BEACON_BODY_MIN x
# radius)
# until the loop with the arms and a new tip of `reach` toward `ang` is as long as the people can hold.
static func body_for_arms(radius: float, arm_list: Array[Vector2], reach: float, ang: float) -> float:
	var budget := budget_of(radius)
	if profile_perimeter(profile(radius, arm_list, reach, ang)) <= budget:
		return radius
	var lo := radius * Config.BEACON_BODY_MIN
	var hi := radius
	for _i: int in range(14):
		var mid := (lo + hi) * 0.5
		if profile_perimeter(profile(mid, arm_list, reach, ang)) > budget:
			hi = mid
		else:
			lo = mid
	return lo


# The arms' radius on each sample ray for body radius `body` (empty with no arms). Cached until the body moves by
# 0.05 m
# or an arm changes, so the per-frame cost is a compare.
func arm_ring(body: float) -> Array[float]:
	if arms.is_empty():
		return _no_ring
	var key := Vector2(roundf(body * 20.0), float(arm_version))
	if key != _ring_key:
		_ring_key = key
		_ring = profile(body, arms, 0.0, 0.0)
	return _ring


# How far the arms reach along `ang` for body radius `body` (0 when there is none there).
func arm_reach_at(ang: float, body: float) -> float:
	var best := 0.0
	var bd := maxf(body, 0.1)
	for a: Vector2 in arms:
		var off := absf(wrapf(ang - a.x, -PI, PI))
		best = maxf(best, hull_radius(bd, Config.BEACON_TIP_WIDTH * bd, a.y, off))
	return best


func has_arms() -> bool:
	return not arms.is_empty()


# The area of a closed polygon (shoelace), square metres.
static func polygon_area(pts: PackedVector2Array) -> float:
	var n := pts.size()
	var total := 0.0
	for i: int in range(n):
		total += pts[i].cross(pts[(i + 1) % n])
	return absf(total) * 0.5


# The farthest reach up to `upto` (toward angle `ang`) whose zone, for a circle of `radius`, leaves
# BEACON_DIM_CLEARANCE
# round every dimmed person it would newly cover. Scans outward from the circle's edge in 24 steps and refines the
# first violation by bisection. Dimmed people already inside the loop are not counted.
func _clear_reach(ang: float, radius: float, upto: float) -> float:
	var near: Array[Vector2] = []  # x = distance from the centre, y = angle off the stretch
	var c2 := Vector2(b.centre.x, b.centre.z)
	for q: Vector2 in dimmed:
		var rel := q - c2
		var d := rel.length()
		if d > upto + Config.BEACON_DIM_CLEARANCE or BorderShape.is_inside(b.polygon, q):
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
static func outline(
	c: Vector2, radius: float, reach: float, ang: float, arm_list: Array[Vector2] = []
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var radii: Array[float]
	if arm_list.is_empty():
		radii = profile(body_for(radius, reach), arm_list, reach, ang)
	else:
		radii = profile(body_for_arms(radius, arm_list, reach, ang), arm_list, reach, ang)
	for i: int in range(Config.BORDER_SAMPLES):
		var a := TAU * float(i) / float(Config.BORDER_SAMPLES)
		pts.append(c + Vector2(cos(a), sin(a)) * radii[i])
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
	var to := goal - tip
	if to.length() <= maxf(step, Config.BEACON_ARRIVE_RADIUS):
		tip = goal
		_arrive()
	else:
		# Toward the goal; round 21: when the reach shrank (people lost, dimmed people near) this walks the tip back.
		tip += to.normalized() * step


# Round 21: true (and the stretch ends) when a limit has pulled the goal back to within BEACON_MIN_GAIN of what the
# zone
# already has there and the tip is there: there is no stretch left. Emits Border.stretch_ended with the reason.
func _fell_back(goal: Vector3, plan: Dictionary) -> bool:
	var reason: String = plan["reason"]
	var have: float = plan["have"]
	if (
		reason == ""
		or reason == Config.BEACON_INSIDE_TEXT
		or _flat_dist(b.centre, goal) >= have + Config.BEACON_MIN_GAIN
	):
		return false
	if _flat_dist(b.centre, tip) > _flat_dist(b.centre, goal) + 0.3:
		return false  # Still walking back.
	clear()
	b.stretch_ended.emit(reason)
	return true


# Round 22: the tip has arrived. Its arm joins the zone for good (no hold, no snap) and the beacon clears. An arm
# already
# within BEACON_ARM_MERGE radians of it is updated instead (the farther reach wins); more than BEACON_MAX_ARMS drops
# the
# shortest.
func _arrive() -> void:
	var to := Vector2(tip.x - b.centre.x, tip.z - b.centre.z)
	var body := b.body_radius if b.body_radius > 0.0 else b._mean_radius()
	if to.length() > body * 1.05:
		var merged := false
		for i: int in range(arms.size()):
			if absf(wrapf(arms[i].x - to.angle(), -PI, PI)) < Config.BEACON_ARM_MERGE:
				if to.length() >= arms[i].y:
					arms[i] = Vector2(to.angle(), to.length())
				merged = true
				break
		if not merged:
			arms.append(Vector2(to.angle(), to.length()))
			if arms.size() > Config.BEACON_MAX_ARMS:
				var shortest := 0
				for i: int in range(arms.size()):
					if arms[i].y < arms[shortest].y:
						shortest = i
				arms.remove_at(shortest)
		arm_version += 1
	var gain := new_ground(_radii_at_start, _polygon_radii())
	var at := tip
	clear()
	b.beacon_reached.emit()
	b.zone_grew.emit(gain, at, to.angle())


# The loop's radius on each sample ray now (empty when there is no loop).
func _polygon_radii() -> Array[float]:
	var out: Array[float] = []
	var c2 := Vector2(b.centre.x, b.centre.z)
	for pt: Vector2 in b.polygon:
		out.append(pt.distance_to(c2))
	return out


# The ground the zone newly covers, square metres: the part of the zone `after` that lies outside the zone `before`
# (both
# radii per sample ray). The loop's length is fixed by the people, so a stretch trades body for arm and the area
# alone would
# hardly change; this counts only what is new.
static func new_ground(before: Array[float], after: Array[float]) -> float:
	var n := mini(before.size(), after.size())
	var total := 0.0
	for i: int in range(n):
		total += maxf(after[i] * after[i] - before[i] * before[i], 0.0)
	return total * 0.5 * TAU / float(maxi(n, 1))


# Round 22: the loop is longer than the people can hold and the body is already at its smallest, so the arms retreat
# toward the body. Round 24: ONE arm at a time, the longest first. Its outline fades for BEACON_PULL_FADE_SECONDS, then
# it walks in at BEACON_PULL_CALM_RATE and is gone when it reaches the body; the next arm starts only after that. The
# harder the loop is over the length the people can hold (`over`, the loop's length as a share of that length), the
# shorter the fade and the faster the walk (up to BEACON_PULL_URGENT_MULT times at BEACON_PULL_URGENT_RATIO), so the
# spacing stays under BORDER_MAX_GAP where it can. `body` is the body's mean radius. Border calls this while the loop is
# over, and settled() when it is not.
func pull_in(delta: float, body: float, over: float = 1.0) -> void:
	if arms.is_empty():
		return
	if not _pulling:
		_pulling = true
		_pull_area0 = polygon_area(b.polygon)
		if _clock - _last_pull_notice >= Config.BEACON_PULL_IN_NOTICE_GAP:
			_last_pull_notice = _clock
			b.zone_pulling_in.emit()
	var calm_over := 1.0 + Config.BEACON_PULL_IN_TOLERANCE
	var pressure := clampf(inverse_lerp(calm_over, Config.BEACON_PULL_URGENT_RATIO, over), 0.0, 1.0)
	var idx := _arm_at(_retreat_angle) if _retreating else -1
	if idx < 0:
		idx = _longest_arm(body)
		_retreating = true
		_retreat_angle = arms[idx].x
		_fade_t = 0.0
	var fade_total := Config.BEACON_PULL_FADE_SECONDS * (1.0 - pressure)
	_fade_t += delta
	_fade_frac = 1.0 if fade_total <= 0.0 else clampf(_fade_t / fade_total, 0.0, 1.0)
	if _fade_t < fade_total:
		return
	var rate := Config.BEACON_PULL_CALM_RATE * lerpf(1.0, Config.BEACON_PULL_URGENT_MULT, pressure)
	var ex := arms[idx].y - body - rate * delta
	if ex > 0.1:
		arms[idx] = Vector2(arms[idx].x, body + ex)
	else:
		arms.remove_at(idx)
		_retreating = false
		_fade_frac = 0.0
	arm_version += 1


# The loop is back within its length: an episode of pulling in (if any) is over.
func settled() -> void:
	_retreating = false
	_fade_frac = 0.0
	if not _pulling:
		return
	_pulling = false
	b.zone_shrunk.emit(maxf(_pull_area0 - polygon_area(b.polygon), 0.0))


# Round 24: the index of the arm at `angle` (the one chosen to retreat), or -1 when it is gone.
func _arm_at(angle: float) -> int:
	for i: int in range(arms.size()):
		if absf(wrapf(arms[i].x - angle, -PI, PI)) < 0.001:
			return i
	return -1


# Round 24: the arm that reaches furthest past the body.
func _longest_arm(body: float) -> int:
	var best := 0
	for i: int in range(1, arms.size()):
		if arms[i].y - body > arms[best].y - body:
			best = i
	return best


# Round 24: true while one arm is retreating (fading, then walking in).
func is_retreating() -> bool:
	return _retreating


# Round 24: the retreating arm's angle (meaningful while is_retreating()).
func retreat_angle() -> float:
	return _retreat_angle


# Round 24: the outline alpha of the segment `a` to `b` (world x, z): 1 normally; the retreating arm's own stretch
# fades toward BEACON_PULL_FADE_ALPHA, softest at the sides. Cheap (a compare) when nothing is retreating.
func outline_alpha(p0: Vector2, p1: Vector2) -> float:
	if not _retreating or _fade_frac <= 0.0:
		return 1.0
	var d := (p0 + p1) * 0.5 - Vector2(b.centre.x, b.centre.z)
	if d.length() <= b.body_radius * 1.02:
		return 1.0
	var off := absf(wrapf(d.angle() - _retreat_angle, -PI, PI))
	if off >= Config.BEACON_PULL_FADE_ANGLE:
		return 1.0
	var weight := 1.0 - off / Config.BEACON_PULL_FADE_ANGLE
	return lerpf(1.0, Config.BEACON_PULL_FADE_ALPHA, _fade_frac * weight)


# How far the stretch reaches along the ray at `angle` from the centre, for a body of radius `body`, or 0 when it adds
# nothing (no stretch, or the ray falls inside the body circle).
func stretch_radius(angle: float, body: float) -> float:
	if not stretching:
		return 0.0
	var to := Vector2(tip.x - b.centre.x, tip.z - b.centre.z)
	return hull_radius(body, Config.BEACON_TIP_WIDTH * body, to.length(), absf(wrapf(angle - to.angle(), -PI, PI)))


# The teardrop: the convex hull of the body circle (radius `body`, round the origin) and a tip circle of radius
# `width`
# whose far edge is `reach` from the origin. Returns its radius along a ray `off` radians from the tip's direction,
# or 0
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


# Before the border exists: the centre is the centroid of the rescued (a post counts like BORDER_POST_WORTH people).
# The
# first rescue sets it, it follows at BORDER_CENTRE_FOLLOW, and it snaps to the centroid on the frame the border
# forms.
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
