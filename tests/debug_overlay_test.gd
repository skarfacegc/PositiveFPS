extends GdUnitTestSuite

# Regression for the F3 debug overlay in real play (round 8). The bug: the cover and protection labels were built at
# about 0.5 m tall in the world, which is only about 9 px on screen from the top-down camera, so the overlay looked
# like nothing happened. This test goes the way a player does (menu, key 2, then F3) and checks that the labels are
# visible and big enough to read on a 1280x720 screen.

const MIN_LABEL_PIXELS := 16.0


func test_f3_from_the_menu_shows_readable_on_screen_labels() -> void:
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
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 1, 0.0)
	await menu.simulate_frames(2)

	menu.simulate_key_pressed(KEY_F3)
	await menu.simulate_frames(2)
	assert_bool(td.debug_on).is_true()
	assert_bool(td.hud.debug_hint_label.visible).is_true()
	assert_bool(p.debug_label.visible).is_true()

	# The label's centre is on screen, and its height on screen is at least MIN_LABEL_PIXELS.
	var rect := td.get_viewport().get_visible_rect()
	var label: Label3D = p.debug_label
	assert_bool(rect.has_point(td.camera.unproject_position(label.global_position))).is_true()
	var half := 0.5 * float(label.font_size) * label.pixel_size
	var up: Vector3 = td.camera.global_transform.basis.y
	var top := td.camera.unproject_position(label.global_position + up * half)
	var bottom := td.camera.unproject_position(label.global_position - up * half)
	assert_float(top.distance_to(bottom)).is_greater_equal(MIN_LABEL_PIXELS)

	await TopDownTestUtil.leave_loaded_scene(td)
