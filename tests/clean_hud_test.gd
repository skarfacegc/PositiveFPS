extends GdUnitTestSuite

# Walls and gates: Clean HUD (#92). Screen-space layout and text: the HUD panels do not overlap at 960 x 540 and
# 1920 x 1080 in either look, one banner shows at a time (events beat tips), the controls strip shows for the first
# seconds and while H is held, landmark pointers carry an initial, world labels keep off the HUD, gate counts show only
# when needed, the take preview is one small panel beside the cell and joy numbers add up per person.

const SMALL := Vector2i(960, 540)
const LARGE := Vector2i(1920, 1080)


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	Config.intro_override = -1
	Input.action_release("show_controls")
	get_window().size = TopDownTestUtil.WINDOW_SIZE


# A level loaded at a window of `size` (the minimap and the HUD lay out from the window size at load).
func _level_at(size: Vector2i) -> Dictionary:
	get_window().size = size
	await get_tree().process_frame
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	var td: TopDownMain = runner.scene()
	td.minimap._timer = -1.0e12
	await runner.simulate_frames(8)
	TopDownTestUtil.send_everyone_away(td)
	return {"td": td, "runner": runner}


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(8)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	return {"td": td, "runner": runner}


# --- Layout -----------------------------------------------------------------------------------------------------------


func _check_layout(td: TopDownMain, screen: Rect2) -> void:
	# The longest burst line and a long people line, a recording mark, and one banner: the worst case.
	td.hud.set_burst(0.0, true, 99)
	td.hud.set_recording(true)
	td.hud.set_people("People: 123 on the line, 45 short, 6 on defences", true)
	td.intro.event_notice("Claimed the Bell tower: gloom slowed x0.4 nearby, and a long second clause to shrink it")
	td.prompts.tick(screen)
	assert_bool(td.hud.controls_shown()).is_true()
	var rects: Array[Rect2] = HudSafeArea.avoid_rects(td.hud, td.minimap, td)
	assert_int(rects.size()).is_greater_equal(8)
	rects.append(td.prompts._rect)
	for i: int in range(rects.size()):
		(
			assert_bool(screen.encloses(rects[i]))
			. override_failure_message("HUD rectangle %s leaves the %s window" % [rects[i], screen.size])
			. is_true()
		)
		for j: int in range(i + 1, rects.size()):
			(
				assert_bool(rects[i].intersects(rects[j]))
				. override_failure_message("HUD rectangles %s and %s overlap at %s" % [rects[i], rects[j], screen.size])
				. is_false()
			)


func _layout_in_both_looks(size: Vector2i) -> void:
	Config.intro_override = 1
	var s: Dictionary = await _level_at(size)
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var screen := Rect2(Vector2.ZERO, Vector2(size))
	assert_vector(td.get_viewport().get_visible_rect().size).is_equal(Vector2(size))
	_check_layout(td, screen)
	td.set_look(Looks.Mode.STYLED)
	await runner.simulate_frames(3)
	td.hud.set_burst(0.0, true, 99)
	td.hud.set_people("People: 123 on the line, 45 short, 6 on defences", true)
	td.intro.event_notice("Claimed the Bell tower: gloom slowed x0.4 nearby, and a long second clause to shrink it")
	td.prompts.tick(screen)
	var rects: Array[Rect2] = HudSafeArea.avoid_rects(td.hud, td.minimap, td)
	rects.append(td.prompts._rect)
	for i: int in range(rects.size()):
		assert_bool(screen.encloses(rects[i])).is_true()
		for j: int in range(i + 1, rects.size()):
			(
				assert_bool(rects[i].intersects(rects[j]))
				. override_failure_message("styled HUD rectangles %s and %s overlap at %s" % [rects[i], rects[j], size])
				. is_false()
			)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_hud_rectangles_do_not_overlap_at_960_by_540() -> void:
	await _layout_in_both_looks(SMALL)


func test_the_hud_rectangles_do_not_overlap_at_1920_by_1080() -> void:
	await _layout_in_both_looks(LARGE)


