extends GdUnitTestSuite

# Round 13b, communication: the gap markers (who, how urgent, how far along), the gloom leaking in, the spirit meter and
# its moments, the mood icons, the sheltering tether and the blocked-joy feedback. Level tests drive real input (hover
# targeting with the mouse, G for the burst, Space for the twirl, WASD); the effects are read from the data model of
# FeedbackLayer, SpiritMeter and the minimap rather than from pixels.


# Rescues `count` people on a ring of radius `r` around the origin and lets the border settle (night at midnight).
func _border_level(count: int = 16, r: float = 6.0) -> Dictionary:
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


# A level with everyone parked away and the player at the origin, with lock-on targeting so nothing fires by itself.
func _quiet_level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.player.targeting_mode = Config.TargetingMode.LOCK_ON
	return {"runner": runner, "td": td}


# Makes `m` falter: joy between the relapse line and the falter line.
func _falter(m: Person, share: float = 0.6) -> void:
	m.joy = m.joy_needed() * share


# A wistful person with a mood at `spot`.
func _mooded(td: TopDownMain, index: int, spot: Vector3, mood: int) -> Person:
	var p: Person = td.people[index]
	TopDownTestUtil.place(p, spot, 0, 0.2)
	p.mood = mood
	return p


func _icon_for(td: TopDownMain, p: Person, kind: int) -> Dictionary:
	for ic: Dictionary in td.feedback.icons:
		if ic["person"] == p and ic["kind"] == kind:
			return ic
	return {}


func _hover(runner: GdUnitSceneRunner, td: TopDownMain, p: Person) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, p.global_position))
	await runner.simulate_frames(3)


# --- Faltering markers --------------------------------------------------------------------------------------------


