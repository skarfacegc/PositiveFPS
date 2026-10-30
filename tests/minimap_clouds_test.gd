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


# --- Binning ---------------------------------------------------------------------------------------------------------


func test_the_clouds_bin_unrescued_people_and_skip_sparse_cells_and_rescued_people() -> void:
	var m := _map()
	var people: Array[Person] = []
	people.append_array(_crowd(Vector2(-40, -40), 4))
	people.append(_person(Vector2(-40, -40), true))  # rescued: not counted
	people.append_array(_crowd(Vector2(30, 30), 2))  # below the minimum: no cloud
	m.refresh_clouds(people)
	assert_int(m.cloud_cells.size()).is_equal(1)
	assert_int(m.cloud_cells[0]["count"]).is_equal(4)
	var centre: Vector2 = m.cloud_cells[0]["centre"]
	assert_vector(centre).is_equal(Vector2(-40, -40))


func test_a_bigger_crowd_makes_a_wider_and_stronger_cloud() -> void:
	var m := _map()
	var people: Array[Person] = []
	people.append_array(_crowd(Vector2(-40, -40), 3))
	people.append_array(_crowd(Vector2(40, 40), 12))
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
	assert_float(a_big).is_greater(a_small)


func test_the_cloud_is_soft_strongest_at_its_centre_and_gone_beyond_its_edge() -> void:
	var m := _map()
	var people: Array[Person] = _crowd(Vector2(-40, -40), 12)
	m.refresh_clouds(people)
	var cell: Dictionary = m.cloud_cells[0]
	var radius: float = cell["radius"]
	var at: Vector2 = cell["centre"]
	var c := m._to_px(at)
	var centre_alpha := m.cloud_alpha_at(int(c.x), int(c.y))
	var half_alpha := m.cloud_alpha_at(int(c.x + radius * 0.5), int(c.y))
	var edge_alpha := m.cloud_alpha_at(int(c.x + radius * 0.95), int(c.y))
	assert_float(centre_alpha).is_greater(half_alpha)
	assert_float(half_alpha).is_greater(edge_alpha)
	assert_float(centre_alpha).is_less_equal(Config.MINIMAP_CLOUD_MAX_ALPHA + 0.0001)
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
	assert_float(Config.MINIMAP_CLOUD_SECONDS).is_equal(0.5)


func test_the_picture_shows_the_cloud_on_the_ground_under_the_markers() -> void:
	var m := _map()
	add_child(m)
	m.look = MinimapLookPlaceholder.new()
	# A cell inside the round picture (the corners of the square plaza are clipped off the circle).
	var people: Array[Person] = _crowd(Vector2(-20, -20), 12)
	m.refresh_clouds(people)
	m._render()
	var at: Vector2 = m.cloud_cells[0]["centre"]
	var c := m._to_px(at)
	var grey := Config.TD_MINIMAP_GREY_COLOUR
	var on_cloud := m._image.get_pixel(int(c.x), int(c.y))
	assert_bool(on_cloud.is_equal_approx(grey)).is_false()
	# The picture is 8-bit, so the ground grey comes back within one level (1/255) of its constant.
	var far := m._image.get_pixel(100, 64)
	assert_float(absf(far.r - grey.r)).is_less(0.005)
	assert_float(absf(far.g - grey.g)).is_less(0.005)
	assert_float(absf(far.b - grey.b)).is_less(0.005)


# --- Performance ----------------------------------------------------------------------------------------------------


# Sixty people, three in each of twenty cells: the most blobs the rules allow at once. The recount (binning and
# painting the alpha map) runs twice a second, so it must stay cheap. Best of three batches of 40 recounts.
func test_perf_the_cloud_recount_with_sixty_people_is_cheap() -> void:
	var m := _map()
	var people: Array[Person] = []
	for cell: int in range(20):
		var ix := cell % 5
		var iz := floori(float(cell) / 5.0)
		var at := Vector2(-40 + ix * 20, -40 + iz * 20)
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
	if OS.get_environment("POSITIVEFPS_PERF_ENFORCE") == "1":
		assert_float(per_recount_ms).is_less(3.0)
