extends GdUnitTestSuite

# Round 20: minimap clouds. Unrescued people are binned into a coarse grid and each busy cell gets one soft blob, sized
# and shaded by its count, recounted twice a second. Tests read the model (cloud_cells, cloud_alpha_at) where they can.


func _person(at: Vector2, rescued: bool = false) -> Person:
	var p: Person = auto_free(Person.new())
	p.position = Vector3(at.x, 0.0, at.y)
	p.is_rescued = rescued
	return p


# `count` people spread a little round `at`, all unrescued.
func _crowd(at: Vector2, count: int) -> Array[Person]:
	var out: Array[Person] = []
	for k: int in range(count):
		var a := TAU * float(k) / float(maxi(count, 1))
		out.append(_person(at + Vector2(cos(a), sin(a)) * 2.0))
	return out


func _map() -> Minimap:
	return auto_free(Minimap.new())


# The index of the grid cell that holds world point `at` (the same binning as Minimap.refresh_clouds).
func _cell(at: Vector2) -> int:
	var n := HudConfig.MINIMAP_CLOUD_CELLS
	var cell_m := float(Config.TD_PLAZA_SIZE) / float(n)
	var half := Config.TD_PLAZA_SIZE * 0.5
	var ix := clampi(floori((at.x + half) / cell_m), 0, n - 1)
	var iz := clampi(floori((at.y + half) / cell_m), 0, n - 1)
	return iz * n + ix


# --- The cached ground layer --------------------------------------------------------------------------------------


func test_the_ground_layer_is_rebuilt_only_when_it_may_have_changed() -> void:
	var m := _map()
	m._ready()
	m._render()
	assert_bool(m._base_is_current()).is_true()
	m.tick(0.2)
	assert_bool(m._base_is_current()).is_true()
	m.first_light_edge = 12.0  # the dawn front moved
	assert_bool(m._base_is_current()).is_false()
	m._render()
	assert_bool(m._base_is_current()).is_true()
	m.tick(HudConfig.MINIMAP_GROUND_SECONDS + 0.01)  # the painted ground may have changed
	assert_bool(m._base_is_current()).is_false()
	m._render()
	assert_bool(m._base_is_current()).is_true()
	m.cloud_alpha_at(0, 0)  # a cloud repaint is only counted when something changed
	assert_bool(m._base_is_current()).is_true()
	m.refresh_clouds(_crowd(Vector2(-23, -23), 4))
	m.cloud_alpha_at(0, 0)
	assert_bool(m._base_is_current()).is_false()


# --- Binning ---------------------------------------------------------------------------------------------------------


func test_the_clouds_bin_unrescued_people_and_skip_sparse_cells_and_rescued_people() -> void:
	var m := _map()
	var people: Array[Person] = []
	people.append_array(_crowd(Vector2(-23, -23), 4))
	people.append(_person(Vector2(-23, -23), true))  # rescued: not counted
	people.append_array(_crowd(Vector2(23, 23), 1))  # below the minimum (2): no cloud
	m.refresh_clouds(people)
	assert_int(m.cloud_cells.size()).is_equal(1)
	assert_int(m.cloud_cells[0]["count"]).is_equal(4)
	# Round 21: the blob sits at the mean of its people (the four people of the crowd average to its middle).
	var centre: Vector2 = m.cloud_cells[0]["centre"]
	assert_vector(centre).is_equal_approx(Vector2(-23, -23), Vector2(0.001, 0.001))


func test_a_bigger_crowd_makes_a_wider_and_stronger_cloud() -> void:
	var m := _map()
	var people: Array[Person] = []
	people.append_array(_crowd(Vector2(-23, -23), 3))
	people.append_array(_crowd(Vector2(23, 23), 12))
	m.refresh_clouds(people)
	assert_int(m.cloud_cells.size()).is_equal(2)
	var small: Dictionary = m.cloud_cells[0]
	var big: Dictionary = m.cloud_cells[1]
	var small_r: float = small["radius"]
	var big_r: float = big["radius"]
	assert_float(big_r).is_greater(small_r)
	var small_at: Vector2 = small["centre"]
	var big_at: Vector2 = big["centre"]
	var small_px := m._to_px(small_at)
	var big_px := m._to_px(big_at)
	var a_small := m.cloud_alpha_at(int(small_px.x), int(small_px.y))
	var a_big := m.cloud_alpha_at(int(big_px.x), int(big_px.y))
	assert_float(a_small).is_greater(0.0)
	# Round 21: a dense cell is stronger than a sparse one, and reaches the higher peak (12 of 12 people).
	assert_float(a_big).is_greater(a_small)
	assert_float(absf(a_big - HudConfig.MINIMAP_CLOUD_MAX_ALPHA)).is_less(0.01)


