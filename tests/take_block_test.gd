# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Walls and gates: Take a block (E, #10) and rescues pull the line (#11), in the real top-down level. Hold E, point at a
# cell beside the zone, release to take it: free when its pips are full, else for spirit; refused (slim banner) only
# when spirit is short. People never refuse a take. Right-click cancels. Rescues fill the pips of the cell they belong
# to; a cell never joins by itself. Most rescues are direct (receive_joy); the E hold, the release and the cancel go
# through real key and mouse events.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# Rescues `p` directly at `spot` (a joy hit that is always enough).
func _rescue(p: Person, spot: Vector3) -> void:
	TopDownTestUtil.place(p, spot, p.affinity, 0.0)
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# Rescues the first `count` people on a ring of radius `r` around `c`: enough members for the start square's gates.
func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		_rescue(td.people[i], c + Vector3(cos(a) * r, 0.0, sin(a) * r))


# The cell beside the start square (the first one that shares a street with it).
func _neighbour() -> Vector2i:
	return TownGrid.neighbours(TownGrid.start_cell())[0]


# Moves the cursor so the player aims at the ground of cell `c`, and lets a physics frame read it.
func _point_at(runner: GdUnitSceneRunner, td: TopDownMain, c: Vector2i) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, TownGrid.cell_centre(c)))
	await runner.simulate_frames(3)


# Holds E on cell `c`, lets a few frames pass, then releases it.
func _hold_e_on(runner: GdUnitSceneRunner, td: TopDownMain, c: Vector2i) -> void:
	await _point_at(runner, td, c)
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(3)


# Fills all the pips of cell `c` with direct rescues (people 40 and up, which the tests above do not use).
func _fill_pips(td: TopDownMain, c: Vector2i) -> void:
	for i: int in range(BorderConfig.TAKE_RESCUES):
		_rescue(td.people[40 + i], TownGrid.cell_centre(c))


func test_holding_e_on_a_cell_beside_the_zone_takes_it_for_spirit() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 30)
	await runner.simulate_frames(120)
	var c := _neighbour()
	td.player.spirit = 80.0
	await _hold_e_on(runner, td, c)
	assert_bool(td.border.zone.has(c)).is_true()
	assert_bool(td.take_block.holding).is_false()
	assert_float(td.player.spirit).is_equal_approx(80.0 - BorderConfig.TAKE_SPIRIT_COST, 0.01)


func test_take_is_refused_when_spirit_is_short() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 20)
	await runner.simulate_frames(120)
	var c := _neighbour()
	td.player.spirit = BorderConfig.TAKE_SPIRIT_COST - 1.0
	await _hold_e_on(runner, td, c)
	assert_bool(td.border.zone.has(c)).is_false()
	assert_float(td.player.spirit).is_equal_approx(BorderConfig.TAKE_SPIRIT_COST - 1.0, 0.01)
	assert_int(td.intro.current).is_equal(Intro.Prompt.SPIRIT_LOW)
	assert_bool(td.intro.coral).is_true()


func test_people_never_refuse_a_take_even_with_nobody_rescued() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	var refusals: Array[String] = []
	td.take_block.refused.connect(func(reason: String, _info: Dictionary) -> void: refusals.append(reason))
	await _hold_e_on(runner, td, _neighbour())
	assert_bool(td.border.zone.has(_neighbour())).is_true()
	assert_float(td.player.spirit).is_equal_approx(80.0 - BorderConfig.TAKE_SPIRIT_COST, 0.01)
	assert_array(refusals).is_empty()
	# The banner says so, warm rather than coral.
	assert_bool(td.intro.coral).is_false()
	assert_str(td.intro.current_text()).contains("people")


func test_right_click_cancels_a_take() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 20)
	await runner.simulate_frames(120)
	var c := _neighbour()
	td.player.spirit = 80.0
	await _point_at(runner, td, c)
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	assert_bool(td.take_block.holding).is_true()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(2)
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(3)
	assert_bool(td.take_block.holding).is_false()
	assert_bool(td.border.zone.has(c)).is_false()
	assert_float(td.player.spirit).is_equal_approx(80.0, 0.01)


