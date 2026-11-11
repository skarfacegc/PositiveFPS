# gdlint: ignore=max-public-methods
class_name Border
extends Node3D

# The living border (round 9; rebuilt for the town grid in 0.4, #55 and #56). The zone is the set of town cells you hold
# (Zone); the line is its outline, split into walls (the face of a held built block, the map's edge: firm, need nobody)
# and gates (an open side of a held square, a street mouth). The rules:
#   - rescued people stand across the gates, spread at BORDER_TARGET_SPACING (fewer people: wider); everyone else is an
#     inner member and stands on the zone's open ground (see border_slots.gd);
#   - gloom outside cannot cross an intact stretch: dimmed people lean on a gate, it bends inward, and it breaks past
#     PUSH_BREAK_DEPTH (see border_push.gd). A break is a gap: gloom passes through it until it mends;
#   - inside the line the ground is painted (see PaintedGround.set_region) and blocks are beautified (see Building);
#   - protection is the depth inside a gate (see cover_at); a wall gives full cover.
# `polygon` is the traced outline with a point every GATE_POINT_STEP metres along each gate, shoved inward where a
# gate is dented. It is what the other scripts read, with `members`, `segment_gap`, `cover_at`, `line_blocks`,
# `clip_move` and `push.dent`.

# Round 26: the line snapped under a push (`pos` is the middle of the break), and a break mended (`seconds` open).
signal line_broke(pos: Vector3)
signal line_mended(pos: Vector3, seconds: float)
# Walls and gates: gate modifiers (shared with Pressure). A gate disappeared on a re-trace (`g` is the id it had).
signal gate_closed(g: int)

# The zone: the cells held and the line they make. The next pass grows and shrinks it (`zone.take`, `zone.lose`).
var zone: Zone = Zone.new()
# The middle of the held cells (a tide is seen from here), and the mean distance of the gates from it.
var centre := Vector3.ZERO
var body_radius: float = 0.0
# True once at least BORDER_MIN_PEOPLE are rescued. Below that there is no line.
var active: bool = false
# True once the border has been active. After that, falling below BORDER_MIN_PEOPLE means the border fell.
var formed: bool = false
# The length of all the gates in metres, and the distance between neighbouring members on them (that over the members).
var perimeter: float = 0.0
var spacing: float = 0.0
# The members the gates ask for together (Zone.members_needed) while the border is active.
var slot_count: int = 0
var member_count: int = 0
var inner_count: int = 0
# The line, as (x, z) points in order (clockwise). Empty when there is no border.
var polygon := PackedVector2Array()
var members: Array[Person] = []
# Walls and gates: Rescues pull the line (#11). The pips on the cells next to the zone (see RescuePips).
var pips := RescuePips.new()
# Round 13b: every rescued person who is faltering as of the last update (members and others).
var faltering: Array[Person] = []
var inner: Array[Person] = []
# One entry per polygon segment (segment j runs from polygon[j] to polygon[j + 1]): true while a break holds it open.
var segment_gap: Array[bool] = []
var buildings: Array[Building] = []
# The block footprints as a flat list (BorderShape.footprints), for the walks; read it through boxes().
var zone_boxes := PackedFloat32Array()
# Round 19: the landmark blocks, in registration order (the order of LandmarkConfig.LANDMARK_NAMES).
var landmark_buildings: Array[Building] = []
# Round 12a: how much faster the border loses ground (1 normally, DIM_LOSS_MULT while the player is dim), and whether
# the line should flicker to show it. Set by set_player_dim().
var loss_mult: float = 1.0
var player_dim: bool = false
# Walls and gates: Defences (#15). People who staff a defence leave the line (Defences owns the list).
var staffed: Array[Person] = []

