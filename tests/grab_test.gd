extends GdUnitTestSuite

# Round 12a: dance with the gloom. Dimmed people within reach start a grab with a visible wind-up, lunge, and drain
# spirit if the player stays. The twirl (Space) dodges: out of range avoids it, a twirl just before it lands is a
# perfect twirl with a small joy burst. Cooldowns, the HUD, and the dimmed haze are checked too.

# What the grab signals reported: true for a perfect twirl, false for a plain avoid.
var _avoided: Array[bool] = []
var _landed: int = 0


func _on_avoided(_p: Person, perfect: bool) -> void:
	_avoided.append(perfect)


func _on_landed(_p: Person) -> void:
	_landed += 1


# The level with everyone parked away, one dimmed grabber `dist` metres south of the player (who stands at the origin),
# and the player's spirit at 80.
func _start(dist: float = 1.2) -> Dictionary:
	_avoided.clear()
	_landed = 0
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(20)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.player.spirit = 80.0
	var grabber: Person = td.people[0]
	TopDownTestUtil.place(grabber, Vector3(0, 0, dist), 1, 0.95)
	td.grabs.grab_avoided.connect(_on_avoided)
	td.grabs.grab_landed.connect(_on_landed)
	return {"runner": runner, "td": td, "grabber": grabber}


# --- The wind-up and the landing ---------------------------------------------------------------------------------


