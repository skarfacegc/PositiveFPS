class_name StyleWalk
extends RefCounted

# Graphics checkpoint 4: puts a Gait pose on a styled body. The body's parts come from StylePeople (`rig`, `legs`,
# `leg_base`, `arms`, `arm_sides`, `arm_base`). The bodies face +z, so a forward lean or swing is a positive/negative
# rotation about x as noted below. A leg is drawn up while it swings forward by shortening it, which lifts the foot.

# How much of the standing pose's splay and arm angle is kept while walking (the pose is relaxed; a walk is not).
const SPLAY_KEPT := 0.25


# Writes `g`'s pose onto the body described by `parts`.
static func apply(g: Gait, parts: Dictionary) -> void:
	var rig: Node3D = parts.get("rig")
	if rig == null:
		return
	var k: float = parts.get("rig_scale", 1.0)
	rig.position = Vector3(g.sway * k, g.bob * k, 0.0)
	rig.rotation = Vector3(g.pitch, g.yaw, g.roll)
	var rest := lerpf(1.0, SPLAY_KEPT, g.move)
	var legs: Array[Node3D] = parts["legs"]
	var leg_base: Array[Vector3] = parts["leg_base"]
	for i: int in range(legs.size()):
		var b := leg_base[i]
		legs[i].rotation = Vector3(b.x * rest - g.swing[i] * g.dir_fwd, b.y, b.z * rest - g.swing[i] * g.dir_side)
		legs[i].scale = Vector3(1.0, 1.0 - g.lift[i], 1.0)
	var arms: Array[Node3D] = parts["arms"]
	var sides: Array[int] = parts["arm_sides"]
	var arm_base: Array[Vector3] = parts["arm_base"]
	for j: int in range(arms.size()):
		var ab := arm_base[j]
		var swing_x := g.arm[sides[j]] * g.dir_fwd
		arms[j].rotation = Vector3(ab.x - swing_x, ab.y, ab.z)
