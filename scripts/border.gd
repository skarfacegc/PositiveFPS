class_name Border
extends Node3D

# The living border (round 9, organic push only since round 10). Rescued people organise themselves into a loop around a
# centre (the smoothed centroid of the rescued). The loop has a radius per angle, pushed outward where each person was
# rescued, and wrapped around blocks. The rules:
#   - the outermost rescued people are the border members, one per slot evenly spaced along the loop; the rest stand
#     inside (inner members). A stretch between members that is longer than BORDER_MAX_GAP is a gap.
#   - darkness outside cannot cross an intact stretch: it presses against the line and drains the nearest member.
#     Through a gap it can pass.
#   - inside the loop the ground is painted (see PaintedGround.set_region) and blocks are beautified (see Building).
#   - protection is the depth inside the loop (see cover_at).

# Inner members are placed on a golden-angle spiral, so they spread out without a random number.
const GOLDEN_ANGLE := 2.39996323

var centre := Vector3.ZERO
# True once at least BORDER_MIN_PEOPLE are rescued. Below that there is no loop.
var active: bool = false
# True once the border has been active. After that, falling below BORDER_MIN_PEOPLE means the border fell.
var formed: bool = false
var perimeter: float = 0.0
# Distance between neighbouring border members, in metres (perimeter / border members).
var spacing: float = 0.0
var member_count: int = 0
# Beautified buildings on the line that count as posts (see _assign_members). Each holds BORDER_POST_WORTH slots.
var post_count: int = 0
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
# Rescued people whose outward push has not been applied yet (see on_rescue).
var _pending_pushes: Array[Person] = []
# Where each post stands on the loop (world positions), from the last update. They pull the centre (see _update_centre).
var _post_points: Array[Vector3] = []
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


# Gets the border ready: the ground it paints and the line it draws.
func setup(ground: PaintedGround) -> void:
	_ground = ground
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
	b.attach(body)
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
	_apply_pending_pushes()
	var n := rescued.size()
	active = n >= Config.BORDER_MIN_PEOPLE
	if active:
		formed = true
		polygon = _organic_polygon(Vector2(centre.x, centre.z), n, delta)
	else:
		polygon = PackedVector2Array()
	_assign_members(rescued)
	_move_members(delta)
	_update_buildings(delta)
	_press_darkness(people, delta, strength)
	_update_ground()
	_draw_lines()
	if _debug_on:
		_update_debug_labels()


# A rescued person was made. The border pushes outward at the angle they were rescued from. The push is applied on the
# next update, once the centre is known (see _apply_pending_pushes).
func on_rescue(p: Person) -> void:
	_pending_pushes.append(p)


# Applies the outward push of every rescue still waiting for one, at the angle from the centre to that person. Before
# this fix a push was measured from the person's own spot when no centre existed yet, so the first rescues (and any
# made in the same frame) all pushed toward angle 0, and the loop then drifted east. A person standing exactly on the
# centre waits until the centre has moved off them, so no push is ever aimed at an arbitrary angle.
func _apply_pending_pushes() -> void:
	var waiting: Array[Person] = []
	for p: Person in _pending_pushes:
		if not p.is_rescued:
			continue
		var to := Vector2(p.position.x - centre.x, p.position.z - centre.z)
		if to.length() < 0.05:
			waiting.append(p)
			continue
		_push_at(atan2(to.y, to.x), Config.BORDER_PUSH)
	_pending_pushes = waiting


# Adds a Gaussian bump of `amount` metres to the raw radius at angle `ang` (the same bump for a rescue and a shove).
func _push_at(ang: float, amount: float) -> void:
	for i: int in range(Config.BORDER_SAMPLES):
		var a := TAU * float(i) / float(Config.BORDER_SAMPLES)
		var d := wrapf(a - ang, -PI, PI)
		_raw_radii[i] += amount * exp(-d * d / (2.0 * Config.BORDER_PUSH_WIDTH * Config.BORDER_PUSH_WIDTH))


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
		"border, members %d, inner %d, posts %d, spacing %.1f m, gaps %d, night x%.2f"
		% [member_count, inner_count, post_count, spacing, gap_count(), _strength]
	)


# ---- Pure shape rules (static, so tests can check them directly) -----------------------------------------------------


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


# One gap flag per slot segment. A segment is a gap if the spacing is too wide, or it touches an empty slot. A segment
# that
# touches a post (`anchored`) is never a gap while the post stands.
static func gap_flags(spacing_m: float, filled: Array[bool], anchored: Array[bool] = []) -> Array[bool]:
	var out: Array[bool] = []
	var m := filled.size()
	for k: int in range(m):
		var gap := spacing_m > Config.BORDER_MAX_GAP or not filled[k] or not filled[(k + 1) % m]
		if anchored.size() == m and (anchored[k] or anchored[(k + 1) % m]):
			gap = false
		out.append(gap)
	return out


