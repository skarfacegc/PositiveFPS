class_name StyleReach
extends RefCounted

# Graphics checkpoint 5 (was the round 20 ring-and-line guide): the shape preview in the locked style.
# ReachGuide hides its flat placeholder drawing and calls this in the styled look. The same facts as the
# placeholder guide, as dithered pieces flat on the ground with an ink edge and no alpha:
#   - while E is held (Checkpoint 5 follow-up: hold to aim), the zone a release of E at the cursor would make
#     (Border.plan_stretch): a thin marching teal outline and a small tip disc with a ring. No fill. When something
#     holds the tip back the outline turns a single thin coral (no stripes) and a small cross marks the tip;
#   - during a stretch (whether or not E is held), a bright path from the centre to the tip, a disc at the tip,
#     coral dashes on to the beacon when the reach falls short, and a parchment tag that says "Stretching";
#   - when a stretch finishes, a wave of light runs along the new arm and a ring opens at the tip (pulse()).
# Pure visuals: it reads Border.plan_stretch() / stretch_info() and the player's aim, and changes nothing.

const OUTLINE_SHADER := "res://shaders/style_outline.gdshader"
const TEAL := Color("#9cf0dc")
const TEAL_LIGHT := Color("#e8fff8")
const CORAL := Color("#e8453b")
const CORAL_LIGHT := Color("#ffb09a")
const TIP := Color("#fff3c4")
const TIP_RIM := Color("#fffbe8")
const GOLD := Color("#ffe27a")
const Y := 0.14
const OUTLINE_WIDTH := 0.3
const LIMITED_WIDTH := 0.3
const PATH_WIDTH := 0.7
const CROSS_SIZE := 1.0
const CROSS_STROKE := 0.2  # Half the stroke width of the cross.
const WORDS := "Stretching"

var root: Node3D
# What was drawn last frame (the tests read these).
var showing_preview: bool = false
var showing_limited: bool = false
var showing_travel: bool = false
var _line: MeshInstance3D  # the outline (or the stretch path)
var _dashes: MeshInstance3D
var _wave: MeshInstance3D
var _line_mesh := ImmediateMesh.new()
var _dash_mesh := ImmediateMesh.new()
var _wave_mesh := ImmediateMesh.new()
var _mat_ok: ShaderMaterial
var _mat_limited: ShaderMaterial
var _mat_path: ShaderMaterial
var _mat_dash: ShaderMaterial
var _mat_wave: ShaderMaterial
var _tip_disc: MeshInstance3D
var _tip_ring: MeshInstance3D
var _pulse_ring: MeshInstance3D
var _cross: MeshInstance3D
var _cross_mesh := ImmediateMesh.new()
var _tag: StyleReachTag
var _main: TopDownMain
var _outline_shader: Shader
var _all: Array[MeshInstance3D] = []


# Builds the pieces under `parent` (all hidden until sync shows them).
func build(parent: Node3D) -> void:
	_outline_shader = load(OUTLINE_SHADER)
	root = Node3D.new()
	root.top_level = true
	parent.add_child(root)
	_mat_ok = _outline_mat(TEAL, TEAL_LIGHT, 1.6, 0.8, false)
	# One colour, no marching: the limited outline is a plain thin coral line, with no stripes.
	_mat_limited = _outline_mat(CORAL, CORAL, 1.2, 0.0, false)
	_mat_path = _outline_mat(TEAL_LIGHT, TIP, 1.2, 2.0, false)
	_mat_dash = _outline_mat(CORAL, CORAL_LIGHT, 2.4, 0.0, true)
	_mat_wave = _outline_mat(TIP, TIP_RIM, 1.0, 2.5, false)
	_line = _mesh_node(_line_mesh, _mat_ok)
	_dashes = _mesh_node(_dash_mesh, _mat_dash)
	_wave = _mesh_node(_wave_mesh, _mat_wave)
	_cross = _mesh_node(_cross_mesh, _mat_limited)
	_tip_disc = _disc(0.0, TIP, TIP_RIM, 0.95)
	_tip_ring = _disc(0.8, TEAL, TEAL_LIGHT, 0.7)
	_pulse_ring = _disc(0.82, TIP, TIP_RIM, 0.8)
	_all = [_line, _dashes, _cross, _tip_disc, _tip_ring]
	_main = parent.get_parent() as TopDownMain
	if _main != null and _main.hud != null:
		_tag = StyleReachTag.new()
		_main.hud.add_child(_tag)
	hide()