func test_the_controls_strip_fits_a_960_wide_window_in_both_looks() -> void:
	var font := ThemeDB.fallback_font
	assert_float(font.get_string_size(LevelHud.HINT, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x).is_less(960.0 - 40.0)
	assert_str(LevelHud.HINT).contains("[F4] look")
	assert_str(LevelHud.HINT).contains("H help")
	var s: Dictionary = await _level_at(SMALL)
	var td: TopDownMain = s["td"]
	assert_float(td.hud.hint_label.get_global_rect().end.x).is_less(960.0)
	assert_float(td.hud.hint_label.get_global_rect().end.y).is_less_equal(540.0)
	td.set_look(Looks.Mode.STYLED)
	await (s["runner"] as GdUnitSceneRunner).simulate_frames(3)
	assert_float(td.hud.key_panel.get_global_rect().end.x).is_less(960.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_banner_keeps_clear_of_the_minimap_in_a_narrow_window() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _level_at(SMALL)
	var td: TopDownMain = s["td"]
	td.intro.event_notice("A very long event line, " + "word ".repeat(30))
	td.prompts.tick(Rect2(Vector2.ZERO, Vector2(SMALL)))
	var r: Rect2 = td.prompts._rect
	assert_float(r.position.x).is_greater_equal(td.minimap.get_global_rect().end.x)
	assert_float(r.get_center().x).is_equal_approx(480.0, 1.0)
	assert_bool(r.intersects(td.hud.landmark_label.get_global_rect())).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_people_line_has_a_dark_backing_and_sits_below_the_spirit_markers() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var backing := td.hud.people_label.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(backing).is_not_null()
	assert_float(backing.bg_color.a).is_greater(0.5)
	# The moon marker hangs about 20 px under the bar.
	var bar_bottom := td.hud.spirit_bar.get_global_rect().end.y
	assert_float(td.hud.people_label.get_global_rect().position.y).is_greater_equal(bar_bottom + 20.0)
	assert_float(td.hud.people_label.get_global_rect().end.y).is_less_equal(
		td.hud.hint_label.get_global_rect().position.y
	)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- The controls strip -----------------------------------------------------------------------------------------------


func test_the_controls_strip_shows_for_the_first_seconds_then_hides_and_h_shows_it_while_held() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	assert_bool(td.hud.hint_label.visible).is_true()
	td.night.elapsed = HudConfig.CLEAN_CONTROLS_SECONDS - 1.0
	td.level_hud.update_feedback(0.0)
	assert_bool(td.hud.hint_label.visible).is_true()
	td.night.elapsed = HudConfig.CLEAN_CONTROLS_SECONDS + 0.1
	td.level_hud.update_feedback(0.0)
	assert_bool(td.hud.hint_label.visible).is_false()
	assert_bool(td.hud.controls_shown()).is_false()
	Input.action_press("show_controls")
	td.level_hud.update_feedback(0.0)
	assert_bool(td.hud.hint_label.visible).is_true()
	Input.action_release("show_controls")
	td.level_hud.update_feedback(0.0)
	assert_bool(td.hud.hint_label.visible).is_false()
	# In the styled look the key panel follows the same rule.
	td.set_look(Looks.Mode.STYLED)
	assert_bool(td.hud.key_panel.visible).is_false()
	td.night.elapsed = 1.0
	td.level_hud.update_feedback(0.0)
	assert_bool(td.hud.key_panel.visible).is_true()
	assert_bool(td.hud.hint_label.visible).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_h_is_bound_to_show_controls() -> void:
	Controls.setup()
	assert_bool(InputMap.has_action("show_controls")).is_true()
	var found := false
	for ev: InputEvent in InputMap.action_get_events("show_controls"):
		var key := ev as InputEventKey
		if key != null and key.physical_keycode == KEY_H:
			found = true
	assert_bool(found).is_true()


# --- One banner at a time ---------------------------------------------------------------------------------------------


func test_an_event_beats_a_tip_and_the_tip_waits_until_it_has_gone() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var intro := td.intro
	intro.current = -1
	intro.queue.clear()
	intro.shown.clear()
	assert_bool(intro.request(Intro.Prompt.GUARDED)).is_true()
	assert_int(intro.current).is_equal(Intro.Prompt.GUARDED)
	# An event arrives: the tip steps back to the front of the queue and does not sit beside it.
	intro.event_notice("Claimed the Garden: nature x2")
	assert_int(intro.current).is_equal(Intro.Prompt.EVENT)
	assert_array(intro.queue).is_equal([Intro.Prompt.GUARDED])
	# A new tip asked for during the event waits too.
	assert_bool(intro.request(Intro.Prompt.SKITTISH)).is_true()
	assert_int(intro.current).is_equal(Intro.Prompt.EVENT)
	assert_array(intro.queue).is_equal([Intro.Prompt.GUARDED, Intro.Prompt.SKITTISH])
	# The banner shows the event only.
	td.prompts.tick(Rect2(Vector2.ZERO, Vector2(1280, 720)))
	assert_str(td.prompts.text).is_equal("Claimed the Garden: nature x2")
	# When the event has gone the waiting tip comes back.
	intro.update(HudConfig.CLEAN_EVENT_SECONDS + 0.1)
	assert_int(intro.current).is_equal(Intro.Prompt.GUARDED)
	assert_bool(intro.event).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_weak_event_never_replaces_a_strong_one_and_a_strong_one_replaces_any() -> void:
	var intro := Intro.new(null, false)
	intro.event_notice("Claimed the Garden", Color.WHITE)
	intro.event_notice("Someone lost their joy!", HudConfig.CLEAN_RELAPSE_TINT, HudConfig.CLEAN_EVENT_SECONDS, false)
	assert_str(intro.current_text()).is_equal("Claimed the Garden")
	intro.event_notice("Lost the Garden boost", Color.RED)
	assert_str(intro.current_text()).is_equal("Lost the Garden boost")
	assert_that(intro.tint).is_equal(Color.RED)
	# A weak event replaces a weak one, and a tip is replaced by a weak event.
	var weak := Intro.new(null, false)
	weak.event_notice("Grabbed!", Color.WHITE, 3.0, false)
	weak.event_notice("Someone lost their joy!", Color.WHITE, 3.0, false)
	assert_str(weak.current_text()).is_equal("Someone lost their joy!")
	assert_float(weak.time_left).is_equal(3.0)


func test_events_and_notices_use_the_one_banner_and_the_hud_has_no_alert_line() -> void:
	Config.intro_override = 1
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	assert_object(td.hud.get("alert_label")).is_null()
	assert_object(td.hud.get("element_label")).is_null()
	assert_object(td.hud.get("targeting_label")).is_null()
	td.events.on_person_relapsed(td.people[0])
	assert_str(td.intro.current_text()).is_equal("Someone lost their joy!")
	assert_that(td.intro.tint).is_equal(HudConfig.CLEAN_RELAPSE_TINT)
	td.events.on_player_dim_changed(true)
	assert_str(td.intro.current_text()).contains("You went dim")
	td.events.on_player_dim_changed(false)
	assert_str(td.intro.current_text()).is_equal("Your spirit is back")
	td.intro.notice(Intro.Prompt.SPIRIT_LOW, "Not enough spirit to take a block.")
	assert_str(td.intro.current_text()).is_equal("Not enough spirit to take a block.")
	assert_bool(td.intro.event).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Landmarks and the pointers ---------------------------------------------------------------------------------------


func test_a_pointer_is_an_initial_with_no_boost_words_and_the_boost_is_on_the_world_label() -> void:
	assert_str(LandmarkPointers.initial_of("Bell tower")).is_equal("B")
	assert_str(LandmarkPointers.initial_of("garden")).is_equal("G")
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.landmark_pointers.update_from(td)
	for k: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
		var p: Dictionary = td.landmark_pointers.pointer_for(LandmarkConfig.LANDMARK_NAMES[k])
		if p.is_empty():
			continue
		var text: String = p["text"]
		assert_int(text.length()).is_equal(1)
		var box: Rect2 = p["label"]
		assert_float(box.size.x).is_less(40.0)
	for lm: Landmark in td.landmarks.items:
		var look := lm.look as LandmarkLookPlaceholder
		look.sync()
		assert_str(look._label.text).contains(LandmarkConfig.LANDMARK_BOOST_TEXT[lm.index])
		assert_str(look._label.text).contains(LandmarkConfig.LANDMARK_NAMES[lm.index])
	await TopDownTestUtil.leave_loaded_scene(td)


# --- World labels keep off the HUD ------------------------------------------------------------------------------------


func test_a_world_label_under_a_hud_rectangle_is_hidden_and_a_clear_one_is_not() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var world := td.player.global_position
	var at := td.world_to_screen(world)
	var over: Array[Rect2] = [Rect2(at - Vector2(5, 5), Vector2(10, 10))]
	var clear: Array[Rect2] = [Rect2(at + Vector2(600, 600), Vector2(10, 10))]
	assert_bool(HudSafeArea.hides_label(td, over, world)).is_true()
	assert_bool(HudSafeArea.hides_label(td, clear, world)).is_false()
	assert_bool(HudSafeArea.hides_label(td, [] as Array[Rect2], world)).is_false()
	# The real rectangles are the same ones the edge pointers avoid.
	assert_int(HudSafeArea.label_avoid(td).size()).is_equal(HudSafeArea.avoid_rects(td.hud, td.minimap, td).size())
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_level_without_a_hud_has_nothing_to_keep_labels_off() -> void:
	var bare: TopDownMain = auto_free(TopDownMain.new())
	assert_int(HudSafeArea.label_avoid(bare).size()).is_equal(0)


func test_switching_the_targeting_mode_with_the_overlay_on_updates_the_overlay_line() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	td.level_hud.set_debug(true)
	td.level_hud._on_targeting_changed(Config.TargetingMode.AUTO)
	assert_str(td.hud.debug_hint_label.text).contains("Targeting: Auto")
	assert_str(td.intro.current_text()).contains("Targeting: Auto")
	td.level_hud.set_debug(false)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_window_too_small_for_the_hud_hides_no_world_label() -> void:
	get_window().size = Vector2i(64, 64)
	await get_tree().process_frame
	var runner: GdUnitSceneRunner = scene_runner(TopDownTestUtil.SCENE)
	var td: TopDownMain = runner.scene()
	await runner.simulate_frames(3)
	var world := td.player.global_position
	var at := td.world_to_screen(world)
	var over: Array[Rect2] = [Rect2(at - Vector2(5, 5), Vector2(10, 10))]
	assert_bool(HudSafeArea.hides_label(td, over, world)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_gate_counts_show_only_for_a_short_pushed_gate_or_while_e_or_f_is_held() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var marks := td.gate_marks
	for i: int in range(8):  # Loop tuning (#93): a gate needs 3 now, so eight people leave each of four gates short.
		var a := TAU * float(i) / 8.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(120)
	var gates: Array[Dictionary] = td.border.zone.gates
	assert_int(gates.size()).is_greater(0)
	# Nothing pushed and nothing held: every count is hidden, even on a gate with nobody on it.
	assert_bool(marks.counts_wanted()).is_false()
	await runner.simulate_frames(2)
	for g: int in range(gates.size()):
		assert_bool(marks.is_short(g)).is_true()
		assert_bool(marks._short_and_pushed(g)).is_false()
		assert_bool((marks._labels[g] as Label3D).visible).is_false()
	# Holding E shows the counts (the ones off the HUD).
	td.take_block.holding = true
	assert_bool(marks.counts_wanted()).is_true()
	marks._update_labels()
	var shown := 0
	for g: int in range(gates.size()):
		if (marks._labels[g] as Label3D).visible:
			shown += 1
	assert_int(shown).is_greater(0)
	td.take_block.holding = false
	assert_bool(marks.counts_wanted()).is_false()
	# A full gate shows nothing even while pushed (it is not short).
	td.defences.holding = true
	assert_bool(marks.counts_wanted()).is_true()
	td.defences.holding = false
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_short_gate_that_is_being_pushed_shows_its_count_and_a_full_one_does_not() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var runner: GdUnitSceneRunner = s["runner"]
	var marks := td.gate_marks
	# Loop tuning (#93): eight people share four gates of three, so every gate is short (was 12 of 5).
	for i: int in range(8):
		var a := TAU * float(i) / 8.0
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * 3.0, 0.0, sin(a) * 3.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(120)
	var east := td.border.push.sample_of(Vector3(9.0, 0.0, 0.0))
	var gate := td.border.point_gate(east)
	assert_bool(marks.is_short(gate)).is_true()
	assert_bool(marks._short_and_pushed(gate)).is_false()  # Short but not pushed.
	td.border.push.dent[east] = PushConfig.PUSH_BREAK_DEPTH * 0.3
	assert_bool(marks._short_and_pushed(gate)).is_true()
	td.border.push.reset()
	assert_bool(marks._short_and_pushed(gate)).is_false()
	# Eight more people fill every gate: pushed or not, a full gate shows nothing.
	for i: int in range(12, 20):
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(float(i - 12) - 4.0, 0.0, 2.0), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(120)
	assert_bool(marks.is_short(gate)).is_false()
	td.border.push.dent[east] = PushConfig.PUSH_BREAK_DEPTH * 0.3
	assert_bool(marks._short_and_pushed(gate)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_take_preview_is_one_small_panel_beside_the_cell_with_cost_pips_and_gates() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var tb := td.take_block
	var cell := TownGrid.neighbours(TownGrid.start_cell())[0]
	tb.holding = true
	tb.target_cell = cell
	tb.preview = td.border.zone.preview(cell, true)
	var text := tb.preview_text()
	var lines := text.split("\n")
	assert_int(lines.size()).is_equal(3)
	assert_str(lines[0]).contains("spirit")
	assert_str(lines[1]).contains("/%d pips" % BorderConfig.TAKE_RESCUES)
	assert_str(lines[2]).contains("gate")
	tb._sync_cell_labels()
	tb._update_label()
	tb._cull_cell_labels()
	# Beside the cell, not on it; the cell's own tag is folded into the panel so the two never stack.
	assert_float(tb._label.position.x).is_greater(TownGrid.cell_centre(cell).x + TownConfig.TOWN_CELL_SIZE * 0.5)
	assert_int(tb._label.horizontal_alignment).is_equal(HORIZONTAL_ALIGNMENT_LEFT)
	assert_bool((tb._cell_labels[cell] as Label3D).visible).is_false()
	tb.holding = false
	tb._cull_cell_labels()
	assert_bool((tb._cell_labels[cell] as Label3D).visible).is_true()
	await TopDownTestUtil.leave_loaded_scene(td)


# --- Joy numbers ------------------------------------------------------------------------------------------------------


func test_joy_numbers_add_up_to_one_running_total_per_person_per_second() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var person: Person = td.people[0]
	var look: PersonLook = person.look
	look.show_number(32.0, 1.0)
	var first := look._number_label
	assert_str(first.text).is_equal("+32")
	look.clock += 0.4
	look.show_number(64.0, 1.0)
	assert_bool(first.is_queued_for_deletion()).is_true()
	assert_str(look._number_label.text).is_equal("+96")
	look.clock += 0.4
	look.show_number(4.0, Config.MATCH_MULT)
	assert_str(look._number_label.text).is_equal("+100!")
	# A second later the total starts again.
	look.clock += HudConfig.CLEAN_JOY_NUMBER_SECONDS + 0.5
	look.show_number(8.0, 1.0)
	assert_str(look._number_label.text).is_equal("+8")
	await TopDownTestUtil.leave_loaded_scene(td)
