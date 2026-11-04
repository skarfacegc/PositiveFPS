extends GdUnitTestSuite

# Checkpoint 5: the wobble alert. An off-screen wobbling person gets a pulsing edge pointer (one per cluster, at most
# WOBBLE_ALERT_MAX), which goes when they are saved, relapse, come on screen or the round ends. Each wobbler is also a
# pulsing blip on the minimap, in both looks.


# Makes `p` a rescued person who has just begun to wobble (joy drained just below the relapse line), with the relapse
# gate open and no grace, so the wobble runs as the person's own timer says.
func _start_wobble(p: Person) -> void:
	p.is_rescued = true
	p.grace_left = 0.0
	p.loss_mult = 1.0
	p.patch_mult = 1.0
	p.relapse_gate = Callable()
	p.joy = p.joy_needed()
	p.drain_joy(p.joy - p.joy_needed() * Config.RELAPSE_FRACTION + 1.0)


# A floor spot a little way from the player that the camera does not show, so a wobbler there is off screen.
func _off_screen_spot(td: TopDownMain) -> Vector3:
	for ix: int in range(-4, 5):
		for iz: int in range(-4, 5):
			var spot := Vector3(ix * 8.0, 0.0, iz * 8.0)
			if spot.distance_to(td.player.global_position) > 20.0 and not _on_screen(td, spot):
				return spot
	assert_bool(false).override_failure_message("no off-screen spot on the plaza").is_true()
	return Vector3.ZERO


func _refresh_minimap(td: TopDownMain) -> void:
	td.minimap.refresh_from(
		td.ground, td.border, td.people, td.player.global_position, td._view_centre(), td.view_half_extents()
	)


func _on_screen(td: TopDownMain, spot: Vector3) -> bool:
	return LandmarkPointers.on_screen(TopDownTestUtil.screen_of(td, spot), Vector2(1280, 720))


# A level with everyone parked far away and one rescued person wobbling off screen.
func _level_with_off_screen_wobbler() -> Array:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, _off_screen_spot(td), 0, 0.0)
	_start_wobble(p)
	return [runner, td, p]


# --- The pointer ----------------------------------------------------------------------------------------------------


