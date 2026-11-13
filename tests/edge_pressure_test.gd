extends GdUnitTestSuite

# Round 8 edge pressure, in the real top-down level and on the painted ground: a rescued person's own paint does not
# protect them, a lone rescued person is at risk at the edge (and a person in a group is not), gloom erodes the
# edge of paint (interior tiles are immune, and eroded tiles are held), and dimmed people chase the weakest point.
# Rescues are made by joy (receive_joy), and the level is driven with real frames. Pure paint rules are called on a
# PaintedGround directly.


# `keep` (when 0 or more): the people beyond the first `keep` are dropped (see TopDownTestUtil.trim_crowd).
func _start(keep: int = -1) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	if keep >= 0:
		TopDownTestUtil.trim_crowd(runner.scene() as TopDownMain, keep)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


func _ground(size: int, erodes: bool) -> PaintedGround:
	var g: PaintedGround = auto_free(PaintedGround.new())
	add_child(g)
	g.setup(size, GroundConfig.TD_GROUND_SPREAD_SPEED, GroundConfig.TD_GROUND_FADE_SPEED, erodes)
	return g


func _person(affinity: int, pos: Vector3, gloom: float, rescued: bool = false) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = affinity
	p.gloom = gloom
	add_child(p)
	p.global_position = pos
	if rescued:
		p.receive_joy(affinity, Config.JOY_MAX, 0.0)
	return p


# Runs `updates` paint updates (each one is GROUND_UPDATE_INTERVAL, so the paint runs once per call).
func _paint_updates(g: PaintedGround, people: Array, updates: int) -> void:
	for i: int in range(updates):
		g.update_paint(people, GroundConfig.GROUND_UPDATE_INTERVAL)


# --- Own paint does not protect -----------------------------------------------------------------------------------


func test_a_lone_rescued_person_gets_no_protection_from_their_own_paint() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var lone: Person = td.people[0]
	TopDownTestUtil.place(lone, Vector3(0, 0, -8), 0, 0.0)
	lone.receive_joy(0, Config.JOY_MAX, 0.0)

	# Seven seconds: the lone person's ground is fully painted, but all of it is their own paint.
	await runner.simulate_frames(420)
	assert_float(td.ground.paint_weight_at(lone.global_position)).is_greater(0.9)
	assert_float(lone.cover).is_less(0.01)
	assert_float(lone.protection).is_less(0.01)


# Round 9: three rescued people form the border and stand on its line. Protection inside the line is depth, so a
# member on the line has none. (Round 8 paint cover still applies before a border forms: see cover_test.gd.)
func test_border_members_on_the_line_have_no_protection() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var centre: Person = td.people[0]
	TopDownTestUtil.place(centre, Vector3(0, 0, -8), 0, 0.0)
	centre.receive_joy(0, Config.JOY_MAX, 0.0)
	var left: Person = td.people[1]
	TopDownTestUtil.place(left, Vector3(-2, 0, -8), 1, 0.0)
	left.receive_joy(1, Config.JOY_MAX, 0.0)
	var right: Person = td.people[2]
	TopDownTestUtil.place(right, Vector3(2, 0, -8), 2, 0.0)
	right.receive_joy(2, Config.JOY_MAX, 0.0)

	await runner.simulate_frames(300)
	assert_int(td.border.member_count).is_equal(3)
	assert_float(centre.protection).is_less(0.1)
	assert_float(centre.cover).is_less(0.1)


func test_cover_excluding_own_paint_matches_others_paint_on_the_ground() -> void:
	# Pure rule: two rescued people, one painted tile each side. Excluding one leaves only the other's paint.
	var g := _ground(20, false)
	var a := _person(0, Vector3(-3, 0, 0), 0.0, true)
	var b := _person(1, Vector3(3, 0, 0), 0.0, true)
	var people: Array = [a, b]
	_paint_updates(g, people, 150)
	var all_cover := g.average_weight(Vector3.ZERO, GroundConfig.TD_COVER_RADIUS)
	var excl_a := g.average_weight_excluding(Vector3.ZERO, GroundConfig.TD_COVER_RADIUS, a)
	var excl_b := g.average_weight_excluding(Vector3.ZERO, GroundConfig.TD_COVER_RADIUS, b)
	assert_float(all_cover).is_greater(0.3)
	# Both paint the centre about equally, so each one's cover without their own paint is still about half.
	assert_float(excl_a).is_greater(0.2)
	assert_float(excl_b).is_greater(0.2)
	assert_float(excl_a).is_less_equal(all_cover + 0.001)
	# Someone who painted nothing leaves nothing out.
	var nobody := _person(2, Vector3(50, 0, 50), 0.0)
	assert_float(g.average_weight_excluding(Vector3.ZERO, GroundConfig.TD_COVER_RADIUS, nobody)).is_equal_approx(
		all_cover, 0.001
	)


