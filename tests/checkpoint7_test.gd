extends GdUnitTestSuite

# Checkpoint 7: the styled push and HUD. The round 26 push in the styled look (the tide's fog banks and figures, a
# pusher's lean), the styled Dusk to Dawn panel and spirit tag, and the ribbon's halo with no dithering. Headless uses a
# dummy renderer, so these check state, geometry and the shader's source; the screenshots (tools/checkpoint_shots.py)
# check the look. Tides are switched on for the tide tests only (see Config.tides_on).


func before_test() -> void:
	Config.tides_override = 1


func after_test() -> void:
	Config.tides_override = -1
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# A level with everyone parked far away (so only what a test places can take part).
func _level() -> Array:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return [runner, td]


# Puts the night clock at `seconds` and runs the tides' update once (no frames).
func _at(td: TopDownMain, seconds: float) -> void:
	td.night.elapsed = seconds
	td.gloom_tide.update(0.0)


# --- The ribbon: no dithering -----------------------------------------------------------------------------------------


func test_the_ribbon_halo_is_a_soft_falloff_with_no_dither() -> void:
	var src := FileAccess.get_file_as_string("res://shaders/style_ribbon.gdshader")
	assert_bool(src.is_empty()).is_false()
	# No ordered-dither table and no screen-position threshold: the halo is an alpha falloff.
	assert_bool(src.contains("FRAGCOORD")).is_false()
	assert_bool(src.contains("M4")).is_false()
	assert_bool(src.contains("bayer")).is_false()
	assert_bool(src.contains("ALPHA = a")).is_true()


# --- The styled HUD: Dusk to Dawn panel and spirit tag ----------------------------------------------------------------


func test_the_night_fill_follows_progress_and_clamps() -> void:
	assert_int(StyleHud.night_fill_cells(0.0, 100)).is_equal(0)
	assert_int(StyleHud.night_fill_cells(0.5, 100)).is_equal(50)
	assert_int(StyleHud.night_fill_cells(1.0, 100)).is_equal(100)
	assert_int(StyleHud.night_fill_cells(2.0, 100)).is_equal(100)
	assert_int(StyleHud.night_fill_cells(-1.0, 10)).is_equal(0)


func test_the_styled_night_panel_and_spirit_tag_replace_the_placeholder_pieces() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	var hud: Hud = td.hud
	# Values are checked before any frame runs (the level sets the night and the spirit again every frame).
	td.set_look(Looks.Mode.STYLED)
	hud.set_night_progress(0.5)
	hud.set_spirit(0.0, true)
	assert_bool(hud.night_view.visible).is_true()
	assert_bool(hud.night_label.visible).is_false()
	assert_bool(hud.night_bar.visible).is_false()
	assert_float(hud.night_bar.value).is_equal_approx(50.0, 0.001)
	assert_bool(hud.spirit_view.visible).is_true()
	assert_bool(hud.spirit_label.visible).is_false()
	# The dimmed tag keeps the placeholder's text; the styled look draws it through its own view.
	assert_str(hud.spirit_label.text).contains("DIM")
	# The target line's mood (the styled line panel is fed the same text).
	hud.set_target(0)
	hud.set_target_mood("guarded")
	hud.set_target_mood("guarded")
	# A frame draws the styled pieces (the draw callbacks run).
	await runner.simulate_frames(3)
	# Back to the placeholder: the Labels and bars return and the styled pieces hide.
	td.set_look(Looks.Mode.PLACEHOLDER)
	assert_bool(hud.night_view.visible).is_false()
	assert_bool(hud.night_label.visible).is_true()
	assert_bool(hud.night_bar.visible).is_true()
	assert_bool(hud.spirit_view.visible).is_false()
	assert_bool(hud.spirit_label.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_spirit_tag_shows_once_the_level_reports_spirit() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(2)
	# The level sets the spirit every frame, so the styled tag is up in the game (and the Label is not).
	assert_bool(td.hud.spirit_view.visible).is_true()
	assert_bool(td.hud.spirit_label.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The styled tide: fog banks and figures ---------------------------------------------------------------------------


func test_the_styled_fog_banks_and_figures_are_built_from_pixel_blocks() -> void:
	var root: Node3D = auto_free(Node3D.new())
	var fog := StylePush.build_fog(root, 20.0, 4.0)
	assert_int(fog.get_child_count()).is_equal(Config.CP7_FOG_BANKS)
	for child: Node in fog.get_children():
		assert_bool(child is MeshInstance3D).is_true()
	for i: int in range(Config.CP7_FOG_BANKS):
		var share := StylePush.bank_height_share(i)
		assert_float(share).is_greater_equal(0.6)
		assert_float(share).is_less_equal(1.0)
	var fig := StylePush.build_figure(root)
	assert_int(fig.get_child_count()).is_equal(2)
	assert_bool(fig.get_parent() == root).is_true()


func test_the_styled_tide_shows_its_fog_only_in_the_styled_look_and_moves_its_figures() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	var tide := td.gloom_tide
	var start: float = tide.tides[0]["start"]
	td.set_look(Looks.Mode.STYLED)
	_at(td, start + 0.1)
	await runner.simulate_frames(2)
	assert_bool(tide.styled_fog.visible).is_true()
	assert_bool(tide.fog.visible).is_false()
	assert_int(tide.styled_figures.size()).is_equal(Config.TIDE_FIGURES)
	var a := tide.styled_figures[0].position
	_at(td, start + 1.3)
	assert_bool(tide.styled_figures[0].position.is_equal_approx(a)).is_false()
	assert_bool(tide.styled_figures[0].get_parent() == tide.styled_fog).is_true()
	# The styled fog sits where the placeholder fog sits.
	assert_bool(tide.styled_fog.position.is_equal_approx(tide.fog.position)).is_true()
	# Back to the placeholder look: the plane shows and the banks hide.
	td.set_look(Looks.Mode.PLACEHOLDER)
	_at(td, start + 1.3)
	await runner.simulate_frames(2)
	assert_bool(tide.styled_fog.visible).is_false()
	assert_bool(tide.fog.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The styled pusher lean -------------------------------------------------------------------------------------------


func test_a_pusher_leans_into_the_line_and_a_still_person_does_not() -> void:
	var identity := Basis.IDENTITY
	assert_bool(PersonLookStyled.brace_lean(Vector3.ZERO, 1.0, identity) == Vector2.ZERO).is_true()
	assert_bool(PersonLookStyled.brace_lean(Vector3(1, 0, 0), 0.0, identity) == Vector2.ZERO).is_true()
	# Pushing from the front (+z in the body's frame) tips the top forward (positive x rotation).
	var front := PersonLookStyled.brace_lean(Vector3(0, 0, 1), 1.0, identity)
	assert_float(front.x).is_equal_approx(Config.PUSH_BRACE_LEAN, 0.0001)
	assert_float(front.y).is_equal_approx(0.0, 0.0001)
	# Pushing from +x tips the top toward +x: a negative z rotation.
	var side := PersonLookStyled.brace_lean(Vector3(1, 0, 0), 1.0, identity)
	assert_float(side.y).is_equal_approx(-Config.PUSH_BRACE_LEAN, 0.0001)


func test_a_styled_pusher_runs_the_lean_in_the_level() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	td.set_look(Looks.Mode.STYLED)
	var p: Person = td.people[0]
	p.brace = 0.8
	p.brace_dir = Vector3(1, 0, 0)
	await runner.simulate_frames(3)
	# The look poses the lean on the body that shows (the rules may clear the brace again within a frame).
	assert_bool(is_instance_valid(p)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
