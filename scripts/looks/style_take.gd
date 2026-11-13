class_name StyleTake
extends RefCounted

# 0.4 pass 2b (#58): the styled "take a block" preview and rescue pips, in the same toon and glow materials as the rest
# of the styled look. The preview is a soft warm glow over the cell with a lantern post at each corner, and a row of
# small lamps along every gate the take would open. The pips of a cell next to the zone are small beads in a row
# across it: a lit one is a warm gold bead, an empty one a dim violet-grey bead.

const GLOW := "#ffe9b0"
const FREE_WASH := "#ffd45a"  # Walls and gates: Style update (#94): takeable cells and the pulse of a taken one.
const PAID_WASH := "#6fa8ec"
const PAID_LAMP := "#8fc0ff"
const PULSE_WASH := "#fff0c0"
const POST := "#6b5a48"
const LAMP := "#ffd24a"
const PIP_LIT := "#ffd24a"
const PIP_EMPTY := "#8b87a0"
const PIP_STEP := 1.8
const PIP_LIT_RADIUS := 0.5
const PIP_EMPTY_RADIUS := 0.32
const PIP_HEIGHT := 5.4  # Above the roofs: a cell next to the zone is a solid block, so the beads float over it.
const GLOW_HEIGHT := 4.9
const POST_HEIGHT := 3.0
const GATE_LAMP_STEP := 2.0
const GLOW_STRENGTH := 0.75


# Builds the preview (when `show`) and the pips under `root`. `rect` is the cell pointed at, `opened` the gates taking
# it opens ({"a": Vector2, "b": Vector2}), `cells` the cells next to the zone ({"centre": Vector3, "filled": int,
# "total": int}).
static func build(root: Node3D, show: bool, rect: Rect2, opened: Array[Dictionary], cells: Array[Dictionary]) -> void:
	if show:
		_preview(root, rect, opened)
	for c: Dictionary in cells:
		var centre: Vector3 = c["centre"]
		var filled: int = c["filled"]
		var total: int = c["total"]
		_pips(root, centre, filled, total)


