class_name PlayerLookStyled
extends PlayerLook

# The styled player (see StylePeople.build_player): wide-brim felt hat with a teal band and a glowing feather, saffron
# coat, teal scarf, satchel with three glowing tubes, a gold double ring and a dithered glow on the ground. The outer
# ring takes the colour of the target's element (cream with no target), as the placeholder ring does.

var _ring: MeshInstance3D
var _last_affinity: int = -2


func is_styled() -> bool:
	return true


func sync() -> void:
	var aff := -1 if subject.target == null else subject.target.affinity
	if aff == _last_affinity:
		return
	_last_affinity = aff
	var col := Config.TD_NO_TARGET_COLOR if aff < 0 else Config.ELEMENT_COLORS[aff]
	_ring.material_override = StyleKit.mat(col, 0, 0.0, 0.8)


func _build_body() -> void:
	var model := Node3D.new()
	# The model faces +z; the player faces -z.
	model.rotation.y = PI
	add_child(model)
	var parts: Dictionary = {}
	StylePeople.build_player(model, parts)
	_ring = parts["ring"]
	sync()
