class_name LandmarkLookStyled
extends LandmarkLook

# The styled landmark hold ring: a glowing beacon, a gold ring and a dithered gold glow that grows with the hold
# progress. (The landmark building itself is a BuildingLookStyled.) The label stays the placeholder text.

var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _label: Label3D


func is_styled() -> bool:
	return true


func sync() -> void:
	if _glow == null:
		return
	var frac := subject.progress()
	_glow.visible = frac > 0.0
	_glow.scale = Vector3(maxf(frac, 0.01), 1.0, maxf(frac, 0.01)) * (RING_INNER / 2.5)
	var shown := subject.beautified or subject.hold > 0.0
	_label.text = "Landmark held %d%%" % roundi(frac * 100.0) if shown else "Landmark"


func _build() -> void:
	var gold := StyleKit.mat(StyleKit.hexc("#ffe08a"), 0, 0.0, 1.4)
	StyleKit.cyl(
		self, 0.15, 9.0, Vector3(0, Config.BORDER_LANDMARK_SIZE.y + 4.5, 0), gold, Vector3.ZERO, -1.0, 6, false
	)
	var ring := StyleKit.torus(self, RING_INNER, RING_OUTER, Vector3(0, 0.08, 0), gold)
	ring.scale = Vector3(1.0, 0.3, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_mat = StyleKit.glow_mat(Color(1.0, 0.82, 0.38), 0.9)
	_glow = StyleKit.glow_plane(self, _glow_mat, 5.0, Vector3(0, 0.06, 0))
	_label = Label3D.new()
	_label.position = Vector3(0, Config.BORDER_LANDMARK_SIZE.y + 9.6, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.012
	_label.no_depth_test = true
	add_child(_label)
	Looks.note_placeholder(_label, "landmark label")
