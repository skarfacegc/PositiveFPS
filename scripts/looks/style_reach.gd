class_name StyleReach
extends RefCounted

# Graphics checkpoint 4: the reach guide in the locked style (ReachGuide hides its flat placeholder drawing and calls
# this in the styled look). The same facts as the placeholder guide, drawn as flat dithered pieces on the ground with a
# solid ink pixel, no alpha, like the other styled ground cues:
#   - a dithered ring round the border's centre at the longest tip distance (the reach);
#   - toward the cursor a pull line to where the tip would stop, ending in a lantern-teal disc, or, when the cursor is
#     past the reach, a coral line ending in a cross (the tip would stop short);
#   - during a stretch, a bright path from the centre to the tip with a disc at the tip, and a row of coral dashes on to
#     the beacon when the reach falls short.
# Pure visuals: it reads Border.stretch_info() and the player's aim, and changes nothing.

const TEAL := Color("#9cf0dc")
const TEAL_RIM := Color("#e8fff8")
const CORAL := Color("#e8453b")
const CORAL_RIM := Color("#ffb09a")
const PATH := Color("#d8fff4")
const TIP := Color("#fff3c4")
const Y := 0.14
const LINE_WIDTH := 0.34
const PATH_WIDTH := 0.6
const DASHES := 30
const DASH_STEP := 2.2

var root: Node3D
var _ring: MeshInstance3D
var _ring_mat: ShaderMaterial
var _ring_r: float = -1.0
var _preview: MeshInstance3D
var _preview_capped: MeshInstance3D
var _preview_end: MeshInstance3D
var _cross: Array[MeshInstance3D] = []
var _path: MeshInstance3D
var _tip: MeshInstance3D
var _dashes: Array[MeshInstance3D] = []
var _unit_box := BoxMesh.new()
var _all: Array[MeshInstance3D] = []


# Builds the pieces under `parent` (all hidden until sync shows them).
func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.top_level = true
	parent.add_child(root)
	_unit_box.size = Vector3(1.0, 0.08, 1.0)
	_ring_mat = StyleCues.ring_material(TEAL, TEAL_RIM, 0.2, 0.96)
	_ring = _flat_disc(_ring_mat)
	var teal_m := StyleKit.mat(TEAL, 0, 0.0, 1.2)
	var coral_m := StyleKit.mat(CORAL, 0, 0.0, 1.0)
	_preview = _bar(teal_m)
	_preview_capped = _bar(coral_m)
	_preview_end = _flat_disc(StyleCues.ring_material(TEAL, TEAL_RIM, 0.9, 0.0))
	for k: int in range(2):
		_cross.append(_bar(coral_m))
	_path = _bar(StyleKit.mat(PATH, 0, 0.0, 1.5))
	_tip = _flat_disc(StyleCues.ring_material(TIP, Color("#fffbe8"), 0.95, 0.0))
	for k: int in range(DASHES):
		_dashes.append(_bar(coral_m))
	_all = [_ring, _preview, _preview_capped, _preview_end, _path, _tip]
	_all.append_array(_cross)
	_all.append_array(_dashes)
	hide()


# Hides every piece.
func hide() -> void:
	for node: MeshInstance3D in _all:
		node.visible = false


# Redraws the guide for this frame.
func sync(border: Border, player: TopDownPlayer) -> void:
	hide()
	if not border.active:
		return
	var info := border.stretch_info()
	var c := Vector2(border.centre.x, border.centre.z)
	var reach: float = info["max"]
	_set_ring(c, reach)
	if player.has_aim():
		var aim := Vector2(player.aim_point().x, player.aim_point().z)
		var p := ReachGuide.preview(c, aim, reach)
		var end: Vector2 = p["end"]
		if p["capped"]:
			_line(_preview_capped, c, end, LINE_WIDTH)
			_set_cross(end, 1.4)
		else:
			_line(_preview, c, end, LINE_WIDTH)
			_set_disc(_preview_end, end, 0.8)
	if info["on"]:
		_travel(c, border, info)


# The reach ring: centred on `c`, thin whatever the radius (its band stays a bit under a metre wide).
func _set_ring(c: Vector2, r: float) -> void:
	_ring.visible = r > 1.0
	_ring.position = Vector3(c.x, Y, c.y)
	_ring.scale = Vector3(r, 1.0, r)
	if not is_equal_approx(r, _ring_r) and r > 1.0:
		_ring_r = r
		_ring_mat.set_shader_parameter("inner", 1.0 - 0.9 / r)
		_ring_mat.set_shader_parameter("rim_width", 0.3 / r)


func _travel(c: Vector2, border: Border, info: Dictionary) -> void:
	var tip_pos: Vector3 = info["tip"]
	var tip := Vector2(tip_pos.x, tip_pos.z)
	_line(_path, c, tip, PATH_WIDTH)
	_set_disc(_tip, tip, 1.5)
	var beacon := border.beacon_pos()
	if beacon != Vector3.INF and Vector2(beacon.x, beacon.z).distance_to(tip) > 1.0:
		_set_dashes(tip, Vector2(beacon.x, beacon.z))


# Coral dashes from the tip on toward the beacon (the reach fell short of it).
func _set_dashes(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	var dir := (to - from) / maxf(length, 0.001)
	for k: int in range(DASHES):
		var d := DASH_STEP * float(k)
		if d >= length:
			break
		_line(_dashes[k], from + dir * d, from + dir * minf(d + 1.2, length), LINE_WIDTH * 1.2)


func _set_cross(at: Vector2, size: float) -> void:
	_line(_cross[0], at + Vector2(-size, -size), at + Vector2(size, size), PATH_WIDTH * 0.6)
	_line(_cross[1], at + Vector2(-size, size), at + Vector2(size, -size), PATH_WIDTH * 0.6)


func _set_disc(node: MeshInstance3D, at: Vector2, r: float) -> void:
	node.visible = true
	node.position = Vector3(at.x, Y + 0.03, at.y)
	node.scale = Vector3(r, 1.0, r)


# Lays a bar from `a` to `b` on the ground.
func _line(node: MeshInstance3D, a: Vector2, b: Vector2, width: float) -> void:
	var d := b - a
	if d.length() < 0.001:
		return
	node.visible = true
	node.position = Vector3((a.x + b.x) * 0.5, Y, (a.y + b.y) * 0.5)
	node.rotation = Vector3(0.0, atan2(-d.y, d.x), 0.0)
	node.scale = Vector3(d.length(), 1.0, width)


func _bar(m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = _unit_box
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)
	return n


func _flat_disc(m: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = StyleCues.ring_mesh()
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(n)
	return n
