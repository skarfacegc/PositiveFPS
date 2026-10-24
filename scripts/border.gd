class_name Border
extends Node3D

# The living border (round 9). Rescued people organise themselves into a loop around a centre (the smoothed centroid of
# the rescued). The loop is built per variant (Config.BorderVariant):
#   CIRCLE: a circle sized from the rescued count.
#   ORGANIC: a radius per angle, pushed outward where each person was rescued, and wrapped around blocks.
#   PAINT_EDGE: the edge of the painted region around the rescued people.
# The rules after that are shared by all variants:
#   - the outermost rescued people are the border members, one per slot evenly spaced along the loop; the rest stand
#     inside (inner members). A stretch between members that is longer than BORDER_MAX_GAP is a gap.
#   - darkness outside cannot cross an intact stretch: it presses against the line and drains the nearest member.
#     Through a gap it can pass.
#   - inside the loop the ground is painted (see PaintedGround.set_region) and blocks are beautified (see Building).
#   - protection is the depth inside the loop (see cover_at).

# Inner members are placed on a golden-angle spiral, so they spread out without a random number.
const GOLDEN_ANGLE := 2.39996323

var variant: int = Config.BorderVariant.ORGANIC
var centre := Vector3.ZERO
# True once at least BORDER_MIN_PEOPLE are rescued. Below that there is no loop.
var active: bool = false
# True once the border has been active. After that, falling below BORDER_MIN_PEOPLE means the border fell.
var formed: bool = false
var perimeter: float = 0.0
# Distance between neighbouring border members, in metres (perimeter / border members).
var spacing: float = 0.0
var member_count: int = 0
var inner_count: int = 0
# The loop, as (x, z) points in order around the centre. Empty when there is no border.
var polygon := PackedVector2Array()
var members: Array[Person] = []
var inner: Array[Person] = []
# One entry per slot segment: true when that stretch is a gap.
var segment_gap: Array[bool] = []
var buildings: Array[Building] = []
var landmark_building: Building = null

var _ground: PaintedGround
var _line_node: MeshInstance3D
var _line_mesh: ImmediateMesh
var _line_mat: StandardMaterial3D
var _has_centre: bool = false
# Organic: the radius per angle before smoothing, and the size factor that eases toward the target perimeter.
var _raw_radii: Array[float] = []
var _scale: float = 1.0
# One entry per polygon segment (sample j runs from polygon[j] to polygon[j + 1]): true when it lies in a gap.
var _sample_gap: Array[bool] = []
# Cumulative arc length at each polygon point, plus the total at the end (so it has one more entry than polygon).
var _arc: Array[float] = []
# Where each rescued person should stand: Person -> Vector3.
var _targets: Dictionary = {}
var _time: float = 0.0
var _strength: float = 1.0
var _debug_on: bool = false
var _debug_labels: Array[Label3D] = []


# Gets the border ready: the ground it paints, the variant to build, and the line it draws.
func setup(ground: PaintedGround, chosen_variant: int) -> void:
	_ground = ground
	variant = chosen_variant
	_raw_radii.clear()
	for i: int in range(Config.BORDER_SAMPLES):
		_raw_radii.append(Config.BORDER_MIN_RADIUS)
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.vertex_color_use_as_albedo = true
	_line_mesh = ImmediateMesh.new()
	_line_node = MeshInstance3D.new()
	_line_node.mesh = _line_mesh
	add_child(_line_node)


# Registers a block the border can beautify. `half` is the half-size of its footprint in x and z.
func register_building(body: StaticBody3D, half: Vector2, is_landmark: bool) -> void:
	var b := Building.new()
	b.centre = Vector2(body.position.x, body.position.z)
	b.half = half
	b.is_landmark = is_landmark
	for child: Node in body.get_children():
		if child is MeshInstance3D:
			b.mat = (child as MeshInstance3D).material_override as StandardMaterial3D
	if b.mat != null:
		b.base_colour = b.mat.albedo_color
	buildings.append(b)
	if is_landmark:
		landmark_building = b


