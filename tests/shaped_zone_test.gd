extends GdUnitTestSuite

# Round 22: the shaped zone. A finished stretch keeps its arm (no snap); the next stretch grows from the shaped zone;
# the
# rescued head count limits how much border can be held (the preview refuses or limits a stretch with a plain reason);
# losing people pulls the arms in without collapsing the zone; the preview is the zone the stretch really makes. Also
# the
# readable refusals (a notice lasts at least 3.5 s, in a larger bar near the middle of the screen), the limited
# preview
# (thick red outline, reason beside the cursor) and the pulse that rewards gaining ground.

const PEOPLE := 24
const CENTRE := Vector3(-11.7, 0.0, -6.5)


func after_test() -> void:
	Config.intro_override = -1


func _radius() -> float:
	return BorderCentre.circle_radius(PEOPLE)


# A level with a settled border of 24 people round CENTRE, full spirit and nobody else about.
func _setup() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	var r := _radius()
	for i: int in range(PEOPLE):
		var a := TAU * float(i) / float(PEOPLE)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(600)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td}


# Stretches toward `spot` (placed by hand, as the E key does after its checks) and waits for the tip to arrive.
func _stretch(td: TopDownMain, runner: GdUnitSceneRunner, spot: Vector3) -> void:
	td.border.place_beacon(spot)
	var guard := 0
	while td.border.stretch_info()["on"] and guard < 60:
		await runner.simulate_frames(60)
		guard += 1
	await runner.simulate_frames(240)


func _max_radius(td: TopDownMain) -> float:
	var c2 := Vector2(CENTRE.x, CENTRE.z)
	var hi := 0.0
	for pt: Vector2 in td.border.polygon:
		hi = maxf(hi, pt.distance_to(c2))
	return hi


func _lose(td: TopDownMain, count: int) -> void:
	for i: int in range(count):
		var p: Person = td.people[i]
		TopDownTestUtil.lose_now(p)


