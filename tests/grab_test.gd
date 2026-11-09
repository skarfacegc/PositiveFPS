extends GdUnitTestSuite

# Round 12a: dance with the gloom. Dimmed people within reach start a grab with a visible wind-up, lunge, and drain
# spirit if the player stays. Stepping out of reach before the lunge ends avoids it.
# Cooldowns, the HUD, and the dimmed haze are checked too.

# What the grab signals reported: how many lunges missed, and how many landed.
var _avoided: int = 0
var _landed: int = 0


func _on_avoided(_p: Person) -> void:
	_avoided += 1


func _on_landed(_p: Person) -> void:
	_landed += 1


# The level with everyone parked away, one dimmed grabber `dist` metres south of the player (who stands at the origin),
# and the player's spirit at 80.
func _start(dist: float = 1.2) -> Dictionary:
	_avoided = 0
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
	assert_float(td.player.spirit).is_equal_approx(80.0 - SpiritConfig.GRAB_SPIRIT_DRAIN, 0.01)
	assert_int(_landed).is_equal(1)
	assert_str(td.hud.alert_label.text).contains("Grabbed")
	assert_bool(td.grabs.is_winding_up(grabber)).is_false()
	assert_float(grabber.grab_frac).is_equal(0.0)

	# Then the cue is gone, and that person waits out the cooldown before the next grab.
	await runner.simulate_frames(20)
	assert_bool(grabber.look.grab_ring.visible).is_false()
	assert_float(td.grabs.cooldown_left(grabber)).is_greater(1.0)
	await runner.simulate_frames(90)
	assert_float(td.player.spirit).is_equal_approx(80.0 - SpiritConfig.GRAB_SPIRIT_DRAIN, 0.01)
	# After the cooldown (2.5 s) another wind-up and lunge: another 25.
	await runner.simulate_frames(180)
	assert_float(td.player.spirit).is_equal_approx(80.0 - 2.0 * SpiritConfig.GRAB_SPIRIT_DRAIN, 0.01)
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
	assert_int(_avoided).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_stepping_out_of_reach_as_the_lunge_comes_avoids_it_once() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var grabber: Person = s["grabber"]
	var frames := 0
	while grabber.grab_frac < 0.9 and frames < 120:
		await runner.simulate_frames(1)
		frames += 1
	assert_float(grabber.grab_frac).is_greater_equal(0.9)
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(20)
	runner.simulate_key_release(KEY_W)
	await runner.simulate_frames(10)
	assert_float(td.player.spirit).is_equal(80.0)
	assert_int(_landed).is_equal(0)
	assert_int(_avoided).is_equal(1)
	assert_bool(td.hud.alert_label.text.contains("Grabbed")).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_stepping_away_after_a_landed_grab_does_not_refund_it() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(60)
	assert_int(_landed).is_equal(1)
	runner.simulate_key_press(KEY_W)
	await runner.simulate_frames(10)
	runner.simulate_key_release(KEY_W)
	assert_float(td.player.spirit).is_equal_approx(80.0 - SpiritConfig.GRAB_SPIRIT_DRAIN, 0.01)
	assert_int(_avoided).is_equal(0)
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


func test_a_lunge_that_ends_in_reach_lands_and_one_that_ends_out_of_reach_is_avoided() -> void:
	_avoided = 0
	_landed = 0
	var d := _bare_player_and_person(Vector3.ZERO, Vector3(0, 0, 1.0))
	var player: TopDownPlayer = d["player"]
	var grabs: Grabs = d["grabs"]
	var person: Person = d["person"]
	grabs._resolve(person, player)
	assert_int(_landed).is_equal(1)
	assert_int(_avoided).is_equal(0)
	assert_float(player.spirit).is_equal(SpiritConfig.SPIRIT_START - SpiritConfig.GRAB_SPIRIT_DRAIN)

	# The player has stepped out of reach by the time the lunge ends: the grab misses and costs nothing.
	player.global_position = Vector3(0, 0, 6.0)
	grabs._resolve(person, player)
	assert_int(_landed).is_equal(1)
	assert_int(_avoided).is_equal(1)
	assert_float(player.spirit).is_equal(SpiritConfig.SPIRIT_START - SpiritConfig.GRAB_SPIRIT_DRAIN)


func test_aiming_at_a_player_on_the_same_spot_changes_nothing() -> void:
	var d := _bare_player_and_person(Vector3(2, 0, 2), Vector3(2, 0, 2))
	var p: Person = d["person"]
	var before := p.grab_toward
	var grabs: Grabs = d["grabs"]
	var player: TopDownPlayer = d["player"]
	grabs._aim(p, player)
	assert_vector(p.grab_toward).is_equal(before)