func test_the_cloud_is_soft_strongest_at_its_centre_and_gone_beyond_its_edge() -> void:
	var m := _map()
	var people: Array[Person] = _crowd(Vector2(-23, -23), 12)
	m.refresh_clouds(people)
	var cell: Dictionary = m.cloud_cells[0]
	var radius: float = cell["radius"]
	var at: Vector2 = cell["centre"]
	var c := m._to_px(at)
	var centre_alpha := m.cloud_alpha_at(int(c.x), int(c.y))
	# Round 22: the core is solid out to MINIMAP_CLOUD_CORE of the radius, so the middle of the blob equals its centre;
	# the soft shoulder starts past the core.
	var half_alpha := m.cloud_alpha_at(int(c.x + radius * 0.5), int(c.y))
	var shoulder_alpha := m.cloud_alpha_at(int(c.x + radius * 0.8), int(c.y))
	var edge_alpha := m.cloud_alpha_at(int(c.x + radius * 0.95), int(c.y))
	assert_float(absf(half_alpha - centre_alpha)).is_less(0.001)
	assert_float(centre_alpha).is_greater(shoulder_alpha)
	assert_float(shoulder_alpha).is_greater(edge_alpha)
	assert_float(centre_alpha).is_less_equal(HudConfig.MINIMAP_CLOUD_MAX_ALPHA + 0.0001)
	assert_float(m.cloud_alpha_at(int(c.x + radius + 4.0), int(c.y))).is_equal(0.0)
	assert_float(m.cloud_alpha_at(127, 127)).is_equal(0.0)


# --- The rate ---------------------------------------------------------------------------------------------------------


func test_the_clouds_are_recounted_about_twice_a_second_not_every_refresh() -> void:
	var m := _map()
	assert_bool(m.clouds_due()).is_true()
	m.refresh_clouds([] as Array[Person])
	assert_bool(m.clouds_due()).is_false()
	m.tick(0.3)
	assert_bool(m.clouds_due()).is_false()
	m.tick(0.25)
	assert_bool(m.clouds_due()).is_true()
	assert_float(HudConfig.MINIMAP_CLOUD_SECONDS).is_equal(0.5)


func test_the_picture_shows_the_cloud_on_the_ground_under_the_markers() -> void:
	var m := _map()
	add_child(m)
	m.look = MinimapLookPlaceholder.new()
	# A cell inside the round picture (the corners of the square plaza are clipped off the circle).
	var people: Array[Person] = _crowd(Vector2(-23, -23), 12)
	m.refresh_clouds(people)
	m._render()
	var at: Vector2 = m.cloud_cells[0]["centre"]
	var c := m._to_px(at)
	var grey := HudConfig.TD_MINIMAP_GREY_COLOUR
	var on_cloud := m._image.get_pixel(int(c.x), int(c.y))
	assert_bool(on_cloud.is_equal_approx(grey)).is_false()
	# The picture is 8-bit, so the ground grey comes back within one level (1/255) of its constant.
	var far := m._image.get_pixel(100, 64)
	assert_float(absf(far.r - grey.r)).is_less(0.005)
	assert_float(absf(far.g - grey.g)).is_less(0.005)
	assert_float(absf(far.b - grey.b)).is_less(0.005)


# --- Round 21: readability -------------------------------------------------------------------------------------------


# A crowd in a corner of the square is outside the map circle. Its blob is pulled in to the rim in that direction, so
# the crowd still shows, inside the circle.
func test_a_crowd_in_a_map_corner_is_drawn_at_the_rim_inside_the_circle() -> void:
	var m := _map()
	m.refresh_clouds(_crowd(Vector2(-42, -42), 4))
	assert_int(m.cloud_cells.size()).is_equal(1)
	var at: Vector2 = m.cloud_cells[0]["centre"]
	var rim := Config.TD_PLAZA_SIZE * 0.5 * HudConfig.MINIMAP_CLOUD_RIM
	assert_float(absf(at.length() - rim)).is_less(0.01)
	assert_bool(at.x < 0.0 and at.y < 0.0).is_true()
	assert_bool(m._in_circle(m._to_px(at))).is_true()


