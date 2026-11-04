class_name FirstLight
extends Node3D

# Round 24: first light. Over the last Config.FIRST_LIGHT_SECONDS of the night a front of dawn starts at the map edge
# and moves inward (a square, like the plaza), reaching the centre at dawn. A person is "passed" once the front is at or
# inside their square distance from the centre. For everyone passed:
#  - unrescued people lose Config.FIRST_LIGHT_LIFT_RATE gloom a second (dimmed to gloomy to wistful) and are calm, so
#    nobody sinks behind the front;
#  - rescued people no longer drain joy (Person.dawn_lit, honoured by Person.drain_joy).
# People ahead of the front get none of this, so it is a rally, not a free win: the rating still depends on what the
# player held. The look is a soft warm tint on the lit ground and a band just inside the front (placeholder), one small
# HUD line when it begins, and the minimap draws the front too. The recorder gets first_light_start and first_light_end.
# It runs just before TopDownMain each frame (process_priority -1) so the end event is written before the round closes.

var main: TopDownMain
var started: bool = false
var finished: bool = false
# Distinct people lifted at least once, and the number of stage lifts (one person can lift twice).
var people_lifted: int = 0
var stages_lifted: int = 0
var label: Label
var _lifted: Dictionary = {}
var _label_left: float = 0.0
var _tint: Array[MeshInstance3D] = []
var _band: Array[MeshInstance3D] = []
var _styled: StyleFirstLight  # Graphics checkpoint 5: built the first time the styled look is on.


# Builds the node under `level` and returns it. (The only wiring TopDownMain needs.)
static func attach(level: TopDownMain) -> FirstLight:
	var f := FirstLight.new()
	f.main = level
	f.process_priority = -1
	level.add_child(f)
	f._build()
	return f


