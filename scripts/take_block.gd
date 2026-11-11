class_name TakeBlock
extends Node3D

# Walls and gates: Recorder catch-up (#59). The recorder listens: `taken` carries the take's numbers and `refused` the
# reason ("spirit_short", "people_short", "not_next" or "cancelled") with what was there.
signal taken(info: Dictionary)
signal refused(reason: String, info: Dictionary)

# Walls and gates: Take a block (E, #10). Hold E and point at a cell: a placeholder outline shows the cell and the gates
# it opens. Release to take it, paying TAKE_SPIRIT_COST; refused with the slim banner when spirit is short or the gates
# need more members than the border has. Right-click cancels. The pips of rescues (#11) are drawn here too; their rules
# are in RescuePips. The placeholder look is flat lines on the ground; the styled look (#58) is StyleTake.

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
var _drawn_target := NO_CELL
var _drawn_pips := -1
var _drawn_zone := -1
var _drawn_styled := false
var _drawn_holding := false
var _styled_root: Node3D


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


func _process(_delta: float) -> void:
	if level == null:
		return
	if holding:
		_refresh()
	var pips_version := level.border.pips.version
	var zone_version := level.border.zone.version
	var look_changed := Looks.is_styled() != _drawn_styled
	if (
		(holding and not _drawn_styled)
		or holding != _drawn_holding
		or look_changed
		or pips_version != _drawn_pips
		or zone_version != _drawn_zone
		or target_cell != _drawn_target
	):
		_drawn_pips = pips_version
		_drawn_zone = zone_version
		_drawn_target = target_cell
		_draw_all()


# Takes `cell` for the spirit cost, or refuses with the slim banner. Returns true when the cell was taken. A cell that
# is not next to the zone (or already held) is ignored without a banner.
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
		refused.emit("not_next", info)
		return false
	if level.player.spirit < BorderConfig.TAKE_SPIRIT_COST:
		refused.emit("spirit_short", info)
		_refuse("Not enough spirit to take a block.")
		return false
	if needed > _rescued_count():
		refused.emit("people_short", info)
		_refuse("The new gates need more people than you have.")
		return false
	level.player.lose_spirit(BorderConfig.TAKE_SPIRIT_COST)
	zone.take(cell)
	info["spirit_paid"] = BorderConfig.TAKE_SPIRIT_COST
	info["spirit"] = snappedf(level.player.spirit, 0.1)
	info["gates_after"] = zone.gates.size()
	info["free"] = false  # Today's rules: a take always costs spirit (2c makes a pip-ready take free).
	taken.emit(info)
	return true


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
	if _drawn_styled:
		_mesh.clear_surfaces()
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
	_mesh.clear_surfaces()
	_surface(outline, _mat(Color(0.95, 0.93, 0.85)))
	_surface(gates, _mat(Color(0.85, 0.66, 0.3)))
	_surface(pip_on, _mat(Color(0.85, 0.66, 0.3)))
	_surface(pip_off, _mat(Color(0.5, 0.5, 0.5)))


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


func _mat(col: Color) -> StandardMaterial3D:
	if not _mats.has(col):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = col
		_mats[col] = m
	return _mats[col]
