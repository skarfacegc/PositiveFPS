class_name StyleGates
extends RefCounted

# Walls and gates: Style update (#94). A gate reads as a gate in the styled look: a stone post with a warm lantern at
# each end of the opening, and a festoon of small bulbs hung between them over the street (the hedged walls stay as they
# are, see StyleHedge). `plan` is pure (tests read it); `build` makes the meshes: three per post, a few string
# pieces a gate and one MultiMesh of bulbs for all the gates.

const POST_COLOUR := "#9a93a8"
const CAP_COLOUR := "#6b5a48"
const LAMP_COLOUR := "#ffd24a"
const STRING_COLOUR := "#4a3a2c"
const MAX_BULBS := 220


# The gates' arches: [{"posts": [Vector2, Vector2], "string": [Vector3, ...], "bulbs": [Vector3, ...]}], one per gate. A
# post stands StyleConfig.SU_GATE_INSET metres inside each end of the opening; the string hangs between the post tops,
# sagging StyleConfig.SU_GATE_SAG at its middle, with a bulb every SU_GATE_BULB_STEP metres.
static func plan(gates: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for g: Dictionary in gates:
		var a: Vector2 = g["a"]
		var b: Vector2 = g["b"]
		var length := a.distance_to(b)
		if length < StyleConfig.SU_GATE_MIN_LENGTH:
			continue
		var d := (b - a) / length
		var p0 := a + d * StyleConfig.SU_GATE_INSET
		var p1 := b - d * StyleConfig.SU_GATE_INSET
		var span := p0.distance_to(p1)
		var string: Array[Vector3] = []
		var pieces := StyleConfig.SU_GATE_PIECES
		for k: int in range(pieces + 1):
			string.append(_hang(p0, p1, float(k) / float(pieces)))
		var bulbs: Array[Vector3] = []
		var n := maxi(1, int(span / StyleConfig.SU_GATE_BULB_STEP))
		for k: int in range(n):
			var at := _hang(p0, p1, (float(k) + 0.5) / float(n))
			bulbs.append(at - Vector3(0.0, StyleConfig.SU_GATE_BULB_DROP, 0.0))
		out.append({"posts": [p0, p1], "string": string, "bulbs": bulbs})
	return out


# The point of the festoon at share `t` of the way from `p0` to `p1`.
static func _hang(p0: Vector2, p1: Vector2, t: float) -> Vector3:
	var p := p0.lerp(p1, t)
	return Vector3(p.x, StyleConfig.SU_GATE_POST_HEIGHT - StyleConfig.SU_GATE_SAG * sin(PI * t), p.y)


# How many meshes (not counting the bulbs' MultiMesh) a planned gate takes.
static func mesh_count(item: Dictionary) -> int:
	var string: Array = item["string"]
	return 6 + string.size() - 1


# Builds the planned arches under `parent`.
static func build(parent: Node3D, items: Array[Dictionary]) -> void:
	var post := StyleKit.mat(StyleKit.hexc(POST_COLOUR))
	var cap := StyleKit.mat(StyleKit.hexc(CAP_COLOUR))
	var lamp := StyleKit.mat(StyleKit.hexc(LAMP_COLOUR), 0, 0.0, 1.4)
	var cord := StyleKit.mat(StyleKit.hexc(STRING_COLOUR))
	var h := StyleConfig.SU_GATE_POST_HEIGHT
	var w := StyleConfig.SU_GATE_POST_SIZE
	var bulbs: Array[Vector3] = []
	for item: Dictionary in items:
		var posts: Array = item["posts"]
		for p: Vector2 in posts:
			StyleKit.box(parent, Vector3(w, h, w), Vector3(p.x, h * 0.5, p.y), post)
			StyleKit.box(parent, Vector3(w * 1.4, 0.18, w * 1.4), Vector3(p.x, h + 0.09, p.y), cap)
			StyleKit.sph(parent, w * 0.42, Vector3(p.x, h + 0.18 + w * 0.4, p.y), lamp, Vector3.ONE, 6, false)
		var string: Array = item["string"]
		for k: int in range(string.size() - 1):
			var s0: Vector3 = string[k]
			var s1: Vector3 = string[k + 1]
			StyleKit.seg(parent, s0, s1, 0.035, cord, 4, false)
		var spots: Array = item["bulbs"]
		for s: Vector3 in spots:
			bulbs.append(s)
	if bulbs.is_empty():
		return
	var sphere := SphereMesh.new()
	sphere.radius = StyleConfig.SU_GATE_BULB_RADIUS
	sphere.height = StyleConfig.SU_GATE_BULB_RADIUS * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = mini(bulbs.size(), MAX_BULBS)
	for i: int in range(mm.instance_count):
		mm.set_instance_transform(i, Transform3D(Basis(), bulbs[i]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = lamp
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
