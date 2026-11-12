class_name GloomTide
extends Node

# Walls and gates: Pressure (#14). One surge a night replaces the two gloom tides (the class keeps its old name). It
# comes down one street, drawn from the level's seed among the streets that meet a gate of the zone when the warning
# starts, and it peaks at midnight (the middle of the push is NightConfig.SURGE_PEAK_PROGRESS of the night).
#  - Warning (SURGE_WARN_SECONDS): fog gathers at the far end of the street, a mark on the minimap, one edge pointer,
#    the light cools and a banner (again SURGE_SOON_SECONDS before the push). The banner is the slim bar under the
#    night bar, so it reaches the player wherever they are.
#  - Surge (SURGE_SECONDS): the fog rolls down the street and pushes the gate it meets with SURGE_PUSH (BorderPush.
#    set_gate_wave) and the gates either side of that one with SURGE_SIDE_SHARE of it. The push builds as the front
#    arrives and fades at the end.
#  - Aftermath (SURGE_AFTERMATH_SECONDS): the fog is gone, the light warms again and dimmed arrivals ease.
# Times are the night's own clock (NightCycle.elapsed): fixed-step. Placeholder look: a grey fog band with dark figures;
# the styled look has its own cloud (StylePush) that follows the same place.

signal surge_warned(street: String, angle: float)
signal surge_started(street: String, angle: float, members: int)
signal surge_ended(street: String, angle: float, members: int)

enum Phase { IDLE, WARNING, SURGE, AFTERMATH, DONE }

var main: TopDownMain
# The night's surge: "start" (night seconds), "roll" (0 to 1, from the seed: which candidate street), "warned",
# "soon", "started" and "ended" (bools), and once warned: "street" (index into streets()), "origin" and "dir" (the
# far end and the way it runs), "street_name", "end_name", "angle" (from the town's middle toward the far end),
# "gate" (the zone gate it meets, -1 for none), "gate_along" (metres down the street to it) and "members" (on that
# gate when it started).
var surge: Dictionary = {}
var pointer: TidePointer  # The edge pointer (placeholder look), shown during the warning.
var fog: MeshInstance3D  # The fog band (placeholder look), shown through the warning and the surge.
var fog_volume: MeshInstance3D  # The tall box of the placeholder fog (child of `fog`, shares its material).
var figures: Array[MeshInstance3D] = []  # Dark figures walking in the fog (children of `fog`).
var styled_fog: Node3D  # The styled fog banks and figures (shown in the styled look, see StylePush).
var styled_figures: Array[Node3D] = []  # The styled figures, children of `styled_fog`.
var wave_force: float = 0.0  # The force the surge puts on the line now (before the night's strength).
var front: float = 0.0  # Metres down the street the fog's leading edge has got to.
var pulse_count: int = 0  # How many times the warning pulsed the pointer and the banner (the warning, then "soon").
var _rng := RandomNumberGenerator.new()
var _pointer_since: float = 0.0


# Builds the schedule, the fog band and the edge pointer, and wires them to `level`. One line in TopDownMain.
static func attach(level: TopDownMain) -> GloomTide:
	var t := GloomTide.new()
	t.main = level
	level.add_child(t)
	t._build_schedule()
	t._build_fog()
	t.pointer = TidePointer.new()
	level.hud.add_child(t.pointer)
	Looks.note_placeholder(t.pointer, "tide_pointer")
	level.events.wire_lost(level.border)
	return t


func _process(delta: float) -> void:
	update(delta)


# Advances the surge by the night's clock and applies it: the warning, the start and the end (with their signals and
# banners), the push on the gates, the light and the arrivals, and the minimap, pointer and fog. Tests call it directly.
func update(delta: float) -> void:
	if main == null or not Config.tides_on():
		return
	if main.running:
		_advance()
		_refresh_target()
	_apply_push()
	_apply_night()
	_show(delta)


