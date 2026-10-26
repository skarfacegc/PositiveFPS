class_name FeedbackLayer
extends Control

# Round 13b: the communication layer. Everything here is drawn in screen space (a full-screen Control on the HUD, so it
# shows in both looks and stays readable at any zoom), anchored to world points through TopDownMain.world_to_screen:
#   - Faltering border people: a pulsing ring at their feet, a "!" badge above, and a progress ring that fills with
#     their joy toward the falter line as you re-joy them; when it completes a short "closed" flash seals the gap.
#   - Gloom leaking inward from each open gap (grey-violet motes drifting from the gap toward the border centre), faster
#     and denser as the gap stays open.
#   - Mood icons over heads (shield, feet, cloud, umbrella), a faint tether from a dimmed person to each person they
#     shelter (it snaps when they leave), and the bounce-off spark with the reason's icon flashing when joy is blocked.
#   - A pulse ring round the player when spirit is gained, spent or lost (see SpiritMeter for the meter itself).
# The lists below are the data model, so tests can check what is shown without reading pixels.

# Faltering people: {"person", "urgency", "progress", "feet", "head"} (screen positions in pixels).
var markers: Array[Dictionary] = []
# Leak motes: {"pos": Vector3, "vel": Vector3, "age": float, "life": float}.
var motes: Array[Dictionary] = []
# Mood and shelter icons: {"person", "kind", "pos", "lift", "flash"}.
var icons: Array[Dictionary] = []
# Sheltering tethers this frame: {"a": Vector3, "b": Vector3}; the broken ones: {"a", "b", "left"}.
var tethers: Array[Dictionary] = []
var snaps: Array[Dictionary] = []
# Blocked-joy sparks: {"pos": Vector3, "left": float, "colour": Color, "turn": float}.
var sparks: Array[Dictionary] = []
# "Closed" flashes where a faltering person recovered: {"pos": Vector3, "left": float, "links": Array[Vector3]}.
var closes: Array[Dictionary] = []
# Pulse rings round the player: {"kind": SpiritMeter.Moment, "left": float}.
var player_pulses: Array[Dictionary] = []
# How many times joy was blocked (for tests and the debug line).
var blocked_count: int = 0
var main: TopDownMain
var _flash: Dictionary = {}
var _was_faltering: Dictionary = {}
var _gaps_near: Dictionary = {}
var _links: Dictionary = {}
var _clock: float = 0.0
var _pending: float = 0.0
var _odd_frame: bool = false
var _gap_mids: Array[Vector3] = []
var _was_busy: bool = false
var _any_sheltered: bool = false
var _spawn_acc: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_rng.seed = Config.RNG_SEED + 13


# Advances every effect by `delta`, rebuilds the data model from the level and redraws.
func tick(delta: float) -> void:
	_clock += delta
	_age_effects(delta)
	# The data model is rebuilt every other frame (30 Hz) with the time that has passed; it is plenty for overlays.
	_pending += delta
	_odd_frame = not _odd_frame
	if _odd_frame:
		_gap_mids = main.border.gap_midpoints_cached()
		_update_markers()
		_update_leak(_pending)
		_update_icons(_pending)
		_update_tethers()
		_pending = 0.0
	var busy := not (
		markers.is_empty()
		and motes.is_empty()
		and icons.is_empty()
		and tethers.is_empty()
		and snaps.is_empty()
		and sparks.is_empty()
		and closes.is_empty()
		and player_pulses.is_empty()
	)
	if busy or _was_busy:
		queue_redraw()
	_was_busy = busy


# Joy was turned away from `p` (Person.joy_blocked): a spark at their chest, and the reason's icon flashes.
func on_blocked(p: Person, reason: int) -> void:
	blocked_count += 1
	var col := Config.SHELTER_COLOUR.lightened(0.5) if reason == Person.Block.SHELTERED else Color(1, 1, 1)
	sparks.append(
		{"pos": p.chest_position(), "left": Config.BLOCK_SPARK_SECONDS, "colour": col, "turn": _rng.randf() * TAU}
	)
	if sparks.size() > 24:
		sparks.pop_front()
	_flash[p] = {"reason": reason, "left": Config.BLOCK_FLASH_SECONDS}


