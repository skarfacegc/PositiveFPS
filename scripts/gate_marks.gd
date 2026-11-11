class_name GateMarks
extends Node3D

# Walls and gates: Grid fixes (#56). What each gate tells you at a glance (placeholder look, drawn in both looks as
# plain labels and flat glows, no new art):
#  - the people on the gate against the people it needs ("3/4"), red when short;
#  - a gate being pushed glows coral along its length, brighter and pulsing as the dent grows (from PUSH_ALERT_FROM of
#    the break depth), so it reads from across the screen. An off-screen gate gets an edge pointer from the gap arrows
#    (see pointers(), called by LevelHud).
# It only reads the border: it changes no rules.

var level: TopDownMain
# The number of gates glowing as of the last frame (tests read it).
var glowing := 0

var _labels: Dictionary = {}  # Gate index -> Label3D
var _shown_texts: Dictionary = {}  # Gate index -> the text on the label now
var _mesh: ImmediateMesh
var _mat: StandardMaterial3D
var _inst: MeshInstance3D
var _clock := 0.0


static func attach(main: TopDownMain) -> GateMarks:
	var node := GateMarks.new()
	node.name = "GateMarks"
	node.level = main
	node._mesh = ImmediateMesh.new()
	node._mat = StandardMaterial3D.new()
	node._mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node._mat.vertex_color_use_as_albedo = true
	node._mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node._mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	node._inst = MeshInstance3D.new()
	node._inst.mesh = node._mesh
	node._inst.material_override = node._mat
	node._inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(node._inst)
	main.add_child(node)
	return node


func _process(delta: float) -> void:
	if level == null:
		return
	_clock += delta
	_update_labels()
	_update_glow()


# The text on gate `g`'s label: members over need.
static func count_text(members: int, need: int) -> String:
	return "%d/%d" % [members, need]


# True when gate `g` has fewer people than it needs.
func is_short(g: int) -> bool:
	var gates: Array[Dictionary] = level.border.zone.gates
	if g < 0 or g >= gates.size():
		return false
	var need: int = gates[g]["need"]
	return level.border.gate_member_count(g) < need


func label_text(g: int) -> String:
	if not _shown_texts.has(g):
		return ""
	var text: String = _shown_texts[g]
	return text


func _update_labels() -> void:
	var border := level.border
	var gates: Array[Dictionary] = border.zone.gates
	var live := border.active and border.polygon.size() >= 3
	for g: int in range(gates.size()):
		var label := _label_for(g)
		label.visible = live
		if not live:
			continue
		var gate := gates[g]
		var need: int = gate["need"]
		var members := border.gate_member_count(g)
		var text := count_text(members, need)
		if _shown_texts.get(g, "") != text:
			_shown_texts[g] = text
			label.text = text
		var mid: Vector2 = gate["mid"]
		var out: Vector2 = gate["out"]
		label.position = Vector3(
			mid.x + out.x * BorderConfig.GATE_COUNT_OUT,
			BorderConfig.GATE_COUNT_HEIGHT,
			mid.y + out.y * BorderConfig.GATE_COUNT_OUT
		)
		label.modulate = (BorderConfig.GATE_COUNT_SHORT_COLOUR if members < need else BorderConfig.GATE_COUNT_OK_COLOUR)
	for key: Variant in _labels.keys():
		var gi: int = key
		if gi >= gates.size():
			var old: Label3D = _labels[gi]
			old.queue_free()
			_labels.erase(gi)
			_shown_texts.erase(gi)


func _label_for(g: int) -> Label3D:
	if _labels.has(g):
		var have: Label3D = _labels[g]
		return have
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = BorderConfig.GATE_COUNT_PIXEL_SIZE
	label.font_size = BorderConfig.GATE_COUNT_FONT_SIZE
	label.outline_size = 12
	label.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
	label.double_sided = true
	add_child(label)
	_labels[g] = label
	return label


func _update_glow() -> void:
	var border := level.border
	var pressed := border.pressed_gates(PushConfig.PUSH_ALERT_FROM)
	glowing = pressed.size()
	_mesh.clear_surfaces()
	if pressed.is_empty():
		return
	var wave := 0.5 - 0.5 * cos(TAU * _clock / PushConfig.PUSH_ALERT_PULSE_SECONDS)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for d: Dictionary in pressed:
		var g: int = d["gate"]
		var bend: float = d["bend"]
		var width := PushConfig.PUSH_ALERT_WIDTH * lerpf(0.5, 1.0, bend)
		var col := PushConfig.PUSH_ALERT_COLOUR
		col.a = clampf((0.25 + 0.6 * bend) * lerpf(0.65, 1.0, wave), 0.0, 1.0)
		var steps := 8
		var prev := border.gate_point(g, 0.0)
		for k: int in range(1, steps + 1):
			var cur := border.gate_point(g, float(k) / float(steps))
			_quad(prev, cur, width, col)
			prev = cur
	_mesh.surface_end()


func _quad(a: Vector2, b: Vector2, width: float, col: Color) -> void:
	var dir := b - a
	if dir.length() < 0.001:
		return
	var side := Vector2(-dir.y, dir.x).normalized() * width * 0.5
	var y := BorderConfig.TAKE_MARK_Y + 0.02
	var corners: Array[Vector2] = [a - side, a + side, b + side, b - side]
	for idx: int in [0, 1, 2, 0, 2, 3]:
		var c := corners[idx]
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(Vector3(c.x, y, c.y))


# The edge-pointer entries for gates bent PUSH_POINTER_FROM or more: points to look at and their urgency (the bend), for
# GapArrows (a break has an arrow of its own already).
static func pointers(border: Border) -> Dictionary:
	var points: Array[Vector3] = []
	var urgencies: Array[float] = []
	for d: Dictionary in border.pressed_gates(PushConfig.PUSH_POINTER_FROM):
		var at: Vector3 = d["at"]
		var bend: float = d["bend"]
		points.append(at)
		urgencies.append(bend)
	return {"points": points, "urgencies": urgencies}
