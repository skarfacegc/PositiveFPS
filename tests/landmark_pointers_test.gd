extends GdUnitTestSuite

# Round 22: landmark pointers. An edge pointer (with the landmark's name and boost) for each landmark that is not
# held and
# is off screen, placed on the inset screen edge clear of the HUD; an unheld landmark also gets a pale ring on the
# minimap.

const SCREEN := Vector2(1280, 720)


# The HUD panels as they sit at 1280 x 720 (the minimap, the rescued counter, the bottom bars and the top right panel).
func _hud_rects() -> Array[Rect2]:
	return [
		Rect2(16, 16, 256, 256),  # minimap
		Rect2(16, 280, 260, 30),  # rescued counter
		Rect2(20, 640, 260, 40),  # target
		Rect2(440, 606, 400, 22),  # spirit bar
		Rect2(920, 90, 340, 104),  # landmark panel
		Rect2(440, 4, 400, 52),  # night label and bar
	]


func _clear_of(box: Rect2, rects: Array[Rect2]) -> bool:
	for r: Rect2 in rects:
		if box.intersects(r.grow(HudConfig.LANDMARK_POINTER_CLEAR_MARGIN)):
			return false
	return true


# --- The geometry ---------------------------------------------------------------------------------------------------


func test_the_edge_point_is_where_the_ray_from_the_centre_leaves_the_inset_rectangle() -> void:
	var inset := HudConfig.LANDMARK_POINTER_INSET
	var right := LandmarkPointers.edge_point(Vector2(2000, 360), SCREEN, inset)
	assert_float(right.x).is_equal_approx(SCREEN.x - inset, 0.01)
	assert_float(right.y).is_equal_approx(360.0, 0.01)
	var up := LandmarkPointers.edge_point(Vector2(640, -900), SCREEN, inset)
	assert_float(up.y).is_equal_approx(inset, 0.01)
	assert_float(up.x).is_equal_approx(640.0, 0.01)


func test_a_target_at_the_centre_has_its_pointer_at_the_centre() -> void:
	assert_vector(LandmarkPointers.edge_point(SCREEN * 0.5, SCREEN, 44.0)).is_equal_approx(
		SCREEN * 0.5, Vector2.ONE * 0.01
	)


func test_on_screen_means_inside_the_window() -> void:
	assert_bool(LandmarkPointers.on_screen(Vector2(100, 100), SCREEN)).is_true()
	assert_bool(LandmarkPointers.on_screen(Vector2(-5, 100), SCREEN)).is_false()
	assert_bool(LandmarkPointers.on_screen(Vector2(1281, 10), SCREEN)).is_false()


# The label sits inward of the edge: on the right edge it is to the left of the tip, and the whole box is on screen.
func test_a_pointer_on_the_right_edge_has_its_label_to_the_left_inside_the_window() -> void:
	var placed := LandmarkPointers.place(Vector2(2000, 360), SCREEN, Vector2(200, 24), [] as Array[Rect2])
	var tip: Vector2 = placed["tip"]
	var label: Rect2 = placed["label"]
	var box: Rect2 = placed["box"]
	assert_float(tip.x).is_equal_approx(SCREEN.x - HudConfig.LANDMARK_POINTER_INSET, 0.01)
	assert_float(label.end.x).is_less(tip.x)
	assert_float(box.position.x).is_greater_equal(0.0)
	assert_float(box.end.x).is_less_equal(SCREEN.x)


# A HUD panel on the path of the pointer: the pointer slides along the edge to a clear spot.
func test_a_pointer_slides_along_the_edge_to_clear_a_hud_panel() -> void:
	var avoid: Array[Rect2] = [Rect2(1000, 300, 280, 120)]
	var placed := LandmarkPointers.place(Vector2(2000, 360), SCREEN, Vector2(200, 24), avoid)
	var box: Rect2 = placed["box"]
	assert_bool(box.intersects(avoid[0].grow(HudConfig.LANDMARK_POINTER_CLEAR_MARGIN))).is_false()
	var tip: Vector2 = placed["tip"]
	assert_float(tip.x).is_equal_approx(SCREEN.x - HudConfig.LANDMARK_POINTER_INSET, 0.01)
	assert_bool(absf(tip.y - 360.0) > 1.0).is_true()


