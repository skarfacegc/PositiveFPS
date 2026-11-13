extends GdUnitTestSuite

# Walls and gates: Style update (#94): the styled look caught up with passes 2c and 3 and the Clean HUD.
# Headless uses a dummy renderer, so these check plans, counts and wiring; the checkpoint shots
# (design/renders/v0.4-style) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _start(styled: bool = true) -> Dictionary:
	Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	return {"runner": runner, "td": runner.scene()}


# ---- Pure pieces -----------------------------------------------------------------------------------------------------


func test_the_storm_front_bows_forward_stands_tall_at_the_front_and_low_at_the_back() -> void:
	var puffs := StylePush.layout_puffs(26.0, NightConfig.TIDE_FOG_DEPTH, NightConfig.SURGE_FOG_HEIGHT)
	var front_h := 0.0
	var back_h := 0.0
	var front_n := 0
	var back_n := 0
	var mid_z := -INF
	var end_z := INF
	for p: Dictionary in puffs:
		var at: Vector3 = p["pos"]
		var h: float = p["height"]
		if at.z > 0.5:
			front_h += h
			front_n += 1
			if absf(at.x) < 3.0:
				mid_z = maxf(mid_z, at.z)
			if absf(at.x) > 10.0:
				end_z = minf(end_z, at.z)
		elif at.z < -0.5:
			back_h += h
			back_n += 1
	assert_float(front_h / float(front_n)).is_greater(back_h / float(back_n))
	assert_float(mid_z).is_greater(end_z + 1.0)  # The middle leads, the ends trail.


func test_wash_tags_and_marks_build_their_pieces() -> void:
	var root := Node3D.new()
	var m := StyleKit.wash(root, Rect2(0.0, 0.0, 12.0, 18.0), Color.WHITE, 0.2, 0.5, 4.5)
	assert_float((m.mesh as PlaneMesh).size.y).is_equal(18.0)
	assert_float(m.position.x).is_equal(6.0)
	StyleKit.set_wash(m, 0.0, 0.1)
	var rim: float = (m.material_override as ShaderMaterial).get_shader_parameter("rim")
	assert_float(rim).is_equal_approx(0.1, 0.001)
	var free: Array[Rect2] = [Rect2(0.0, 0.0, 12.0, 12.0)]
	var paid: Array[Rect2] = [Rect2(20.0, 0.0, 12.0, 12.0)]
	var pulses: Array[Dictionary] = [{"rect": Rect2(40.0, 0.0, 12.0, 12.0), "share": 0.5}]
	var before := root.get_child_count()
	StyleTake.marks(root, free, paid, pulses)
	# Two washes, two lantern rows and a pulse wash.
	assert_int(root.get_child_count()).is_equal(before + 5)
	assert_int(StyleTake.edge_lamps(Rect2(0.0, 0.0, 12.0, 12.0)).size()).is_equal(20)
	root.free()


func test_a_gate_gets_posts_a_festoon_clear_of_the_player_and_bulbs() -> void:
	var gate := {"a": Vector2(9.0, 9.0), "b": Vector2(21.0, 9.0)}
	var tiny := {"a": Vector2(0.0, 0.0), "b": Vector2(1.0, 0.0)}
	var gates: Array[Dictionary] = [gate, tiny]
	var plan := StyleGates.plan(gates)
	assert_int(plan.size()).is_equal(1)
	var posts: Array = plan[0]["posts"]
	var p0: Vector2 = posts[0]
	assert_float(p0.x).is_equal_approx(9.0 + StyleConfig.SU_GATE_INSET, 0.001)
	var low := INF
	for s: Vector3 in plan[0]["string"]:
		low = minf(low, s.y)
	assert_float(low).is_greater_equal(StyleConfig.L32_PLAYER_HEIGHT + StyleConfig.L32_LINE_CLEARANCE)
	var bulbs: Array = plan[0]["bulbs"]
	assert_int(bulbs.size()).is_greater(1)
	var root := Node3D.new()
	StyleGates.build(root, plan)
	var meshes := root.find_children("*", "MeshInstance3D", true, false).size()
	assert_int(meshes).is_equal(StyleGates.mesh_count(plan[0]))
	assert_int(root.find_children("*", "MultiMeshInstance3D", true, false).size()).is_equal(1)
	root.free()