# The look: draws the line, the haze and the gap glow from the state above (see scripts/looks/border_look.gd).
var look: BorderLook
# Round 26: the physical push (border_push.gd): the dent in the gates and their breaks. (Made in _init, after the line's
# arrays, which it reads when it is made.)
var push: BorderPush
var _ground: PaintedGround
# The traced line without dents, and per point: the gate it starts (-1 on a wall) and whether a dent may move it. Per
# segment: the gate it belongs to (-1 for a wall). Per gate: its first point and how many points it has.
var _base := PackedVector2Array()
var _pt_gate: Array[int] = []
var _pt_dentable: Array[bool] = []
var _seg_gate: Array[int] = []
var _gate_first: Array[int] = []
var _gate_points: Array[int] = []
var _built_version: int = -1
# Where each rescued person should stand: Person -> Vector3.
var _targets: Dictionary = {}
# Person -> the corner (Vector2) they are heading round while a detour is on (see _move_members).
var _detour: Dictionary = {}
var _time: float = 0.0
var _strength: float = 1.0
# Seconds each border member has been faltering (drained below MEMBER_FALTER_FRACTION; the "!" cue reads it).
var _falter_age: Dictionary = {}
# Round 13b: the age of each open gap (see gap_tracker.gd) and the gap middles as of the last update.
var _tracker := GapTracker.new()
var _mids_cache: Array[Vector3] = []
# Round 18: the slot code (who stands where) lives in border_slots.gd.
var _slots: BorderSlots = BorderSlots.new(self)
# Goal tile -> distance (in tiles) of every walkable tile from it; the town never changes, so it is kept.
var _flow: Dictionary = {}
var _debug_on: bool = false
var _debug_labels: Array[Label3D] = []
# Walls and gates: gate modifiers (shared with Pressure). Gate key -> its modifiers (only gates that differ from the
# defaults are stored), and the keys of the gates at the last trace (ids are indexes and shift when the zone changes).
var _gate_mods: Dictionary = {}
var _gate_keys: Array[String] = []


func _init() -> void:
	push = BorderPush.new(self)


# Gets the border ready: the ground it paints and the line it draws.
func setup(ground: PaintedGround) -> void:
	_ground = ground
	_make_look()


# Swaps the look in place (F4).
func rebuild_look() -> void:
	if look != null:
		remove_child(look)
		look.queue_free()
	_make_look()
	look.refresh()


func _make_look() -> void:
	look = Looks.border_look()
	add_child(look)
	look.setup(self)


# Registers a block the border can beautify. `half` is the half-size of its footprint in x and z.
# `size` is the block's collision box (its footprint is `half` * 2 when left out) and `colour` its plain colour.
func register_building(
	body: StaticBody3D,
	half: Vector2,
	is_landmark: bool,
	size: Vector3 = Vector3.ZERO,
	colour: Color = Color(0.6, 0.6, 0.62)
) -> void:
	var b := Building.new()
	b.centre = Vector2(body.position.x, body.position.z)
	b.half = half
	b.is_landmark = is_landmark
	var box := size if size != Vector3.ZERO else Vector3(half.x * 2.0, 2.0, half.y * 2.0)
	b.attach(body, box, colour)
	buildings.append(b)
	if is_landmark:
		landmark_buildings.append(b)


# Call every frame, before people move. Traces the line when the zone changed, applies the push, places the members on
# the gates, beautifies blocks, drains members from gloom outside and updates the ground and the line.
func update(people: Array[Person], delta: float, strength: float) -> void:
	_time += delta
	_strength = strength
	pips.prune(zone)
	var rescued: Array[Person] = []
	for p: Person in people:
		if p.is_rescued:
			rescued.append(p)
	centre = zone.centre()
	_update_falter(rescued, delta)
	active = rescued.size() >= BorderConfig.BORDER_MIN_PEOPLE
	if active:
		formed = true
		if _built_version != zone.version:
			_trace()
			polygon = _base.duplicate()  # The old polygon no longer fits the points the push works on (a lost cell).
		push.update(people, delta, strength)  # Round 26: pushed by what is outside; the dent goes into the line below.
		polygon = _dented()
		_mark_gaps()
	else:
		polygon = PackedVector2Array()
		segment_gap.clear()
		push.reset()
		_base = PackedVector2Array()
		_built_version = -1
	_assign_members(rescued)
	_move_members(delta)
	_update_buildings(delta)
	_press_gloom(people, delta, strength)
	_update_gap_ages(delta)
	_update_ground()
	_draw_lines()
	if _debug_on:
		_update_debug_labels()


