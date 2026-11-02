extends GdUnitTestSuite

# Round 23, the pressure curve. The round 22 playtests lost half the border in the last 30 s. The causes found in the
# recordings (see the "Round 23: pressure curve" block in config.gd) were (1) dimmed people arrived on a flat conveyor,
# (2) the "easing" phase was still 82% of midnight's grey strength, and (3) one dimmed person with a line of sight
# drains a whole cohort at once, so they all relapse together. These tests pin the cohort timing (the cause,
# reproduced) and
# the new curve (the fix).

const ROUND_22_GAP := 9.0  # The flat gap before round 23 (DIM_ARRIVAL_MIN_GAP, unchanged).


func _person(pos: Vector3, gloom: float, rescued: bool) -> Person:
	var p: Person = auto_free(Person.new())
	p.affinity = 0
	p.gloom = gloom
	add_child(p)
	p.global_position = pos
	if rescued:
		p.receive_joy(0, Config.JOY_MAX, 0.0)
		p.grace_left = 0.0
	return p


# Greedy count of dimmed arrivals between two night fractions, with a deep pool of people waiting at the gate.
func _arrivals(from_p: float, to_p: float, gap_for: Callable) -> int:
	var t := from_p * Config.NIGHT_LENGTH
	var count := 0
	var last := -INF
	while t < to_p * Config.NIGHT_LENGTH:
		if t - last >= gap_for.call(t / Config.NIGHT_LENGTH):
			last = t
			count += 1
		t += 0.05
	return count


# --- The cause, reproduced ---------------------------------------------------------------------------------------


# One dimmed person with a clear line drains EVERY rescued person within SPREAD_RADIUS at the same rate, so the whole
# cohort passes the relapse line on the same frame, 500 / (SPREAD_DRAIN_RATE x drain x strength) seconds in. That is
# 14.5 s at the strength the round 22 recording had when it began (1.44, 80% of the night): the 14.4 s between the
# dimmed person sinking at 133.05 s and the first relapse at 147.4 s, and then 20 relapses in 12 s.
func test_one_dimmed_person_with_a_clear_line_makes_a_whole_cohort_wobble_on_the_same_frame() -> void:
	var dimmed := _person(Vector3.ZERO, 1.0, false)
	var cohort: Array[Person] = []
	for i: int in range(8):
		var a := TAU * float(i) / 8.0
		cohort.append(_person(Vector3(cos(a), 0.0, sin(a)) * 4.0, 0.0, true))
	var everyone: Array = [dimmed]
	everyone.append_array(cohort)
	var strength := 1.44
	var relapse_frame: Array[int] = []
	for p: Person in cohort:
		relapse_frame.append(-1)
	for frame: int in range(60 * 30):
		GloomSim.update(everyone, 1.0 / 60.0, Config.TD_DRAIN_MULTIPLIER, strength)
		for i: int in range(cohort.size()):
			# Round 24: a drained person wobbles before relapsing, so the cohort tips into the wobble together.
			if relapse_frame[i] < 0 and cohort[i].wobbling:
				relapse_frame[i] = frame
	for f: int in relapse_frame:
		assert_int(f).is_equal(relapse_frame[0])
	var seconds := float(relapse_frame[0]) / 60.0
	var expected := Config.JOY_MAX * 0.5 / (Config.SPREAD_DRAIN_RATE * Config.TD_DRAIN_MULTIPLIER * strength)
	assert_float(seconds).is_equal_approx(expected, 0.1)
	assert_float(seconds).is_between(13.5, 15.5)


# --- The fix: the grey strength really eases --------------------------------------------------------------------


func test_midnight_strength_is_unchanged_and_dawn_is_still_one() -> void:
	var night := NightCycle.new()
	night.elapsed = Config.NIGHT_LENGTH * 0.5
	assert_float(night.strength()).is_equal_approx(1.75, 0.0001)
	night.elapsed = Config.NIGHT_LENGTH * Config.NIGHT_EASE_START
	assert_float(night.strength()).is_equal_approx(1.0 + Config.NIGHT_PEAK_EXTRA * sin(PI * 0.6), 0.0001)
	night.elapsed = Config.NIGHT_LENGTH
	assert_float(night.strength()).is_equal_approx(1.0, 0.0001)


func test_the_easing_phase_has_no_surge_the_strength_only_falls() -> void:
	var night := NightCycle.new()
	var last := 99.0
	for step: int in range(0, 41):
		night.elapsed = Config.NIGHT_LENGTH * (0.5 + 0.5 * float(step) / 40.0)
		var s := night.strength()
		assert_float(s).is_less_equal(last + 0.0001)
		last = s
	# The easing phase (the last quarter) begins well under midnight's strength (round 22: 1.53, 87%), and ends near 1.
	night.elapsed = Config.NIGHT_LENGTH * 0.75
	assert_float(night.strength()).is_less(1.4)
	night.elapsed = Config.NIGHT_LENGTH * 0.8
	assert_float(night.strength()).is_less(1.3)  # Round 22: 1.44, the strength of the mass relapse.
	night.elapsed = Config.NIGHT_LENGTH * 0.9
	assert_float(night.strength()).is_less(1.1)