func _build() -> void:
	_tint = _make_strips(Config.FIRST_LIGHT_TINT)
	_band = _make_strips(Config.FIRST_LIGHT_BAND_COLOUR)
	label = Label.new()
	label.text = Config.FIRST_LIGHT_TEXT
	label.add_theme_font_size_override("font_size", Config.FIRST_LIGHT_FONT_SIZE)
	label.add_theme_color_override("font_color", Config.FIRST_LIGHT_TEXT_COLOUR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	label.offset_left = -150
	label.offset_right = 150
	label.offset_top = 40
	label.offset_bottom = 64
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.visible = false
	main.hud.add_child(label)


func _process(delta: float) -> void:
	if main.running:
		step(delta)


# Half size (metres) of the square the front has reached: the plaza edge at the start, 0 at dawn.
func edge() -> float:
	return Config.TD_PLAZA_SIZE * 0.5 * (1.0 - main.night.first_light_progress())


# True when the front has passed `pos` (its square distance from the centre is at least the front's).
func has_passed(pos: Vector3) -> bool:
	return started and maxf(absf(pos.x), absf(pos.z)) >= edge()


# One frame. Nothing happens before the last FIRST_LIGHT_SECONDS of the night.
func step(delta: float) -> void:
	if not main.night.first_light_active():
		return
	if not started:
		_begin()
	for p: Person in main.people:
		var passed := has_passed(p.global_position)
		p.dawn_lit = passed
		if passed and not p.is_rescued:
			_lift(p, delta)
	_sync_look(delta)
	main.minimap.first_light_edge = edge()
	if not finished and main.night.elapsed + delta >= Config.NIGHT_LENGTH:
		finish()


# Lifts one unrescued person who is behind the front, and keeps them from sinking.
func _lift(p: Person, delta: float) -> void:
	p.calm_left = maxf(p.calm_left, Config.FIRST_LIGHT_CALM)
	var before := Config.gloom_level(p.gloom)
	p.gloom = maxf(0.0, p.gloom - Config.FIRST_LIGHT_LIFT_RATE * delta)
	var drop := before - Config.gloom_level(p.gloom)
	if drop > 0:
		stages_lifted += drop
		if not _lifted.has(p):
			_lifted[p] = true
			people_lifted += 1


func _begin() -> void:
	started = true
	label.visible = true
	_label_left = Config.FIRST_LIGHT_TEXT_HOLD + Config.FIRST_LIGHT_TEXT_FADE
	if Looks.is_styled():
		# Graphics checkpoint 5: the styled banner, not the plain label.
		label.visible = false
		main.hud.show_alert(Config.FIRST_LIGHT_TEXT, Config.FIRST_LIGHT_TEXT_COLOUR, Config.FIRST_LIGHT_TEXT_HOLD)
	var dimmed := 0
	for p: Person in main.people:
		if GloomSim.is_dimmed(p):
			dimmed += 1
	_emit("first_light_start", {"rescued": main.rescued_count, "dimmed": dimmed})


# The front has reached the centre: writes how many people it lifted (once).
func finish() -> void:
	if finished or not started:
		return
	finished = true
	_emit(
		"first_light_end",
		{"people_lifted": people_lifted, "stages_lifted": stages_lifted, "rescued": main.rescued_count}
	)


func _emit(type: String, fields: Dictionary) -> void:
	if main.recorder != null:
		main.recorder.emit_event(type, fields)


# The small line fades out after its hold; the tint and band follow the front.
func _sync_look(delta: float) -> void:
	var styled := Looks.is_styled()
	if _label_left > 0.0:
		_label_left -= delta
		label.modulate.a = clampf(_label_left / Config.FIRST_LIGHT_TEXT_FADE, 0.0, 1.0)
		label.visible = _label_left > 0.0 and not styled
	var half := Config.TD_PLAZA_SIZE * 0.5
	var e := edge()
	if styled:
		# Graphics checkpoint 5: the ground carries the front (warm wash, a line and glints), light motes ride it and the
		# sky warms; the placeholder strips are hidden.
		_set_frame(_tint, 0.0, 0.0)
		_set_frame(_band, 0.0, 0.0)
		_sync_styled(e)
		return
	if _styled != null:
		_styled.hide()
	_set_frame(_tint, e, half)
	_set_frame(_band, maxf(0.0, e - Config.FIRST_LIGHT_BAND_WIDTH), e)


# The styled front: the ground shader's front, the motes near the player, and the sky.
func _sync_styled(e: float) -> void:
	if _styled == null:
		_styled = StyleFirstLight.new()
		_styled.build(self)
	var ground_look := main.ground.look as GroundLookStyled
	if ground_look != null:
		ground_look.set_dawn_front(e)
	_styled.sync(e, main.player.global_position, Time.get_ticks_msec() / 1000.0)
	main.environment().background_color = StyleFirstLight.sky_at(main.night.first_light_progress())


# Four ground strips make a square frame from half size `inner` out to `outer`.
func _set_frame(strips: Array[MeshInstance3D], inner: float, outer: float) -> void:
	var width := outer - inner
	var show := width > 0.01
	for s: MeshInstance3D in strips:
		s.visible = show
	if not show:
		return
	var mid := (inner + outer) * 0.5
	_place(strips[0], Vector3(0.0, 0.0, -mid), Vector2(outer * 2.0, width))
	_place(strips[1], Vector3(0.0, 0.0, mid), Vector2(outer * 2.0, width))
	_place(strips[2], Vector3(-mid, 0.0, 0.0), Vector2(width, inner * 2.0))
	_place(strips[3], Vector3(mid, 0.0, 0.0), Vector2(width, inner * 2.0))


func _place(s: MeshInstance3D, at: Vector3, size_xz: Vector2) -> void:
	s.position = Vector3(at.x, Config.FIRST_LIGHT_Y, at.z)
	s.scale = Vector3(maxf(size_xz.x, 0.001), 1.0, maxf(size_xz.y, 0.001))


func _make_strips(col: Color) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	for i: int in range(4):
		var m := MeshInstance3D.new()
		m.mesh = quad
		m.material_override = mat
		m.visible = false
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		out.append(m)
	return out


# For tests and the recorder: how many strips of the tint are showing.
func tint_visible_count() -> int:
	var n := 0
	for s: MeshInstance3D in _tint:
		if s.visible:
			n += 1
	return n