# A rescued person was made: the cell they belong to fills a pip (RescuePips); the cell never joins by itself.
func on_rescue(p: Person) -> void:
	pips.on_rescue(zone, p.position)


# A member relapsed: they step out through the gate and leave the border (the slots reshuffle on the next update).
func on_relapse(p: Person) -> void:
	var out := out_at(p.position)
	p.position += Vector3(out.x, 0.0, out.y) * BorderConfig.BORDER_OUTWARD_STEP


# ---- The traced line
# ---------------------------------------------------------------------------------------------------


# Traces the zone's outline into points: a corner for each wall, and a point every GATE_POINT_STEP metres along each
# gate.
func _trace() -> void:
	var old_base := _base
	_base = PackedVector2Array()
	_pt_gate.clear()
	_pt_dentable.clear()
	_seg_gate.clear()
	_gate_first.clear()
	_gate_points.clear()
	perimeter = 0.0
	for _g: Dictionary in zone.gates:
		_gate_first.append(-1)
		_gate_points.append(0)
	for run: Dictionary in zone.runs:
		var a: Vector2 = run["a"]
		var c: Vector2 = run["b"]
		var gate_id: int = run["gate_id"]
		if gate_id < 0:
			_base.append(a)
			_pt_gate.append(-1)
			_pt_dentable.append(false)
			_seg_gate.append(-1)
			continue
		var count := maxi(1, ceili(a.distance_to(c) / BorderConfig.GATE_POINT_STEP - 0.001))
		_gate_first[gate_id] = _base.size()
		_gate_points[gate_id] = count
		perimeter += a.distance_to(c)
		for k: int in range(count):
			_base.append(a.lerp(c, float(k) / float(count)))
			_pt_gate.append(gate_id)
			_pt_dentable.append(k > 0)
			_seg_gate.append(gate_id)
	_built_version = zone.version
	_close_gone_gates()
	var sum := 0.0
	var seen := 0
	for i: int in range(_base.size()):
		if _pt_gate[i] >= 0 or zone.gates.is_empty():
			sum += _base[i].distance_to(Vector2(centre.x, centre.z))
			seen += 1
	body_radius = sum / float(maxi(seen, 1))
	push.carry(old_base, _base)


# ---- Walls and gates: gate modifiers (shared with Pressure)
# ---------------------------------------------------------------------------------------------------
# What a defence does to a gate: {"strength_mult": float (default 1), "cannot_break": bool, "cannot_lose": bool}.
# Kept by the gate's key, so a gate keeps them when a re-trace shifts the ids; a gate that disappears loses them and
# emits gate_closed. (This block is the minimal version; the Pressure agent's replaces it at the merge.)


func set_gate_modifiers(g: int, mods: Dictionary) -> void:
	if g < 0 or g >= zone.gates.size():
		return
	var key: String = zone.gates[g]["key"]
	var full := _full_modifiers(mods)
	if full == _full_modifiers({}):
		_gate_mods.erase(key)
	else:
		_gate_mods[key] = full


func gate_modifiers(g: int) -> Dictionary:
	if g < 0 or g >= zone.gates.size():
		return _full_modifiers({})
	var key: String = zone.gates[g]["key"]
	var found: Dictionary = _gate_mods.get(key, {})
	return _full_modifiers(found)


func _full_modifiers(mods: Dictionary) -> Dictionary:
	var strength: float = mods.get("strength_mult", 1.0)
	var no_break: bool = mods.get("cannot_break", false)
	var no_lose: bool = mods.get("cannot_lose", false)
	return {"strength_mult": strength, "cannot_break": no_break, "cannot_lose": no_lose}


# After a trace: forgets the modifiers of gates that are gone and says so.
func _close_gone_gates() -> void:
	var now: Array[String] = []
	for gate: Dictionary in zone.gates:
		var key: String = gate["key"]
		now.append(key)
	var old := _gate_keys
	_gate_keys = now
	for i: int in range(old.size()):
		if not now.has(old[i]):
			_gate_mods.erase(old[i])
			gate_closed.emit(i)


