class_name TakeBlock
extends Node3D

# Walls and gates: Recorder catch-up (#59). The recorder listens: `taken` carries the take's numbers and `refused` the
# reason ("spirit_short", "not_next", "already_held" or "cancelled") with what was there.
signal taken(info: Dictionary)
signal refused(reason: String, info: Dictionary)

# Walls and gates: Take a block (E, #10). Hold E and point at a cell: a placeholder outline shows the cell and the gates
# it opens. Release to take it. Grid fixes: E is the only way a cell joins. A cell with all its pips (RescuePips) is
# ready and free; any other cell next to the zone costs TAKE_SPIRIT_COST (refused with the slim banner when spirit is
# short). People never refuse a take: the preview shows the people the new gates need against the free ones, and a short
# line is shared out thinly. Right-click cancels. Cells you can take now glow on the ground (and on the minimap): one
# look for free, another for paid; a taken cell pulses. The pips of rescues (#11) are drawn here too; their rules are in
# RescuePips. The placeholder look is flat lines and glows on the ground; the styled look (#58) adds StyleTake.

enum Mark { NONE, PAID, FREE }

const NO_CELL := Vector2i(-99, -99)
const LINE_Y := 0.3
const PIP_HALF := 0.35
const PIP_STEP := 1.0

var level: TopDownMain
var holding := false
# The Zone.preview of the cell pointed at while holding (empty otherwise).
var preview: Dictionary = {}
var target_cell := NO_CELL

var _mesh: ImmediateMesh
var _mats: Dictionary = {}
var _alpha_mats: Dictionary = {}
var _drawn_target := NO_CELL
var _drawn_pips := -1
var _drawn_zone := -1
var _drawn_styled := false
var _drawn_holding := false
var _drawn_marks := -1
var _styled_root: Node3D
var _label: Label3D
# The cells that pulse after a take: {"cell": Vector2i, "left": float}.
var _pulses: Array[Dictionary] = []


static func attach(main: TopDownMain) -> TakeBlock:
	var node := TakeBlock.new()
	node.name = "TakeBlock"
	node.level = main
	node._mesh = ImmediateMesh.new()
	var inst := MeshInstance3D.new()
	inst.mesh = node._mesh
	node.add_child(inst)
	node._styled_root = Node3D.new()
	node._styled_root.name = "StyledParts"
	node.add_child(node._styled_root)
	node._label = Label3D.new()
	node._label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node._label.no_depth_test = true
	node._label.pixel_size = BorderConfig.GATE_COUNT_PIXEL_SIZE
	node._label.font_size = BorderConfig.GATE_COUNT_FONT_SIZE
	node._label.outline_size = 12
	node._label.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
	node._label.visible = false
	node.add_child(node._label)
	main.add_child(node)
	return node


func _unhandled_input(event: InputEvent) -> void:
	if level == null or not level.player.active:
		return
	if event.is_action_pressed("take_block"):
		holding = true
		_refresh()
	elif event.is_action_released("take_block"):
		_release()
	elif holding and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()


func _process(delta: float) -> void:
	if level == null:
		return
	if holding:
		_refresh()
	var had_pulses := not _pulses.is_empty()
	var alive: Array[Dictionary] = []
	for pulse: Dictionary in _pulses:
		var left: float = pulse["left"]
		pulse["left"] = left - delta
		if left - delta > 0.0:
			alive.append(pulse)
	_pulses = alive
	var pips_version := level.border.pips.version
	var zone_version := level.border.zone.version
	var look_changed := Looks.is_styled() != _drawn_styled
	var marks := _marks_signature()
	if (
		(holding and not _drawn_styled)
		or holding != _drawn_holding
		or look_changed
		or pips_version != _drawn_pips
		or zone_version != _drawn_zone
		or target_cell != _drawn_target
		or marks != _drawn_marks
		or had_pulses
	):
		_drawn_pips = pips_version
		_drawn_zone = zone_version
		_drawn_target = target_cell
		_drawn_marks = marks
		_draw_all()
	_update_label()


