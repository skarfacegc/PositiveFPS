# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Walls and gates: Take a block (E, #10) and rescues pull the line (#11), in the real top-down level. Hold E, point at a
# cell beside the zone, release to take it for spirit. Refused (slim banner) when spirit or people are short;
# right-click cancels. Rescues fill the pips of the cell they belong to; at BorderConfig.TAKE_RESCUES the cell joins.
# Most rescues are direct (receive_joy); the E hold, the release and the cancel go through real key and mouse events.


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


func test_take_is_refused_when_the_gates_need_more_members_than_there_are() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	await _hold_e_on(runner, td, _neighbour())
	assert_bool(td.border.zone.has(_neighbour())).is_false()
	assert_float(td.player.spirit).is_equal_approx(80.0, 0.01)
	assert_int(td.intro.current).is_equal(Intro.Prompt.SPIRIT_LOW)


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


func test_rescues_fill_pips_and_the_third_joins_the_cell_by_itself() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var c := _neighbour()
	var spot := TownGrid.cell_centre(c)
	_rescue(td.people[0], spot)
	await runner.simulate_frames(2)
	assert_int(td.border.pips.filled(c)).is_equal(1)
	assert_bool(td.border.zone.has(c)).is_false()
	_rescue(td.people[1], spot)
	await runner.simulate_frames(2)
	assert_int(td.border.pips.filled(c)).is_equal(2)
	assert_bool(td.border.zone.has(c)).is_false()
	_rescue(td.people[2], spot)
	await runner.simulate_frames(2)
	assert_bool(td.border.zone.has(c)).is_true()
	assert_bool(td.border.pips.counts.has(c)).is_false()


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
