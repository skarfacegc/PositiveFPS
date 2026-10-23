extends GdUnitTestSuite

# Round 6 projectile trails and visual size, in the real top-down level. Shots come from real clicks (lock-on), so
# the element is the target's affinity, as a player would get it. Trail pieces are found through their group
# (JoyProjectile.TRAIL_GROUP) and the element tag each one carries.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	await runner.simulate_frames(60)
	return {"runner": runner, "td": runner.scene()}


# Moves the mouse over the floor under `spot` and clicks there.
func _click_at(runner: GdUnitSceneRunner, td: TopDownMain, spot: Vector3) -> void:
	runner.simulate_mouse_move(TopDownTestUtil.screen_of(td, spot))
	await runner.simulate_frames(2)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(2)


# Every trail piece in the level that was left by `element`.
func _trail_pieces(td: TopDownMain, element: int) -> Array[Node]:
	var out: Array[Node] = []
	for node: Node in td.get_tree().get_nodes_in_group(JoyProjectile.TRAIL_GROUP):
		var tagged: int = node.get_meta("trail_element", -1)
		if tagged == element:
			out.append(node)
	return out


# True if the piece's colour (ignoring its fading alpha) is `col`.
func _colour_is(node: Node, col: Color) -> bool:
	var mesh := node as MeshInstance3D
	var mat := mesh.material_override as StandardMaterial3D
	var c := mat.albedo_color
	return Color(c.r, c.g, c.b).is_equal_approx(Color(col.r, col.g, col.b))


func _is_petal_colour(node: Node) -> bool:
	for col: Color in Config.TD_PETAL_COLORS:
		if _colour_is(node, col):
			return true
	return false


func test_locked_shots_of_each_element_leave_their_own_trail_colour() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]

	for affinity: int in range(3):
		TopDownTestUtil.place(target, Vector3(0, 0, -8), affinity, 0.0)
		await _click_at(runner, td, target.global_position)
		await runner.simulate_frames(20)
		# Let go of the lock before the next element, so only one element is firing at a time.
		await _click_at(runner, td, Vector3(-25, 0, 25))

		var pieces := _trail_pieces(td, affinity)
		assert_int(pieces.size()).is_greater(0)
		for node: Node in pieces:
			if affinity == Config.Element.MUSIC:
				assert_bool(_colour_is(node, Config.TD_TRAIL_COLOR)).is_true()
			elif affinity == Config.Element.ART:
				assert_bool(_colour_is(node, Config.TD_DRIP_COLOR)).is_true()
			else:
				assert_bool(_is_petal_colour(node)).is_true()


func test_music_trail_pieces_free_themselves_after_their_lifetime() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	var target: Person = td.people[0]
	TopDownTestUtil.place(target, Vector3(0, 0, -8), Config.Element.MUSIC, 0.0)
	await _click_at(runner, td, target.global_position)
	await runner.simulate_frames(20)
	await _click_at(runner, td, Vector3(-25, 0, 25))

	# Wait for the notes in the air to finish (they hit or fizzle).
	var frames := 0
	while not TopDownTestUtil.projectiles(td).is_empty() and frames < 300:
		await runner.simulate_frames(1)
		frames += 1
	assert_int(TopDownTestUtil.projectiles(td).size()).is_equal(0)
	# Their trail is still there, but each piece lives only TD_TRAIL_SECONDS. Give them that long, plus a margin.
	await runner.simulate_frames(int((Config.TD_TRAIL_SECONDS + 0.2) * 60.0))
	assert_int(_trail_pieces(td, Config.Element.MUSIC).size()).is_equal(0)


func test_each_projectile_leaves_at_most_the_trail_cap() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	# A flower flying level for about a second, far from everyone, so nothing stops it before the cap.
	var flower := JoyProjectile.new()
	flower.element = Config.Element.NATURE
	flower.people = td.people
	flower.velocity = Vector3(0, 0, -9)
	td.add_child(flower)
	flower.global_position = Vector3(0, 5, 0)

	await runner.simulate_frames(60)
	assert_bool(is_instance_valid(flower)).is_true()
	assert_int(flower.trail_pieces).is_equal(Config.TD_TRAIL_MAX_PIECES)
	# The cap holds: more flight does not leave more pieces.
	await runner.simulate_frames(20)
	assert_bool(is_instance_valid(flower)).is_true()
	assert_int(flower.trail_pieces).is_equal(Config.TD_TRAIL_MAX_PIECES)


func test_projectiles_are_drawn_bigger_in_top_down() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var note := JoyProjectile.new()
	note.element = Config.Element.MUSIC
	td.add_child(note)
	note.global_position = Vector3(0, 5, 0)
	await runner.simulate_frames(1)
	assert_float(note.scale.x).is_equal_approx(Config.TD_PROJECTILE_VISUAL_SCALE, 0.001)
