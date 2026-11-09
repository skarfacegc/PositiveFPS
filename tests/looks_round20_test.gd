extends GdUnitTestSuite

# Graphics checkpoint 4: the walk (Gait and its poses on both looks), and the styled look of the round 20 pieces (the
# reach guide, the minimap clouds, the landmark pulse, the alert banner) with the round 19 flag fixes. Headless uses a
# dummy renderer, so these check state and geometry; the screenshots (tools/checkpoint_shots.py --set round20) check
# the look.

const DT := 1.0 / 60.0


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


# A gait for a person-sized walker facing -z (forward is -z), walking along -z at `speed` for `frames` frames.
func _walk(g: Gait, speed: float, frames: int, z: float = 0.0, dir: Vector3 = Vector3(0, 0, -1)) -> float:
	for i: int in range(frames):
		z += speed * DT * dir.z
		g.advance(Vector3(0.0, 0.0, z), DT, Basis.IDENTITY)
	return z


func _person_gait(seed_id: int = 3) -> Gait:
	var g := Gait.new()
	g.configure(seed_id, 0.62, 1.5, 3.0, 4.2)
	return g


# --- The step cycle ---------------------------------------------------------------------------------------------------


func test_the_hash_is_repeatable_and_between_zero_and_one() -> void:
	for k: int in range(1, 6):
		var h := Gait.hash01(7, k)
		assert_float(h).is_between(0.0, 1.0)
		assert_float(Gait.hash01(7, k)).is_equal(h)
	assert_bool(is_equal_approx(Gait.hash01(1, 1), Gait.hash01(2, 1))).is_false()


func test_the_leg_wave_goes_down_through_stance_then_swings_back() -> void:
	assert_float(Gait.wave(0.0, 0.6)).is_equal_approx(1.0, 0.001)
	assert_float(Gait.wave(0.3, 0.6)).is_equal_approx(0.0, 0.001)
	assert_float(Gait.wave(0.6, 0.6)).is_equal_approx(-1.0, 0.001)
	assert_float(Gait.wave(0.99, 0.6)).is_greater(0.9)
	assert_float(Gait.lift_curve(0.3, 0.6)).is_equal(0.0)
	assert_float(Gait.lift_curve(0.8, 0.6)).is_equal_approx(1.0, 0.001)


func test_a_planted_foot_stays_put_on_the_ground() -> void:
	# The foot's world position along the walk while it is in stance must hardly move (no skating).
	for speed: float in [1.0, 2.0, 3.0]:
		var g := _person_gait()
		var z := _walk(g, speed, 180)
		var leg_world := g.leg_len * g.unit
		var last := INF
		var slip := 0.0
		var samples := 0
		for i: int in range(240):
			z = _walk(g, speed, 1, z)
			var foot := z - leg_world * sin(g.swing[0])  # forward is -z
			if g.lift[0] == 0.0 and last != INF:
				slip += absf(foot - last)
				samples += 1
			last = foot if g.lift[0] == 0.0 else INF
		assert_int(samples).is_greater(40)
		var mean := slip / float(samples)
		assert_float(mean).is_less(0.3 * speed * DT)


func test_the_gait_eases_in_and_settles_out() -> void:
	var g := _person_gait()
	var z := _walk(g, 2.4, 3)
	var early := absf(g.swing[0])
	z = _walk(g, 2.4, 90, z)
	assert_float(absf(g.swing[0]) + absf(g.swing[1])).is_greater(early)
	assert_float(g.move).is_greater(0.9)
	# Standing: it fades out over the following second.
	for i: int in range(90):
		g.advance(Vector3(0.0, 0.0, z), DT, Basis.IDENTITY)
	assert_float(g.move).is_less(0.01)
	assert_float(absf(g.swing[0])).is_less(0.02)
	assert_float(absf(g.lift[0])).is_less(0.01)


func test_standing_still_shifts_weight_slowly() -> void:
	var g := _person_gait()
	var seen: Array[float] = []
	for i: int in range(240):
		g.advance(Vector3.ZERO, DT, Basis.IDENTITY)
		seen.append(g.roll)
	assert_float(seen.max() - seen.min()).is_greater(0.02)
	assert_float(seen.max()).is_less(0.05)
	assert_float(g.bob).is_equal(0.0)


