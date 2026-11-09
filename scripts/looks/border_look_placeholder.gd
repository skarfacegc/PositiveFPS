class_name BorderLookPlaceholder
extends BorderLook

# The placeholder border (round 25): one flat ribbon through the members. Gold when healthy, amber when strained,
# thin and coral near breaking; a gap is a real break in it. A dimmed person pressing on the line bows the ribbon
# inward. A dim player makes it flicker (Border.flicker). The ribbon is rebuilt every EDGE_RIBBON_REBUILD_FRAMES.

var _mesh: ArrayMesh
var _mat: StandardMaterial3D
var _node: MeshInstance3D
var _last_frame: int = -100000


func refresh() -> void:
	var live := subject.active and subject.polygon.size() >= 3
	_node.visible = live
	if not live:
		_mesh.clear_surfaces()
		strips = []
		_last_frame = -100000
		return
	var now := Engine.get_process_frames()
	if now - _last_frame >= BorderConfig.EDGE_RIBBON_REBUILD_FRAMES:
		_last_frame = now
		_rebuild_strips()
		_mesh.clear_surfaces()
		var arrays := EdgeRibbon.mesh_arrays(strips, BorderConfig.BORDER_LINE_HEIGHT, 1.0)
		if not arrays.is_empty():
			_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	# Round 12a: a dim player makes the line flicker (see Border.flicker).
	_mat.albedo_color = Color(1.0, 1.0, 1.0, subject.flicker())


func _build() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true  # The ribbon colours are written as plain sRGB colours.
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh = ArrayMesh.new()
	_node = MeshInstance3D.new()
	_node.mesh = _mesh
	_node.material_override = _mat
	_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_node)
