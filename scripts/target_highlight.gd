class_name TargetHighlight
extends MeshInstance3D

# The ring under the target's feet: a flat warm disc (placeholder) or the styled ring (StyleTarget). Hidden while there
# is no valid target. TopDownMain builds it with `TargetHighlight.attach(self)` and keeps it as `highlight`.

var _mat: StandardMaterial3D
var _pulse_time := 0.0
var _main: TopDownMain


static func attach(main: TopDownMain) -> TargetHighlight:
	var h := TargetHighlight.new()
	h._main = main
	h.visible = false
	main.add_child(h)
	h.apply_look()
	return h


# Checkpoint 6: the highlight's pieces for the current look: the warm disc (placeholder) or the flat ring with an
# element-tinted disc (styled, see StyleTarget). Called at the start and when the look changes.
func apply_look() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	scale = Vector3.ONE
	if Looks.is_styled():
		StyleTarget.build(self)
		return
	var disc := CylinderMesh.new()
	disc.top_radius = PlayerConfig.TD_HIGHLIGHT_RADIUS
	disc.bottom_radius = PlayerConfig.TD_HIGHLIGHT_RADIUS
	disc.height = 0.02
	mesh = disc
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = PlayerConfig.TD_HIGHLIGHT_COLOR
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


# Moves the highlight to the target's feet and pulses it slowly. Hidden while there is no valid target.
func sync(delta: float) -> void:
	_pulse_time += delta
	if not is_instance_valid(_main.player.target):
		visible = false
		return
	var t: Person = _main.player.target
	visible = true
	global_position = Vector3(t.global_position.x, 0.03, t.global_position.z)
	var s := 1.0 + PlayerConfig.TD_HIGHLIGHT_PULSE * sin(_pulse_time * PlayerConfig.TD_HIGHLIGHT_PULSE_SPEED)
	if Looks.is_styled():
		StyleTarget.sync(self, Config.ELEMENT_COLORS[t.affinity], s)
		return
	scale = Vector3(s, 1.0, s)
