extends GdUnitTestSuite

# Round 12a: spirit and going dim, in the real level. Rescues fill spirit (hover-fire input), the burst (G) spends it,
# fire rate scales with it, and at zero the player goes dim: half speed (WASD), no joy, dimmed people ignore them,
# recovery only inside the border (by depth) or near the landmark before a border, back to normal at 30, and the border
# loses ground x1.5 faster meanwhile.

# Counts the joy projectiles that enter the level (see test_the_fire_rate_scales_with_spirit).
var _shots: int = 0


func _on_child(node: Node) -> void:
	if node is JoyProjectile:
		_shots += 1


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(30)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# Rescues `p` directly at `spot`.
func _rescue(p: Person, spot: Vector3) -> void:
	TopDownTestUtil.place(p, spot, p.affinity, 0.0)
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


# Makes the player dim by draining all their spirit.
func _go_dim(td: TopDownMain) -> void:
	td.player.lose_spirit(Config.SPIRIT_MAX * 2.0)


# --- Spirit gain, burst cost, fire rate -----------------------------------------------------------------------


func test_a_rescue_made_by_hover_fire_adds_spirit() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = 10.0
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -6), 0, 0.0)
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.HOVER_STICKY)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	var frames := 0
	while not target.is_rescued and frames < 900:
		await runner.simulate_frames(1)
		frames += 1
	assert_bool(target.is_rescued).is_true()
	assert_float(td.player.spirit).is_equal_approx(10.0 + Config.SPIRIT_PER_RESCUE, 0.01)
	await runner.simulate_frames(2)
	assert_str(td.hud.spirit_label.text).contains("30")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_spirit_is_capped_at_the_maximum() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	td.player.add_spirit(Config.SPIRIT_MAX * 3.0)
	assert_float(td.player.spirit).is_equal(Config.SPIRIT_MAX)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_burst_spends_spirit_and_is_blocked_when_short() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	player.spirit = 80.0
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(2)
	assert_float(player.spirit).is_equal_approx(80.0 - Config.BURST_SPIRIT_COST, 0.01)
	assert_float(player.burst_cooldown).is_greater(Config.TD_BURST_COOLDOWN - 0.5)

	# Ready again with 50 left: it works and leaves 20.
	player.burst_cooldown = 0.0
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(2)
	assert_float(player.spirit).is_equal_approx(20.0, 0.01)

	# Ready again, but 20 spirit is short of the cost (30): nothing happens and the HUD says why.
	player.burst_cooldown = 0.0
	runner.simulate_key_pressed(KEY_Q)
	await runner.simulate_frames(2)
	assert_float(player.burst_cooldown).is_equal(0.0)
	assert_float(player.spirit).is_equal_approx(20.0, 0.01)
	assert_str(td.hud.burst_label.text).contains("needs 30 spirit")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_fire_rate_scales_with_spirit() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	player.spirit = Config.SPIRIT_MAX
	assert_float(player.fire_rate_mult()).is_equal(1.0)
	player.spirit = 50.0
	assert_float(player.fire_rate_mult()).is_equal(1.0)
	player.spirit = 25.0
	assert_float(player.fire_rate_mult()).is_equal_approx(0.7, 0.001)
	player.spirit = 0.01
	assert_float(player.fire_rate_mult()).is_equal_approx(Config.SPIRIT_MIN_FIRE_FRACTION, 0.01)

	# With real hover fire: shots in a second at full spirit against shots at 10 spirit.
	td.child_entered_tree.connect(_on_child)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 2, 1.0)
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.HOVER_STICKY)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	player.spirit = Config.SPIRIT_MAX
	await runner.simulate_frames(2)
	_shots = 0
	await runner.simulate_frames(66)
	var full := _shots
	target.joy = 0.0
	player.spirit = 10.0
	player._fire_cooldown = 0.0
	_shots = 0
	await runner.simulate_frames(66)
	var low := _shots
	assert_int(full).is_greater(3)
	assert_int(low).is_greater(0)
	assert_float(float(low)).is_less(float(full) * 0.75)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Going dim --------------------------------------------------------------------------------------------------