# The traced line with the gates' dents applied: a dented point moves inward by its dent.
func _dented() -> PackedVector2Array:
	var pts := _base.duplicate()
	for i: int in range(mini(pts.size(), push.dent.size())):
		var d := push.dent[i]
		if d > 0.001 and _pt_dentable[i]:
			var gate: Dictionary = zone.gates[_pt_gate[i]]
			var out: Vector2 = gate["out"]
			pts[i] -= out * d
	return pts


func _mark_gaps() -> void:
	segment_gap.clear()
	for j: int in range(polygon.size()):
		segment_gap.append(push.segment_broken(j))


# How many points the traced line has now (0 when there is no border).
func point_count() -> int:
	return _base.size()


# True when a dent may move point `i` (it lies on a gate and is not the gate's first corner).
func point_dentable(i: int) -> bool:
	return i >= 0 and i < _pt_dentable.size() and _pt_dentable[i]


# The gate that starts at point `i`, or -1 on a wall (and out of range).
func point_gate(i: int) -> int:
	return _pt_gate[i] if i >= 0 and i < _pt_gate.size() else -1


# The angle (radians) of base point `i` as seen from the zone's centre.
func point_angle(i: int) -> float:
	return (_base[i] - Vector2(centre.x, centre.z)).angle()


# The index of the point of the line nearest to the ground point `p2` (0 when there is no line).
func nearest_point(p2: Vector2) -> int:
	var pts := polygon if not polygon.is_empty() else _base
	var best := 0
	var best_d := INF
	for i: int in range(pts.size()):
		var d := pts[i].distance_squared_to(p2)
		if d < best_d:
			best_d = d
			best = i
	return best


# True when segment `j` runs along a wall (not a gate).
func is_wall(j: int) -> bool:
	return j >= 0 and j < _seg_gate.size() and _seg_gate[j] < 0


# The gate segment `j` belongs to, or -1 on a wall.
func segment_gate(j: int) -> int:
	return _seg_gate[j] if j >= 0 and j < _seg_gate.size() else -1


# The point of gate `g` at fraction `t` (0 to 1) of its way along (clockwise), on the dented line.
func gate_point(g: int, t: float) -> Vector2:
	if g < 0 or g >= _gate_first.size() or _gate_first[g] < 0 or polygon.size() < 3:
		return Vector2(centre.x, centre.z)
	var count := _gate_points[g]
	var u := clampf(t, 0.0, 1.0) * float(count)
	var k := mini(floori(u), count - 1)
	var i0 := _gate_first[g] + k
	var n := polygon.size()
	return polygon[i0 % n].lerp(polygon[(i0 + 1) % n], u - float(k))


# The unit direction pointing out of the zone through the gate nearest to the ground point `pos`.
func out_at(pos: Vector3) -> Vector2:
	var g := zone.nearest_gate(Vector2(pos.x, pos.z))
	if g.is_empty():
		return Vector2.RIGHT
	var out: Vector2 = g["out"]
	return out


# The members the gates ask for together.
func required_members() -> int:
	return zone.members_needed()


# Walls and gates: Grid fixes (#56). The members gate `g` has now (the people are shared out thinly when short).
func gate_member_count(g: int) -> int:
	if g < 0 or g >= _slots.gate_counts.size():
		return 0
	return _slots.gate_counts[g]


# How bent gate `g` is at its deepest point (0 flat to 1 at the break depth) and where that point is on the dented line:
# {"bend": float, "at": Vector3}. A gate that is not on the line now gives bend 0.
func gate_deepest(g: int) -> Dictionary:
	var out := {"bend": 0.0, "at": Vector3.ZERO}
	if g < 0 or g >= _gate_first.size() or _gate_first[g] < 0 or polygon.size() < 3:
		return out
	var best_k := 0
	var best := -1.0
	for k: int in range(_gate_points[g]):
		var bend := push.bend_of_point(_gate_first[g] + k)
		if bend > best:
			best = bend
			best_k = k
	var p := polygon[(_gate_first[g] + best_k) % polygon.size()]
	out["bend"] = maxf(best, 0.0)
	out["at"] = Vector3(p.x, 0.0, p.y)
	return out