func test_rescues_fill_pips_and_a_full_cell_never_joins_by_itself() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	var spot := TownGrid.cell_centre(c)
	var ready_cells: Array[Vector2i] = []
	td.border.pips.cell_ready.connect(func(cell: Vector2i) -> void: ready_cells.append(cell))
	_rescue(td.people[0], spot)
	await runner.simulate_frames(2)
	assert_int(td.border.pips.filled(c)).is_equal(1)
	assert_bool(td.border.pips.is_ready(c)).is_false()
	_rescue(td.people[1], spot)
	await runner.simulate_frames(2)
	assert_int(td.border.pips.filled(c)).is_equal(2)
	_rescue(td.people[2], spot)
	await runner.simulate_frames(200)
	assert_int(td.border.pips.filled(c)).is_equal(BorderConfig.TAKE_RESCUES)
	assert_bool(td.border.pips.is_ready(c)).is_true()
	assert_bool(td.border.zone.has(c)).is_false()  # Ready, but only E takes it.
	assert_array(ready_cells).is_equal([c])
	# A fourth rescue changes nothing and does not announce the cell again.
	_rescue(td.people[3], spot)
	await runner.simulate_frames(2)
	assert_int(td.border.pips.filled(c)).is_equal(BorderConfig.TAKE_RESCUES)
	assert_array(ready_cells).has_size(1)


func test_taking_a_ready_cell_with_e_is_free() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	_fill_pips(td, c)
	await runner.simulate_frames(2)
	td.player.spirit = 10.0  # Not enough for a paid take: a free one does not care.
	var taken: Array[Dictionary] = []
	td.take_block.taken.connect(func(info: Dictionary) -> void: taken.append(info))
	await _hold_e_on(runner, td, c)
	assert_bool(td.border.zone.has(c)).is_true()
	assert_float(td.player.spirit).is_equal_approx(10.0, 0.01)
	assert_array(taken).has_size(1)
	assert_bool(taken[0]["free"] as bool).is_true()
	assert_float(taken[0]["spirit_paid"] as float).is_equal(0.0)
	assert_bool(td.border.pips.counts.has(c)).is_false()  # The pips go with the cell.
	assert_str(td.intro.current_text()).contains("ready")


func test_a_paid_take_reports_free_false_and_the_spirit_paid() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 60.0
	var taken: Array[Dictionary] = []
	td.take_block.taken.connect(func(info: Dictionary) -> void: taken.append(info))
	assert_bool(td.take_block.take_now(_neighbour())).is_true()
	await runner.simulate_frames(2)
	assert_bool(taken[0]["free"] as bool).is_false()
	assert_float(taken[0]["spirit_paid"] as float).is_equal(BorderConfig.TAKE_SPIRIT_COST)


func test_a_held_cell_and_a_far_cell_are_ignored_with_their_own_reasons() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	var refusals: Array[String] = []
	td.take_block.refused.connect(func(reason: String, _info: Dictionary) -> void: refusals.append(reason))
	assert_bool(td.take_block.take_now(TownGrid.start_cell())).is_false()
	assert_bool(td.take_block.take_now(Vector2i(0, 0))).is_false()
	assert_array(refusals).is_equal(["already_held", "not_next"])
	assert_float(td.player.spirit).is_equal_approx(80.0, 0.01)


func test_pips_are_cleared_when_their_cell_joins_or_is_no_longer_beside_the_zone() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	_rescue(td.people[0], TownGrid.cell_centre(c))
	await runner.simulate_frames(2)
	assert_bool(td.border.pips.counts.has(c)).is_true()
	# The cell joins by another route (a take through the zone): its pip goes with it.
	td.border.zone.take(c)
	await runner.simulate_frames(2)
	assert_bool(td.border.pips.counts.has(c)).is_false()
	# A pip on a cell that is not beside the zone is cleared by prune.
	var far := Vector2i(-1, -1)
	for cell: Vector2i in TownGrid.all_cells():
		if not td.border.zone.has(cell) and not td.border.zone.can_take(cell):
			far = cell
			break
	assert_bool(far == Vector2i(-1, -1)).is_false()
	var pips := RescuePips.new()
	pips.counts[far] = 1
	pips.prune(td.border.zone)
	assert_bool(pips.counts.has(far)).is_false()


