extends GdUnitTestSuite

# Round 24 (part H): things react. A patch makes the border people at that spot hop, turn toward it and glow; a burst
# makes each lifted person hop and glow; the F and G cues sit on the HUD beside the spirit meter and glow when ready;
# the reach preview has no words while hovering (a refusal shows only as a small notice on E); a pull-in retreats one
# arm at a time with its outline fading first; and one landmark is within the first arm's reach of the start.

const PEOPLE := 24
const CENTRE := Vector3(-11.7, 0.0, -6.5)


func after_test() -> void:
	Config.intro_override = -1


func _border_level(count: int, r: float) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = Config.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	return {"runner": runner, "td": td}


# A level with a settled border of PEOPLE people round CENTRE, full spirit and nobody else about.
func _zone_level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	var r := BorderCentre.circle_radius(PEOPLE)
	for i: int in range(PEOPLE):
		var a := TAU * float(i) / float(PEOPLE)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(600)
	td.player.add_spirit(100.0)
	return {"runner": runner, "td": td}


func _stretch(td: TopDownMain, runner: GdUnitSceneRunner, spot: Vector3) -> void:
	td.border.place_beacon(spot)
	var guard := 0
	while td.border.stretch_info()["on"] and guard < 60:
		await runner.simulate_frames(60)
		guard += 1
	await runner.simulate_frames(240)


# --- A patch makes people react -------------------------------------------------------------------------------------


