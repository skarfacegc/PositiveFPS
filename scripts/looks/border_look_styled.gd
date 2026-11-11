class_name BorderLookStyled
extends BorderLook

# 0.4 (#58): the ribbon is the gates alone; a wall is a low hedge with small lamps (StyleHedge), so the two read apart.
# The styled border (round 25): one ribbon through the members, a solid core with a soft halo (shaders/style_ribbon
# .gdshader) and a few golden motes drifting over it. Gold when healthy, amber when strained, thin and coral near
# breaking; a gap is a real break; a dimmed person pressing on the line bows it inward (see EdgeRibbon). The columns
# and breach rings of checkpoint 5 are gone: EdgeMarkerFx marks the trouble spots. The geometry is rebuilt every
# EDGE_RIBBON_REBUILD_FRAMES frames.

const RIBBON_SHADER := "res://shaders/style_ribbon.gdshader"
const RIBBON_Y := 0.2
const MAX_MOTES := 400
const MOTE_HEIGHT := 0.18

var _ribbon: MeshInstance3D
var _ribbon_mat: ShaderMaterial
var _mesh: ArrayMesh
var _gold_motes: MultiMeshInstance3D
var _last_frame: int = -100000
var _hedges: Node3D
var _hedge_version: int = -1


func is_styled() -> bool:
	return true


func refresh() -> void:
	var live := subject.active and subject.polygon.size() >= 3
	# Round 12a: a dim player makes the border flicker; the ribbon drops out in the dark half of the flicker.
	var lit := subject.flicker() > 0.5 * (1.0 + SpiritConfig.DIM_FLICKER_MIN)
	_ribbon.visible = live and lit
	_gold_motes.visible = live and lit
	_hedges.visible = live
	if not live:
		strips = []
		gate_strips = []
		_last_frame = -100000
		return
	if subject.zone.version != _hedge_version:
		_rebuild_hedges()
	var now := Engine.get_process_frames()
	if now - _last_frame >= BorderConfig.EDGE_RIBBON_REBUILD_FRAMES:
		_last_frame = now
		_rebuild_strips()
		gate_strips = EdgeRibbon.build(subject, true)
		_mesh.clear_surfaces()
		var arrays := EdgeRibbon.mesh_arrays(gate_strips, RIBBON_Y, 1.0, BorderConfig.EDGE_RIBBON_HALO)
		if not arrays.is_empty():
			_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_place_motes(true)


func _build() -> void:
	_ribbon_mat = ShaderMaterial.new()
	_ribbon_mat.shader = load(RIBBON_SHADER)
	_ribbon_mat.render_priority = StyleConfig.L31_SOFT_PRIORITY + 1
	_mesh = ArrayMesh.new()
	_ribbon = MeshInstance3D.new()
	_ribbon.mesh = _mesh
	_ribbon.material_override = _ribbon_mat
	_ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ribbon)
	var sphere := SphereMesh.new()
	sphere.radius = 0.055
	sphere.height = 0.11
	sphere.radial_segments = 4
	sphere.rings = 2
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sphere
	mm.instance_count = MAX_MOTES
	mm.visible_instance_count = 0
	_gold_motes = MultiMeshInstance3D.new()
	_gold_motes.multimesh = mm
	_gold_motes.material_override = StyleKit.mat(StyleKit.hexc("#ffe28a"), 0, 0.0, 1.2)
	_gold_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_gold_motes)
	_hedges = Node3D.new()
	_hedges.name = "Hedges"
	add_child(_hedges)


# 0.4 (#58): the walls as hedges. Rebuilt whenever the zone changes (a take or a loss), not every frame.
func _rebuild_hedges() -> void:
	_hedge_version = subject.zone.version
	for child: Node in _hedges.get_children():
		_hedges.remove_child(child)
		child.queue_free()
	StyleHedge.build(_hedges, StyleHedge.plan(subject.zone.runs))


# Golden motes over the healthy part of the ribbon (a hash of the point picks each one's offset, so they stay put
# between rebuilds). Strained points get none: the ribbon's colour is the signal there.
func _place_motes(gates_only: bool = false) -> void:
	var mm := _gold_motes.multimesh
	var count := 0
	var k := 0
	var list: Array[EdgeStrip] = gate_strips if gates_only else strips
	for s: EdgeStrip in list:
		for i: int in range(s.size()):
			k += 1
			if count >= MAX_MOTES:
				break
			if s.strain[i] > 0.35 or _hash(k) < 0.45:
				continue
			var off := Vector2(_hash(k + 31) - 0.5, _hash(k + 57) - 0.5) * 0.9
			var at := s.pts[i] + off
			var lift := MOTE_HEIGHT + _hash(k + 7919) * 1.1
			mm.set_instance_transform(count, Transform3D(Basis(), Vector3(at.x, lift, at.y)))
			count += 1
	mm.visible_instance_count = count


static func _hash(k: int) -> float:
	return fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)
