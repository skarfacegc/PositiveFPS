class_name StyleBeacon
extends RefCounted

# Graphics checkpoint 3: the spirit beacon in the locked style. A small stone-and-timber lantern post (warm light on
# grey) with a teal-white flame, a slender beam, a dithered pulse ring and glow on the ground, and a few motes orbiting
# the lantern. The centre's pull is drawn as a line of small bright dashes that march from the border's centre toward
# the beacon, thinning out at both ends. The teal sets it apart from the gold of the landmarks and the coral of the
# gaps. Pure visuals: BeaconMarker owns the node and calls build() and animate().

const FLAME := Color("#b8f2e6")
const GLOW := Color(0.55, 0.95, 0.85)
const RIM := Color("#e8fff8")
const DASHES := 40
const DASH_SPACING := 1.6
const DASH_SPEED := 1.4
const MOTES := 4


# Builds the beacon's parts into `root` and returns them for animate().
static func build(root: Node3D) -> Dictionary:
	var stone := StyleKit.mat(StyleKit.hexc("#8d95a1"), 0, 0.6)
	var wood := StyleKit.mat(StyleKit.hexc("#7d5438"))
	var flame := StyleKit.mat(FLAME, 0, 0.0, 1.8)
	var cap := StyleKit.mat(StyleKit.hexc("#3f5a52"))
	StyleKit.cyl(root, 0.62, 0.28, Vector3(0, 0.14, 0), stone, Vector3.ZERO, 0.5, 6)
	StyleKit.cyl(root, 0.14, 1.9, Vector3(0, 1.2, 0), wood, Vector3.ZERO, 0.09, 6)
	StyleKit.box(root, Vector3(0.62, 0.7, 0.62), Vector3(0, 2.5, 0), flame)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			StyleKit.box(root, Vector3(0.08, 0.76, 0.08), Vector3(sx * 0.32, 2.5, sz * 0.32), wood)
	StyleKit.prism(root, Vector3(0.9, 0.5, 0.9), Vector3(0, 3.1, 0), cap)
	StyleKit.sph(root, 0.1, Vector3(0, 3.42, 0), flame, Vector3.ONE, 6, false)
	var beam := StyleKit.cyl(root, 0.09, 7.0, Vector3(0, 6.9, 0), flame, Vector3.ZERO, -1.0, 6, false)
	var glow_mat := StyleKit.glow_mat(GLOW, 0.8)
	StyleKit.glow_plane(root, glow_mat, 6.0, Vector3(0, 0.05, 0))
	var ring_mat := StyleCues.ring_material(GLOW, RIM, 0.35, 0.8)
	var ring := MeshInstance3D.new()
	ring.mesh = StyleCues.ring_mesh()
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.07, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var motes: Array[MeshInstance3D] = []
	for k: int in range(MOTES):
		motes.append(StyleKit.sph(root, 0.1, Vector3(0, 2.5, 0), flame, Vector3.ONE, 6, false))
	return {"beam": beam, "ring": ring, "ring_mat": ring_mat, "motes": motes}


# The pooled dashes of the pull line, parented to `root` (they are positioned in the parent's space, see place_dashes).
static func build_dashes(root: Node3D) -> Array[MeshInstance3D]:
	var dash_m := StyleKit.mat(FLAME, 0, 0.0, 1.8)
	var ink_m := StyleKit.mat(StyleKit.hexc("#3a2a20"))
	var out: Array[MeshInstance3D] = []
	for k: int in range(DASHES):
		# Graphics checkpoint 4: bigger, with an ink edge under each dash so it shows on any ground.
		var d := StyleKit.box(root, Vector3(1.0, 0.1, 0.32), Vector3.ZERO, dash_m, Vector3.ZERO, false)
		StyleKit.box(d, Vector3(1.28, 0.06, 0.6), Vector3(0, -0.02, 0), ink_m, Vector3.ZERO, false)
		d.visible = false
		out.append(d)
	return out


# Moves the beacon's own cues at play time `t`: the ring breathes, the beam shimmers and the motes circle the lantern.
static func animate(parts: Dictionary, t: float) -> void:
	var ring: MeshInstance3D = parts["ring"]
	var r := 1.35 + 0.25 * sin(t * 3.0)
	ring.scale = Vector3(r, 1.0, r)
	var beam: MeshInstance3D = parts["beam"]
	var w := 1.0 + 0.3 * sin(t * 5.0)
	beam.scale = Vector3(w, 1.0, w)
	var motes: Array[MeshInstance3D] = parts["motes"]
	for k: int in range(motes.size()):
		var a := t * 1.3 + TAU * float(k) / float(motes.size())
		motes[k].position = Vector3(cos(a) * 0.75, 2.4 + 0.25 * sin(t * 2.0 + float(k)), sin(a) * 0.75)


# Lays the dashes along the line from `from` to `to` (world positions, the pool's parent sitting at `origin`), marching
# toward `to` at DASH_SPEED. Dashes beyond the line are hidden; the first and last fade by shrinking.
static func place_dashes(dashes: Array[MeshInstance3D], origin: Vector3, from: Vector3, to: Vector3, t: float) -> void:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := flat.length()
	var count := mini(DASHES, int(length / DASH_SPACING))
	if length < 0.01 or count < 1:
		for d: MeshInstance3D in dashes:
			d.visible = false
		return
	var spacing := length / float(count)
	var dir := flat / length
	var yaw := atan2(-dir.z, dir.x)
	var shift := fposmod(t * DASH_SPEED, spacing)
	for k: int in range(dashes.size()):
		var d := dashes[k]
		var along := shift + spacing * float(k)
		d.visible = k < count and along < length
		if not d.visible:
			continue
		var at := from + dir * along - origin
		d.position = Vector3(at.x, 0.12, at.z)
		d.rotation = Vector3(0.0, yaw, 0.0)
		var edge := minf(along, length - along) / 2.0
		d.scale = Vector3.ONE * clampf(edge, 0.15, 1.0)