# Between recounts a blob glides from where it was to where its crowd now is, over several frames, instead of jumping.
func test_between_recounts_a_cloud_glides_to_its_new_place() -> void:
	var m := _map()
	m.refresh_clouds(_crowd(Vector2(-24, -23), 3))  # the first recount snaps into place
	var cell := _cell(Vector2(-24, -23))
	var before: Vector2 = m._cloud_shown[cell]["pos"]
	m.refresh_clouds(_crowd(Vector2(-22, -23), 3))  # same cell, a little further in
	var target: Vector2 = m.cloud_cells[0]["centre"]
	m.tick(0.1)
	var mid: Vector2 = m._cloud_shown[cell]["pos"]
	assert_float(mid.distance_to(before)).is_greater(0.0)
	assert_float(mid.distance_to(target)).is_less(before.distance_to(target))
	m.tick(4.0)
	var settled: Vector2 = m._cloud_shown[cell]["pos"]
	assert_float(settled.distance_to(target)).is_less(0.01)


# A crowd that thins out or leaves fades away over a moment, and a new crowd fades in, rather than popping.
func test_a_cloud_fades_in_and_out_rather_than_popping() -> void:
	var m := _map()
	m.refresh_clouds(_crowd(Vector2(-23, -23), 12))
	var old_cell := _cell(Vector2(-23, -23))
	m.refresh_clouds([] as Array[Person])
	m.tick(0.1)
	assert_bool(m._cloud_shown.has(old_cell)).is_true()
	var fading: float = m._cloud_shown[old_cell]["peak"]
	assert_float(fading).is_greater(0.0)
	assert_float(fading).is_less(HudConfig.MINIMAP_CLOUD_MAX_ALPHA)
	# A new crowd elsewhere (cell 18) fades in while the old cloud is still fading out.
	m.refresh_clouds(_crowd(Vector2(23, 23), 12))
	m.tick(0.1)
	var new_cell := _cell(Vector2(23, 23))
	var growing: float = m._cloud_shown[new_cell]["peak"]
	assert_float(growing).is_greater(0.0)
	assert_float(growing).is_less(HudConfig.MINIMAP_CLOUD_MAX_ALPHA)
	m.tick(5.0)
	assert_bool(m._cloud_shown.has(old_cell)).is_false()
	var settled_peak: float = m._cloud_shown[new_cell]["peak"]
	assert_float(absf(settled_peak - HudConfig.MINIMAP_CLOUD_MAX_ALPHA)).is_less(0.001)


# The cloud has to show against the grey ground at its strongest: a rough contrast ratio (on sRGB values) of at least 2.
func test_the_cloud_at_full_strength_stands_out_from_the_grey_ground() -> void:
	var m := _map()
	add_child(m)
	m.look = MinimapLookPlaceholder.new()
	m.refresh_clouds(_crowd(Vector2(-23, -23), 12))
	m._render()
	var at: Vector2 = m.cloud_cells[0]["centre"]
	var c := m._to_px(at)
	var on_cloud := m._image.get_pixel(int(c.x), int(c.y))
	var ground := m._image.get_pixel(100, 64)
	var ratio := (_luminance(ground) + 0.05) / (_luminance(on_cloud) + 0.05)
	assert_float(ratio).is_greater_equal(2.0)