func test_a_person_who_is_not_reacting_has_no_progress() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var td: TopDownMain = s["td"]
	for p: Person in td.people:
		assert_int(p.react_kind).is_equal(Person.React.NONE)
		assert_float(p.react_progress()).is_equal(-1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_reacting_person_hops_turns_toward_the_spot_glows_then_settles() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	var m: Person = td.border.members[4]
	var look := m.look as PersonLookPlaceholder
	# Something off to one side to turn toward.
	var spot := m.position + Vector3(0.0, 0.0, 2.0)
	m.react(Person.React.PATCH, Config.REACT_PATCH_SECONDS, spot)
	var top := 0.0
	var turned := 0.0
	var glowed := false
	for _i: int in range(int(Config.REACT_PATCH_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, look.visual.position.y)
		turned = maxf(turned, absf(look.visual.rotation.y))
		glowed = glowed or look.body_mat.emission_enabled
	assert_float(top).is_greater(Config.REACT_PATCH_HOP_HEIGHT * 0.5)
	assert_float(turned).is_greater(0.2)
	assert_bool(glowed).is_true()
	# Afterwards the body is put back.
	await runner.simulate_frames(20)
	assert_int(m.react_kind).is_equal(Person.React.NONE)
	assert_float(look.visual.position.y).is_equal(0.0)
	assert_float(look.visual.rotation.y).is_equal(0.0)
	assert_bool(look.body_mat.emission_enabled).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_waiting_reaction_does_not_pose_the_body_until_its_turn() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[2]
	m.react(Person.React.PATCH, 1.0, m.position + Vector3.RIGHT, 0.5)
	assert_float(m.react_progress()).is_equal(-1.0)
	await runner.simulate_frames(10)
	assert_float(m.look.visual.position.y).is_equal(0.0)
	await runner.simulate_frames(40)
	assert_float(m.react_progress()).is_greater_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- A burst makes the lifted people perk up ------------------------------------------------------------------------


# Merged: covers "the grace glow still works when no one is reacting" (no frames, so it goes first) and "a burst makes
# each lifted person hop and glow warm" (same border level).
func test_the_grace_glow_works_when_no_one_reacts_and_a_burst_makes_each_lifted_person_hop_and_glow_warm() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var glow_look := td.people[20].look as PersonLookPlaceholder
	glow_look._set_glow(1.0)
	assert_bool(glow_look.body_mat.emission_enabled).is_true()
	assert_float(glow_look.body_mat.emission_energy_multiplier).is_equal_approx(Config.GRACE_GLOW_ENERGY, 0.001)
	glow_look._set_react_glow(Config.PATCH_COLOUR, 1.0)
	assert_bool(glow_look.body_mat.emission.is_equal_approx(Config.PATCH_COLOUR)).is_true()
	glow_look._set_react_glow(Color.WHITE, 0.0)
	assert_bool(glow_look.body_mat.emission.is_equal_approx(Config.GRACE_GLOW_COLOR)).is_true()
	glow_look._set_glow(0.0)
	assert_bool(glow_look.body_mat.emission_enabled).is_false()
	var lifted: Person = td.people[20]
	var other: Person = td.people[21]
	var cleared: Array[Dictionary] = [{"person": lifted, "from": lifted.position, "to": lifted.position}]
	td.burst_cue._on_burst_cleared({"cleared": cleared, "lifted": 1, "joy_hits": 0})
	assert_int(lifted.react_kind).is_equal(Person.React.LIFT)
	assert_int(other.react_kind).is_equal(Person.React.NONE)
	var look := lifted.look as PersonLookPlaceholder
	var top := 0.0
	var warm := false
	for _i: int in range(int(Config.REACT_LIFT_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, look.visual.position.y)
		warm = (
			warm or (look.body_mat.emission_enabled and look.body_mat.emission.is_equal_approx(Config.BURST_FX_COLOUR))
		)
	assert_float(top).is_greater(Config.REACT_LIFT_HOP_HEIGHT * 0.5)
	assert_bool(warm).is_true()
	await runner.simulate_frames(20)
	assert_float(look.visual.position.y).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_styled_look_hops_and_turns_in_a_reaction_and_settles() -> void:
	# Graphics checkpoint 5: the styled look reacts too (its bodies face the other way, so the turn is added to PI).
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	m.react(Person.React.PATCH, Config.REACT_PATCH_SECONDS, m.position + Vector3.RIGHT * 3.0)
	var top := 0.0
	var turned := 0.0
	for _i: int in range(int(Config.REACT_PATCH_SECONDS * 60.0) - 2):
		await runner.simulate_frames(1)
		top = maxf(top, m.look.visual.position.y)
		turned = maxf(turned, absf(m.look.visual.rotation.y - PI))
	assert_float(top).is_greater(Config.REACT_PATCH_HOP_HEIGHT * 0.5)
	assert_float(turned).is_greater(0.2)
	await runner.simulate_frames(20)
	assert_float(m.look.visual.position.y).is_equal(0.0)
	assert_float(m.look.visual.rotation.y).is_equal_approx(PI, 0.0001)
	# The base look's glow hook does nothing (only the placeholder and styled looks glow).
	var base: PersonLook = auto_free(PersonLook.new())
	base._set_react_glow(Config.PATCH_COLOUR, 1.0)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The cues are on the HUD beside the spirit meter ----------------------------------------------------------------


func test_the_cue_sits_right_of_the_spirit_meter_and_glows_when_it_is_ready() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	td.player.burst_cooldown = 0.0
	td.burst_cue.burst_targets = 2
	td.burst_cue._update_label()
	var label := td.burst_cue.cue_label
	var screen := td.get_viewport().get_visible_rect().size
	assert_bool(label.visible).is_true()
	assert_bool(td.burst_cue.cue_ready).is_true()
	assert_str(label.text).is_equal(Config.CUE_BURST_TEXT % 2)
	assert_float(label.position.x).is_greater(screen.x * 0.5 + Config.SPIRIT_METER_WIDTH * 0.5)
	assert_float(label.position.y).is_greater(screen.y * 0.7)
	var ready_edge := (label.get_theme_stylebox("normal") as StyleBoxFlat).border_color
	assert_float(ready_edge.a).is_greater(0.5)
	# Nobody to lift: the cue goes (and stops glowing).
	td.burst_cue.burst_targets = 0
	td.burst_cue._update_label()
	assert_bool(label.visible).is_false()
	assert_bool(td.burst_cue.cue_ready).is_false()
	await runner.simulate_frames(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- A quiet reminder -----------------------------------------------------------------------------------------------


func test_hovering_shows_no_words_a_refusal_shows_only_on_e_and_the_pull_in_retreats_calmly_or_hurries() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _zone_level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(2)
	# Hover on a spot inside the zone (it would be refused): no label, no notice, however long it stays there.
	td.player._has_aim = true
	td.player._aim_point = CENTRE + Vector3(1.0, 0.0, 1.0)
	TopDownTestUtil.press_e(td)  # Checkpoint 5 follow-up: the preview shows only while E is held.
	await runner.simulate_frames(120)
	td.reach_guide.sync(td.border, td.player)
	assert_bool(td.reach_guide._label == null or not td.reach_guide._label.visible).is_true()
	assert_bool(td.intro.coral).is_false()
	var plan: Dictionary = td.border.plan_stretch(td.player.aim_point())
	assert_bool(plan["refused"]).is_true()
	# Pressing E on it shows the one small notice with the reason, and spends nothing.
	var spirit := td.player.spirit
	assert_bool(td.try_place_beacon()).is_false()
	assert_int(td.intro.current).is_equal(Intro.Prompt.BEACON_BLOCKED)
	assert_bool(td.intro.coral).is_true()
	assert_float(td.player.spirit).is_equal(spirit)
	# Merged below (no frames run in these parts, and they set the arms themselves, so they go last): "one arm retreats
	# at a time, the longest first, after its outline fades" and "a loop far over its length hurries and skips the fade".
	var ctl := _centre_ctl(td)
	var step := 1.0 / 60.0
	# While it fades, nothing walks in, and the fade deepens.
	var alpha_early := 1.0
	var tip_mid := td.border.centre + Vector3(cos(0.0), 0.0, sin(0.0)) * 12.0
	var seg_a := Vector2(tip_mid.x, tip_mid.z)
	for i: int in range(60):
		ctl.pull_in(step, 5.0, 1.05)
		if i == 5:
			alpha_early = ctl.outline_alpha(seg_a, seg_a + Vector2(0.0, 1.0))
	assert_bool(ctl.is_retreating()).is_true()
	assert_float(ctl.retreat_angle()).is_equal(0.0)
	assert_float(ctl.arms[0].y).is_equal(20.0)
	assert_float(ctl.arms[1].y).is_equal(16.0)
	var alpha_late := ctl.outline_alpha(seg_a, seg_a + Vector2(0.0, 1.0))
	assert_float(alpha_late).is_less(alpha_early)
	assert_float(alpha_late).is_greater_equal(Config.BEACON_PULL_FADE_ALPHA - 0.001)
	# A stretch of the outline on the far side, or inside the body, is not faded.
	var behind := Vector2(td.border.centre.x - 12.0, td.border.centre.z)
	assert_float(ctl.outline_alpha(behind, behind + Vector2(0.0, 1.0))).is_equal(1.0)
	var inside := Vector2(td.border.centre.x + 1.0, td.border.centre.z)
	assert_float(ctl.outline_alpha(inside, inside + Vector2(0.0, 0.5))).is_equal(1.0)
	# After the fade only the longest arm walks in, slowly; the others hold.
	for _i: int in range(120):
		ctl.pull_in(step, 5.0, 1.05)
	assert_float(ctl.arms[0].y).is_less(20.0)
	assert_float(ctl.arms[0].y).is_greater(20.0 - Config.BEACON_PULL_CALM_RATE * 2.2)
	assert_float(ctl.arms[1].y).is_equal(16.0)
	assert_float(ctl.arms[2].y).is_equal(12.0)
	# When it has reached the body it is gone, and the next arm is the one that fades and retreats.
	var guard := 0
	while ctl.arms.size() == 3 and guard < 3000:
		ctl.pull_in(step, 5.0, 1.05)
		guard += 1
	assert_int(ctl.arms.size()).is_equal(2)
	ctl.pull_in(step, 5.0, 1.05)
	assert_float(ctl.retreat_angle()).is_equal(2.0)
	assert_float(ctl.arms[0].y).is_equal(16.0)
	# An arm taken away mid-retreat (a new stretch merged it) is dropped from the plan: the longest one is picked again.
	ctl.arms = [Vector2(5.0, 14.0), Vector2(4.0, 19.0)]
	ctl.pull_in(step, 5.0, 1.05)
	assert_float(ctl.retreat_angle()).is_equal(4.0)
	# Settling ends the retreat and clears the fade.
	ctl.settled()
	assert_bool(ctl.is_retreating()).is_false()
	assert_float(ctl.outline_alpha(seg_a, seg_a + Vector2(0.0, 1.0))).is_equal(1.0)
	# A loop far over its length hurries and skips the fade (a fresh set of arms).
	ctl = _centre_ctl(td)
	# Over by the urgent ratio: the arm starts walking at once, at the urgent speed.
	ctl.pull_in(step, 5.0, Config.BEACON_PULL_URGENT_RATIO + 0.05)
	var y0 := ctl.arms[0].y
	assert_float(y0).is_less(20.0)
	for _i: int in range(60):
		ctl.pull_in(step, 5.0, Config.BEACON_PULL_URGENT_RATIO + 0.05)
	var walked := y0 - ctl.arms[0].y
	assert_float(walked).is_equal_approx(Config.BEACON_PULL_CALM_RATE * Config.BEACON_PULL_URGENT_MULT, 0.2)
	assert_float(Config.BEACON_PULL_URGENT_RATIO).is_less(Config.BORDER_MAX_GAP / Config.BORDER_TARGET_SPACING)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_no_world_text_can_fill_the_view_and_the_notice_is_small() -> void:
	# What filled the screen in the round 23 playtest: the limited-preview reason was a Label3D (default font 32, pixel
	# size 0.035 m) with BEACON_FULL_TEXT, a 71-character line about 40 m wide, more than the whole 19.5 m view height.
	var font := ThemeDB.fallback_font
	var old_width := font.get_string_size(Config.BEACON_FULL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x * 0.035
	assert_float(old_width).is_greater(Config.TD_CAMERA_ORTHO_SIZE)
	# Now the only world label of the preview is "Stretching", a few metres.
	var now_width := (
		font.get_string_size("Stretching", HORIZONTAL_ALIGNMENT_LEFT, -1, 32).x * Config.BEACON_GUIDE_LABEL_SIZE
	)
	assert_float(now_width).is_less(Config.TD_CAMERA_ORTHO_SIZE * 0.15)
	assert_int(Config.NOTICE_FONT_SIZE).is_less_equal(16)
	assert_float(Config.NOTICE_HEIGHT).is_less_equal(34.0)
	# The notice bar for the longest refusal is a fraction of a 1280 px window.
	var bar := (
		font.get_string_size(Config.BEACON_FULL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, Config.NOTICE_FONT_SIZE).x + 90.0
	)
	assert_float(bar).is_less(1280.0 * 0.8)


# --- A calm pull-in -------------------------------------------------------------------------------------------------


func _centre_ctl(td: TopDownMain) -> BorderCentre:
	var ctl: BorderCentre = td.border._centre_ctl
	td.border.body_radius = 5.0
	ctl.arms = [Vector2(0.0, 20.0), Vector2(2.0, 16.0), Vector2(4.0, 12.0)]
	return ctl


func test_losing_people_pulls_the_arms_in_one_at_a_time_and_keeps_the_spacing_held() -> void:
	var s: Dictionary = await _zone_level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _stretch(td, runner, CENTRE + Vector3(24.0, 0.0, 0.0))
	await _stretch(td, runner, CENTRE + Vector3(0.0, 0.0, 24.0))
	var ctl: BorderCentre = td.border._centre_ctl
	var arms0 := ctl.arms.size()
	assert_int(arms0).is_greater_equal(2)
	var reach0 := 0.0
	for a: Vector2 in ctl.arms:
		reach0 += a.y
	for i: int in range(5):
		var p: Person = td.people[i]
		p.grace_left = 0.0
		p.drain_joy(1.0e6)
	# Watch the arms every half second: at most one of them shrinks in any interval.
	var last: Dictionary[float, float] = {}
	for a: Vector2 in ctl.arms:
		last[a.x] = a.y
	var most := 0
	var worst_spacing := 0.0
	for _i: int in range(90):
		await runner.simulate_frames(30)
		var shrinking := 0
		for a: Vector2 in ctl.arms:
			if last.has(a.x) and last[a.x] - a.y > 0.02:
				shrinking += 1
		most = maxi(most, shrinking)
		last = {}
		for a: Vector2 in ctl.arms:
			last[a.x] = a.y
		if td.border.member_count > 0:
			var spacing := BorderShape.perimeter_of(td.border.polygon) / float(td.border.member_count)
			worst_spacing = maxf(worst_spacing, spacing)
	var reach1 := 0.0
	for a: Vector2 in ctl.arms:
		reach1 += a.y
	print(
		(
			"PROBE pull-in: arms %d -> %d, summed reach %.1f -> %.1f, worst spacing %.2f m"
			% [arms0, ctl.arms.size(), reach0, reach1, worst_spacing]
		)
	)
	assert_int(most).is_less_equal(1)
	assert_float(reach1).is_less(reach0)
	assert_float(worst_spacing).is_less_equal(Config.BORDER_MAX_GAP)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_placeholder_border_line_fades_along_the_retreating_arm() -> void:
	var s: Dictionary = await _zone_level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	await _stretch(td, runner, CENTRE + Vector3(60.0, 0.0, 0.0))
	var ctl: BorderCentre = td.border._centre_ctl
	assert_float(td.border.segment_fade(0)).is_equal(1.0)
	ctl._retreating = true
	ctl._retreat_angle = ctl.arms[0].x
	ctl._fade_frac = 1.0
	var faded := 0
	for j: int in range(td.border.polygon.size()):
		if td.border.segment_fade(j) < 1.0:
			faded += 1
	assert_int(faded).is_greater(0)
	assert_int(faded).is_less(td.border.polygon.size() / 2)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- A nearer landmark ----------------------------------------------------------------------------------------------


func test_a_stretch_from_twelve_people_can_reach_the_near_landmark() -> void:
	var s: Dictionary = await _border_level(12, BorderCentre.circle_radius(12))
	var td: TopDownMain = s["td"]
	var at := Config.LANDMARK_POSITIONS[Config.LANDMARK_NEAR_INDEX]
	td.border.buildings.clear()
	var plan: Dictionary = td.border.plan_stretch(at)
	var reach: float = plan["reach"]
	var from_centre := GloomSim.flat_dist(td.border.centre, at)
	assert_bool(plan["refused"]).is_false()
	assert_float(reach).is_greater_equal(from_centre - Config.LANDMARK_SIZES[Config.LANDMARK_NEAR_INDEX].x * 0.5)
	await TopDownTestUtil.leave_loaded_scene(td)