func test_at_zero_spirit_the_player_goes_dim_and_walks_at_half_speed() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	player.spirit = 5.0
	player.lose_spirit(5.0)
	assert_bool(player.is_dim).is_true()
	assert_float(player.dim_level()).is_equal(1.0)
	await runner.simulate_frames(2)
	assert_str(td.hud.spirit_label.text).contains("DIM")

	var start: Vector3 = player.global_position
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(60)
	runner.simulate_key_release(KEY_W)
	var walked := start.distance_to(player.global_position)
	assert_float(walked).is_equal_approx(Config.TD_MOVE_SPEED * Config.DIM_MOVE_MULT, 0.25)
	# The body has drained to grey.
	var body: StandardMaterial3D = (player.look as PlayerLookPlaceholder).body_mat
	assert_bool(body.albedo_color.is_equal_approx(Config.DIM_PLAYER_GREY)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_dim_player_fires_no_joy_and_cannot_burst() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	_go_dim(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.HOVER_STICKY)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(90)
	assert_object(player.target).is_same(target)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)
	assert_float(target.joy).is_equal(0.0)
	runner.simulate_key_pressed(KEY_G)
	await runner.simulate_frames(2)
	assert_float(player.burst_cooldown).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_people_reach_for_a_player_but_ignore_a_dim_one() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	var dimmed: Person = td.people[0]
	var rescued: Person = td.people[1]
	_rescue(rescued, Vector3(0, 0, 10))
	TopDownTestUtil.place(dimmed, Vector3(0, 0, 5), 1, 0.95)
	var start_z := dimmed.global_position.z
	await runner.simulate_frames(60)
	# A player who is not dim draws them in (toward z = 0).
	assert_float(start_z - dimmed.global_position.z).is_greater(0.4)

	# A dim player is ignored: the dimmed person turns to the rescued person (toward z = 10) instead.
	TopDownTestUtil.place(dimmed, Vector3(0, 0, 5), 1, 0.95)
	_go_dim(td)
	await runner.simulate_frames(60)
	assert_float(dimmed.global_position.z - 5.0).is_greater(0.4)
	assert_float(player.spirit).is_less(1.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Recovery ---------------------------------------------------------------------------------------------------


# Rescues eight people on a ring of radius 4 around the origin and lets the border form around them.
func _form_border(runner: GdUnitSceneRunner, td: TopDownMain) -> void:
	for i: int in range(8):
		var a := TAU * float(i) / 8.0
		_rescue(td.people[i], Vector3(cos(a) * 4.0, 0.0, sin(a) * 4.0))
	await runner.simulate_frames(300)
	assert_bool(td.border.active).is_true()


func test_recovery_inside_the_border_grows_with_depth_and_stops_outside_it() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _form_border(runner, td)
	var centre := td.border.centre
	td.player.global_position = Vector3(centre.x, 0.0, centre.z)
	var deep := td.dim_recovery_rate()
	assert_float(deep).is_equal_approx(Config.DIM_RECOVER_RATE, 0.01)

	# Half a metre inside the line: depth protection 0.5.
	var edge := Vector2(td.border.polygon[0].x, td.border.polygon[0].y)
	var inward := (Vector2(centre.x, centre.z) - edge).normalized()
	var shallow_pt := edge + inward * 0.5
	td.player.global_position = Vector3(shallow_pt.x, 0.0, shallow_pt.y)
	var shallow := td.dim_recovery_rate()
	var expected := Config.DIM_RECOVER_RATE * (Config.DIM_RECOVER_BASE + Config.DIM_RECOVER_DEPTH * 0.5)
	assert_float(shallow).is_equal_approx(expected, 0.4)
	assert_float(shallow).is_less(deep)

	var outside := edge - inward * 3.0
	td.player.global_position = Vector3(outside.x, 0.0, outside.y)
	assert_float(td.dim_recovery_rate()).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_dim_player_deep_inside_the_border_recovers_and_leaves_dim_at_thirty() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _form_border(runner, td)
	var player: TopDownPlayer = td.player
	player.global_position = Vector3(td.border.centre.x, 0.0, td.border.centre.z)
	player.spirit = 0.0
	player.lose_spirit(1.0)
	assert_bool(player.is_dim).is_true()
	await runner.simulate_frames(60)
	assert_float(player.spirit).is_equal_approx(Config.DIM_RECOVER_RATE, 1.5)
	assert_bool(player.is_dim).is_true()
	# Past 30 spirit (about three seconds in all) the player is back to normal.
	await runner.simulate_frames(150)
	assert_float(player.spirit).is_greater_equal(Config.DIM_EXIT_SPIRIT)
	assert_bool(player.is_dim).is_false()
	assert_float(player.dim_level()).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_leaving_dim_needs_thirty_spirit() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	_go_dim(td)
	player.add_spirit(20.0)
	assert_bool(player.is_dim).is_true()
	player.add_spirit(9.0)
	assert_bool(player.is_dim).is_true()
	player.add_spirit(1.0)
	assert_bool(player.is_dim).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_before_a_border_a_dim_player_recovers_only_near_the_landmark() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	var landmark := Config.BORDER_LANDMARK_POS
	player.global_position = Vector3(landmark.x, 0.0, landmark.z + 5.0)
	_go_dim(td)
	assert_bool(td.border.active).is_false()
	assert_float(td.dim_recovery_rate()).is_equal(Config.DIM_RECOVER_RATE)
	await runner.simulate_frames(60)
	assert_float(player.spirit).is_equal_approx(Config.DIM_RECOVER_RATE, 1.5)

	player.global_position = Vector3(landmark.x, 0.0, landmark.z + 12.0)
	var before := player.spirit
	await runner.simulate_frames(60)
	assert_float(player.spirit).is_equal_approx(before, 0.001)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The border loses heart --------------------------------------------------------------------------------------


func test_a_dim_player_makes_the_border_dim_and_lose_ground_faster() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _form_border(runner, td)
	td.player.global_position = Vector3(40, 0, 40)
	assert_float(td.border.loss_mult).is_equal(1.0)
	assert_float(td.ground.loss_mult).is_equal(1.0)
	assert_float(td.border.flicker()).is_equal(1.0)
	_go_dim(td)
	await runner.simulate_frames(2)
	assert_float(td.border.loss_mult).is_equal(Config.DIM_LOSS_MULT)
	assert_float(td.ground.loss_mult).is_equal(Config.DIM_LOSS_MULT)
	# The line flickers: its brightness swings between the minimum and full over the flicker period.
	var lo := INF
	var hi := -INF
	for i: int in range(40):
		await runner.simulate_frames(1)
		lo = minf(lo, td.border.flicker())
		hi = maxf(hi, td.border.flicker())
	assert_float(lo).is_less(0.4)
	assert_float(hi).is_greater(0.9)
	await TopDownTestUtil.leave_loaded_scene(td)


# One dimmed person presses a bare border for one second: how much joy its members lose in all.
func _press_loss(dim: bool) -> float:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = Border.circle_polygon(Vector2.ZERO, 5.0, Config.BORDER_SAMPLES)
	border.active = true
	var rescued: Array[Person] = []
	for i: int in range(14):
		var p: Person = auto_free(Person.new())
		add_child(p)
		p.is_rescued = true
		p.joy = Config.JOY_MAX
		var a := TAU * float(i) / 14.0
		p.position = Vector3(cos(a) * 5.0, 0.0, sin(a) * 5.0)
		rescued.append(p)
	border._assign_members(rescued)
	var presser: Person = auto_free(Person.new())
	add_child(presser)
	presser.gloom = 0.95
	presser.position = Vector3(6.0, 0.0, 0.0)
	border.set_player_dim(dim)
	var everyone: Array[Person] = [presser]
	everyone.append_array(rescued)
	var before := 0.0
	for p: Person in rescued:
		before += p.joy
	border._press_darkness(everyone, 1.0, 1.0)
	var after := 0.0
	for p: Person in rescued:
		after += p.joy
	return before - after


func test_the_border_drains_one_and_a_half_times_faster_while_the_player_is_dim() -> void:
	var normal := _press_loss(false)
	var dim := _press_loss(true)
	assert_float(normal).is_greater(1.0)
	assert_float(dim / normal).is_equal_approx(Config.DIM_LOSS_MULT, 0.001)


func _erosion_after(mult: float) -> float:
	var g: PaintedGround = auto_free(PaintedGround.new())
	add_child(g)
	g.setup(40, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)
	var lone: Person = auto_free(Person.new())
	add_child(lone)
	lone.global_position = Vector3.ZERO
	lone.receive_joy(0, Config.JOY_MAX, 0.0)
	var people: Array = [lone]
	for i: int in range(100):
		g.update_paint(people, Config.GROUND_UPDATE_INTERVAL)
	var dark: Person = auto_free(Person.new())
	add_child(dark)
	dark.gloom = 0.9
	dark.global_position = Vector3(4.0, 0.0, 0.0)
	people.append(dark)
	var before := g.paint_weight_at(Vector3(4.5, 0.0, 0.5))
	g.loss_mult = mult
	for i: int in range(4):
		g.update_paint(people, Config.GROUND_UPDATE_INTERVAL)
	return before - g.paint_weight_at(Vector3(4.5, 0.0, 0.5))


func test_paint_erodes_one_and_a_half_times_faster_while_the_player_is_dim() -> void:
	var normal := _erosion_after(1.0)
	var dim := _erosion_after(Config.DIM_LOSS_MULT)
	assert_float(normal).is_greater(0.05)
	assert_float(dim / normal).is_greater(1.35)