func test_a_finished_stretch_keeps_its_arm_and_the_next_grows_from_the_shaped_zone() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var plain := _max_radius(td)
	await _stretch(td, runner, CENTRE + Vector3(0, 0, 21))
	assert_bool(td.border.stretch_info()["on"]).is_false()
	var south := _max_radius(td)
	assert_float(south).is_greater(plain + 2.0)
	# 30 s later the arm is still there: no snap back to a circle, and the centre never moved.
	await runner.simulate_frames(1800)
	assert_float(_max_radius(td)).is_equal_approx(south, 0.8)
	assert_float(GloomSim.flat_dist(td.border.centre, CENTRE)).is_less(0.8)
	# A second stretch the other way is a second arm; the first is still there.
	var c0 := td.border.centre
	await _stretch(td, runner, CENTRE + Vector3(0, 0, -21))
	var c2 := Vector2(c0.x, c0.z)
	var north := 0.0
	var south_now := 0.0
	for pt: Vector2 in td.border.polygon:
		if pt.y < c2.y:
			north = maxf(north, pt.distance_to(c2))
		else:
			south_now = maxf(south_now, pt.distance_to(c2))
	print("PROBE arms: north %.1f m, south %.1f m (was %.1f), circle %.1f m" % [north, south_now, south, plain])
	assert_float(north).is_greater(plain + 1.5)
	assert_float(south_now).is_greater(south - 1.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_second_stretch_starts_at_the_existing_arm() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _stretch(td, runner, CENTRE + Vector3(0, 0, 21))  # a short arm
	var arm_reach: float = td.border._centre_ctl.arm_reach_at(PI * 0.5, td.border.body_radius)
	assert_float(arm_reach).is_greater(_radius() + 0.5)
	td.border.place_beacon(CENTRE + Vector3(0, 0, 40))
	var tip: Vector3 = td.border.stretch_info()["tip"]
	assert_float(GloomSim.flat_dist(tip, CENTRE)).is_greater_equal(arm_reach - 0.1)
	await TopDownTestUtil.leave_loaded_scene(td)


# Merged: covers "the head count limits how much border can be held" and "the limited preview is a red outline with no
# words" (same border, same arm east; the preview's checks come before and just after the arm, the head count's go on to
# rescue more people).
func test_the_head_count_limits_the_border_and_the_limited_preview_is_a_red_outline_with_no_words() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(2)
	# A fine stretch (nothing holds it back) is the calm blue one. Round 24: no words while hovering.
	td.player._has_aim = true
	td.player._aim_point = CENTRE + Vector3(0, 0, _radius() + 6.0)
	TopDownTestUtil.press_e(td)  # Checkpoint 5 follow-up: the preview shows only while E is held.
	td.reach_guide.sync(td.border, td.player)
	assert_object(td.reach_guide._label).is_null()
	var fresh: Dictionary = td.border.plan_stretch(CENTRE + Vector3(-60, 0, 0))
	# Round 23: a far aim alone is no longer limited (it just goes as far as the people allow), so the limit here is an
	# arm east that uses up the length, and the cursor west of it (no frame runs between setting it and the guide's sync).
	await _stretch(td, runner, CENTRE + Vector3(60, 0, 0))
	td.player._aim_point = CENTRE + Vector3(-60, 0, 0)
	td.reach_guide.sync(td.border, td.player)
	var preview_plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	assert_str(preview_plan["reason"]).is_not_equal("")
	# Limited too: still no words (the reason shows only as a notice when E is pressed on a refused spot).
	if td.reach_guide._label != null:
		assert_bool(td.reach_guide._label.visible).is_false()
	assert_float(BeaconConfig.BEACON_LIMITED_OUTLINE_WIDTH).is_greater(BeaconConfig.BEACON_GUIDE_OUTLINE_WIDTH)
	assert_float(absf(BeaconConfig.BEACON_LIMITED_COLOUR.r - BeaconConfig.BEACON_GUIDE_PREVIEW_COLOUR.r)).is_greater(
		0.3
	)
	await runner.simulate_frames(20)
	var limited: Dictionary = td.border.plan_stretch(CENTRE + Vector3(-60, 0, 0))
	var f_reach: float = fresh["reach"]
	var l_reach: float = limited["reach"]
	print("PROBE reach west: fresh %.1f m, after an arm east %.1f m (%s)" % [f_reach, l_reach, limited["reason"]])
	assert_float(l_reach).is_less(f_reach - 1.0)
	assert_str(limited["reason"]).is_equal(BeaconConfig.BEACON_FULL_TEXT)
	# The loop the plan shows is never longer than the people can hold.
	var out: PackedVector2Array = limited["outline"]
	assert_float(BorderShape.perimeter_of(out)).is_less_equal(BorderCentre.budget_of(_radius()) * 1.01)
	# Rescuing more people allows more.
	for j: int in range(8):
		var p: Person = td.people[PEOPLE + j]
		var a := TAU * float(j) / 8.0
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * 4.0, 0.0, sin(a) * 4.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(60)
	var more: Dictionary = td.border.plan_stretch(CENTRE + Vector3(-60, 0, 0))
	var m_reach: float = more["reach"]
	print("PROBE reach west with 8 more people %.1f m" % m_reach)
	assert_float(m_reach).is_greater(l_reach + 1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_stretch_inside_the_zone_is_refused_with_a_reason_and_nothing_is_spent() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var plan: Dictionary = td.border.plan_stretch(CENTRE + Vector3(3, 0, 3))
	assert_bool(plan["refused"]).is_true()
	assert_str(plan["reason"]).is_equal(BeaconConfig.BEACON_INSIDE_TEXT)
	td.player._aim_point = CENTRE + Vector3(3, 0, 3)
	var before := td.player.spirit
	assert_bool(td.try_place_beacon()).is_false()
	assert_float(td.player.spirit).is_equal(before)
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_BLOCKED)
	assert_str(td.intro.current_text()).is_equal(BeaconConfig.BEACON_INSIDE_TEXT)
	assert_float(td.intro.time_left).is_greater_equal(3.5)
	assert_bool(td.intro.big).is_true()
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_losing_people_pulls_the_arms_in_without_collapsing_the_zone() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var pulled: Array[int] = [0]
	var shown: Array[float] = []
	var shrunk: Array[float] = []
	td.border.zone_pulling_in.connect(func() -> void: pulled[0] += 1)
	td.border.zone_pulling_in.connect(
		func() -> void:
			shown.append(float(td.intro.current))
			shown.append(td.intro.time_left)
	)
	td.border.zone_shrunk.connect(func(lost: float) -> void: shrunk.append(lost))
	await _stretch(td, runner, CENTRE + Vector3(0, 0, 40))
	var long_reach := _max_radius(td)
	var area0 := BorderCentre.polygon_area(td.border.polygon)
	assert_int(pulled[0]).is_equal(0)
	_lose(td, 10)
	await runner.simulate_frames(10)
	assert_int(td.rescued_count).is_equal(PEOPLE - 10)
	# Pulling in is gradual (not a jump), and it is announced when it starts.
	var waited := 0
	while pulled[0] == 0 and waited < 40:
		await runner.simulate_frames(60)
		waited += 1
	print("PROBE the pull-in began %d s after the loss" % waited)
	assert_int(pulled[0]).is_equal(1)
	assert_int(int(shown[0])).is_equal(Intro.Prompt.ZONE_PULLED_IN)
	assert_float(shown[1]).is_greater_equal(3.5)
	assert_float(_max_radius(td)).is_greater(long_reach * 0.5)
	await runner.simulate_frames(60 * 40)
	var now := _max_radius(td)
	var area1 := BorderCentre.polygon_area(td.border.polygon)
	var budget := BorderCentre.budget_of(BorderCentre.circle_radius(PEOPLE - 10))
	var perimeter := BorderShape.perimeter_of(td.border.polygon)
	print(
		(
			"PROBE pull-in: reach %.1f -> %.1f m, area %.0f -> %.0f, loop %.1f of %.1f"
			% [long_reach, now, area0, area1, perimeter, budget]
		)
	)
	assert_float(now).is_less(long_reach - 2.0)
	assert_bool(td.border.polygon.is_empty()).is_false()
	assert_float(area1).is_greater(area0 * 0.25)
	assert_float(area1).is_less(area0)
	# The border stays held: the loop is within its length (so no gaps from overextension).
	assert_float(perimeter).is_less_equal(budget * (1.0 + BeaconConfig.BEACON_PULL_IN_TOLERANCE + 0.05))
	assert_int(shrunk.size()).is_greater_equal(1)
	assert_float(shrunk[0]).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_preview_matches_the_zone_a_second_stretch_makes() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _stretch(td, runner, CENTRE + Vector3(0, 0, 12))
	var aim := CENTRE + Vector3(-20, 0, -8)
	var plan: Dictionary = td.border.plan_stretch(aim)
	var outline: PackedVector2Array = plan["outline"]
	var reach: float = plan["reach"]
	var landed: Array[Vector3] = []
	td.border.zone_grew.connect(func(_g: float, tip: Vector3, _a: float) -> void: landed.append(tip))
	td.border.place_beacon(aim)
	await runner.simulate_frames(60 * 22)
	assert_int(landed.size()).is_equal(1)
	assert_float(GloomSim.flat_dist(landed[0], CENTRE)).is_equal_approx(reach, 0.4)
	var c2 := Vector2(CENTRE.x, CENTRE.z)
	var poly := td.border.polygon
	assert_int(poly.size()).is_equal(outline.size())
	var total := 0.0
	var worst := 0.0
	for i: int in range(poly.size()):
		var d := absf(poly[i].distance_to(c2) - outline[i].distance_to(c2))
		total += d
		worst = maxf(worst, d)
	var mean := total / float(poly.size())
	print("PROBE shaped preview vs real: mean %.2f m, worst %.2f m (reach %.1f)" % [mean, worst, reach])
	assert_float(mean).is_less(1.2)
	assert_float(worst).is_less(3.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_profile_helpers_keep_the_loop_length() -> void:
	var r := 10.0
	var none: Array[Vector2] = []
	var circle := BorderCentre.profile(r, none, 0.0, 0.0)
	assert_int(circle.size()).is_equal(RoundLoopConfig.BORDER_SAMPLES)
	assert_float(BorderCentre.profile_perimeter(circle)).is_equal_approx(BorderCentre.budget_of(r), 0.001)
	var arms: Array[Vector2] = [Vector2(0.0, 20.0)]
	var body := BorderCentre.body_for_arms(r, arms, 0.0, PI)
	assert_float(body).is_less_equal(r)
	assert_float(body).is_greater_equal(r * BeaconConfig.BEACON_BODY_MIN)
	var squeezed := BorderCentre.profile(body, arms, 0.0, PI)
	if body > r * BeaconConfig.BEACON_BODY_MIN + 0.01:
		assert_float(BorderCentre.profile_perimeter(squeezed)).is_equal_approx(BorderCentre.budget_of(r), 0.2)
	# New ground counts only what lies outside the old zone.
	var before: Array[float] = [10.0, 10.0, 10.0, 10.0]
	var after: Array[float] = [10.0, 12.0, 9.0, 10.0]
	assert_float(BorderCentre.new_ground(before, after)).is_equal_approx((144.0 - 100.0) * 0.5 * TAU / 4.0, 0.001)
	assert_float(BorderCentre.polygon_area(PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(4, 3)]))).is_equal(
		6.0
	)