# Where the surge is now (see Phase).
func phase() -> int:
	if surge.is_empty() or not surge["warned"]:
		return Phase.IDLE
	if not surge["started"]:
		return Phase.WARNING
	if not surge["ended"]:
		return Phase.SURGE
	var done: float = surge["start"] + NightConfig.SURGE_SECONDS + NightConfig.SURGE_AFTERMATH_SECONDS
	return Phase.AFTERMATH if main.night.elapsed < done else Phase.DONE


# True from the warning until the surge ends (the fog and the pointer are up).
func is_up() -> bool:
	var p := phase()
	return p == Phase.WARNING or p == Phase.SURGE


# How far through the push the surge is, 0 (not started) to 1 (over).
func progress() -> float:
	if surge.is_empty():
		return 0.0
	var start: float = surge["start"]
	return clampf((main.night.elapsed - start) / NightConfig.SURGE_SECONDS, 0.0, 1.0)


# How hard the surge pushes now, 0 to 1: it builds as the front arrives and fades over the last SURGE_FADE of the push.
func push_share() -> float:
	if phase() != Phase.SURGE:
		return 0.0
	var f := progress()
	var build := smoothstep(NightConfig.SURGE_ARRIVE * 0.6, NightConfig.SURGE_ARRIVE, f)
	return build * (1.0 - smoothstep(1.0 - NightConfig.SURGE_FADE, 1.0, f))


# The gates the surge pushes and their shares: the gate it meets at 1, the gates either side of that one (next in the
# line) at SURGE_SIDE_SHARE. Empty when it meets none.
func pushed_gates() -> Dictionary:
	var out: Dictionary = {}
	if surge.is_empty() or not surge.has("gate"):
		return out
	var g: int = surge["gate"]
	var n := main.border.zone.gates.size()
	if g < 0 or g >= n:
		return out
	out[g] = 1.0
	if n > 1:
		for side: int in [posmod(g - 1, n), posmod(g + 1, n)]:
			if not out.has(side):
				out[side] = NightConfig.SURGE_SIDE_SHARE
	return out


# Works the edge pointer out now: its tip sits where the ray from the screen centre toward the street's far end leaves
# the safe rectangle (HudSafeArea.current, shrunk by WOBBLE_ALERT_REACH), so the whole pointer stays on screen and
# clear of the HUD. Hidden when no warning is up or the window is too small for the HUD (headless).
func refresh_pointer() -> void:
	if phase() != Phase.WARNING or not main.running:
		pointer.hide_pointer()
		return
	var screen := main.get_viewport().get_visible_rect().size
	var safe: Rect2 = HudSafeArea.current(main, screen)
	var tips := safe.grow(-HudConfig.WOBBLE_ALERT_REACH)
	if tips.size.x <= 0.0 or tips.size.y <= 0.0:
		pointer.hide_pointer()
		return
	var angle: float = surge["angle"]
	var dir := Vector2.from_angle(angle)
	var far := main.border.centre + Vector3(dir.x, 0.0, dir.y) * NightConfig.TIDE_POINTER_FAR
	var placed := WobbleAlert.tip_for(main.world_to_screen(far), screen, tips)
	var at: Vector2 = placed["tip"]
	var outward: Vector2 = placed["dir"]
	pointer.show_at(at, outward)


# The compass name of a side (north is -z, as the camera sees it: north is up the screen).
static func side_name(angle: float) -> String:
	var d := Vector2.from_angle(angle)
	if absf(d.x) >= absf(d.y):
		return "east" if d.x > 0.0 else "west"
	return "south" if d.y > 0.0 else "north"


# ---- The streets
# ---------------------------------------------------------------------------------------------------