func test_takeable_cells_are_marked_free_or_paid_and_unaffordable_ones_are_not() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	var other := TownGrid.neighbours(TownGrid.start_cell())[1]
	td.player.spirit = 80.0
	assert_int(td.take_block.mark_of(c)).is_equal(TakeBlock.Mark.PAID)
	assert_int(td.take_block.mark_of(Vector2i(0, 0))).is_equal(TakeBlock.Mark.NONE)  # Not beside the zone.
	assert_int(td.take_block.mark_of(TownGrid.start_cell())).is_equal(TakeBlock.Mark.NONE)  # Held.
	_fill_pips(td, c)
	await runner.simulate_frames(2)
	assert_int(td.take_block.mark_of(c)).is_equal(TakeBlock.Mark.FREE)
	assert_int(td.take_block.mark_of(other)).is_equal(TakeBlock.Mark.PAID)
	td.player.spirit = 5.0
	assert_int(td.take_block.mark_of(other)).is_equal(TakeBlock.Mark.NONE)  # Cannot afford it now.
	assert_int(td.take_block.mark_of(c)).is_equal(TakeBlock.Mark.FREE)  # Ready is free whatever the spirit.
	var rects := td.take_block.mark_rects()
	assert_int(rects.size()).is_equal(1)
	assert_bool(rects[0]["free"] as bool).is_true()
	(
		assert_bool(
			(rects[0]["rect"] as Rect2).has_point(Vector2(TownGrid.cell_centre(c).x, TownGrid.cell_centre(c).z))
		)
		. is_true()
	)


func test_the_marks_reach_the_minimap_and_the_ground() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self, true)  # The minimap refreshes itself.
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.spirit = 80.0
	await runner.simulate_frames(20)
	assert_int(td.minimap.take_marks.size()).is_equal(TownGrid.neighbours(TownGrid.start_cell()).size())
	# Free cells and paid cells draw as different surfaces on the ground (a filled quad each, two triangles).
	var c := _neighbour()
	_fill_pips(td, c)
	await runner.simulate_frames(20)
	var free_count := 0
	for tm: Dictionary in td.minimap.take_marks:
		if tm["free"] as bool:
			free_count += 1
	assert_int(free_count).is_equal(1)
	assert_int(td.take_block._mesh.get_surface_count()).is_greater_equal(2)


func test_the_preview_says_what_the_cell_costs_and_the_people_it_needs_against_the_free_ones() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 12)
	await runner.simulate_frames(10)
	var c := _neighbour()
	td.player.spirit = 80.0
	await _point_at(runner, td, c)
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	var needed: int = td.take_block.preview["members_needed"]
	assert_int(needed).is_equal(13)  # Loop tuning (#93): was 23 at 3.7 m.
	var text := td.take_block.preview_text()
	var added: int = (td.take_block.preview["gates"] as Array).size() - td.border.zone.gates.size()
	var word := "gate" if absi(added) == 1 else "gates"
	assert_str(text).contains("%+d %s: 1 more people" % [added, word])  # 13 needed, 12 free (was 11 more of 23).
	assert_str(text).contains("25 spirit")
	assert_bool(td.take_block._label.visible).is_true()
	assert_object(td.take_block._label.modulate).is_equal(BorderConfig.GATE_COUNT_SHORT_COLOUR)  # 12 free < 23 needed.
	runner.simulate_key_release(KEY_E)
	await runner.simulate_frames(3)
	assert_bool(td.take_block._label.visible).is_false()


func test_the_preview_says_covered_when_spare_people_cover_the_new_gates() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, Vector3.ZERO, 3.0, 60)
	await runner.simulate_frames(10)
	var c := _neighbour()
	td.player.spirit = 80.0
	await _point_at(runner, td, c)
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	assert_str(td.take_block.preview_text()).contains("covered by spare people")
	assert_str(td.take_block.preview_text()).not_contains("more people")
	assert_object(td.take_block._label.modulate).is_equal(BorderConfig.GATE_COUNT_OK_COLOUR)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(2)
	runner.simulate_key_release(KEY_E)


func test_the_preview_counts_a_single_new_gate_in_the_singular() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var have := td.border.zone.gates.size()
	td.take_block.target_cell = _neighbour()
	var one_more: Array[Dictionary] = []
	one_more.resize(have + 1)
	td.take_block.preview = {"valid": true, "members_needed": 0, "gates": one_more}
	assert_str(td.take_block.preview_text()).contains("+1 gate: covered")
	var same: Array[Dictionary] = []
	same.resize(have)
	td.take_block.preview = {"valid": true, "members_needed": 0, "gates": same}
	assert_str(td.take_block.preview_text()).contains("+0 gates: covered")
	td.take_block.preview = {}
	assert_str(td.take_block.preview_text()).is_equal("")


