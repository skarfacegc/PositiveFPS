# gdlint: ignore=max-public-methods
extends GdUnitTestSuite

# Walls and gates: Pressure (#14). The night's one surge (it replaced the two gloom tides; the class is still
# GloomTide): it comes down one street, peaks at midnight, and has a warning (fog at the far end, a minimap mark, the
# edge pointer, the cooling light and a banner), a push on the gate it meets and the gates beside it, and an aftermath
# where arrivals ease. Times are set on the night's clock (night.elapsed) and update() is called directly, so nothing
# waits on frames. The recorder is pointed at a throw-away folder (as in recorder_test).

var _base: String = ""


func before_test() -> void:
	_base = "user://rec_tests/%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	Recorder.base_dir_override = _base
	Recorder.enabled = false
	Config.tides_override = 1  # The surge is off under automated tests unless a test turns it on (see Config.tides_on).


func after_test() -> void:
	Config.tides_override = -1
	Recorder.enabled = false
	Recorder.base_dir_override = ""
	TopDownTestUtil.close_open_recorders(get_tree().root)
	_remove_tree(_base)
	var rec_dir := DirAccess.open("user://rec_tests")
	if rec_dir != null:
		rec_dir.remove(_base.get_file())
	var user_dir := DirAccess.open("user://")
	if user_dir != null:
		user_dir.remove("rec_tests")


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_remove_tree(path.path_join(sub))
		dir.remove(sub)
	for f: String in dir.get_files():
		dir.remove(f)


# A level with everyone parked far away (so only what a test places can take part).
func _level() -> Array:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return [runner, td]


# Puts the night clock at `seconds` and runs the surge's update once (no frames, so nothing else moves).
func _at(td: TopDownMain, seconds: float) -> void:
	td.night.elapsed = seconds
	td.gloom_tide.update(0.0)


func _start(td: TopDownMain) -> float:
	var s: float = td.gloom_tide.surge["start"]
	return s


# A border that exists only as far as the surge cares: active, the start square's line traced, fully staffed.
func _pretend_border(td: TopDownMain) -> void:
	td.border.active = true
	td.border._trace()  # The start square's line, so the push has points for the surge to shove.
	td.border.polygon = td.border._base.duplicate()
	var needs: Array[int] = []
	for g: Dictionary in td.border.zone.gates:
		needs.append(g["need"])
	td.border._slots.gate_counts.assign(needs)


# --- The schedule ---------------------------------------------------------------------------------------------------


func test_the_surge_is_timed_to_peak_at_midnight() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var middle := _start(td) + NightConfig.SURGE_SECONDS * 0.5
	assert_float(middle / NightConfig.NIGHT_LENGTH).is_equal_approx(NightConfig.SURGE_PEAK_PROGRESS, 0.0001)
	assert_str(Recorder.phase_for(middle / NightConfig.NIGHT_LENGTH)).is_equal("midnight")
	# The warning is a whole warning long before the push and still comes after dusk.
	assert_float(_start(td) - NightConfig.SURGE_WARN_SECONDS).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_same_seed_gives_the_same_surge() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var first: Dictionary = td.gloom_tide.surge.duplicate(true)
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.1)
	var street_a: int = td.gloom_tide.surge["street"]
	await TopDownTestUtil.leave_loaded_scene(td)
	parts = await _level()
	td = parts[1]
	var roll_a: float = first["roll"]
	var roll_b: float = td.gloom_tide.surge["roll"]
	assert_float(roll_b).is_equal_approx(roll_a, 0.0001)
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.1)
	assert_int(td.gloom_tide.surge["street"]).is_equal(street_a)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_side_names_are_pure() -> void:
	assert_str(GloomTide.side_name(0.0)).is_equal("east")
	assert_str(GloomTide.side_name(PI)).is_equal("west")
	assert_str(GloomTide.side_name(-PI / 2.0)).is_equal("north")
	assert_str(GloomTide.side_name(PI / 2.0)).is_equal("south")


func test_there_are_sixteen_streets_each_running_in_from_the_edge_of_the_map() -> void:
	var all := GloomTide.streets()
	assert_int(all.size()).is_equal(16)
	var half := TownGrid.span() * 0.5
	var names: Dictionary = {}
	for s: Dictionary in all:
		var origin: Vector2 = s["origin"]
		var dir: Vector2 = s["dir"]
		assert_float(dir.length()).is_equal_approx(1.0, 0.0001)
		assert_float(maxf(absf(origin.x), absf(origin.y))).is_equal_approx(half, 0.0001)
		assert_float((Vector2.ZERO - origin).dot(dir)).is_greater(0.0)  # It runs toward the middle of the town.
		names[s["name"]] = true
	assert_int(names.size()).is_equal(8)  # Four vertical and four horizontal streets, each with a name.


