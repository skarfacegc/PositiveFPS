extends GdUnitTestSuite

# Walls and gates: Grid fixes (#56). Each gate shows its people against its need (red when short), a gate being pushed
# glows from across the screen and, from half the break depth, an off-screen gate gets an edge pointer.


func _start() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"runner": runner, "td": td}


func _rescue_ring(td: TopDownMain, count: int) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)


func _bare_border(cells: Array[Vector2i] = []) -> Border:
	var border: Border = auto_free(Border.new())
	add_child(border)
	border.setup(null)
	for c: Vector2i in cells:
		border.zone.take(c)
	border.active = true
	border._trace()
	border.polygon = border._base.duplicate()
	border._mark_gaps()
	var needs: Array[int] = []  # Fully staffed: a gate short of members would break at a shallower dent (Pressure #12).
	for g: Dictionary in border.zone.gates:
		needs.append(g["need"])
	border._slots.gate_counts.assign(needs)
	return border


func test_each_gate_shows_its_people_against_its_need_and_is_red_when_short() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	# Loop tuning (#93): a gate now needs 3, so 12 people would fill four gates exactly; 8 leaves each short.
	_rescue_ring(td, 8)
	await runner.simulate_frames(120)
	var marks := td.gate_marks
	assert_int(td.border.zone.gates.size()).is_equal(4)
	for g: int in range(4):
		assert_str(marks.label_text(g)).is_equal(GateMarks.count_text(2, 3))  # 8 people share four gates of 3 (was 12 of 5).
		assert_bool(marks.is_short(g)).is_true()
		var label: Label3D = marks._labels[g]
		# Clean HUD (#92): a short gate nobody pushes shows no count until E or F is held.
		assert_bool(label.visible).is_false()
		assert_object(label.modulate).is_equal(BorderConfig.GATE_COUNT_SHORT_COLOUR)
	td.take_block.holding = true
	await runner.simulate_frames(2)
	var avoid := HudSafeArea.label_avoid(td)
	var shown := 0
	for g: int in range(4):
		var held_label: Label3D = marks._labels[g]
		# Shown unless it would sit over a HUD panel (Clean HUD item 5).
		assert_bool(held_label.visible).is_equal(not HudSafeArea.hides_label(td, avoid, held_label.position))
		shown += 1 if held_label.visible else 0
	assert_int(shown).is_greater(0)
	td.take_block.holding = false
	# Enough people: every gate reads full and the red goes.
	for i: int in range(12, 20):
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(float(i - 12) - 4.0, 0.0, 2.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(120)
	for g: int in range(4):
		assert_str(marks.label_text(g)).is_equal(GateMarks.count_text(3, 3))  # Loop tuning (#93): need 3 (was 5/5).
		assert_bool(marks.is_short(g)).is_false()
		var label: Label3D = marks._labels[g]
		assert_object(label.modulate).is_equal(BorderConfig.GATE_COUNT_OK_COLOUR)


func test_the_labels_follow_the_gates_when_the_zone_grows_and_hide_without_a_border() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await runner.simulate_frames(5)
	for g: Variant in td.gate_marks._labels:
		assert_bool((td.gate_marks._labels[g] as Label3D).visible).is_false()  # Nobody rescued: no border yet.
	_rescue_ring(td, 24)
	await runner.simulate_frames(60)
	td.border.zone.take(Vector2i(3, 2))
	await runner.simulate_frames(60)
	assert_int(td.border.zone.gates.size()).is_equal(5)
	assert_int(td.gate_marks._labels.size()).is_equal(5)
	# Taking the cell back out (a loss) drops the extra labels.
	td.border.zone.lose(Vector2i(3, 2))
	await runner.simulate_frames(60)
	assert_int(td.gate_marks._labels.size()).is_equal(4)


func test_odd_inputs_are_handled() -> void:
	var s: Dictionary = await _start()
	var td: TopDownMain = s["td"]
	var marks := td.gate_marks
	assert_bool(marks.is_short(-1)).is_false()
	assert_bool(marks.is_short(99)).is_false()
	assert_str(marks.label_text(99)).is_equal("")
	marks._quad(Vector2(1.0, 1.0), Vector2(1.0, 1.0), 1.0, Color.RED)  # A zero-length piece draws nothing.
	var loose := GateMarks.new()  # No level yet: a frame does nothing.
	loose._process(0.1)
	assert_float(loose._clock).is_equal(0.0)
	loose.free()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_bent_gate_is_found_with_its_deepest_point_and_a_flat_line_has_none() -> void:
	var border := _bare_border()
	assert_int(border.pressed_gates(0.01).size()).is_equal(0)
	var east := border.push.sample_of(Vector3(9.0, 0.0, 0.0))
	border.push.dent[east] = PushConfig.PUSH_BREAK_DEPTH * 0.6
	var pressed := border.pressed_gates(PushConfig.PUSH_POINTER_FROM)
	assert_int(pressed.size()).is_equal(1)
	assert_float(pressed[0]["bend"] as float).is_equal_approx(0.6, 0.001)
	var at: Vector3 = pressed[0]["at"]
	assert_float(at.x).is_equal_approx(9.0, 0.5)
	assert_int(pressed[0]["gate"] as int).is_equal(border.point_gate(east))
	# Less than the pointer share: the glow wants it (from PUSH_ALERT_FROM) but the pointer does not.
	border.push.dent[east] = PushConfig.PUSH_BREAK_DEPTH * 0.3
	assert_int(border.pressed_gates(PushConfig.PUSH_ALERT_FROM).size()).is_equal(1)
	assert_int(border.pressed_gates(PushConfig.PUSH_POINTER_FROM).size()).is_equal(0)
	var none: Array[Vector3] = GateMarks.pointers(border)["points"]
	assert_int(none.size()).is_equal(0)
	assert_float(border.gate_deepest(-1)["bend"] as float).is_equal(0.0)
	assert_float(border.gate_deepest(99)["bend"] as float).is_equal(0.0)


func test_the_pointer_list_holds_the_pressed_gates_with_the_bend_as_urgency() -> void:
	var border := _bare_border()
	var east := border.push.sample_of(Vector3(9.0, 0.0, 0.0))
	border.push.dent[east] = PushConfig.PUSH_BREAK_DEPTH * 0.8
	var list := GateMarks.pointers(border)
	var points: Array[Vector3] = list["points"]
	var urgencies: Array[float] = list["urgencies"]
	assert_int(points.size()).is_equal(1)
	assert_float(urgencies[0]).is_equal_approx(0.8, 0.001)
	border.active = false
	assert_int(border.pressed_gates(0.01).size()).is_equal(0)


func test_a_pushed_gate_glows_and_a_far_one_past_half_depth_gets_an_edge_pointer() -> void:
	var s: Dictionary = await _start()
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_rescue_ring(td, 24)
	td.border.zone.take(Vector2i(3, 2))
	td.border.zone.take(Vector2i(3, 1))  # The Bandstand square: its north side (z = -33) is a gate, 33 m from the player.
	await runner.simulate_frames(90)
	assert_int(td.gate_marks.glowing).is_equal(0)
	var base_arrows := td.arrows.arrows.size()
	var far := td.border.push.sample_of(Vector3(27.0, 0.0, -33.0))
	assert_bool(td.border.point_dentable(far)).is_true()
	td.border.push.dent[far] = PushConfig.PUSH_BREAK_DEPTH * 0.7
	await runner.simulate_frames(4)
	assert_int(td.gate_marks.glowing).is_greater_equal(1)
	assert_int(td.arrows.arrows.size()).is_greater(base_arrows)
	# A light push (a quarter of the way) glows but earns no pointer.
	td.border.push.reset()
	await runner.simulate_frames(4)
	assert_int(td.gate_marks.glowing).is_equal(0)
	td.border.push.dent[far] = PushConfig.PUSH_BREAK_DEPTH * 0.3
	await runner.simulate_frames(2)
	assert_int(td.gate_marks.glowing).is_greater_equal(1)
	assert_int(td.arrows.arrows.size()).is_equal(base_arrows)
	assert_int(td.gate_marks._mesh.get_surface_count()).is_equal(1)