# True when `p` is inside the loop.
static func is_inside(pts: PackedVector2Array, p: Vector2) -> bool:
	return pts.size() >= 3 and Geometry2D.is_point_in_polygon(p, pts)


# ---- Loop variants ---------------------------------------------------------------------------------------------------


# Per angle, the smoothed radius times the size factor. A block on the ray that the radius reaches is wrapped:
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


# The radius per angle after a small circular blur (so one bump does not look like a spike).
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
	# Round 10: a post pulls the centre like three rescued people (see BORDER_POST_WORTH), so the loop does not slide away
	# from a landmark or a captured block that no member stands beside.
	var sum := Vector3.ZERO
	for p: Person in rescued:
		sum += Vector3(p.position.x, 0.0, p.position.z)
	var weight := float(rescued.size())
	for pt: Vector3 in _post_points:
		sum += pt * float(Config.BORDER_POST_WORTH)
		weight += float(Config.BORDER_POST_WORTH)
	var target := sum / weight
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


# Splits the rescued people into border members (the outermost, one per free slot) and inner members, works out the
# slots
# and the gaps. Round 10: beautified buildings on the line are posts. Each post claims BORDER_POST_WORTH consecutive
# slots,
# so the loop needs that many fewer people, and the segments beside a post are never gaps. Everyone gets a target
# position (see _move_members).
func _assign_members(rescued: Array[Person]) -> void:
	members.clear()
	inner.clear()
	segment_gap.clear()
	_targets.clear()
	member_count = 0
	inner_count = 0
	post_count = 0
	spacing = 0.0
	perimeter = 0.0
	_sample_gap.clear()
	_arc.clear()
	for b: Building in buildings:
		b.set_post(false)
	_post_points.clear()
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

	var posts := _find_posts(slot_count_for(perimeter))
	post_count = posts.size()
	var m := mini(rescued.size(), required_members())
	if m < 1:
		return
	# The slot grid: m member slots plus BORDER_POST_WORTH slots per post, evenly spaced around the loop.
	var k_total := m + Config.BORDER_POST_WORTH * post_count
	spacing = perimeter / float(k_total)
	var slot_taken: Array[bool] = []
	var post_slot: Array[bool] = []
	for k: int in range(k_total):
		slot_taken.append(false)
		post_slot.append(false)
	var placed := 0
	for entry: Dictionary in posts:
		var b: Building = entry["building"]
		var arc: float = entry["arc"]
		var c := roundi(arc / spacing)
		for off: int in range(k_total):
			var s := posmod(c - 1 + off, k_total)
			if _run_free(slot_taken, s):
				for t: int in range(Config.BORDER_POST_WORTH):
					slot_taken[posmod(s + t, k_total)] = true
					post_slot[posmod(s + t, k_total)] = true
				b.set_post(true)
				placed += 1
				var at2 := _point_at_arc(arc)
				_post_points.append(Vector3(at2.x, 0.0, at2.y))
				break
	post_count = placed

	var slots: Array[Vector2] = []
	for k: int in range(k_total):
		slots.append(_point_at_arc(float(k) * spacing))
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

	# Greedy assignment: each border member takes the nearest free slot, in the order they were chosen. There are always
	# at least m free slots, because the posts were counted out of the slot total.
	for p: Person in border_list:
		var pos2 := Vector2(p.position.x, p.position.z)
		var best_k := -1
		var best_d2 := INF
		for k: int in range(k_total):
			if slot_taken[k]:
				continue
			var d2 := pos2.distance_to(slots[k])
			if d2 < best_d2:
				best_d2 = d2
				best_k = k
		slot_taken[best_k] = true
		_targets[p] = Vector3(slots[best_k].x, 0.0, slots[best_k].y)
		members.append(p)

	var spiral_cap := 0.6 * _mean_radius()
	for j: int in range(inner.size()):
		var ang := float(j) * GOLDEN_ANGLE
		var r := minf(Config.BORDER_INNER_SPACING * sqrt(float(j) + 1.0), spiral_cap)
		_targets[inner[j]] = Vector3(centre.x + cos(ang) * r, 0.0, centre.z + sin(ang) * r)

	member_count = members.size()
	inner_count = inner.size()
	var anchored: Array[bool] = []
	for k: int in range(k_total):
		anchored.append(post_slot[k] or post_slot[(k + 1) % k_total])
	segment_gap = gap_flags(spacing, slot_taken, anchored)
	for j: int in range(n):
		var k := mini(k_total - 1, floori(_arc[j] / spacing))
		_sample_gap[j] = segment_gap[k]


# True when slot `s` and the BORDER_POST_WORTH slots after it are all free (see _assign_members).
static func _run_free(taken: Array[bool], s: int) -> bool:
	var k := taken.size()
	for t: int in range(Config.BORDER_POST_WORTH):
		if taken[posmod(s + t, k)]:
			return false
	return true


