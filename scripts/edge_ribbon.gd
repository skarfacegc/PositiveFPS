class_name EdgeRibbon
extends RefCounted

# Round 25 (edge cleanup): the border drawn as ribbons. The pure maths lives here and both border looks only turn the
# result into a mesh. 0.4 (#56): the ribbon follows the traced line itself (Border.polygon), point by point.
#  - A wall (a held block's face, the map's edge) is drawn honey-coloured and never strains; a gate is gold.
#  - A break (a stretch the push opened) is NOT joined: the ribbon really breaks there.
#  - Strain (0 flat .. 1 at the break depth) sets the colour (gold, amber, coral) and the width (thinner near
#    breaking). Round 26: it is how far the gate is bent at the point (BorderPush.bend_of_point).
# `build` returns EdgeStrips, one per unbroken run (a line with no break is one closed strip).


# Strain per member (Person -> 0..1): how far the line is bent at them, 1 while they wobble.
static func strain_map(border: Border) -> Dictionary[Person, float]:
	var out: Dictionary[Person, float] = {}
	for m: Person in border.members:
		out[m] = 1.0 if m.wobbling else border.push.bend_at(m.position)
	return out


# The ribbon's strips. With `gates_only` (the styled look, #58) the walls are left out like breaks: a wall is drawn by
# the look as a hedge instead, so the ribbon is the gates alone.
static func build(border: Border, gates_only: bool = false) -> Array[EdgeStrip]:
	var strips: Array[EdgeStrip] = []
	var n := border.polygon.size()
	if not border.active or n < 3:
		return strips
	var gaps := 0
	for j: int in range(n):
		if _skipped(border, j, gates_only):
			gaps += 1
	var cur := EdgeStrip.new()
	if gaps == 0:
		for j: int in range(n):
			_add_point(border, cur, j)
		_finish(strips, cur, true)
	else:
		# Start just after a break, so no strip is split across the start.
		var first := 0
		for j: int in range(n):
			if _skipped(border, posmod(j - 1, n), gates_only) and not _skipped(border, j, gates_only):
				first = j
				break
		for step: int in range(n):
			var j := (first + step) % n
			if _skipped(border, j, gates_only):
				_finish(strips, cur, false)
				cur = EdgeStrip.new()
				continue
			if cur.size() == 0:
				_add_point(border, cur, j)
			_add_point(border, cur, (j + 1) % n)
		_finish(strips, cur, false)
	for s: EdgeStrip in strips:
		_densify(s)
	return strips


# True when segment `j` is not drawn: a break, or (with `gates_only`) a wall.
static func _skipped(border: Border, j: int, gates_only: bool) -> bool:
	return border.segment_is_gap(j) or (gates_only and border.is_wall(j))


# Adds polygon point `j` to strip `s`: its strain from the dent there, and how much of it is wall.
static func _add_point(border: Border, s: EdgeStrip, j: int) -> void:
	var n := border.polygon.size()
	var wall := (1.0 if border.is_wall(posmod(j - 1, n)) else 0.0) + (1.0 if border.is_wall(j) else 0.0)
	s.add(border.polygon[j], border.push.bend_of_point(j), wall * 0.5, 1.0)


# Width of a ribbon point: full when healthy, EDGE_RIBBON_THIN of it at full strain.
static func width_for(strain: float) -> float:
	var t := smoothstep(0.45, 1.0, strain)
	return BorderConfig.EDGE_RIBBON_WIDTH * lerpf(1.0, BorderConfig.EDGE_RIBBON_THIN, t)


# Colour of a ribbon point: gold, amber from about half strain, coral at full; a wall tends to honey.
static func colour_for(strain: float, seal: float = 0.0) -> Color:
	var c := BorderConfig.EDGE_RIBBON_GOLD
	if strain < 0.5:
		c = c.lerp(BorderConfig.EDGE_RIBBON_AMBER, smoothstep(0.1, 0.5, strain))
	else:
		c = BorderConfig.EDGE_RIBBON_AMBER.lerp(BorderConfig.EDGE_RIBBON_CORAL, smoothstep(0.5, 0.95, strain))
	return c.lerp(BorderConfig.EDGE_RIBBON_HONEY, seal * (1.0 - strain))


# Triangles for a set of strips as mesh arrays (Mesh.ARRAY_*), flat at height `y`, `alpha` on every colour. `halo`
# widens the quad beyond the ribbon (the styled look's halo widens it): UV.x runs -1 to 1 across and UV2.x is the share
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
	return lerpf(BorderConfig.EDGE_RIBBON_CAP, 1.0, float(span) / 2.0)


static func _finish(strips: Array[EdgeStrip], s: EdgeStrip, closed: bool) -> void:
	if s.size() < 2:
		return
	s.closed = closed
	strips.append(s)


# Splits any piece longer than EDGE_RIBBON_STEP so the colour and width change smoothly along it.
static func _densify(s: EdgeStrip) -> void:
	var m := s.size()
	var out := EdgeStrip.new()
	out.closed = s.closed
	var segs := m if s.closed else m - 1
	for i: int in range(segs):
		var j := (i + 1) % m
		var parts := maxi(1, ceili(s.pts[i].distance_to(s.pts[j]) / BorderConfig.EDGE_RIBBON_STEP))
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
