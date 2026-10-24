extends GdUnitTestSuite

# The two looks (placeholder and styled, see scripts/looks). Tests run in the placeholder look by default. These tests
# switch to the styled look on purpose and always switch back. Headless Godot uses a dummy renderer, so shaders are not
# compiled and nothing is drawn here; what is checked is the wiring: which look each object gets, that the styled looks
# build and run, that F4 swaps looks without touching the game state, and that mouse aiming still works when the 3D view
# is drawn in a small pixel viewport (the real rendering is checked by tools/checkpoint_shots.py).


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _start(styled: bool = false) -> Dictionary:
	Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(30)
	return {"runner": runner, "td": runner.scene()}


# Rescues the first `count` people on a ring of radius 4 round (12, -12), and lets the border form.
func _rescue_ring(runner: GdUnitSceneRunner, td: TopDownMain, count: int) -> void:
	TopDownTestUtil.send_everyone_away(td)
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p := td.people[i]
		TopDownTestUtil.place(p, Vector3(12.0 + cos(a) * 4.0, 0.0, -12.0 + sin(a) * 4.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	await runner.simulate_frames(240)


func test_the_switch_names_the_look_and_flips() -> void:
	assert_int(Looks.mode).is_equal(Looks.Mode.PLACEHOLDER)
	assert_str(Looks.mode_name()).is_equal("Placeholder")
	assert_int(Looks.placeholder_fallback_count()).is_equal(0)
	assert_str(Looks.debug_line()).is_equal("Look: Placeholder")
	assert_int(Looks.toggle()).is_equal(Looks.Mode.STYLED)
	assert_str(Looks.mode_name()).is_equal("Styled")
	assert_str(Looks.debug_line()).starts_with("Look: Styled (")
	assert_int(Looks.toggle()).is_equal(Looks.Mode.PLACEHOLDER)


func _styled_kinds() -> Array[bool]:
	var nodes: Array[Node] = [
		Looks.person_look(),
		Looks.player_look(),
		Looks.building_look(),
		Looks.landmark_look(),
		Looks.ground_look(),
		Looks.border_look(),
		Looks.plaza_look()
	]
	var out: Array[bool] = []
	for n: Node in nodes:
		out.append(n.call("is_styled"))
		n.free()
	out.append(Looks.minimap_look().is_styled())
	return out


func test_each_kind_gets_the_look_of_the_current_mode() -> void:
	for styled: bool in _styled_kinds():
		assert_bool(styled).is_false()
	Looks.set_mode(Looks.Mode.STYLED)
	for styled: bool in _styled_kinds():
		assert_bool(styled).is_true()


func test_the_placeholder_level_uses_placeholder_looks_and_the_normal_camera() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	assert_bool(td.people[0].look.is_styled()).is_false()
	assert_bool(td.player.look.is_styled()).is_false()
	assert_bool(td.pipeline.styled).is_false()
	assert_vector(td.pipeline.view_scale()).is_equal(Vector2.ONE)
	assert_bool(td.camera.get_parent() == td).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_level_loads_and_runs_frames() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 6)
	await runner.simulate_frames(120)
	assert_bool(td.people[0].look.is_styled()).is_true()
	assert_bool(td.player.look.is_styled()).is_true()
	assert_bool(td.border.look.is_styled()).is_true()
	assert_bool(td.minimap.look.is_styled()).is_true()
	assert_bool(td.landmark.look.is_styled()).is_true()
	assert_bool(td.ground.look.is_styled()).is_true()
	assert_bool(td.plaza_look.is_styled()).is_true()
	assert_bool(td.border.buildings[0].look.is_styled()).is_true()
	assert_bool(td.pipeline.styled).is_true()
	assert_bool(td.rescued_count >= 6).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pixel_view_is_small_and_the_camera_lives_in_it() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var size := td.pipeline.view_size()
	assert_int(size.y).is_equal(ViewPipeline.VIEW_HEIGHT)
	assert_int(size.x).is_equal(640)
	assert_vector(td.pipeline.view_scale()).is_equal_approx(Vector2(2.0, 2.0), Vector2(0.01, 0.01))
	assert_bool(td.camera.get_parent() is SubViewport).is_true()
	assert_float(td.camera.size).is_equal_approx(Config.TD_CAMERA_ORTHO_SIZE, 0.0001)
	var there := td.pipeline.window_to_view(Vector2(640.0, 360.0))
	assert_vector(there).is_equal_approx(Vector2(320.0, 180.0), Vector2(0.01, 0.01))
	assert_vector(td.pipeline.view_to_window(there)).is_equal_approx(Vector2(640.0, 360.0), Vector2(0.01, 0.01))
	await TopDownTestUtil.leave_loaded_scene(td)


func test_hover_aiming_and_lock_on_clicks_work_in_the_styled_look() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 1, 0.0)
	await runner.simulate_frames(2)
	# Hover (the default mode): the mouse over the person picks them as the target.
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(4)
	assert_object(td.player.target).is_same(target)
	var aim := td.player._aim_point
	assert_float(Vector2(aim.x, aim.z).distance_to(Vector2(0.0, -8.0))).is_less(0.3)
	# Lock-on: a click on the floor under them locks on; a click on empty floor clears it.
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	assert_object(td.player.target).is_same(target)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_f4_swaps_the_look_in_place_and_keeps_the_game_state() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 6)
	td.running = false
	var before := _state(td)
	assert_bool(td.people[0].look.is_styled()).is_false()
	runner.simulate_key_pressed(KEY_F4)
	await runner.simulate_frames(3)
	assert_int(Looks.mode).is_equal(Looks.Mode.STYLED)
	assert_bool(td.people[0].look.is_styled()).is_true()
	assert_bool(td.player.look.is_styled()).is_true()
	assert_bool(td.border.look.is_styled()).is_true()
	assert_bool(td.pipeline.styled).is_true()
	assert_dict(_state(td)).is_equal(before)
	runner.simulate_key_pressed(KEY_F4)
	await runner.simulate_frames(3)
	assert_int(Looks.mode).is_equal(Looks.Mode.PLACEHOLDER)
	assert_bool(td.people[0].look.is_styled()).is_false()
	assert_bool(td.pipeline.styled).is_false()
	assert_bool(td.camera.get_parent() == td).is_true()
	assert_dict(_state(td)).is_equal(before)
	await TopDownTestUtil.leave_loaded_scene(td)


