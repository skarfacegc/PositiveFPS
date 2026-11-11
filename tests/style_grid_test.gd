extends GdUnitTestSuite

# 0.4 pass 2b, Styled grid (#58): the houses that fill a built cell, the hedge on a wall run (and the ribbon that is
# the gates alone), the styled take preview and pips, and the minimap's wall colour. Headless uses a dummy renderer, so
# these check the plans, the counts and the wiring; the checkpoint shots (design/renders/v0.4-grid) check the look.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _start(styled: bool = false) -> Dictionary:
	Looks.set_mode(Looks.Mode.STYLED if styled else Looks.Mode.PLACEHOLDER)
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(20)
	return {"runner": runner, "td": runner.scene()}


# ---- The houses ----------------------------------------------------------------------------------------------------


func test_a_block_is_five_houses_that_fill_its_footprint() -> void:
	for seed_idx: int in range(4):
		var houses := StyleHouses.layout(12.0, 12.0, seed_idx)
		assert_int(houses.size()).is_equal(5)
		var area := 0.0
		for h: Dictionary in houses:
			var pos: Vector3 = h["pos"]
			var w: float = h["w"]
			var d: float = h["d"]
			assert_float(absf(pos.x) + w * 0.5).is_less_equal(6.0 + 0.001)
			assert_float(absf(pos.z) + d * 0.5).is_less_equal(6.0 + 0.001)
			area += w * d
		# Only the alley and the thin gaps are left open.
		assert_float(area).is_greater(12.0 * 12.0 * 0.8)


func test_the_house_group_is_steady_and_varies_between_blocks() -> void:
	var a := StyleHouses.layout(12.0, 12.0, 6)
	var b := StyleHouses.layout(12.0, 12.0, 6)
	assert_bool(a == b).is_true()
	var c := StyleHouses.layout(12.0, 12.0, 7)
	assert_bool(a[0]["w"] == c[0]["w"]).is_false()
	# Every house faces the alley: the back row (z < 0) faces +z, the front row faces -z.
	for h: Dictionary in a:
		var pos: Vector3 = h["pos"]
		var yaw: float = h["yaw"]
		assert_float(yaw).is_equal(0.0 if pos.z < 0.0 else PI)


func test_a_styled_block_builds_few_meshes_and_a_whimsical_one_on_demand() -> void:
	var s: Dictionary = await _start(true)
	var td: TopDownMain = s["td"]
	var look: BuildingLookStyled = null
	for node: Node in td.find_children("*", "BuildingLookStyled", true, false):
		var l := node as BuildingLookStyled
		if l.industrial != null:
			look = l
			break
	assert_object(look).is_not_null()
	assert_object(look.whimsical).is_null()
	var count := look.industrial.find_children("*", "MeshInstance3D", true, false).size()
	assert_int(count).is_equal(StyleHouses.mesh_count(true))
	look.whimsical = look._make_version(false)
	var whim := look.whimsical.find_children("*", "MeshInstance3D", true, false).size()
	assert_int(whim).is_equal(StyleHouses.mesh_count(false))
	await TopDownTestUtil.leave_loaded_scene(td)


# ---- The hedge and the gate ribbon ---------------------------------------------------------------------------------


func test_a_hedge_follows_a_wall_run_on_the_street_side_and_skips_the_map_edge_and_gates() -> void:
	var zone := Zone.new()
	var runs: Array[Dictionary] = zone.runs
	assert_int(StyleHedge.plan(runs).size()).is_equal(0)  # The start square alone is all gates.
	zone.take(Vector2i(3, 2))
	var plan := StyleHedge.plan(zone.runs)
	assert_int(plan.size()).is_greater(0)
	var block_rect := TownGrid.cell_rect(Vector2i(3, 2))
	for h: Dictionary in plan:
		var a: Vector2 = h["a"]
		var b: Vector2 = h["b"]
		# Outside the block, but within a metre or so of its face.
		assert_bool(block_rect.has_point((a + b) * 0.5)).is_false()
		assert_bool(block_rect.grow(StyleHedge.OFFSET + 0.1).has_point((a + b) * 0.5)).is_true()
	assert_bool(StyleHedge.on_map_edge(Vector2(57.0, -10.0), Vector2(57.0, 10.0))).is_true()
	assert_bool(StyleHedge.on_map_edge(Vector2(10.0, 6.0), Vector2(20.0, 6.0))).is_false()
	assert_int(StyleHedge.lamp_count(0.5)).is_equal(1)
	assert_int(StyleHedge.lamp_count(12.0)).is_equal(4)


