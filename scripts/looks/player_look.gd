class_name PlayerLook
extends Node3D

# The look of the player. The rules (topdown_player.gd) own movement, aiming, targeting and firing; this node draws the
# body and the ring under the feet from the player's public state (its target). The base class holds the joy burst ring
# that expands from the feet, which both looks share. A subclass draws the body: _build_body, sync and is_styled.

var subject: TopDownPlayer


func setup(player: TopDownPlayer) -> void:
	subject = player
	_build_body()


# True for the styled look.
func is_styled() -> bool:
	return false


# Reads the player's state (the target's element sets the ring colour). Called every physics tick.
func sync() -> void:
	pass


# The joy burst: a flat ring that expands from the player's feet and fades. Shared by both looks.
func play_burst(radius: float, duration: float) -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = 1.0
	mesh.height = 0.05
	ring.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1, 0.9, 0.5, 0.6)
	ring.material_override = mat
	ring.scale = Vector3(0.1, 1.0, 0.1)
	subject.get_parent().add_child(ring)
	ring.global_position = Vector3(subject.global_position.x, 0.03, subject.global_position.z)
	Looks.note_placeholder(ring, "burst ring")

	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(radius, 1.0, radius), duration)
	t.tween_property(mat, "albedo_color:a", 0.0, duration)
	t.chain().tween_callback(ring.queue_free)


# Builds the body and the ground marker. Overridden by each look.
func _build_body() -> void:
	pass