static func _luminance(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


# --- Round 22: the finer grid
# ------------------------------------------------------------------------------------------


# A pair of people is enough for a cloud now (the minimum is 2, was 3), so a small crowd split over two cells still
# shows.
func test_a_pair_of_people_makes_a_cloud() -> void:
	var m := _map()
	m.refresh_clouds(_crowd(Vector2(-23, -23), 2))
	assert_int(m.cloud_cells.size()).is_equal(1)
	assert_int(m.cloud_cells[0]["count"]).is_equal(2)


# The clouds follow the crowd's outline: people along an L shape colour the L, and its empty inside corner stays clear.
func test_the_cloud_follows_an_l_shaped_crowd_and_leaves_its_inside_corner_clear() -> void:
	var m := _map()
	var people: Array[Person] = []
	for i: int in range(11):
		people.append(_person(Vector2(-40.0 + 2.0 * float(i), -28.0)))  # along the row: x -40 to -20
	for i: int in range(8):
		people.append(_person(Vector2(-20.0, -28.0 + 2.0 * float(i))))  # up the column: z -28 to -14
	m.refresh_clouds(people)
	var on_row := m._to_px(Vector2(-30.0, -28.0))
	var inside_corner := m._to_px(Vector2(-32.0, -14.0))
	var on_row_alpha := m.cloud_alpha_at(int(on_row.x), int(on_row.y))
	var corner_alpha := m.cloud_alpha_at(int(inside_corner.x), int(inside_corner.y))
	assert_float(on_row_alpha).is_greater(0.4)
	assert_float(corner_alpha).is_less(0.05)


# --- Performance ----------------------------------------------------------------------------------------------------


# Sixty people, three in each of twenty cells: the most blobs the rules allow at once. The recount (binning and
# painting the alpha map) runs twice a second, so it must stay cheap. Best of three batches of 40 recounts.
func test_perf_the_cloud_recount_with_sixty_people_is_cheap() -> void:
	var m := _map()
	var people: Array[Person] = []
	for cell: int in range(20):
		var ix := cell % 5
		var iz := floori(float(cell) / 5.0)
		# The middle of every third bin of the 15 x 15 grid (a bin is TD_PLAZA_SIZE / 15 wide), so no crowd straddles two.
		var bin := float(Config.TD_PLAZA_SIZE) / float(HudConfig.MINIMAP_CLOUD_CELLS)
		var at := Vector2(
			-Config.TD_PLAZA_SIZE * 0.5 + bin * (1.5 + 3.0 * float(ix)),
			-Config.TD_PLAZA_SIZE * 0.5 + bin * (1.5 + 3.0 * float(iz))
		)
		people.append_array(_crowd(at, 3))
	assert_int(people.size()).is_equal(60)
	var per_recount_ms := 1.0e9
	for batch: int in range(3):
		var start := Time.get_ticks_usec()
		for i: int in range(40):
			m.refresh_clouds(people)
		per_recount_ms = minf(per_recount_ms, float(Time.get_ticks_usec() - start) / 1000.0 / 40.0)
	assert_int(m.cloud_cells.size()).is_equal(20)
	print("MINIMAP clouds recount with 60 people in 20 cells: %.3f ms" % per_recount_ms)
	# Round 20: the worst case measured about 1.9 ms per recount (plain, alone, in a scratch run). Budget = measured x 1.5,
	# rounded up to 3 ms. The recount runs twice a second, so this is well inside the frame budget.
	# Round 21: the recount now only bins the people and sets the blobs' targets (about 0.05 ms). Painting the alpha map
	# moved to the picture refresh, repainted at most every MINIMAP_CLOUD_PAINT_SECONDS (about 1.8 ms each, measured in
	# a scratch run). The budget is unchanged.
	if OS.get_environment("POSITIVEFPS_PERF_ENFORCE") == "1":
		assert_float(per_recount_ms).is_less(3.0)


# --- Edges -----------------------------------------------------------------------------------------------------------


func test_the_circle_radius_is_half_the_control_width() -> void:
	var m := _map()
	m.size = Vector2(120.0, 120.0)
	assert_bool(m.is_circular()).is_true()
	assert_float(m.radius()).is_equal(60.0)


func test_the_cloud_alpha_outside_the_picture_is_zero() -> void:
	var m := _map()
	m.refresh_clouds(_crowd(Vector2(-23, -23), 12))
	var at: Vector2 = m.cloud_cells[0]["centre"]
	var c := m._to_px(at)
	assert_float(m.cloud_alpha_at(int(c.x), int(c.y))).is_greater(0.0)
	assert_float(m.cloud_alpha_at(-1, 10)).is_equal(0.0)
	assert_float(m.cloud_alpha_at(10, -1)).is_equal(0.0)
	assert_float(m.cloud_alpha_at(Minimap.RESOLUTION, 10)).is_equal(0.0)
	assert_float(m.cloud_alpha_at(10, Minimap.RESOLUTION)).is_equal(0.0)


func test_a_blob_that_has_faded_out_paints_nothing() -> void:
	var m := _map()
	m.refresh_clouds(_crowd(Vector2(-23, -23), 12))
	var cell := _cell(Vector2(-23, -23))
	var at: Vector2 = m.cloud_cells[0]["centre"]
	var c := m._to_px(at)
	assert_float(m.cloud_alpha_at(int(c.x), int(c.y))).is_greater(0.0)
	m._cloud_shown[cell]["peak"] = 0.0
	m._paint_clouds()
	assert_float(m._cloud_alpha[int(c.y) * Minimap.RESOLUTION + int(c.x)]).is_equal(0.0)


func test_drawing_before_the_picture_exists_does_nothing() -> void:
	var m := _map()  # not in the tree, so no picture has been made yet
	assert_object(m._image).is_null()
	m._render()
	assert_object(m._image).is_null()


func test_a_pixel_off_the_picture_is_ignored_and_one_on_it_is_set() -> void:
	var m := _map()
	add_child(m)
	m.look = MinimapLookPlaceholder.new()
	var before := m._image.get_data()
	for off: Vector2i in [
		Vector2i(-1, 5), Vector2i(5, -1), Vector2i(Minimap.RESOLUTION, 5), Vector2i(5, Minimap.RESOLUTION)
	]:
		m._put(off.x, off.y, Color.RED)
	assert_bool(m._image.get_data() == before).is_true()
	var mid := Minimap.RESOLUTION / 2
	m._put(mid, mid, Color.RED)
	assert_bool(m._image.get_pixel(mid, mid).is_equal_approx(Color.RED)).is_true()
