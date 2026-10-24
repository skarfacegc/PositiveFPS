extends GdUnitTestSuite

# Top-down joy projectiles and blooms in the real level. Shots come from real clicks (lock-on) where the player
# fires; the projectile physics checks place or launch the projectile directly, so the outcome is what is tested.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Adds a projectile of `element` to the level, flying from the player's chest at `target` (the arc or the homing
# depends on the element). Returns it.
func _launch(td: TopDownMain, element: int, target: Person) -> JoyProjectile:
	var start := td.player.global_position + Vector3(0, 1.2, 0)
	var pr := JoyProjectile.new()
	pr.element = element
	pr.target = target
	pr.people = td.people
	pr.shooter_pos = td.player.global_position
	pr.ignore_rids = [td.player.get_rid()]
	pr.velocity = JoyProjectile.launch_velocity(element, start, target.chest_position())
	td.add_child(pr)
	pr.global_position = start
	return pr


func test_music_note_homes_onto_a_target_that_moved_sideways() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)

	var note := _launch(td, Config.Element.MUSIC, target)
	# The target steps 2.5 m sideways while the note is in the air. A straight note would miss.
	target.global_position = Vector3(2.5, 0, -8)
	await runner.simulate_frames(60)

	assert_float(target.joy).is_greater(0.0)
	assert_bool(is_instance_valid(note)).is_false()


func test_paint_hit_splashes_a_neighbour_but_not_someone_outside_the_radius() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	var neighbour: Person = td.people[1]
	var outsider: Person = td.people[2]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 1, 0.0)
	TopDownTestUtil.place(neighbour, Vector3(0.9, 0, -8), 0, 0.0)  # Outside the hit reach, inside the splash.
	TopDownTestUtil.place(outsider, Vector3(2.4, 0, -8), 0, 0.0)

	_launch(td, Config.Element.ART, target)
	await runner.simulate_frames(45)

	assert_float(target.joy).is_greater(0.0)
	assert_float(neighbour.joy).is_greater(0.0)
	# The direct hit gets the full joy, the splash only a share of it.
	assert_float(target.joy).is_greater(neighbour.joy)
	assert_float(outsider.joy).is_equal(0.0)


func test_bloom_gives_joy_to_people_standing_in_it_then_frees_itself() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var person: Person = td.people[0]
	TopDownTestUtil.place(person, Vector3(0, 0, -3), 2, 0.0)

	var bloom := Bloom.new()
	bloom.people = td.people
	td.add_child(bloom)
	bloom.global_position = Vector3(0, 0, -3)

	await runner.simulate_frames(60)
	assert_float(person.joy).is_greater(0.0)
	assert_bool(is_instance_valid(bloom)).is_true()

	# The bloom lasts TD_BLOOM_SECONDS, then frees itself.
	await runner.simulate_frames(int((Config.TD_BLOOM_SECONDS + 0.5) * 60.0))
	assert_bool(is_instance_valid(bloom)).is_false()


func test_flower_that_lands_leaves_a_bloom() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var person: Person = td.people[0]
	# The flower drops straight down at x = 0 and lands at (0, 0, -3). The person stands 1 m off, so the flower
	# lands next to them (no direct hit) inside the bloom radius.
	TopDownTestUtil.place(person, Vector3(1.0, 0, -3), 2, 0.0)
	var flower := JoyProjectile.new()
	flower.element = Config.Element.NATURE
	flower.people = td.people
	flower.velocity = Vector3(0, -6, 0)
	td.add_child(flower)
	flower.global_position = Vector3(0, 1.2, -3)

	await runner.simulate_frames(20)
	assert_bool(is_instance_valid(flower)).is_false()
	assert_int(TopDownTestUtil.blooms(td).size()).is_equal(1)
	await runner.simulate_frames(60)
	assert_float(person.joy).is_greater(0.0)


func test_projectile_fired_at_a_target_behind_a_block_fizzles_on_the_block() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	# The block at (-20, -18) spans x -22..-18 and z -20..-16. The target stands just beyond it, to the north.
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(-20, 0, -21.5), 0, 0.0)
	td.player.global_position = Vector3(-20, 0, -14.0)
	await runner.simulate_frames(2)

	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(40)
	assert_object(td.player.target).is_same(target)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_greater(0)
	assert_float(target.joy).is_equal(0.0)

	# Drop the lock (click empty ground). The shots already in the air hit the block and fizzle, so none remain.
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, TopDownTestUtil.clear_spot(td)))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(60)
	assert_float(target.joy).is_equal(0.0)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)


func test_projectile_can_miss_and_frees_after_its_lifetime() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), 0, 0.0)

	# Lock on, let the first shot leave, then teleport the target out of reach.
	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_greater(0)
	target.global_position = Vector3(0, 0, -30)

	await runner.simulate_frames(120)
	assert_float(target.joy).is_equal(0.0)
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)


func test_locked_shots_rescue_a_light_grey_person_at_close_range_within_a_second() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(3, 0, 0), 0, 0.0)

	await TopDownTestUtil.select_mode(runner, td, Config.TargetingMode.LOCK_ON)
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, target.global_position))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	var frames := 0
	while not target.is_rescued and frames < 300:
		await runner.simulate_frames(1)
		frames += 1

	# Round 6: a match at close range is 2 x 135 = 270 joy per hit, so 4 hits rescue a light person. Measured: 47
	# frames (about 0.8 s, 1.5x faster than the round 5 count of 72 frames with 90 joy per shot). Bound: 60 frames.
	assert_bool(target.is_rescued).is_true()
	assert_int(frames).is_less(60)