# A spirit moment (SpiritMeter.Moment): a ring pulses round the player.
func pulse_player(kind: int) -> void:
	player_pulses.append({"kind": kind, "left": 0.5})


# True while the icon flash of `p` is showing (0 to 1, 1 just after joy was blocked).
func flash_of(p: Person) -> float:
	if not _flash.has(p):
		return 0.0
	return _num(_flash[p]["left"]) / Config.BLOCK_FLASH_SECONDS


# The marker of `p`, or an empty Dictionary when they are not faltering.
func marker_for(p: Person) -> Dictionary:
	for m: Dictionary in markers:
		if m["person"] == p:
			return m
	return {}


# Typed reads from the effect dictionaries.
static func _int(v: Variant) -> int:
	var out: int = v
	return out


static func _vec3(v: Variant) -> Vector3:
	var out: Vector3 = v
	return out


# A float read from one of the effect dictionaries.
static func _num(v: Variant) -> float:
	var out: float = v
	return out


# ---- The data model, rebuilt each tick
# -------------------------------------------------------------------------------------------------------------


func _update_markers() -> void:
	markers.clear()
	var now: Dictionary = {}
	var mids := _gap_mids
	for p: Person in main.border.faltering:
		if not p.is_rescued or not p.is_faltering():
			continue
		now[p] = true
		var line := p.joy_needed() * Config.MEMBER_FALTER_FRACTION
		var near: Array[Vector3] = []
		for g: Vector3 in mids:
			if GloomSim.flat_dist(g, p.global_position) <= Config.GAP_TRACK_RADIUS:
				near.append(g)
		_gaps_near[p] = near
		(
			markers
			. append(
				{
					"person": p,
					"urgency": main.border.falter_urgency(p),
					"progress": clampf(p.joy / line, 0.0, 1.0),
					"feet": main.world_to_screen(p.global_position),
					"head": main.world_to_screen(p.global_position + Vector3(0, 3.0, 0)),
				}
			)
		)
	for p: Person in _was_faltering.keys():
		if now.has(p) or not is_instance_valid(p) or not p.is_rescued:
			continue
		var links: Array[Vector3] = []
		var near_gaps: Array = _gaps_near.get(p, [])
		links.assign(near_gaps)
		closes.append({"pos": p.global_position, "left": Config.FALTER_CLOSED_SECONDS, "links": links})
	for p: Person in _gaps_near.keys():
		if not now.has(p):
			_gaps_near.erase(p)
	_was_faltering = now


# Spawns and drifts the leak motes: from each open gap, inward toward the border centre.
func _update_leak(delta: float) -> void:
	for i: int in range(motes.size() - 1, -1, -1):
		var m: Dictionary = motes[i]
		var age: float = m["age"] + delta
		if age >= _num(m["life"]):
			motes.remove_at(i)
			continue
		m["age"] = age
		var pos: Vector3 = m["pos"]
		var vel: Vector3 = m["vel"]
		m["pos"] = pos + vel * delta
	var mids := _gap_mids
	var urg := main.border.gap_urgencies()
	if not main.border.active:
		return
	if mids.is_empty():
		return
	# Only gaps near the view leak motes (the rest could not be seen).
	var half := main.view_half_extents()
	var reach := maxf(half.x, half.y) + Config.LEAK_VIEW_MARGIN
	var at := main.player.global_position
	for gi: int in range(mids.size()):
		if GloomSim.flat_dist(mids[gi], at) > reach:
			continue
		var u := urg[gi] if gi < urg.size() else 0.0
		var rate := float(Config.LEAK_MOTES_PER_GAP) / Config.LEAK_LIFE_SECONDS * lerpf(0.7, 2.0, u)
		var acc: float = _spawn_acc.get(gi, 0.0) + rate * delta
		while acc >= 1.0:
			acc -= 1.0
			if motes.size() < Config.LEAK_MOTES_MAX:
				motes.append(_new_mote(mids[gi], u))
		_spawn_acc[gi] = acc


