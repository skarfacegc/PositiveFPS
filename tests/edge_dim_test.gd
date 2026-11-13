extends GdUnitTestSuite

# Round 25: dimmed people still outside the border are drawn at lower contrast (EdgeDim), so the members and the line
# stand out from the crowd pressing on them. Only the look changes.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _ring_level(count: int, r: float) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	TopDownTestUtil.trim_crowd(td, count + 8)  # Slowest tests (#88): the parked crowd beyond the people used is dropped.
	td.border.buildings.clear()
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0
	await TopDownTestUtil.settle_on_line(runner, td)  # Up to 600 frames; stops once the members are on the line.
	return {"runner": runner, "td": td}


func _distance_from_ground(col: Color) -> float:
	return (
		absf(col.r - BorderConfig.EDGE_OUT_GROUND.r)
		+ absf(col.g - BorderConfig.EDGE_OUT_GROUND.g)
		+ absf(col.b - BorderConfig.EDGE_OUT_GROUND.b)
	)


func test_only_dimmed_people_outside_an_active_border_are_faded() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	TopDownTestUtil.open_dim_gate(td)
	var outside: Person = td.people[20]
	var inside: Person = td.people[21]
	TopDownTestUtil.place(outside, Vector3(14.0, 0.0, 0.0), 1, 0.95)
	TopDownTestUtil.place(inside, Vector3(0.5, 0.0, 0.5), 1, 0.95)
	assert_bool(EdgeDim.is_faded(td.border, outside)).is_true()
	assert_bool(EdgeDim.is_faded(td.border, inside)).is_false()
	assert_bool(EdgeDim.is_faded(td.border, td.border.members[0])).is_false()
	# A person who is not dimmed is never faded, and nobody is when there is no border.
	var light: Person = td.people[22]
	TopDownTestUtil.place(light, Vector3(14.0, 0.0, 3.0), 1, 0.1)
	assert_bool(EdgeDim.is_faded(td.border, light)).is_false()
	var bare: Border = auto_free(Border.new())
	assert_bool(EdgeDim.is_faded(bare, outside)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fade_comes_in_over_its_seconds_and_goes_when_they_cross_the_line() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	TopDownTestUtil.open_dim_gate(td)
	var outside: Person = td.people[20]
	TopDownTestUtil.place(outside, Vector3(14.0, 0.0, 0.0), 1, 0.95)
	var look := outside.look as PersonLookPlaceholder
	EdgeDim.update(td.border, td.people, BorderConfig.EDGE_OUT_FADE_SECONDS * 2.0)
	assert_float(look.outside_fade).is_equal(1.0)
	look.outside_fade = 0.0
	EdgeDim.update(td.border, td.people, BorderConfig.EDGE_OUT_FADE_SECONDS * 0.5)
	assert_float(look.outside_fade).is_equal_approx(0.5, 0.01)
	TopDownTestUtil.place(outside, Vector3(1.0, 0.0, 1.0), 1, 0.95)
	EdgeDim.update(td.border, td.people, BorderConfig.EDGE_OUT_FADE_SECONDS * 2.0)
	assert_float(look.outside_fade).is_equal(0.0)
	await runner.simulate_frames(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fade_moves_the_body_colour_toward_the_ground() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	TopDownTestUtil.open_dim_gate(td)
	var outside: Person = td.people[20]
	TopDownTestUtil.place(outside, Vector3(14.0, 0.0, 0.0), 1, 0.95)
	var look := outside.look as PersonLookPlaceholder
	look.outside_fade = 0.0
	look.sync()
	var plain := _distance_from_ground(look.body_mat.albedo_color)
	look.outside_fade = 1.0
	look.sync()
	assert_float(_distance_from_ground(look.body_mat.albedo_color)).is_less(plain)
	assert_bool(EdgeDim.faded(Color.WHITE, 0.0).is_equal_approx(Color.WHITE)).is_true()
	assert_bool(EdgeDim.faded(Color.WHITE, 2.0).is_equal_approx(EdgeDim.faded(Color.WHITE, 1.0))).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_person_with_no_look_is_skipped() -> void:
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	var p: Person = td.people[20]
	var look := p.look
	p.look = null
	EdgeDim.update(td.border, td.people, 1.0)
	p.look = look
	assert_object(p).is_not_null()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_look_tints_a_faded_dimmed_person_toward_the_ground() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var s: Dictionary = await _ring_level(16, 6.0)
	var td: TopDownMain = s["td"]
	TopDownTestUtil.open_dim_gate(td)
	var outside: Person = td.people[20]
	TopDownTestUtil.place(outside, Vector3(14.0, 0.0, 0.0), 1, 0.95)
	outside.tick(0.016)
	var look := outside.look as PersonLookStyled
	assert_int(look.shown_kind()).is_equal(PersonLook.Kind.DIMMED)
	look.outside_fade = 1.0
	look.sync()
	var mesh: MeshInstance3D = look._light_meshes[PersonLook.Kind.DIMMED][0]
	var packed: float = mesh.get_instance_shader_parameter("tint")
	assert_int(floori(packed)).is_equal(3)
	assert_float(packed - 3.0).is_greater(0.3)
	look.outside_fade = 0.0
	look.sync()
	assert_float(mesh.get_instance_shader_parameter("tint")).is_less(3.0)
	await TopDownTestUtil.leave_loaded_scene(td)
