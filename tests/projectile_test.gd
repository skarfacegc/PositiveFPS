extends GdUnitTestSuite

# Visual joy projectiles: each one must free itself after it arrives. Not player-driven.

const JoyProjectileScript = preload("res://scripts/joy_projectile.gd")


func test_projectiles_free_themselves_on_arrival() -> void:
	var projectiles: Array = []
	for element in range(3):
		var pr = JoyProjectileScript.new()
		pr.element = element
		pr.start = Vector3(0, 1.2, 0)
		pr.end_pos = Vector3(3, 1.2, 0)
		add_child(pr)
		projectiles.append(pr)
	for pr in projectiles:
		assert_bool(pr.is_inside_tree()).is_true()

	# Flight is about 0.2 s; allow up to 2 s of frames.
	for i in range(120):
		await get_tree().process_frame
		var flying := false
		for pr in projectiles:
			if is_instance_valid(pr) and pr.is_inside_tree():
				flying = true
		if not flying:
			break

	for i in range(projectiles.size()):
		var pr = projectiles[i]
		assert_bool(is_instance_valid(pr) and pr.is_inside_tree()).is_false()
	await get_tree().create_timer(1.2).timeout  # Let puff and splat timers finish.
