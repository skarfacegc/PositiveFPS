class_name BorderPush
extends RefCounted

# Round 26, physical push. The only things that push the border are visible: dimmed people leaning on the line from
# outside, and a gloom tide (a wave of fog with figures in it) shoving the side it rolls in from. Everything is kept per
# angle sample round the centre (RoundLoopConfig.BORDER_SAMPLES, the same samples the loop is built from):
#  - force: what pushes there this frame (pushers spread along the loop as a bell, plus the tide's `wave`);
#  - dent: how far the line is shoved inward there, in metres. It follows force x PUSH_DENT_PER_FORCE, deepening at
#    PUSH_GIVE_SPEED and springing back at PUSH_SPRING_SPEED when relieved;
#  - calm: joy at a bending member, or a burst, calms a spot: its force is cut and the line springs back faster.
# Past PUSH_BREAK_DEPTH the line snaps: a break (PUSH_BREAK_HALF samples either side). A break is a gap that pushing
# made: Border marks its polygon segments as gap, so dimmed people walk through. It mends when no dimmed person is near
# it and a member near it has had joy since it opened (or after PUSH_MEND_AUTO seconds clear; see Config).
# Border applies `dent` to the loop it builds, so the polygon, the members' slots and the painted land all follow.

var b: Border
# Metres the line is shoved inward at each sample.
var dent: Array[float] = []
# True at the samples a break holds open.
var broken: Array[bool] = []
# Open breaks: {"at": sample, "age": s, "joyed": bool, "clear": s without a dimmed person near}.
var breaks: Array[Dictionary] = []
# The tide's force at each sample (set by GloomTide.update through set_wave; cleared by clear_wave).
var wave: Array[float] = []
# Pushers leaning on the line this frame, and the deepest dent now.
var pushers: int = 0
var deepest: float = 0.0
var _force: Array[float] = []
var _calm: Array[float] = []
var _seen_hits: Dictionary = {}


func _init(border: Border) -> void:
	b = border
	reset()


# Back to a flat line with nothing pushing (a new border, or no border).
func reset() -> void:
	var n := RoundLoopConfig.BORDER_SAMPLES
	dent.clear()
	broken.clear()
	wave.clear()
	_force.clear()
	_calm.clear()
	for i: int in range(n):
		dent.append(0.0)
		broken.append(false)
		wave.append(0.0)
		_force.append(0.0)
		_calm.append(0.0)
	breaks.clear()
	_seen_hits.clear()
	pushers = 0
	deepest = 0.0


# The sample nearest the direction of `pos` from the border's centre.
func sample_of(pos: Vector3) -> int:
	var n := dent.size()
	return posmod(roundi(atan2(pos.z - b.centre.z, pos.x - b.centre.x) / TAU * float(n)), n)


# The tide pushes the samples within `half_width` of `angle` with up to `force` (a cosine taper to the sides).
func set_wave(angle: float, half_width: float, force: float) -> void:
	var n := wave.size()
	for i: int in range(n):
		var d := absf(angle_difference(TAU * float(i) / float(n), angle))
		wave[i] = force * cos(d / half_width * PI * 0.5) if d < half_width else 0.0


func clear_wave() -> void:
	for i: int in range(wave.size()):
		wave[i] = 0.0


# How bent the line is at `pos`, 0 (flat) to 1 (at the break depth): what the ribbon colours and a member braces by.
func bend_at(pos: Vector3) -> float:
	return clampf(dent[sample_of(pos)] / PushConfig.PUSH_BREAK_DEPTH, 0.0, 1.0)


# True when polygon segment `j` lies in a break.
func segment_broken(j: int) -> bool:
	return j >= 0 and j < broken.size() and broken[j]


# One frame. Called by Border.update before the loop is built, so the dent it makes is in this frame's polygon.
func update(people: Array[Person], delta: float, strength: float) -> void:
	var n := dent.size()
	for i: int in range(n):
		_force[i] = wave[i] * strength
	_push_from_people(people, strength, delta)
	_read_joy(delta)
	_move_dents(delta)
	_update_breaks(people, delta)
	_brace_members(delta)
	deepest = 0.0
	for i: int in range(n):
		deepest = maxf(deepest, dent[i])