# Hides the preview and travel pieces (not the finished-stretch pulse, see end_pulse).
func hide() -> void:
	for node: MeshInstance3D in _all:
		node.visible = false
	for mesh: ImmediateMesh in [_line_mesh, _dash_mesh, _cross_mesh]:
		mesh.clear_surfaces()
	if _tag != null:
		_tag.hide_tag()
	showing_preview = false
	showing_limited = false
	showing_travel = false


# Hides everything, the pulse too (the look went back to the placeholder).
func hide_all() -> void:
	hide()
	end_pulse()


# Redraws the guide for this frame (ReachGuide then calls pulse() while a finished stretch's wave lasts). The zone
# preview shows only while `aiming` (E held); a stretch's travel shows either way.
func sync(border: Border, player: TopDownPlayer, aiming: bool = false) -> void:
	hide()
	if not border.active:
		return
	var info := border.stretch_info()
	var c := Vector2(border.centre.x, border.centre.z)
	if info["on"]:
		_travel(c, border, info)
	elif aiming and player.has_aim():
		_preview(c, border.plan_stretch(player.aim_point()))


# The zone a release of E at the cursor would make: a thin outline only (no fill).
func _preview(c: Vector2, plan: Dictionary) -> void:
	var outline: PackedVector2Array = plan["outline"]
	var limited := (plan["reason"] as String) != ""
	var reach: float = plan["reach"]
	var ang: float = plan["dir"]
	showing_preview = true
	showing_limited = limited
	_line.material_override = _mat_limited if limited else _mat_ok
	_line.visible = true
	_ribbon(_line_mesh, outline, true, LIMITED_WIDTH if limited else OUTLINE_WIDTH, Y)
	var end := c + Vector2(cos(ang), sin(ang)) * reach
	var pulse := 0.5 + 0.5 * sin(float(Engine.get_process_frames()) / 60.0 * TAU * 1.2)
	if limited:
		_set_disc(_tip_disc, end, 0.0, CORAL, CORAL_LIGHT, 0.0)
		_cross.visible = true
		_cross_x(end, CROSS_SIZE)
	else:
		_set_disc(_tip_disc, end, 1.0, TIP, TIP_RIM, 0.95)
		_set_disc(_tip_ring, end, 1.9 + 0.25 * pulse, TEAL, TEAL_LIGHT, 0.7)


# During a stretch: the path to the tip, the disc and the dashes on to the beacon.
func _travel(c: Vector2, border: Border, info: Dictionary) -> void:
	var tip_pos: Vector3 = info["tip"]
	var tip := Vector2(tip_pos.x, tip_pos.z)
	showing_travel = true
	_line.material_override = _mat_path
	_line.visible = true
	_ribbon(_line_mesh, PackedVector2Array([c, tip]), false, PATH_WIDTH, Y)
	_set_disc(_tip_disc, tip, 1.5, TIP, TIP_RIM, 0.95)
	var beacon := border.beacon_pos()
	if beacon != Vector3.INF and Vector2(beacon.x, beacon.z).distance_to(tip) > 1.0:
		_dashes.visible = true
		_ribbon(_dash_mesh, PackedVector2Array([tip, Vector2(beacon.x, beacon.z)]), false, 0.5, Y)
	if _tag != null and _main != null:
		_tag.show_at(WORDS, _main.world_to_screen(Vector3(tip.x, 0.0, tip.y)))


# A finished stretch: a wave of light along the new arm (the polygon pieces within 1.2 rad of the arm) and a ring at the
# tip. `p` runs 0 to 1 over the pulse. Called by ReachGuide every frame while the pulse lasts.
func pulse(border: Border, p: float, ang: float, tip_at: Vector2) -> void:
	var c := Vector2(border.centre.x, border.centre.z)
	var poly := border.polygon
	var n := poly.size()
	var body := maxf(border.body_radius, 0.1)
	var tip_r := maxf(tip_at.distance_to(c), body + 0.1)
	_wave_mesh.clear_surfaces()
	_wave.visible = true
	var dens := clampf(1.0 - p * 0.8, 0.2, 1.0)
	_mat_wave.set_shader_parameter("density", dens)
	var run: Array[Vector2] = []
	for i: int in range(n):
		var q0 := poly[i]
		var q1 := poly[(i + 1) % n]
		var mid := (q0 + q1) * 0.5 - c
		if absf(wrapf(mid.angle() - ang, -PI, PI)) > 1.2:
			continue
		var u := clampf((mid.length() - body) / (tip_r - body), 0.0, 1.2)
		if u <= 0.05:
			continue
		var wave := clampf(1.0 - absf(u - p * 1.3) / 0.45, 0.0, 1.0)
		if wave > 0.15:
			run.append(q0)
			run.append(q1)
	if run.size() >= 2:
		_ribbon_pairs(_wave_mesh, run, 0.9, Y + 0.02)
	var r := Config.BEACON_PULSE_RING_START + Config.BEACON_PULSE_RING_GROW * p
	_pulse_ring.visible = true
	_pulse_ring.position = Vector3(tip_at.x, Y + 0.03, tip_at.y)
	_pulse_ring.scale = Vector3(r, 1.0, r)
	StyleFight.set_ring(_pulse_ring, TIP, 0.85, 0.1, 1.0 - p)


