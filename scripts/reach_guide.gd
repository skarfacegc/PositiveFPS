class_name ReachGuide
extends Node3D

# Round 20: the placeholder look's guide to the stretching zone, drawn flat on the ground. Before you commit it shows
# how far the zone can reach (a dashed ring round the border's centre at the maximum tip distance) and, toward the
# cursor, a preview line to where the tip would stop (blue; coral with a cross when the cursor is beyond the reach and
# the tip would stop short). During a stretch it shows the tip's travel (a bright line from the centre to the tip, a
# disc at the tip, a dashed line on to the beacon when the reach falls short) and, once the tip holds, an arc round the
# tip that empties as the snap-back nears. Graphics checkpoint 4: the styled look draws the same facts with dithered
# ground pieces (StyleReach), swapped in by sync.

const SEGMENTS := 72
const LINE_WIDTH := 0.28
const PATH_WIDTH := 0.5

var _mesh := ImmediateMesh.new()
var _item := MeshInstance3D.new()
var _styled: StyleReach


func _ready() -> void:
	top_level = true
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_item.mesh = _mesh
	_item.material_override = mat
	add_child(_item)


# Redraws the guide for this frame.
func sync(border: Border, player: TopDownPlayer) -> void:
	_mesh.clear_surfaces()
	if Looks.is_styled():
		if _styled == null:
			_styled = StyleReach.new()
			_styled.build(self)
		_styled.sync(border, player)
		return
	if _styled != null:
		_styled.hide()
	if not border.active:
		return
	var info := border.stretch_info()
	var c := Vector2(border.centre.x, border.centre.z)
	var reach: float = info["max"]
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	_ring(c, reach, Config.BEACON_GUIDE_RING_COLOUR, true)
	if player.has_aim():
		_preview(c, Vector2(player.aim_point().x, player.aim_point().z), reach)
	if info["on"]:
		_travel(c, border, info)
	_mesh.surface_end()


# Where the tip would stop toward `aim` from the centre `c` with the longest reach `reach`: {"end": Vector2, "capped":
# bool} (capped when the cursor is beyond the reach, so the tip stops short). Both looks draw this.
static func preview(c: Vector2, aim: Vector2, reach: float) -> Dictionary:
	var to := aim - c
	return {"end": c + to.normalized() * minf(to.length(), reach), "capped": to.length() > reach}


func _preview(c: Vector2, aim: Vector2, reach: float) -> void:
	var p := preview(c, aim, reach)
	var end: Vector2 = p["end"]
	if p["capped"]:
		_line(c, end, LINE_WIDTH, Config.BEACON_GUIDE_CAPPED_COLOUR)
		_cross(end, 1.4, Config.BEACON_GUIDE_CAPPED_COLOUR)
	else:
		_line(c, end, LINE_WIDTH, Config.BEACON_GUIDE_PREVIEW_COLOUR)
		_disc(end, 0.7, Config.BEACON_GUIDE_PREVIEW_COLOUR)


func _travel(c: Vector2, border: Border, info: Dictionary) -> void:
	var tip_pos: Vector3 = info["tip"]
	var tip := Vector2(tip_pos.x, tip_pos.z)
	_line(c, tip, PATH_WIDTH, Config.BEACON_GUIDE_PATH_COLOUR)
	_disc(tip, 1.3, Config.BEACON_GUIDE_TIP_COLOUR)
	var beacon := border.beacon_pos()
	if beacon != Vector3.INF and Vector2(beacon.x, beacon.z).distance_to(tip) > 1.0:
		_dashes(tip, Vector2(beacon.x, beacon.z), Config.BEACON_GUIDE_CAPPED_COLOUR)
	if info["holding"]:
		var left: float = info["hold_left"]
		var share := clampf(left / Config.BEACON_STRETCH_HOLD, 0.0, 1.0)
		_ring(tip, 2.4, Config.BEACON_GUIDE_TIP_COLOUR, false, share)


# A ring of radius `r` round `at`; dashed when `dashed`; only `share` of the way round when it is below 1.
func _ring(at: Vector2, r: float, col: Color, dashed: bool, share: float = 1.0) -> void:
	var count := maxi(int(float(SEGMENTS) * share), 1)
	for i: int in range(count):
		if dashed and i % 2 == 1:
			continue
		var a0 := TAU * float(i) / float(SEGMENTS) - PI * 0.5
		var a1 := TAU * float(i + 1) / float(SEGMENTS) - PI * 0.5
		_line(at + Vector2(cos(a0), sin(a0)) * r, at + Vector2(cos(a1), sin(a1)) * r, LINE_WIDTH, col)


func _dashes(from: Vector2, to: Vector2, col: Color) -> void:
	var len_total := from.distance_to(to)
	var dir := (to - from) / maxf(len_total, 0.001)
	var d := 0.0
	while d < len_total:
		_line(from + dir * d, from + dir * minf(d + 1.2, len_total), LINE_WIDTH, col)
		d += 2.4


func _cross(at: Vector2, size: float, col: Color) -> void:
	_line(at + Vector2(-size, -size), at + Vector2(size, size), PATH_WIDTH * 0.6, col)
	_line(at + Vector2(-size, size), at + Vector2(size, -size), PATH_WIDTH * 0.6, col)


func _line(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var side := Vector2(-dir.y, dir.x).normalized() * width * 0.5
	var y := Config.BEACON_GUIDE_Y
	var quad := [a - side, a + side, b + side, a - side, b + side, b - side]
	for v: Vector2 in quad:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(Vector3(v.x, y, v.y))


func _disc(at: Vector2, r: float, col: Color) -> void:
	var y := Config.BEACON_GUIDE_Y + 0.02
	for i: int in range(16):
		var a0 := TAU * float(i) / 16.0
		var a1 := TAU * float(i + 1) / 16.0
		for v: Vector2 in [at, at + Vector2(cos(a0), sin(a0)) * r, at + Vector2(cos(a1), sin(a1)) * r]:
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(Vector3(v.x, y, v.y))