func test_a_faltering_member_gets_a_marker_and_a_bang_badge_that_clear_on_recovery() -> void:
	var s: Dictionary = await _border_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_int(td.feedback.markers.size()).is_equal(0)
	var m: Person = td.border.members[3]
	var other: Person = td.border.members[8]
	_falter(m)
	await runner.simulate_frames(3)
	var marker: Dictionary = td.feedback.marker_for(m)
	assert_bool(marker.is_empty()).is_false()
	var feet: Vector2 = marker["feet"]
	var head: Vector2 = marker["head"]
	assert_float(head.y).is_less(feet.y)  # the "!" badge is drawn above the head
	assert_int(td.feedback.markers.size()).is_equal(1)
	# The marker belongs to the faltering person only.
	assert_bool(td.feedback.marker_for(other).is_empty()).is_true()
	m.joy = m.joy_needed()
	await runner.simulate_frames(3)
	assert_bool(td.feedback.marker_for(m).is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_urgency_rises_with_the_time_a_gap_stays_open() -> void:
	var s: Dictionary = await _border_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	_falter(m)
	await runner.simulate_frames(60)
	assert_int(td.border.gap_count()).is_greater(0)
	var early: float = td.feedback.marker_for(m)["urgency"]
	var early_gap: float = td.border.gap_urgencies().max()
	await runner.simulate_frames(240)
	var later: float = td.feedback.marker_for(m)["urgency"]
	var later_gap: float = td.border.gap_urgencies().max()
	assert_float(early).is_less(0.3)
	assert_float(later).is_greater(early + 0.3)
	assert_float(later_gap).is_greater(early_gap + 0.3)
	await runner.simulate_frames(300)
	assert_float(td.feedback.marker_for(m)["urgency"]).is_equal_approx(1.0, 0.001)
	assert_float(td.border.gap_urgencies().max()).is_equal_approx(1.0, 0.001)
	# A recovered member starts over.
	m.joy = m.joy_needed()
	await runner.simulate_frames(10)
	assert_float(td.border.falter_urgency(m)).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_progress_ring_fills_as_the_player_rejoys_them_and_a_closed_flash_follows() -> void:
	var s: Dictionary = await _border_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	_falter(m, 0.5)
	await runner.simulate_frames(3)
	var start: float = td.feedback.marker_for(m)["progress"]
	assert_float(start).is_less(0.8)
	assert_int(td.feedback.closes.size()).is_equal(0)
	# Hover-fire at them: the player shoots joy at the faltering member.
	await _hover(runner, td, m)
	assert_object(td.player.target).is_same(m)
	var mid_progress := start
	var frames := 0
	while not td.feedback.marker_for(m).is_empty() and frames < 900:
		await runner.simulate_frames(1)
		frames += 1
		var marker: Dictionary = td.feedback.marker_for(m)
		if not marker.is_empty():
			var seen_progress: float = marker["progress"]
			mid_progress = maxf(mid_progress, seen_progress)
	assert_float(mid_progress).is_greater(start + 0.05)
	# They are back above the falter line: the marker is gone and the "closed" flash plays.
	assert_bool(m.is_faltering()).is_false()
	assert_int(td.feedback.closes.size()).is_greater(0)
	var left: float = td.feedback.closes[0]["left"]
	assert_float(left).is_greater(0.0)
	await runner.simulate_frames(int(Config.FALTER_CLOSED_SECONDS * 60.0) + 10)
	assert_int(td.feedback.closes.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_gloom_leaks_in_from_an_open_gap_and_stops_when_it_closes() -> void:
	var s: Dictionary = await _border_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_int(td.feedback.motes.size()).is_equal(0)
	var m: Person = td.border.members[3]
	_falter(m)
	await runner.simulate_frames(90)
	assert_int(td.border.gap_count()).is_greater(0)
	assert_int(td.feedback.motes.size()).is_greater(3)
	# They drift inward: their velocity points from the gap toward the border centre.
	var mote: Dictionary = td.feedback.motes[0]
	var pos: Vector3 = mote["pos"]
	var vel: Vector3 = mote["vel"]
	var to_centre := Vector3(td.border.centre.x - pos.x, 0.0, td.border.centre.z - pos.z)
	assert_float(vel.dot(to_centre)).is_greater(0.0)
	m.joy = m.joy_needed()
	await runner.simulate_frames(int((Config.LEAK_LIFE_SECONDS * 1.2 + 0.5) * 60.0))
	assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.feedback.motes.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_marker_and_the_arrow_intensify_with_urgency() -> void:
	var s: Dictionary = await _border_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	_falter(m)
	await runner.simulate_frames(30)
	var view := td.view_half_extents()
	td.minimap.refresh_from(td.ground, td.border, td.people, td.player.global_position, td.player.global_position, view)
	assert_int(td.minimap.gap_markers.size()).is_greater(0)
	var early: float = td.minimap.gap_markers[0]["urgency"]
	await runner.simulate_frames(540)
	td.minimap.refresh_from(td.ground, td.border, td.people, td.player.global_position, td.player.global_position, view)
	var late: float = td.minimap.gap_markers[0]["urgency"]
	assert_float(late).is_greater(early + 0.4)
	# The arrow: an off-screen gap carries its urgency, and an urgent arrow is brighter at its dimmest and whiter.
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var gaps: Array[Vector3] = [Vector3(0, 0, -40)]
	var urgencies: Array[float] = [0.8]
	var arrows := GapArrows.off_screen_arrows(
		td.camera, screen, gaps, td.minimap.get_global_rect(), Vector2.ONE, urgencies
	)
	assert_float(arrows[0]["urgency"]).is_equal_approx(0.8, 0.0001)
	var calm_min := 1.0
	var urgent_min := 1.0
	for k: int in range(40):
		var t := float(k) / 40.0
		calm_min = minf(calm_min, GapArrows.arrow_colour(0.0, t, 0.45).a)
		urgent_min = minf(urgent_min, GapArrows.arrow_colour(1.0, t, 0.45).a)
	assert_float(urgent_min).is_greater(calm_min + 0.2)
	assert_float(GapArrows.arrow_colour(1.0, 0.0, 1.0).g).is_greater(GapArrows.arrow_colour(0.0, 0.0, 1.0).g)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The spirit meter ---------------------------------------------------------------------------------------------


func test_the_spirit_meter_is_wide_and_has_ticks_at_the_burst_cost_and_the_dim_exit() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(3)
	var meter: SpiritMeter = td.spirit_meter
	assert_float(meter.size.x).is_equal_approx(Config.SPIRIT_METER_WIDTH, 0.5)
	assert_float(meter.burst_tick_x()).is_equal_approx(
		meter.size.x * Config.BURST_SPIRIT_COST / Config.SPIRIT_MAX, 0.01
	)
	assert_float(meter.dim_tick_x()).is_equal_approx(meter.size.x * Config.DIM_EXIT_SPIRIT / Config.SPIRIT_MAX, 0.01)
	assert_float(meter.tick_x(Config.SPIRIT_MAX)).is_equal_approx(meter.size.x, 0.01)
	# It sits at the bottom centre of the window.
	var rect := meter.get_global_rect()
	assert_float(rect.get_center().x).is_equal_approx(640.0, 1.0)
	assert_float(rect.end.y).is_greater(560.0)
	# It follows the player's spirit.
	td.player.spirit = 64.0
	await runner.simulate_frames(2)
	assert_float(meter.spirit).is_equal_approx(64.0, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_rescue_flashes_the_meter_with_a_plus_number_and_pulses_the_player() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.targeting_mode = Config.TargetingMode.HOVER_STICKY
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -6), 0, 0.0)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	var frames := 0
	while not target.is_rescued and frames < 900:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(target.is_rescued).is_true()
	await runner.simulate_frames(1)
	var meter: SpiritMeter = td.spirit_meter
	assert_int(meter.popups.size()).is_greater(0)
	var popup: Dictionary = meter.popups[meter.popups.size() - 1]
	assert_str(popup["text"]).is_equal("+20")
	assert_object(popup["colour"]).is_equal(Config.SPIRIT_GAIN_COLOUR)
	assert_float(meter.flash).is_greater(0.3)
	assert_int(td.feedback.player_pulses.size()).is_greater(0)
	assert_int(td.feedback.player_pulses[0]["kind"]).is_equal(SpiritMeter.Moment.GAIN)
	# The moment fades away.
	await runner.simulate_frames(int((Config.SPIRIT_MOMENT_SECONDS + 0.3) * 60.0))
	assert_int(meter.popups.size()).is_equal(0)
	assert_float(meter.flash).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_burst_key_spends_spirit_with_a_minus_number() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(2)
	assert_float(td.player.spirit).is_equal_approx(80.0 - Config.BURST_SPIRIT_COST, 0.01)
	var meter: SpiritMeter = td.spirit_meter
	assert_int(meter.popups.size()).is_greater(0)
	var popup: Dictionary = meter.popups[meter.popups.size() - 1]
	assert_str(popup["text"]).contains("30")
	assert_bool(str(popup["text"]).begins_with("+")).is_false()
	assert_object(popup["colour"]).is_equal(Config.SPIRIT_SPEND_COLOUR)
	assert_int(td.feedback.player_pulses[0]["kind"]).is_equal(SpiritMeter.Moment.SPEND)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_grab_that_lands_shows_a_loss_moment() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 80.0
	TopDownTestUtil.place(td.people[0], Vector3(0, 0, 1.2), 1, 0.95)
	var frames := 0
	while td.player.spirit > 79.0 and frames < 300:
		await runner.simulate_frames(1)
		frames += 1
	assert_float(td.player.spirit).is_equal_approx(80.0 - Config.GRAB_SPIRIT_DRAIN, 0.01)
	await runner.simulate_frames(1)
	var meter: SpiritMeter = td.spirit_meter
	assert_int(meter.popups.size()).is_greater(0)
	var popup: Dictionary = meter.popups[meter.popups.size() - 1]
	assert_str(popup["text"]).contains("25")
	assert_object(popup["colour"]).is_equal(Config.SPIRIT_LOSS_COLOUR)
	assert_int(td.feedback.player_pulses[td.feedback.player_pulses.size() - 1]["kind"]).is_equal(
		SpiritMeter.Moment.LOSS
	)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_twirl_arc_empties_on_a_twirl_and_fills_back() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(3)
	assert_float(td.spirit_meter.twirl_frac).is_equal(1.0)
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(3)
	assert_float(td.spirit_meter.twirl_frac).is_less(0.2)
	await runner.simulate_frames(50)
	var half: float = td.spirit_meter.twirl_frac
	assert_float(half).is_between(0.3, 0.9)
	await runner.simulate_frames(60)
	assert_float(td.spirit_meter.twirl_frac).is_equal(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Mood icons, tether, blocked joy ------------------------------------------------------------------------------


func test_each_mood_has_its_own_icon_over_the_head_and_dimmed_people_have_none() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var guarded := _mooded(td, 0, Vector3(-4, 0, -7), Person.Mood.GUARDED)
	var skittish := _mooded(td, 1, Vector3(0, 0, -7), Person.Mood.SKITTISH)
	var glum := _mooded(td, 2, Vector3(4, 0, -7), Person.Mood.GLUM)
	var dimmed := td.people[3]
	TopDownTestUtil.place(dimmed, Vector3(10, 0, -7), 1, 0.95)
	dimmed.mood = Person.Mood.GUARDED
	await runner.simulate_frames(5)
	assert_bool(_icon_for(td, guarded, MoodIcons.Kind.SHIELD).is_empty()).is_false()
	assert_bool(_icon_for(td, skittish, MoodIcons.Kind.FEET).is_empty()).is_false()
	assert_bool(_icon_for(td, glum, MoodIcons.Kind.CLOUD).is_empty()).is_false()
	var from_dimmed := 0
	for ic: Dictionary in td.feedback.icons:
		if ic["person"] == dimmed:
			from_dimmed += 1
	assert_int(from_dimmed).is_equal(0)
	# The icon sits above the head on screen.
	var pos: Vector2 = _icon_for(td, guarded, MoodIcons.Kind.SHIELD)["pos"]
	assert_float(pos.y).is_less(TopDownTestUtil.screen_of(td, guarded.global_position).y)
	# Rescued people lose it.
	guarded.receive_joy(guarded.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(3)
	assert_bool(_icon_for(td, guarded, MoodIcons.Kind.SHIELD).is_empty()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_glum_cloud_lifts_and_brightens_while_they_look_up() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var glum := _mooded(td, 0, Vector3(0, 0, -7), Person.Mood.GLUM)
	var seen_up := false
	var seen_down := false
	var frames := 0
	while not (seen_up and seen_down) and frames < 600:
		await runner.simulate_frames(1)
		frames += 1
		var ic: Dictionary = _icon_for(td, glum, MoodIcons.Kind.CLOUD)
		if ic.is_empty():
			continue
		if glum.glum_up:
			assert_float(ic["lift"]).is_equal(1.0)
			seen_up = true
		else:
			assert_float(ic["lift"]).is_equal(0.0)
			seen_down = true
	assert_bool(seen_up).is_true()
	assert_bool(seen_down).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_tether_joins_the_dimmed_person_to_who_they_shelter_and_snaps_when_they_leave() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var wistful := _mooded(td, 0, Vector3(0, 0, -8), Person.Mood.NONE)
	var dimmed := td.people[1]
	TopDownTestUtil.place(dimmed, Vector3(Config.SHELTER_RADIUS + 0.6, 0, -8), 1, 0.95)
	await runner.simulate_frames(4)
	assert_bool(wistful.sheltered).is_false()
	assert_int(td.feedback.tethers.size()).is_equal(0)
	assert_bool(_icon_for(td, wistful, MoodIcons.Kind.UMBRELLA).is_empty()).is_true()
	TopDownTestUtil.place(dimmed, Vector3(Config.SHELTER_RADIUS - 0.4, 0, -8), 1, 0.95)
	await runner.simulate_frames(4)
	assert_bool(wistful.sheltered).is_true()
	assert_int(td.feedback.tethers.size()).is_equal(1)
	assert_bool(_icon_for(td, wistful, MoodIcons.Kind.UMBRELLA).is_empty()).is_false()
	assert_int(td.feedback.snaps.size()).is_equal(0)
	# The dimmed person is led away: the tether breaks with a snap effect that then fades.
	TopDownTestUtil.place(dimmed, Vector3(Config.SHELTER_RADIUS + 1.5, 0, -8), 1, 0.95)
	await runner.simulate_frames(3)
	assert_int(td.feedback.tethers.size()).is_equal(0)
	assert_int(td.feedback.snaps.size()).is_equal(1)
	await runner.simulate_frames(int(Config.TETHER_SNAP_SECONDS * 60.0) + 10)
	assert_int(td.feedback.snaps.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_joy_shot_at_a_guarded_back_bounces_off_with_a_spark_and_the_shield_flashes() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.targeting_mode = Config.TargetingMode.HOVER_STICKY
	var guarded := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	guarded.rotation.y = 0.0  # Facing away (north); the player is south.
	await _hover(runner, td, guarded)
	assert_object(td.player.target).is_same(guarded)
	var frames := 0
	while td.feedback.sparks.is_empty() and frames < 400:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(td.feedback.sparks.size()).is_greater(0)
	assert_int(td.feedback.blocked_count).is_greater(0)
	assert_float(td.feedback.flash_of(guarded)).is_greater(0.3)
	await runner.simulate_frames(1)
	var icon: Dictionary = _icon_for(td, guarded, MoodIcons.Kind.SHIELD)
	assert_float(icon["flash"]).is_greater(0.3)
	assert_float(guarded.joy).is_equal(0.0)
	# The flash and the spark fade.
	guarded.joy = 0.0
	td.player.active = false
	await runner.simulate_frames(int((Config.BLOCK_FLASH_SECONDS + 1.5) * 60.0))
	assert_float(td.feedback.flash_of(guarded)).is_equal(0.0)
	assert_int(td.feedback.sparks.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_joy_shot_at_a_sheltered_person_bounces_off_and_the_umbrella_flashes() -> void:
	var s: Dictionary = await _quiet_level()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.targeting_mode = Config.TargetingMode.HOVER_STICKY
	var wistful := _mooded(td, 0, Vector3(0, 0, -8), Person.Mood.NONE)
	var dimmed := td.people[1]
	TopDownTestUtil.place(dimmed, Vector3(1.6, 0, -8), 1, 0.95)
	await _hover(runner, td, wistful)
	assert_object(td.player.target).is_same(wistful)
	var frames := 0
	while td.feedback.sparks.is_empty() and frames < 400:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(td.feedback.sparks.size()).is_greater(0)
	assert_float(wistful.joy).is_equal(0.0)
	await runner.simulate_frames(1)
	var icon: Dictionary = _icon_for(td, wistful, MoodIcons.Kind.UMBRELLA)
	assert_float(icon["flash"]).is_greater(0.3)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_icons_have_distinct_kinds_and_colours() -> void:
	var kinds := [MoodIcons.Kind.SHIELD, MoodIcons.Kind.FEET, MoodIcons.Kind.CLOUD, MoodIcons.Kind.UMBRELLA]
	assert_int(MoodIcons.kind_for_mood(Person.Mood.GUARDED)).is_equal(MoodIcons.Kind.SHIELD)
	assert_int(MoodIcons.kind_for_mood(Person.Mood.SKITTISH)).is_equal(MoodIcons.Kind.FEET)
	assert_int(MoodIcons.kind_for_mood(Person.Mood.GLUM)).is_equal(MoodIcons.Kind.CLOUD)
	assert_int(MoodIcons.kind_for_mood(Person.Mood.NONE)).is_equal(MoodIcons.Kind.NONE)
	assert_int(MoodIcons.kind_for_block(Person.Block.SHELTERED)).is_equal(MoodIcons.Kind.UMBRELLA)
	assert_int(MoodIcons.kind_for_block(Person.Block.GUARDED)).is_equal(MoodIcons.Kind.SHIELD)
	var seen: Array[Color] = []
	for k: int in kinds:
		assert_bool(seen.has(MoodIcons.colour_for(k))).is_false()
		seen.append(MoodIcons.colour_for(k))


func test_the_spark_list_is_capped() -> void:
	var s: Dictionary = await _quiet_level()
	var td: TopDownMain = s["td"]
	for i: int in range(40):
		td.feedback.on_blocked(td.people[0], Person.Block.GUARDED)
	assert_int(td.feedback.sparks.size()).is_equal(24)
	await TopDownTestUtil.leave_loaded_scene(td)
