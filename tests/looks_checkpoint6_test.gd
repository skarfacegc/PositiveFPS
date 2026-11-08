extends GdUnitTestSuite

# Graphics checkpoint 6: the styled stipple is about half as strong (the dither strengths are what the shaders
# receive), and the player's run (Shift) is a jog that reads apart from the walk in both looks. Headless uses a
# dummy renderer, so these check the values and the gait; the screenshots (tools/checkpoint_shots.py --set round24)
# check the look.

const DT := 1.0 / 60.0
const WARM_FRAMES := 60


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	return {"td": td, "runner": runner}


# --- The dither strengths ---------------------------------------------------------------------------------


func test_the_stipple_is_cut_to_about_half() -> void:
	assert_float(Config.STYLED_DITHER_LIGHT).is_equal_approx(0.08, 0.0001)


# Checkpoint 7: the toon light and the glows no longer dither; the toon materials get the soft band width instead.
func test_the_toon_materials_receive_the_soft_band_width() -> void:
	var toon := StyleKit.mat(Color(0.5, 0.5, 0.5))
	assert_float(toon.get_shader_parameter("band_soft")).is_equal(Config.CP7_TOON_SOFT)
	var own := StyleKit.unique_mat(Color(0.5, 0.5, 0.5), 0.2)
	assert_float(own.get_shader_parameter("band_soft")).is_equal(Config.CP7_TOON_SOFT)


func test_the_glow_halos_keep_their_strength() -> void:
	var glow := StyleKit.glow_mat(Color(1.0, 0.8, 0.4), 0.62)
	assert_float(glow.get_shader_parameter("strength")).is_equal(0.62)


func test_the_styled_ground_receives_its_shadow_and_stipple_strengths() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	td.set_look(Looks.Mode.STYLED)
	var ground := td.ground.look as GroundLookStyled
	var mat := ground._mat
	# Checkpoint 7: the ground has no dithering at all.
	assert_float(mat.get_shader_parameter("dither_amt")).is_equal(0.0)
	td.set_look(Looks.Mode.PLACEHOLDER)
	await runner.simulate_frames(2)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The jog ---------------------------------------------------------------------------------------------------


# Moves the player along its facing at `speed` for `frames` frames (after a warm-up) and measures the walk:
# the bob's range, the most lean, the widest leg swing and how many footfalls it took, plus the puffs it raised.
func _measure(mode: int, speed: float, frames: int) -> Dictionary:
	Looks.set_mode(mode)
	var player: TopDownPlayer = auto_free(TopDownPlayer.new())
	add_child(player)
	player.rotation.y = -PI * 0.5
	var gait: Gait = player.look.gait
	var lo := INF
	var hi := -INF
	var lean := 0.0
	var swing := 0.0
	var steps := 0
	var last_step := -1
	for i: int in range(WARM_FRAMES + frames):
		player.position.x += speed * DT
		player.look.advance(DT)
		if i < WARM_FRAMES:
			continue
		lo = minf(lo, gait.bob)
		hi = maxf(hi, gait.bob)
		lean = maxf(lean, gait.pitch)
		swing = maxf(swing, absf(gait.swing[0]))
		var step := floori(gait.phase * 2.0)
		if last_step >= 0 and step != last_step:
			steps += 1
		last_step = step
	var puffs := 0
	if player.look is PlayerLookStyled:
		puffs = (player.look as PlayerLookStyled).puffs_started
	return {"bob": hi - lo, "lean": lean, "swing": swing, "steps": steps, "puffs": puffs, "jog": gait.jog}


