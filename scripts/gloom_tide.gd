class_name GloomTide
extends Node

# Round 25: gloom tides. Two a night (Config TIDE_*): one in the rising phase, one at midnight. Each comes from an
# angle drawn from the level's seed (so a replay matches) and starts at a time inside its window. About
# TIDE_WARN_SECONDS before it hits there is a warning: a fog edge on the minimap, one edge pointer toward it
# (TidePointer, inside HudSafeArea as the wobble pointers are) and a notice. Round 26: the tide is a visible wave, a
# grey fog band with dark figures in it, rolling in from that side. Once its front reaches the line it SHOVES the side
# it comes from (BorderPush.set_wave: TIDE_PUSH of force over TIDE_HALF_WIDTH) until it has passed (TIDE_SECONDS); it
# no longer drains anyone by itself. Times are the night's own clock (NightCycle.elapsed): fixed-step.

signal tide_warned(side: String, angle: float)
signal tide_started(side: String, angle: float, members: int)
signal tide_ended(side: String, angle: float, members: int)

var main: TopDownMain
# One entry per tide: "start" (night seconds), "angle" (radians; x and z on the ground), "side" (a compass name),
# "warned", "started" and "ended" (bools) and "members" (border members facing it when it started).
var tides: Array[Dictionary] = []
var pointer: TidePointer  # The edge pointer (placeholder look), shown during a warning.
var fog: MeshInstance3D  # The fog band (placeholder look), shown while a tide passes.
var figures: Array[MeshInstance3D] = []  # Round 26: dark figures walking in the fog (children of `fog`).
var wave_force: float = 0.0  # The force the wave puts on the line now (0 until its front reaches it).
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
	return t


func _process(delta: float) -> void:
	update(delta)


# Advances the tides by the night's clock and applies them: the warnings and the start and end of each tide (with their
# signals and notice), the drain multiplier of the members, and the minimap, pointer and fog. Tests call it directly.
func update(delta: float) -> void:
	if main == null or not Config.tides_on():
		return
	if main.running:
		_advance()
	_apply_push()
	_show(delta)


# The index of the tide on show now (warned and not yet ended, the earliest first), or -1.
func showing_index() -> int:
	for i: int in range(tides.size()):
		var t: Dictionary = tides[i]
		if t["warned"] and not t["ended"]:
			return i
	return -1


# The index of the tide being warned about (warned, not yet started), or -1.
func warning_index() -> int:
	for i: int in range(tides.size()):
		var t: Dictionary = tides[i]
		if t["warned"] and not t["started"]:
			return i
	return -1


# The index of the tide passing now (started, not yet ended), or -1.
func passing_index() -> int:
	for i: int in range(tides.size()):
		var t: Dictionary = tides[i]
		if t["started"] and not t["ended"]:
			return i
	return -1


# How many rescued border members face `angle` now (see faces).
func count_facing(angle: float) -> int:
	var n := 0
	for m: Person in main.border.members:
		if m.is_rescued and faces(m.position, main.border.centre, angle):
			n += 1
	return n


# Works the edge pointer out now: its tip sits where the ray from the screen centre toward the side leaves the safe
# rectangle (HudSafeArea.current, shrunk by WOBBLE_ALERT_REACH), so the whole pointer stays on screen and clear of the
# HUD. Hidden when no warning is up or the window is too small for the HUD (headless).
func refresh_pointer() -> void:
	var i := warning_index()
	if i < 0 or not main.running:
		pointer.hide_pointer()
		return
	var screen := main.get_viewport().get_visible_rect().size
	var safe: Rect2 = HudSafeArea.current(main, screen)
	var tips := safe.grow(-Config.WOBBLE_ALERT_REACH)
	if tips.size.x <= 0.0 or tips.size.y <= 0.0:
		pointer.hide_pointer()
		return
	var angle: float = tides[i]["angle"]
	var dir := Vector2.from_angle(angle)
	var far := main.border.centre + Vector3(dir.x, 0.0, dir.y) * Config.TIDE_POINTER_FAR
	var placed := WobbleAlert.tip_for(main.world_to_screen(far), screen, tips)
	var at: Vector2 = placed["tip"]
	var outward: Vector2 = placed["dir"]
	pointer.show_at(at, outward)