# The members the loop needs now: the slots its perimeter holds, less BORDER_POST_WORTH for each post.
func required_members() -> int:
	return maxi(0, slot_count_for(perimeter) - Config.BORDER_POST_WORTH * post_count)


# The beautified buildings the loop passes within BORDER_POST_REACH of. Each entry has the building and the arc length
# of
# the nearest loop point. At most as many as leave BORDER_MIN_PEOPLE slots for people.
func _find_posts(slots_total: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap := (slots_total - Config.BORDER_MIN_PEOPLE) / Config.BORDER_POST_WORTH
	for b: Building in buildings:
		if not b.beautified or out.size() >= cap:
			continue
		var near := _nearest_loop_point_to_box(b)
		if near.x <= Config.BORDER_POST_REACH:
			out.append({"building": b, "arc": near.y})
	return out


# The distance from a building's footprint to the nearest loop point, and that point's arc length: Vector2(distance,
# arc).
func _nearest_loop_point_to_box(b: Building) -> Vector2:
	var best := Vector2(INF, 0.0)
	for j: int in range(polygon.size()):
		var d := box_distance(polygon[j], b.centre, b.half)
		if d < best.x:
			best = Vector2(d, _arc[j])
	return best


# Distance from point `p` to the box centred on `c` with half-size `half` (0 inside it).
static func box_distance(p: Vector2, c: Vector2, half: Vector2) -> float:
	var d := Vector2(maxf(absf(p.x - c.x) - half.x, 0.0), maxf(absf(p.y - c.y) - half.y, 0.0))
	return d.length()


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


# Dark people pressing on the border (outside, within BORDER_PRESS_RANGE of the line). On an intact stretch they are
# pushed
# outward at BORDER_PUSHBACK_SPEED and nothing is drained. At a gap they drain the nearest member, at the usual drain
# rate
# scaled by the night strength. Dark people inside are handled by GloomSim.
func _press_darkness(people: Array[Person], delta: float, strength: float) -> void:
	if not active:
		return
	var rate := Config.SPREAD_DRAIN_RATE * Config.TD_DRAIN_MULTIPLIER * strength * delta
	for p: Person in people:
		if p.is_rescued or not GloomSim.is_dark(p):
			continue
		var p2 := Vector2(p.position.x, p.position.z)
		if Geometry2D.is_point_in_polygon(p2, polygon):
			continue
		var near := _nearest_on_loop(p2)
		var dist: float = near["dist"]
		if dist > Config.BORDER_PRESS_RANGE:
			continue
		var seg: int = near["seg"]
		if segment_is_gap(seg):
			var best := _nearest_member(p.position)
			if best != null:
				best.drain_joy(rate)
		else:
			var point: Vector2 = near["point"]
			var out := p2 - point
			if out.length() < 0.001:
				out = p2 - Vector2(centre.x, centre.z)
			if out.length() < 0.001:
				continue
			var move := out.normalized() * Config.BORDER_PUSHBACK_SPEED * delta
			p.position += Vector3(move.x, 0.0, move.y)


# The border member nearest to `pos`, or null when there are none.
func _nearest_member(pos: Vector3) -> Person:
	var best: Person = null
	var best_d := INF
	for m: Person in members:
		var d := GloomSim.flat_dist(pos, m.position)
		if d < best_d:
			best_d = d
			best = m
	return best


# The nearest point on the loop to `p2`: a Dictionary with "dist" (metres), "point" (Vector2) and "seg" (segment index).
func _nearest_on_loop(p2: Vector2) -> Dictionary:
	var best := {"dist": INF, "point": p2, "seg": -1}
	var n := polygon.size()
	for j: int in range(n):
		var c := Geometry2D.get_closest_point_to_segment(p2, polygon[j], polygon[(j + 1) % n])
		var d := c.distance_to(p2)
		var best_dist: float = best["dist"]
		if d < best_dist:
			best = {"dist": d, "point": c, "seg": j}
	return best


# The joy burst shoves the border outward toward the player when they are within BORDER_SHOVE_RANGE of the line. It
# uses the
# same bump as a rescue, divided by the size factor so that it shows as about BORDER_SHOVE_AMOUNT metres on the line.
func shove(at: Vector3) -> void:
	if not active:
		return
	var p2 := Vector2(at.x, at.z)
	var near := _nearest_on_loop(p2)
	var dist: float = near["dist"]
	if dist > Config.BORDER_SHOVE_RANGE:
		return
	var to := p2 - Vector2(centre.x, centre.z)
	if to.length() < 0.001:
		return
	_push_at(atan2(to.y, to.x), Config.BORDER_SHOVE_AMOUNT / maxf(_scale, 0.01))


# The ground inside the loop is painted by the region (paint edge uses its own painted region instead).
func _update_ground() -> void:
	if _ground == null:
		return
	if active:
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