# The rules state that must not change when the look does.
func _state(td: TopDownMain) -> Dictionary:
	var people: Array = []
	for p: Person in td.people:
		people.append([p.is_rescued, p.level, snappedf(p.joy, 0.001), snappedf(p.gloom, 0.001), p.position])
	return {
		"people": people,
		"members": td.border.member_count,
		"inner": td.border.inner_count,
		"gaps": td.border.gap_count(),
		"polygon": td.border.polygon.size(),
		"night": td.night.elapsed,
		"rescued": td.rescued_count,
		"player": td.player.global_position,
	}


func test_the_hud_hint_names_f4_and_f3_shows_the_look_and_fallback_count() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_str(td.hud.hint_label.text).contains("[F4] look")
	runner.simulate_key_pressed(KEY_F3)
	await runner.simulate_frames(3)
	assert_str(td.hud.floor_label.text).contains("Look: Placeholder")
	runner.simulate_key_pressed(KEY_F4)
	await runner.simulate_frames(3)
	assert_str(td.hud.floor_label.text).contains("Look: Styled")
	assert_int(Looks.placeholder_fallback_count()).is_greater(1)
	assert_str(Looks.fallback_summary()).contains("target highlight")
	assert_str(Looks.fallback_summary()).contains("hud text")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_styled_people_build_the_body_for_each_state() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	td.running = false
	var grey: Person = td.people[0]
	var dark: Person = td.people[1]
	var joy: Person = td.people[2]
	TopDownTestUtil.place(grey, Vector3(0, 0, -6), 0, 0.5)
	TopDownTestUtil.place(dark, Vector3(3, 0, -6), 1, 0.9)
	TopDownTestUtil.place(joy, Vector3(-3, 0, -6), 2, 0.0)
	grey.level = 1
	dark.level = 2
	joy.receive_joy(2, Config.JOY_MAX * 2.0, 0.0)
	for p: Person in [grey, dark, joy]:
		p._update_visuals()
	var gl := grey.look as PersonLookStyled
	var dl := dark.look as PersonLookStyled
	var jl := joy.look as PersonLookStyled
	assert_int(gl.shown_kind()).is_equal(PersonLook.Kind.GREY)
	assert_int(dl.shown_kind()).is_equal(PersonLook.Kind.DARK)
	assert_int(jl.shown_kind()).is_equal(PersonLook.Kind.JOYFUL)
	assert_bool(gl._holders[PersonLook.Kind.GREY].visible).is_true()
	assert_object(gl._holders[PersonLook.Kind.JOYFUL]).is_null()
	assert_bool(dl._holders[PersonLook.Kind.DARK].visible).is_true()
	assert_bool(jl._holders[PersonLook.Kind.JOYFUL].visible).is_true()
	# Joy builds up on the grey person: their pip glows. A losing-joy rescued person flickers to the grey body.
	grey.joy = 600.0
	grey._update_visuals()
	assert_float(gl.frac).is_greater(0.2)
	joy.joy = joy.joy_needed() * Config.WARN_FRACTION * 0.5
	joy.look.wave = -1.0
	joy._update_visuals()
	jl.wave = -1.0
	assert_int(jl.shown_kind()).is_equal(PersonLook.Kind.GREY)
	# The grace glow, the bounce and the slump run without errors.
	joy.grace_left = 2.0
	joy._update_visuals()
	joy.look.play_bounce()
	joy.look.play_slump(0.8, 0.2)
	dark.look.play_slump(0.8, 0.2)
	await runner.simulate_frames(30)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_styled_building_dissolves_to_the_whimsical_version_when_beautified() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var b: Building = td.border.buildings[0]
	var look := b.look as BuildingLookStyled
	assert_object(look.whimsical).is_null()
	assert_bool(look.industrial.visible).is_true()
	for i: int in range(3):
		b.update(1.0, 1.0)
	assert_bool(b.beautified).is_true()
	assert_object(look.whimsical).is_not_null()
	assert_bool(look.whimsical.visible).is_true()
	assert_bool(look.industrial.visible).is_true()
	for i: int in range(2):
		b.update(1.0, 1.0)
	assert_bool(look.industrial.visible).is_false()
	b.set_post(true)
	assert_bool(look._lantern.visible).is_true()
	b.set_post(false)
	assert_bool(look._lantern.visible).is_false()
	b.update(1.0, 0.0)
	b.update(3.0, 0.0)
	assert_bool(look.industrial.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_ground_gets_the_paint_weights_as_a_texture() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 6)
	var look := td.ground.look as GroundLookStyled
	look.refresh(td.ground._colors, td.ground._weights)
	var img := look._image
	var size := Config.TD_PLAZA_SIZE
	assert_int(img.get_width()).is_equal(size)
	# The pixel for a tile holds that tile's paint weight (tile ix, iz is centred at -size/2 + 0.5 + ix).
	var spot := Vector3(12.0, 0.0, -12.0)
	var ix := floori(spot.x + size / 2.0)
	var iz := floori(spot.z + size / 2.0)
	assert_float(img.get_pixel(ix, iz).r).is_equal_approx(td.ground.paint_weight_at(spot), 0.02)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_border_draws_haze_motes_and_gap_glows() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 5)
	var look := td.border.look as BorderLookStyled
	assert_bool(td.border.active).is_true()
	assert_bool(look._haze.visible).is_true()
	assert_object(look._haze.mesh).is_not_null()
	(
		assert_int(look._gold_motes.multimesh.visible_instance_count + look._gap_motes.multimesh.visible_instance_count)
		. is_greater(0)
	)
	# Five people on the smallest loop leave every stretch open: glows over the gaps, and the pulse swells the motes.
	assert_int(td.border.gap_count()).is_greater(0)
	assert_int(look._glows.size()).is_greater(0)
	assert_bool(look._glows[0].visible).is_true()
	look.refresh()
	assert_float(look._glows[0].scale.x).is_between(0.8, 1.26)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_player_ring_takes_the_targets_colour() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, td.player.global_position + Vector3(0, 0, -5), 1, 0.5)
	td.player._set_target(target)
	await runner.simulate_frames(4)
	var look := td.player.look as PlayerLookStyled
	var mat := look._ring.material_override as ShaderMaterial
	var col: Color = mat.get_shader_parameter("albedo")
	assert_bool(col.is_equal_approx(Config.ELEMENT_COLORS[1])).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_minimap_palette_and_frame() -> void:
	var look := MinimapLookStyled.new()
	assert_bool(look.is_styled()).is_true()
	assert_bool(look.ground_colour(null, Vector2.ZERO, 0, 0).is_equal_approx(MinimapLookStyled.GREY_B)).is_true()
	assert_bool(look.building_colour(true).is_equal_approx(look.building_colour(false))).is_false()
	assert_bool(look.line_colour(true).is_equal_approx(look.line_colour(false))).is_false()
	assert_float(look.halo_colour("dark").a).is_equal(1.0)
	var colours: Array[Color] = [
		look.member_colour(), look.dark_colour(), look.landmark_colour(), look.player_colour(), look.view_colour()
	]
	assert_int(colours.size()).is_equal(5)
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.minimap.refresh_from(td.ground, td.border, td.people, td.player.global_position, Vector3.ZERO, Vector2(10, 10))
	td.minimap.queue_redraw()
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_landmark_ring_grows_in_the_styled_look() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var lm: Landmark = auto_free(Landmark.new())
	add_child(lm)
	lm.update(0.0, false)
	var look := lm.look as LandmarkLookStyled
	assert_bool(look._glow.visible).is_false()
	assert_str(look._label.text).is_equal("Landmark")
	lm.update(5.0, true)
	assert_bool(look._glow.visible).is_true()
	assert_str(look._label.text).contains("50%")


