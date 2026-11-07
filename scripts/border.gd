# gdlint: ignore=max-public-methods
class_name Border
extends Node3D

# The living border (round 9, organic push only since round 10). Rescued people organise themselves into a loop around
# a centre (the smoothed centroid of the rescued). The loop has a radius per angle, pushed outward where each person
# was rescued, and wrapped around blocks. The rules:
#   - the outermost rescued people are the border members, one per slot evenly spaced along the loop; the rest stand
#     inside (inner members). A stretch between members that is longer than BORDER_MAX_GAP is a gap.
#   - gloom outside cannot cross an intact stretch: it presses against the line and drains the nearest member.
#     Through a gap it can pass.
#   - inside the loop the ground is painted (see PaintedGround.set_region) and blocks are beautified (see Building).
#   - protection is the depth inside the loop (see cover_at).

# Round 19/20: the stretch's tip reached the beacon (or the maximum reach); a beacon was placed.
# Round 22: no snap. A finished stretch keeps its arm: `zone_grew` (area gained in square metres, the tip, the stretch's
# angle); people were lost and the arms retreat: `zone_pulling_in` (starts), `zone_shrunk` (area lost, when it ends).
signal beacon_reached
signal stretch_started(beacon: Vector3, tip_target: Vector3)
signal zone_grew(gain: float, tip: Vector3, angle: float)
signal zone_pulling_in
signal zone_shrunk(lost: float)
# Round 21: a stretch ended without a snap because the border could no longer support it (`reason` is plain words).
signal stretch_ended(reason: String)
# Round 26: the line snapped under a push (`pos` is the middle of the break), and a break mended (`seconds` open).
signal line_broke(pos: Vector3)
signal line_mended(pos: Vector3, seconds: float)

# Inner members are placed on a golden-angle spiral, so they spread out without a random number.
const GOLDEN_ANGLE := 2.39996323

var centre := Vector3.ZERO
# Round 22: the mean radius of the body circle (the smoothed radii times the size factor) in the last loop built.
var body_radius: float = 0.0
# True once at least BORDER_MIN_PEOPLE are rescued. Below that there is no loop.
var active: bool = false
# True once the border has been active. After that, falling below BORDER_MIN_PEOPLE means the border fell.
var formed: bool = false
var perimeter: float = 0.0
# Distance between neighbouring border members, in metres (perimeter / border members).
var spacing: float = 0.0
# Checkpoint 5: the slot count the loop holds, with hysteresis (BorderShape.held_slot_count); 0 until the first update.
var slot_count: int = 0
var member_count: int = 0
# Beautified buildings on the line that count as posts (see BorderSlots). Each holds BORDER_POST_WORTH slots.
var post_count: int = 0
var inner_count: int = 0
# The loop, as (x, z) points in order around the centre. Empty when there is no border.
var polygon := PackedVector2Array()
var members: Array[Person] = []
# Round 13b: every rescued person who is faltering as of the last update (members, benched and others).
var faltering: Array[Person] = []
var inner: Array[Person] = []
# One entry per slot segment: true when that stretch is a gap.
var segment_gap: Array[bool] = []
var buildings: Array[Building] = []
# Round 19: the landmark blocks, in registration order (the order of Config.LANDMARK_NAMES).
var landmark_buildings: Array[Building] = []
# Round 12a: how much faster the border loses ground (1 normally, DIM_LOSS_MULT while the player is dim), and whether
# the line should flicker to show it. Set by set_player_dim().
var loss_mult: float = 1.0
var player_dim: bool = false