func test_the_windup_is_visible_then_the_grab_drains_spirit_if_the_player_stays() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var grabber: Person = s["grabber"]
	await runner.simulate_frames(15)
	assert_bool(td.grabs.is_winding_up(grabber)).is_true()
	assert_float(grabber.grab_frac).is_greater(0.1)
	assert_bool(grabber.look.grab_ring.visible).is_true()
	var early_ring: float = grabber.look.grab_ring.scale.x
	var early_lean: float = grabber.look.visual.rotation.x
	assert_float(td.player.spirit).is_equal(80.0)

	await runner.simulate_frames(15)
	# The ring has grown and the grabber leans further back (the placeholder look leans on x, positive is backward).
	assert_float(grabber.look.grab_ring.scale.x).is_greater(early_ring)
	assert_float(grabber.look.visual.rotation.x).is_greater(early_lean)
	assert_float(grabber.look.visual.rotation.x).is_greater(0.1)
	assert_float(td.player.spirit).is_equal(80.0)

	# The wind-up lasts 0.7 s and the lunge 0.15 s: the grab lands and costs 25 spirit.
	await runner.simulate_frames(40)
	assert_float(td.player.spirit).is_equal_approx(80.0 - Config.GRAB_SPIRIT_DRAIN, 0.01)
	assert_int(_landed).is_equal(1)
	assert_str(td.hud.alert_label.text).contains("Grabbed")
	assert_bool(td.grabs.is_winding_up(grabber)).is_false()
	assert_float(grabber.grab_frac).is_equal(0.0)

	# Then the cue is gone, and that person waits out the cooldown before the next grab.
	await runner.simulate_frames(20)
	assert_bool(grabber.look.grab_ring.visible).is_false()
	assert_float(td.grabs.cooldown_left(grabber)).is_greater(1.0)
	await runner.simulate_frames(90)
	assert_float(td.player.spirit).is_equal_approx(80.0 - Config.GRAB_SPIRIT_DRAIN, 0.01)
	# After the cooldown (2.5 s) another wind-up and lunge: another 25.
	await runner.simulate_frames(180)
	assert_float(td.player.spirit).is_equal_approx(80.0 - 2.0 * Config.GRAB_SPIRIT_DRAIN, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_walking_out_of_reach_avoids_the_grab() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(5)
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(80)
	runner.simulate_key_release(KEY_W)
	assert_float(td.player.spirit).is_equal(80.0)
	assert_int(_landed).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_people_far_away_or_facing_a_dim_player_do_not_grab() -> void:
	var s: Dictionary = await _start(4.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var grabber: Person = s["grabber"]
	# 4 m is outside GRAB_RANGE: no wind-up yet (the grabber is also walking toward the player, so check at once).
	await runner.simulate_frames(3)
	assert_bool(td.grabs.is_grabbing(grabber)).is_false()
	TopDownTestUtil.place(grabber, Vector3(0, 0, 1.2), 1, 0.95)
	td.player.lose_spirit(1000.0)
	await runner.simulate_frames(60)
	assert_bool(td.grabs.is_grabbing(grabber)).is_false()
	assert_float(grabber.grab_frac).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The twirl --------------------------------------------------------------------------------------------------


func test_space_twirls_three_metres_in_the_move_direction_and_has_a_cooldown() -> void:
	var s: Dictionary = await _start(30.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	TopDownTestUtil.send_everyone_away(td)
	await runner.simulate_frames(5)
	var start: Vector3 = player.global_position
	runner.simulate_key_press(KEY_D)
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(4)
	assert_bool(player.is_twirling()).is_true()
	assert_float(player.twirl_cooldown).is_greater(Config.TWIRL_COOLDOWN - 0.2)
	assert_str(td.hud.twirl_label.text).contains("s")
	await runner.simulate_frames(16)
	runner.simulate_key_release(KEY_D)
	var moved: Vector3 = player.global_position - start
	assert_float(moved.x).is_greater(Config.TWIRL_DISTANCE - 0.3)
	assert_float(moved.x).is_less(Config.TWIRL_DISTANCE + 0.9)  # the dash plus a little walking before it ended
	assert_bool(player.is_twirling()).is_false()

	# During the cooldown a second press does nothing.
	var age_before: float = player.twirl_age
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(2)
	assert_float(player.twirl_age).is_greater(age_before)

	# After the cooldown (1.5 s) the twirl works again, and the HUD says READY first.
	await runner.simulate_frames(90)
	assert_str(td.hud.twirl_label.text).contains("READY")
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(2)
	assert_bool(player.is_twirling()).is_true()
	assert_float(player.twirl_age).is_less(0.1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_standing_twirl_dashes_the_way_the_player_faces_and_works_while_dim() -> void:
	var s: Dictionary = await _start(30.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var player: TopDownPlayer = td.player
	TopDownTestUtil.send_everyone_away(td)
	player.lose_spirit(1000.0)
	await runner.simulate_frames(5)
	var start: Vector3 = player.global_position
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(20)
	assert_float(start.distance_to(player.global_position)).is_equal_approx(Config.TWIRL_DISTANCE, 0.3)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_twirl_made_early_to_get_out_of_range_avoids_the_grab_without_a_burst() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var bystander: Person = td.people[1]
	TopDownTestUtil.place(bystander, Vector3(0, 0, -4), 0, 0.0)
	await runner.simulate_frames(3)
	runner.simulate_key_press(KEY_W)
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(10)
	runner.simulate_key_release(KEY_W)
	await runner.simulate_frames(70)
	assert_float(td.player.spirit).is_equal(80.0)
	assert_int(_landed).is_equal(0)
	assert_bool(_avoided.has(true)).is_false()
	assert_float(bystander.joy).is_equal(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_perfect_twirl_just_before_the_grab_lands_avoids_it_and_bursts_joy() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var grabber: Person = s["grabber"]
	var bystander: Person = td.people[1]
	# A light-grey person where the player will land after the dash (3 m north).
	TopDownTestUtil.place(bystander, Vector3(0, 0, -4), 0, 0.0)
	var frames := 0
	while grabber.grab_frac < 0.9 and frames < 120:
		await runner.simulate_frames(1)
		frames += 1
	assert_float(grabber.grab_frac).is_greater_equal(0.9)
	runner.simulate_key_press(KEY_W)
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(20)
	runner.simulate_key_release(KEY_W)
	await runner.simulate_frames(10)
	assert_float(td.player.spirit).is_equal(80.0)
	assert_int(_landed).is_equal(0)
	assert_bool(_avoided.has(true)).is_true()
	assert_str(td.hud.alert_label.text).contains("Perfect twirl")
	# The mini burst: half the normal burst joy (best match, up close), and it cost no spirit.
	assert_float(bystander.joy).is_greater(Config.TD_BURST_JOY * Config.TWIRL_BURST_JOY_FRACTION * 0.5)
	assert_float(bystander.joy).is_less_equal(Config.TD_BURST_JOY * Config.TWIRL_BURST_JOY_FRACTION * 2.0 + 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_twirl_too_late_does_not_undo_a_landed_grab() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(60)
	assert_int(_landed).is_equal(1)
	runner.simulate_key_pressed(KEY_SPACE)
	await runner.simulate_frames(10)
	assert_float(td.player.spirit).is_equal_approx(80.0 - Config.GRAB_SPIRIT_DRAIN, 0.01)
	assert_bool(_avoided.has(true)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The dimmed haze ----------------------------------------------------------------------------------------------


func _person_at_level(gloom: float) -> Person:
	var p: Person = auto_free(Person.new())
	p.gloom = gloom
	add_child(p)
	p.tick(0.016)
	return p


func test_dimmed_people_have_a_haze_and_wistful_or_gloomy_people_do_not() -> void:
	var dimmed := _person_at_level(0.95)
	assert_bool(dimmed.look.has_aura()).is_true()
	assert_bool(dimmed.look.aura.visible).is_true()
	var gloomy := _person_at_level(0.5)
	assert_bool(gloomy.look.has_aura()).is_false()
	var wistful := _person_at_level(0.05)
	assert_bool(wistful.look.has_aura()).is_false()
	assert_bool(wistful.look.aura.visible).is_false()
	# A rescued person has none either.
	dimmed.receive_joy(dimmed.affinity, Config.JOY_MAX * 3.0, 0.0)
	assert_bool(dimmed.look.has_aura()).is_false()


# --- Edge cases (direct calls on Grabs) ------------------------------------------------------------------------


func test_a_windup_is_cancelled_when_the_player_goes_dim() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var grabber: Person = s["grabber"]
	await runner.simulate_frames(15)
	assert_bool(td.grabs.is_winding_up(grabber)).is_true()
	td.player.lose_spirit(1000.0)
	await runner.simulate_frames(2)
	assert_bool(td.grabs.is_grabbing(grabber)).is_false()
	assert_float(grabber.grab_frac).is_equal(0.0)
	assert_bool(grabber.look.grab_ring.visible).is_false()
	await runner.simulate_frames(60)
	assert_int(_landed).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func _bare_player_and_person(person_at: Vector3, player_at: Vector3) -> Dictionary:
	var player: TopDownPlayer = auto_free(TopDownPlayer.new())
	add_child(player)
	player.global_position = player_at
	var p: Person = auto_free(Person.new())
	p.gloom = 0.95
	add_child(p)
	p.global_position = person_at
	var grabs: Grabs = auto_free(Grabs.new())
	add_child(grabs)
	grabs.grab_avoided.connect(_on_avoided)
	grabs.grab_landed.connect(_on_landed)
	return {"player": player, "person": p, "grabs": grabs}


func test_a_twirl_from_far_away_that_ends_in_reach_is_a_plain_avoid() -> void:
	_avoided.clear()
	var d := _bare_player_and_person(Vector3.ZERO, Vector3(0, 0, 1.0))
	var player: TopDownPlayer = d["player"]
	var grabs: Grabs = d["grabs"]
	var person: Person = d["person"]
	# The twirl began 10 m away (so nothing was about to land), but the dash ended within reach: still safe, no burst.
	player.twirl_age = 0.1
	player.twirl_from = Vector3(10, 0, 10)
	grabs._resolve(person, player)
	assert_array(_avoided).is_equal([false])
	assert_float(player.spirit).is_equal(Config.SPIRIT_START)

	# A twirl that ended out of reach with a far start: nothing to report.
	_avoided.clear()
	player.global_position = Vector3(0, 0, 6.0)
	grabs._resolve(person, player)
	assert_array(_avoided).is_empty()


func test_aiming_at_a_player_on_the_same_spot_changes_nothing() -> void:
	var d := _bare_player_and_person(Vector3(2, 0, 2), Vector3(2, 0, 2))
	var p: Person = d["person"]
	var before := p.grab_toward
	var grabs: Grabs = d["grabs"]
	var player: TopDownPlayer = d["player"]
	grabs._aim(p, player)
	assert_vector(p.grab_toward).is_equal(before)