func test_a_block_wears_one_piece_on_four_houses_and_its_bloom_has_a_counterpart() -> void:
	var roles: Array[int] = []
	for h: Dictionary in StyleHouses.layout(12.0, 12.0, 3):
		roles.append(h["role"])
	roles.sort()
	assert_array(roles).is_equal([0, 1, 2, 3, 4])
	var g := Node3D.new()
	StyleDress.industrial(g, StyleDress.Role.BARE, 4.0, 4.0, 3.0)
	StyleDress.whimsical(g, StyleDress.Role.BARE, 4.0, 4.0, 3.0)
	assert_int(g.get_child_count()).is_equal(0)
	var cold := 0
	var warm := 0
	for role: int in range(4):
		var a := Node3D.new()
		StyleDress.industrial(a, role, 4.0, 4.0, 3.0)
		cold += a.get_child_count()
		var b := Node3D.new()
		StyleDress.whimsical(b, role, 4.0, 4.0, 3.0)
		warm += b.get_child_count()
		a.free()
		b.free()
	assert_int(cold).is_equal(StyleDress.INDUSTRIAL_MESHES)
	assert_int(warm).is_equal(StyleDress.WHIMSICAL_MESHES)
	g.free()


func test_each_defence_type_builds_its_own_small_piece() -> void:
	for type: int in range(4):
		var n := StyleDefence.build(type, Vector3(1.0, 0.0, 2.0), false)
		assert_int(n.find_children("*", "MeshInstance3D", true, false).size()).is_equal(StyleDefence.mesh_count(type))
		assert_float(n.position.z).is_equal(2.0)
		n.free()
	var ghost := StyleDefence.build(Landmarks.GARDEN, Vector3.ZERO, true)
	assert_int(ghost.find_children("*", "MeshInstance3D", true, false).size()).is_equal(StyleDefence.mesh_count(1) + 1)
	ghost.free()


func test_the_surge_mark_has_its_own_storm_palette_in_the_styled_minimap() -> void:
	var plain := MinimapLook.new()
	var styled := MinimapLookStyled.new()
	assert_float(plain.surge_ink().a).is_equal(0.0)
	assert_float(plain.surge_beat_colour().a).is_equal(0.0)
	assert_bool(plain.surge_colour().is_equal_approx(NightConfig.TIDE_MINIMAP_COLOUR)).is_true()
	assert_float(styled.surge_ink().a).is_equal(1.0)
	assert_bool(styled.surge_colour().is_equal_approx(NightConfig.TIDE_MINIMAP_COLOUR)).is_false()
	assert_float(styled.surge_beat_colour().a).is_greater(0.0)
	assert_float(styled.surge_ring_colour().a).is_greater(0.0)


func test_the_preview_panel_is_sized_to_its_lines() -> void:
	var one := StyleHud.preview_size("Free: ready")
	var three := StyleHud.preview_size("Free: ready\n3/3 pips\n+1 gate: covered by spare people")
	assert_float(three.y).is_greater(one.y + StyleConfig.SU_PREVIEW_LINE)
	assert_float(three.x).is_greater(one.x)


# ---- In a level ------------------------------------------------------------------------------------------------------


