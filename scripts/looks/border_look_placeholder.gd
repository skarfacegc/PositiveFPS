class_name BorderLookPlaceholder
extends BorderLook

# The placeholder border: intact stretches are gold lines. A gap is not drawn as a line: it glows, a coral band that
# fades to nothing at its edges and breathes with the gap pulse.

var _line_mesh: ImmediateMesh
var _line_mat: StandardMaterial3D
var _glow_mesh: ImmediateMesh
var _glow_mat: StandardMaterial3D


func refresh() -> void:
	_line_mesh.clear_surfaces()
	var poly := subject.polygon
	var n := poly.size()
	if not subject.active or n < 3:
		_glow_mesh.clear_surfaces()
		return
	# Round 12a: a dim player makes the line flicker (see Border.flicker).
	var flick := subject.flicker()
	var intact := 0
	for j: int in range(n):
		if not subject.segment_is_gap(j):
			intact += 1
	if intact > 0:
		_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _line_mat)
		for j: int in range(n):
			if subject.segment_is_gap(j):
				continue
			var colour := subject.segment_colour(j)
			colour.a = flick
			var a := poly[j]
			var b := poly[(j + 1) % n]
			_line_mesh.surface_set_color(colour)
			_line_mesh.surface_add_vertex(Vector3(a.x, Config.BORDER_LINE_HEIGHT, a.y))
			_line_mesh.surface_set_color(colour)
			_line_mesh.surface_add_vertex(Vector3(b.x, Config.BORDER_LINE_HEIGHT, b.y))
		_line_mesh.surface_end()
	_draw_gap_glow()


func _build() -> void:
	_line_mat = StandardMaterial3D.new()
	_line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_line_mat.vertex_color_use_as_albedo = true
	_line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_line_mesh = ImmediateMesh.new()
	var line_node := MeshInstance3D.new()
	line_node.mesh = _line_mesh
	add_child(line_node)
	# Round 10: the gap glow (a soft coral band over each gap), drawn on its own mesh.
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_glow_mesh = ImmediateMesh.new()
	var glow_node := MeshInstance3D.new()
	glow_node.mesh = _glow_mesh
	add_child(glow_node)


# Each gap is a coral band, BORDER_GAP_GLOW_WIDTH metres wide: strongest along the stretch and fading to nothing at
# its two edges. Its alpha follows the gap pulse, so the whole glow breathes softly.
func _draw_gap_glow() -> void:
	_glow_mesh.clear_surfaces()
	var poly := subject.polygon
	var n := poly.size()
	if not subject.active or n < 3 or subject.gap_count() == 0:
		return
	var alpha := lerpf(Config.BORDER_GAP_GLOW_ALPHA_MIN, Config.BORDER_GAP_GLOW_ALPHA_MAX, subject.pulse())
	alpha *= subject.flicker()
	var centre_col := Color(Config.BORDER_GAP_COLOUR.r, Config.BORDER_GAP_COLOUR.g, Config.BORDER_GAP_COLOUR.b, alpha)
	var edge_col := Color(Config.BORDER_GAP_COLOUR.r, Config.BORDER_GAP_COLOUR.g, Config.BORDER_GAP_COLOUR.b, 0.0)
	var half := Config.BORDER_GAP_GLOW_WIDTH * 0.5
	_glow_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _glow_mat)
	for j: int in range(n):
		if not subject.segment_is_gap(j):
			continue
		var a := poly[j]
		var b := poly[(j + 1) % n]
		var dir := b - a
		if dir.length() < 0.0001:
			continue
		var nrm := Vector2(-dir.y, dir.x).normalized()
		for side: float in [-1.0, 1.0]:
			var off := nrm * half * side
			_glow_vertex(a, centre_col)
			_glow_vertex(b, centre_col)
			_glow_vertex(b + off, edge_col)
			_glow_vertex(a, centre_col)
			_glow_vertex(b + off, edge_col)
			_glow_vertex(a + off, edge_col)
	_glow_mesh.surface_end()


func _glow_vertex(p2: Vector2, col: Color) -> void:
	_glow_mesh.surface_set_color(col)
	_glow_mesh.surface_add_vertex(Vector3(p2.x, Config.BORDER_LINE_HEIGHT, p2.y))