# How a cell reads right now: FREE (next to the zone with all its pips), PAID (next to the zone and you have the spirit
# for it), or NONE (not takeable now).
func mark_of(cell: Vector2i) -> int:
	var zone := level.border.zone
	if not zone.can_take(cell):
		return Mark.NONE
	if level.border.pips.is_ready(cell):
		return Mark.FREE
	if level.player.spirit >= BorderConfig.TAKE_SPIRIT_COST:
		return Mark.PAID
	return Mark.NONE


# The takeable cells as {"rect": Rect2, "free": bool}, for the minimap.
func mark_rects() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for c: Vector2i in TownGrid.all_cells():
		var kind := mark_of(c)
		if kind != Mark.NONE:
			out.append({"rect": TownGrid.cell_rect(c), "free": kind == Mark.FREE})
	return out


func _marks_signature() -> int:
	var sig := 0
	for c: Vector2i in TownGrid.all_cells():
		sig = sig * 3 + mark_of(c)
	return sig


# True while the cell is pulsing after a take (tests read it).
func is_pulsing(cell: Vector2i) -> bool:
	for pulse: Dictionary in _pulses:
		if pulse["cell"] == cell:
			return true
	return false


# What the preview label says: the price of the cell, then the people the new gates need against the free people.
func preview_text() -> String:
	var valid: bool = preview.get("valid", false)
	if not valid:
		return ""
	var needed: int = preview["members_needed"]
	var price := (
		"Free: ready" if level.border.pips.is_ready(target_cell) else "%d spirit" % int(BorderConfig.TAKE_SPIRIT_COST)
	)
	return "%s\nPeople: need %d, free %d" % [price, needed, _rescued_count()]


func _update_label() -> void:
	var text := preview_text() if holding else ""
	_label.visible = text != ""
	if text == "":
		return
	if _label.text != text:
		_label.text = text
	var centre := TownGrid.cell_centre(target_cell)
	_label.position = Vector3(centre.x, BorderConfig.GATE_COUNT_HEIGHT + 1.2, centre.z)
	var needed: int = preview["members_needed"]
	_label.modulate = (
		BorderConfig.GATE_COUNT_SHORT_COLOUR if needed > _rescued_count() else BorderConfig.GATE_COUNT_OK_COLOUR
	)


# Takes `cell` (free when its pips are full, else for the spirit cost), or refuses with the slim banner when spirit is
# short. Returns true when the cell was taken. A cell that is not next to the zone, or already held, is ignored without
# a banner (the recorder logs `not_next` or `already_held`). People never refuse a take.
func take_now(cell: Vector2i) -> bool:
	var zone := level.border.zone
	var pv: Dictionary = zone.preview(cell, true)
	var valid: bool = pv["valid"]
	var needed: int = pv.get("members_needed", 0)
	var info := {
		"cell": [cell.x, cell.y],
		"spirit": snappedf(level.player.spirit, 0.1),
		"people_needed": needed,
		"people_free": _rescued_count(),
		"gates_before": zone.gates.size()
	}
	if not valid:
		refused.emit("already_held" if zone.has(cell) else "not_next", info)
		return false
	var free := level.border.pips.is_ready(cell)
	if not free and level.player.spirit < BorderConfig.TAKE_SPIRIT_COST:
		refused.emit("spirit_short", info)
		_refuse("Not enough spirit to take a block.")
		return false
	if not free:
		level.player.lose_spirit(BorderConfig.TAKE_SPIRIT_COST)
	zone.take(cell)
	level.border.pips.prune(zone)
	info["spirit_paid"] = 0.0 if free else BorderConfig.TAKE_SPIRIT_COST
	info["spirit"] = snappedf(level.player.spirit, 0.1)
	info["gates_after"] = zone.gates.size()
	info["free"] = free
	_pulses.append({"cell": cell, "left": BorderConfig.TAKE_PULSE_SECONDS})
	_announce(free, zone.members_needed())
	taken.emit(info)
	return true