func test_a_pointer_shows_for_an_off_screen_wobbler() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	var p: Person = parts[2]
	assert_bool(p.wobbling).is_true()
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(1)
	var s := td.wobble_alert.first_pointer()
	assert_int(s["count"]).is_equal(1)
	assert_float(s["urgency"]).is_equal_approx(p.wobble_progress(), 0.001)
	var tip: Vector2 = s["tip"]
	assert_float(tip.x).is_greater_equal(0.0)
	assert_float(tip.x).is_less_equal(1280.0)
	assert_float(tip.y).is_greater_equal(0.0)
	assert_float(tip.y).is_less_equal(720.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_goes_when_the_wobbler_is_saved() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	var p: Person = parts[2]
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(1)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	assert_bool(p.wobbling).is_false()
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_goes_when_the_wobbler_relapses() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	var p: Person = parts[2]
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(1)
	p.wobble_left = 0.0
	p.tick(1.0 / 60.0)
	assert_bool(p.is_rescued).is_false()
	assert_bool(p.wobbling).is_false()
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_goes_when_the_wobbler_comes_on_screen() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	var p: Person = parts[2]
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(1)
	TopDownTestUtil.place(p, td.player.global_position, 0, 0.0)
	assert_bool(_on_screen(td, p.global_position)).is_true()
	assert_bool(p.wobbling).is_true()
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_no_pointer_once_the_round_is_over() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	td.running = false
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_pointer_is_drawn_in_the_styled_look_too() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	var runner: GdUnitSceneRunner = parts[0]
	Looks.set_mode(Looks.Mode.STYLED)
	td.wobble_alert.update_now()
	await runner.simulate_frames(3)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	assert_int(td.wobble_alert.shown_count()).is_equal(1)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Clusters -------------------------------------------------------------------------------------------------------


func test_nearby_off_screen_wobblers_share_one_pointer() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	var spot := _off_screen_spot(td)
	var a: Person = td.people[0]
	var b: Person = td.people[1]
	TopDownTestUtil.place(a, spot, 0, 0.0)
	TopDownTestUtil.place(b, spot + Vector3(1.5, 0, 0) * Config.WORLD_SCALE, 0, 0.0)
	_start_wobble(a)
	_start_wobble(b)
	td.wobble_alert.update_now()
	assert_int(td.wobble_alert.shown_count()).is_equal(1)
	assert_int(td.wobble_alert.first_pointer()["count"]).is_equal(2)
	await runner.simulate_frames(3)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_far_apart_wobblers_each_get_a_pointer_up_to_the_cap() -> void:
	var entries: Array[Dictionary] = []
	for k: int in range(4):
		entries.append({"pos": Vector3(k * 60.0, 0, 0), "urgency": 0.5})
	var clusters := WobbleAlert.group(entries, Config.WOBBLE_ALERT_CLUSTER_RADIUS)
	assert_int(clusters.size()).is_equal(4)
	assert_int(Config.WOBBLE_ALERT_MAX).is_less(clusters.size())


func test_grouping_takes_the_most_urgent_first_and_means_the_centre() -> void:
	var entries: Array[Dictionary] = [
		{"pos": Vector3(0, 0, 0), "urgency": 0.2},
		{"pos": Vector3(3, 0, 0), "urgency": 0.9},
		{"pos": Vector3(100, 0, 0), "urgency": 0.5},
	]
	var clusters := WobbleAlert.group(entries, Config.WOBBLE_ALERT_CLUSTER_RADIUS)
	assert_int(clusters.size()).is_equal(2)
	var first: Dictionary = clusters[0]
	assert_int(first["count"]).is_equal(2)
	assert_float(first["urgency"]).is_equal_approx(0.9, 0.001)
	var centre: Vector3 = first["pos"]
	assert_float(centre.x).is_equal_approx(1.5, 0.001)
	var second: Dictionary = clusters[1]
	assert_int(second["count"]).is_equal(1)
	assert_float(second["urgency"]).is_equal_approx(0.5, 0.001)


# --- The pulse -----------------------------------------------------------------------------------------------------


func test_the_pulse_speeds_up_as_the_wobble_runs_out() -> void:
	assert_float(WobbleAlert.hz_for(0.0)).is_equal_approx(Config.WOBBLE_ALERT_PULSE_HZ_CALM, 0.001)
	assert_float(WobbleAlert.hz_for(1.0)).is_equal_approx(Config.WOBBLE_ALERT_PULSE_HZ_URGENT, 0.001)
	assert_float(WobbleAlert.hz_for(5.0)).is_equal_approx(Config.WOBBLE_ALERT_PULSE_HZ_URGENT, 0.001)
	assert_float(WobbleAlert.pulse_at(0.0, 0.3)).is_equal_approx(0.0, 0.001)
	var half_beat := 0.5 / WobbleAlert.hz_for(0.3)
	assert_float(WobbleAlert.pulse_at(half_beat, 0.3)).is_equal_approx(1.0, 0.001)
	var col := WobbleAlert.colour_at(0.8, 1.0)
	assert_float(col.a).is_equal_approx(1.0, 0.001)
	assert_float(WobbleAlert.colour_at(0.8, 0.0).a).is_less(col.a)


# --- The minimap blip ----------------------------------------------------------------------------------------------


func test_a_wobbler_is_a_minimap_blip_until_saved() -> void:
	var parts := await _level_with_off_screen_wobbler()
	var td: TopDownMain = parts[1]
	var p: Person = parts[2]
	_refresh_minimap(td)
	assert_int(td.minimap.wobble_marks.size()).is_equal(1)
	p.receive_joy(0, Config.JOY_MAX, 0.0)
	_refresh_minimap(td)
	assert_int(td.minimap.wobble_marks.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_blip_is_drawn_in_both_looks() -> void:
	assert_float(MinimapLookPlaceholder.new().wobble_colour(0.5).a).is_greater(0.0)
	assert_float(MinimapLookStyled.new().wobble_colour(0.5).a).is_greater(0.0)
	assert_float(MinimapLook.new().wobble_colour(0.5).a).is_equal(0.0)
	assert_float(MinimapLookStyled.new().wobble_colour(0.0).a).is_less(MinimapLookStyled.new().wobble_colour(1.0).a)