# Every street the surge can come down: each of the town's four vertical and four horizontal streets from either end.
# {"vertical": bool, "line": the coordinate of its middle, "origin": the far end (Vector2), "dir": the way it runs
# (unit), "end_name": the compass side its far end is on, "name": which street it is ("far west", "east", ...)}.
static func streets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var half := TownGrid.span() * 0.5
	for vertical: bool in [true, false]:
		for i: int in range(TownConfig.TOWN_GRID_CELLS - 1):
			var strip := 2 * i + 1
			var line := TownGrid.tile_lo(strip) + TownGrid.tile_len(strip) * 0.5
			for from_low: bool in [true, false]:
				var edge := -half if from_low else half
				var origin := Vector2(line, edge) if vertical else Vector2(edge, line)
				var dir := Vector2.ZERO
				if vertical:
					dir = Vector2(0.0, 1.0 if from_low else -1.0)
				else:
					dir = Vector2(1.0 if from_low else -1.0, 0.0)
				var end_name := side_name(origin.angle())
				out.append(
					{
						"vertical": vertical,
						"line": line,
						"origin": origin,
						"dir": dir,
						"end_name": end_name,
						"name": _street_name(vertical, line, half)
					}
				)
	return out


static func _street_name(vertical: bool, line: float, half: float) -> String:
	var side := ""
	if vertical:
		side = "west" if line < 0.0 else "east"
	else:
		side = "north" if line < 0.0 else "south"
	return ("far " if absf(line) > half * 0.5 else "") + side


# The first gate of `gates` the surge down `street` meets: a gate facing the way it comes from, whose line lies within
# half a street's width (and SURGE_STREET_REACH) of the street's middle. {"gate": index, "along": metres down the street
# to it}, or an empty Dictionary when it meets none.
static func street_meets(street: Dictionary, gates: Array[Dictionary]) -> Dictionary:
	var dir: Vector2 = street["dir"]
	var origin: Vector2 = street["origin"]
	var line: float = street["line"]
	var vertical: bool = street["vertical"]
	var reach := TownConfig.TOWN_STREET_WIDTH * 0.5 + NightConfig.SURGE_STREET_REACH
	var best: Dictionary = {}
	var best_score := INF
	for g: Dictionary in gates:
		var out: Vector2 = g["out"]
		if out.dot(dir) > -0.7:
			continue
		var ga: Vector2 = g["a"]
		var gb: Vector2 = g["b"]
		var lo := minf(ga.x, gb.x) if vertical else minf(ga.y, gb.y)
		var hi := maxf(ga.x, gb.x) if vertical else maxf(ga.y, gb.y)
		var across := 0.0 if line >= lo and line <= hi else minf(absf(lo - line), absf(hi - line))
		if across > reach:
			continue
		var mid: Vector2 = g["mid"]
		var along := (mid - origin).dot(dir)
		var score := along + across * 0.01  # Level in distance: the gate the street runs straight into wins.
		if score < best_score:
			best_score = score
			best = {"gate": g["id"], "along": along}
	return best


# The streets (indexes into streets()) whose surge would meet a gate of `gates`.
static func candidates(gates: Array[Dictionary]) -> Array[int]:
	var out: Array[int] = []
	var all := streets()
	for i: int in range(all.size()):
		if not street_meets(all[i], gates).is_empty():
			out.append(i)
	return out


# ---- The schedule and its clock
# ---------------------------------------------------------------------------------------------------


# Draws the night's surge: it starts so that its middle is at SURGE_PEAK_PROGRESS of the night (midnight), and which
# street it comes down is a roll from the seed (RNG_SEED + SURGE_SEED_OFFSET) over the candidates at the warning.
func _build_schedule() -> void:
	_rng.seed = Config.RNG_SEED + NightConfig.SURGE_SEED_OFFSET
	var peak := NightConfig.SURGE_PEAK_PROGRESS * NightConfig.NIGHT_LENGTH
	surge = {
		"start": peak - NightConfig.SURGE_SECONDS * 0.5,
		"roll": _rng.randf(),
		"warned": false,
		"soon": false,
		"started": false,
		"ended": false,
		"members": 0,
	}