# The slim banner for a taken cell: what it cost and what the line wants now.
func _announce(free: bool, needed: int) -> void:
	var cost := "Block taken (ready)" if free else "Block taken (%d spirit)" % int(BorderConfig.TAKE_SPIRIT_COST)
	level.intro.calm_notice(Intro.Prompt.SPIRIT_LOW, "%s: the line wants %d people" % [cost, needed])


# The people you have: every rescued person (the border only seats the ones its gates can hold).
func _rescued_count() -> int:
	var n := 0
	for p: Person in level.people:
		if p.is_rescued:
			n += 1
	return n


func _refuse(words: String) -> void:
	level.intro.notice(Intro.Prompt.SPIRIT_LOW, words)


func _refresh() -> void:
	target_cell = _aim_cell()
	if target_cell == NO_CELL:
		preview = {}
	else:
		preview = level.border.zone.preview(target_cell, true)


func _aim_cell() -> Vector2i:
	if not level.player.has_aim():
		return NO_CELL
	return TownGrid.cell_of(level.player.aim_point())


func _release() -> void:
	if not holding:
		return
	_refresh()
	holding = false
	take_now(target_cell)
	preview = {}
	target_cell = NO_CELL


func _cancel() -> void:
	refused.emit("cancelled", {"cell": [target_cell.x, target_cell.y]})
	holding = false
	preview = {}
	target_cell = NO_CELL


func _draw_all() -> void:
	var outline := Array()
	var gates := Array()
	var pip_on := Array()
	var pip_off := Array()
	var zone := level.border.zone
	var valid: bool = preview.get("valid", false)
	_drawn_styled = Looks.is_styled()
	_drawn_holding = holding
	for child: Node in _styled_root.get_children():
		_styled_root.remove_child(child)
		child.queue_free()
	_mesh.clear_surfaces()
	_draw_marks()
	if _drawn_styled:
		_draw_styled(zone, holding and valid)
		return
	if holding and valid:
		_add_rect(outline, TownGrid.cell_rect(target_cell))
		for g: Dictionary in preview["opened"]:
			var a: Vector2 = g["a"]
			var b: Vector2 = g["b"]
			_add_seg(gates, a, b)
	for c: Vector2i in TownGrid.all_cells():
		if zone.can_take(c):
			_add_pips(pip_on, pip_off, c, level.border.pips.filled(c))
	_surface(outline, _mat(Color(0.95, 0.93, 0.85)))
	_surface(gates, _mat(Color(0.85, 0.66, 0.3)))
	_surface(pip_on, _mat(Color(0.85, 0.66, 0.3)))
	_surface(pip_off, _mat(Color(0.5, 0.5, 0.5)))


# The glow on every takeable cell (free and paid look different) and the pulse on cells just taken. Flat quads on the
# ground; both looks draw them.
func _draw_marks() -> void:
	var free_pts := Array()
	var paid_pts := Array()
	for c: Vector2i in TownGrid.all_cells():
		var kind := mark_of(c)
		if kind == Mark.FREE:
			_add_quad(free_pts, TownGrid.cell_rect(c))
		elif kind == Mark.PAID:
			_add_quad(paid_pts, TownGrid.cell_rect(c))
	_triangles(free_pts, _alpha_mat(BorderConfig.TAKE_MARK_FREE_COLOUR))
	_triangles(paid_pts, _alpha_mat(BorderConfig.TAKE_MARK_PAID_COLOUR))
	for pulse: Dictionary in _pulses:
		var cell: Vector2i = pulse["cell"]
		var left: float = pulse["left"]
		var share := ceilf(clampf(left / BorderConfig.TAKE_PULSE_SECONDS, 0.0, 1.0) * 8.0) / 8.0  # In eighths.
		var col := BorderConfig.TAKE_PULSE_COLOUR
		col.a *= share
		var pts := Array()
		_add_quad(pts, TownGrid.cell_rect(cell).grow(-BorderConfig.TAKE_MARK_INSET * (1.0 - share)))
		_triangles(pts, _alpha_mat(col))


