extends GdUnitTestSuite

# Round 17, the guarded wedge: a flat wedge on the ground shows the open side of a guarded person (the arc where joy
# lands, GUARDED_ARC_DEG either side of their facing). It follows the facing, shows only while they are guarded,
# brightens while a shot from the player would land, and the turn that moves the facing is slower (GUARDED_TURN_SPEED).
# The rule is Person.is_open_to (the same function receive_joy uses), so the tests check the wedge against it.


# The level with everyone parked away and the player standing at the origin.
func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	return {"runner": runner, "td": td}


# A person with a mood, placed at `spot`.
func _mooded(td: TopDownMain, index: int, spot: Vector3, mood: int) -> Person:
	var p: Person = td.people[index]
	TopDownTestUtil.place(p, spot, 0, 0.2)
	p.mood = mood
	return p


# The wedge's vertices in world space (the look is a child of the person, so this follows the facing).
func _wedge_world_points(p: Person) -> PackedVector3Array:
	var mesh: ArrayMesh = p.look.guard_wedge.mesh
	var verts: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var out := PackedVector3Array()
	for v: Vector3 in verts:
		out.append(p.look.guard_wedge.global_transform * v)
	return out


# The angle, in degrees from the person's facing, of a world point (positive toward the person's right).
func _angle_from_facing(p: Person, world: Vector3) -> float:
	var local := p.global_transform.basis.inverse() * (world - p.global_position)
	return rad_to_deg(atan2(local.x, -local.z))


# --- Shown only while guarded ------------------------------------------------------------------------------------


func test_the_wedge_shows_on_a_guarded_person_and_hides_when_they_stop_being_guarded() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	await runner.simulate_frames(1)
	assert_bool(p.look.guard_wedge.visible).is_true()
	# Not guarded: a skittish person has no wedge.
	p.mood = Person.Mood.SKITTISH
	await runner.simulate_frames(1)
	assert_bool(p.look.guard_wedge.visible).is_false()
	# Rescued: the wedge goes.
	p.mood = Person.Mood.GUARDED
	await runner.simulate_frames(1)
	assert_bool(p.look.guard_wedge.visible).is_true()
	p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(1)
	assert_bool(p.is_rescued).is_true()
	assert_bool(p.look.guard_wedge.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The span and the rule --------------------------------------------------------------------------------------


func test_the_wedge_spans_exactly_guarded_arc_deg_either_side_of_the_facing() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	p.rotation.y = 0.7
	var lo := 1000.0
	var hi := -1000.0
	var far := 0.0
	for w: Vector3 in _wedge_world_points(p):
		if w.distance_to(p.look.guard_wedge.global_position) < 0.01:
			continue  # The centre of the fan.
		var a := _angle_from_facing(p, w)
		lo = minf(lo, a)
		hi = maxf(hi, a)
		far = maxf(far, Vector2(w.x - p.global_position.x, w.z - p.global_position.z).length())
	assert_float(lo).is_equal_approx(-Config.GUARDED_ARC_DEG, 0.01)
	assert_float(hi).is_equal_approx(Config.GUARDED_ARC_DEG, 0.01)
	assert_float(far).is_equal_approx(Config.GUARDED_WEDGE_RADIUS, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wedge_edges_are_exactly_the_edges_of_the_open_arc() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	p.rotation.y = -1.9
	for deg: float in [-109.0, -60.0, 0.0, 60.0, 109.0]:
		var a := deg_to_rad(deg)
		var dir := p.global_transform.basis * Vector3(sin(a), 0.0, -cos(a))
		var spot := p.global_position + dir * 4.0
		assert_bool(p.is_open_to(spot)).is_true()
	for deg: float in [-111.0, 111.0, 150.0, 180.0]:
		var a := deg_to_rad(deg)
		var dir := p.global_transform.basis * Vector3(sin(a), 0.0, -cos(a))
		var spot := p.global_position + dir * 4.0
		assert_bool(p.is_open_to(spot)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_wedge_follows_the_facing_as_the_person_turns() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(3, 0, -5), Person.Mood.GUARDED)
	for yaw: float in [0.0, 1.3, -2.4, 3.0]:
		p.rotation.y = yaw  # Set directly: the wedge is a child of the person, so it has turned at once.
		var facing := p.facing_dir()
		var edge_lo := 1000.0
		var edge_hi := -1000.0
		var mid := Vector3.ZERO
		for w: Vector3 in _wedge_world_points(p):
			if w.distance_to(p.look.guard_wedge.global_position) < 0.01:
				continue
			var a := _angle_from_facing(p, w)
			edge_lo = minf(edge_lo, a)
			edge_hi = maxf(edge_hi, a)
			mid += w - p.global_position
		assert_float(edge_lo).is_equal_approx(-Config.GUARDED_ARC_DEG, 0.01)
		assert_float(edge_hi).is_equal_approx(Config.GUARDED_ARC_DEG, 0.01)
		# The fan's middle lies along the person's facing.
		var mid_dir := Vector3(mid.x, 0.0, mid.z).normalized()
		assert_float(mid_dir.dot(facing)).is_greater(0.99)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The open-side highlight ------------------------------------------------------------------------------------


func test_the_open_side_is_brighter_exactly_when_a_shot_from_the_player_would_land() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	p.rotation.y = 0.0  # Facing north (-Z), away from the player at the origin.
	# (angle from the facing in degrees, expected open): in front, the open side, the edge, just past it, and behind.
	var cases := [[0.0, true], [60.0, true], [-100.0, true], [115.0, false], [180.0, false]]
	for c: Array in cases:
		var deg: float = c[0]
		var a := deg_to_rad(deg)
		var dir := p.global_transform.basis * Vector3(sin(a), 0.0, -cos(a))
		td.player.global_position = p.global_position + dir * 5.0
		await runner.simulate_frames(1)
		var expected: bool = c[1]
		# The rule the game uses (receive_joy calls is_open_to with the shooter's position).
		assert_bool(p.is_open_to(td.player.global_position)).is_equal(expected)
		assert_bool(p.shot_lands_now()).is_equal(expected)
		assert_bool(p.look.wedge_open).is_equal(expected)
		var colour: Color = p.look.wedge_mat.albedo_color
		assert_bool(colour.is_equal_approx(Config.GUARDED_WEDGE_OPEN_COLOUR)).is_equal(expected)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The turn ---------------------------------------------------------------------------------------------------


func test_a_guarded_person_turns_at_the_round_17_speed() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var p := _mooded(td, 0, Vector3(0, 0, -6), Person.Mood.GUARDED)
	# Facing 1 rad off the away direction (north): one frame of turning is limited by GUARDED_TURN_SPEED.
	p.rotation.y = 1.0
	await runner.simulate_frames(1)
	var step := absf(p.rotation.y - 1.0)
	assert_float(Config.GUARDED_TURN_SPEED).is_equal(0.45)
	assert_float(step).is_equal_approx(Config.GUARDED_TURN_SPEED / 60.0, 0.0005)
	await TopDownTestUtil.leave_loaded_scene(td)
