extends GdUnitTestSuite

# Round 8 visuals and camera: paint projectile size, the paint splat and splash radii, the crisp bloom outline, and
# the closer top-down camera (its range ring must fit on a 1280x720 screen). Gameplay values are checked against
# Config, so a tuning change keeps the drawing and the rule in step.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# The cylinder radius of the first impact node of `kind` in the level, or -1 if there is none.
func _impact_radius(td: TopDownMain, kind: String) -> float:
	for node: Node in td.get_tree().get_nodes_in_group(JoyProjectile.IMPACT_GROUP):
		if node.get_meta("impact_kind") == kind and node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh is CylinderMesh:
				return (mesh as CylinderMesh).top_radius
	return -1.0


func test_paint_projectile_is_drawn_at_the_configured_size() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var pr := JoyProjectile.new()
	pr.element = Config.Element.ART
	td.add_child(pr)
	# Scale is set in _ready, so it is already in place once the node is in the level.
	var expected := Config.TD_PROJECTILE_VISUAL_SCALE * Config.TD_ELEMENT_VISUAL_SCALE[Config.Element.ART]
	assert_float(pr.scale.x).is_equal_approx(expected, 0.001)
	assert_float(Config.TD_ELEMENT_VISUAL_SCALE[Config.Element.ART]).is_equal_approx(1.3, 0.001)


func test_paint_splat_radius_matches_the_config() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var pr := JoyProjectile.new()
	pr.element = Config.Element.ART
	td.add_child(pr)
	pr._spawn_splat(Vector3(-30, 0, 10))
	assert_float(_impact_radius(td, "splat")).is_equal_approx(Config.TD_SPLAT_RADIUS, 0.001)


func test_paint_splash_reaches_a_person_at_one_metre_but_not_at_one_point_three() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var at := Vector3(-30, 0, 10)
	var pr := JoyProjectile.new()
	pr.element = Config.Element.ART
	pr.people = td.people
	pr.shooter_pos = at
	td.add_child(pr)
	var near: Person = td.people[0]
	TopDownTestUtil.place(near, at + Vector3(1.0, 0, 0), 0, 0.0)
	var far: Person = td.people[1]
	TopDownTestUtil.place(far, at + Vector3(1.3, 0, 0), 0, 0.0)

	pr._splash(at, null)
	assert_float(near.joy).is_greater(0.0)
	assert_float(far.joy).is_equal(0.0)


func test_paint_splash_ring_is_drawn_at_exactly_the_splash_radius() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var pr := JoyProjectile.new()
	pr.element = Config.Element.ART
	td.add_child(pr)
	pr._spawn_splash_ring(Vector3(-30, 0, 10))
	assert_float(_impact_radius(td, "splash")).is_equal_approx(Config.TD_PAINT_SPLASH_RADIUS, 0.001)


func test_bloom_has_no_outline_and_a_faint_fill() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var bloom := Bloom.new()
	td.add_child(bloom)
	bloom.global_position = Vector3(-30, 0, 10)

	# Round 10: no outline ring. The only disc is the fill, at the bloom's radius and at most TD_BLOOM_FILL_ALPHA opaque.
	var discs := 0
	var flowers := 0
	for child: Node in bloom.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is CylinderMesh:
			var mesh := (child as MeshInstance3D).mesh as CylinderMesh
			if is_equal_approx(mesh.top_radius, Config.TD_BLOOM_RADIUS):
				discs += 1
				var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
				assert_float(mat.albedo_color.a).is_less_equal(Config.TD_BLOOM_FILL_ALPHA + 0.001)
		elif child is Node3D and not (child is MeshInstance3D):
			flowers += 1
	assert_int(discs).is_equal(1)
	assert_int(flowers).is_equal(Config.TD_BLOOM_FLOWER_COUNT)
	assert_bool(Config.TD_BLOOM_FLOWER_COUNT <= 4).is_true()
	assert_int(Config.TD_BLOOM_PETALS).is_less_equal(4)


func test_bloom_fades_as_one_piece_without_shrinking() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var bloom := Bloom.new()
	td.add_child(bloom)
	bloom._set_fade(0.5)
	assert_vector(bloom.scale).is_equal(Vector3.ONE)
	for child: Node in bloom.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			assert_float(mat.albedo_color.a).is_less(1.0)
	bloom._set_fade(0.0)
	for child: Node in bloom.get_children():
		if child is MeshInstance3D:
			var mat := (child as MeshInstance3D).material_override as StandardMaterial3D
			assert_float(mat.albedo_color.a).is_equal_approx(0.0, 0.001)


func test_camera_range_ring_fits_on_a_1280_by_720_screen() -> void:
	# The menu tests show the gdUnit CLI shrinks the window, so give it the project's real size first.
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rect := td.get_viewport().get_visible_rect()
	assert_vector(rect.size).is_equal(Vector2(1280, 720))

	# Round 10: the whole auto-range ring (16 points) is on screen, from the orthographic camera.
	var centre := td.player.global_position
	var r := Config.TD_AUTO_RANGE
	for i: int in range(16):
		var a := TAU * float(i) / 16.0
		var spot := centre + Vector3(cos(a) * r, 0, sin(a) * r)
		assert_bool(td.camera.is_position_behind(spot)).is_false()
		assert_bool(rect.has_point(td.camera.unproject_position(spot))).is_true()
