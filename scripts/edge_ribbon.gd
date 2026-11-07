class_name EdgeRibbon
extends RefCounted

# Round 25 (edge cleanup): the border drawn as ONE ribbon through its members, in the loop's order. The pure maths
# lives here and both border looks only turn the result into a mesh.
#  - Between two neighbouring members the ribbon follows the loop (so it bends round arms and runs along a sealed
#    map edge). A pair whose stretch is a gap is NOT joined: the ribbon really breaks there.
#  - Strain (0 healthy .. 1 at the falter line) sets the colour (gold, amber, coral) and the width (thinner near
#    breaking).
#  - Dents: a dimmed person pressing from outside bows the ribbon inward (drawn offset only, nobody moves), deeper
#    for a closer or bigger crowd.
# `build` returns EdgeStrips, one per unbroken run (a loop with no gap is one closed strip).


# One member as the ribbon sees them: the angle round the centre (0..TAU), the ground position and the strain.
class Stop:
	var key: float = 0.0
	var pos := Vector2.ZERO
	var strain: float = 0.0

	func _init(key_in: float, pos_in: Vector2, strain_in: float) -> void:
		key = key_in
		pos = pos_in
		strain = strain_in


# Strain per member (Person -> 0..1): the joy urgency, 1 while wobbling, raised by the warnings (a dimmed person
# pressing), 0 under a patch.
static func strain_map(border: Border) -> Dictionary[Person, float]:
	var out: Dictionary[Person, float] = {}
	var pressed: Dictionary[Person, float] = {}
	if border.patch != null:
		for w: Dictionary in border.patch.warnings:
			var who: Person = w.get("person")
			if who != null and is_instance_valid(who):
				var urgency: float = w["urgency"]
				pressed[who] = urgency
	for m: Person in border.members:
		if not is_instance_valid(m):
			continue
		var u := BorderWarning.joy_urgency(m)
		if pressed.has(m):
			u = maxf(u, pressed[m])
		if m.wobbling:
			u = 1.0
		if m.patch_mult < 1.0:
			u = 0.0
		out[m] = u
	return out


# The dimmed, unrescued people outside the loop close enough to press on it (their ground positions).
static func pressers(border: Border, people: Array[Person]) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not border.active or border.polygon.size() < 3:
		return out
	for p: Person in people:
		if p.is_rescued or not GloomSim.is_dimmed(p):
			continue
		var at := Vector2(p.position.x, p.position.z)
		if Geometry2D.is_point_in_polygon(at, border.polygon):
			continue
		if BorderShape.distance_to_line(border.polygon, at) <= Config.EDGE_DENT_RANGE:
			out.append(at)
	return out


# The ribbon's strips. `push` is the pressers() positions (may be empty).
static func build(border: Border, push: PackedVector2Array) -> Array[EdgeStrip]:
	var strips: Array[EdgeStrip] = []
	var n := border.polygon.size()
	if not border.active or n < 3:
		return strips
	var order := _ordered(border)
	var count := order.size()
	if count < 2:
		return strips
	# Pair k joins order[k] to order[k + 1]; flag the ones that are gaps.
	var gaps: Array[bool] = []
	var first_gap := -1
	for k: int in range(count):
		var g := _pair_is_gap(border, order[k].key, order[(k + 1) % count].key, n)
		gaps.append(g)
		if g and first_gap < 0:
			first_gap = k
	var cur := EdgeStrip.new()
	var start := 0 if first_gap < 0 else (first_gap + 1) % count
	for step: int in range(count):
		var k := (start + step) % count
		if gaps[k]:
			_finish(strips, cur, false)
			cur = EdgeStrip.new()
			continue
		_add_pair(border, cur, order[k], order[(k + 1) % count], n)
	_finish(strips, cur, first_gap < 0)
	var centre := Vector2(border.centre.x, border.centre.z)
	var hard := _hardness(border, push)
	for s: EdgeStrip in strips:
		_densify(s)
		_dent(s, push, hard, centre)
	return strips


# Width of a ribbon point: full when healthy, EDGE_RIBBON_THIN of it at full strain.
static func width_for(strain: float) -> float:
	var t := smoothstep(0.45, 1.0, strain)
	return Config.EDGE_RIBBON_WIDTH * lerpf(1.0, Config.EDGE_RIBBON_THIN, t)