# The look: draws the line, the haze and the gap glow from the state above (see scripts/looks/border_look.gd).
var look: BorderLook
# Round 26: the physical push (border_push.gd): the dent in the line and its breaks.
var push: BorderPush = BorderPush.new(self)
var _ground: PaintedGround
var _has_centre: bool = false
# Rescued people whose outward push has not been applied yet (see on_rescue).
var _pending_pushes: Array[Person] = []
# Where each post stands on the loop (world positions), from the last update. They pull the centre (see
# _update_centre).
var _post_points: Array[Vector3] = []
# Organic: the radius per angle before smoothing, and the size factor that eases toward the target perimeter.
var _raw_radii: Array[float] = []
var _scale: float = 1.0
# One entry per polygon segment (sample j runs from polygon[j] to polygon[j + 1]): true when it lies in a gap.
var _sample_gap: Array[bool] = []
# Cumulative arc length at each polygon point, plus the total at the end (so it has one more entry than polygon).
var _arc: Array[float] = []
# Round 16: per polygon segment, how much of it lies along the map edge, 0..1 (1 = sealed: closed by the map, needs no
# slots and is never a gap; it fades in over BORDER_SEAL_BAND so the open length never jumps). _open is the cumulative
# OPEN length at each polygon point (a sealed segment adds nothing), with the total at the end. Slots are spaced evenly
# along the open length, starting at _phase.
var _sealed: Array[float] = []
var _open: Array[float] = []
var _phase: float = 0.0
# Where each rescued person should stand: Person -> Vector3.
var _targets: Dictionary = {}
var _time: float = 0.0
var _strength: float = 1.0
# Round 12b: per angle sample, the time the raw radius was last pushed outward (a rescue or a shove), so dimmed people
# can prefer the newest stretch (see edge_pressure).
var _pushed_at: Array[float] = []
# Seconds each border member has been faltering (drained below MEMBER_FALTER_FRACTION; the "!" cue reads it).
var _falter_age: Dictionary = {}
# Round 13b: the age of each open gap (see gap_tracker.gd) and the gap middles as of the last update.
var _tracker := GapTracker.new()
var _mids_cache: Array[Vector3] = []
# Round 18: the slot code (layout, who stands where, gaps) lives in border_slots.gd.
var _slots: BorderSlots = BorderSlots.new(self)
# Round 19: the centre and the spirit beacon (border_centre.gd).
var _centre_ctl: BorderCentre = BorderCentre.new(self)
var _debug_on: bool = false
var _debug_labels: Array[Label3D] = []


# Gets the border ready: the ground it paints and the line it draws.
func setup(ground: PaintedGround) -> void:
	_ground = ground
	_raw_radii.clear()
	_pushed_at.clear()
	for i: int in range(Config.BORDER_SAMPLES):
		_raw_radii.append(Config.BORDER_MIN_RADIUS)
		_pushed_at.append(-1.0e9)
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


# Call every frame, before people move. Recomputes the centre, the loop, the slots and the gaps, moves the rescued
# people to their places, beautifies blocks, drains members from gloom outside and updates the ground and the line.
func update(people: Array[Person], delta: float, strength: float) -> void:
	_time += delta
	_strength = strength
	var rescued: Array[Person] = []
	_centre_ctl.dimmed.clear()
	for p: Person in people:
		if p.is_rescued:
			rescued.append(p)
		elif GloomSim.is_dimmed(p):
			_centre_ctl.dimmed.append(Vector2(p.position.x, p.position.z))  # Round 21: the tip keeps clear of them.
	_update_centre(rescued, delta)
	_apply_pending_pushes()
	_update_falter(rescued, delta)
	var n := rescued.size()
	active = n >= Config.BORDER_MIN_PEOPLE
	if active:
		formed = true
		_raw_radii = BorderShape.relax_radii(_raw_radii, _sealed, delta)
		BorderShape.trim_to_map(_raw_radii, centre, _scale)
		push.update(people, delta, strength)  # Round 26: pushed by what is outside; the dent goes into the loop below.
		polygon = _organic_polygon(Vector2(centre.x, centre.z), n, delta)
	else:
		polygon = PackedVector2Array()
		push.reset()
	_assign_members(rescued)
	_move_members(delta)
	_update_buildings(delta)
	_press_gloom(people, delta, strength)
	_update_gap_ages(delta)
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
		var bump := exp(-d * d / (2.0 * Config.BORDER_PUSH_WIDTH * Config.BORDER_PUSH_WIDTH))
		_raw_radii[i] += amount * bump
		if bump >= 0.5 and i < _pushed_at.size():
			_pushed_at[i] = _time


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
	return clampf(BorderShape.distance_to_line(polygon, p2) / Config.BORDER_EDGE_BAND, 0.0, 1.0)


# The first crossing (closest to `a2`) between the move a2 -> b2 and an intact stretch of the loop, or null.
func _crossing(a2: Vector2, b2: Vector2) -> Variant:
	if not active:
		return null
	return BorderShape.first_crossing(polygon, _sample_gap, a2, b2)