# Call every frame, before people move. Recomputes the centre, the loop, the slots and the gaps, moves the rescued
# people to their places, beautifies blocks, drains members from darkness outside and updates the ground and the line.
func update(people: Array[Person], delta: float, strength: float) -> void:
	_time += delta
	_strength = strength
	var rescued: Array[Person] = []
	for p: Person in people:
		if p.is_rescued:
			rescued.append(p)
	_update_centre(rescued, delta)
	var n := rescued.size()
	active = n >= Config.BORDER_MIN_PEOPLE
	if active:
		formed = true
		polygon = _build_polygon(n, delta)
	else:
		polygon = PackedVector2Array()
	_assign_members(rescued)
	_move_members(delta)
	_update_buildings(delta)
	_drain_darkness(people, delta, strength)
	_update_ground()
	_draw_lines()
	if _debug_on:
		_update_debug_labels()


# A rescued person was made. Organic borders push outward at the angle they were rescued from.
func on_rescue(p: Person) -> void:
	if variant != Config.BorderVariant.ORGANIC:
		return
	# The centre snaps to the rescued centroid on the next update (see _update_centre). Before that, the push is
	# measured from the person's own spot, so the first rescue does not pick the centre for the whole border.
	var origin := centre if _has_centre else Vector3(p.position.x, 0.0, p.position.z)
	var to := Vector2(p.position.x - origin.x, p.position.z - origin.z)
	var ang := atan2(to.y, to.x)
	for i: int in range(Config.BORDER_SAMPLES):
		var a := TAU * float(i) / float(Config.BORDER_SAMPLES)
		var d := wrapf(a - ang, -PI, PI)
		_raw_radii[i] += Config.BORDER_PUSH * exp(-d * d / (2.0 * Config.BORDER_PUSH_WIDTH * Config.BORDER_PUSH_WIDTH))


# A member relapsed: they step out from the centre and leave the border (the slots reshuffle on the next update).
func on_relapse(p: Person) -> void:
	var out := Vector3(p.position.x - centre.x, 0.0, p.position.z - centre.z)
	if out.length() < 0.01:
		out = Vector3.RIGHT
	p.position += out.normalized() * Config.BORDER_OUTWARD_STEP


# How protected a person at `pos` is by the border: 0 outside and on the line, 1 BORDER_EDGE_BAND metres inside.
func cover_at(pos: Vector3) -> float:
	if not active:
		return 0.0
	var p2 := Vector2(pos.x, pos.z)
	if not Geometry2D.is_point_in_polygon(p2, polygon):
		return 0.0
	return clampf(_distance_to_line(p2) / Config.BORDER_EDGE_BAND, 0.0, 1.0)


# True when the straight move from `a` to `b` crosses an intact stretch of the border.
func line_blocks(a: Vector3, b: Vector3) -> bool:
	return _first_crossing(Vector2(a.x, a.z), Vector2(b.x, b.z)) != null


# A dark person outside the border moves from `from` toward `to`. If the move crosses an intact stretch, it stops just
# short of the line. Otherwise (inside, or through a gap) the move is unchanged.
func clip_move(from: Vector3, to: Vector3) -> Vector3:
	if not active:
		return to
	var a2 := Vector2(from.x, from.z)
	var b2 := Vector2(to.x, to.z)
	if Geometry2D.is_point_in_polygon(a2, polygon):
		return to
	var hit: Variant = _first_crossing(a2, b2)
	if hit == null:
		return to
	var h: Vector2 = hit
	var dir := (b2 - a2).normalized()
	var stop_dist := maxf(0.0, a2.distance_to(h) - 0.05)
	var stop := a2 + dir * stop_dist
	return Vector3(stop.x, to.y, stop.y)


# The colour of polygon segment `j` right now: intact gold, or a flickering grey and red when it is a gap.
func segment_colour(j: int) -> Color:
	if segment_is_gap(j):
		return _gap_colour()
	return Config.BORDER_INTACT_COLOUR


func segment_is_gap(j: int) -> bool:
	return j >= 0 and j < _sample_gap.size() and _sample_gap[j]


func gap_count() -> int:
	var n := 0
	for g: bool in segment_gap:
		if g:
			n += 1
	return n


func landmark_beautified() -> bool:
	return landmark_building != null and landmark_building.beautified


func beautified_building_count() -> int:
	var n := 0
	for b: Building in buildings:
		if b.beautified:
			n += 1
	return n


