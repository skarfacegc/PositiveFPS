class_name StyleTake
extends RefCounted

# 0.4 pass 2b (#58): the styled "take a block" preview and rescue pips, in the same toon and glow materials as the rest
# of the styled look. The preview is a soft warm glow over the cell with a lantern post at each corner, and a row of
# small lamps along every gate the take would open. The pips of a cell next to the zone are small beads in a row
# across it: a lit one is a warm gold bead, an empty one a dim violet-grey bead.

const GLOW := "#ffe9b0"
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
	var mid := rect.get_center()
	StyleKit.glow_plane(
		root,
		StyleKit.glow_mat(StyleKit.hexc(GLOW), GLOW_STRENGTH),
		rect.size.x * 1.15,
		Vector3(mid.x, GLOW_HEIGHT, mid.y)
	)
	var post := StyleKit.mat(StyleKit.hexc(POST))
	var lamp := StyleKit.mat(StyleKit.hexc(LAMP), 0, 0.0, 1.3)
	var corners: Array[Vector2] = [
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)
	]
	for c: Vector2 in corners:
		StyleKit.cyl(root, 0.1, POST_HEIGHT, Vector3(c.x, POST_HEIGHT * 0.5, c.y), post, Vector3.ZERO, -1.0, 6, false)
		StyleKit.sph(root, 0.25, Vector3(c.x, POST_HEIGHT + 0.2, c.y), lamp, Vector3.ONE, 6, false)
	for g: Dictionary in opened:
		var a: Vector2 = g["a"]
		var b: Vector2 = g["b"]
		for p: Vector2 in gate_spots(a, b):
			StyleKit.cyl(root, 0.06, 0.5, Vector3(p.x, 0.25, p.y), post, Vector3.ZERO, -1.0, 5, false)
			StyleKit.sph(root, 0.14, Vector3(p.x, 0.58, p.y), lamp, Vector3.ONE, 5, false)


static func _pips(root: Node3D, centre: Vector3, filled: int, total: int) -> void:
	var lit := StyleKit.mat(StyleKit.hexc(PIP_LIT), 0, 0.0, 1.1)
	var empty := StyleKit.mat(StyleKit.hexc(PIP_EMPTY))
	var spots := pip_spots(centre, total)
	for i: int in range(spots.size()):
		if i < filled:
			StyleKit.sph(root, PIP_LIT_RADIUS, spots[i], lit, Vector3.ONE, 8, false)
		else:
			StyleKit.sph(root, PIP_EMPTY_RADIUS, spots[i], empty, Vector3(1.0, 0.7, 1.0), 6, false)
