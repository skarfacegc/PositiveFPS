extends GdUnitTestSuite

# Snag round: shader instances. The styled look's toon shader declares `instance uniform`s, and the renderer gives every
# mesh that uses it a slice of the global shader-variable buffer: 16 vec4 (256 bytes) per instance, hidden or not. With
# the default 65536-vec4 buffer that is 4096 meshes, and a real styled game (more than 2800 at the start, then every
# block's whimsical version, built the first time it shows) went over: the engine logged "Too many instances using
# shader instance variables" and then "instance_buffer_pos.has(p_instance)". Headless has no renderer to log it, so this
# counts the live users (the thing that overflowed) and checks them against what the project's buffer can hold.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# The number of nodes under `root` that the renderer counts as instance-uniform users.
static func count_users(root: Node) -> int:
	var n := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is GeometryInstance3D and uses_instance_uniforms(node as GeometryInstance3D):
			n += 1
	return n


static func uses_instance_uniforms(g: GeometryInstance3D) -> bool:
	var mats: Array[Material] = [g.material_override, g.material_overlay]
	if g is MeshInstance3D and (g as MeshInstance3D).mesh != null:
		var mi := g as MeshInstance3D
		for s: int in range(mi.mesh.get_surface_count()):
			mats.append(mi.get_active_material(s))
	for m: Material in mats:
		if m is ShaderMaterial and (m as ShaderMaterial).shader != null:
			if (m as ShaderMaterial).shader.code.contains("instance uniform"):
				return true
	return false


# How many instances the project's buffer holds (the engine reserves 16 vec4 per instance).
static func capacity() -> int:
	var buffer: int = ProjectSettings.get_setting("rendering/limits/global_shader_variables/buffer_size", 65536)
	return buffer / Config.SNAG_INSTANCE_VEC4S


func _styled_level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(60)
	return {"td": td, "runner": runner}


func test_the_buffer_holds_the_worst_case_of_styled_instance_users_with_room_to_spare() -> void:
	var s: Dictionary = await _styled_level()
	var td: TopDownMain = s["td"]
	var start := count_users(td)
	assert_int(start).is_greater(0)
	# The worst case: every block has built its whimsical version too.
	for node: Node in td.find_children("*", "BuildingLookStyled", true, false):
		var b := node as BuildingLookStyled
		if b.whimsical == null:
			b.whimsical = b._make_version(false)
	var worst := count_users(td)
	assert_int(worst).is_greater(start)
	# Room for the effects, pools and people a game adds: the worst case may use at most half of the buffer.
	assert_int(worst * 2).is_less(capacity())


func test_switching_looks_does_not_leak_instance_users() -> void:
	var s: Dictionary = await _styled_level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var first := count_users(td)
	for i: int in range(3):
		td.set_look(Looks.Mode.PLACEHOLDER)
		await runner.simulate_frames(5)
		td.set_look(Looks.Mode.STYLED)
		await runner.simulate_frames(30)
	assert_int(count_users(td)).is_less_equal(first + 10)
