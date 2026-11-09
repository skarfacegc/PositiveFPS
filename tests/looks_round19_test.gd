extends GdUnitTestSuite

# Graphics checkpoint 3: the styled look of the round 19 pieces (the spirit beacon, the four landmarks, the landmark
# panel and the dawn rating screen). Headless uses a dummy renderer, so these check that everything builds, shows the
# right state and draws without errors; the screenshots (tools/checkpoint_shots.py --set round19) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _landmark(index: int) -> Landmark:
	Looks.set_mode(Looks.Mode.STYLED)
	var lm: Landmark = auto_free(Landmark.new())
	lm.index = index
	add_child(lm)
	return lm


func _meshes(look: LandmarkLookStyled) -> int:
	return look.alive.find_children("*", "MeshInstance3D", true, false).size()


func test_each_styled_landmark_builds_both_versions_with_its_own_name() -> void:
	for i: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
		var lm := _landmark(i)
		var look := lm.look as LandmarkLookStyled
		assert_bool(look.is_styled()).is_true()
		assert_int(look.ruin.get_child_count()).is_greater(3)
		assert_int(look.alive.get_child_count()).is_greater(3)
		assert_str(look._label.text).is_equal(LandmarkConfig.LANDMARK_NAMES[i])


func test_the_three_landmarks_have_different_silhouettes() -> void:
	var a := _meshes(_landmark(0).look as LandmarkLookStyled)
	var b := _meshes(_landmark(1).look as LandmarkLookStyled)
	var c := _meshes(_landmark(2).look as LandmarkLookStyled)
	assert_bool(a != b and b != c and a != c).is_true()


func test_a_held_landmark_is_lit_and_shows_its_boost() -> void:
	var lm := _landmark(Landmarks.BELL_TOWER)
	var look := lm.look as LandmarkLookStyled
	assert_bool(look.is_lit()).is_false()
	assert_bool(look._beam.visible).is_false()
	assert_bool(look.ruin.visible).is_true()
	lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD * 0.5, true)
	assert_bool(look.alive.visible).is_true()
	assert_str(look._label.text).contains("Bell tower 50%")
	lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	assert_bool(look.is_lit()).is_true()
	assert_bool(look._beam.visible).is_true()
	assert_bool(look.ruin.visible).is_false()
	assert_bool(look._calm_ring.visible).is_true()
	assert_str(look._label.text).is_equal("Bell tower: gloom slowed x0.4 nearby")
	# Losing it puts it back to a ruin.
	lm.update(0.1, false)
	assert_bool(look.is_lit()).is_false()
	assert_bool(look._beam.visible).is_false()
	assert_bool(look.ruin.visible).is_true()


func test_held_cues_exist_for_the_bandstand_and_the_garden() -> void:
	for i: int in [Landmarks.BANDSTAND, Landmarks.GARDEN]:
		var lm := _landmark(i)
		var look := lm.look as LandmarkLookStyled
		lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
		assert_int(look._motes.size()).is_equal(LandmarkLookStyled.MOTES)
		assert_bool(look._motes[0].visible).is_true()


func test_a_styled_landmark_block_draws_nothing_itself_but_keeps_its_post_marker() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var td: TopDownMain = auto_free(TopDownMain.new())
	add_child(td)
	var block: Building = td.border.landmark_buildings[0]
	var look := block.look as BuildingLookStyled
	assert_object(look.industrial).is_null()
	block.post = true
	look.set_post(true)
	look.sync()
	assert_bool(look._lantern.visible).is_true()


func test_the_beacon_marker_swaps_looks_and_lays_a_pull_line() -> void:
	var marker: BeaconMarker = auto_free(BeaconMarker.new())
	add_child(marker)
	assert_bool(marker._parts.is_empty()).is_true()
	Looks.set_mode(Looks.Mode.STYLED)
	marker.rebuild_look()
	assert_bool(marker._parts.is_empty()).is_false()
	marker.sync(Vector3(20, 0, 0), 0.1, Vector3(0, 0, 0))
	assert_bool(marker.visible).is_true()
	var shown := 0
	for d: MeshInstance3D in marker._dashes:
		if d.visible:
			shown += 1
	assert_int(shown).is_greater(3)
	marker.sync(Vector3.INF, 0.1, Vector3.ZERO)
	assert_bool(marker.visible).is_false()
	# A beacon at the centre has no line; going back to the placeholder look restores its pillar.
	marker.sync(Vector3(0, 0, 0), 0.1, Vector3(0, 0, 0))
	for d: MeshInstance3D in marker._dashes:
		assert_bool(d.visible).is_false()
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	marker.rebuild_look()
	assert_bool(marker._parts.is_empty()).is_true()
	assert_int(marker.get_child_count()).is_equal(2)