func test_a_run_differs_from_a_walk() -> void:
	var walk := Gait.new()
	walk.configure(0, 0.7, 1.1, PlayerConfig.TD_MOVE_SPEED * 1.12, PlayerConfig.TD_RUN_SPEED * 0.93)
	var run := Gait.new()
	run.configure(0, 0.7, 1.1, PlayerConfig.TD_MOVE_SPEED * 1.12, PlayerConfig.TD_RUN_SPEED * 0.93)
	_walk(walk, PlayerConfig.TD_MOVE_SPEED, 120)
	_walk(run, PlayerConfig.TD_RUN_SPEED, 120)
	assert_float(walk.run).is_less(0.05)
	assert_float(run.run).is_greater(0.9)
	assert_float(run.pitch).is_greater(walk.pitch)
	assert_float(run.stance).is_less(walk.stance)
	assert_float(run.stride).is_greater(walk.stride)


func test_a_slow_walker_takes_shorter_steps_than_a_fast_one() -> void:
	var slow := _person_gait()
	var fast := _person_gait()
	_walk(slow, 1.0, 120)
	_walk(fast, 3.0, 120)
	assert_float(fast.stride).is_greater(slow.stride)
	var slow_peak := 0.0
	var fast_peak := 0.0
	var z_slow := 0.0
	var z_fast := 0.0
	for i: int in range(120):
		z_slow = _walk(slow, 1.0, 1, z_slow)
		z_fast = _walk(fast, 3.0, 1, z_fast)
		slow_peak = maxf(slow_peak, absf(slow.swing[0]))
		fast_peak = maxf(fast_peak, absf(fast.swing[0]))
	assert_float(fast_peak).is_greater(slow_peak)


func test_each_walker_has_its_own_rhythm() -> void:
	var a := _person_gait(1)
	var b := _person_gait(2)
	assert_bool(is_equal_approx(a.phase_off, b.phase_off)).is_false()
	assert_bool(is_equal_approx(a.cadence_var, b.cadence_var)).is_false()
	_walk(a, 2.0, 200)
	_walk(b, 2.0, 200)
	assert_bool(is_equal_approx(a.phase, b.phase)).is_false()


func test_the_same_walk_repeats_exactly() -> void:
	var a := _person_gait(5)
	var b := _person_gait(5)
	_walk(a, 2.2, 150)
	_walk(b, 2.2, 150)
	assert_float(a.phase).is_equal(b.phase)
	assert_float(a.swing[0]).is_equal(b.swing[0])
	assert_float(a.bob).is_equal(b.bob)


func test_walking_backwards_or_sideways_turns_the_swing() -> void:
	var back := _person_gait()
	# Facing -z but moving +z: backwards.
	_walk(back, 2.0, 60, 0.0, Vector3(0, 0, 1))
	assert_float(back.dir_fwd).is_less(-0.9)
	var side := _person_gait()
	for i: int in range(60):
		side.advance(Vector3(2.0 * DT * float(i), 0.0, 0.0), DT, Basis.IDENTITY)
	assert_float(absf(side.dir_side)).is_greater(0.9)
	assert_float(absf(side.dir_fwd)).is_less(0.2)


func test_a_jump_in_position_is_not_a_walk() -> void:
	var g := _person_gait()
	g.advance(Vector3.ZERO, DT, Basis.IDENTITY)
	g.advance(Vector3(80.0, 0.0, 0.0), DT, Basis.IDENTITY)
	g.advance(Vector3(80.0, 0.0, 0.0), DT, Basis.IDENTITY)
	assert_float(g.speed).is_less(0.1)
	g.advance(Vector3(80.0, 0.0, 0.0), 0.0, Basis.IDENTITY)
	assert_float(g.clock).is_less(0.1)


func test_a_heavy_walker_shuffles() -> void:
	var light := _person_gait()
	var heavy := _person_gait()
	heavy.heavy = 1.0
	_walk(light, 1.5, 150)
	_walk(heavy, 1.5, 150)
	assert_float(heavy.pitch).is_greater(light.pitch)
	assert_float(heavy.stance).is_greater(light.stance)


# --- The poses on the bodies ------------------------------------------------------------------------------------------


func _person(mode: int, rescued: bool, level: int = 1) -> Person:
	Looks.set_mode(mode)
	var p: Person = auto_free(Person.new())
	p.look_seed = 4
	add_child(p)
	p.rotation.y = -PI * 0.5  # faces +x, the way the tests walk
	p.is_rescued = rescued
	p.level = level
	p.gloom = 0.95 if level == 2 else 0.45
	# Enough joy for the person's level, so they are not in the flickering warning (that swaps the body that shows).
	p.joy = maxf(Config.JOY_MAX, p.joy_needed()) if rescued else 0.0
	p.look.sync()
	return p


