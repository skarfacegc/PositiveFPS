extends GdUnitTestSuite

# Joy projectiles on their own (no level): lifetime, landing and the blooms they leave. Not player-driven.


func _spawn(element: int, from: Vector3, velocity: Vector3) -> JoyProjectile:
	var pr := JoyProjectile.new()
	pr.element = element
	pr.velocity = velocity
	add_child(pr)
	pr.global_position = from
	return pr


func _blooms() -> Array[Bloom]:
	var out: Array[Bloom] = []
	for child: Node in get_children():
		if child is Bloom:
			out.append(child as Bloom)
	return out


func test_projectile_with_no_target_fizzles_after_its_lifetime() -> void:
	var pr := _spawn(Config.Element.MUSIC, Vector3(0, 1.2, 0), Vector3(0, 0, -5))
	await get_tree().create_timer(Config.TD_PROJECTILE_LIFETIME + 0.5).timeout
	assert_bool(is_instance_valid(pr)).is_false()


func test_paint_that_lands_frees_itself_and_leaves_a_splat() -> void:
	var before := get_child_count()
	var pr := _spawn(Config.Element.ART, Vector3(0, 1.2, 0), Vector3(0, -4, 0))
	await get_tree().create_timer(0.5).timeout
	assert_bool(is_instance_valid(pr)).is_false()
	# The splat and the puff stay in the level after the blob is gone.
	assert_int(get_child_count()).is_greater(before)


func test_flower_that_lands_leaves_a_bloom_that_frees_itself() -> void:
	var pr := _spawn(Config.Element.NATURE, Vector3(0, 1.2, 0), Vector3(0, -6, 0))
	await get_tree().create_timer(0.5).timeout
	assert_bool(is_instance_valid(pr)).is_false()
	assert_int(_blooms().size()).is_equal(1)
	await get_tree().create_timer(Config.TD_BLOOM_SECONDS + 0.5).timeout
	assert_int(_blooms().size()).is_equal(0)


func test_launch_velocity_for_paint_lands_on_the_target_after_the_flight_time() -> void:
	var from := Vector3(0, 1.2, 0)
	var to := Vector3(6, 1.0, -8)
	var v := JoyProjectile.launch_velocity(Config.Element.ART, from, to)
	var t := Config.TD_PAINT_FLIGHT_TIME
	var landed := from + v * t
	landed.y -= 0.5 * Config.TD_PAINT_GRAVITY * t * t
	assert_float(landed.distance_to(to)).is_less(0.001)
	# Notes and flowers just fly in a straight line at their own speed.
	var note := JoyProjectile.launch_velocity(Config.Element.MUSIC, from, to)
	assert_float(note.length()).is_equal_approx(Config.TD_NOTE_SPEED, 0.001)
	var flower := JoyProjectile.launch_velocity(Config.Element.NATURE, from, to)
	assert_float(flower.length()).is_equal_approx(Config.TD_FLOWER_SPEED, 0.001)


func test_music_note_that_lands_just_fizzles_and_leaves_no_bloom() -> void:
	var pr := _spawn(Config.Element.MUSIC, Vector3(0, 1.2, 0), Vector3(0, -6, 0))
	await get_tree().create_timer(0.5).timeout
	assert_bool(is_instance_valid(pr)).is_false()
	assert_int(_blooms().size()).is_equal(0)


func test_note_with_no_speed_cannot_turn_and_still_fizzles_after_its_lifetime() -> void:
	var goal := Person.new()
	add_child(goal)
	goal.global_position = Vector3(0, 0, -5)
	var pr := _spawn(Config.Element.MUSIC, Vector3(0, 1.2, 0), Vector3.ZERO)
	pr.target = goal
	await get_tree().create_timer(Config.TD_PROJECTILE_LIFETIME + 0.5).timeout
	assert_bool(is_instance_valid(pr)).is_false()
	goal.queue_free()


func test_a_finished_projectile_ignores_further_physics_steps() -> void:
	var pr := _spawn(Config.Element.NATURE, Vector3(0, 1.2, 0), Vector3(0, 0, -3))
	pr._free_self()
	pr._physics_process(1.0 / 60.0)
	assert_bool(pr.is_queued_for_deletion()).is_true()