func test_refusals_last_long_enough_to_read_and_ordinary_prompts_do_not() -> void:
	var intro := Intro.new(null, false)
	intro.notice(Intro.Prompt.BEACON_SPIRIT)
	assert_float(intro.time_left).is_greater_equal(3.5)
	assert_float(HudConfig.NOTICE_SECONDS).is_greater_equal(3.5)
	assert_bool(intro.coral).is_true()
	assert_str(intro.current_text()).is_equal(BeaconConfig.BEACON_NO_SPIRIT_TEXT)
	intro.update(3.4)
	assert_int(intro.current).is_equal(Intro.Prompt.BEACON_SPIRIT)
	intro.update(0.7)
	assert_int(intro.current).is_equal(-1)
	assert_bool(intro.coral).is_false()
	# An ordinary prompt keeps PROMPT_SECONDS and the small bar.
	var lesson := Intro.new(null, true)
	lesson.request(Intro.Prompt.DIM_HELP)
	assert_float(lesson.time_left).is_equal(HudConfig.PROMPT_SECONDS)
	assert_bool(lesson.coral).is_false()
	assert_str(lesson.current_text()).is_equal(PeopleConfig.DIM_HELP_TEXT)
	# Words of its own.
	intro.notice(Intro.Prompt.BEACON_BLOCKED, "Because")
	assert_str(intro.current_text()).is_equal("Because")