func _walk_person(p: Person, speed: float, frames: int) -> void:
	for i: int in range(frames):
		p.position.x += speed * DT
		p.look.advance(DT)
		p.look.sync()


func test_a_styled_person_swings_legs_and_arms_while_walking_and_not_when_still() -> void:
	for spec: Array in [[false, 1], [true, 0], [false, 2]]:
		var rescued: bool = spec[0]
		var level: int = spec[1]
		var p := _person(Looks.Mode.STYLED, rescued, level)
		var look := p.look as PersonLookStyled
		var kind := look.shown_kind()
		var parts: Dictionary = look._parts[kind]
		var legs: Array[Node3D] = parts["legs"]
		var rest_x := legs[0].rotation.x
		var peak := 0.0
		var lifted := false
		for i: int in range(150):
			_walk_person(p, 2.0, 1)
			peak = maxf(peak, absf(legs[0].rotation.x - rest_x))
			lifted = lifted or legs[0].scale.y < 0.95 or legs[1].scale.y < 0.95
		assert_float(peak).is_greater(0.15)
		assert_bool(lifted).is_true()
		var rig: Node3D = parts["rig"]
		assert_float(rig.rotation.x).is_not_equal(0.0)
		for i: int in range(120):
			p.look.advance(DT)
		assert_float(absf(legs[0].rotation.x - rest_x)).is_less(0.03)
		assert_float(legs[0].scale.y).is_equal_approx(1.0, 0.01)


func test_the_swing_goes_on_whichever_body_shows_after_a_change() -> void:
	var p := _person(Looks.Mode.STYLED, false)
	_walk_person(p, 2.0, 100)
	p.is_rescued = true
	p.level = 0
	p.gloom = 0.0
	p.joy = Config.JOY_MAX
	p.look.sync()
	_walk_person(p, 2.0, 30)
	var look := p.look as PersonLookStyled
	var legs: Array[Node3D] = look._parts[PersonLook.Kind.JOYFUL]["legs"]
	assert_float(absf(legs[0].rotation.x)).is_greater(0.05)


func test_the_dimmed_smoke_stays_on_the_ground_while_the_body_leans() -> void:
	var p := _person(Looks.Mode.STYLED, false, 2)
	_walk_person(p, 1.5, 120)
	var look := p.look as PersonLookStyled
	var haze: Node3D = look._parts[PersonLook.Kind.DIMMED]["haze"]
	assert_object(haze.get_parent()).is_same(look._holders[PersonLook.Kind.DIMMED])
	assert_bool(look.has_styled_aura()).is_true()


func test_a_placeholder_person_bobs_and_leans_while_walking() -> void:
	var p := _person(Looks.Mode.PLACEHOLDER, true, 0)
	var look := p.look as PersonLookPlaceholder
	var rig_y: Array[float] = []
	for i: int in range(120):
		_walk_person(p, 2.0, 1)
		rig_y.append(look.rig.position.y)
	assert_float(rig_y.max() - rig_y.min()).is_greater(0.005)
	# The capsule faces -z, so a forward lean is a negative rotation about x.
	assert_float(look.rig.rotation.x).is_less(0.0)


func test_a_styled_player_swings_its_legs_and_a_placeholder_player_bobs() -> void:
	for mode: int in [Looks.Mode.STYLED, Looks.Mode.PLACEHOLDER]:
		Looks.set_mode(mode)
		var player: TopDownPlayer = auto_free(TopDownPlayer.new())
		add_child(player)
		player.rotation.y = -PI * 0.5
		var peak := 0.0
		for i: int in range(120):
			player.position.x += PlayerConfig.TD_RUN_SPEED * DT
			player.look.advance(DT)
			if player.look is PlayerLookStyled:
				var legs: Array[Node3D] = (player.look as PlayerLookStyled)._parts["legs"]
				peak = maxf(peak, absf(legs[0].rotation.x))
			else:
				peak = maxf(peak, absf((player.look as PlayerLookPlaceholder).rig.rotation.x))
		assert_float(peak).is_greater(0.05)
		assert_float(player.look.gait.run).is_greater(0.5)
		player.look.advance(0.0)
