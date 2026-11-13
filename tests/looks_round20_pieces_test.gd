extends GdUnitTestSuite

# Graphics checkpoint 4: the styled look of the round 20 pieces (the minimap clouds, the landmark pulse, the alert
# banner; the reach guide and the beacon went in 0.4) and the round 19 flag fixes. Headless uses a dummy renderer, so
# these check state and geometry; the screenshots (tools/checkpoint_shots.py --set round20) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# --- The round 20 pieces in the styled look
# ---------------------------------------------------------------------------


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
	lm.update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	assert_int(get_tree().get_nodes_in_group("landmark_pulse").size()).is_equal(1)
	var claim: MeshInstance3D = get_tree().get_nodes_in_group("landmark_pulse")[0]
	assert_float(claim.scale.x).is_equal_approx(1.5, 0.01)
	lm.update(0.0, false)
	assert_int(get_tree().get_nodes_in_group("landmark_pulse").size()).is_equal(2)
	var loss: MeshInstance3D = get_tree().get_nodes_in_group("landmark_pulse")[1]
	assert_float(loss.scale.x).is_equal_approx(LandmarkLookStyled.PULSE_RADIUS, 0.01)
	for node: Node in get_tree().get_nodes_in_group("landmark_pulse"):
		node.free()


func test_the_styled_alert_panel_still_draws_its_banner() -> void:
	# Clean HUD (#92): the HUD no longer owns an alert line (events use the one banner), but the styled panel kind stays.
	Looks.set_mode(Looks.Mode.STYLED)
	var panel: StyledPanel = auto_free(StyledPanel.new())
	panel.kind = StyledPanel.Kind.ALERT
	add_child(panel)
	panel.set_alert("Claimed the Bandstand", LandmarkConfig.LANDMARK_CLAIM_COLOUR)
	assert_str(panel.alert_text).is_equal("Claimed the Bandstand")
	assert_bool(panel.alert_colour.is_equal_approx(LandmarkConfig.LANDMARK_CLAIM_COLOUR)).is_true()
	panel._draw()
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func test_the_styled_alert_panel_draws_nothing_for_empty_text() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var panel: StyledPanel = auto_free(StyledPanel.new())
	panel.kind = StyledPanel.Kind.ALERT
	add_child(panel)
	panel.set_alert("", LandmarkConfig.LANDMARK_CLAIM_COLOUR)
	panel._draw()
	assert_str(panel.alert_text).is_equal("")
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


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