func _new_mote(gap: Vector3, urgency: float) -> Dictionary:
	var out := Vector3(gap.x - main.border.centre.x, 0.0, gap.z - main.border.centre.z)
	out = out.normalized() if out.length() > 0.01 else Vector3.FORWARD
	var side := Vector3(-out.z, 0.0, out.x)
	var start := gap + out * _rng.randf_range(0.4, 1.4) + side * _rng.randf_range(-1.3, 1.3)
	start.y = 0.5
	var speed := Config.LEAK_SPEED * _rng.randf_range(0.8, 1.2) * lerpf(1.0, 1.5, urgency)
	var vel := -out * speed + side * _rng.randf_range(-0.4, 0.4)
	return {"pos": start, "vel": vel, "age": 0.0, "life": Config.LEAK_LIFE_SECONDS * _rng.randf_range(0.8, 1.2)}


func _update_icons(delta: float) -> void:
	icons.clear()
	for p: Person in _flash.keys():
		var left: float = _num(_flash[p]["left"]) - delta
		if left <= 0.0 or not is_instance_valid(p):
			_flash.erase(p)
		else:
			_flash[p]["left"] = left
	var view := get_viewport_rect().grow(60.0)
	_any_sheltered = false
	for p: Person in main.people:
		if p.is_rescued:
			continue
		_any_sheltered = _any_sheltered or p.sheltered
		var kinds: Array[int] = []
		var mood_kind := MoodIcons.kind_for_mood(p.active_mood())
		if mood_kind != MoodIcons.Kind.NONE:
			kinds.append(mood_kind)
		if p.sheltered:
			kinds.append(MoodIcons.Kind.UMBRELLA)
		if kinds.is_empty():
			continue
		var head := main.world_to_screen(p.global_position + Vector3(0, 3.0, 0))
		if not view.has_point(head):
			continue
		for k: int in range(kinds.size()):
			var kind := kinds[k]
			var offset := (float(k) - float(kinds.size() - 1) * 0.5) * (Config.MOOD_ICON_SIZE + 6.0)
			var lift := 0.0
			if kind == MoodIcons.Kind.CLOUD and p.glum_up:
				lift = 1.0
			var flash := 0.0
			if _flash.has(p) and MoodIcons.kind_for_block(_int(_flash[p]["reason"])) == kind:
				flash = flash_of(p)
			icons.append({"person": p, "kind": kind, "pos": head + Vector2(offset, 0.0), "lift": lift, "flash": flash})


# Tethers from each dimmed person to each wistful or gloomy person they shelter. A link that was there last frame and is
# gone now snaps.
func _update_tethers() -> void:
	tethers.clear()
	var now: Dictionary = {}
	var people := main.people
	for i: int in range(people.size()):
		if not _any_sheltered:
			break
		var q := people[i]
		if not GloomSim.is_dark(q):
			continue
		for j: int in range(people.size()):
			var p := people[j]
			if p == q or p.is_rescued or not p.sheltered or GloomSim.is_dark(p):
				continue
			if GloomSim.flat_dist(p.global_position, q.global_position) > Config.SHELTER_RADIUS:
				continue
			var link := {"a": q.chest_position(), "b": p.chest_position()}
			now[i * 1000 + j] = link
			tethers.append(link)
	for key: int in _links.keys():
		if not now.has(key):
			var old: Dictionary = _links[key]
			snaps.append({"a": old["a"], "b": old["b"], "left": Config.TETHER_SNAP_SECONDS})
	_links = now


func _age_effects(delta: float) -> void:
	_age_list(snaps, delta)
	_age_list(sparks, delta)
	_age_list(closes, delta)
	_age_list(player_pulses, delta)