# --- Edge relapse risk ---------------------------------------------------------------------------------------------


func test_a_lone_rescued_person_next_to_a_dimmed_person_relapses_within_a_bounded_time() -> void:
	var s: Dictionary = await _start(2)  # Slowest tests (#88): only the two people used are kept.
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var lone: Person = td.people[0]
	TopDownTestUtil.place(lone, Vector3(0, 0, -8), 0, 0.0)
	lone.receive_joy(0, Config.JOY_MAX, 0.0)
	var dimmed: Person = td.people[1]
	TopDownTestUtil.place(dimmed, Vector3(2, 0, -8), 1, 0.9)
	# Round 10: the calm opening (grey strength 0.2) slows the drain, so this runs at midnight, where it was tuned.
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0

	# Grace first, then the drain (about 24 joy a second) takes them below half their joy: about 25 seconds in all.
	var frames := 0
	while lone.is_rescued and frames < 2400:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(lone.is_rescued).is_false()
	assert_int(frames).is_less(2400)


# Round 9: a dimmed person outside the border presses against its line. It cannot get inside, however long it stays.
func test_a_dimmed_person_outside_the_border_cannot_get_inside_it() -> void:
	var s: Dictionary = await _start(9)  # Slowest tests (#88): only the nine people used are kept.
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	target.receive_joy(0, Config.JOY_MAX, 0.0)
	var group: Array[Person] = [target]
	# Round 19: the centre no longer drifts, so the line must hold by itself: six members round the radius-4.3 minimum loop
	# leave no gap (four did, and only the old drifting centre moved the loop away from the dimmed person).
	var spots: Array[Vector3] = [
		Vector3(2, 0, -8),
		Vector3(-1, 0, -6),
		Vector3(-1, 0, -10),
		Vector3(-2, 0, -8),
		Vector3(1, 0, -6),
	]
	for i: int in range(spots.size()):
		var p: Person = td.people[i + 1]
		TopDownTestUtil.place(p, spots[i], (i + 1) % 3, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
		group.append(p)
	# The dimmed person joins once the group's border is in.
	var dimmed: Person = td.people[8]
	TopDownTestUtil.place(dimmed, Vector3(-25, 0, 25), 1, 0.0)
	await runner.simulate_frames(360)
	# In the street north of the start square (its gate is z = -9).
	TopDownTestUtil.place(dimmed, Vector3(0, 0, -13), 1, 0.9)

	await runner.simulate_frames(2400)
	# The press drains a member, so the count may drop; the line is what matters here.
	assert_bool(BorderShape.is_inside(td.border.polygon, Vector2(dimmed.position.x, dimmed.position.z))).is_false()


func test_a_dimmed_person_at_the_edge_erodes_the_edge_tiles_next_to_them() -> void:
	var g := _ground(40, true)
	var lone := _person(0, Vector3.ZERO, 0.0, true)
	var people: Array = [lone]
	# Ten seconds: the paint is in. The tile at (4.5, 0.5) is on the edge (about 0.67).
	_paint_updates(g, people, 100)
	var edge_before := g.paint_weight_at(Vector3(4.5, 0.0, 0.5))
	assert_float(edge_before).is_greater(0.5)

	var dimmed := _person(1, Vector3(4.0, 0.0, 0.0), 0.9)
	people.append(dimmed)
	_paint_updates(g, people, 30)
	# Three seconds of gloom: the edge tile is eaten away.
	assert_float(g.paint_weight_at(Vector3(4.5, 0.0, 0.5))).is_less(edge_before - 0.3)


func test_a_dimmed_person_deep_inside_the_paint_erodes_nothing_within_reach() -> void:
	var g := _ground(40, true)
	var lone := _person(0, Vector3.ZERO, 0.0, true)
	var people: Array = [lone]
	_paint_updates(g, people, 100)
	# Deep inside: the dimmed person is 1 m from the centre, so the tile at (2.5, 0.5) is within their 2 m reach. Every
	# tile round them is interior (weight >= 0.9 with painted neighbours), so it is immune. (4.5, 0.5) is out of reach.
	var dimmed := _person(1, Vector3(1.0, 0.0, 0.0), 0.9)
	people.append(dimmed)
	_paint_updates(g, people, 30)
	assert_float(g.paint_weight_at(Vector3(2.5, 0.0, 0.5))).is_greater(0.95)
	assert_float(g.paint_weight_at(Vector3(4.5, 0.0, 0.5))).is_greater(0.5)


func test_an_eroded_tile_does_not_regrow_for_the_hold_time() -> void:
	var g := _ground(40, true)
	var lone := _person(0, Vector3.ZERO, 0.0, true)
	# Round 13a: the paint disc is bigger, so the dimmed person stands at the edge of it (4 m x WORLD_SCALE).
	var dimmed := _person(1, Vector3(5.7, 0.0, 0.0), 0.9)
	var people: Array = [lone, dimmed]
	_paint_updates(g, people, 100)
	_paint_updates(g, people, 30)
	var tile := Vector3(6.5, 0.0, 0.5)
	var eroded := g.paint_weight_at(tile)
	assert_float(eroded).is_less(0.01)

	# The dimmed person leaves. For the hold time (3 s, 30 updates) the eroded tile does not grow back.
	people = [lone]
	_paint_updates(g, people, 20)
	assert_float(g.paint_weight_at(tile)).is_less_equal(eroded + 0.001)
	# Once the hold has run out, paint grows back there again.
	_paint_updates(g, people, 20)
	assert_float(g.paint_weight_at(tile)).is_greater(eroded + 0.01)


func test_a_tile_at_the_grid_corner_is_interior_only_if_its_neighbours_are_painted() -> void:
	var g := _ground(10, true)
	for i: int in range(100):
		g._weights[i] = 1.0
	# The corner has only three neighbours inside the grid, and they are all painted.
	assert_bool(g._is_interior(0, 0)).is_true()
	g._weights[1] = 0.5  # Tile (0, 1), a neighbour of the corner, is only half painted.
	assert_bool(g._is_interior(0, 0)).is_false()


func test_erosion_only_runs_when_the_ground_is_set_to_erode() -> void:
	# With erosion off (a plain ground), a dimmed neighbour does not take paint away.
	var g := _ground(40, false)
	var lone := _person(0, Vector3.ZERO, 0.0, true)
	var dimmed := _person(1, Vector3(4.0, 0.0, 0.0), 0.9)
	var people: Array = [lone]
	_paint_updates(g, people, 100)
	var before := g.paint_weight_at(Vector3(4.5, 0.0, 0.5))
	people.append(dimmed)
	_paint_updates(g, people, 30)
	assert_float(g.paint_weight_at(Vector3(4.5, 0.0, 0.5))).is_greater(before - 0.05)


# --- Weakest-point pursuit -----------------------------------------------------------------------------------------


func test_a_dimmed_person_with_nobody_to_chase_drifts_to_the_territory_edge() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var rescued: Person = td.people[0]
	TopDownTestUtil.place(rescued, Vector3(-33, 0, -33), 0, 0.0)
	rescued.receive_joy(0, Config.JOY_MAX, 0.0)
	var dimmed: Person = td.people[1]
	# 66 m from the rescued person along the same street (0.4: the blocks are solid, so a straight walk needs a street
	# and the diagonal is not one), well outside the pursuit search radius.
	TopDownTestUtil.place(dimmed, Vector3(33, 0, -33), 0, 0.9)

	await runner.simulate_frames(150)
	assert_bool(td.ground.has_edge()).is_true()
	var before := dimmed.global_position.distance_to(rescued.global_position)
	assert_bool(td.pursuit_assignments(td.people).has(dimmed)).is_false()
	await runner.simulate_frames(60)
	assert_float(dimmed.global_position.distance_to(rescued.global_position)).is_less(before - 0.5)