func test_the_styled_ribbon_is_the_gates_alone_and_walls_grow_hedges() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var look := td.border.look as BorderLookStyled
	TopDownTestUtil.send_everyone_away(td)
	for i: int in range(8):
		var a := TAU * float(i) / 8.0
		var p := td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	await runner.simulate_frames(240)
	td.running = false
	assert_int(look._hedges.get_child_count()).is_equal(0)
	td.border.zone.take(Vector2i(3, 2))
	td.running = true
	await runner.simulate_frames(3)
	td.running = false
	look._last_frame = -100000
	look.refresh()
	assert_int(look._hedges.get_child_count()).is_greater(0)
	var sealed := 0
	for strip: EdgeStrip in look.gate_strips:
		for w: float in strip.seal:
			sealed += 1 if w > 0.99 else 0
	assert_int(sealed).is_equal(0)  # The ribbon is gates only.
	var all_sealed := 0
	for strip: EdgeStrip in look.strips:
		for w: float in strip.seal:
			all_sealed += 1 if w > 0.99 else 0
	assert_int(all_sealed).is_greater(0)  # The full ribbon still knows the walls.
	# Losing the block takes the hedges away again.
	td.border.zone.lose(Vector2i(3, 2))
	look._last_frame = -100000
	look.refresh()
	assert_int(look._hedges.get_child_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_draws_a_wall_in_its_own_colour() -> void:
	var styled := MinimapLookStyled.new()
	assert_bool(styled.seal_colour().is_equal_approx(styled.line_colour(false))).is_false()
	assert_bool(styled.seal_colour().is_equal_approx(styled.line_colour(true))).is_false()
	assert_int(styled.seal_width()).is_greater(1)


# ---- The take preview and the pips ---------------------------------------------------------------------------------


func test_the_pip_and_gate_spots_follow_the_cell_and_the_gate() -> void:
	var spots := StyleTake.pip_spots(Vector3(10.0, 0.0, 4.0), 3)
	assert_int(spots.size()).is_equal(3)
	assert_float(spots[1].x).is_equal_approx(10.0, 0.001)
	assert_float(spots[0].x).is_less(spots[2].x)
	var lamps := StyleTake.gate_spots(Vector2(0.0, 0.0), Vector2(12.0, 0.0))
	assert_int(lamps.size()).is_equal(7)
	assert_float(lamps[0].x).is_greater(0.0)
	assert_float(lamps[lamps.size() - 1].x).is_less(12.0)
	assert_int(StyleTake.gate_spots(Vector2.ZERO, Vector2(0.5, 0.0)).size()).is_equal(2)


func test_the_styled_take_preview_and_pips_are_beads_and_lanterns_and_clear_on_release() -> void:
	var s: Dictionary = await _start(true)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var take := td.take_block
	var c := TownGrid.neighbours(TownGrid.start_cell())[0]
	# A rescue in the cell fills one pip: three beads for that cell, one of them lit.
	td.border.pips.on_rescue(td.border.zone, TownGrid.cell_centre(c))
	await runner.simulate_frames(3)
	assert_bool(take._drawn_styled).is_true()
	var beads := take._styled_root.get_child_count()
	assert_int(beads).is_greater_equal(BorderConfig.TAKE_RESCUES)
	# Holding on the cell adds the glow, the corner lanterns and the gate lamps.
	take.holding = true
	take.target_cell = c
	take.preview = td.border.zone.preview(c, true)
	take._draw_all()
	assert_int(take._styled_root.get_child_count()).is_greater(beads + 8)
	take.holding = false
	take.preview = {}
	take.target_cell = TakeBlock.NO_CELL
	take._draw_all()
	assert_int(take._styled_root.get_child_count()).is_equal(beads)
	# Back in the placeholder look the styled parts are gone and the lines come back.
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(3)
	assert_bool(take._drawn_styled).is_false()
	assert_int(take._styled_root.get_child_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