# True when `pos` (a point on the ground) lies within TIDE_HALF_WIDTH of `angle` as seen from `centre`.
static func faces(pos: Vector3, centre: Vector3, angle: float) -> bool:
	var d := Vector2(pos.x - centre.x, pos.z - centre.z)
	if d.length() < 0.001:
		return false
	return absf(angle_difference(d.angle(), angle)) <= Config.TIDE_HALF_WIDTH


# The compass name of a side (north is -z, as the camera sees it: north is up the screen).
static func side_name(angle: float) -> String:
	var d := Vector2.from_angle(angle)
	if absf(d.x) >= absf(d.y):
		return "east" if d.x > 0.0 else "west"
	return "south" if d.y > 0.0 else "north"


# Draws the two tides: a random angle and a start time inside each window, from the seed (RNG_SEED + TIDE_SEED_OFFSET).
func _build_schedule() -> void:
	_rng.seed = Config.RNG_SEED + Config.TIDE_SEED_OFFSET
	_add_tide(Config.TIDE_RISING_FROM, Config.TIDE_RISING_TO)
	_add_tide(Config.TIDE_MIDNIGHT_FROM, Config.TIDE_MIDNIGHT_TO)


func _add_tide(from: float, to: float) -> void:
	var progress := lerpf(from, to, _rng.randf())
	var angle := _rng.randf() * TAU
	(
		tides
		. append(
			{
				"start": progress * Config.NIGHT_LENGTH,
				"angle": angle,
				"side": side_name(angle),
				"warned": false,
				"started": false,
				"ended": false,
				"members": 0,
			}
		)
	)


# The tides' clock: each step fires at most once, in order (warn, start, end), even when time jumps past several.
func _advance() -> void:
	var now := main.night.elapsed
	for t: Dictionary in tides:
		var start: float = t["start"]
		var side: String = t["side"]
		var angle: float = t["angle"]
		if not t["warned"] and now >= start - Config.TIDE_WARN_SECONDS:
			t["warned"] = true
			main.intro.notice(Intro.Prompt.TIDE, Config.TIDE_TEXT % side)
			tide_warned.emit(side, angle)
			refresh_pointer()
		if t["warned"] and not t["started"] and now >= start:
			t["started"] = true
			pointer.hide_pointer()
			var facing: int = count_facing(angle)
			t["members"] = facing
			tide_started.emit(side, angle, facing)
		if t["started"] and not t["ended"] and now >= start + Config.TIDE_SECONDS:
			t["ended"] = true
			var left: int = count_facing(angle)
			tide_ended.emit(side, angle, left)


# Round 26: where the wave's front is, as a distance from the border's centre (the front is its near edge). It arrives
# over the first TIDE_ARRIVE share of the passing and then holds just past the line, shoving it.
func front_distance(idx: int) -> float:
	var start: float = tides[idx]["start"]
	var f := clampf((main.night.elapsed - start) / Config.TIDE_SECONDS, 0.0, 1.0)
	var arrive := smoothstep(0.0, Config.TIDE_ARRIVE, f)
	return lerpf(Config.TIDE_FOG_FAR - Config.TIDE_FOG_DEPTH * 0.5, _shove_front(), arrive)


# The front's resting place: TIDE_SHOVE_DEPTH metres inside the border's mean radius.
func _shove_front() -> float:
	var r := Config.TIDE_FOG_NEAR
	if main.border != null and main.border.active:
		r = main.border.body_radius
	return r - Config.TIDE_SHOVE_DEPTH


# The wave's shove on the line now: 0 until the front is within TIDE_PUSH_REACH of the line, TIDE_PUSH once it is
# TIDE_SHOVE_DEPTH past it (a smooth ramp between), and eased off at the end of the passing.
func shove_strength(idx: int) -> float:
	var r := main.border.body_radius
	var span := Config.TIDE_PUSH_REACH + Config.TIDE_SHOVE_DEPTH
	var ramp := clampf((r + Config.TIDE_PUSH_REACH - front_distance(idx)) / span, 0.0, 1.0)
	var start: float = tides[idx]["start"]
	var f := clampf((main.night.elapsed - start) / Config.TIDE_SECONDS, 0.0, 1.0)
	return ramp * clampf((1.0 - f) / Config.TIDE_FOG_FADE, 0.0, 1.0)


