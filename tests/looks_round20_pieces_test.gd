extends GdUnitTestSuite

# Graphics checkpoint 4: the styled look of the round 20 pieces (the reach guide, the minimap clouds, the landmark
# pulse, the alert banner) and the round 19 flag fixes. Headless uses a dummy renderer, so these check state and
# geometry; the screenshots (tools/checkpoint_shots.py --set round20) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# --- The round 20 pieces in the styled look
# ---------------------------------------------------------------------------


func _formed() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	for i: int in range(6):
		var a := TAU * float(i) / 6.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(-6, 0, 4) + Vector3(cos(a) * 4.0, 0.0, sin(a) * 4.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(60)
	td.player.add_spirit(100.0)
	return {"td": td, "runner": runner}


func _visible_count(guide: StyleReach) -> int:
	var n := 0
	for node: MeshInstance3D in guide._all:
		if node.visible:
			n += 1
	return n


func test_the_styled_reach_guide_shows_the_zone_preview_and_the_travel() -> void:
	var s: Dictionary = await _formed()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	var guide: StyleReach = td.reach_guide._styled
	assert_object(guide).is_not_null()
	# Graphics checkpoint 5: no aim, nothing; aim within reach: the zone outline and its fill (not limited).
	td.player._has_aim = false
	td.reach_guide.sync(td.border, td.player)
	assert_int(_visible_count(guide)).is_equal(0)
	var reach: float = td.border.stretch_info()["max"]
	td.player._aim_point = td.border.centre + Vector3(reach * 0.95, 0.0, 0.0)
	td.player._has_aim = true
	td.reach_guide.sync(td.border, td.player)
	assert_bool(guide.showing_preview).is_true()
	assert_bool(guide.showing_limited).is_false()
	assert_bool(guide._line.visible).is_true()
	assert_bool(guide._fill.visible).is_true()
	assert_bool(guide._cross.visible).is_false()
	# A beacon beyond the reach: the path, the tip, the dashes on to the beacon, then, once it arrives, nothing (round
	# 22: no hold).
	td.border.place_beacon(td.border.centre + Vector3(reach * 3.0, 0.0, 0.0))
	# Round 23: the tip walks at the new pull speed, so it has not arrived after 20 frames (a third of a second) here.
	await runner.simulate_frames(20)
	td.reach_guide.sync(td.border, td.player)
	assert_bool(guide.showing_travel).is_true()
	assert_bool(guide._tip_disc.visible).is_true()
	assert_bool(guide._dashes.visible).is_true()
	# Round 22: there is no hold any more: once the tip has arrived the travel is gone.
	await runner.simulate_frames(1500)
	td.reach_guide.sync(td.border, td.player)
	assert_bool(guide.showing_travel).is_false()
	# Back to the placeholder look: the styled pieces hide.
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(3)
	assert_int(_visible_count(guide)).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_reach_guide_hides_without_a_border() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var guide := StyleReach.new()
	var root: Node3D = auto_free(Node3D.new())
	guide.build(root)
	var border: Border = auto_free(Border.new())
	var player: TopDownPlayer = auto_free(TopDownPlayer.new())
	add_child(player)
	guide.sync(border, player)
	assert_int(_visible_count(guide)).is_equal(0)


func test_the_preview_stops_at_the_reach() -> void:
	var inside := ReachGuide.preview(Vector2.ZERO, Vector2(5, 0), 10.0)
	assert_bool(inside["capped"]).is_false()
	assert_vector(inside["end"]).is_equal(Vector2(5, 0))
	var past := ReachGuide.preview(Vector2.ZERO, Vector2(0, 30), 10.0)
	assert_bool(past["capped"]).is_true()
	assert_vector(past["end"]).is_equal_approx(Vector2(0, 10), Vector2(0.001, 0.001))


func test_the_styled_minimap_draws_dusk_clouds_on_top_of_the_ground() -> void:
	var look := MinimapLookStyled.new()
	assert_float(look.cloud_colour().a).is_equal(1.0)
	var m: Minimap = auto_free(Minimap.new())
	m.look = look
	add_child(m)
	var people: Array[Person] = []
	for k: int in range(5):
		var p: Person = auto_free(Person.new())
		p.position = Vector3(-30.0 + float(k), 0.0, -30.0)
		people.append(p)
	m.refresh_clouds(people)
	assert_int(m.cloud_cells.size()).is_equal(1)
	m._render()
	var centre: Vector2 = m.cloud_cells[0]["centre"]
	var c := m._to_px(centre)
	var shown := m._image.get_pixel(int(c.x), int(c.y))
	var bare := look.ground_colour(null, Vector2(-30, -30), int(c.x), int(c.y))
	assert_bool(shown.is_equal_approx(bare)).is_false()


func test_a_styled_landmark_pulses_on_a_claim_and_on_a_loss() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var lm: Landmark = auto_free(Landmark.new())
	lm.index = Landmarks.BANDSTAND
	add_child(lm)
	lm.update(Config.BORDER_LANDMARK_HOLD, true)
	assert_int(get_tree().get_nodes_in_group("landmark_pulse").size()).is_equal(1)
	var claim: MeshInstance3D = get_tree().get_nodes_in_group("landmark_pulse")[0]
	assert_float(claim.scale.x).is_equal_approx(1.5, 0.01)
	lm.update(0.0, false)
	assert_int(get_tree().get_nodes_in_group("landmark_pulse").size()).is_equal(2)
	var loss: MeshInstance3D = get_tree().get_nodes_in_group("landmark_pulse")[1]
	assert_float(loss.scale.x).is_equal_approx(LandmarkLookStyled.PULSE_RADIUS, 0.01)
	for node: Node in get_tree().get_nodes_in_group("landmark_pulse"):
		node.free()


func test_the_styled_alert_is_a_banner_and_the_label_hides() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var hud: Hud = auto_free(Hud.new())
	add_child(hud)
	hud.rebuild_look()
	assert_bool(hud.alert_label.visible).is_false()
	assert_bool(hud.alert_panel.visible).is_true()
	hud.show_alert("Claimed the Bandstand", Config.LANDMARK_CLAIM_COLOUR)
	assert_str(hud.alert_panel.alert_text).is_equal("Claimed the Bandstand")
	assert_bool(hud.alert_panel.alert_colour.is_equal_approx(Config.LANDMARK_CLAIM_COLOUR)).is_true()
	assert_float(hud.alert_panel.modulate.a).is_equal(1.0)
	hud.alert_panel._draw()
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	hud.rebuild_look()
	assert_bool(hud.alert_label.visible).is_true()
	assert_bool(hud.alert_panel.visible).is_false()


# --- The round 19 flags
# ----------------------------------------------------------------------------------------------


func test_the_guarded_icon_is_a_shield_with_a_chevron_not_a_cross() -> void:
	var rows := StyleUi.glyph_rows(1)
	# A cross has a dark centre column running through the middle rows; the chevron's middle column is plain shield.
	var column := ""
	for y: int in range(3, 9):
		column += rows[y][6]
	assert_bool(column.contains("dddd")).is_false()
	var dark := 0
	for row: String in rows:
		dark += row.count("d")
	assert_int(dark).is_greater(8)


func test_the_dawn_lights_are_round_suns_with_no_ground_band() -> void:
	for rows: Array[String] in [StyleGlyphs.SUN_LIT, StyleGlyphs.SUN_OUT]:
		assert_int(rows.size()).is_equal(rows[0].length())
		for row: String in rows:
			assert_bool(row.contains("g")).is_false()
	assert_int(StyleGlyphs.SUN_LIT[0].count("h")).is_equal(1)
	assert_int(StyleGlyphs.SUN_OUT[0].count("h")).is_equal(0)
	assert_int(StyleGlyphs.SUN_LIT[7].length()).is_equal(15)


func test_the_styled_look_skips_the_canopy_over_a_sheltered_head() -> void:
	assert_bool(FeedbackLayer.canopy_shown()).is_true()
	Looks.set_mode(Looks.Mode.STYLED)
	assert_bool(FeedbackLayer.canopy_shown()).is_false()


func test_the_beacon_dashes_are_bigger_with_an_ink_edge() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var root: Node3D = auto_free(Node3D.new())
	var dashes := StyleBeacon.build_dashes(root)
	assert_int(dashes.size()).is_equal(StyleBeacon.DASHES)
	var size := (dashes[0].mesh as BoxMesh).size
	assert_float(size.x).is_greater_equal(1.0)
	assert_float(size.z).is_greater_equal(0.3)
	assert_int(dashes[0].get_child_count()).is_equal(1)


func test_the_bandstand_ruin_is_lighter_than_it_was() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var root: Node3D = auto_free(Node3D.new())
	StyleLandmarks.build(root, Landmarks.BANDSTAND, true)
	var lightest := 0.0
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var m := (node as MeshInstance3D).material_override as ShaderMaterial
		var col: Color = m.get_shader_parameter("albedo")
		lightest = maxf(lightest, col.get_luminance())
	assert_float(lightest).is_greater(0.5)
