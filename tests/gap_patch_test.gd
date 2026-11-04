extends GdUnitTestSuite

# Round 22: the gap patch (F), the border warning rings and the reworked joy burst, as rules and through real input.
# The seeded scenarios that compare a collapse with and without help live in spirit_defence_test.gd.


# A ring of `count` rescued people at radius `r` around the origin, settled at midnight.
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


# Drains `m` below the falter line so the border opens a gap beside them, and waits for it.
func _open_gap(s: Dictionary, m: Person) -> void:
	var runner: GdUnitSceneRunner = s["runner"]
	m.joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION - 0.05)
	await runner.simulate_frames(20)


func _aim_at(s: Dictionary, spot: Vector3) -> void:
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.global_position = Vector3.ZERO
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(3)


# --- The warning -------------------------------------------------------------------------------------------------


func test_joy_urgency_grows_from_the_warn_start_to_the_falter_line() -> void:
	var p: Person = auto_free(Person.new())
	p.is_rescued = true
	p.joy = Config.JOY_MAX
	assert_float(BorderWarning.joy_urgency(p)).is_equal(0.0)
	p.joy = Config.JOY_MAX * (Config.BORDER_WARN_START + Config.MEMBER_FALTER_FRACTION) * 0.5
	assert_float(BorderWarning.joy_urgency(p)).is_equal_approx(0.5, 0.01)
	p.joy = Config.JOY_MAX * Config.MEMBER_FALTER_FRACTION
	assert_float(BorderWarning.joy_urgency(p)).is_equal_approx(1.0, 0.01)
	p.is_rescued = false
	assert_float(BorderWarning.joy_urgency(p)).is_equal(0.0)


func test_a_draining_member_gets_a_ring_and_a_minimap_marker_before_the_gap_opens() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.gap_patch.warnings.size()).is_equal(0)
	var m: Person = td.border.members[4]
	# Partway between the warn start and the falter line: strained, but no gap yet.
	m.joy = Config.JOY_MAX * (Config.BORDER_WARN_START + Config.MEMBER_FALTER_FRACTION) * 0.5
	await runner.simulate_frames(20)
	assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.gap_patch.warnings.size()).is_equal(1)
	assert_float(td.gap_patch.warnings[0]["urgency"]).is_between(0.3, 0.7)
	assert_int(td.gap_patch.fx.warning_ring_count()).is_equal(1)
	td.minimap.refresh_from(
		td.ground, td.border, td.people, td.player.global_position, Vector3.ZERO, td.view_half_extents()
	)
	assert_int(td.minimap.warn_markers.size()).is_equal(1)
	# Worse drain, stronger warning.
	m.joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION + 0.02)
	await runner.simulate_frames(20)
	assert_float(td.gap_patch.warnings[0]["urgency"]).is_greater(0.85)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Patching ----------------------------------------------------------------------------------------------------