# The clock: each step fires at most once, in order (warn, start, end), even when time jumps past several.
func _advance() -> void:
	var now := main.night.elapsed
	var start: float = surge["start"]
	if not surge["warned"] and now >= start - NightConfig.SURGE_WARN_SECONDS:
		if not _choose_street():
			return
		surge["warned"] = true
		var street: Dictionary = streets()[surge["street"]]
		var street_name := _label(street)
		main.intro.notice(Intro.Prompt.TIDE, NightConfig.SURGE_WARN_TEXT % [street["end_name"], street["name"]])
		surge_warned.emit(street_name, surge["angle"])
		refresh_pointer()
		_pulse_warning()
	if surge["warned"] and not surge["soon"] and now >= start - NightConfig.SURGE_SOON_SECONDS:
		surge["soon"] = true
		var street: Dictionary = streets()[surge["street"]]
		main.intro.notice(Intro.Prompt.TIDE, NightConfig.SURGE_SOON_TEXT % street["name"])
		_pulse_warning()
	if surge["warned"] and not surge["started"] and now >= start:
		surge["started"] = true
		pointer.hide_pointer()
		var street: Dictionary = streets()[surge["street"]]
		main.intro.notice(Intro.Prompt.TIDE, NightConfig.SURGE_START_TEXT % street["name"])
		var members := _members_on_target()
		surge["members"] = members
		surge_started.emit(_label(street), surge["angle"], members)
	if surge["started"] and not surge["ended"] and now >= start + NightConfig.SURGE_SECONDS:
		surge["ended"] = true
		var street: Dictionary = streets()[surge["street"]]
		surge_ended.emit(_label(street), surge["angle"], _members_on_target())


# Surge warning: the edge pointer and the banner swell (visual only), at the warning and again at the "soon" mark.
func _pulse_warning() -> void:
	pulse_count += 1
	pointer.pulse()
	main.intro.pulse()


# A street's label for the recorder and the signals: the end it comes from and the street, "north end of the far east".
func _label(street: Dictionary) -> String:
	return "%s end of the %s" % [street["end_name"], street["name"]]


# Picks the street the surge comes down: the roll over the streets that meet a gate of the zone. False when none does
# (the zone has no gates yet), and the warning waits.
func _choose_street() -> bool:
	var gates: Array[Dictionary] = main.border.zone.gates
	var options := candidates(gates)
	if options.is_empty():
		return false
	var roll: float = surge["roll"]
	var pick := options[mini(floori(roll * float(options.size())), options.size() - 1)]
	var street: Dictionary = streets()[pick]
	var origin: Vector2 = street["origin"]
	surge["street"] = pick
	surge["origin"] = origin
	surge["dir"] = street["dir"]
	surge["street_name"] = street["name"]
	surge["end_name"] = street["end_name"]
	surge["angle"] = origin.angle()
	surge["gate"] = -1
	surge["gate_along"] = 0.0
	return true


# Works out which gate of the zone the surge meets now (the zone changes as the night goes on).
func _refresh_target() -> void:
	if not surge["warned"] or surge["ended"]:
		return
	var street: Dictionary = streets()[surge["street"]]
	var hit := street_meets(street, main.border.zone.gates)
	surge["gate"] = hit.get("gate", -1)
	surge["gate_along"] = hit.get("along", 0.0)


func _members_on_target() -> int:
	var g: int = surge.get("gate", -1)
	return main.border.gate_member_count(g)


# Sets (or clears) the surge's force on the border: SURGE_PUSH x its share now, on the gates it meets.
func _apply_push() -> void:
	wave_force = 0.0
	var share := push_share()
	if share <= 0.0 or not main.border.active or not main.running:
		main.border.push.clear_wave()
		return
	wave_force = NightConfig.SURGE_PUSH * share
	main.border.push.set_gate_wave(pushed_gates(), wave_force)


