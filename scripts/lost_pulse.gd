class_name LostPulse
extends Node3D

# Walls and gates: Pressure (#13). A cell the gloom took pulses grey on the ground for LOST_PULSE_SECONDS. Flat quads
# (placeholder look; the styled look draws the same, nothing styled is added). LevelEvents wires it to
# Border.cells_lost.

# One entry per pulse: {"node": MeshInstance3D, "mat": StandardMaterial3D, "left": seconds}.
var _items: Array[Dictionary] = []


# Makes the node under `parent`.
static func attach(parent: Node) -> LostPulse:
	var node := LostPulse.new()
	parent.add_child(node)
	return node


func _process(delta: float) -> void:
	update(delta)


# Starts a pulse on `cell`.
func pulse(cell: Vector2i) -> void:
	var rect := TownGrid.cell_rect(cell)
	var plane := PlaneMesh.new()
	plane.size = rect.size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = BorderConfig.LOST_PULSE_COLOUR
	var node := MeshInstance3D.new()
	node.mesh = plane
	node.material_override = mat
	var mid := rect.get_center()
	node.position = Vector3(mid.x, BorderConfig.LOST_PULSE_Y, mid.y)
	add_child(node)
	_items.append({"node": node, "mat": mat, "left": BorderConfig.LOST_PULSE_SECONDS})


# How many pulses are showing.
func count() -> int:
	return _items.size()


# Fades the pulses and frees the ones that are done. Tests call it directly.
func update(delta: float) -> void:
	for k: int in range(_items.size() - 1, -1, -1):
		var item: Dictionary = _items[k]
		var left: float = item["left"] - delta
		var node: MeshInstance3D = item["node"]
		if left <= 0.0:
			node.queue_free()
			_items.remove_at(k)
			continue
		item["left"] = left
		var mat: StandardMaterial3D = item["mat"]
		var col := BorderConfig.LOST_PULSE_COLOUR
		col.a *= clampf(left / BorderConfig.LOST_PULSE_SECONDS, 0.0, 1.0)
		mat.albedo_color = col