# The gates bent to `from` (a share of the break depth) or more, as gate_deepest dictionaries plus "gate" (the index).
func pressed_gates(from: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not active:
		return out
	for g: int in range(zone.gates.size()):
		var d := gate_deepest(g)
		var bend: float = d["bend"]
		if bend >= from and bend > 0.0:
			d["gate"] = g
			out.append(d)
	return out


# ---- Reading the line
# ---------------------------------------------------------------------------------------------------


# How protected a person at `pos` is by the border: 0 outside and on a gate, 1 BORDER_EDGE_BAND metres inside (a wall
# protects fully).
func cover_at(pos: Vector3) -> float:
	if not active:
		return 0.0
	var p2 := Vector2(pos.x, pos.z)
	if not Geometry2D.is_point_in_polygon(p2, polygon):
		return 0.0
	var best := INF
	var n := polygon.size()
	for j: int in range(n):
		if _seg_gate[j] < 0:
			continue
		best = minf(best, Geometry2D.get_closest_point_to_segment(p2, polygon[j], polygon[(j + 1) % n]).distance_to(p2))
	return clampf(best / BorderConfig.BORDER_EDGE_BAND, 0.0, 1.0)


# The first crossing (closest to `a2`) between the move a2 -> b2 and an intact stretch of the line, or null.
func _crossing(a2: Vector2, b2: Vector2) -> Variant:
	if not active:
		return null
	return BorderShape.first_crossing(polygon, segment_gap, a2, b2)


# True when the straight move from `a` to `b` crosses an intact stretch of the border.
func line_blocks(a: Vector3, b: Vector3) -> bool:
	return _crossing(Vector2(a.x, a.z), Vector2(b.x, b.z)) != null


# A dimmed person outside the border moves from `from` toward `to`. If the move crosses an intact stretch, it stops just
# short of the line. Otherwise (inside, or through a break) the move is unchanged.
func clip_move(from: Vector3, to: Vector3) -> Vector3:
	if not active:
		return to
	var a2 := Vector2(from.x, from.z)
	var b2 := Vector2(to.x, to.z)
	if Geometry2D.is_point_in_polygon(a2, polygon):
		return to
	var hit: Variant = _crossing(a2, b2)
	if hit == null:
		# A person hugging a gate that is bending can slide in along its edge without a step crossing it: that is not a
		# way in either, unless the nearest stretch is a break.
		if Geometry2D.is_point_in_polygon(b2, polygon) and not segment_is_gap(_nearest_on_loop(b2)["seg"] as int):
			return Vector3(from.x, to.y, from.z)
		return to
	var h: Vector2 = hit
	var dir := (b2 - a2).normalized()
	var stop_dist := maxf(0.0, a2.distance_to(h) - 0.05)
	var stop := a2 + dir * stop_dist
	return Vector3(stop.x, to.y, stop.y)


# The direction a dimmed person at `pos` outside the line walks to get to the nearest gate along the streets, or
# Vector3.ZERO when they are already at the gate's mouth (or there is no line or no way). The route is the tile lattice
# of the town: each frame step to the neighbouring walkable tile that is nearer a gate's mouth.
func route_to_gate(pos: Vector3) -> Vector3:
	if not active or zone.gates.is_empty() or BorderShape.is_inside(polygon, Vector2(pos.x, pos.z)):
		return Vector3.ZERO
	var mouth := zone.nearest_gate(Vector2(pos.x, pos.z))
	var ga: Vector2 = mouth["a"]
	var gb: Vector2 = mouth["b"]
	var here2 := Vector2(pos.x, pos.z)
	if Geometry2D.get_closest_point_to_segment(here2, ga, gb).distance_to(here2) <= BorderConfig.GATE_MOUTH_REACH:
		return Vector3.ZERO  # Already at the gate's mouth: no more going round.
	var mid: Vector2 = mouth["mid"]
	var out: Vector2 = mouth["out"]
	var goal := mid + out * BorderConfig.GATE_MOUTH_OUTSIDE
	var here := TownGrid.tile_of(pos)
	var there := TownGrid.tile_of(Vector3(goal.x, 0.0, goal.y))
	if here == there:
		return Vector3.ZERO
	var step := _next_tile(here, there)
	var c := TownGrid.tile_centre(step.x, step.y)
	var to := Vector3(c.x - pos.x, 0.0, c.z - pos.z)
	return to.normalized() if to.length() > 0.01 else Vector3.ZERO


# The first tile on a shortest walk over walkable tiles from `from` to `to` (`from` itself when there is none).
func _next_tile(from: Vector2i, to: Vector2i) -> Vector2i:
	if not _flow.has(to):
		var field: Dictionary = {to: 0}
		var queue: Array[Vector2i] = [to]
		var head := 0
		while head < queue.size():
			var cur := queue[head]
			head += 1
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nxt := cur + d
				if field.has(nxt) or not TownGrid.tile_walkable(nxt.x, nxt.y):
					continue
				var steps: int = field[cur]
				field[nxt] = steps + 1
				queue.append(nxt)
		_flow[to] = field
	var dist: Dictionary = _flow[to]
	var best := from
	var best_d: int = dist.get(from, 1000000)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nxt := from + d
		var nd: int = dist.get(nxt, 1000000)
		if nd < best_d:
			best_d = nd
			best = nxt
	return best


# The colour of polygon segment `j` right now: intact gold, or a flickering grey and red when it is a gap.
func segment_colour(j: int) -> Color:
	if segment_is_gap(j):
		return BorderConfig.BORDER_GAP_COLOUR
	return BorderConfig.BORDER_INTACT_COLOUR


func segment_is_gap(j: int) -> bool:
	return j >= 0 and j < segment_gap.size() and segment_gap[j]


# The middle of each break, in world coordinates (the points the off-screen gap arrows point at).
func gap_midpoints() -> Array[Vector3]:
	return push.break_points()


# The gap middles as of the last update(), for the things that read them every frame (do not change the result).
func gap_midpoints_cached() -> Array[Vector3]:
	return _mids_cache


# Round 13b: carries each open gap's age over from last frame (a gap within GAP_TRACK_RADIUS of an old one is the same
# gap) and starts new ones at zero.
func _update_gap_ages(delta: float) -> void:
	_mids_cache = gap_midpoints()
	_tracker.update(_mids_cache, delta)


# How urgent each gap is, 0 (just opened) to 1 (open GAP_URGENCY_SECONDS or more), in gap_midpoints() order.
func gap_urgencies() -> Array[float]:
	return _tracker.urgencies


# Urgency (0 to 1) of a faltering rescued person: how long they have faltered, over GAP_URGENCY_SECONDS.
func falter_urgency(p: Person) -> float:
	var age: float = _falter_age.get(p, 0.0)
	return clampf(age / BorderConfig.GAP_URGENCY_SECONDS, 0.0, 1.0)


# The gap pulse right now (see gap_pulse).
func pulse() -> float:
	return gap_pulse(_time)


# Round 12a: a dim player makes the troupe lose heart. The border loses ground DIM_LOSS_MULT times faster and flickers.
func set_player_dim(dim: bool) -> void:
	player_dim = dim
	loss_mult = SpiritConfig.DIM_LOSS_MULT if dim else 1.0


# How bright the line and haze are drawn: 1 normally, pulsing between DIM_FLICKER_MIN and 1 while the player is dim.
func flicker() -> float:
	if not player_dim:
		return 1.0
	var wave := 0.5 + 0.5 * sin(TAU * _time / SpiritConfig.DIM_FLICKER_SECONDS)
	return lerpf(SpiritConfig.DIM_FLICKER_MIN, 1.0, wave)


# The gap pulse at time `t`: 0 at its trough, 1 at its peak, once every BORDER_GAP_PULSE_SECONDS. It is a cosine, so
# it is soft at both ends and never a hard edge.
static func gap_pulse(t: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t / BorderConfig.BORDER_GAP_PULSE_SECONDS)


# Round 12b: how much a dimmed person wants to press at the border member standing at `pos`, 0 to 1: how bent the gate
# is there (the gloom goes where it is already giving). 0 when there is no border.
func edge_pressure(pos: Vector3) -> float:
	if not active:
		return 0.0
	return push.bend_at(pos)


# How many separate breaks the line has.
func gap_region_count() -> int:
	return push.breaks.size()


# True when `p` is a border member who is faltering right now.
func is_faltering(p: Person) -> bool:
	return members.has(p) and p.is_faltering()


# How many breaks are open.
func gap_count() -> int:
	return push.breaks.size()


# True while landmark block number `index` (LandmarkConfig.LANDMARK_NAMES order) is beautified.
func landmark_beautified(index: int = 0) -> bool:
	return index < landmark_buildings.size() and landmark_buildings[index].beautified


func beautified_building_count() -> int:
	var n := 0
	for b: Building in buildings:
		if b.beautified:
			n += 1
	return n


# F3: shows a label per gate with its members and what it needs. debug_summary gives the counts.
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
		"border, members %d, inner %d, gates %d, spacing %.1f m, gaps %d, night x%.2f"
		% [member_count, inner_count, zone.gates.size(), spacing, gap_count(), _strength]
	)