# Round 12a: the dimmed person's aura and the grab cue exist in the styled look too; the styled minimap shows warm
# territory wherever the placeholder minimap does.
func test_styled_dimmed_people_have_a_smoke_aura_and_the_grab_cue_leans_the_other_way() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var dimmed: Person = auto_free(Person.new())
	dimmed.gloom = 0.95
	add_child(dimmed)
	dimmed.tick(0.016)
	assert_bool(dimmed.look.is_styled()).is_true()
	assert_bool(dimmed.look.has_aura()).is_true()
	assert_bool(dimmed.look.aura.visible).is_false()  # the placeholder haze stays hidden; the styled smoke is drawn
	var parts: Dictionary = (dimmed.look as PersonLookStyled)._parts[PersonLook.Kind.DARK]
	assert_bool(parts.has("haze")).is_true()
	var grey: Person = auto_free(Person.new())
	add_child(grey)
	grey.tick(0.016)
	assert_bool(grey.look.has_aura()).is_false()
	dimmed.grab_frac = 0.8
	dimmed.tick(0.016)
	assert_bool(dimmed.look.grab_ring.visible).is_true()
	assert_float(dimmed.look.visual.rotation.x).is_less(-0.1)


func test_the_styled_minimap_shows_warm_territory_like_the_placeholder_one() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _rescue_ring(runner, td, 8)
	await runner.simulate_frames(200)
	var placeholder := MinimapLookPlaceholder.new()
	var styled := MinimapLookStyled.new()
	var warm_points := 0
	for ix: int in range(-24, 24, 2):
		for iz: int in range(-24, 24, 2):
			var at := Vector3(float(ix) + 0.5, 0.0, float(iz) + 0.5)
			var weight := td.ground.paint_weight_at(at)
			var p_col := placeholder.ground_colour(td.ground, Vector2(at.x, at.z), 3, 5)
			var s_col := styled.ground_colour(td.ground, Vector2(at.x, at.z), 3, 5)
			var styled_warm := s_col.r > s_col.b
			var grey_col := Config.GROUND_GREY
			var placeholder_warm := (
				absf(p_col.r - grey_col.r) + absf(p_col.g - grey_col.g) + absf(p_col.b - grey_col.b) > 0.03
			)
			if weight >= 0.2:
				warm_points += 1
				assert_bool(styled_warm).is_true()
				assert_bool(placeholder_warm).is_true()
			elif weight <= 0.0:
				assert_bool(styled_warm).is_false()
	assert_int(warm_points).is_greater(20)
	await TopDownTestUtil.leave_loaded_scene(td)
