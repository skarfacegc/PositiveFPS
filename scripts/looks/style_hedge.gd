class_name StyleHedge
extends RefCounted

# 0.4 pass 2b (#58): the styled wall. A wall run of the zone's line (the face of a held built block) is a low clipped
# hedge along the street side, with small warm lamps on top, so at play zoom a wall reads as a solid green edge and a
# gate as the open golden ribbon. A run along the map's edge is left bare: the plaza's stone wall is already there.
# `plan` is pure (tests read it); `build` makes the meshes: two boxes per run and one MultiMesh of lamps for all.

const OFFSET := 0.6  # Metres from the run toward the street.
const HEIGHT := 0.6
const WIDTH := 0.7
const CAP_HEIGHT := 0.14
const LAMP_STEP := 2.5
const LAMP_RADIUS := 0.13
const MAX_LAMPS := 160
const MIN_LENGTH := 1.0
const BODY := "#4f8a48"
const CAP := "#78b05a"
const LAMP := "#ffe28a"


# The hedges of a zone's runs: [{"a": Vector2, "b": Vector2, "len": float}] along the street side of every wall run
# that is not on the map's edge.
static func plan(runs: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Dictionary in runs:
		var is_gate: bool = r["gate"]
		var a: Vector2 = r["a"]
		var b: Vector2 = r["b"]
		if is_gate or on_map_edge(a, b):
			continue
		var length := a.distance_to(b)
		if length < MIN_LENGTH:
			continue
		# Runs go clockwise with the inside on the right, so the street is on the left: (dz, -dx).
		var d := (b - a) / length
		var off := Vector2(d.y, -d.x) * OFFSET
		out.append({"a": a + off, "b": b + off, "len": length})
	return out


# True when a run lies along the edge of the map (both ends on the same outer line).
static func on_map_edge(a: Vector2, b: Vector2) -> bool:
	var half := TownGrid.span() * 0.5 - 0.01
	return (
		(absf(a.x) >= half and absf(b.x) >= half and signf(a.x) == signf(b.x))
		or (absf(a.y) >= half and absf(b.y) >= half and signf(a.y) == signf(b.y))
	)


# How many lamps a hedge of `length` metres carries.
static func lamp_count(length: float) -> int:
	return maxi(1, int(length / LAMP_STEP))


# Builds the hedges of `plan_list` under `parent`.
static func build(parent: Node3D, plan_list: Array[Dictionary]) -> void:
	var body := StyleKit.mat(StyleKit.hexc(BODY), 0, 0.0, 0.0, 0, 1.0)
	var cap := StyleKit.mat(StyleKit.hexc(CAP))
	var lamps: Array[Vector3] = []
	for h: Dictionary in plan_list:
		var a: Vector2 = h["a"]
		var b: Vector2 = h["b"]
		var length: float = h["len"]
		var mid := (a + b) * 0.5
		var yaw := -atan2(b.y - a.y, b.x - a.x)
		var rot := Vector3(0.0, yaw, 0.0)
		StyleKit.box(parent, Vector3(length, HEIGHT, WIDTH), Vector3(mid.x, HEIGHT * 0.5, mid.y), body, rot)
		StyleKit.box(
			parent,
			Vector3(length - 0.1, CAP_HEIGHT, WIDTH * 0.7),
			Vector3(mid.x, HEIGHT + CAP_HEIGHT * 0.4, mid.y),
			cap,
			rot,
			false
		)
		var n := lamp_count(length)
		for i: int in range(n):
			var t := (float(i) + 0.5) / float(n)
			var p := a.lerp(b, t)
			lamps.append(Vector3(p.x, HEIGHT + CAP_HEIGHT + LAMP_RADIUS, p.y))
	if lamps.is_empty():
		return
	var sphere := SphereMesh.new()
	sphere.radius = LAMP_RADIUS
	sphere.height = LAMP_RADIUS * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = mini(lamps.size(), MAX_LAMPS)
	for i: int in range(mm.instance_count):
		mm.set_instance_transform(i, Transform3D(Basis(), lamps[i]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = StyleKit.mat(StyleKit.hexc(LAMP), 0, 0.0, 1.2)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