func test_the_player_jog_is_clearly_different_from_the_walk_in_both_looks() -> void:
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		var walk := _measure(mode, Config.TD_MOVE_SPEED, 180)
		var run := _measure(mode, Config.TD_RUN_SPEED, 180)
		var walk_bob: float = walk["bob"]
		var run_bob: float = run["bob"]
		var walk_lean: float = walk["lean"]
		var run_lean: float = run["lean"]
		var walk_steps: int = walk["steps"]
		var run_steps: int = run["steps"]
		var run_jog: float = run["jog"]
		assert_float(run_jog).is_equal(1.0)
		# More bob and more lean.
		assert_float(run_bob).is_greater(walk_bob * 1.3)
		assert_float(run_lean).is_greater(walk_lean + 0.1)
		# A quicker step: more footfalls in the same two seconds.
		assert_int(run_steps).is_greater(int(walk_steps * 1.3))


func test_the_styled_jog_swings_the_legs_wider_than_the_walk() -> void:
	var walk := _measure(Looks.Mode.STYLED, Config.TD_MOVE_SPEED, 180)
	var run := _measure(Looks.Mode.STYLED, Config.TD_RUN_SPEED, 180)
	var walk_swing: float = walk["swing"]
	var run_swing: float = run["swing"]
	assert_float(run_swing).is_greater(walk_swing + 0.15)
	assert_float(run_swing).is_less_equal(Config.JOG_SWING_ANGLE + 0.01)


func test_a_styled_run_raises_a_dust_puff_at_each_footfall_and_a_walk_raises_none() -> void:
	var walk := _measure(Looks.Mode.STYLED, Config.TD_MOVE_SPEED, 180)
	var run := _measure(Looks.Mode.STYLED, Config.TD_RUN_SPEED, 180)
	var walk_puffs: int = walk["puffs"]
	var run_puffs: int = run["puffs"]
	var run_steps: int = run["steps"]
	assert_int(walk_puffs).is_equal(0)
	assert_int(run_puffs).is_greater(run_steps - 2)
	assert_int(run_puffs).is_greater(5)


func test_people_keep_their_walk_and_run() -> void:
	# A person's gait is not a jog (jog 0): the run lean stays what it was before checkpoint 6.
	var g := Gait.new()
	g.configure(3, 0.62, 1.5, 3.0, 4.2)
	assert_float(g.jog).is_equal(0.0)
	var z := 0.0
	var lean := 0.0
	for i: int in range(180):
		z -= Config.TD_RUN_SPEED * DT
		g.advance(Vector3(0.0, 0.0, z), DT, Basis.IDENTITY)
		lean = maxf(lean, g.pitch)
	assert_float(lean).is_less(0.12)
	assert_float(g.run).is_greater(0.9)


func test_a_styled_footfall_with_no_parent_raises_no_puff() -> void:
	Looks.set_mode(Looks.Mode.STYLED)
	var player: TopDownPlayer = auto_free(TopDownPlayer.new())
	add_child(player)
	var look := player.look as PlayerLookStyled
	remove_child(player)
	assert_object(player.get_parent()).is_null()
	look._dust(0)
	look._dust(1)
	assert_int(look.puffs_started).is_equal(0)


# --- The first-light motes -----------------------------------------------------------------------------------


func _first_light(instance_count: int = -1) -> StyleFirstLight:
	var holder: Node3D = auto_free(Node3D.new())
	add_child(holder)
	var fl := StyleFirstLight.new()
	fl.build(holder)
	if instance_count >= 0:
		fl._multi.instance_count = instance_count
	return fl


func test_a_small_front_lays_motes_from_the_whole_circle() -> void:
	var fl := _first_light()
	# SPAN / 0.6 is well over PI, so every angle is used: motes appear on both sides of the focus.
	fl.sync(0.6, Vector3(30.0, 0.0, 0.0), 0.0)
	var pos := fl.mote_positions()
	assert_int(pos.size()).is_greater(0)
	var behind := false
	for p: Vector3 in pos:
		if p.x < 0.0:
			behind = true
	assert_bool(behind).is_true()


func test_the_motes_stop_at_the_instance_count() -> void:
	var fl := _first_light(3)
	fl.sync(0.6, Vector3.ZERO, 0.0)
	assert_int(fl.mote_count()).is_equal(3)
	assert_int(fl.mote_positions().size()).is_equal(3)
