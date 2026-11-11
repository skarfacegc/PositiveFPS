class_name BorderPush
extends RefCounted

# Round 26, physical push; 0.4 (#56): it lives on gates. The only things that push the line are visible: dimmed people
# leaning on a gate from outside, and the night's surge (a wave of fog with figures in it) shoving the gate it meets and
# the gates beside it. Pressure (#12): a gate's break depth follows its members (Border.break_depth).
# Walls hold firm: nothing leans on them and they never dent. Everything is kept per point of the traced line (Border.
# polygon; a gate has a point every BorderConfig.GATE_POINT_STEP metres):
#  - force: what pushes there this frame (pushers spread along their gate as a bell, plus the surge's `wave`);
#  - dent: how far the gate is shoved inward there, in metres. It follows force x PUSH_DENT_PER_FORCE, deepening at
#    PUSH_GIVE_SPEED and springing back at PUSH_SPRING_SPEED when relieved;
#  - calm: joy at a bending member, or a burst, calms a spot: its force is cut and the gate springs back faster.
# Past PUSH_BREAK_DEPTH the gate snaps: a break (PUSH_BREAK_HALF points either side, never past the gate's own ends). A
# break is a gap that pushing made: Border marks its segments as gap, so dimmed people walk through. It mends when no
# dimmed person is near it and a member near it has had joy since it opened (or after PUSH_MEND_AUTO seconds clear).
# Border applies `dent` to the polygon it builds, so the line, the members' places and the painted land all follow.

var b: Border
# Metres the gate is shoved inward at each point.
var dent: Array[float] = []
# True at the points a break holds open.
var broken: Array[bool] = []
# Open breaks: {"at": point, "age": s, "joyed": bool, "clear": s without a dimmed person near}.
var breaks: Array[Dictionary] = []
# The surge's force at each point (set by GloomTide.update through set_gate_wave; cleared by clear_wave).
var wave: Array[float] = []
# Pushers leaning on a gate this frame, and the deepest dent now.
var pushers: int = 0
var deepest: float = 0.0
var _force: Array[float] = []
var _calm: Array[float] = []
var _seen_hits: Dictionary = {}


func _init(border: Border) -> void:
	b = border
	reset()


# Back to flat gates with nothing pushing (a new border, or no border).
func reset() -> void:
	resize(b.point_count())


# Fresh state for `n` points of the line.
func resize(n: int) -> void:
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


# The line was traced again (the zone changed): keeps dents, calm and breaks at the points that are still there.
func carry(old_pts: PackedVector2Array, new_pts: PackedVector2Array) -> void:
	var old_dent := dent.duplicate()
	var old_broken := broken.duplicate()
	var old_calm := _calm.duplicate()
	var old_breaks := breaks.duplicate(true)
	resize(new_pts.size())
	var lookup: Dictionary = {}
	for i: int in range(new_pts.size()):
		lookup[_key(new_pts[i])] = i
	for i: int in range(mini(old_pts.size(), old_dent.size())):
		var k: int = lookup.get(_key(old_pts[i]), -1)
		if k >= 0 and b.point_dentable(k):
			dent[k] = old_dent[i]
			broken[k] = old_broken[i]
			_calm[k] = old_calm[i]
	for br: Dictionary in old_breaks:
		var was: int = br["at"]
		var k: int = lookup.get(_key(old_pts[was]), -1) if was < old_pts.size() else -1
		if k >= 0 and b.point_dentable(k):
			br["at"] = k
			breaks.append(br)


func _key(p: Vector2) -> Vector2i:
	return Vector2i(roundi(p.x * 10.0), roundi(p.y * 10.0))


# Makes the arrays fit the line (after the line changed under a caller that holds no reference to it).
func _fit() -> void:
	if dent.size() != b.point_count():
		resize(b.point_count())


# The point of the line nearest to `pos`.
func sample_of(pos: Vector3) -> int:
	return b.nearest_point(Vector2(pos.x, pos.z))


# The surge pushes whole gates: `weights` maps a gate index to its share (1 for the gate it meets, less beside it) of
# `force`. Every other point of the line gets nothing.
func set_gate_wave(weights: Dictionary, force: float) -> void:
	_fit()
	for i: int in range(wave.size()):
		var g := b.point_gate(i)
		if not b.point_dentable(i) or not weights.has(g):
			wave[i] = 0.0
			continue
		var share: float = weights[g]
		wave[i] = force * share


func clear_wave() -> void:
	for i: int in range(wave.size()):
		wave[i] = 0.0


# How bent the line is at `pos`, 0 (flat) to 1 (at the break depth): what the ribbon colours and a member braces by.
func bend_at(pos: Vector3) -> float:
	if dent.is_empty():
		return 0.0
	return bend_of_point(sample_of(pos))


# How bent the line is at point `i`: its dent over the break depth of its gate (a thin gate is bent sooner).
func bend_of_point(i: int) -> float:
	if i < 0 or i >= dent.size():
		return 0.0
	return clampf(dent[i] / b.break_depth_at_point(i), 0.0, 1.0)


# True when polygon segment `j` lies in a break.
func segment_broken(j: int) -> bool:
	return j >= 0 and j < broken.size() and broken[j]


