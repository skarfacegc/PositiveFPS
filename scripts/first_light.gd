class_name FirstLight
extends Node3D

# Round 24: first light. Over the last Config.FIRST_LIGHT_SECONDS of the night a front of dawn starts where it covers
# the whole play area and moves inward as a circle (checkpoint 6; it was a square), reaching the centre at dawn. A
# person is "passed" once the front's radius is at or inside their distance from the centre. For everyone passed:
#  - unrescued people lose Config.FIRST_LIGHT_LIFT_RATE gloom a second (dimmed to gloomy to wistful) and are calm, so
#    nobody sinks behind the front;
#  - rescued people no longer drain joy (Person.dawn_lit, honoured by Person.drain_joy).
# People ahead of the front get none of this, so it is a rally, not a free win: the rating still depends on what the
# player held. The look is a soft warm tint on the lit ground and a band just inside the front (placeholder), a notice
# when it begins (Intro.notice, the helper the other notices use in both looks), and the minimap draws the front too.
# The recorder gets first_light_start and first_light_end.
# It runs just before TopDownMain each frame (process_priority -1) so the end event is written before the round closes.

var main: TopDownMain
var started: bool = false
var finished: bool = false
# Distinct people lifted at least once, and the number of stage lifts (one person can lift twice).
var people_lifted: int = 0
var stages_lifted: int = 0
var _lifted: Dictionary = {}
var _tint: MeshInstance3D  # Placeholder look: the lit ground outside the front (a flat ring).
var _band: MeshInstance3D  # Placeholder look: a warm band just inside the front.
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
	_tint = _make_ring(Config.FIRST_LIGHT_TINT)
	_band = _make_ring(Config.FIRST_LIGHT_BAND_COLOUR)


func _process(delta: float) -> void:
	if main.running:
		step(delta)


# Radius (metres) of the circle the front has reached: FIRST_LIGHT_START_RADIUS at the start, 0 at dawn.
func edge() -> float:
	return Config.FIRST_LIGHT_START_RADIUS * (1.0 - main.night.first_light_progress())


# True when the front has passed `pos` (its round distance from the centre is at least the front's radius).
func has_passed(pos: Vector3) -> bool:
	return started and Vector2(pos.x, pos.z).length() >= edge()


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
	_sync_look()
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
	# Snag round: the start notice is an Intro notice, drawn by PromptBar (placeholder) or StyleHud (styled).
	main.intro.notice(Intro.Prompt.FIRST_LIGHT)
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


# The tint and band follow the front (the start notice is Intro's, not this).
func _sync_look() -> void:
	var styled := Looks.is_styled()
	var e := edge()
	if styled:
		# Graphics checkpoint 5: the ground carries the front (warm wash, a line and glints), light motes ride it and the
		# sky warms; the placeholder rings are hidden.
		_set_ring(_tint, 0.0, 0.0)
		_set_ring(_band, 0.0, 0.0)
		_sync_styled(e)
		return
	if _styled != null:
		_styled.hide()
	_set_ring(_tint, e, Config.FIRST_LIGHT_START_RADIUS)
	_set_ring(_band, maxf(0.0, e - Config.FIRST_LIGHT_BAND_WIDTH), e)


# The styled front: the ground shader's front, the motes near the player, and the sky.
func _sync_styled(e: float) -> void:
	if _styled == null:
		_styled = StyleFirstLight.new()
		_styled.build(self)
	var ground_look := main.ground.look as GroundLookStyled
	if ground_look != null:
		ground_look.set_dawn_front(e)
	_styled.sync(e, main.player.global_position, float(Engine.get_process_frames()) / 60.0)
	main.environment().background_color = StyleFirstLight.sky_at(main.night.first_light_progress())


# A flat ring of ground from radius `inner` out to `outer` (shown only when it is wide enough to see).
func _set_ring(ring: MeshInstance3D, inner: float, outer: float) -> void:
	var show := outer - inner > 0.01
	ring.visible = show
	if not show:
		return
	var segs := Config.FIRST_LIGHT_RING_SEGMENTS
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	for i: int in range(segs):
		var a := TAU * float(i) / float(segs)
		var dir := Vector3(cos(a), 0.0, sin(a))
		verts.append(dir * inner)
		verts.append(dir * outer)
		var j := (i + 1) % segs
		idx.append_array([2 * i, 2 * i + 1, 2 * j, 2 * i + 1, 2 * j + 1, 2 * j])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ring.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _make_ring(col: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = col
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := MeshInstance3D.new()
	m.mesh = ArrayMesh.new()
	m.material_override = mat
	m.position = Vector3(0.0, Config.FIRST_LIGHT_Y, 0.0)
	m.visible = false
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.extra_cull_margin = 200.0
	add_child(m)
	return m


# For tests and the recorder: how many rings of the tint are showing (0 or 1).
func tint_visible_count() -> int:
	return 1 if _tint.visible else 0