# Colour of a ribbon point: gold, amber from about half strain, coral at full; a sealed stretch tends to honey.
static func colour_for(strain: float, seal: float = 0.0) -> Color:
	var c := Config.EDGE_RIBBON_GOLD
	if strain < 0.5:
		c = c.lerp(Config.EDGE_RIBBON_AMBER, smoothstep(0.1, 0.5, strain))
	else:
		c = Config.EDGE_RIBBON_AMBER.lerp(Config.EDGE_RIBBON_CORAL, smoothstep(0.5, 0.95, strain))
	return c.lerp(Config.EDGE_RIBBON_HONEY, seal * (1.0 - strain))


# Triangles for a set of strips as mesh arrays (Mesh.ARRAY_*), flat at height `y`, `alpha` on every colour. `halo`
# widens the quad beyond the ribbon (the styled look dithers it): UV.x runs -1 to 1 across and UV2.x is the share
# of that which is solid ribbon. Returns [] when there is nothing to draw.
static func mesh_arrays(strips: Array[EdgeStrip], y: float, alpha: float, halo: float = 1.0) -> Array:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for s: EdgeStrip in strips:
		_add_quads(s, y, alpha, halo, verts, cols, uvs)
	if verts.is_empty():
		return []
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var uv2s := PackedVector2Array()
	uv2s.resize(verts.size())
	uv2s.fill(Vector2(1.0 / halo, 0.0))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	return arrays


# Two triangles per piece of the strip: the left and right edge of the ribbon at each point, coloured by strain.
static func _add_quads(
	s: EdgeStrip,
	y: float,
	alpha: float,
	halo: float,
	verts: PackedVector3Array,
	cols: PackedColorArray,
	uvs: PackedVector2Array
) -> void:
	var m := s.size()
	if m < 2:
		return
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var col := PackedColorArray()
	var along := PackedFloat32Array()
	var dist := 0.0
	for i: int in range(m):
		var around := s.neighbours(i)
		var tangent := (around[1] - around[0]).normalized()
		var nrm := Vector2(-tangent.y, tangent.x)
		var w := width_for(s.strain[i])
		if not s.closed:
			w *= _cap(i, m)
		var half := w * 0.5 * halo
		left.append(Vector3(s.pts[i].x - nrm.x * half, y, s.pts[i].y - nrm.y * half))
		right.append(Vector3(s.pts[i].x + nrm.x * half, y, s.pts[i].y + nrm.y * half))
		var c := colour_for(s.strain[i], s.seal[i])
		c.a = alpha * s.fade[i]
		col.append(c)
		along.append(dist)
		if i + 1 < m or s.closed:
			dist += s.pts[i].distance_to(s.pts[(i + 1) % m])
	var segs := m if s.closed else m - 1
	for i: int in range(segs):
		var j := (i + 1) % m
		var dj := dist if j == 0 else along[j]
		var corner_idx: Array[int] = [i, i, j, j, i, j]
		var corner_side: Array[float] = [-1.0, 1.0, -1.0, -1.0, 1.0, 1.0]
		for q: int in range(6):
			var idx := corner_idx[q]
			var side := corner_side[q]
			verts.append(left[idx] if side < 0.0 else right[idx])
			cols.append(col[idx])
			uvs.append(Vector2(side, dj if idx == j else along[idx]))


# The share of the width at point `i` of an open strip: it tapers over its first and last two points.
static func _cap(i: int, m: int) -> float:
	var span := mini(i, m - 1 - i)
	if span >= 2:
		return 1.0
	return lerpf(Config.EDGE_RIBBON_CAP, 1.0, float(span) / 2.0)


# The members that stand on the loop, in order round the centre.
static func _ordered(border: Border) -> Array[Stop]:
	var out: Array[Stop] = []
	var strain := strain_map(border)
	for m: Person in border.members:
		if not is_instance_valid(m) or not m.is_rescued:
			continue
		var d := Vector2(m.position.x - border.centre.x, m.position.z - border.centre.z)
		var u: float = strain.get(m, 0.0)
		out.append(Stop.new(fposmod(atan2(d.y, d.x), TAU), Vector2(m.position.x, m.position.z), u))
	out.sort_custom(func(a: Stop, b: Stop) -> bool: return a.key < b.key)
	return out


# True when the loop between angle `ka` and the next member's angle `kb` is a gap (looked up at its middle).
static func _pair_is_gap(border: Border, ka: float, kb: float, n: int) -> bool:
	var span := kb - ka
	if span <= 0.0:
		span += TAU
	var mid := fposmod(ka + span * 0.5, TAU)
	return border.segment_is_gap(posmod(int(mid / TAU * float(n)), n))