# True when the straight move from `a` to `b` crosses an intact stretch of the border.
func line_blocks(a: Vector3, b: Vector3) -> bool:
	return _crossing(Vector2(a.x, a.z), Vector2(b.x, b.z)) != null


# A dimmed person outside the border moves from `from` toward `to`. If the move crosses an intact stretch, it stops just
# short of the line. Otherwise (inside, or through a gap) the move is unchanged.
func clip_move(from: Vector3, to: Vector3) -> Vector3:
	if not active:
		return to
	var a2 := Vector2(from.x, from.z)
	var b2 := Vector2(to.x, to.z)
	if Geometry2D.is_point_in_polygon(a2, polygon):
		return to
	var hit: Variant = _crossing(a2, b2)
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
		return Config.BORDER_GAP_COLOUR
	return Config.BORDER_INTACT_COLOUR


# Round 24: the outline alpha of segment `j` (1 except along an arm that is pulling in; see BorderCentre.outline_alpha).
func segment_fade(j: int) -> float:
	var n := polygon.size()
	if n < 3 or not _centre_ctl.is_retreating():
		return 1.0
	return _centre_ctl.outline_alpha(polygon[j], polygon[(j + 1) % n])


func segment_is_gap(j: int) -> bool:
	return j >= 0 and j < _sample_gap.size() and _sample_gap[j]


# The middle of each gap, in world coordinates (the points the off-screen gap arrows point at).
func gap_midpoints() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k: int in range(segment_gap.size()):
		if segment_gap[k]:
			var mid := _point_at_open(_phase + (float(k) + 0.5) * spacing)
			out.append(Vector3(mid.x, 0.0, mid.y))
	return out


# The gap middles as of the last update(), for the things that read them every frame (do not change the result).
func gap_midpoints_cached() -> Array[Vector3]:
	return _mids_cache


# Round 13b: carries each open gap's age over from last frame (a gap within GAP_TRACK_RADIUS of an old one is the same
# gap) and starts new ones at zero.
func _update_gap_ages(delta: float) -> void:
	_mids_cache = gap_midpoints()
	_tracker.update(segment_gap, _mids_cache, delta)


# How urgent each open gap is, 0 (just opened) to 1 (open GAP_URGENCY_SECONDS or more), in gap_midpoints() order.
func gap_urgencies() -> Array[float]:
	return _tracker.urgencies


# Urgency (0 to 1) of a faltering rescued person: how long they have faltered, over GAP_URGENCY_SECONDS.
func falter_urgency(p: Person) -> float:
	var age: float = _falter_age.get(p, 0.0)
	return clampf(age / Config.GAP_URGENCY_SECONDS, 0.0, 1.0)


# The gap pulse right now (see gap_pulse).
func pulse() -> float:
	return gap_pulse(_time)


# Round 12a: a dim player makes the troupe lose heart. The border loses ground DIM_LOSS_MULT times faster and flickers.
func set_player_dim(dim: bool) -> void:
	player_dim = dim
	loss_mult = Config.DIM_LOSS_MULT if dim else 1.0


# How bright the line and haze are drawn: 1 normally, pulsing between DIM_FLICKER_MIN and 1 while the player is dim.
func flicker() -> float:
	if not player_dim:
		return 1.0
	var wave := 0.5 + 0.5 * sin(TAU * _time / Config.DIM_FLICKER_SECONDS)
	return lerpf(Config.DIM_FLICKER_MIN, 1.0, wave)


# The gap pulse at time `t`: 0 at its trough, 1 at its peak, once every BORDER_GAP_PULSE_SECONDS. It is a cosine, so
# it is soft at both ends and never a hard edge.
static func gap_pulse(t: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t / Config.BORDER_GAP_PULSE_SECONDS)