func test_every_cell_beside_the_zone_shows_its_pips_and_a_free_or_paid_tag() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	var other := TownGrid.neighbours(TownGrid.start_cell())[1]
	td.player.spirit = 80.0
	assert_str(td.take_block.cell_label_text(c)).is_equal("25\n0/3")
	assert_str(td.take_block.cell_label_text(Vector2i(0, 0))).is_equal("")  # Not beside the zone.
	assert_str(td.take_block.cell_label_text(TownGrid.start_cell())).is_equal("")  # Held.
	_fill_pips(td, c)
	await runner.simulate_frames(5)
	assert_str(td.take_block.cell_label_text(c)).is_equal("Free\n3/3")
	td.player.spirit = 5.0
	assert_str(td.take_block.cell_label_text(other)).is_equal("0/3")  # No tag when it cannot be taken now.
	await runner.simulate_frames(5)
	# A label floats over each of the cells beside the zone, with the same text.
	for n: Vector2i in TownGrid.neighbours(TownGrid.start_cell()):
		var label: Label3D = td.take_block._cell_labels[n]
		assert_str(label.text).is_equal(td.take_block.cell_label_text(n))
	assert_object((td.take_block._cell_labels[c] as Label3D).modulate).is_equal(
		Color(BorderConfig.TAKE_MARK_FREE_COLOUR, 1.0)
	)
	assert_object((td.take_block._cell_labels[other] as Label3D).modulate).is_equal(
		DefenceConfig.CAPTURE_LABEL_NONE_COLOUR
	)
	td.player.spirit = 80.0
	await runner.simulate_frames(5)
	assert_object((td.take_block._cell_labels[other] as Label3D).modulate).is_equal(
		Color(BorderConfig.TAKE_MARK_PAID_COLOUR, 1.0)
	)
	# Taking the cell removes its label.
	assert_bool(td.take_block.take_now(c)).is_true()
	await runner.simulate_frames(5)
	assert_bool(td.take_block._cell_labels.has(c)).is_false()


func test_a_free_cell_is_filled_and_a_paid_cell_is_an_outline() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var quad: Array = []
	var frame: Array = []
	var rect := TownGrid.cell_rect(_neighbour())
	td.take_block._add_quad(quad, rect)
	td.take_block._add_frame(frame, rect)
	assert_int(quad.size()).is_equal(6)  # One filled square: two triangles.
	assert_int(frame.size()).is_equal(24)  # Four strips: eight triangles.
	# The frame leaves the middle of the cell open.
	var centre := TownGrid.cell_centre(_neighbour())
	for i: int in range(0, frame.size(), 3):
		var tri_min_x := minf(minf((frame[i] as Vector3).x, (frame[i + 1] as Vector3).x), (frame[i + 2] as Vector3).x)
		var tri_max_x := maxf(maxf((frame[i] as Vector3).x, (frame[i + 1] as Vector3).x), (frame[i + 2] as Vector3).x)
		var tri_min_z := minf(minf((frame[i] as Vector3).z, (frame[i + 1] as Vector3).z), (frame[i + 2] as Vector3).z)
		var tri_max_z := maxf(maxf((frame[i] as Vector3).z, (frame[i + 1] as Vector3).z), (frame[i + 2] as Vector3).z)
		var covers_centre := (
			tri_min_x < centre.x and tri_max_x > centre.x and tri_min_z < centre.z and tri_max_z > centre.z
		)
		assert_bool(covers_centre).is_false()
	assert_float(TakeBlock.PIP_HALF).is_greater(0.35)  # Larger pips (#75).


func test_a_ready_cell_reads_free_in_the_preview() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	_fill_pips(td, c)
	await _point_at(runner, td, c)
	runner.simulate_key_press(KEY_E)
	await runner.simulate_frames(3)
	assert_str(td.take_block.preview_text()).starts_with("Free")
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	await runner.simulate_frames(2)
	runner.simulate_key_release(KEY_E)


func test_a_taken_cell_pulses_for_a_moment() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	var c := _neighbour()
	assert_bool(td.take_block.is_pulsing(c)).is_false()
	assert_bool(td.take_block.take_now(c)).is_true()
	assert_bool(td.take_block.is_pulsing(c)).is_true()
	await runner.simulate_frames(int(BorderConfig.TAKE_PULSE_SECONDS * 60.0) + 20)
	assert_bool(td.take_block.is_pulsing(c)).is_false()