# The positions of the `total` pips of a cell about its centre (a row across it, along x).
static func pip_spots(centre: Vector3, total: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i: int in range(total):
		out.append(centre + Vector3((float(i) - float(total - 1) * 0.5) * PIP_STEP, PIP_HEIGHT, 0.0))
	return out


# The lamp spots along the gate from `a` to `b` (ground points): one every GATE_LAMP_STEP metres, at least two.
static func gate_spots(a: Vector2, b: Vector2) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var n := maxi(2, int(a.distance_to(b) / GATE_LAMP_STEP) + 1)
	for i: int in range(n):
		out.append(a.lerp(b, (float(i) + 0.5) / float(n)))
	return out


static func _preview(root: Node3D, rect: Rect2, opened: Array[Dictionary]) -> void:
	# Walls and gates: Style update (#94). The faint glow plane is a soft wash laid over the cell (it was a square of
	# radial glow whose falloff covered only its middle): a faint warm fill and a brighter band along the edge, above
	# the rooftops, with a small lantern at each corner.
	StyleKit.wash(
		root,
		rect,
		StyleKit.hexc(GLOW),
		StyleConfig.SU_PREVIEW_FILL,
		StyleConfig.SU_PREVIEW_RIM,
		StyleConfig.SU_PREVIEW_Y
	)
	var post := StyleKit.mat(StyleKit.hexc(POST))
	var lamp := StyleKit.mat(StyleKit.hexc(LAMP), 0, 0.0, 1.3)
	var corners: Array[Vector2] = [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	]
	for c: Vector2 in corners:
		StyleKit.cyl(root, 0.1, POST_HEIGHT, Vector3(c.x, POST_HEIGHT * 0.5, c.y), post, Vector3.ZERO, -1.0, 6, false)
		StyleKit.sph(root, 0.2, Vector3(c.x, POST_HEIGHT + 0.2, c.y), lamp, Vector3.ONE, 6, false)
	for g: Dictionary in opened:
		var a: Vector2 = g["a"]
		var b: Vector2 = g["b"]
		for p: Vector2 in gate_spots(a, b):
			StyleKit.cyl(root, 0.06, 0.5, Vector3(p.x, 0.25, p.y), post, Vector3.ZERO, -1.0, 5, false)
			StyleKit.sph(root, 0.14, Vector3(p.x, 0.58, p.y), lamp, Vector3.ONE, 5, false)


# Walls and gates: Style update (#94). The takeable cells (pass 2c) in the styled look. A free cell (all its pips)
# gets a gold wash with a bright edge band and gold lanterns round its roofline; a paid one a blue edge band, hardly
# any fill, and blue lanterns, so the two differ in shape as well as colour. `pulses` ({"rect": Rect2, "share":
# 0..1}) are cells just taken: a warm wash that fades with `share`. One MultiMesh of lanterns a colour keeps it cheap.
static func marks(root: Node3D, free: Array[Rect2], paid: Array[Rect2], pulses: Array[Dictionary]) -> void:
	var gold: Array[Vector3] = []
	var blue: Array[Vector3] = []
	for r: Rect2 in free:
		var inner := r.grow(-StyleConfig.SU_MARK_INSET)
		StyleKit.wash(
			root,
			inner,
			StyleKit.hexc(FREE_WASH),
			StyleConfig.SU_MARK_FREE_FILL,
			StyleConfig.SU_MARK_FREE_RIM,
			StyleConfig.SU_MARK_Y
		)
		gold.append_array(edge_lamps(inner))
	for r: Rect2 in paid:
		var inner := r.grow(-StyleConfig.SU_MARK_INSET)
		StyleKit.wash(
			root,
			inner,
			StyleKit.hexc(PAID_WASH),
			StyleConfig.SU_MARK_PAID_FILL,
			StyleConfig.SU_MARK_PAID_RIM,
			StyleConfig.SU_MARK_Y
		)
		blue.append_array(edge_lamps(inner))
	_lamp_row(root, gold, StyleKit.hexc(LAMP), 1.4)
	_lamp_row(root, blue, StyleKit.hexc(PAID_LAMP), 1.2)
	for p: Dictionary in pulses:
		var rect: Rect2 = p["rect"]
		var share: float = p["share"]
		StyleKit.wash(
			root,
			rect.grow(-StyleConfig.SU_MARK_INSET * (1.0 - share)),
			StyleKit.hexc(PULSE_WASH),
			StyleConfig.SU_PULSE_FILL * share,
			StyleConfig.SU_PULSE_RIM * share,
			StyleConfig.SU_MARK_Y + 0.1
		)


# The lantern spots round the edge of `rect`: one every SU_MARK_LAMP_STEP metres along its four sides, on the roofline.
static func edge_lamps(rect: Rect2) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var corners: Array[Vector2] = [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	]
	for i: int in range(4):
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var n := maxi(2, roundi(a.distance_to(b) / StyleConfig.SU_MARK_LAMP_STEP))
		for k: int in range(n):  # The corner starts each side; the next side's start is this side's end.
			var p := a.lerp(b, float(k) / float(n))
			out.append(Vector3(p.x, StyleConfig.SU_MARK_LAMP_Y, p.y))
	return out


static func _lamp_row(root: Node3D, spots: Array[Vector3], col: Color, glow: float) -> void:
	if spots.is_empty():
		return
	var sphere := SphereMesh.new()
	sphere.radius = StyleConfig.SU_MARK_LAMP_RADIUS
	sphere.height = StyleConfig.SU_MARK_LAMP_RADIUS * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = spots.size()
	for i: int in range(spots.size()):
		mm.set_instance_transform(i, Transform3D(Basis(), spots[i]))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = StyleKit.mat(col, 0, 0.0, glow)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(node)


static func _pips(root: Node3D, centre: Vector3, filled: int, total: int) -> void:
	var lit := StyleKit.mat(StyleKit.hexc(PIP_LIT), 0, 0.0, 1.1)
	var empty := StyleKit.mat(StyleKit.hexc(PIP_EMPTY))
	var spots := pip_spots(centre, total)
	for i: int in range(spots.size()):
		if i < filled:
			StyleKit.sph(root, PIP_LIT_RADIUS, spots[i], lit, Vector3.ONE, 8, false)
		else:
			StyleKit.sph(root, PIP_EMPTY_RADIUS, spots[i], empty, Vector3(1.0, 0.7, 1.0), 6, false)