# Dimmed people outside the line, close enough to lean on it, add their force at the sample they stand at.
func _push_from_people(people: Array[Person], strength: float, delta: float) -> void:
	pushers = 0
	var sigma := PushConfig.PUSH_SPREAD / (TAU / float(dent.size()))
	for p: Person in people:
		if p.is_rescued:
			continue
		var leaning := false
		if GloomSim.is_dimmed(p):
			leaning = _lean(p, strength, sigma, delta)
		if not leaning:
			p.brace = move_toward(p.brace, 0.0, PushConfig.PUSH_BRACE_SMOOTH * delta)


# Works out whether `p` leans on an intact stretch; if so adds the force and sets their lean. Returns true then.
func _lean(p: Person, strength: float, sigma: float, delta: float) -> bool:
	var p2 := Vector2(p.position.x, p.position.z)
	if Geometry2D.is_point_in_polygon(p2, b.polygon):
		return false
	var near := b._nearest_on_loop(p2)
	var dist: float = near["dist"]
	var seg: int = near["seg"]
	if dist > PushConfig.PUSH_LEAN_RANGE or b.is_sealed(seg) or segment_broken(seg):
		return false
	pushers += 1
	var force := PushConfig.PUSH_PER_PERSON * strength * p.push_mult * (1.0 - 0.4 * dist / PushConfig.PUSH_LEAN_RANGE)
	var who := b._nearest_member(p.position)
	if who != null:
		var share := clampf(who.joy / maxf(who.joy_needed(), 0.001), 0.0, 1.0)
		force *= 1.0 + PushConfig.PUSH_SOFT_BONUS * (1.0 - share)
	var i := sample_of(p.position)
	var reach := ceili(3.0 * sigma)
	var n := dent.size()
	for off: int in range(-reach, reach + 1):
		_force[posmod(i + off, n)] += force * exp(-float(off * off) / (2.0 * sigma * sigma))
	var line_point: Vector2 = near["point"]
	var to_line := line_point - p2
	if to_line.length() > 0.001:
		p.brace_dir = Vector3(to_line.x, 0.0, to_line.y).normalized()
	p.brace = move_toward(p.brace, clampf(force / 2.0, 0.3, 1.0), PushConfig.PUSH_BRACE_SMOOTH * delta)
	return true


# A member who has had joy since last frame calms their spot (and counts as mending the ends of a break near them).
func _read_joy(delta: float) -> void:
	var next: Dictionary = {}
	for m: Person in b.members:
		next[m] = m.joy_hits
		if not _seen_hits.has(m) or _seen_hits[m] == m.joy_hits:
			continue
		calm_at(m.position, PushConfig.PUSH_JOY_CALM, 2)
		for br: Dictionary in breaks:
			if _flat(m.position, _break_point(br)) <= PushConfig.PUSH_MEND_REACH:
				br["joyed"] = true
	_seen_hits = next
	for i: int in range(_calm.size()):
		_calm[i] = maxf(0.0, _calm[i] - delta / PushConfig.PUSH_CALM_SECONDS)


# Calms the samples within `spread` of the one nearest `pos` (a joy hit on a member, or a burst).
func calm_at(pos: Vector3, amount: float, spread: int) -> void:
	var n := _calm.size()
	var i := sample_of(pos)
	for off: int in range(-spread, spread + 1):
		var k := posmod(i + off, n)
		_calm[k] = maxf(_calm[k], amount * (1.0 - 0.25 * float(absi(off))))


# A burst at `at` relieves the line within PUSH_BURST_REACH of it: the force there is cut and the line springs back.
func relieve(at: Vector3) -> void:
	if not b.active:
		return
	var at2 := Vector2(at.x, at.z)
	for i: int in range(_calm.size()):
		if b.polygon.size() > i and b.polygon[i].distance_to(at2) <= PushConfig.PUSH_BURST_REACH:
			_calm[i] = maxf(_calm[i], PushConfig.PUSH_BURST_CALM)


