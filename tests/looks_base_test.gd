extends GdUnitTestSuite

# The look base classes (their default methods do nothing), the building models' other variants, the pixel view's
# resize, and a few player and person edge cases that the move of the visuals into looks left as small gaps.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func test_base_looks_have_do_nothing_defaults() -> void:
	var person := PersonLook.new()
	person._build_body()
	person._sync_body()
	person._set_glow(0.5)
	person.play_bounce()
	person.play_slump(0.8, 0.2)
	person.sync()
	assert_bool(person.is_styled()).is_false()
	person.free()
	var player := PlayerLook.new()
	player._build_body()
	player.sync()
	assert_bool(player.is_styled()).is_false()
	player.free()
	var building := BuildingLook.new()
	building.sync()
	building.set_post(true)
	building._build()
	assert_bool(building.is_styled()).is_false()
	building.free()
	var landmark := LandmarkLook.new()
	landmark.sync()
	landmark._build()
	landmark.free()
	var ground := GroundLook.new()
	var colours: Array[Color] = []
	var weights: Array[float] = []
	ground.refresh(colours, weights)
	ground._build()
	ground.free()
	var border := BorderLook.new()
	border.refresh()
	border._build()
	border.free()
	var plaza := PlazaLook.new()
	plaza._build()
	plaza.free()
	var map := MinimapLook.new()
	assert_bool(map.is_styled()).is_false()
	assert_bool(map.ground_colour(null, Vector2.ZERO, 0, 0).is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.building_colour(true).is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.line_colour(true).is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.member_colour().is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.dark_colour().is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.landmark_colour().is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.player_colour().is_equal_approx(Color.WHITE)).is_true()
	assert_bool(map.view_colour().is_equal_approx(Color.WHITE)).is_true()
	assert_float(map.halo_colour("dark").a).is_equal(0.0)
	map.draw_back(null)
	map.draw_frame(null)


func test_the_styled_minimap_shades_painted_ground_warm() -> void:
	var ground: PaintedGround = auto_free(PaintedGround.new())
	add_child(ground)
	ground.setup(10)
	ground._weights[0] = 0.6
	ground._weights[1] = 0.9
	var look := MinimapLookStyled.new()
	var spot_a := Vector3(-4.5, 0.0, -4.5)
	var spot_b := Vector3(-4.5, 0.0, -3.5)
	var a := look.ground_colour(ground, Vector2(spot_a.x, spot_a.z), 1, 1)
	var b := look.ground_colour(ground, Vector2(spot_b.x, spot_b.z), 1, 1)
	assert_bool(a.is_equal_approx(MinimapLookStyled.WARM_A.darkened(0.08))).is_true()
	assert_bool(b.is_equal_approx(MinimapLookStyled.WARM_A)).is_true()


func test_the_other_building_models_build() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var root: Node3D = auto_free(Node3D.new())
	add_child(root)
	# A full-size, non-kiosk block with a smokestack, a tank and a pennant, in both versions.
	var opts := {"stack": true, "tank": true, "nwin": 2, "landmark": true, "tankside": -1.0}
	StyleBuildings.build_industrial(root, 7.0, 5.0, 4.0, opts)
	StyleBuildings.build_whimsical(root, 7.0, 5.0, 4.0, opts)
	assert_int(root.get_child_count()).is_greater(100)


func test_the_pixel_view_follows_the_window_shape_and_ignores_a_second_apply() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	var td := runner.scene() as TopDownMain
	await runner.simulate_frames(3)
	var view := td.pipeline._viewport
	view.size = Vector2i(10, 10)
	await runner.simulate_frames(2)
	assert_int(view.size.y).is_equal(ViewPipeline.VIEW_HEIGHT)
	td.pipeline.apply(td)
	assert_bool(td.pipeline.styled).is_true()
	td.set_look(Looks.Mode.PLACEHOLDER)
	assert_vector(Vector2(td.pipeline.view_size())).is_equal(td.get_viewport().get_visible_rect().size)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_player_edge_cases() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	var td := runner.scene() as TopDownMain
	await runner.simulate_frames(3)
	var player := td.player
	# Inactive: key presses are ignored.
	player.active = false
	runner.simulate_key_pressed(KEY_F2)
	await runner.simulate_frames(2)
	player.active = true
	# No camera: no aim point, so no turning and no lock.
	var camera := player.camera
	player.camera = null
	player._update_aim()
	player._has_aim = false
	player._click_lock()
	player._face_aim()
	player.camera = camera
	# Aiming at their own feet does not turn them.
	player._has_aim = true
	player._aim_point = player.global_position
	var before := player.rotation.y
	player._face_aim()
	assert_float(player.rotation.y).is_equal(before)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_an_unrescued_person_with_enough_joy_is_rescued_on_the_next_tick() -> void:
	var p: Person = auto_free(Person.new())
	add_child(p)
	p.joy = p.joy_needed()
	p._since_hit = 0.0
	p.tick(1.0 / 60.0)
	assert_bool(p.is_rescued).is_true()
