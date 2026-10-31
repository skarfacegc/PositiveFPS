class_name ReachGuide
extends Node3D

# Round 20/21: the placeholder look's guide to the stretching zone, drawn flat on the ground. Before you commit it shows
# the zone a press of E at the cursor would make: the teardrop outline (a faint fill inside), a bright marker at the tip
# and the words "E: stretch here". When something holds the tip back (too far for the people, or dimmed people in the
# way) the outline turns coral, shows the zone the stretch would really make and says why in a few words. During a
# stretch it shows the tip's travel (a line from the centre to the tip, a disc at the tip, a dashed line on to the
# beacon when the reach falls short), the plain circle the zone becomes at the snap (dashed, round the tip) and, once
# the tip
# holds, a double arc round the tip that empties as the snap-back nears with "Holds N s". Graphics checkpoint 4: the
# styled look draws the older reach ring and line with dithered ground pieces (StyleReach), swapped in by sync.

const SEGMENTS := 72
const LINE_WIDTH := 0.28
const PATH_WIDTH := 0.5

var _mesh := ImmediateMesh.new()
var _item := MeshInstance3D.new()
var _styled: StyleReach
var _label: Label3D


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
		_set_label("", Vector2.ZERO)
		_styled.sync(border, player)
		return
	if _styled != null:
		_styled.hide()
	if not border.active:
		_set_label("", Vector2.ZERO)
		return
	var info := border.stretch_info()
	var c := Vector2(border.centre.x, border.centre.z)
	if info["on"]:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_travel(c, border, info)
		_mesh.surface_end()
	elif player.has_aim():
		var aim := Vector2(player.aim_point().x, player.aim_point().z)
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_zone_preview(c, border.plan_stretch(player.aim_point()), aim)
		_mesh.surface_end()
	else:
		_set_label("", Vector2.ZERO)


# Where the tip would stop toward `aim` from the centre `c` with the longest reach `reach`: {"end": Vector2, "capped":
# bool} (capped when the cursor is beyond the reach, so the tip stops short). The styled guide draws this.
static func preview(c: Vector2, aim: Vector2, reach: float) -> Dictionary:
	var to := aim - c
	return {"end": c + to.normalized() * minf(to.length(), reach), "capped": to.length() > reach}


# Round 21: the zone a press of E at the cursor would make (Border.plan_stretch, the same plan the real stretch
# uses): its outline and a faint fill, a marker at the tip, and, when something holds the tip back, a coral outline
# and the reason.
func _zone_preview(c: Vector2, plan: Dictionary, aim: Vector2) -> void:
	var outline: PackedVector2Array = plan["outline"]
	var reason: String = plan["reason"]
	var reach: float = plan["reach"]
	var ang: float = plan["dir"]
	var limited := reason != ""
	var col := Config.BEACON_GUIDE_CAPPED_COLOUR if limited else Config.BEACON_GUIDE_PREVIEW_COLOUR
	var fill := Config.BEACON_GUIDE_LIMITED_FILL_COLOUR if limited else Config.BEACON_GUIDE_FILL_COLOUR
	_fill(c, outline, fill)
	_outline(outline, Config.BEACON_GUIDE_OUTLINE_WIDTH, col)
	var end := c + Vector2(cos(ang), sin(ang)) * reach
	_disc(end, 1.1, Config.BEACON_GUIDE_TIP_COLOUR)
	_ring(end, 2.0, Config.BEACON_GUIDE_TIP_COLOUR, false)
	if limited and aim.distance_to(end) > 2.0:
		_cross(aim, 1.2, Config.BEACON_GUIDE_CAPPED_COLOUR)
	_set_label(reason if limited else "E: stretch here", end)


func _travel(c: Vector2, border: Border, info: Dictionary) -> void:
	var tip_pos: Vector3 = info["tip"]
	var tip := Vector2(tip_pos.x, tip_pos.z)
	_line(c, tip, PATH_WIDTH, Config.BEACON_GUIDE_PATH_COLOUR)
	_disc(tip, 1.3, Config.BEACON_GUIDE_TIP_COLOUR)
	# What the zone becomes at the snap: a plain circle round the tip.
	var radius: float = info["radius"]
	_ring(tip, radius, Config.BEACON_GUIDE_RING_COLOUR, true)
	var beacon := border.beacon_pos()
	if beacon != Vector3.INF and Vector2(beacon.x, beacon.z).distance_to(tip) > 1.0:
		_dashes(tip, Vector2(beacon.x, beacon.z), Config.BEACON_GUIDE_CAPPED_COLOUR)
	if info["holding"]:
		var left: float = info["hold_left"]
		var share := clampf(left / Config.BEACON_STRETCH_HOLD, 0.0, 1.0)
		_ring(tip, 2.4, Config.BEACON_GUIDE_TIP_COLOUR, false, share)
		_ring(tip, 2.7, Config.BEACON_GUIDE_TIP_COLOUR, false, share)
		_set_label("Holds %d s" % ceili(left), tip)
	else:
		_set_label("Stretching", tip)


# Shows `text` just beyond `at` (nothing when it is empty). The text is set only when it changes.
func _set_label(text: String, at: Vector2) -> void:
	if _label == null:
		if text == "":
			return
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.pixel_size = Config.BEACON_GUIDE_LABEL_SIZE
		_label.modulate = Config.BEACON_GUIDE_LABEL_COLOUR
		_label.outline_size = 10
		add_child(_label)
	_label.visible = text != ""
	if text != "" and text != _label.text:
		_label.text = text
	_label.position = Vector3(at.x, 3.2, at.y)


# A filled fan from `c` to the outline (a faint tint over the zone).
func _fill(c: Vector2, pts: PackedVector2Array, col: Color) -> void:
	var y := Config.BEACON_GUIDE_Y - 0.02
	var n := pts.size()
	for i: int in range(n):
		for v: Vector2 in [c, pts[i], pts[(i + 1) % n]]:
			_mesh.surface_set_color(col)
			_mesh.surface_add_vertex(Vector3(v.x, y, v.y))


func _outline(pts: PackedVector2Array, width: float, col: Color) -> void:
	var n := pts.size()
	for i: int in range(n):
		_line(pts[i], pts[(i + 1) % n], width, col)


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
