extends GdUnitTestSuite

# Readability (round 10), in the real level: the orthographic camera, the minimap (its data model and its circle), the
# off-screen gap arrows, the gap pulse, the player marker and the people's size. Pure rules are called directly.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self, true)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	return {"runner": runner, "td": td}


# Rescues `count` people on a ring of radius `r` around `c` (a joy hit that is always enough).
func _rescue_ring(td: TopDownMain, c: Vector3, r: float, count: int) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, c + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


func _refresh(td: TopDownMain) -> void:
	td.minimap.refresh_from(
		td.ground, td.border, td.people, td.player.global_position, td._view_centre(), td.view_half_extents()
	)


func test_the_camera_is_orthographic_at_the_configured_size_and_pitch() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	assert_int(td.camera.projection).is_equal(Camera3D.PROJECTION_ORTHOGONAL)
	assert_float(td.camera.size).is_equal_approx(Config.TD_CAMERA_ORTHO_SIZE, 0.001)
	# The camera looks down at the pitch angle.
	var forward := -td.camera.global_transform.basis.z
	assert_float(forward.y).is_equal_approx(-sin(deg_to_rad(Config.TD_CAMERA_PITCH_DEG)), 0.001)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_is_a_circle_top_left_about_a_fifth_of_the_screen() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var mm := td.minimap
	assert_bool(mm.is_circular()).is_true()
	assert_float(mm.size.x).is_equal(floorf(0.2 * 1280.0))
	assert_float(mm.size.y).is_equal(mm.size.x)
	assert_vector(mm.position).is_equal(Vector2(16, 16))
	# The corners of the picture are outside the circle, so they are transparent.
	assert_float(mm._image.get_pixel(0, 0).a).is_equal(0.0)
	# The minimap never takes clicks (they aim and lock on).
	assert_int(mm.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_model_shows_the_border_gaps_members_landmark_and_player() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	# Four rescued people: too few for the loop, so it has gaps.
	_rescue_ring(td, Vector3(0, 0, 0), 4.0, 4)
	await (s["runner"] as GdUnitSceneRunner).simulate_frames(120)
	_refresh(td)
	var mm := td.minimap
	assert_int(mm.border_pts.size()).is_equal(td.border.polygon.size())
	assert_bool(mm.gap_flags.has(true)).is_true()
	assert_int(mm.member_pts.size()).is_equal(td.border.member_count)
	assert_vector(mm.landmark_pos).is_equal(Vector2(Config.BORDER_LANDMARK_POS.x, Config.BORDER_LANDMARK_POS.z))
	assert_vector(mm.player_pos).is_equal(Vector2(td.player.global_position.x, td.player.global_position.z))
	assert_int(mm.view_pts.size()).is_equal(4)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_marks_dark_people_and_refreshes_about_ten_times_a_second() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	TopDownTestUtil.send_everyone_away(td)
	TopDownTestUtil.place(td.people[0], Vector3(-10, 0, 10), 0, 1.0)
	_refresh(td)
	assert_int(td.minimap.dark_pts.size()).is_equal(1)
	# A dark person in the plaza corner is on the map's data but outside its circle, so no pixel is drawn there.
	TopDownTestUtil.place(td.people[1], TopDownTestUtil.FAR, 0, 1.0)
	_refresh(td)
	assert_int(td.minimap.dark_pts.size()).is_equal(2)
	var corner := td.minimap._to_px(Vector2(TopDownTestUtil.FAR.x, TopDownTestUtil.FAR.z))
	assert_float(td.minimap._image.get_pixel(int(corner.x), int(corner.y)).a).is_equal(0.0)
	# The tick is due once a refresh interval has passed, and not before.
	td.minimap._timer = 0.0
	assert_bool(td.minimap.tick(0.05)).is_false()
	assert_bool(td.minimap.tick(Config.TD_MINIMAP_REFRESH_SECONDS)).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_off_screen_gap_arrows_appear_for_an_off_screen_gap_only() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var mm_rect := td.minimap.get_global_rect()
	var on_screen := td.player.global_position
	var off_screen := Vector3(0, 0, -40)
	var gaps: Array[Vector3] = [Vector3(on_screen.x, 0.0, on_screen.z), off_screen]
	var arrows := GapArrows.off_screen_arrows(td.camera, screen, gaps, mm_rect)
	assert_int(arrows.size()).is_equal(1)
	var pos: Vector2 = arrows[0]["pos"]
	# The badge sits on the inset screen edge, and clear of the minimap circle.
	assert_float(pos.x).is_greater_equal(Config.OFFSCREEN_ARROW_MARGIN - 0.5)
	assert_float(pos.y).is_greater_equal(Config.OFFSCREEN_ARROW_MARGIN - 0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_an_arrow_for_a_gap_toward_the_minimap_is_kept_clear_of_it() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	var mm_rect := td.minimap.get_global_rect()
	# Far up and to the left: the line to it leaves the screen where the minimap sits.
	var gaps: Array[Vector3] = [Vector3(-60, 0, -60)]
	var arrows := GapArrows.off_screen_arrows(td.camera, screen, gaps, mm_rect)
	assert_int(arrows.size()).is_equal(1)
	var pos: Vector2 = arrows[0]["pos"]
	var mm_c := mm_rect.get_center()
	assert_float(pos.distance_to(mm_c)).is_greater_equal(mm_rect.size.x * 0.5 + Config.OFFSCREEN_ARROW_PAD - 0.5)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_gap_pulse_follows_its_formula_over_time() -> void:
	assert_float(Border.gap_pulse(0.0)).is_equal_approx(0.0, 0.0001)
	assert_float(Border.gap_pulse(Config.BORDER_GAP_PULSE_SECONDS * 0.5)).is_equal_approx(1.0, 0.0001)
	assert_float(Border.gap_pulse(Config.BORDER_GAP_PULSE_SECONDS)).is_equal_approx(0.0, 0.0001)
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	for i: int in range(5):
		border.update([], 0.1, 1.0)
	var expected := 0.5 - 0.5 * cos(TAU * border._time / Config.BORDER_GAP_PULSE_SECONDS)
	assert_float(border.pulse()).is_equal_approx(expected, 0.0001)


func test_a_gap_glows_coral_and_intact_stretches_stay_gold() -> void:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	border.polygon = Border.circle_polygon(Vector2.ZERO, 3.0, Config.BORDER_SAMPLES)
	border.active = true
	var ring: Array[Person] = []
	for i: int in range(4):
		var a := TAU * float(i) / 4.0
		var p: Person = auto_free(Person.new())
		add_child(p)
		p.position = Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0)
		p.is_rescued = true
		ring.append(p)
	border._assign_members(ring)
	assert_bool(border.segment_is_gap(0)).is_true()
	assert_float(border.segment_colour(0).r).is_equal_approx(Config.BORDER_GAP_COLOUR.r, 0.001)
	assert_int(border.gap_midpoints().size()).is_equal(border.gap_count())
	# A segment that is not a gap keeps the gold line colour.
	assert_float(border.segment_colour(0).g).is_not_equal(Config.BORDER_INTACT_COLOUR.g)


func test_the_player_marker_is_saffron_and_no_person_shares_its_colour() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var col := (td.player.look as PlayerLookPlaceholder).body_mat.albedo_color
	assert_float(col.r).is_equal_approx(Config.TD_PLAYER_COLOUR.r, 0.001)
	for c: Color in Config.ELEMENT_COLORS:
		assert_bool(col.is_equal_approx(c)).is_false()
	for c: Color in Config.LEVEL_COLORS:
		assert_bool(col.is_equal_approx(c)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_people_are_drawn_one_and_a_half_times_bigger_and_collide_the_same() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	assert_float(p.look.visual.scale.x).is_equal_approx(1.5, 0.0001)
	var shape: CapsuleShape3D = null
	for child: Node in p.get_children():
		if child is CollisionShape3D:
			shape = (child as CollisionShape3D).shape as CapsuleShape3D
	assert_float(shape.radius).is_equal_approx(0.4, 0.0001)
	await TopDownTestUtil.leave_loaded_scene(td)