func test_the_rise_to_midnight_and_the_calm_opening_are_unchanged() -> void:
	var night := NightCycle.new()
	night.elapsed = Config.NIGHT_LENGTH * 0.24
	assert_float(night.strength()).is_equal_approx(Config.NIGHT_CALM_STRENGTH, 0.0001)
	# The ease only acts after NIGHT_EASE_START, so up to there the curve is the round 10 curve.
	for f: float in [0.3, 0.4, 0.5, 0.55]:
		night.elapsed = Config.NIGHT_LENGTH * f
		var round10 := lerpf(
			Config.NIGHT_CALM_STRENGTH,
			1.0 + Config.NIGHT_PEAK_EXTRA * sin(PI * f),
			smoothstep(Config.NIGHT_CALM_FRACTION, 0.5, f)
		)
		assert_float(night.strength()).is_equal_approx(round10, 0.0001)


# --- The fix: dimmed people arrive sooner and stop arriving at the end ---------------------------------------------


func test_the_arrival_gap_is_short_in_the_rising_phase_nine_seconds_at_midnight_and_long_at_dawn() -> void:
	assert_float(NightCycle.dim_gap_at(Config.NIGHT_CALM_FRACTION)).is_equal_approx(Config.DIM_GAP_RISING, 0.0001)
	assert_float(NightCycle.dim_gap_at(0.5)).is_equal_approx(Config.DIM_ARRIVAL_MIN_GAP, 0.0001)
	assert_float(NightCycle.dim_gap_at(Config.DIM_GAP_EASE_START)).is_equal_approx(Config.DIM_ARRIVAL_MIN_GAP, 0.0001)
	assert_float(NightCycle.dim_gap_at(1.0)).is_equal_approx(Config.DIM_GAP_EASE_END, 0.0001)
	assert_float(Config.DIM_GAP_RISING).is_less(Config.DIM_ARRIVAL_MIN_GAP)
	assert_float(Config.DIM_GAP_EASE_END).is_greater(Config.DIM_ARRIVAL_MIN_GAP * 2.0)


func test_the_arrival_gap_never_drops_below_the_midnight_gap_after_midnight_and_only_lengthens() -> void:
	var last := 0.0
	for step: int in range(0, 51):
		var p := 0.5 + 0.5 * float(step) / 50.0
		var g := NightCycle.dim_gap_at(p)
		assert_float(g).is_greater_equal(Config.DIM_ARRIVAL_MIN_GAP - 0.0001)
		assert_float(g).is_greater_equal(last - 0.0001)
		last = g
	# And through the rising phase it only lengthens toward midnight (the shortest gap is at the start).
	last = 0.0
	for step: int in range(0, 26):
		var p := Config.NIGHT_CALM_FRACTION + (0.5 - Config.NIGHT_CALM_FRACTION) * float(step) / 25.0
		var g := NightCycle.dim_gap_at(p)
		assert_float(g).is_less_equal(Config.DIM_ARRIVAL_MIN_GAP + 0.0001)
		assert_float(g).is_greater_equal(last - 0.0001)
		last = g


func test_more_dimmed_people_arrive_in_the_rising_phase_and_far_fewer_in_the_easing_phase() -> void:
	var flat := func(_p: float) -> float: return ROUND_22_GAP
	var curve := func(p: float) -> float: return NightCycle.dim_gap_at(p)
	var rising_old := _arrivals(0.25, 0.5, flat)
	var rising_new := _arrivals(0.25, 0.5, curve)
	var easing_old := _arrivals(0.75, 1.0, flat)
	var easing_new := _arrivals(0.75, 1.0, curve)
	assert_int(rising_new).is_greater(rising_old)  # Round 22: 5, now 6.
	assert_int(easing_old).is_greater_equal(5)
	assert_int(easing_new).is_less_equal(2)
	# The rising phase brings more trouble than the easing phase does, where round 22 had the same for both.
	assert_int(rising_new).is_greater(easing_new + 2)
	# Not an easier night overall: the whole night brings at least 85% of the round 22 arrivals.
	var all_old := _arrivals(0.25, 1.0, flat)
	var all_new := _arrivals(0.25, 1.0, curve)
	assert_int(all_new * 100).is_greater_equal(all_old * 85)


func test_the_midnight_gate_in_the_level_follows_the_night() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	# Eight seconds since the last sink: the rising phase lets the next one go, the easing phase holds it back.
	td._dim_clock = 100.0
	td.night.elapsed = Config.NIGHT_LENGTH * 0.3
	td._last_dim_sink = 92.0
	assert_bool(td._try_dim_sink()).is_true()
	td._last_dim_sink = 92.0
	td.night.elapsed = Config.NIGHT_LENGTH * 0.95
	assert_bool(td._try_dim_sink()).is_false()
	# Thirty-two seconds is enough even then (the gap peaks at DIM_GAP_EASE_END, 30 s).
	td._last_dim_sink = 68.0
	assert_bool(td._try_dim_sink()).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)
