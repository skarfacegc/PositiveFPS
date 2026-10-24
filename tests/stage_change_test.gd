extends GdUnitTestSuite

# Round 12b: noticeable gloom-stage changes. Sinking a stage (wistful to gloomy to dimmed) gives a grey-violet puff and
# ripple, lifting gives a warm one, and the minimap shows a brief blip where someone became dimmed.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self, true)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


# The colours of the puffs (particle bursts) among the person look's children.
func _puff_colours(p: Person) -> Array[Color]:
	var out: Array[Color] = []
	for child: Node in p.look.get_children():
		if child is CPUParticles3D:
			var mesh := (child as CPUParticles3D).mesh as SphereMesh
			var mat := mesh.material as StandardMaterial3D
			out.append(mat.albedo_color)
	return out


# True when two colours match to within 8-bit rounding.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _ripples(p: Person) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in p.look.get_children():
		if child.is_in_group("stage_ripple"):
			out.append(child)
	return out


func test_sinking_a_stage_gives_a_grey_violet_puff_and_ripple() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 0, 0.2)
	await runner.simulate_frames(5)
	var sank: Array[int] = []
	p.stage_changed.connect(func(from_level: int, to_level: int) -> void: sank.append(to_level - from_level))
	var before := _puff_colours(p).size()
	p.gloom = 0.45  # wistful -> gloomy
	await runner.simulate_frames(2)
	assert_array(sank).is_equal([1])
	var colours := _puff_colours(p)
	assert_int(colours.size()).is_greater(before)
	assert_bool(colours.has(Config.STAGE_SINK_COLOUR)).is_true()
	assert_int(_ripples(p).size()).is_equal(1)
	# Not icy: more red than blue is not needed, but it must not be a cold blue-white.
	assert_float(Config.STAGE_SINK_COLOUR.b - Config.STAGE_SINK_COLOUR.r).is_less(0.25)
	# Gloomy to dimmed: another one.
	p.gloom = 0.8
	await runner.simulate_frames(2)
	assert_array(sank).is_equal([1, 1])
	assert_int(_ripples(p).size()).is_greater(1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_lifting_a_stage_gives_a_warm_puff_and_ripple() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 0, 0.5)
	await runner.simulate_frames(5)
	var lifted: Array[int] = []
	p.stage_changed.connect(func(from_level: int, to_level: int) -> void: lifted.append(to_level - from_level))
	var ripples_before := _ripples(p).size()
	p.gloom = 0.2  # gloomy -> wistful
	await runner.simulate_frames(2)
	assert_array(lifted).is_equal([-1])
	var colours := _puff_colours(p)
	assert_bool(colours.has(Config.STAGE_LIFT_COLOUR)).is_true()
	assert_float(Config.STAGE_LIFT_COLOUR.r).is_greater(Config.STAGE_LIFT_COLOUR.b)  # warm
	assert_int(_ripples(p).size()).is_equal(ripples_before + 1)
	# The ripples spread out and are gone a moment later.
	await runner.simulate_frames(int(Config.STAGE_RIPPLE_SECONDS * 60.0) + 20)
	assert_int(_ripples(p).size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_no_stage_change_means_no_puff() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(0, 0, -8), 0, 0.2)
	await runner.simulate_frames(5)
	p.gloom = 0.25  # still wistful
	await runner.simulate_frames(5)
	assert_int(_ripples(p).size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_minimap_shows_a_blip_where_someone_became_dimmed_and_it_fades() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p: Person = td.people[0]
	TopDownTestUtil.place(p, Vector3(5, 0, -8), 0, 0.5)
	await runner.simulate_frames(5)
	assert_int(td.minimap.blips.size()).is_equal(0)
	# Gloomy to dimmed: a blip. (Gloomy from wistful is not one.)
	p.gloom = 0.8
	await runner.simulate_frames(3)
	assert_int(td.minimap.blips.size()).is_equal(1)
	var at: Vector2 = td.minimap.blips[0]["pos"]
	assert_float(at.distance_to(Vector2(p.position.x, p.position.z))).is_less(0.5)
	# It is drawn: pixels of the blip colour exist on the picture after a redraw.
	await runner.simulate_frames(12)
	var found := false
	for py: int in range(Minimap.RESOLUTION):
		for px: int in range(Minimap.RESOLUTION):
			if _close(td.minimap._image.get_pixel(px, py), Config.MINIMAP_BLIP_COLOUR):
				found = true
	assert_bool(found).is_true()
	await runner.simulate_frames(int(Config.MINIMAP_BLIP_SECONDS * 60.0) + 10)
	assert_int(td.minimap.blips.size()).is_equal(0)
	# Sinking to gloomy, or lifting out of dimmed, makes no blip.
	var q: Person = td.people[1]
	TopDownTestUtil.place(q, Vector3(-5, 0, -8), 1, 0.2)
	await runner.simulate_frames(3)
	q.gloom = 0.45
	await runner.simulate_frames(3)
	assert_int(td.minimap.blips.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)
