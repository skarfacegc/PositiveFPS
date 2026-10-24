extends GdUnitTestSuite

# Round 7 cover: paint weight on the ground, protection from cover, edge-only darkness, joy contagion, the slower
# ground (painting in and fading back), partial joy that does not fade deep in cover, and the F3 debug overlay.
# (Round 8: own-paint exclusion, erosion and pursuit are in edge_pressure_test.gd.)
# Pure rules are called directly. The level tests (cover in the real top-down level, and the F3 key) drive the scene.


func _ground(size: int, spread: float, fade: float) -> PaintedGround:
	var g: PaintedGround = auto_free(PaintedGround.new())
	add_child(g)
	g.setup(size, spread, fade)
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


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Moves the mouse over the floor under `spot` and clicks there (lock-on).
func _click_at(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


# Runs `seconds` of gloom rules at a fixed step, with the cover values as they are set on the people.
func _run_gloom(people: Array[Person], seconds: float) -> void:
	var steps := roundi(seconds * 60.0)
	for i: int in range(steps):
		GloomSim.update(people, 1.0 / 60.0, Config.TD_DRAIN_MULTIPLIER)


# --- Ground paint weight -------------------------------------------------------------------------------------------


func test_fully_painted_area_averages_to_one() -> void:
	var g := _ground(10, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED)
	for i: int in range(100):
		g._weights[i] = 1.0
	assert_float(g.average_weight(Vector3.ZERO, Config.TD_COVER_RADIUS)).is_equal_approx(1.0, 0.001)
	assert_float(g.paint_weight_at(Vector3(1.2, 0.0, -2.3))).is_equal_approx(1.0, 0.001)


func test_the_edge_of_a_painted_area_averages_to_half() -> void:
	var size := 10
	var g := _ground(size, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED)
	# Paint the left half (x < 0) only. A disc centred on the boundary is half painted.
	var half := size / 2.0
	for ix: int in range(size):
		for iz: int in range(size):
			g._weights[ix * size + iz] = 1.0 if float(ix) < half else 0.0
	assert_float(g.average_weight(Vector3.ZERO, Config.TD_COVER_RADIUS)).is_equal_approx(0.5, 0.01)
	# Deep inside the painted side, and deep inside the unpainted side.
	assert_float(g.average_weight(Vector3(-3.0, 0.0, 0.0), 1.5)).is_equal_approx(1.0, 0.001)
	assert_float(g.average_weight(Vector3(3.0, 0.0, 0.0), 1.5)).is_equal_approx(0.0, 0.001)


func test_positions_outside_the_grid_have_no_paint() -> void:
	var g := _ground(10, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED)
	for i: int in range(100):
		g._weights[i] = 1.0
	assert_float(g.average_weight(Vector3(50.0, 0.0, 50.0), Config.TD_COVER_RADIUS)).is_equal(0.0)
	assert_float(g.paint_weight_at(Vector3(50.0, 0.0, 0.0))).is_equal(0.0)


func test_paint_weight_at_reads_the_tile_under_the_point() -> void:
	var g := _ground(10, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED)
	# Tile (ix 7, iz 2) is centred at x = 2.5, z = -2.5 on a 10 m grid.
	g._weights[7 * 10 + 2] = 0.6
	assert_float(g.paint_weight_at(Vector3(2.5, 0.0, -2.5))).is_equal_approx(0.6, 0.0001)
	assert_float(g.paint_weight_at(Vector3(2.5, 0.0, -1.5))).is_equal(0.0)


func test_a_rescued_person_paints_in_slowly_and_fades_back_slower_than_people_change() -> void:
	var tg := _ground(40, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED)
	var fg := _ground(40, Config.GROUND_PAINT_SPEED, Config.GROUND_PAINT_SPEED)
	var p := _person(0, Vector3.ZERO, 0.0, true)
	var people: Array = [p]
	# Each update is 0.1 s (GROUND_UPDATE_INTERVAL), so ten updates are one second.
	for i: int in range(10):
		tg.update_paint(people, 0.1)
		fg.update_paint(people, 0.1)
	# Top-down paints in more slowly: about 40% after a second, against about 80% at first-person speed.
	assert_float(tg.paint_weight_at(Vector3.ZERO)).is_less(0.5)
	assert_float(fg.paint_weight_at(Vector3.ZERO)).is_greater(0.75)
	for i: int in range(20):
		tg.update_paint(people, 0.1)
		fg.update_paint(people, 0.1)
	# Relapse: the person is grey again. Four seconds later the top-down ground is still well painted...
	p.is_rescued = false
	people = []
	for i: int in range(40):
		tg.update_paint(people, 0.1)
		fg.update_paint(people, 0.1)
	assert_float(tg.paint_weight_at(Vector3.ZERO)).is_greater(0.45)
	# ...while first-person ground has almost faded.
	assert_float(fg.paint_weight_at(Vector3.ZERO)).is_less(0.01)


# --- Protection and cover ------------------------------------------------------------------------------------------


func test_protection_is_zero_at_the_edge_and_one_deep_inside() -> void:
	assert_float(GloomSim.protection_for(0.0)).is_equal(0.0)
	assert_float(GloomSim.protection_for(Config.TD_COVER_EDGE)).is_equal(0.0)
	assert_float(GloomSim.protection_for(Config.TD_COVER_FULL)).is_equal(1.0)
	assert_float(GloomSim.protection_for(1.0)).is_equal(1.0)
	var middle := GloomSim.protection_for((Config.TD_COVER_EDGE + Config.TD_COVER_FULL) / 2.0)
	assert_float(middle).is_equal_approx(0.5, 0.001)
	assert_float(GloomSim.protection_for(0.5)).is_less(GloomSim.protection_for(0.7))


# --- Edge-only darkness --------------------------------------------------------------------------------------------


func test_dark_neighbour_cannot_drain_a_rescued_person_deep_in_cover() -> void:
	var rescued := _person(0, Vector3.ZERO, 0.0, true)
	var dark := _person(1, Vector3(2.0, 0.0, 0.0), 1.0)
	rescued.protection = 1.0
	var before := rescued.joy
	GloomSim.update([rescued, dark], 1.0, Config.TD_DRAIN_MULTIPLIER)
	assert_float(rescued.joy).is_equal_approx(before, 0.001)


func test_dark_neighbour_drains_a_rescued_person_at_the_edge_at_the_top_down_rate() -> void:
	var rescued := _person(0, Vector3.ZERO, 0.0, true)
	var dark := _person(1, Vector3(2.0, 0.0, 0.0), 1.0)
	rescued.protection = 0.0
	var before := rescued.joy
	GloomSim.update([rescued, dark], 1.0, Config.TD_DRAIN_MULTIPLIER)
	var lost := before - rescued.joy
	assert_float(lost).is_equal_approx(Config.SPREAD_DRAIN_RATE * Config.TD_DRAIN_MULTIPLIER, 0.01)


func test_darkness_spreads_to_unrescued_people_only_at_the_edges() -> void:
	var dark := _person(1, Vector3(0.0, 0.0, 0.0), 1.0)
	var deep := _person(0, Vector3(2.0, 0.0, 2.0), 0.2)
	var edge := _person(2, Vector3(-2.0, 0.0, 2.0), 0.2)
	deep.protection = 1.0
	deep.cover = 0.5  # Below the contagion threshold, so only the spread and growth rules act on it.
	edge.protection = 0.0
	edge.cover = 0.0
	GloomSim.update([dark, deep, edge], 1.0, Config.TD_DRAIN_MULTIPLIER)
	assert_float(deep.gloom).is_less_equal(0.2001)
	assert_float(edge.gloom).is_greater(0.2 + Config.SPREAD_GLOOM_RATE * 0.9)


# --- Joy contagion ------------------------------------------------------------------------------------------------


func test_contagion_lightens_a_dark_person_deep_in_cover_but_never_rescues_them() -> void:
	var p := _person(1, Vector3.ZERO, 0.8)
	p.cover = 0.9
	p.protection = 1.0
	var people: Array[Person] = [p]
	_run_gloom(people, 12.0)
	# 12 s at 0.034 per second takes 0.8 down to about 0.39: grey.
	assert_int(Config.gloom_level(p.gloom)).is_equal(1)
	_run_gloom(people, 10.0)
	assert_int(Config.gloom_level(p.gloom)).is_equal(0)
	_run_gloom(people, 10.0)
	# Floored at light grey (0), and never rescued or given joy by contagion.
	assert_float(p.gloom).is_equal(0.0)
	assert_bool(p.is_rescued).is_false()
	assert_float(p.joy).is_equal(0.0)


func test_outside_cover_gloom_grows_and_inside_cover_it_does_not() -> void:
	var outside := _person(0, Vector3(40.0, 0.0, 0.0), 0.3)
	outside.cover = 0.0
	outside.protection = 0.0
	var inside := _person(1, Vector3(-40.0, 0.0, 0.0), 0.3)
	inside.cover = 0.9
	inside.protection = 1.0
	var people: Array[Person] = [outside, inside]
	_run_gloom(people, 12.0)
	# Round 11: the grey -> dark step grows at 0.65 of the old rate, so 12 s from 0.3 is about 0.49 (was 0.5 or more).
	assert_float(outside.gloom).is_greater(0.45)
	# Inside cover, growth is off (the contagion only lowers gloom), so the gloom has gone down.
	assert_float(inside.gloom).is_less(0.3)


# --- Partial joy ----------------------------------------------------------------------------------------------------


func test_partial_joy_does_not_fade_deep_in_cover_but_fades_outside_it() -> void:
	var deep := _person(1, Vector3(0.0, 0.0, 0.0), 0.0)
	deep.protection = 1.0
	deep.receive_joy(0, 100.0, 0.0)  # Music on art: 1.5x, so 150 joy.
	var outside := _person(1, Vector3(5.0, 0.0, 0.0), 0.0)
	outside.protection = 0.0
	outside.receive_joy(0, 100.0, 0.0)
	for i: int in range(360):
		deep.tick(1.0 / 60.0)
		outside.tick(1.0 / 60.0)
	assert_float(deep.joy).is_equal_approx(150.0, 0.001)
	assert_float(outside.joy).is_less(150.0)


# --- Level tests (real top-down level, driven by real input where it matters) -----------------------------------------


func test_cover_and_protection_follow_the_painted_ground_in_the_level() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var rescued: Person = td.people[0]
	var grey: Person = td.people[1]
	var far: Person = td.people[2]
	TopDownTestUtil.place(rescued, Vector3(0, 0, -8), 0, 0.0)
	rescued.receive_joy(0, Config.JOY_MAX, 0.0)
	TopDownTestUtil.place(grey, Vector3(1, 0, -8), 1, 0.5)
	TopDownTestUtil.place(far, Vector3(-25, 0, 25), 2, 0.5)

	# Five seconds: the rescued person's ground paints in, so the grey person next to them is deep inside. Round 11: the
	# grey person wanders (0.92 m/s now, was 0.8), so in 5 s they walk to a new spot at the edge of the paint. Cover is
	# still well above the contagion threshold there, so the thresholds are looser than round 10.
	await runner.simulate_frames(300)
	assert_float(grey.cover).is_greater(0.5)
	assert_float(grey.protection).is_greater(0.2)
	assert_float(far.cover).is_less(0.01)
	assert_float(far.protection).is_equal(0.0)
	# Contagion has lightened the grey person (they are not rescued by it).
	assert_float(grey.gloom).is_less(0.5)
	assert_bool(grey.is_rescued).is_false()


func test_f3_toggles_the_cover_debug_labels_and_hint() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 1, 0.0)
	await runner.simulate_frames(2)
	# Off by default: no label is built and the HUD hint is hidden.
	assert_bool(td.debug_on).is_false()
	assert_object(p.debug_label).is_null()
	assert_bool(td.hud.debug_hint_label.visible).is_false()

	runner.simulate_key_pressed(KEY_F3)
	await runner.simulate_frames(2)
	assert_bool(td.debug_on).is_true()
	assert_bool(td.hud.debug_hint_label.visible).is_true()
	assert_bool(p.debug_label.visible).is_true()
	assert_str(p.debug_label.text).contains("c ")
	assert_str(p.debug_label.text).contains(" p ")

	runner.simulate_key_pressed(KEY_F3)
	await runner.simulate_frames(2)
	assert_bool(td.debug_on).is_false()
	assert_bool(td.hud.debug_hint_label.visible).is_false()
	assert_bool(p.debug_label.visible).is_false()