func test_a_street_meets_the_first_gate_facing_it_that_it_runs_alongside() -> void:
	var zone := Zone.new()  # The start square: four 18 m gates.
	var all := GloomTide.streets()
	var meeting := 0
	for s: Dictionary in all:
		var hit := GloomTide.street_meets(s, zone.gates)
		var line: float = s["line"]
		# Only the streets beside the square (their middle 15 m out either side) meet one of its gates.
		var beside := absf(line) < 20.0
		assert_bool(not hit.is_empty()).is_equal(beside)
		if beside:
			meeting += 1
			var gate: Dictionary = zone.gates[hit["gate"]]
			var out: Vector2 = gate["out"]
			var dir: Vector2 = s["dir"]
			assert_float(out.dot(dir)).is_less(-0.99)
			assert_float(hit["along"]).is_equal_approx(TownGrid.span() * 0.5 - 9.0, 0.01)
	assert_int(meeting).is_equal(8)
	assert_int(GloomTide.candidates(zone.gates).size()).is_equal(8)


func test_a_street_meets_the_nearest_gate_when_the_zone_has_grown() -> void:
	var zone := Zone.new()
	zone.take(Vector2i(3, 2))  # The east cell: a street piece joins it to the start square.
	var all := GloomTide.streets()
	var from_north_east := {}
	for s: Dictionary in all:
		var line: float = s["line"]
		var dir: Vector2 = s["dir"]
		var vertical: bool = s["vertical"]
		if vertical and is_equal_approx(line, 15.0) and dir.y > 0.0:
			from_north_east = s
	var hit := GloomTide.street_meets(from_north_east, zone.gates)
	assert_bool(hit.is_empty()).is_false()
	var gate: Dictionary = zone.gates[hit["gate"]]
	# The street runs over the street piece that joins the two cells, so it meets that piece's mouth first.
	var mid: Vector2 = gate["mid"]
	assert_float(mid.x).is_equal_approx(15.0, 0.01)
	assert_float(mid.y).is_equal_approx(-9.0, 0.01)


# --- The warning, the push and the aftermath ------------------------------------------------------------------------