# Round 12b: how much a dimmed person wants to press at the border member standing at `pos`, 0 to 1. It mixes how
# recently that stretch advanced (EDGE_RECENCY_WEIGHT; 1 just pushed, 0 after EDGE_RECENT_SECONDS) with how far out it
# is compared with the rest of the loop. 0 when there is no border.
func edge_pressure(pos: Vector3) -> float:
	if not active or _raw_radii.is_empty():
		return 0.0
	var n := _raw_radii.size()
	var to := Vector2(pos.x - centre.x, pos.z - centre.z)
	var i := posmod(roundi(atan2(to.y, to.x) / TAU * float(n)), n)
	var recency := clampf(1.0 - (_time - _pushed_at[i]) / Config.EDGE_RECENT_SECONDS, 0.0, 1.0)
	var lo: float = _raw_radii.min()
	var hi: float = _raw_radii.max()
	var outer := 0.5
	if hi - lo > 0.01:
		outer = (_raw_radii[i] - lo) / (hi - lo)
	return Config.EDGE_RECENCY_WEIGHT * recency + (1.0 - Config.EDGE_RECENCY_WEIGHT) * outer


# How many separate gaps the loop has: runs of neighbouring gap segments count once (a whole open loop counts as one).
func gap_region_count() -> int:
	var m := segment_gap.size()
	var runs := 0
	for k: int in range(m):
		if segment_gap[k] and not segment_gap[(k + m - 1) % m]:
			runs += 1
	if runs == 0 and gap_count() > 0:
		return 1
	return runs


# True when `p` is a border member who is faltering right now.
func is_faltering(p: Person) -> bool:
	return members.has(p) and p.is_faltering()


func gap_count() -> int:
	var n := 0
	for g: bool in segment_gap:
		if g:
			n += 1
	return n


# True while landmark block number `index` (Config.LANDMARK_NAMES order) is beautified.
func landmark_beautified(index: int = 0) -> bool:
	return index < landmark_buildings.size() and landmark_buildings[index].beautified


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


# ---- Loop variants
# ---------------------------------------------------------------------------------------------------


# Per angle, the smoothed radius times the size factor. A block on the ray that the radius reaches is wrapped: the
# sample jumps to just beyond the far side of the block, so buildings end up inside the loop.
func _organic_polygon(c2: Vector2, n: int, delta: float) -> PackedVector2Array:
	var smooth: Array[float] = BorderShape.smoothed_radii(_raw_radii)
	var count := Config.BORDER_SAMPLES
	var radii: Array[float] = []
	var extra: Array[float] = []
	var body := 0.0
	for r0: float in smooth:
		body += r0 * _scale / float(count)
	body_radius = body
	var arm_ring := _centre_ctl.arm_ring(body)
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var r: float = maxf(smooth[i] * _scale, _centre_ctl.stretch_radius(a, body))  # Round 20: the stretched tip.
		if not arm_ring.is_empty():
			r = maxf(r, arm_ring[i])  # Round 22: the arms kept from finished stretches.
		var block := BorderShape.first_block_along(buildings, c2, Vector2(cos(a), sin(a)))
		var wrapped := r
		if block.x > 0.0 and block.x < r:
			wrapped = maxf(r, block.y + 0.5)
		radii.append(r)
		extra.append(wrapped - r)
	# Round 18: a block seen by one or two rays used to leave a one-sample spike, a neck narrower than the spacing. The
	# extra radius it asks for now spreads to the neighbouring samples as a tent BORDER_WRAP_TENT samples wide each side.
	var pts := PackedVector2Array()
	for i: int in range(count):
		var lift := 0.0
		for off: int in range(-Config.BORDER_WRAP_TENT, Config.BORDER_WRAP_TENT + 1):
			var share := 1.0 - float(absi(off)) / float(Config.BORDER_WRAP_TENT + 1)
			lift = maxf(lift, extra[posmod(i + off, count)] * share)
		var a := TAU * float(i) / float(count)
		pts.append(c2 + Vector2(cos(a), sin(a)) * (radii[i] + lift))
	# Round 16: the map edge seals the territory. Points beyond the edge are pulled onto it, and a segment between two
	# points on the same edge is sealed: it counts as closed border, so nobody stands on it and the loop's size is
	# measured by its open length only (the loop grows elsewhere to make up for it).
	_sealed = BorderShape.clamp_to_map(pts)
	BorderShape.drop_short_seals(pts, _sealed, Config.BORDER_MIN_SEAL_RUN)
	# Soft normalisation: ease the size so the open perimeter moves toward n x spacing (never below the smallest circle).
	var raw := BorderShape.open_perimeter_of(pts, _sealed)
	var circle := BorderShape.circle_polygon(c2, Config.BORDER_MIN_RADIUS, Config.BORDER_SAMPLES)
	var smallest := BorderShape.perimeter_of(circle)
	var target := maxf(float(n) * Config.BORDER_TARGET_SPACING, smallest)
	if raw > 0.001:
		var desired := clampf(_scale * target / raw, BorderShape.SCALE_FLOOR, 5.0)
		if _centre_ctl.has_arms() or _centre_ctl.stretching:
			# Round 22: the body never squeezes below BEACON_BODY_MIN of the plain radius. When the arms still make the loop
			# too long at that size (people were lost) they retreat (BorderCentre.pull_in); otherwise a pull-in is over.
			var min_scale := Config.BEACON_BODY_MIN * BorderCentre.circle_radius(n) * _scale / maxf(body, 0.001)
			desired = maxf(desired, min_scale)
			# Round 23: the scale never goes under its floor (0.2), so for a small head count min_scale lies below it and
			# the old test (scale <= min_scale x 1.03) was never true: nothing pulled in. The test is now against the
			# floor the scale can really reach, with room for the lag of the ease.
			var squeezed := maxf(min_scale, BorderShape.SCALE_FLOOR) * Config.BEACON_PULL_IN_SQUEEZE
			if raw > target * (1.0 + Config.BEACON_PULL_IN_TOLERANCE) and _scale <= squeezed:
				_centre_ctl.pull_in(delta, body, raw / target)
			else:
				_centre_ctl.settled()
		_scale = lerpf(_scale, desired, clampf(delta / Config.BORDER_NORMALISE_SECONDS, 0.0, 1.0))
	# Round 26: the push bows the line inward where it is shoved (after the size is worked out, so the size factor does not
	# grow the loop back out to cancel the dent).
	for i: int in range(mini(count, pts.size())):
		var d := push.dent[i]
		if d <= 0.001 or _sealed[i] > 0.5:
			continue
		var inward := c2 - pts[i]
		var reach := inward.length()
		if reach > 0.01:
			pts[i] += inward / reach * minf(d, reach * 0.6)
	return pts