# Ends the pulse.
func end_pulse() -> void:
	_wave.visible = false
	_pulse_ring.visible = false
	_wave_mesh.clear_surfaces()


# ---- Drawing --------------------------------------------------------------------------------------------------------


# A ribbon along `pts` (closed back to the first point when `closed`), `width` metres wide, at height `y`.
func _ribbon(mesh: ImmediateMesh, pts: PackedVector2Array, closed: bool, width: float, y: float) -> void:
	mesh.clear_surfaces()
	var n := pts.size()
	var count := n if closed else n - 1
	if count < 1:
		return
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i: int in range(count):
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		var seg_len := d.length()
		if seg_len < 0.001:
			continue
		var dir := d / seg_len
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var ext := dir * width * 0.35
		var a2 := a - ext
		var b2 := b + ext
		var d0 := dist - width * 0.35
		var d1 := dist + seg_len + width * 0.35
		_quad(mesh, a2 - side, a2 + side, b2 + side, b2 - side, d0, d1, y)
		dist += seg_len
	mesh.surface_end()


# Ribbons for a list of separate segments given as consecutive pairs [a0, b0, a1, b1, ...].
func _ribbon_pairs(mesh: ImmediateMesh, pts: Array[Vector2], width: float, y: float) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var dist := 0.0
	for i: int in range(0, pts.size() - 1, 2):
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		var seg_len := d.length()
		if seg_len < 0.001:
			continue
		var dir := d / seg_len
		var side := Vector2(-dir.y, dir.x) * width * 0.5
		var ext := dir * width * 0.35
		_quad(mesh, a - ext - side, a - ext + side, b + ext + side, b + ext - side, dist, dist + seg_len, y)
		dist += seg_len
	mesh.surface_end()


func _quad(
	mesh: ImmediateMesh, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, d0: float, d1: float, y: float
) -> void:
	var corners: Array = [[p0, -1.0, d0], [p1, 1.0, d0], [p2, 1.0, d1], [p0, -1.0, d0], [p2, 1.0, d1], [p3, -1.0, d1]]
	for v: Array in corners:
		var at: Vector2 = v[0]
		var side_x: float = v[1]
		var dist: float = v[2]
		mesh.surface_set_uv(Vector2(side_x, dist))
		mesh.surface_add_vertex(Vector3(at.x, y, at.y))


# A small X (half-length `size`) at the tip of a limited preview.
func _cross_x(at: Vector2, size: float) -> void:
	_cross_mesh.clear_surfaces()
	_cross_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for sgn: float in [-1.0, 1.0]:
		var a := at + Vector2(-size, -size * sgn)
		var b := at + Vector2(size, size * sgn)
		var dir := (b - a).normalized()
		var side := Vector2(-dir.y, dir.x) * CROSS_STROKE
		_quad(_cross_mesh, a - side, a + side, b + side, b - side, 0.0, a.distance_to(b), Y + 0.04)
	_cross_mesh.surface_end()


func _set_disc(node: MeshInstance3D, at: Vector2, r: float, fill: Color, rim: Color, density: float) -> void:
	node.visible = r > 0.01
	node.position = Vector3(at.x, Y + 0.03, at.y)
	node.scale = Vector3(maxf(r, 0.01), 1.0, maxf(r, 0.01))
	StyleFight.set_ring(node, fill, density, 0.14)
	(node.material_override as ShaderMaterial).set_shader_parameter("rim_color", rim)


func _outline_mat(col: Color, light: Color, dash: float, speed: float, gaps: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _outline_shader
	m.set_shader_parameter("line_color", col)
	m.set_shader_parameter("light_color", light)
	m.set_shader_parameter("ink_color", StyleCues.INK)
	m.set_shader_parameter("dash", dash)
	m.set_shader_parameter("speed", speed)
	m.set_shader_parameter("gaps", 1.0 if gaps else 0.0)
	return m


func _mesh_node(mesh: ImmediateMesh, m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.extra_cull_margin = 200.0
	root.add_child(n)
	return n


func _disc(inner: float, fill: Color, rim: Color, density: float) -> MeshInstance3D:
	return StyleFight.ring_node(root, inner, fill, rim, density)