# The light cools through the warning, stays cool through the surge and warms over the aftermath; dimmed arrivals ease
# in the aftermath (the gap between two is longer, easing back to normal).
func _apply_night() -> void:
	var night := main.night
	night.chill = 0.0
	night.arrival_ease = 1.0
	if surge.is_empty() or not surge["warned"]:
		return
	var start: float = surge["start"]
	var now := night.elapsed
	match phase():
		Phase.WARNING:
			night.chill = smoothstep(start - NightConfig.SURGE_WARN_SECONDS, start, now)
		Phase.SURGE:
			night.chill = 1.0
		Phase.AFTERMATH:
			var gone := clampf(
				(now - start - NightConfig.SURGE_SECONDS) / NightConfig.SURGE_AFTERMATH_SECONDS, 0.0, 1.0
			)
			night.chill = 1.0 - smoothstep(0.0, 1.0, gone)
			night.arrival_ease = lerpf(NightConfig.SURGE_AFTERMATH_GAP_MULT, 1.0, smoothstep(0.0, 1.0, gone))


# ---- What shows
# ---------------------------------------------------------------------------------------------------


# The minimap's mark, the fog band and the pointer.
func _show(delta: float) -> void:
	if not main.running or not is_up():
		main.minimap.surge_from = Vector2.INF
		_set_fog_shown(false)
		if not main.running:
			pointer.hide_pointer()
	else:
		front = front_distance()
		var origin: Vector2 = surge["origin"]
		main.minimap.surge_from = origin
		main.minimap.surge_dir = surge["dir"]
		main.minimap.surge_front = front
		_place_fog()
	_pointer_since += delta
	if _pointer_since >= NightConfig.TIDE_POINTER_REFRESH:
		_pointer_since = 0.0
		refresh_pointer()


# How far down the street the fog's leading edge is. In the warning it sits at the far end; in the surge it rolls to
# just past the gate it meets over the first SURGE_ARRIVE share, and holds there.
func front_distance() -> float:
	var depth := NightConfig.TIDE_FOG_DEPTH
	if surge.is_empty() or not surge["warned"]:
		return depth
	var along: float = surge["gate_along"]
	var target := maxf(along + 1.5, depth)
	if phase() != Phase.SURGE:
		return depth
	return lerpf(depth, target, smoothstep(0.0, NightConfig.SURGE_ARRIVE, progress()))


# How solid the fog is now, 0 to 1: it thickens through the warning, holds through the surge and thins at the end.
func fog_density() -> float:
	match phase():
		Phase.WARNING:
			var start: float = surge["start"]
			var rise := smoothstep(start - NightConfig.SURGE_WARN_SECONDS, start, main.night.elapsed)
			return lerpf(NightConfig.SURGE_FOG_START_DENSITY, 0.5, rise)
		Phase.SURGE:
			var f := progress()
			return (
				lerpf(0.5, 1.0, smoothstep(0.0, NightConfig.SURGE_ARRIVE, f))
				* (1.0 - smoothstep(1.0 - NightConfig.SURGE_FADE, 1.0, f))
			)
	return 0.0


# The fog band: centred on the street, its leading edge `front` metres from the far end, facing down the street.
func _place_fog() -> void:
	var origin: Vector2 = surge["origin"]
	var dir: Vector2 = surge["dir"]
	var centre := origin + dir * (front - NightConfig.TIDE_FOG_DEPTH * 0.5)
	var density := fog_density()
	fog.position = Vector3(centre.x, NightConfig.TIDE_FOG_Y, centre.y)
	fog.rotation.y = PI / 2.0 - dir.angle()  # The plane's depth runs down the street.
	_sway_figures(main.night.elapsed)
	var mat := fog.material_override as StandardMaterial3D
	var c := NightConfig.TIDE_FOG_COLOUR
	mat.albedo_color = Color(c.r, c.g, c.b, NightConfig.TIDE_FOG_ALPHA * density)
	styled_fog.position = fog.position
	styled_fog.rotation = fog.rotation
	styled_fog.scale.y = clampf(density / NightConfig.SURGE_FOG_FULL_DENSITY, 0.02, 1.0)
	_set_fog_shown(density > 0.01)
	if styled_fog.visible:
		StylePush.set_length(styled_fog, NightConfig.SURGE_FOG_WIDTH)