# ---- Members
# ---------------------------------------------------------------------------------------------------


# Round 12b: tracks how long each border member has been faltering (the "!" cue and the urgency read it). A member who
# recovers is forgotten. (Round 26: a faltering member no longer steps back or opens a gap.)
func _update_falter(rescued: Array[Person], delta: float) -> void:
	var ages: Dictionary = {}
	faltering.clear()
	for p: Person in rescued:
		if not p.is_faltering():
			continue
		faltering.append(p)
		if members.has(p):
			ages[p] = _falter_age.get(p, 0.0) + delta
	_falter_age = ages


func _assign_members(rescued: Array[Person]) -> void:
	if staffed.is_empty():
		_slots.assign_members(rescued)
		return
	var on_line: Array[Person] = []
	for p: Person in rescued:  # Walls and gates: Defences (#15). A defence's staff are not on the line.
		if not staffed.has(p):
			on_line.append(p)
	_slots.assign_members(on_line)


# The block footprints (BorderShape.footprints), rebuilt when blocks were added or removed.
func boxes() -> PackedFloat32Array:
	if zone_boxes.size() != buildings.size() * 4:
		zone_boxes = BorderShape.footprints(buildings)
	return zone_boxes


# Walks every rescued person toward their target at BORDER_WALK_SPEED.
func _move_members(delta: float) -> void:
	var step := BorderConfig.BORDER_WALK_SPEED * delta
	var arrive := BorderConfig.BORDER_ARRIVE_GAIN * delta
	var everyone: Array[Person] = []
	everyone.append_array(members)
	everyone.append_array(inner)
	for p: Person in everyone:
		if not _targets.has(p):
			continue
		var target: Vector3 = _targets[p]
		var to := Vector3(target.x - p.position.x, 0.0, target.z - p.position.z)
		var d := to.length()
		# Round 18: slow down on approach (speed = BORDER_ARRIVE_GAIN x distance, at most the walk speed), so people ease
		# into their slot and do not overshoot it when it moves.
		var go := minf(step, d * arrive)
		if d <= 0.01:
			p.position = Vector3(target.x, 0.0, target.z)
			_detour.erase(p)
		else:
			# 0.3.3 (#53): a person slides round a block's face and does not walk through it.
			var way: Vector2 = _detour.get(p, Vector2.INF)
			var res := BorderShape.step_around(
				boxes(),
				Vector2(p.position.x, p.position.z),
				Vector2(target.x, target.z),
				go,
				BorderConfig.ZONE_BLOCK_CLEAR,
				way
			)
			var at: Vector2 = res["pos"]
			p.position = Vector3(at.x, p.position.y, at.y)
			way = res["waypoint"]
			if way == Vector2.INF or d <= BorderConfig.ZONE_DETOUR_ARRIVE:
				_detour.erase(p)
			else:
				_detour[p] = way


