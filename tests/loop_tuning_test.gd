extends GdUnitTestSuite

# Walls and gates: Loop tuning (#93). One member per 6 m on a gate (a new cell wants about 12), 10 spirit a rescue
# (takes stay 25, the burst stays 30), and a burst mends every break within BURST_LIFT_RADIUS at once and holds that
# gate calm for BURST_CALM_SECONDS, with the cue saying "G: mend" when a break is in that range. Pure rules on a bare
# Border (no frames) except the cue, which runs in a level.

const R := 9.0
const DT := 1.0 / 60.0


# A bare Border with the start square's line traced, the way Border.update would on its first frame.
func _border() -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border._mark_gaps()
	var needs: Array[int] = []
	for g: Dictionary in border.zone.gates:
		needs.append(g["need"])
	border._slots.gate_counts.assign(needs)  # Fully staffed, so a gate breaks at the full PUSH_BREAK_DEPTH.
	return border


func _run(border: Border, people: Array[Person], seconds: float) -> void:
	var nobody: Array[Person] = people
	for i: int in range(int(seconds * 60.0)):
		border.push.update(nobody, DT, 1.0)


func _east(border: Border) -> int:
	return border.push.sample_of(Vector3(R, 0.0, 0.0))


func _west(border: Border) -> int:
	return border.push.sample_of(Vector3(-R, 0.0, 0.0))


func test_a_gate_asks_for_one_member_per_six_metres_and_the_start_square_wants_twelve() -> void:
	assert_float(BorderConfig.BORDER_TARGET_SPACING).is_equal_approx(6.0, 0.01)
	var z := Zone.new()
	for g: Dictionary in z.gates:
		assert_int(g["need"] as int).is_equal(3)
	assert_int(z.members_needed()).is_equal(12)


func test_a_rescue_gives_ten_spirit_and_takes_and_bursts_keep_their_costs() -> void:
	assert_float(SpiritConfig.SPIRIT_PER_RESCUE).is_equal(10.0)
	assert_float(BorderConfig.TAKE_SPIRIT_COST).is_equal(25.0)
	assert_float(SpiritConfig.BURST_SPIRIT_COST).is_equal(30.0)


func test_the_burst_cue_text_is_g_mend() -> void:
	assert_str(SpiritConfig.BURST_MEND_CUE_TEXT).is_equal("G: mend")


func test_a_burst_mends_every_break_in_reach_at_once() -> void:
	var border := _border()
	var east := _east(border)
	var west := _west(border)
	border.push._open_break(east)
	border.push._open_break(west)
	assert_int(border.push.breaks.size()).is_equal(2)
	assert_int(border.push.breaks_in_reach(Vector3.ZERO)).is_equal(2)  # Both are 9 m from the middle: inside 14 m.
	border.push.relieve(Vector3.ZERO)
	assert_int(border.push.breaks.size()).is_equal(0)
	assert_bool(border.push.broken[east]).is_false()
	assert_bool(border.push.broken[west]).is_false()


func test_a_burst_leaves_a_break_out_of_reach_open() -> void:
	var border := _border()
	var east := _east(border)
	var west := _west(border)
	border.push._open_break(east)
	border.push._open_break(west)
	var from_east := Vector3(R, 0.0, 0.0)
	assert_int(border.push.breaks_in_reach(from_east)).is_equal(1)  # The west break is 18 m away: outside 14 m.
	border.push.relieve(from_east)
	assert_int(border.push.breaks.size()).is_equal(1)
	assert_bool(border.push.broken[west]).is_true()
	assert_bool(border.push.broken[east]).is_false()


func test_a_mended_gate_is_held_calm_while_the_hold_runs() -> void:
	var border := _border()
	var east := _east(border)
	border.push._open_break(east)
	border.push.relieve(Vector3(R, 0.0, 0.0))
	assert_int(border.push.breaks.size()).is_equal(0)
	assert_float(border.push._hold[east]).is_equal_approx(SpiritConfig.BURST_CALM_SECONDS, 0.001)
	# Ten seconds in, the hold still holds the calm at its burst strength (it would fade over PUSH_CALM_SECONDS).
	var nobody: Array[Person] = []
	_run(border, nobody, 10.0)
	assert_float(border.push._calm[east]).is_equal_approx(PushConfig.PUSH_BURST_CALM, 0.001)
	assert_float(border.push._hold[east]).is_equal_approx(SpiritConfig.BURST_CALM_SECONDS - 10.0, 0.05)


func test_the_hold_runs_out_after_burst_calm_seconds_and_the_calm_fades() -> void:
	var border := _border()
	var east := _east(border)
	border.push._open_break(east)
	border.push.relieve(Vector3(R, 0.0, 0.0))
	var nobody: Array[Person] = []
	# Then the calm fades out too.
	_run(border, nobody, SpiritConfig.BURST_CALM_SECONDS + PushConfig.PUSH_CALM_SECONDS + 0.5)
	assert_float(border.push._hold[east]).is_equal(0.0)
	assert_float(border.push._calm[east]).is_equal(0.0)


func test_the_cue_says_mend_when_a_break_is_in_reach_and_not_otherwise() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	for i: int in range(16):
		var a := TAU * float(i) / 16.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 6.0, 0.0, sin(a) * 6.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	td.night.elapsed = NightConfig.NIGHT_LENGTH / 2.0
	await runner.simulate_frames(600)
	td.player.add_spirit(100.0)
	var border: Border = td.border
	var spot: Vector3 = border.members[3].position
	border.push._open_break(border.push.sample_of(spot))
	td.player.global_position = spot
	await runner.simulate_frames(2)
	assert_str(td.burst_cue.cue_text()).is_equal(SpiritConfig.BURST_MEND_CUE_TEXT)
	assert_bool(td.burst_cue.cue_ready).is_true()
	# Far from the break: no mend (and no lift either, since no one is dimmed).
	td.player.global_position = Vector3(-33.0, 0.0, 0.0)
	assert_str(td.burst_cue.cue_text()).is_not_equal(SpiritConfig.BURST_MEND_CUE_TEXT)
	await TopDownTestUtil.leave_loaded_scene(td)