func test_the_people_line_and_landmark_pointers_show_in_the_styled_look_only() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.hud.set_people("People: 12 on the line, 4 short", true)
	assert_bool(td.hud.people_panel.visible).is_true()
	assert_bool(td.hud.people_label.visible).is_false()
	assert_int(td.hud.people_panel.kind).is_equal(StyledPanel.Kind.PEOPLE)
	assert_bool(td.hud.layout_controls().has(td.hud.people_panel)).is_true()
	assert_bool(td.landmark_pointers.visible).is_true()
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(2)
	assert_bool(td.hud.people_panel.visible).is_false()
	assert_bool(td.hud.people_label.visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_surge_pointer_is_no_longer_a_placeholder_piece() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var p := td.gloom_tide.pointer
	p.show_at(Vector2(600.0, 40.0), Vector2.UP)
	p.pulse()
	await get_tree().process_frame  # The styled drawing runs on the redraw the calls above asked for.
	await get_tree().process_frame
	assert_bool(p.shown).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_gate_counts_and_cell_tags_are_dressed_in_the_styled_look_and_put_back() -> void:
	var label := Label3D.new()
	label.outline_size = 12
	label.font_size = 40
	label.modulate = Color(0.2, 0.3, 0.4)
	Looks.set_mode(Looks.Mode.STYLED)
	StyleTags.apply(label, StyleTags.Role.GATE_SHORT, Color(0.2, 0.3, 0.4))
	assert_int(label.outline_size).is_equal(StyleConfig.SU_TAG_OUTLINE)
	assert_int(label.font_size).is_greater(40)
	assert_bool(label.modulate.is_equal_approx(StyleTags.CORAL)).is_true()
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	StyleTags.apply(label, StyleTags.Role.GATE_SHORT, Color(0.2, 0.3, 0.4))
	assert_int(label.outline_size).is_equal(12)
	assert_int(label.font_size).is_equal(40)
	assert_bool(label.modulate.is_equal_approx(Color(0.2, 0.3, 0.4))).is_true()
	Looks.set_mode(Looks.Mode.STYLED)
	StyleTags.joy_number(label, Config.MATCH_MULT)
	assert_bool(label.outline_modulate.is_equal_approx(StyleTags.INK)).is_false()
	label.free()


func test_takeable_cells_pulses_and_the_preview_are_washes_in_the_styled_look() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var take := td.take_block
	var c := TownGrid.neighbours(TownGrid.start_cell())[0]
	td.player.spirit = 90.0
	take._draw_all()
	var washes := 0
	for n: Node in take._styled_root.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is PlaneMesh:
			washes += 1
	assert_int(washes).is_greater(0)  # The cells next to the zone are takeable (paid).
	take.holding = true
	take.target_cell = c
	take.preview = td.border.zone.preview(c, true)
	td.player._aim_point = TownGrid.cell_centre(c)
	td.player._has_aim = true
	await runner.simulate_frames(3)
	assert_bool(take._panel != null and take._panel.kind == StyledPanel.Kind.PREVIEW).is_true()
	assert_bool(take._label.visible).is_false()
	take.holding = false
	td.player._has_aim = false
	await runner.simulate_frames(3)
	assert_bool(take._panel.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_lost_cell_pulses_a_cold_wash_and_a_planted_defence_is_styled_furniture() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.events.on_cells_lost([Vector2i(3, 2)] as Array[Vector2i], 0)
	var pulse: LostPulse = td.events._pulse
	assert_int(pulse.count()).is_equal(1)
	pulse.update(BorderConfig.LOST_PULSE_SECONDS * 0.5)
	assert_int(pulse.count()).is_equal(1)
	pulse.update(BorderConfig.LOST_PULSE_SECONDS)
	assert_int(pulse.count()).is_equal(0)
	TopDownTestUtil.send_everyone_away(td)
	for i: int in range(12):
		var a := TAU * float(i) / 12.0
		var p := td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	await runner.simulate_frames(240)
	td.landmarks.unlock_order.append(Landmarks.GARDEN)
	assert_bool(td.defences.plant_now(0, Landmarks.GARDEN)).is_true()
	await runner.simulate_frames(3)
	var meshes := td.defences._root.find_children("*", "MeshInstance3D", true, false)
	assert_int(meshes.size()).is_equal(StyleDefence.mesh_count(Landmarks.GARDEN))
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_mended_break_shows_a_closing_ring_in_the_styled_look_only() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var fx := td.burst_cue.fx
	fx.add_mend(Vector3(5.0, 0.0, 5.0))
	fx.add_mend(Vector3(5.5, 0.0, 5.0))  # Replaces the first (same spot).
	assert_int(fx.mend_count()).is_equal(1)
	fx.sync(0.1)
	fx.sync(0.1)
	assert_int(fx._mend_nodes.size()).is_equal(1)
	assert_bool(fx._mend_nodes[0].visible).is_true()
	fx.sync(StyleConfig.SU_MEND_SECONDS + 1.0)
	assert_int(fx.mend_count()).is_equal(0)
	# A real mend reaches it through the border's signal.
	td.border.line_mended.emit(Vector3(1.0, 0.0, 1.0), 2.0)
	assert_int(fx.mend_count()).is_equal(1)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	fx.sync(0.1)
	var count := fx.mend_count()
	fx.add_mend(Vector3(30.0, 0.0, 30.0))
	assert_int(fx.mend_count()).is_equal(count)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_every_styled_line_panel_kind_and_state_draws() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var kinds: Array[int] = [
		StyledPanel.Kind.PEOPLE,
		StyledPanel.Kind.RESCUED,
		StyledPanel.Kind.TARGET,
		StyledPanel.Kind.TARGETING,
		StyledPanel.Kind.BURST,
		StyledPanel.Kind.KEYS,
		StyledPanel.Kind.PREVIEW,
	]
	var states: Array[int] = [StyleHudText.IDLE, StyleHudText.READY, StyleHudText.WARN, StyleHudText.DIM]
	var panels: Array[StyledPanel] = []
	for kind: int in kinds:
		for state: int in states:
			var p := StyledPanel.new()
			p.kind = kind
			p.size = Vector2(300.0, 60.0)
			p.set_line("People: 3 | WASD move", state, StyleUi.GOLD)
			add_child(p)
			panels.append(p)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(panels.size()).is_equal(kinds.size() * states.size())
	for p: StyledPanel in panels:
		p.queue_free()
	var plain_label: Label3D = auto_free(Label3D.new())
	StyleTags.apply(plain_label, StyleTags.Role.PLAIN, Color.RED)
	assert_bool(StyleTags.colour_of(StyleTags.Role.IDLE) == StyleTags.GREY).is_true()
	assert_bool(StyleTags.colour_of(StyleTags.Role.FREE) == StyleTags.GOLD).is_true()
	assert_bool(StyleTags.colour_of(StyleTags.Role.PAID) == StyleTags.BLUE).is_true()
	assert_bool(StyleTags.colour_of(StyleTags.Role.GATE_OK) == StyleTags.CREAM).is_true()
	assert_bool(StyleTags.colour_of(StyleTags.Role.PLAIN, Color.RED) != Color.RED).is_true()
	var no_bulbs: Array[Dictionary] = [
		{"posts": [Vector2.ZERO, Vector2.ONE], "string": [Vector3.ZERO, Vector3.ONE], "bulbs": []}
	]
	var root := Node3D.new()
	StyleGates.build(root, no_bulbs)
	assert_int(root.find_children("*", "MultiMeshInstance3D", true, false).size()).is_equal(0)
	root.free()


func test_a_free_cell_and_a_pulse_are_drawn_as_washes() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var take := td.take_block
	var c := TownGrid.neighbours(TownGrid.start_cell())[0]
	td.border.pips.counts[c] = BorderConfig.TAKE_RESCUES
	td.border.pips.version += 1
	take._pulses.append({"cell": c, "left": BorderConfig.TAKE_PULSE_SECONDS * 0.5})
	take._draw_all()
	var washes := 0
	for n: Node in take._styled_root.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is PlaneMesh:
			washes += 1
	assert_int(washes).is_greater(1)  # The free cell's wash and the pulse's.
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_border_look_builds_gate_arches_when_the_zone_has_gates() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(30)
	var look := td.border.look as BorderLookStyled
	if look._arches.get_child_count() == 0:
		look._hedge_version = -1
		look.subject.active = true
		look._rebuild_hedges()
	assert_int(look._arches.get_child_count()).is_greater(0)
	await TopDownTestUtil.leave_loaded_scene(td)