func test_a_notice_is_a_slim_banner_centred_in_the_top_half_of_the_screen() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.intro.notice(Intro.Prompt.BEACON_BLOCKED, BeaconConfig.BEACON_FULL_TEXT)
	await runner.simulate_frames(30)
	var bar: PromptBar = td.prompts
	var screen := td.get_viewport().get_visible_rect()
	assert_bool(bar.big).is_true()
	assert_str(bar.text).is_equal(BeaconConfig.BEACON_FULL_TEXT)
	assert_float(bar._rect.size.y).is_equal(HudConfig.NOTICE_HEIGHT)
	assert_float(bar._rect.get_center().x).is_equal_approx(screen.size.x * 0.5, 2.0)
	assert_float(bar._rect.position.y).is_less(screen.size.y * 0.5)
	assert_float(bar.alpha).is_greater(0.9)
	# Three and a half seconds on, it is still up.
	await runner.simulate_frames(60 * 3)
	assert_float(bar.alpha).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_gaining_ground_pulses_along_the_new_arm_and_says_how_much() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var grown: Array[float] = []
	td.border.zone_grew.connect(func(gain: float, _t: Vector3, _a: float) -> void: grown.append(gain))
	td.border.place_beacon(CENTRE + Vector3(0, 0, 40))
	var guard := 0
	while grown.is_empty() and guard < 40:
		await runner.simulate_frames(30)
		guard += 1
	assert_int(grown.size()).is_equal(1)
	assert_float(grown[0]).is_greater(10.0)
	await runner.simulate_frames(10)
	var guide: ReachGuide = td.reach_guide
	assert_float(guide._pulse_left).is_greater(0.0)
	assert_object(guide._gain_label).is_not_null()
	assert_bool(guide._gain_label.visible).is_true()
	assert_str(guide._gain_label.text).is_equal(BeaconConfig.BEACON_GAIN_TEXT % int(roundf(grown[0])))
	assert_int(guide._mesh.get_surface_count()).is_greater_equal(1)
	await runner.simulate_frames(int(BeaconConfig.BEACON_PULSE_SECONDS * 60.0) + 30)
	assert_float(guide._pulse_left).is_equal(0.0)
	assert_bool(guide._gain_label.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)