# The styled look (#58): lanterns, gate lamps and bead pips (StyleTake) instead of the flat lines.
func _draw_styled(zone: Zone, show_preview: bool) -> void:
	var rect := Rect2()
	var opened: Array[Dictionary] = []
	if show_preview:
		rect = TownGrid.cell_rect(target_cell)
		for g: Dictionary in preview["opened"]:
			opened.append(g)
	var cells: Array[Dictionary] = []
	for c: Vector2i in TownGrid.all_cells():
		if zone.can_take(c):
			cells.append(
				{
					"centre": TownGrid.cell_centre(c),
					"filled": level.border.pips.filled(c),
					"total": BorderConfig.TAKE_RESCUES
				}
			)
	StyleTake.build(_styled_root, show_preview, rect, opened, cells)


# The pips of cell `c`: one small square per pip in a row across the cell, lit ones first.
func _add_pips(on: Array, off: Array, c: Vector2i, filled: int) -> void:
	var centre := TownGrid.cell_centre(c)
	for i: int in range(BorderConfig.TAKE_RESCUES):
		var x := (float(i) - float(BorderConfig.TAKE_RESCUES - 1) * 0.5) * PIP_STEP
		var at := centre + Vector3(x, 0.0, 0.0)
		var pts := on if i < filled else off
		_add_seg(pts, Vector2(at.x - PIP_HALF, at.z - PIP_HALF), Vector2(at.x + PIP_HALF, at.z - PIP_HALF))
		_add_seg(pts, Vector2(at.x + PIP_HALF, at.z - PIP_HALF), Vector2(at.x + PIP_HALF, at.z + PIP_HALF))
		_add_seg(pts, Vector2(at.x + PIP_HALF, at.z + PIP_HALF), Vector2(at.x - PIP_HALF, at.z + PIP_HALF))
		_add_seg(pts, Vector2(at.x - PIP_HALF, at.z + PIP_HALF), Vector2(at.x - PIP_HALF, at.z - PIP_HALF))


func _add_rect(pts: Array, r: Rect2) -> void:
	var x0 := r.position.x
	var z0 := r.position.y
	var x1 := r.end.x
	var z1 := r.end.y
	_add_seg(pts, Vector2(x0, z0), Vector2(x1, z0))
	_add_seg(pts, Vector2(x1, z0), Vector2(x1, z1))
	_add_seg(pts, Vector2(x1, z1), Vector2(x0, z1))
	_add_seg(pts, Vector2(x0, z1), Vector2(x0, z0))


# Two triangles filling `r` (inset by TAKE_MARK_INSET), flat on the ground.
func _add_quad(pts: Array, r: Rect2) -> void:
	var q := r.grow(-BorderConfig.TAKE_MARK_INSET)
	var y := BorderConfig.TAKE_MARK_Y
	var a := Vector3(q.position.x, y, q.position.y)
	var b := Vector3(q.end.x, y, q.position.y)
	var c := Vector3(q.end.x, y, q.end.y)
	var d := Vector3(q.position.x, y, q.end.y)
	pts.append_array([a, b, c, a, c, d])


func _add_seg(pts: Array, a: Vector2, b: Vector2) -> void:
	pts.append(Vector3(a.x, LINE_Y, a.y))
	pts.append(Vector3(b.x, LINE_Y, b.y))


func _surface(pts: Array, mat: Material) -> void:
	if pts.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES, mat)
	for v: Vector3 in pts:
		_mesh.surface_add_vertex(v)
	_mesh.surface_end()


func _triangles(pts: Array, mat: Material) -> void:
	if pts.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, mat)
	for v: Vector3 in pts:
		_mesh.surface_add_vertex(v)
	_mesh.surface_end()


func _mat(col: Color) -> StandardMaterial3D:
	if not _mats.has(col):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		_mats[col] = m
	return _mats[col]


func _alpha_mat(col: Color) -> StandardMaterial3D:
	if not _alpha_mats.has(col):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = col
		_alpha_mats[col] = m
	return _alpha_mats[col]