# Blocks: the share of each footprint inside the line (sampled on a 5 x 5 grid, a little in from its edge so a held
# block whose face is the line counts as inside) drives their beautifying.
func _update_buildings(delta: float) -> void:
	for b: Building in buildings:
		var frac := 0.0
		if active:
			var inside := 0
			var h := b.half - Vector2(0.2, 0.2)
			for ix: int in range(5):
				for iz: int in range(5):
					var pt := b.centre + Vector2(lerpf(-h.x, h.x, float(ix) / 4.0), lerpf(-h.y, h.y, float(iz) / 4.0))
					if Geometry2D.is_point_in_polygon(pt, polygon):
						inside += 1
			frac = float(inside) / 25.0
		b.update(delta, frac)


# Dimmed people pressing on the border (outside, within BORDER_PRESS_RANGE of a gate). On an intact gate they are pushed
# outward at BORDER_PUSHBACK_SPEED, and the nearest member drains at BORDER_INTACT_DRAIN_FRACTION of the rate (round
# 11). At a break they drain the nearest member at the full rate, scaled by the night strength. A wall is never pressed.
# Dimmed people inside are handled by GloomSim.
func _press_gloom(people: Array[Person], delta: float, strength: float) -> void:
	if not active:
		return
	var rate := PeopleConfig.SPREAD_DRAIN_RATE * PeopleConfig.TD_DRAIN_MULTIPLIER * strength * delta * loss_mult
	for p: Person in people:
		if p.is_rescued or not GloomSim.is_dimmed(p):
			continue
		var p2 := Vector2(p.position.x, p.position.z)
		if Geometry2D.is_point_in_polygon(p2, polygon):
			_sweep_out(p)
			continue
		var near := _nearest_on_loop(p2)
		var dist: float = near["dist"]
		if dist > BorderConfig.BORDER_PRESS_RANGE:
			continue
		var seg: int = near["seg"]
		if is_wall(seg):
			continue  # A wall holds firm; nothing presses on it.
		if segment_is_gap(seg):
			var best := _nearest_member(p.position)
			if best != null:
				best.drain_joy(rate)
		else:
			var point: Vector2 = near["point"]
			var out := p2 - point
			if out.length() < 0.001:
				continue  # Exactly on the line: nothing to push away from.
			var best_intact := _nearest_member(p.position)
			if best_intact != null:
				best_intact.drain_joy(rate * BorderConfig.BORDER_INTACT_DRAIN_FRACTION)
			var move := out.normalized() * BorderConfig.BORDER_PUSHBACK_SPEED * delta
			var lim := BorderConfig.BORDER_MAP_LIMIT
			p.position = Vector3(
				clampf(p.position.x + move.x, -lim, lim), p.position.y, clampf(p.position.z + move.y, -lim, lim)
			)