# Shows the fog in the look that is on: the placeholder plane or the styled banks (the figures go with it).
func _set_fog_shown(on: bool) -> void:
	var styled := Looks.is_styled()
	fog.visible = on and not styled
	styled_fog.visible = on and styled


# The figures walk on the spot (a small step-bob and sideways drift) so the surge looks alive.
func _sway_figures(clock: float) -> void:
	for i: int in range(figures.size()):
		var fig := figures[i]
		var phase_i := float(i) * 1.7 + clock * 3.0
		fig.position.y = NightConfig.TIDE_FIGURE_HEIGHT * 0.5 - NightConfig.TIDE_FOG_Y + absf(sin(phase_i)) * 0.18
		fig.position.x = _figure_x(i) + sin(phase_i * 0.5) * 0.4
	# The styled figures stand on the ground (their origin is the base) and walk the same way.
	for i: int in range(styled_figures.size()):
		var fig := styled_figures[i]
		var phase_i := float(i) * 1.7 + clock * 3.0
		fig.position.y = -NightConfig.TIDE_FOG_Y + absf(sin(phase_i)) * 0.18
		fig.position.x = _figure_x(i) + sin(phase_i * 0.5) * 0.4


# The figures spread over the band's width (never past TIDE_FIGURE_SPREAD).
func _figure_x(i: int) -> float:
	var spread := minf(NightConfig.TIDE_FIGURE_SPREAD, NightConfig.SURGE_FOG_WIDTH * 0.5 - 2.0)
	return lerpf(-1.0, 1.0, (float(i) + 0.5) / float(NightConfig.TIDE_FIGURES)) * spread


func _build_figures() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.36
	mesh.height = NightConfig.TIDE_FIGURE_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = NightConfig.TIDE_FIGURE_COLOUR
	for i: int in range(NightConfig.TIDE_FIGURES):
		var fig := MeshInstance3D.new()
		fig.mesh = mesh
		fig.material_override = mat
		# A fixed zig-zag in the band's depth, so they do not stand in a row.
		var row := -0.3 if i % 2 == 0 else 0.3
		fig.position = Vector3(_figure_x(i), 0.0, row * NightConfig.TIDE_FOG_DEPTH)
		fog.add_child(fig)
		figures.append(fig)


func _build_fog() -> void:
	fog = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(NightConfig.SURGE_FOG_WIDTH, NightConfig.TIDE_FOG_DEPTH)
	fog.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = NightConfig.TIDE_FOG_COLOUR
	fog.material_override = mat
	# Surge warning: a tall volume over the plane, so the fog shows over the blocks (a block is 3 m, the fog 6 m).
	fog_volume = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(NightConfig.SURGE_FOG_WIDTH, NightConfig.SURGE_FOG_HEIGHT, NightConfig.TIDE_FOG_DEPTH)
	fog_volume.mesh = box
	fog_volume.position.y = NightConfig.SURGE_FOG_HEIGHT * 0.5 - NightConfig.TIDE_FOG_Y
	fog_volume.material_override = mat
	fog_volume.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fog.add_child(fog_volume)
	fog.visible = false
	_build_figures()
	main.add_child(fog)
	# The placeholder plane is not noted as a fallback: the styled storm cloud below covers it.
	styled_fog = StylePush.build_fog(
		main, NightConfig.SURGE_FOG_WIDTH, NightConfig.TIDE_FOG_DEPTH, NightConfig.SURGE_FOG_HEIGHT
	)
	styled_fog.visible = false
	for i: int in range(NightConfig.TIDE_FIGURES):
		var fig := StylePush.build_figure(styled_fog)
		var row := -0.3 if i % 2 == 0 else 0.3
		fig.position = Vector3(_figure_x(i), 0.0, row * NightConfig.TIDE_FOG_DEPTH)
		styled_figures.append(fig)