# F3: shows a label per slot segment with its spacing (and GAP). debug_summary gives the counts.
func set_debug(on: bool) -> void:
	_debug_on = on
	if not on:
		for lbl: Label3D in _debug_labels:
			lbl.visible = false
	elif active:
		_update_debug_labels()


# How many debug labels are showing right now.
func visible_debug_label_count() -> int:
	var n := 0
	for lbl: Label3D in _debug_labels:
		if lbl.visible:
			n += 1
	return n


func debug_summary() -> String:
	if not active:
		return "border: none yet"
	return (
		"border %s, members %d, inner %d, spacing %.1f m, gaps %d, night x%.2f"
		% [Config.BORDER_VARIANT_NAMES[variant], member_count, inner_count, spacing, gap_count(), _strength]
	)


# ---- Pure shape rules (static, so tests can check them directly) -----------------------------------------------------


# The radius of a circle border for `n` rescued people: their count times the spacing, as a circle, within the limits.
static func circle_radius_for(n: int) -> float:
	return clampf(float(n) * Config.BORDER_TARGET_SPACING / TAU, Config.BORDER_MIN_RADIUS, Config.BORDER_MAX_RADIUS)


static func circle_polygon(c: Vector2, radius: float, samples: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(samples):
		var a := TAU * float(i) / float(samples)
		pts.append(c + Vector2(cos(a), sin(a)) * radius)
	return pts


# Total length of a closed loop of points.
static func perimeter_of(pts: PackedVector2Array) -> float:
	var total := 0.0
	var n := pts.size()
	for j: int in range(n):
		total += pts[j].distance_to(pts[(j + 1) % n])
	return total


# How many slots a loop of this perimeter holds (perimeter over the target spacing, rounded up).
static func slot_count_for(loop_perimeter: float) -> int:
	return ceili(loop_perimeter / Config.BORDER_TARGET_SPACING)


# One gap flag per slot segment. A segment is a gap if the spacing is too wide, or it touches an empty slot.
static func gap_flags(spacing_m: float, filled: Array[bool]) -> Array[bool]:
	var out: Array[bool] = []
	var m := filled.size()
	for k: int in range(m):
		var gap := spacing_m > Config.BORDER_MAX_GAP or not filled[k] or not filled[(k + 1) % m]
		out.append(gap)
	return out


# True when `p` is inside the loop.
static func is_inside(pts: PackedVector2Array, p: Vector2) -> bool:
	return pts.size() >= 3 and Geometry2D.is_point_in_polygon(p, pts)


# ---- Loop variants ---------------------------------------------------------------------------------------------------


func _build_polygon(n: int, delta: float) -> PackedVector2Array:
	var c2 := Vector2(centre.x, centre.z)
	if variant == Config.BorderVariant.CIRCLE:
		return circle_polygon(c2, circle_radius_for(n), Config.BORDER_SAMPLES)
	if variant == Config.BorderVariant.PAINT_EDGE:
		return _paint_edge_polygon(c2)
	return _organic_polygon(c2, n, delta)


# Organic: per angle, the smoothed radius times the size factor. A block on the ray that the radius reaches is wrapped:
# the sample jumps to just beyond the far side of the block, so buildings end up inside the loop.
func _organic_polygon(c2: Vector2, n: int, delta: float) -> PackedVector2Array:
	var smooth: Array[float] = _smoothed_radii()
	var pts := PackedVector2Array()
	for i: int in range(Config.BORDER_SAMPLES):
		var a := TAU * float(i) / float(Config.BORDER_SAMPLES)
		var dir := Vector2(cos(a), sin(a))
		var r: float = smooth[i] * _scale
		var block := _first_block_along(c2, dir)
		if block.x > 0.0 and block.x < r:
			r = maxf(r, block.y + 0.5)
		pts.append(c2 + dir * r)
	# Soft normalisation: ease the size so the perimeter moves toward n x spacing (never below the smallest circle).
	var raw := perimeter_of(pts)
	var smallest := perimeter_of(circle_polygon(c2, Config.BORDER_MIN_RADIUS, Config.BORDER_SAMPLES))
	var target := maxf(float(n) * Config.BORDER_TARGET_SPACING, smallest)
	if raw > 0.001:
		var desired := clampf(_scale * target / raw, 0.2, 5.0)
		_scale = lerpf(_scale, desired, clampf(delta / Config.BORDER_NORMALISE_SECONDS, 0.0, 1.0))
	return pts


# Paint edge: along each angle, the farthest point that is still in the painted region (weight above one half).
func _paint_edge_polygon(c2: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(Config.BORDER_SAMPLES):
		var a := TAU * float(i) / float(Config.BORDER_SAMPLES)
		var dir := Vector2(cos(a), sin(a))
		var t_last := 0.5
		var t := 0.5
		while t <= Config.BORDER_MAX_RADIUS:
			var w := 0.0
			if _ground != null:
				w = _ground.paint_weight_at(Vector3(c2.x + dir.x * t, 0.0, c2.y + dir.y * t))
			if w <= 0.5:
				break
			t_last = t
			t += 0.5
		pts.append(c2 + dir * t_last)
	return pts


# Organic: the radius per angle after a small circular blur (so one bump does not look like a spike).
func _smoothed_radii() -> Array[float]:
	var out: Array[float] = []
	var n := _raw_radii.size()
	for i: int in range(n):
		var prev := _raw_radii[(i - 1 + n) % n]
		var nxt := _raw_radii[(i + 1) % n]
		out.append((prev + 2.0 * _raw_radii[i] + nxt) / 4.0)
	return out


# The nearest block on the ray from `o` along `d` that lies in front of `o`: Vector2(entry, exit). entry is INF if none.
func _first_block_along(o: Vector2, d: Vector2) -> Vector2:
	var best := Vector2(INF, -INF)
	for b: Building in buildings:
		var hit := _ray_box(o, d, b.centre - b.half, b.centre + b.half)
		if hit.x == INF or hit.y <= 0.0:
			continue
		if hit.x < best.x:
			best = hit
	return best


# Ray against an axis-aligned box in 2D. Returns Vector2(entry, exit) along the ray, or Vector2(INF, -INF) for a miss.
static func _ray_box(o: Vector2, d: Vector2, lo: Vector2, hi: Vector2) -> Vector2:
	var miss := Vector2(INF, -INF)
	var tmin := -INF
	var tmax := INF
	if absf(d.x) < 1e-9:
		if o.x < lo.x or o.x > hi.x:
			return miss
	else:
		var tx1 := (lo.x - o.x) / d.x
		var tx2 := (hi.x - o.x) / d.x
		tmin = maxf(tmin, minf(tx1, tx2))
		tmax = minf(tmax, maxf(tx1, tx2))
	if absf(d.y) < 1e-9:
		if o.y < lo.y or o.y > hi.y:
			return miss
	else:
		var tz1 := (lo.y - o.y) / d.y
		var tz2 := (hi.y - o.y) / d.y
		tmin = maxf(tmin, minf(tz1, tz2))
		tmax = minf(tmax, maxf(tz1, tz2))
	if tmax < tmin or tmax < 0.0:
		return miss
	return Vector2(tmin, tmax)


# Distance from `p2` to the nearest point on the loop.
func _distance_to_line(p2: Vector2) -> float:
	var best := INF
	var n := polygon.size()
	for j: int in range(n):
		var closest := Geometry2D.get_closest_point_to_segment(p2, polygon[j], polygon[(j + 1) % n])
		best = minf(best, closest.distance_to(p2))
	return best


# The first crossing (closest to `a2`) between the move a2 -> b2 and an intact stretch of the loop, or null.
func _first_crossing(a2: Vector2, b2: Vector2) -> Variant:
	var n := polygon.size()
	if not active or n < 3 or _sample_gap.size() != n:
		return null
	var best: Variant = null
	var best_d := INF
	for j: int in range(n):
		if _sample_gap[j]:
			continue
		var hit: Variant = Geometry2D.segment_intersects_segment(a2, b2, polygon[j], polygon[(j + 1) % n])
		if hit == null:
			continue
		var h: Vector2 = hit
		var d := a2.distance_to(h)
		if d < best_d:
			best_d = d
			best = h
	return best


# ---- Centre, members and slots ---------------------------------------------------------------------------------------


# The centre follows the centroid of the rescued people at BORDER_CENTRE_FOLLOW metres a second. It snaps to the first
# centroid it sees, so the first rescue is the starting point.
func _update_centre(rescued: Array[Person], delta: float) -> void:
	if rescued.is_empty():
		return
	var sum := Vector3.ZERO
	for p: Person in rescued:
		sum += Vector3(p.position.x, 0.0, p.position.z)
	var target := sum / float(rescued.size())
	if not _has_centre:
		centre = target
		_has_centre = true
		return
	var to := Vector3(target.x - centre.x, 0.0, target.z - centre.z)
	var step := Config.BORDER_CENTRE_FOLLOW * delta
	if to.length() <= step:
		centre = Vector3(target.x, 0.0, target.z)
	else:
		centre += to.normalized() * step


# Splits the rescued people into border members (the outermost, one per slot) and inner members, works out the slots,
# and the gaps. Everyone gets a target position (see _move_members).
func _assign_members(rescued: Array[Person]) -> void:
	members.clear()
	inner.clear()
	segment_gap.clear()
	_targets.clear()
	member_count = 0
	inner_count = 0
	spacing = 0.0
	perimeter = 0.0
	_sample_gap.clear()
	_arc.clear()
	var n := polygon.size()
	for j: int in range(n):
		_sample_gap.append(false)
	if not active or n < 3:
		return
	perimeter = perimeter_of(polygon)
	if perimeter < 0.01:
		return
	var acc := 0.0
	for j: int in range(n):
		_arc.append(acc)
		acc += polygon[j].distance_to(polygon[(j + 1) % n])
	_arc.append(acc)

	var m := mini(rescued.size(), slot_count_for(perimeter))
	if m < 1:
		return
	# The outermost m rescued people are border members; the rest are inner members.
	var remaining: Array[Person] = []
	for p: Person in rescued:
		remaining.append(p)
	var border_list: Array[Person] = []
	for k: int in range(m):
		var best_i := 0
		var best_d := -1.0
		for i: int in range(remaining.size()):
			var d := Vector2(remaining[i].position.x - centre.x, remaining[i].position.z - centre.z).length()
			if d > best_d:
				best_d = d
				best_i = i
		border_list.append(remaining[best_i])
		remaining.remove_at(best_i)
	inner = remaining
	spacing = perimeter / float(m)

	# Greedy assignment: each border member takes the nearest free slot, in the order they were chosen.
	var slots: Array[Vector2] = []
	var used: Array[bool] = []
	for k: int in range(m):
		slots.append(_point_at_arc(float(k) * spacing))
		used.append(false)
	for p: Person in border_list:
		var pos2 := Vector2(p.position.x, p.position.z)
		var best_k := -1
		var best_d2 := INF
		for k: int in range(m):
			if used[k]:
				continue
			var d2 := pos2.distance_to(slots[k])
			if d2 < best_d2:
				best_d2 = d2
				best_k = k
		used[best_k] = true
		_targets[p] = Vector3(slots[best_k].x, 0.0, slots[best_k].y)
		members.append(p)

	var spiral_cap := 0.6 * _mean_radius()
	for j: int in range(inner.size()):
		var ang := float(j) * GOLDEN_ANGLE
		var r := minf(Config.BORDER_INNER_SPACING * sqrt(float(j) + 1.0), spiral_cap)
		_targets[inner[j]] = Vector3(centre.x + cos(ang) * r, 0.0, centre.z + sin(ang) * r)

	member_count = members.size()
	inner_count = inner.size()
	var filled: Array[bool] = []
	for k: int in range(m):
		filled.append(true)
	segment_gap = gap_flags(spacing, filled)
	for j: int in range(n):
		var k := mini(m - 1, floori(_arc[j] / spacing))
		_sample_gap[j] = segment_gap[k]


# The point on the loop at arc length `s` from its first point.
func _point_at_arc(s: float) -> Vector2:
	var total := _arc[_arc.size() - 1]
	var along := fposmod(s, total)
	var n := polygon.size()
	for j: int in range(n):
		if along <= _arc[j + 1]:
			var seg := _arc[j + 1] - _arc[j]
			var t := 0.0
			if seg > 1e-9:
				t = (along - _arc[j]) / seg
			return polygon[j].lerp(polygon[(j + 1) % n], t)
	return polygon[0]


func _mean_radius() -> float:
	if polygon.is_empty():
		return Config.BORDER_MIN_RADIUS
	var c2 := Vector2(centre.x, centre.z)
	var total := 0.0
	for p2: Vector2 in polygon:
		total += p2.distance_to(c2)
	return total / float(polygon.size())


# Walks every rescued person toward their target at BORDER_WALK_SPEED.
func _move_members(delta: float) -> void:
	var step := Config.BORDER_WALK_SPEED * delta
	var everyone: Array[Person] = []
	everyone.append_array(members)
	everyone.append_array(inner)
	for p: Person in everyone:
		if not _targets.has(p):
			continue
		var target: Vector3 = _targets[p]
		var to := Vector3(target.x - p.position.x, 0.0, target.z - p.position.z)
		var d := to.length()
		if d <= step:
			p.position = Vector3(target.x, 0.0, target.z)
		else:
			p.position += to / d * step


# Blocks: the share of each footprint inside the loop (sampled on a 5 x 5 grid) drives their beautifying.
func _update_buildings(delta: float) -> void:
	for b: Building in buildings:
		var frac := 0.0
		if active:
			var inside := 0
			for ix: int in range(5):
				for iz: int in range(5):
					var pt := (
						b.centre
						+ Vector2(
							lerpf(-b.half.x, b.half.x, float(ix) / 4.0), lerpf(-b.half.y, b.half.y, float(iz) / 4.0)
						)
					)
					if Geometry2D.is_point_in_polygon(pt, polygon):
						inside += 1
			frac = float(inside) / 25.0
		b.update(delta, frac)


# Dark people outside the loop drain the nearest member within BORDER_PRESS_RANGE (at the usual drain rate, scaled by
# the night strength). Dark people inside are handled by GloomSim.
func _drain_darkness(people: Array[Person], delta: float, strength: float) -> void:
	if not active:
		return
	var rate := Config.SPREAD_DRAIN_RATE * Config.TD_DRAIN_MULTIPLIER * strength * delta
	for p: Person in people:
		if p.is_rescued or not GloomSim.is_dark(p):
			continue
		if Geometry2D.is_point_in_polygon(Vector2(p.position.x, p.position.z), polygon):
			continue
		var best: Person = null
		var best_d := INF
		for m: Person in members:
			var d := GloomSim.flat_dist(p.position, m.position)
			if d <= Config.BORDER_PRESS_RANGE and d < best_d:
				best_d = d
				best = m
		if best != null:
			best.drain_joy(rate)


# The ground inside the loop is painted by the region (paint edge uses its own painted region instead).
func _update_ground() -> void:
	if _ground == null:
		return
	if active and variant != Config.BorderVariant.PAINT_EDGE:
		_ground.set_region(polygon)
	else:
		_ground.set_region(PackedVector2Array())


# ---- Drawing and debug -----------------------------------------------------------------------------------------------


func _draw_lines() -> void:
	_line_mesh.clear_surfaces()
	var n := polygon.size()
	if not active or n < 3:
		return
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
	for j: int in range(n):
		var colour := segment_colour(j)
		var a := polygon[j]
		var b := polygon[(j + 1) % n]
		_line_mesh.surface_set_color(colour)
		_line_mesh.surface_add_vertex(Vector3(a.x, Config.BORDER_LINE_HEIGHT, a.y))
		_line_mesh.surface_set_color(colour)
		_line_mesh.surface_add_vertex(Vector3(b.x, Config.BORDER_LINE_HEIGHT, b.y))
	_line_mesh.surface_end()


func _gap_colour() -> Color:
	var wave := 0.5 + 0.5 * sin(_time * TAU * Config.BORDER_GAP_FLICKER_HZ)
	return Config.BORDER_GAP_COLOUR.lerp(Config.BORDER_GAP_ALARM_COLOUR, wave)


func _update_debug_labels() -> void:
	var m := segment_gap.size()
	while _debug_labels.size() < m:
		var lbl := Label3D.new()
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 48
		lbl.pixel_size = 0.02
		lbl.no_depth_test = true
		lbl.outline_size = 10
		add_child(lbl)
		_debug_labels.append(lbl)
	for k: int in range(_debug_labels.size()):
		var lbl := _debug_labels[k]
		lbl.visible = k < m
		if k < m:
			var mid := _point_at_arc((float(k) + 0.5) * spacing)
			lbl.position = Vector3(mid.x, 2.0, mid.y)
			lbl.text = "%.1f m%s" % [spacing, " GAP" if segment_gap[k] else ""]