# Adds the path from member `a` to member `b` (the loop's vertices between them) to strip `s`; the first member is only
# added when the strip is empty, so neighbouring pairs share their member.
static func _add_pair(border: Border, s: EdgeStrip, a: Stop, b: Stop, n: int) -> void:
	var poly := border.polygon
	var kb := b.key
	if kb <= a.key:
		kb += TAU
	var pts: Array[Vector2] = []
	var seals: Array[float] = []
	var fades: Array[float] = []
	var j0 := floori(a.key / TAU * float(n)) + 1
	var j1 := ceili(kb / TAU * float(n)) - 1
	for j: int in range(j0, j1 + 1):
		var jj := posmod(j, n)
		var seal := 1.0 if border.is_sealed(jj) or border.is_sealed(posmod(jj - 1, n)) else 0.0
		pts.append(poly[jj])
		seals.append(seal)
		fades.append(border.segment_fade(jj))
	var total := 0.0
	var prev := a.pos
	for q: Vector2 in pts:
		total += prev.distance_to(q)
		prev = q
	total += prev.distance_to(b.pos)
	if s.size() == 0:
		s.add(a.pos, a.strain, 0.0, border.segment_fade(posmod(floori(a.key / TAU * float(n)), n)))
	var run := 0.0
	prev = a.pos
	for i: int in range(pts.size()):
		run += prev.distance_to(pts[i])
		prev = pts[i]
		s.add(pts[i], lerpf(a.strain, b.strain, run / maxf(total, 0.001)), seals[i], fades[i])
	s.add(b.pos, b.strain, 0.0, border.segment_fade(posmod(floori(kb / TAU * float(n)), n)))


static func _finish(strips: Array[EdgeStrip], s: EdgeStrip, closed: bool) -> void:
	if s.size() < 2:
		return
	s.closed = closed
	if closed:
		# The last point is the first member again: drop it so the loop closes on itself.
		var last := s.size() - 1
		s.pts.remove_at(last)
		s.strain.remove_at(last)
		s.seal.remove_at(last)
		s.fade.remove_at(last)
	strips.append(s)


# Splits any piece longer than EDGE_RIBBON_STEP so a dent can bend it, and zeroes the dent depths.
static func _densify(s: EdgeStrip) -> void:
	var m := s.size()
	var out := EdgeStrip.new()
	out.closed = s.closed
	var segs := m if s.closed else m - 1
	for i: int in range(segs):
		var j := (i + 1) % m
		var parts := maxi(1, ceili(s.pts[i].distance_to(s.pts[j]) / Config.EDGE_RIBBON_STEP))
		for q: int in range(parts):
			var t := float(q) / float(parts)
			out.add(
				s.pts[i].lerp(s.pts[j], t),
				lerpf(s.strain[i], s.strain[j], t),
				lerpf(s.seal[i], s.seal[j], t),
				lerpf(s.fade[i], s.fade[j], t)
			)
	if not s.closed:
		out.add(s.pts[m - 1], s.strain[m - 1], s.seal[m - 1], s.fade[m - 1])
	s.pts = out.pts
	s.strain = out.strain
	s.seal = out.seal
	s.fade = out.fade
	s.dent = PackedFloat32Array()
	s.dent.resize(out.size())


# How hard each presser pushes (1 pressed against the line, 0 at the edge of the range), parallel to `push`.
static func _hardness(border: Border, push: PackedVector2Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for q: Vector2 in push:
		var d := BorderShape.distance_to_line(border.polygon, q)
		out.append(clampf(1.0 - d / Config.EDGE_DENT_RANGE, 0.0, 1.0))
	return out


# Bows each point inward by the pressers' summed push (a bell round each one), clamped to EDGE_DENT_MAX.
static func _dent(s: EdgeStrip, push: PackedVector2Array, hard: PackedFloat32Array, centre: Vector2) -> void:
	if push.is_empty():
		return
	var inv2 := 1.0 / (2.0 * Config.EDGE_DENT_WIDTH * Config.EDGE_DENT_WIDTH)
	var moved := s.pts.duplicate()
	for i: int in range(s.size()):
		var sum := 0.0
		for k: int in range(push.size()):
			sum += hard[k] * exp(-s.pts[i].distance_squared_to(push[k]) * inv2)
		if sum < 0.01:
			continue
		var around := s.neighbours(i)
		var tangent := (around[1] - around[0]).normalized()
		var nrm := Vector2(-tangent.y, tangent.x)
		if nrm.dot(centre - s.pts[i]) < 0.0:
			nrm = -nrm
		var depth := Config.EDGE_DENT_MAX * minf(sum, 1.0)
		s.dent[i] = depth
		moved[i] = s.pts[i] + nrm * depth
	s.pts = moved
