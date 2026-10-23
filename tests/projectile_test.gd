extends GdUnitTestSuite

# Visual joy projectiles: each one must free itself after it arrives. Not player-driven.


func test_projectiles_free_themselves_on_arrival() -> void:
	var projectiles: Array = []
	for element: int in range(3):
		var pr: JoyProjectile = JoyProjectile.new()
		pr.element = element
		pr.start = Vector3(0, 1.2, 0)
		pr.end_pos = Vector3(3, 1.2, 0)
		add_child(pr)
		projectiles.append(pr)
	for pr: JoyProjectile in projectiles:
		assert_bool(pr.is_inside_tree()).is_true()

	# Flight is about 0.2 s; allow up to 2 s of frames. Freed projectiles cannot be assigned to typed
	# variables, so this checks the projectiles still in the tree (the test node's children) instead.
	for i: int in range(120):
		await get_tree().process_frame
		var flying := false
		for child: Node in get_children():
			if child is JoyProjectile:
				flying = true
		if not flying:
			break

	var still_in_tree := 0
	for child: Node in get_children():
		if child is JoyProjectile:
			still_in_tree += 1
	assert_int(still_in_tree).is_equal(0)
	await get_tree().create_timer(1.2).timeout  # Let puff and splat timers finish.
