extends GdUnitTestSuite

# 0.3.3 (#52, #17): the town is a main street and a cross street that meet at the player's start. About twenty blocks
# stand in rows along them and face them, one landmark ends each street arm, and everything can be walked to.


func _blocks() -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.assign(TopDownMain.BLOCK_POSITIONS)
	return out


func test_there_are_sixteen_to_twenty_four_blocks_inside_the_walls_that_do_not_overlap() -> void:
	var blocks := _blocks()
	assert_int(blocks.size()).is_between(16, 24)
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	var size := TopDownMain.BLOCK_SIZE
	for i: int in range(blocks.size()):
		assert_float(absf(blocks[i].x) + size.x * 0.5).is_less(half - 2.0)
		assert_float(absf(blocks[i].z) + size.z * 0.5).is_less(half - 2.0)
		for j: int in range(i + 1, blocks.size()):
			var dx := absf(blocks[i].x - blocks[j].x)
			var dz := absf(blocks[i].z - blocks[j].z)
			# At least a 2 m lane between two blocks, on one axis or the other.
			assert_bool(dx >= size.x + 2.0 or dz >= size.z + 2.0).is_true()


func test_blocks_stand_in_rows_beside_the_streets_and_face_them() -> void:
	for c: Vector3 in _blocks():
		var f := TownLayout.facing(c)
		assert_float(f.length()).is_equal_approx(1.0, 0.001)
		# The block's face toward the street is clear of the street: the pavement strip lies between them.
		var face := Vector3(c.x, 0.0, c.z) + f * TopDownMain.BLOCK_SIZE.x * 0.5
		assert_bool(TownLayout.on_street(face, 0.0)).is_false()
		assert_bool(TownLayout.on_street(face, 2.0)).is_true()
		# The block itself stands off the streets.
		assert_bool(TownLayout.on_street(Vector3(c.x, 0.0, c.z))).is_false()


func test_the_start_and_the_first_border_ring_sit_on_the_crossing() -> void:
	assert_bool(TownLayout.on_street(Vector3.ZERO)).is_true()
	assert_bool(TownLayout.on_square(Vector3.ZERO)).is_true()
	# The smallest border ring (BORDER_MIN_RADIUS) fits the crossing without touching a block.
	var ring := RoundLoopConfig.BORDER_MIN_RADIUS
	for c: Vector3 in _blocks():
		var nearest := Vector2(maxf(absf(c.x) - 2.0, 0.0), maxf(absf(c.z) - 2.0, 0.0)).length()
		assert_float(nearest).is_greater(ring + 2.0)


func test_the_facing_turns_each_side_of_each_street_toward_it() -> void:
	assert_vector(TownLayout.facing(Vector3(14, 1, -8))).is_equal(Vector3(0, 0, 1))
	assert_vector(TownLayout.facing(Vector3(14, 1, 8))).is_equal(Vector3(0, 0, -1))
	assert_vector(TownLayout.facing(Vector3(8, 1, 15))).is_equal(Vector3(-1, 0, 0))
	assert_vector(TownLayout.facing(Vector3(-8, 1, -15))).is_equal(Vector3(1, 0, 0))
	assert_float(TownLayout.yaw_toward(Vector3(0, 0, 1))).is_equal_approx(0.0, 0.001)
	assert_float(TownLayout.yaw_toward(Vector3(1, 0, 0))).is_equal_approx(PI / 2.0, 0.001)
	# A block on a street's own line still gets a direction.
	assert_vector(TownLayout.facing(Vector3(0, 1, 0))).is_equal(Vector3(0, 0, 1))


func test_lamps_stand_inside_the_walls_on_the_pavement_and_off_the_blocks() -> void:
	var half := float(Config.TD_PLAZA_SIZE) * 0.5
	var spots := TownLayout.lamp_spots()
	assert_int(spots.size()).is_greater(16)
	for at: Vector3 in spots:
		assert_float(absf(at.x)).is_less_equal(half - TownConfig.TOWN_EDGE_CLEAR)
		assert_float(absf(at.z)).is_less_equal(half - TownConfig.TOWN_EDGE_CLEAR)
		assert_bool(TownLayout.on_street(at, 1.0)).is_true()
		for c: Vector3 in _blocks():
			assert_bool(absf(at.x - c.x) < 2.0 and absf(at.z - c.z) < 2.0).is_false()


# A flood fill over a one-metre grid (a person is under a metre wide): from the start, every landmark's surroundings
# and the front of every block can be walked to, with blocks and landmarks as obstacles grown by half a metre.
func test_every_landmark_and_every_block_front_can_be_walked_to() -> void:
	var half := Config.TD_PLAZA_SIZE / 2
	var blocked := {}
	var obstacles: Array[Vector3] = []
	obstacles.append_array(_blocks())
	obstacles.append_array(LandmarkConfig.LANDMARK_POSITIONS)
	for o: Vector3 in obstacles:
		var reach := TopDownMain.BLOCK_SIZE.x * 0.5 + 0.5
		for x: int in range(floori(o.x - reach), ceili(o.x + reach) + 1):
			for z: int in range(floori(o.z - reach), ceili(o.z + reach) + 1):
				blocked[Vector2i(x, z)] = true
	var seen := {Vector2i(0, 0): true}
	var queue: Array[Vector2i] = [Vector2i(0, 0)]
	var head := 0
	while head < queue.size():
		var cell := queue[head]
		head += 1
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + step
			if absi(next.x) >= half - 1 or absi(next.y) >= half - 1 or seen.has(next) or blocked.has(next):
				continue
			seen[next] = true
			queue.append(next)
	for at: Vector3 in LandmarkConfig.LANDMARK_POSITIONS:
		# A cell next to the landmark's block on the side toward the start.
		var toward := -Vector2(at.x, at.z).normalized()
		var spot := Vector2i(roundi(at.x + toward.x * 4.0), roundi(at.z + toward.y * 4.0))
		assert_bool(seen.has(spot)).override_failure_message("landmark at %s" % at).is_true()
	for c: Vector3 in _blocks():
		var front := Vector3(c.x, 0.0, c.z) + TownLayout.facing(c) * 4.0
		(
			assert_bool(seen.has(Vector2i(roundi(front.x), roundi(front.z))))
			. override_failure_message("block %s" % c)
			. is_true()
		)
