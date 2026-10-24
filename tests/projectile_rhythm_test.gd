extends GdUnitTestSuite

# Round 7 projectile rhythm and impacts, in the real top-down level. Shots come from real clicks (lock-on). Each element
# fires at its own rate (music twice as often as nature, art half as often) and delivers the same joy per second.
# Each element also has its own impact: a sound ring (music), a bigger splat (art) and a petal burst (nature).


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Moves the mouse over the floor under `spot` and clicks there (lock-on).
func _click_at(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


# Clicks empty ground, which drops the lock.
func _release(runner: GdUnitSceneRunner, td: TopDownMain) -> void:
	await _click_at(runner, td, TopDownTestUtil.clear_spot(td))


# Impact nodes of one kind ("ring", "splat" or "petals") still in the level.
func _impacts(td: TopDownMain, kind: String) -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in td.get_tree().get_nodes_in_group(JoyProjectile.IMPACT_GROUP):
		if td.is_ancestor_of(node) and node.get_meta("impact_kind", "") == kind:
			out.append(node)
	return out


# Locks onto `target` (of `affinity`, 8 m in front of the player) and fires for `frames` frames. Their joy is cleared
# each frame so they are never rescued (every shot stays a hit). Returns the shots of that element and the joy they
# delivered to the person.
func _measure(runner: GdUnitSceneRunner, td: TopDownMain, target: Person, affinity: int, frames: int) -> Dictionary:
	TopDownTestUtil.place(target, Vector3(0, 0, -5), affinity, 0.0)
	var shots: Array[int] = [0]
	var counter := func(node: Node) -> void:
		if node is JoyProjectile and (node as JoyProjectile).element == affinity:
			shots[0] += 1
	td.child_entered_tree.connect(counter)
	await _click_at(runner, td, target.global_position)
	var joy_total: float = 0.0
	for i: int in range(frames):
		await runner.simulate_frames(1)
		joy_total += target.joy
		target.joy = 0.0
	td.child_entered_tree.disconnect(counter)
	# Drop the lock and send the person away, then let the shots in the air finish before the next measurement.
	await _release(runner, td)
	TopDownTestUtil.place(target, TopDownTestUtil.FAR, affinity, 0.0)
	await runner.simulate_frames(120)
	return {"shots": shots[0], "joy": joy_total}


func test_music_fires_twice_as_often_as_nature_and_art_half_as_often() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var music: Dictionary = await _measure(runner, td, td.people[0], Config.Element.MUSIC, 180)
	var art: Dictionary = await _measure(runner, td, td.people[1], Config.Element.ART, 180)
	var nature: Dictionary = await _measure(runner, td, td.people[2], Config.Element.NATURE, 180)
	var m_count: int = music["shots"]
	var a_count: int = art["shots"]
	var n_count: int = nature["shots"]
	var m_shots := float(m_count)
	var a_shots := float(a_count)
	var n_shots := float(n_count)
	assert_float(m_shots).is_greater(0.0)
	assert_float(m_shots / n_shots).is_equal_approx(2.0, 0.15)
	assert_float(a_shots / n_shots).is_equal_approx(0.5, 0.08)


func test_joy_per_second_is_about_equal_for_music_and_art() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var music: Dictionary = await _measure(runner, td, td.people[0], Config.Element.MUSIC, 180)
	var art: Dictionary = await _measure(runner, td, td.people[1], Config.Element.ART, 180)
	var m_joy: float = music["joy"]
	var a_joy: float = art["joy"]
	assert_float(m_joy).is_greater(0.0)
	# Music hits twice as often for half the joy each; art the other way round. Within 15% of each other.
	assert_float(m_joy / a_joy).is_equal_approx(1.0, 0.15)


func test_music_hit_makes_a_sound_ring_that_frees_itself() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), Config.Element.MUSIC, 0.0)
	await _click_at(runner, td, target.global_position)

	var frames := 0
	while _impacts(td, "ring").is_empty() and frames < 120:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(_impacts(td, "ring").size()).is_greater(0)

	# Let go and wait out the notes in the air. The rings are gone once their 0.35 s is over.
	await _release(runner, td)
	await runner.simulate_frames(180)
	assert_int(_impacts(td, "ring").size()).is_equal(0)


func test_art_splat_is_bigger_than_before_and_frees_itself() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), Config.Element.ART, 0.0)
	await _click_at(runner, td, target.global_position)

	var frames := 0
	while _impacts(td, "splat").is_empty() and frames < 240:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(_impacts(td, "splat").size()).is_greater(0)
	var splat := _impacts(td, "splat")[0] as MeshInstance3D
	var disc := splat.mesh as CylinderMesh
	assert_float(disc.top_radius).is_equal_approx(Config.TD_SPLAT_RADIUS, 0.001)
	# Round 7: bigger than the round 6 splat (0.6 m).
	assert_float(disc.top_radius).is_greater(0.4)

	await _release(runner, td)
	await runner.simulate_frames(300)
	assert_int(_impacts(td, "splat").size()).is_equal(0)


func test_nature_hit_bursts_petals_and_blooms_then_both_free_themselves() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), Config.Element.NATURE, 0.0)
	await _click_at(runner, td, target.global_position)

	var frames := 0
	while _impacts(td, "petals").is_empty() and frames < 240:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(_impacts(td, "petals").size()).is_greater_equal(Config.TD_PETAL_BURST_COUNT)
	assert_int(TopDownTestUtil.blooms(td).size()).is_greater(0)

	await _release(runner, td)
	await runner.simulate_frames(300)
	assert_int(_impacts(td, "petals").size()).is_equal(0)
	assert_int(TopDownTestUtil.blooms(td).size()).is_equal(0)