# ---- Centre, members and slots
# ---------------------------------------------------------------------------------------


# Round 19/20: puts the spirit beacon at `pos` (clamped inside the map); the zone stretches toward it. One at a time.
func place_beacon(pos: Vector3) -> void:
	_centre_ctl.place(pos)


# Where the beacon is, or Vector3.INF when there is none.
func beacon_pos() -> Vector3:
	return _centre_ctl.beacon


func has_beacon() -> bool:
	return _centre_ctl.has_beacon()


# Round 20: the stretch (see BorderCentre): is one under way, where is its tip, and how far from the centre can it go.
func stretch_info() -> Dictionary:
	var c := _centre_ctl
	return {
		"on": c.stretching,
		"tip": c.tip,
		"arms": c.has_arms(),
		"max": c.max_distance(),
		"radius": BorderCentre.circle_radius(member_count + inner_count),
	}


# Round 21: what a stretch toward `aim` would do now (see BorderCentre.plan_toward): reach, outline, reason, refused.
func plan_stretch(aim: Vector3) -> Dictionary:
	return _centre_ctl.plan_toward(aim)


# Round 19/20: the centre is handled by BorderCentre (anchored once the border forms; a beacon stretches the zone).
func _update_centre(rescued: Array[Person], delta: float) -> void:
	_centre_ctl.update(rescued, delta)


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


# The members the loop needs now: the slots its perimeter holds, less BORDER_POST_WORTH for each post.
func required_members() -> int:
	var slots := slot_count if slot_count > 0 else BorderShape.slot_count_for(perimeter)
	return maxi(0, slots - Config.BORDER_POST_WORTH * post_count)