func _move_dents(delta: float) -> void:
	for i: int in range(dent.size()):
		var calm := _calm[i]
		var cut := 1.0 - PushConfig.PUSH_CALM_CUT * calm
		var target := 0.0
		if not b.is_sealed(i):
			target = minf(_force[i] * cut * PushConfig.PUSH_DENT_PER_FORCE, PushConfig.PUSH_DENT_MAX)
		if target > dent[i]:
			dent[i] = minf(target, dent[i] + PushConfig.PUSH_GIVE_SPEED * delta)
		else:
			var spring := PushConfig.PUSH_SPRING_SPEED * lerpf(1.0, PushConfig.PUSH_CALM_SPRING, calm)
			dent[i] = maxf(target, dent[i] - spring * delta)


# New breaks where the dent passed the limit; open ones age and mend.
func _update_breaks(people: Array[Person], delta: float) -> void:
	var n := dent.size()
	for i: int in range(n):
		if dent[i] < PushConfig.PUSH_BREAK_DEPTH or broken[i] or _near_break(i):
			continue
		_open_break(i)
	for k: int in range(breaks.size() - 1, -1, -1):
		var br: Dictionary = breaks[k]
		var age: float = br["age"]
		var clear: float = br["clear"]
		br["age"] = age + delta
		clear = 0.0 if _dimmed_near(people, _break_point(br)) else clear + delta
		br["clear"] = clear
		var joyed: bool = br["joyed"] or not PushConfig.PUSH_MEND_NEEDS_JOY
		if clear > 0.0 and (joyed or clear >= PushConfig.PUSH_MEND_AUTO):
			_mend(k)


func _near_break(i: int) -> bool:
	var n := broken.size()
	for off: int in range(-2 * PushConfig.PUSH_BREAK_HALF - 1, 2 * PushConfig.PUSH_BREAK_HALF + 2):
		if broken[posmod(i + off, n)]:
			return true
	return false


func _open_break(i: int) -> void:
	var n := broken.size()
	for off: int in range(-PushConfig.PUSH_BREAK_HALF, PushConfig.PUSH_BREAK_HALF + 1):
		broken[posmod(i + off, n)] = true
	var br := {"at": i, "age": 0.0, "joyed": false, "clear": 0.0}
	breaks.append(br)
	var spot := _break_point(br)
	b.line_broke.emit(spot)


func _mend(k: int) -> void:
	var br: Dictionary = breaks[k]
	var n := broken.size()
	var i: int = br["at"]
	for off: int in range(-PushConfig.PUSH_BREAK_HALF, PushConfig.PUSH_BREAK_HALF + 1):
		var at := posmod(i + off, n)
		broken[at] = false
		dent[at] = minf(dent[at], PushConfig.PUSH_BREAK_DEPTH * 0.5)  # Mended: half sprung back, not at the limit.
	var spot := _break_point(br)
	var open_for: float = br["age"]
	breaks.remove_at(k)
	b.line_mended.emit(spot, open_for)


# Where a break is on the ground (the loop's point at its middle sample).
func _break_point(br: Dictionary) -> Vector3:
	var i: int = br["at"]
	if i < b.polygon.size():
		return Vector3(b.polygon[i].x, 0.0, b.polygon[i].y)
	return b.centre


func _dimmed_near(people: Array[Person], spot: Vector3) -> bool:
	for p: Person in people:
		if not p.is_rescued and GloomSim.is_dimmed(p) and _flat(p.position, spot) <= PushConfig.PUSH_MEND_CLEAR:
			return true
	return false


func _flat(a: Vector3, c: Vector3) -> float:
	return Vector2(a.x - c.x, a.z - c.z).length()


# Members brace against the dent at their spot: lean outward, planted, struggling more as it deepens.
func _brace_members(delta: float) -> void:
	var step := PushConfig.PUSH_BRACE_SMOOTH * delta
	for m: Person in b.members:
		var out := Vector3(m.position.x - b.centre.x, 0.0, m.position.z - b.centre.z)
		if out.length() > 0.01:
			m.brace_dir = out.normalized()
		var i := sample_of(m.position)
		var want := clampf(maxf(dent[i] / PushConfig.PUSH_BREAK_DEPTH, _force[i] * 0.25), 0.0, 1.0)
		if broken[i]:
			want = 1.0
		m.brace = move_toward(m.brace, want, step)
	for m: Person in b.inner:
		m.brace = move_toward(m.brace, 0.0, step)


# The break points, for the pointer to an off-screen break and the recorder.
func break_points() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for br: Dictionary in breaks:
		out.append(_break_point(br))
	return out