static func _age_list(list: Array[Dictionary], delta: float) -> void:
	for i: int in range(list.size() - 1, -1, -1):
		var left: float = _num(list[i]["left"]) - delta
		list[i]["left"] = left
		if left <= 0.0:
			list.remove_at(i)


# ---- Drawing
# -------------------------------------------------------------------------------------------------------------


func _draw() -> void:
	_draw_motes()
	_draw_tethers()
	_draw_closes()
	for m: Dictionary in markers:
		_draw_marker(m)
	for ic: Dictionary in icons:
		_draw_icon(ic)
	_draw_sparks()
	_draw_player_pulses()


func _draw_motes() -> void:
	for m: Dictionary in motes:
		var t: float = _num(m["age"]) / _num(m["life"])
		var pos: Vector3 = m["pos"]
		var col := Config.LEAK_COLOUR
		col.a = 0.75 * minf(t / 0.15, 1.0) * (1.0 - t)
		draw_circle(main.world_to_screen(pos), 2.5 + 3.5 * t, col)


func _draw_tethers() -> void:
	for t: Dictionary in tethers:
		var a := main.world_to_screen(_vec3(t["a"]))
		var b := main.world_to_screen(_vec3(t["b"]))
		draw_line(a, b, Config.TETHER_COLOUR, 2.0, true)
		draw_circle(a, 3.0, Config.TETHER_COLOUR)
		draw_circle(b, 3.0, Config.TETHER_COLOUR)
	for s: Dictionary in snaps:
		var f: float = _num(s["left"]) / Config.TETHER_SNAP_SECONDS
		var a := main.world_to_screen(_vec3(s["a"]))
		var b := main.world_to_screen(_vec3(s["b"]))
		var col := Config.TETHER_COLOUR
		col.a = 0.8 * f
		var gap := (1.0 - f) * 14.0
		var dir := (b - a).normalized() if (b - a).length() > 1.0 else Vector2.RIGHT
		var mid := (a + b) * 0.5
		draw_line(a, mid - dir * (4.0 + gap), col, 2.0, true)
		draw_line(b, mid + dir * (4.0 + gap), col, 2.0, true)
		for k: int in range(4):
			var ang := TAU * float(k) / 4.0 + 0.4
			var d := Vector2(cos(ang), sin(ang))
			draw_line(mid + d * 3.0, mid + d * (6.0 + 12.0 * (1.0 - f)), col, 1.8, true)


func _draw_closes() -> void:
	for c: Dictionary in closes:
		var f: float = _num(c["left"]) / Config.FALTER_CLOSED_SECONDS
		var at := main.world_to_screen(_vec3(c["pos"]))
		var col := Config.FALTER_SEAL_COLOUR
		col.a = f
		for g: Vector3 in c["links"]:
			var seal := col
			seal.a = f * 0.9
			draw_line(main.world_to_screen(g), at, seal, 3.0 + 5.0 * f, true)
		var r := lerpf(60.0, 20.0, f)
		draw_arc(at, r, 0.0, TAU, 32, col, 4.0, true)
		var fill := col
		fill.a = 0.35 * f
		draw_circle(at + Vector2(0, -20), 22.0 * (1.2 - 0.4 * f), fill)