func test_the_styled_minimap_marks_the_beacon_and_unheld_landmarks_apart() -> void:
	var look := MinimapLookStyled.new()
	assert_bool(look.landmark_state_colour(true).is_equal_approx(look.landmark_colour())).is_true()
	assert_bool(look.landmark_state_colour(false).is_equal_approx(look.landmark_colour())).is_false()
	assert_bool(look.beacon_colour().is_equal_approx(BeaconConfig.BEACON_COLOUR)).is_false()
	assert_float(look.halo_colour("beacon").a).is_greater(0.0)
	var plain := MinimapLookPlaceholder.new()
	assert_bool(plain.beacon_colour().is_equal_approx(BeaconConfig.BEACON_COLOUR)).is_true()
	assert_float(plain.halo_colour("landmark").a).is_equal(0.0)
	var map: Minimap = auto_free(Minimap.new())
	map.size = Vector2(144, 144)
	add_child(map)
	Looks.set_mode(Looks.Mode.STYLED)
	map.rebuild_look()
	map.beacon_pos = Vector2(10, 5)
	map.held_landmarks = [true, false, false]
	map.landmark_pts = PackedVector2Array([Vector2(20, 20), Vector2(-20, 20), Vector2(0, -30)])
	map._render()
	map.queue_redraw()
	await get_tree().process_frame
	assert_bool(map.beacon_pos != Vector2.INF).is_true()


func test_the_end_screen_data_the_dawn_panel_draws() -> void:
	var r := DawnRating.rate(42, 60, 0.46, 3)
	var reasons: Array[String] = []
	reasons.assign(r["lines"] as Array)
	var detail := "Dawn lights: [*][*][*]\n" + "\n".join(reasons) + "\n0 of 13 buildings beautified\n"
	var plain := StyleDawn.plain_lines(detail, r)
	assert_int(plain.size()).is_equal(1)
	assert_str(plain[0]).is_equal("0 of 13 buildings beautified")
	assert_array(StyleDawn.goals_met(r)).is_equal([true, true, true])
	var weak := DawnRating.rate(5, 60, 0.0, 0)
	assert_array(StyleDawn.goals_met(weak)).is_equal([false, false, false])
	# A lost round has no rating: every line is plain text.
	assert_int(StyleDawn.plain_lines("a\nb", {}).size()).is_equal(2)


func test_the_hud_draws_the_styled_panels_and_hides_the_labels() -> void:
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	assert_bool(hud.landmark_label.visible).is_true()
	assert_bool(hud.dawn_panel.visible).is_false()
	Looks.set_mode(Looks.Mode.STYLED)
	hud.rebuild_look()
	assert_bool(hud.landmark_label.visible).is_false()
	assert_bool(hud.landmark_panel.visible).is_true()
	hud.landmark_panel.size = Vector2(250, 164)
	hud.set_landmarks(["Bandstand: music x2"], 3, [true, false, false])
	assert_array(hud.landmark_panel.held).is_equal([true, false, false])
	assert_str(hud.landmark_label.text).contains("Landmarks 1 of 3")
	for lights: int in [3, 2, 1]:
		var r := DawnRating.rate(10 * lights, 60, 0.1 * float(lights), lights - 1)
		var reasons: Array[String] = []
		reasons.assign(r["lines"] as Array)
		hud.show_end("Dawn", "Dawn lights: x\n" + "\n".join(reasons) + "\nextra", r)
		hud.dawn_panel.size = Vector2(1280, 720)
		await get_tree().process_frame
	hud.show_end("The border fell", "one\ntwo")
	await get_tree().process_frame
	assert_str(hud.end_label.text).contains("The border fell")
	assert_bool(hud.end_label.visible).is_false()
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	hud.rebuild_look()
	assert_bool(hud.end_label.visible).is_true()
	assert_bool(hud.dawn_panel.visible).is_false()


func test_glyph_bitmaps_are_outlined_and_the_same_width_per_row() -> void:
	var all: Array[Array] = [
		StyleGlyphs.SUN_LIT,
		StyleGlyphs.SUN_OUT,
		StyleGlyphs.BANDSTAND,
		StyleGlyphs.GARDEN,
		StyleGlyphs.BELL,
		StyleGlyphs.PERSON,
		StyleGlyphs.COBBLES,
		StyleGlyphs.STAR,
		StyleGlyphs.TICK
	]
	for k: int in range(all.size()):
		var rows: Array[String] = []
		rows.assign(all[k])
		var width := rows[0].length()
		for row: String in rows:
			assert_int(row.length()).is_equal(width)
		var out := StyleGlyphs.outlined("test%d" % k, rows)
		assert_int(out.size()).is_equal(rows.size() + 2)
		assert_int(out[0].length()).is_equal(width + 2)
	assert_bool(StyleGlyphs.sun_palette(true)["#"] != StyleGlyphs.sun_palette(false)["#"]).is_true()
	for i: int in range(3):
		assert_bool(StyleGlyphs.landmark_palette(i, true)["#"] != StyleGlyphs.landmark_palette(i, false)["#"]).is_true()