# Whatever way the landmark lies, the pointer's box is on screen and clear of every HUD panel at 1280 x 720.
func test_the_pointer_fits_the_screen_and_clears_the_hud_from_every_direction() -> void:
	var rects := _hud_rects()
	var label := Vector2(260, 24)
	for k: int in range(16):
		var a := TAU * float(k) / 16.0
		var target := SCREEN * 0.5 + Vector2(cos(a), sin(a)) * 900.0
		var placed := LandmarkPointers.place(target, SCREEN, label, rects as Array[Rect2])
		var box: Rect2 = placed["box"]
		assert_float(box.position.x).is_greater_equal(0.0)
		assert_float(box.end.x).is_less_equal(SCREEN.x)
		assert_float(box.position.y).is_greater_equal(0.0)
		assert_float(box.end.y).is_less_equal(SCREEN.y)
		assert_bool(_clear_of(box, rects)).override_failure_message("direction %d overlaps the HUD" % k).is_true()


# --- The minimap ring -----------------------------------------------------------------------------------------------


# The pale ring round an unheld landmark is drawn on the placeholder minimap, and not once it is held. The base look
# (and
# so the styled look) draws no ring and keeps the star at its usual size.
func test_an_unheld_landmark_has_a_pale_ring_on_the_placeholder_minimap_and_a_held_one_does_not() -> void:
	var m: Minimap = auto_free(Minimap.new())
	add_child(m)
	m.look = MinimapLookPlaceholder.new()
	m.landmark_pts = PackedVector2Array([Vector2(-20, -20)])
	var unheld: Array[bool] = [false]
	m.held_landmarks = unheld
	m._render()
	var pale := _count_colour(m._image, HudConfig.TD_MINIMAP_LANDMARK_UNHELD_RING_COLOUR)
	assert_int(pale).is_greater(20)
	var held: Array[bool] = [true]
	m.held_landmarks = held
	m._render()
	assert_int(_count_colour(m._image, HudConfig.TD_MINIMAP_LANDMARK_UNHELD_RING_COLOUR)).is_equal(0)
	var base := MinimapLook.new()
	assert_float(base.landmark_star_grow(false)).is_equal(1.0)
	assert_float(base.unheld_landmark_ring_colour().a).is_equal(0.0)


# Pixels within one 8-bit step (about 0.01) of `col` on every channel.
func _count_colour(img: Image, col: Color) -> int:
	var n := 0
	for py: int in range(img.get_height()):
		for px: int in range(img.get_width()):
			var p := img.get_pixel(px, py)
			if absf(p.r - col.r) < 0.01 and absf(p.g - col.g) < 0.01 and absf(p.b - col.b) < 0.01 and p.a > 0.5:
				n += 1
	return n


# --- In the level ----------------------------------------------------------------------------------------------------


# A pointer shows for each landmark that is unheld and off screen, and never for a held one or one on screen.
func test_a_pointer_is_shown_for_each_unheld_landmark_that_is_off_screen() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	# Hold the bandstand by hand and refresh the pointers at once (the level resets a hold it does not see each frame).
	td.landmarks.items[Landmarks.BANDSTAND].update(LandmarkConfig.BORDER_LANDMARK_HOLD, true)
	td.landmark_pointers.update_from(td)
	var screen := td.get_viewport().get_visible_rect().size
	assert_bool(td.landmarks.is_held(Landmarks.BANDSTAND)).is_true()
	assert_bool(td.landmark_pointers.pointer_for("Bandstand").is_empty()).is_true()
	for k: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
		if k == Landmarks.BANDSTAND:
			continue
		var label_name: String = LandmarkConfig.LANDMARK_NAMES[k]
		var at := td.world_to_screen(LandmarkConfig.LANDMARK_POSITIONS[k])
		var expected := not LandmarkPointers.on_screen(at, screen)
		(
			assert_bool(not td.landmark_pointers.pointer_for(label_name).is_empty())
			. override_failure_message("pointer for %s should be %s" % [label_name, expected])
			. is_equal(expected)
		)
	await TopDownTestUtil.leave_loaded_scene(td)


# Every shown pointer reads "Name: boost" and clears the HUD panels of the level.
func test_each_shown_pointer_names_its_landmark_and_boost_and_clears_the_hud() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	await runner.simulate_frames(2)
	var rects: Array[Rect2] = td.landmark_pointers._avoid_rects(td)
	for k: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
		if td.landmarks.is_held(k):
			continue
		var s: Dictionary = td.landmark_pointers.pointer_for(LandmarkConfig.LANDMARK_NAMES[k])
		if s.is_empty():
			continue
		assert_str(s["text"]).is_equal(
			"%s: %s" % [LandmarkConfig.LANDMARK_NAMES[k], LandmarkConfig.LANDMARK_BOOST_TEXT[k]]
		)
		var box: Rect2 = s["box"]
		(
			assert_bool(_clear_of(box, rects))
			. override_failure_message("%s overlaps the HUD" % LandmarkConfig.LANDMARK_NAMES[k])
			. is_true()
		)
	await TopDownTestUtil.leave_loaded_scene(td)