func _draw_marker(m: Dictionary) -> void:
	var u: float = m["urgency"]
	var feet: Vector2 = m["feet"]
	var head: Vector2 = m["head"]
	var wave := 0.5 - 0.5 * cos(TAU * _clock * lerpf(Config.FALTER_PULSE_HZ_MIN, Config.FALTER_PULSE_HZ_MAX, u))
	var base := Config.BORDER_GAP_COLOUR.lerp(Color(1.0, 0.85, 0.75), u * 0.6)
	# The pulsing marker at the feet: a flattened ring that swells with the beat.
	var radius := Config.FALTER_MARKER_RADIUS * (0.85 + 0.3 * wave) * (1.0 + 0.3 * u)
	var ring := base
	ring.a = lerpf(0.35, 0.95, wave) * (0.65 + 0.35 * u)
	var pts := PackedVector2Array()
	for i: int in range(25):
		var a := TAU * float(i) / 24.0
		pts.append(feet + Vector2(cos(a) * radius, sin(a) * radius * 0.55))
	draw_polyline(pts, ring, 3.0 + 2.0 * u, true)
	var fill := ring
	fill.a *= 0.18
	draw_colored_polygon(pts, fill)
	# The progress ring around the body: fills toward the falter line as joy comes back.
	var centre := (feet + head) * 0.5 + Vector2(0, 6)
	var prog: float = m["progress"]
	draw_arc(centre, Config.FALTER_RING_RADIUS, 0.0, TAU, 40, Color(0.1, 0.08, 0.14, 0.45), 6.0, true)
	if prog > 0.0:
		var pc := Config.BORDER_GAP_COLOUR.lerp(Config.FALTER_SEAL_COLOUR, prog)
		draw_arc(centre, Config.FALTER_RING_RADIUS, -PI * 0.5, -PI * 0.5 + TAU * prog, 40, pc, 6.0, true)
	# The "!" badge above the head: bigger and bobbing faster as the gap stays open.
	var badge := Config.FALTER_BADGE_SIZE * (1.0 + 0.35 * u) * (1.0 + 0.1 * wave)
	var badge_col := base
	badge_col.a = 1.0
	MoodIcons.draw(self, MoodIcons.Kind.BANG, head + Vector2(0, -22.0 - 4.0 * wave), badge, badge_col)


func _draw_icon(ic: Dictionary) -> void:
	var kind: int = ic["kind"]
	var lift: float = ic["lift"]
	var flash: float = ic["flash"]
	var col := MoodIcons.colour_for(kind)
	var pos: Vector2 = ic["pos"]
	if lift > 0.0:
		col = Config.GLUM_UP_ICON_COLOUR
		pos += Vector2(0, -10.0 - 3.0 * sin(_clock * 10.0))
	col = col.lerp(Color.WHITE, flash)
	MoodIcons.draw(self, kind, pos, Config.MOOD_ICON_SIZE * (1.0 + 0.8 * flash) * (1.0 + 0.2 * lift), col)


func _draw_sparks() -> void:
	for s: Dictionary in sparks:
		var f: float = _num(s["left"]) / Config.BLOCK_SPARK_SECONDS
		var t := 1.0 - f
		var at := main.world_to_screen(_vec3(s["pos"]))
		var col: Color = s["colour"]
		col.a = f
		var turn: float = s["turn"]
		for k: int in range(8):
			var a := turn + TAU * float(k) / 8.0
			var d := Vector2(cos(a), sin(a))
			draw_line(at + d * (8.0 + 12.0 * t), at + d * (16.0 + 24.0 * t), col, 2.5, true)


func _draw_player_pulses() -> void:
	for p: Dictionary in player_pulses:
		var f: float = _num(p["left"]) / 0.5
		var kind: int = p["kind"]
		var col := Config.SPIRIT_GAIN_COLOUR
		var radius := lerpf(70.0, 24.0, f)
		if kind == SpiritMeter.Moment.SPEND:
			col = Config.SPIRIT_SPEND_COLOUR
			radius = lerpf(24.0, 70.0, f)
		elif kind == SpiritMeter.Moment.LOSS:
			col = Config.SPIRIT_LOSS_COLOUR
			radius = lerpf(80.0, 22.0, f)
		col.a = f * 0.9
		var at := main.world_to_screen(main.player.global_position)
		var pts := PackedVector2Array()
		for i: int in range(25):
			var a := TAU * float(i) / 24.0
			pts.append(at + Vector2(cos(a) * radius, sin(a) * radius * 0.6))
		draw_polyline(pts, col, 4.0, true)