func test_f_patches_the_gap_near_the_cursor_and_charges_spirit() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[4]
	await _open_gap(s, m)
	assert_int(td.border.gap_count()).is_greater(0)
	var gap: Vector3 = td.border.gap_midpoints()[0]
	td.player.add_spirit(100.0)
	await _aim_at(s, gap)
	var before := td.player.spirit
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.patches.size()).is_equal(1)
	assert_float(td.player.spirit).is_equal_approx(before - Config.PATCH_SPIRIT_COST, 0.5)
	# The gap is sealed: no open gap, its stretch blocks gloom, and the member inside is shielded.
	assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.border.gap_midpoints().size()).is_equal(0)
	assert_float(m.patch_mult).is_equal(Config.PATCH_DRAIN_MULT)
	assert_int(td.gap_patch.fx.patch_disc_count()).is_equal(1)
	# A second press at the same spot is refused (already patched) and spends nothing.
	var spent := td.player.spirit
	await runner.simulate_frames(2)
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.patches.size()).is_equal(1)
	assert_float(td.player.spirit).is_equal_approx(spent, 0.5)
	assert_int(td.intro.current).is_equal(Intro.Prompt.PATCH_ALREADY)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_patch_runs_out_and_the_gap_comes_back() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[4]
	await _open_gap(s, m)
	td.player.add_spirit(100.0)
	td.gap_patch.patch_at(td.border.gap_midpoints()[0])
	await runner.simulate_frames(5)
	assert_int(td.border.gap_count()).is_equal(0)
	# Checkpoint 5: spare spirit (the add_spirit above spilled past a full meter) would warm the faltering member and
	# heal the gap; this test is about the patch alone, so the pool is emptied.
	td.spirit_warmth.pool = 0.0
	await runner.simulate_frames(int((Config.PATCH_SECONDS + 1.0) * 60.0))
	assert_int(td.gap_patch.patches.size()).is_equal(0)
	assert_float(m.patch_mult).is_equal(1.0)
	# Nobody was healed meanwhile, so the gap is open again: a patch is a pause, not a cure.
	assert_bool(m.is_faltering()).is_true()
	assert_int(td.border.gap_count()).is_greater(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_patched_stretch_stops_a_dimmed_person_walking_through() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[4]
	await _open_gap(s, m)
	var gap: Vector3 = td.border.gap_midpoints()[0]
	var out := Vector3(gap.x - td.border.centre.x, 0.0, gap.z - td.border.centre.z).normalized()
	var outside := gap + out * 3.0
	var inside := gap - out * 3.0
	assert_bool(td.border.line_blocks(outside, inside)).is_false()
	td.player.add_spirit(100.0)
	td.gap_patch.patch_at(gap)
	await runner.simulate_frames(5)
	assert_bool(td.border.line_blocks(outside, inside)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_patch_is_refused_with_a_reason_when_nothing_is_near_or_spirit_is_short() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.add_spirit(100.0)
	# A healthy border: no gap and no strained spot anywhere.
	await _aim_at(s, td.border.members[2].position)
	var full := td.player.spirit
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.patches.size()).is_equal(0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.PATCH_NONE)
	assert_float(td.player.spirit).is_equal_approx(full, 0.01)
	assert_str(Intro.text_for(Intro.Prompt.PATCH_NONE)).contains("No gap")
	# A gap exists but the player is out of spirit.
	var m: Person = td.border.members[4]
	await _open_gap(s, m)
	var gap: Vector3 = td.border.gap_midpoints()[0]
	td.player.lose_spirit(td.player.spirit - (Config.PATCH_SPIRIT_COST - 5.0))
	await _aim_at(s, gap)
	await runner.simulate_frames(2)
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.patches.size()).is_equal(0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.PATCH_SPIRIT)
	# A gap far from the cursor is refused as "none near".
	td.player.add_spirit(100.0)
	await _aim_at(s, -gap)
	await runner.simulate_frames(2)
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.patches.size()).is_equal(0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.PATCH_NONE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_strained_spot_can_be_patched_before_its_gap_opens() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[6]
	m.joy = Config.JOY_MAX * (Config.MEMBER_FALTER_FRACTION + 0.05)
	await runner.simulate_frames(20)
	assert_int(td.border.gap_count()).is_equal(0)
	td.player.add_spirit(100.0)
	await _aim_at(s, m.position)
	runner.simulate_key_pressed(KEY_F)
	await runner.simulate_frames(3)
	assert_int(td.gap_patch.patches.size()).is_equal(1)
	assert_float(m.patch_mult).is_equal(Config.PATCH_DRAIN_MULT)
	# A shielded member is no longer flagged as the place to spend spirit.
	await runner.simulate_frames(20)
	assert_int(td.gap_patch.warnings.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_patch_recorder_event_and_hint_text() -> void:
	assert_str(TopDownMain.HINT_PLAY).contains("F patch gap")
	var menu_text: String = (load("res://scripts/menu.gd") as GDScript).get_script_constant_map()["HOW_TO_PLAY_TEXT"]
	assert_str(menu_text).contains("F patch gap")
	assert_float(Config.PATCH_SPIRIT_COST).is_equal(25.0)
	assert_float(Config.PATCH_SECONDS).is_equal(12.0)


# --- The burst ---------------------------------------------------------------------------------------------------


func test_the_burst_pushes_back_and_lifts_dimmed_people_at_the_border() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var border: Border = td.border
	var m: Person = border.members[3]
	var out := Vector3(m.position.x - border.centre.x, 0.0, m.position.z - border.centre.z).normalized()
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	var near: Person = td.people[20]
	var far: Person = td.people[21]
	TopDownTestUtil.place(near, m.position + out * 1.2, 1, 0.95)
	# Round 24: out of the lift radius (dimmed people anywhere inside it are lifted now), so not a target.
	td.player.global_position = m.position - out * 2.0
	TopDownTestUtil.place(far, td.player.global_position + out * (Config.BURST_LIFT_RADIUS + 2.0), 2, 0.95)
	await runner.simulate_frames(2)
	near.gloom = 0.95
	far.gloom = 0.95
	assert_bool(BurstClear.is_target(near, td.player.global_position, border)).is_true()
	assert_bool(BurstClear.is_target(far, td.player.global_position, border)).is_false()
	td.player.add_spirit(100.0)
	var spirit := td.player.spirit
	var start := near.global_position
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(3)
	assert_float(td.player.spirit).is_equal_approx(spirit - Config.BURST_SPIRIT_COST, 1.0)
	# Pushed away from the line and lifted a stage; the streak shows.
	# (The burst also shoves the line outward, so measure the push itself, away from the centre.)
	assert_float(near.global_position.distance_to(start)).is_greater(Config.BURST_PUSH_DISTANCE - 0.5)
	assert_float(near.global_position.length()).is_greater(start.length() + 2.0)
	assert_int(Config.gloom_level(near.gloom)).is_equal(1)
	assert_bool(GloomSim.is_dimmed(near)).is_false()
	assert_int(td.gap_patch.fx.streak_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_hud_says_how_many_dimmed_people_the_burst_would_clear() -> void:
	var s: Dictionary = await _border_level(16, 6.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var m: Person = td.border.members[3]
	var out := Vector3(m.position.x - td.border.centre.x, 0.0, m.position.z - td.border.centre.z).normalized()
	for p: Person in td.people:
		if not p.is_rescued:
			p.gloom = 0.0
	TopDownTestUtil.open_dim_gate(td)
	td.player.add_spirit(100.0)
	td.player.burst_cooldown = 0.0
	td.player.global_position = m.position - out * 2.0
	await runner.simulate_frames(20)
	assert_str(td.hud.burst_label.text).is_equal("Joy burst [G]: READY")
	TopDownTestUtil.place(td.people[20], m.position + out * 1.2, 1, 0.95)
	await runner.simulate_frames(20)
	assert_int(td.gap_patch.burst_targets).is_equal(1)
	assert_str(td.hud.burst_label.text).contains("clears 1 dimmed")
	await TopDownTestUtil.leave_loaded_scene(td)