func test_the_warning_comes_forty_seconds_before_the_push() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS - 0.5)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.IDLE)
	assert_bool(td.minimap.surge_from == Vector2.INF).is_true()
	assert_bool(td.gloom_tide.fog.visible).is_false()
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.WARNING)
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	assert_int(td.intro.current).is_equal(Intro.Prompt.TIDE)
	assert_bool(td.minimap.surge_from == Vector2.INF).is_false()
	_at(td, start - NightConfig.SURGE_WARN_SECONDS * 0.5)
	assert_bool(td.gloom_tide.fog.visible).is_true()  # Fog has gathered at the far end of the street.
	_at(td, start - 0.1)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.WARNING)
	assert_float(td.gloom_tide.wave_force).is_equal(0.0)
	_at(td, start + 0.1)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.SURGE)
	assert_bool(td.gloom_tide.pointer.shown).is_false()
	_at(td, start + NightConfig.SURGE_SECONDS + 0.1)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.AFTERMATH)
	assert_bool(td.gloom_tide.fog.visible).is_false()
	assert_bool(td.minimap.surge_from == Vector2.INF).is_true()
	_at(td, start + NightConfig.SURGE_SECONDS + NightConfig.SURGE_AFTERMATH_SECONDS + 0.1)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.DONE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_banners_point_to_the_radar_without_naming_the_street_at_the_warning_again_and_at_the_start() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	assert_str(td.intro.current_text()).is_equal("The gloom is gathering: watch the radar")
	assert_str(td.intro.current_text()).is_equal(NightConfig.SURGE_WARN_TEXT)
	assert_bool(td.intro.coral).is_true()  # A slim banner under the night bar, wherever the player is.
	_at(td, start - NightConfig.SURGE_SOON_SECONDS + 0.1)
	assert_str(td.intro.current_text()).is_equal("The gloom is close: hold the marked gate")
	assert_str(td.intro.current_text()).is_equal(NightConfig.SURGE_SOON_TEXT)
	_at(td, start + 0.1)
	assert_str(td.intro.current_text()).is_equal("The gloom is surging in")
	assert_str(td.intro.current_text()).is_equal(NightConfig.SURGE_START_TEXT)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_warning_waits_while_the_zone_has_no_gate_for_a_street_to_meet() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	td.border.zone.gates.clear()
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.1)
	assert_int(td.gloom_tide.phase()).is_equal(GloomTide.Phase.IDLE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_chosen_street_meets_a_gate_and_the_pushed_gates_are_that_one_and_its_neighbours() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.1)
	var surge: Dictionary = td.gloom_tide.surge
	var gate: int = surge["gate"]
	assert_int(gate).is_greater_equal(0)
	var pushed: Dictionary = td.gloom_tide.pushed_gates()
	assert_float(pushed[gate]).is_equal(1.0)
	assert_int(pushed.size()).is_equal(3)  # The start square has four gates: the one it meets and the two beside it.
	var n := td.border.zone.gates.size()
	assert_float(pushed[posmod(gate + 1, n)]).is_equal(NightConfig.SURGE_SIDE_SHARE)
	assert_float(pushed[posmod(gate - 1, n)]).is_equal(NightConfig.SURGE_SIDE_SHARE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_surge_pushes_the_gate_it_meets_in_full_and_the_gates_beside_it_at_half() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	_pretend_border(td)
	var start := _start(td)
	_at(td, start - 1.0)
	assert_float(td.gloom_tide.wave_force).is_equal(0.0)
	_at(td, start + 0.5)  # The front is still far up the street: no shove yet.
	assert_float(td.gloom_tide.wave_force).is_equal(0.0)
	_at(td, start + NightConfig.SURGE_SECONDS * 0.5)
	assert_float(td.gloom_tide.wave_force).is_equal_approx(NightConfig.SURGE_PUSH, 0.001)
	var gate: int = td.gloom_tide.surge["gate"]
	var n := td.border.zone.gates.size()
	var met := _point_of_gate(td, gate)
	var beside := _point_of_gate(td, posmod(gate + 1, n))
	var across := _point_of_gate(td, posmod(gate + 2, n))
	assert_float(td.border.push.wave[met]).is_equal_approx(NightConfig.SURGE_PUSH, 0.001)
	assert_float(td.border.push.wave[beside]).is_equal_approx(
		NightConfig.SURGE_PUSH * NightConfig.SURGE_SIDE_SHARE, 0.001
	)
	assert_float(td.border.push.wave[across]).is_equal(0.0)
	_at(td, start + NightConfig.SURGE_SECONDS + 1.0)
	assert_float(td.border.push.wave[met]).is_equal(0.0)
	assert_float(td.gloom_tide.wave_force).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# A dentable point of gate `g`.
func _point_of_gate(td: TopDownMain, g: int) -> int:
	for i: int in range(td.border.point_count()):
		if td.border.point_gate(i) == g and td.border.point_dentable(i):
			return i
	return -1


func test_the_push_builds_as_the_front_arrives_and_fades_at_the_end() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.1)
	var start := _start(td)
	_at(td, start + 0.1)
	assert_float(td.gloom_tide.push_share()).is_equal(0.0)
	_at(td, start + NightConfig.SURGE_SECONDS * NightConfig.SURGE_ARRIVE * 0.8)
	var mid_build := td.gloom_tide.push_share()
	assert_float(mid_build).is_between(0.01, 0.99)
	_at(td, start + NightConfig.SURGE_SECONDS * 0.6)
	assert_float(td.gloom_tide.push_share()).is_equal(1.0)
	_at(td, start + NightConfig.SURGE_SECONDS * (1.0 - NightConfig.SURGE_FADE * 0.5))
	assert_float(td.gloom_tide.push_share()).is_between(0.01, 0.99)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_front_rolls_down_the_street_and_holds_just_past_the_gate() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - 1.0)
	assert_float(td.gloom_tide.front_distance()).is_equal_approx(NightConfig.TIDE_FOG_DEPTH, 0.01)
	var along: float = td.gloom_tide.surge["gate_along"]
	_at(td, start + NightConfig.SURGE_SECONDS * 0.1)
	var early := td.gloom_tide.front_distance()
	assert_float(early).is_greater(NightConfig.TIDE_FOG_DEPTH)
	assert_float(early).is_less(along)
	_at(td, start + NightConfig.SURGE_SECONDS * NightConfig.SURGE_ARRIVE)
	assert_float(td.gloom_tide.front_distance()).is_equal_approx(along + 1.5, 0.01)
	_at(td, start + NightConfig.SURGE_SECONDS * 0.8)
	assert_float(td.gloom_tide.front_distance()).is_equal_approx(along + 1.5, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fog_gathers_at_the_far_end_then_comes_down_the_street() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS * 0.5)
	var origin: Vector2 = td.gloom_tide.surge["origin"]
	var dir: Vector2 = td.gloom_tide.surge["dir"]
	var gathered := Vector2(td.gloom_tide.fog.position.x, td.gloom_tide.fog.position.z)
	assert_float(gathered.distance_to(origin + dir * NightConfig.TIDE_FOG_DEPTH * 0.5)).is_less(0.01)
	_at(td, start + NightConfig.SURGE_SECONDS * 0.4)
	var rolled := Vector2(td.gloom_tide.fog.position.x, td.gloom_tide.fog.position.z)
	assert_float((rolled - origin).dot(dir)).is_greater((gathered - origin).dot(dir) + 5.0)
	# It stays on the street's middle line.
	var line: float = GloomTide.streets()[td.gloom_tide.surge["street"]]["line"]
	var along_x := absf(dir.y) > 0.5  # A vertical street: its middle is an x.
	assert_float(rolled.x if along_x else rolled.y).is_equal_approx(line, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wave_comes_with_dark_figures_in_the_fog() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	assert_int(td.gloom_tide.figures.size()).is_equal(NightConfig.TIDE_FIGURES)
	var start := _start(td)
	_at(td, start + 3.0)
	var a := td.gloom_tide.figures[0].position
	_at(td, start + 3.4)
	assert_bool(td.gloom_tide.figures[0].position.is_equal_approx(a)).is_false()
	assert_bool(td.gloom_tide.figures[0].get_parent() == td.gloom_tide.fog).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_light_cools_through_the_warning_and_the_surge_and_warms_in_the_aftermath() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS - 1.0)
	assert_float(td.night.chill).is_equal(0.0)
	var plain := td.night.sun_color()
	_at(td, start - NightConfig.SURGE_WARN_SECONDS * 0.5)
	assert_float(td.night.chill).is_between(0.1, 0.9)
	_at(td, start + 10.0)
	assert_float(td.night.chill).is_equal(1.0)
	assert_bool(td.night.sun_color().is_equal_approx(plain)).is_false()
	_at(td, start + NightConfig.SURGE_SECONDS + NightConfig.SURGE_AFTERMATH_SECONDS * 0.5)
	assert_float(td.night.chill).is_between(0.1, 0.9)
	_at(td, start + NightConfig.SURGE_SECONDS + NightConfig.SURGE_AFTERMATH_SECONDS + 1.0)
	assert_float(td.night.chill).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_arrivals_ease_after_the_surge_and_come_back_to_normal() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start + 10.0)
	assert_float(td.night.arrival_ease).is_equal(1.0)
	_at(td, start + NightConfig.SURGE_SECONDS + 0.01)
	assert_float(td.night.arrival_ease).is_equal_approx(NightConfig.SURGE_AFTERMATH_GAP_MULT, 0.01)
	_at(td, start + NightConfig.SURGE_SECONDS + NightConfig.SURGE_AFTERMATH_SECONDS * 0.5)
	assert_float(td.night.arrival_ease).is_between(1.1, NightConfig.SURGE_AFTERMATH_GAP_MULT - 0.1)
	_at(td, start + NightConfig.SURGE_SECONDS + NightConfig.SURGE_AFTERMATH_SECONDS + 1.0)
	assert_float(td.night.arrival_ease).is_equal(1.0)
	# The dimmed-arrival gate waits longer in the aftermath.
	_at(td, start + NightConfig.SURGE_SECONDS + 1.0)
	td.dim_gate.clock = 1000.0
	td.dim_gate.last_sink = td.dim_gate.clock - NightCycle.dim_gap_at(td.night.progress()) * 1.2
	assert_bool(td.dim_gate.ask()).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The pointer, the minimap and the fog ---------------------------------------------------------------------------