# A gate that springs back sweeps outward over a dimmed person pressing on it: someone caught within
# BORDER_SWEEP_BAND of an intact gate on its inner side is put back just outside it (a break is the only way in).
func _sweep_out(p: Person) -> void:
	var p2 := Vector2(p.position.x, p.position.z)
	var near := _nearest_on_loop(p2)
	var dist: float = near["dist"]
	var seg: int = near["seg"]
	if dist > BorderConfig.BORDER_SWEEP_BAND or seg < 0 or is_wall(seg) or segment_is_gap(seg):
		return
	var point: Vector2 = near["point"]
	var out := out_at(p.position)
	var to := point + out * 0.06
	p.position = Vector3(to.x, p.position.y, to.y)


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


# The nearest point on the line to `p2`: a Dictionary with "dist" (metres), "point" (Vector2) and "seg" (segment index).
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


# The ground inside the line is painted by the region (paint edge uses its own painted region instead).
func _update_ground() -> void:
	if _ground == null:
		return
	if active:
		_ground.set_region(polygon)
	else:
		_ground.set_region(PackedVector2Array())


# ---- Drawing and debug
# -----------------------------------------------------------------------------------------------


# Tells the look to redraw the line, the haze and the gap glow from the current state.
func _draw_lines() -> void:
	if look != null:
		look.refresh()


func _update_debug_labels() -> void:
	var gates: Array[Dictionary] = zone.gates
	var m := gates.size()
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
			var mid: Vector2 = gates[k]["mid"]
			var need: int = gates[k]["need"]
			lbl.position = Vector3(mid.x, 2.0, mid.y)
			lbl.text = "gate %d, needs %d%s" % [k, need, " GAP" if push.breaks.size() > 0 else ""]