# Sets (or clears) the wave's force on the border: Config.TIDE_PUSH over the side the passing tide comes from.
func _apply_push() -> void:
	wave_force = 0.0
	var i := passing_index()
	if i < 0 or not main.border.active or not main.running:
		main.border.push.clear_wave()
		return
	wave_force = Config.TIDE_PUSH * shove_strength(i)
	var angle: float = tides[i]["angle"]
	main.border.push.set_wave(angle, Config.TIDE_HALF_WIDTH, wave_force)


# The minimap's fog edge, the fog band and the pointer, from the tide on show.
func _show(delta: float) -> void:
	if not main.running:
		main.minimap.tide_fog = Vector2.INF
		fog.visible = false
		pointer.hide_pointer()
		return
	var idx := showing_index()
	if idx < 0:
		main.minimap.tide_fog = Vector2.INF
		fog.visible = false
	else:
		var angle: float = tides[idx]["angle"]
		var started: bool = tides[idx]["started"]
		main.minimap.tide_fog = Vector2.from_angle(angle)
		fog.visible = started
		if started:
			_place_fog(idx)
	_pointer_since += delta
	if _pointer_since >= Config.TIDE_POINTER_REFRESH:
		_pointer_since = 0.0
		refresh_pointer()


# The fog band for a passing tide: it drifts in from the far edge to the near distance over TIDE_SECONDS, and fades in
# and out at the ends (TIDE_FOG_FADE of the passing each).
func _place_fog(idx: int) -> void:
	var start: float = tides[idx]["start"]
	var angle: float = tides[idx]["angle"]
	var f := clampf((main.night.elapsed - start) / Config.TIDE_SECONDS, 0.0, 1.0)
	var dist := front_distance(idx) + Config.TIDE_FOG_DEPTH * 0.5  # The band's middle (its front is the near edge).
	var dir := Vector2.from_angle(angle)
	var around := Vector3.ZERO
	if main.border != null and main.border.active:
		around = main.border.centre
	fog.position = Vector3(around.x + dir.x * dist, Config.TIDE_FOG_Y, around.z + dir.y * dist)
	_sway_figures(f)
	# The plane's long side runs along the tangent of the side (its local X axis turned to (-sin, 0, cos)).
	fog.rotation.y = -angle - PI / 2.0
	var fade := clampf(minf(f, 1.0 - f) / Config.TIDE_FOG_FADE, 0.0, 1.0)
	var mat := fog.material_override as StandardMaterial3D
	var c := Config.TIDE_FOG_COLOUR
	mat.albedo_color = Color(c.r, c.g, c.b, Config.TIDE_FOG_ALPHA * fade)


# Round 26: the figures walk on the spot (a small step-bob and sideways drift) so the wave looks alive.
func _sway_figures(f: float) -> void:
	for i: int in range(figures.size()):
		var fig := figures[i]
		var phase := float(i) * 1.7 + f * Config.TIDE_SECONDS * 3.0
		fig.position.y = Config.TIDE_FIGURE_HEIGHT * 0.5 - Config.TIDE_FOG_Y + absf(sin(phase)) * 0.18
		fig.position.x = _figure_x(i) + sin(phase * 0.5) * 0.4


func _figure_x(i: int) -> float:
	return lerpf(-1.0, 1.0, (float(i) + 0.5) / float(Config.TIDE_FIGURES)) * Config.TIDE_FIGURE_SPREAD


func _build_figures() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.36
	mesh.height = Config.TIDE_FIGURE_HEIGHT
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Config.TIDE_FIGURE_COLOUR
	for i: int in range(Config.TIDE_FIGURES):
		var fig := MeshInstance3D.new()
		fig.mesh = mesh
		fig.material_override = mat
		# A fixed zig-zag in the band's depth, so they do not stand in a row.
		var row := -0.3 if i % 2 == 0 else 0.3
		fig.position = Vector3(_figure_x(i), 0.0, row * Config.TIDE_FOG_DEPTH)
		fog.add_child(fig)
		figures.append(fig)


func _build_fog() -> void:
	fog = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(Config.TIDE_FOG_WIDTH, Config.TIDE_FOG_DEPTH)
	fog.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Config.TIDE_FOG_COLOUR
	fog.material_override = mat
	fog.visible = false
	_build_figures()
	main.add_child(fog)
	Looks.note_placeholder(fog, "tide_fog")
