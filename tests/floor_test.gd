extends GdUnitTestSuite

# The floor (round 10): the cap on floor effects (the oldest priority-3 effect goes first), and the F3 readout of
# the live counts. The F3 check goes through the menu and real keys, as a player would.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# Spawns one music sound ring (a floor effect) at `at` and returns it.
func _ring(td: TopDownMain, at: Vector3) -> Node:
	var pr := JoyProjectile.new()
	pr.element = Config.Element.MUSIC
	td.add_child(pr)
	pr._spawn_sound_ring(at)
	return td.get_child(td.get_child_count() - 1)


func test_the_cap_frees_the_oldest_projectile_effect_first() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var rings: Array[Node] = []
	for i: int in range(Config.TD_MAX_FLOOR_EFFECTS + 5):
		rings.append(_ring(td, Vector3(-30, 0, float(i) * 0.1)))
	# Five more than the cap: the five oldest are freed, and the newest is still there.
	assert_int(FloorEffects.live(td.get_tree()).size()).is_equal(Config.TD_MAX_FLOOR_EFFECTS)
	assert_bool(rings[0].is_queued_for_deletion()).is_true()
	assert_bool(rings[4].is_queued_for_deletion()).is_true()
	assert_bool(rings[rings.size() - 1].is_queued_for_deletion()).is_false()
	await runner_wait(s)


func test_a_higher_priority_effect_outlives_a_projectile_effect_under_the_cap() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	# A priority-2 (target) effect, added first, so it is the oldest of all.
	var target_node := Node3D.new()
	FloorEffects.add(td, target_node, "target", 2, Vector3(-30, 0, 0))
	for i: int in range(Config.TD_MAX_FLOOR_EFFECTS + 5):
		_ring(td, Vector3(-30, 0, float(i) * 0.1))
	assert_bool(target_node.is_queued_for_deletion()).is_false()
	await runner_wait(s)


func test_f3_shows_the_live_floor_effect_counts() -> void:
	get_window().size = Vector2i(1280, 720)
	await get_tree().process_frame
	var menu: GdUnitSceneRunner = scene_runner("res://menu.tscn")
	(menu.scene() as Control).size = Vector2(1280, 720)
	await menu.simulate_frames(10)
	menu.simulate_key_pressed(KEY_1)
	await menu.simulate_frames(10)
	var td: TopDownMain = get_tree().current_scene as TopDownMain
	assert_object(td).is_not_null()
	TopDownTestUtil.send_everyone_away(td)
	_ring(td, Vector3(-30, 0, 0))
	_ring(td, Vector3(-30, 0, 1))
	menu.simulate_key_pressed(KEY_F3)
	await menu.simulate_frames(3)
	assert_bool(td.hud.floor_label.visible).is_true()
	assert_str(td.hud.floor_label.text).contains("floor fx 2/40")
	assert_str(td.hud.floor_label.text).contains("ring 2")
	await TopDownTestUtil.leave_loaded_scene(td)


# Lets the level process a few frames, so tweens and frees run, before the test ends.
func runner_wait(s: Dictionary) -> void:
	var runner: GdUnitSceneRunner = s["runner"]
	await runner.simulate_frames(2)