# The beautified buildings the loop passes within BORDER_POST_REACH of. Each entry has the building and the arc length
# of the nearest loop point. At most as many as leave BORDER_MIN_PEOPLE slots for people.
func _find_posts(slots_total: int, held: Array[Building] = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cap := (slots_total - Config.BORDER_MIN_PEOPLE) / Config.BORDER_POST_WORTH
	for b: Building in buildings:
		if not b.beautified or out.size() >= cap:
			continue
		var near := _nearest_loop_point_to_box(b)
		# Round 18: a block that was a post last frame stays one out to BORDER_POST_HOLD x the reach, so a loop edge that sits
		# right at the reach does not flip the post on and off (each flip re-slots the whole ring).
		var reach := Config.BORDER_POST_REACH * (Config.BORDER_POST_HOLD if held.has(b) else 1.0)
		if near.x <= reach:
			out.append({"building": b, "arc": near.y})
	return out


# The distance from a building's footprint to the nearest loop point, and that point's arc length: Vector2(distance,
# arc).
func _nearest_loop_point_to_box(b: Building) -> Vector2:
	var best := Vector2(INF, 0.0)
	for j: int in range(polygon.size()):
		var d := BorderShape.box_distance(polygon[j], b.centre, b.half)
		if d < best.x:
			best = Vector2(d, _arc[j])
	return best


# Round 16: true when polygon segment `j` runs along the map edge (fully closed by the map).
func is_sealed(j: int) -> bool:
	return j >= 0 and j < _sealed.size() and _sealed[j] >= 0.999


# ---- Slot code (see border_slots.gd)
# ----------------------------------------------------------------------------------


func _assign_members(rescued: Array[Person]) -> void:
	_slots.assign_members(rescued)


static func nearest_free_slot(pos2: Vector2, slots: Array[Vector2], taken: Array[bool]) -> int:
	return BorderSlots.nearest_free_slot(pos2, slots, taken)


func _ordered_slots(list: Array[Person], slots: Array[Vector2], taken: Array[bool]) -> Array[int]:
	return _slots.ordered_slots(list, slots, taken)


func _grid_phase(list: Array[Person]) -> float:
	return _slots.grid_phase(list)


func _point_at_arc(s: float) -> Vector2:
	return _slots.point_at_arc(s)


func _point_at_open(s: float) -> Vector2:
	return _slots.point_at_open(s)


func _open_of_arc(a: float) -> float:
	return _slots.open_of_arc(a)


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
	var arrive := Config.BORDER_ARRIVE_GAIN * delta
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
		else:
			p.position += to / d * go


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


# Dimmed people pressing on the border (outside, within BORDER_PRESS_RANGE of the line). On an intact stretch they are
# pushed outward at BORDER_PUSHBACK_SPEED, and the nearest member drains at BORDER_INTACT_DRAIN_FRACTION of the rate
# (round 11). At a gap they drain the nearest member at the full rate, scaled by the night strength. Dimmed people
# inside are handled by GloomSim.
func _press_gloom(people: Array[Person], delta: float, strength: float) -> void:
	if not active:
		return
	var rate := Config.SPREAD_DRAIN_RATE * Config.TD_DRAIN_MULTIPLIER * strength * delta * loss_mult
	for p: Person in people:
		if p.is_rescued or not GloomSim.is_dimmed(p):
			continue
		var p2 := Vector2(p.position.x, p.position.z)
		if Geometry2D.is_point_in_polygon(p2, polygon):
			continue
		var near := _nearest_on_loop(p2)
		var dist: float = near["dist"]
		if dist > Config.BORDER_PRESS_RANGE:
			continue
		var seg: int = near["seg"]
		if is_sealed(seg):
			continue  # Round 16: the map edge is closed border; nothing presses on it.
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
			var best_intact := _nearest_member(p.position)
			if best_intact != null:
				best_intact.drain_joy(rate * Config.BORDER_INTACT_DRAIN_FRACTION)
			var move := out.normalized() * Config.BORDER_PUSHBACK_SPEED * delta
			var lim := Config.BORDER_MAP_LIMIT
			p.position = Vector3(
				clampf(p.position.x + move.x, -lim, lim), p.position.y, clampf(p.position.z + move.y, -lim, lim)
			)


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


# The nearest point on the loop to `p2`: a Dictionary with "dist" (metres), "point" (Vector2) and "seg" (segment
# index).
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
# uses the same bump as a rescue, divided by the size factor so that it shows as about BORDER_SHOVE_AMOUNT metres on
# the line.
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


# ---- Drawing and debug
# -----------------------------------------------------------------------------------------------


# Tells the look to redraw the line, the haze and the gap glow from the current state.
func _draw_lines() -> void:
	if look != null:
		look.refresh()


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
			var mid := _point_at_open(_phase + (float(k) + 0.5) * spacing)
			lbl.position = Vector3(mid.x, 2.0, mid.y)
			lbl.text = "%.1f m%s" % [spacing, " GAP" if segment_gap[k] else ""]