# One frame. Called by Border.update before the polygon is built, so the dent it makes is in this frame's polygon.
func update(people: Array[Person], delta: float, strength: float) -> void:
	_fit()
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


# Dimmed people outside a gate, close enough to lean on it, add their force at the point they stand at.
func _push_from_people(people: Array[Person], strength: float, delta: float) -> void:
	pushers = 0
	var sigma := PushConfig.PUSH_SPREAD_METRES / BorderConfig.GATE_POINT_STEP
	for p: Person in people:
		if p.is_rescued:
			continue
		var leaning := false
		if GloomSim.is_dimmed(p):
			leaning = _lean(p, strength, sigma, delta)
		if not leaning:
			p.brace = move_toward(p.brace, 0.0, PushConfig.PUSH_BRACE_SMOOTH * delta)


# Works out whether `p` leans on an intact gate; if so adds the force and sets their lean. Returns true then.
func _lean(p: Person, strength: float, sigma: float, delta: float) -> bool:
	var p2 := Vector2(p.position.x, p.position.z)
	if Geometry2D.is_point_in_polygon(p2, b.polygon):
		return false
	var near := b._nearest_on_loop(p2)
	var dist: float = near["dist"]
	var seg: int = near["seg"]
	if dist > PushConfig.PUSH_LEAN_RANGE or b.is_wall(seg) or segment_broken(seg):
		return false
	pushers += 1
	var force := PushConfig.PUSH_PER_PERSON * strength * p.push_mult * (1.0 - 0.4 * dist / PushConfig.PUSH_LEAN_RANGE)
	var who := b._nearest_member(p.position)
	if who != null:
		var share := clampf(who.joy / maxf(who.joy_needed(), 0.001), 0.0, 1.0)
		force *= 1.0 + PushConfig.PUSH_SOFT_BONUS * (1.0 - share)
	# The force spreads as a bell along the gate, measured in metres from where they lean (not from the nearest point, so
	# two people leaning side by side add up at the same spot however the points fall).
	var line_point: Vector2 = near["point"]
	var i := b.nearest_point(line_point)
	var gate := b.point_gate(i)
	var reach := ceili(3.0 * sigma)
	var n := dent.size()
	var metres := sigma * BorderConfig.GATE_POINT_STEP
	for off: int in range(-reach, reach + 1):
		var k := posmod(i + off, n)
		if b.point_gate(k) == gate:
			var d := b.polygon[k].distance_to(line_point)
			_force[k] += force * exp(-d * d / (2.0 * metres * metres))
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


# Calms the points within `spread` of the one nearest `pos` (a joy hit on a member, or a burst).
func calm_at(pos: Vector3, amount: float, spread: int) -> void:
	if _calm.is_empty():
		return
	var n := _calm.size()
	var i := sample_of(pos)
	for off: int in range(-spread, spread + 1):
		var k := posmod(i + off, n)
		_calm[k] = maxf(_calm[k], amount * (1.0 - 0.25 * float(absi(off))))


# A burst at `at` relieves the line within PUSH_BURST_REACH of it: the force there is cut and the gate springs back.
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
		if b.point_dentable(i):
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
		if dent[i] < b.break_depth_at_point(i) or broken[i] or _near_break(i):
			continue
		if b.gate_cannot_break(b.point_gate(i)):  # A defence: the gate bends but never snaps.
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
	var gate := b.point_gate(i)
	for off: int in range(-2 * PushConfig.PUSH_BREAK_HALF - 1, 2 * PushConfig.PUSH_BREAK_HALF + 2):
		var k := posmod(i + off, n)
		if broken[k] and b.point_gate(k) == gate:
			return true
	return false


# The points a break at `i` covers: PUSH_BREAK_HALF either side, but only those on the same gate.
func _span(i: int) -> Array[int]:
	var n := broken.size()
	var gate := b.point_gate(i)
	var out: Array[int] = []
	for off: int in range(-PushConfig.PUSH_BREAK_HALF, PushConfig.PUSH_BREAK_HALF + 1):
		var k := posmod(i + off, n)
		if b.point_gate(k) == gate:
			out.append(k)
	return out


func _open_break(i: int) -> void:
	for k: int in _span(i):
		broken[k] = true
	var br := {"at": i, "age": 0.0, "joyed": false, "clear": 0.0}
	breaks.append(br)
	var spot := _break_point(br)
	b.line_broke.emit(spot)


func _mend(k: int) -> void:
	var br: Dictionary = breaks[k]
	var i: int = br["at"]
	for at: int in _span(i):
		broken[at] = false
		dent[at] = minf(dent[at], b.break_depth_at_point(at) * 0.5)  # Mended: half sprung back, not at the limit.
	var spot := _break_point(br)
	var open_for: float = br["age"]
	breaks.remove_at(k)
	b.line_mended.emit(spot, open_for)


# Where a break is on the ground (the line's point at its middle).
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
	if dent.is_empty():
		return
	for m: Person in b.members:
		var out := b.out_at(m.position)
		m.brace_dir = Vector3(out.x, 0.0, out.y)
		var i := sample_of(m.position)
		var want := clampf(maxf(bend_of_point(i), _force[i] * 0.25), 0.0, 1.0)
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