func test_the_pointer_stays_inside_the_safe_rect() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	_at(td, _start(td) - NightConfig.SURGE_WARN_SECONDS + 0.1)
	td.gloom_tide.refresh_pointer()
	var screen := td.get_viewport().get_visible_rect().size
	var safe: Rect2 = HudSafeArea.current(td, screen)
	assert_bool(safe.size.x > 0.0).is_true()
	assert_bool(td.gloom_tide.pointer.shown).is_true()
	var tip: Vector2 = td.gloom_tide.pointer.tip
	# The tip sits on the edge of the shrunk rectangle (the ray leaves it there), and Rect2.has_point leaves out the far
	# edge, so the check allows a hair's breadth either side.
	var tips := safe.grow(-HudConfig.WOBBLE_ALERT_REACH).grow(0.01)
	assert_bool(safe.grow(0.01).has_point(tip)).is_true()
	assert_bool(tips.has_point(tip)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_mark_follows_the_street_and_the_front() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 0.1)
	var origin: Vector2 = td.gloom_tide.surge["origin"]
	var dir: Vector2 = td.gloom_tide.surge["dir"]
	assert_bool(td.minimap.surge_from.is_equal_approx(origin)).is_true()
	assert_bool(td.minimap.surge_dir.is_equal_approx(dir)).is_true()
	var gathering := td.minimap.surge_front
	_at(td, start + NightConfig.SURGE_SECONDS * 0.4)
	assert_float(td.minimap.surge_front).is_greater(gathering)
	_at(td, start + NightConfig.SURGE_SECONDS + 1.0)
	assert_bool(td.minimap.surge_from == Vector2.INF).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fog_is_thickest_in_the_surge_and_thin_in_the_warning() -> void:
	var parts := await _level()
	var td: TopDownMain = parts[1]
	var start := _start(td)
	assert_float(td.gloom_tide.fog_density()).is_equal(0.0)
	_at(td, start - 1.0)
	var warning := td.gloom_tide.fog_density()
	assert_float(warning).is_between(0.2, 0.5)
	_at(td, start + NightConfig.SURGE_SECONDS * 0.6)
	assert_float(td.gloom_tide.fog_density()).is_equal(1.0)
	_at(td, start + NightConfig.SURGE_SECONDS - 0.5)
	assert_float(td.gloom_tide.fog_density()).is_less(0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The recorder ---------------------------------------------------------------------------------------------------


func test_the_surge_events_go_to_the_recorder() -> void:
	Recorder.enabled = true
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	assert_object(td.recorder).is_not_null()
	var start := _start(td)
	_at(td, start - NightConfig.SURGE_WARN_SECONDS + 1.0)
	_at(td, start + 1.0)
	_at(td, start + NightConfig.SURGE_SECONDS + 1.0)
	var events := _events(td)
	var warns := _of_type(events, "surge_warn")
	var starts := _of_type(events, "surge_start")
	var ends := _of_type(events, "surge_end")
	assert_int(warns.size()).is_equal(1)
	assert_int(starts.size()).is_equal(1)
	assert_int(ends.size()).is_equal(1)
	var street: Dictionary = GloomTide.streets()[td.gloom_tide.surge["street"]]
	var street_name: String = street["name"]
	var end_name: String = street["end_name"]
	var warned_street: String = warns[0]["street"]
	var warned_side: String = warns[0]["side"]
	assert_str(warned_street).contains(street_name)
	assert_str(warned_side).is_equal(end_name)
	assert_bool(starts[0].has("members")).is_true()
	assert_bool(starts[0].has("gate")).is_true()
	assert_bool(ends[0].has("cells")).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_lost_cell_goes_to_the_recorder_with_its_gate_and_the_people_on_it() -> void:
	Recorder.enabled = true
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.last_loss = {"gate": 2, "members": 3, "need": 5, "seconds": 12.0}
	td.border.cells_lost.emit([Vector2i(3, 2)] as Array[Vector2i], 2)
	var lost := _of_type(_events(td), "cell_lost")
	assert_int(lost.size()).is_equal(1)
	assert_float(lost[0]["gate"]).is_equal(2.0)  # (Numbers come back from the file as floats.)
	assert_float(lost[0]["members"]).is_equal(3.0)
	assert_float(lost[0]["need"]).is_equal(5.0)
	assert_bool(lost[0]["surge"]).is_false()
	assert_float(lost[0]["cells"]).is_equal(float(td.border.zone.held.size()))
	await TopDownTestUtil.leave_loaded_scene(td)


# The parsed lines of the session's events file, after flushing what is buffered.
func _events(td: TopDownMain) -> Array[Dictionary]:
	td.recorder._flush()
	var out: Array[Dictionary] = []
	var file := FileAccess.open(td.recorder.events_path, FileAccess.READ)
	assert_object(file).is_not_null()
	while not file.eof_reached():
		var line := file.get_line()
		if line != "":
			out.append(JSON.parse_string(line))
	file.close()
	return out


func _of_type(events: Array[Dictionary], type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e: Dictionary in events:
		if e["type"] == type:
			out.append(e)
	return out
