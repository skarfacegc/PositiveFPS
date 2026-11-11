extends GdUnitTestSuite

# Walls and gates: Pressure (#12, #13) and the interface the Defences pass codes against. Scene-free: a bare Border
# holding the start square and a few cells, no frames. A thin gate (fewer members than it needs) breaks at a shallower
# dent; a defence's modifiers (strength_mult, cannot_break, cannot_lose) are kept per gate across re-traces and
# dropped when the gate closes; a gate that stays broken for GATE_LOST_SECONDS loses the cell behind it, and the
# cells that leaves cut off.

const DT := 1.0 / 60.0
const EAST := Vector2i(3, 2)
const FAR_EAST := Vector2i(4, 2)


func _border(cells: Array[Vector2i] = []) -> Border:
	return TopDownTestUtil.bare_border(self, cells)


# Every gate of the line fully staffed (members = need).
func _staff(border: Border, share: float = 1.0) -> void:
	var counts: Array[int] = []
	for g: Dictionary in border.zone.gates:
		var need: int = g["need"]
		counts.append(roundi(float(need) * share))
	border._slots.gate_counts.assign(counts)


# The index of the gate with the cell `cell` behind it (the first such gate), or -1.
func _gate_behind(border: Border, cell: Vector2i) -> int:
	for g: int in range(border.zone.gates.size()):
		if border.zone.cell_behind(border.zone.gates[g]) == cell:
			return g
	return -1


# A dentable point of gate `g`.
func _point(border: Border, g: int) -> int:
	for i: int in range(border.point_count()):
		if border.point_gate(i) == g and border.point_dentable(i):
			return i
	return -1


# Opens a break on gate `g` by pushing its middle point past any depth.
func _break_gate(border: Border, g: int) -> void:
	var i := _point(border, g) + 1
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH + 0.6
	var nobody: Array[Person] = []
	border.push.update(nobody, DT, 1.0)
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH + 0.6  # (The update sprang it back a little.)


# Runs the loss counter for `seconds` in one-second steps.
func _wait(border: Border, seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(1.0, left)
		border._track_losses(step)
		left -= step


# --- The thin line (#12) --------------------------------------------------------------------------------------------


func test_a_gate_breaks_at_a_depth_that_follows_its_members() -> void:
	var border := _border()
	var depth := PushConfig.PUSH_BREAK_DEPTH
	_staff(border, 0.0)
	assert_float(border.gate_fill(0)).is_equal(0.0)
	assert_float(border.break_depth(0)).is_equal_approx(depth * PushConfig.THIN_LINE_MIN_STRENGTH, 0.0001)
	_staff(border, 0.5)
	var half_fill := border.gate_fill(0)
	assert_float(half_fill).is_between(0.4, 0.7)
	assert_float(border.break_depth(0)).is_equal_approx(
		depth * lerpf(PushConfig.THIN_LINE_MIN_STRENGTH, 1.0, half_fill), 0.0001
	)
	_staff(border)
	assert_float(border.gate_fill(0)).is_equal(1.0)
	assert_float(border.break_depth(0)).is_equal_approx(depth, 0.0001)
	# More members than it needs do not make it stronger than the full depth.
	var over: Array[int] = []
	for g: Dictionary in border.zone.gates:
		var need: int = g["need"]
		over.append(need + 5)
	border._slots.gate_counts.assign(over)
	assert_float(border.gate_fill(0)).is_equal(1.0)
	assert_float(border.break_depth(0)).is_equal_approx(depth, 0.0001)


func test_a_thin_gate_snaps_at_a_dent_a_full_one_holds() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	var i := _point(border, 0)
	var dent := PushConfig.PUSH_BREAK_DEPTH * 0.7  # Between the thin depth (0.5) and the full depth (1.0).
	_staff(border)
	border.push.dent[i] = dent
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.breaks.size()).is_equal(0)
	_staff(border, 0.0)
	border.push.dent[i] = dent
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.breaks.size()).is_equal(1)


func test_a_thin_gate_reads_as_more_bent_for_the_same_dent() -> void:
	var border := _border()
	var i := _point(border, 0)
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH * 0.5
	_staff(border)
	assert_float(border.push.bend_of_point(i)).is_equal_approx(0.5, 0.0001)
	_staff(border, 0.0)
	assert_float(border.push.bend_of_point(i)).is_equal_approx(1.0, 0.0001)
	assert_float(border.gate_deepest(0)["bend"]).is_equal_approx(1.0, 0.0001)


func test_a_short_gates_members_stand_further_apart() -> void:
	# BorderSlots spreads the members it has evenly along the gate: fewer members, wider spacing, nothing else needed.
	var full := BorderSlots.share_out([7, 7, 7, 7] as Array[int], 28)
	var thin := BorderSlots.share_out([7, 7, 7, 7] as Array[int], 12)
	assert_int(full[0]).is_equal(7)
	assert_int(thin[0]).is_equal(3)
	assert_float(18.0 / float(thin[0])).is_greater(18.0 / float(full[0]))


# --- The defence interface ------------------------------------------------------------------------------------------


func test_modifiers_default_to_nothing_and_are_kept_per_gate() -> void:
	var border := _border()
	var mods := border.gate_modifiers(1)
	assert_float(mods["strength_mult"]).is_equal(1.0)
	assert_bool(mods["cannot_break"]).is_false()
	assert_bool(mods["cannot_lose"]).is_false()
	border.set_gate_modifiers(1, {"strength_mult": 1.5})
	assert_float(border.gate_modifiers(1)["strength_mult"]).is_equal(1.5)
	assert_bool(border.gate_modifiers(1)["cannot_break"]).is_false()
	assert_float(border.gate_modifiers(0)["strength_mult"]).is_equal(1.0)
	border.set_gate_modifiers(1, {"cannot_break": true})  # Keys not given keep their value.
	assert_float(border.gate_modifiers(1)["strength_mult"]).is_equal(1.5)
	assert_bool(border.gate_modifiers(1)["cannot_break"]).is_true()
	border.set_gate_modifiers(1, {})  # An empty set clears them.
	assert_float(border.gate_modifiers(1)["strength_mult"]).is_equal(1.0)
	# A gate that is not on the line is ignored.
	border.set_gate_modifiers(99, {"cannot_break": true})
	assert_bool(border.gate_modifiers(99)["cannot_break"]).is_false()


func test_strength_mult_multiplies_the_break_depth() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	_staff(border)
	border.set_gate_modifiers(0, {"strength_mult": 1.5})
	assert_float(border.break_depth(0)).is_equal_approx(PushConfig.PUSH_BREAK_DEPTH * 1.5, 0.0001)
	var i := _point(border, 0)
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH * 1.2
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.breaks.size()).is_equal(0)
	border.set_gate_modifiers(0, {"strength_mult": 1.0})
	border.push.dent[i] = PushConfig.PUSH_BREAK_DEPTH * 1.2
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.breaks.size()).is_equal(1)


func test_a_gate_that_cannot_break_dents_but_never_snaps() -> void:
	var border := _border()
	var nobody: Array[Person] = []
	_staff(border, 0.0)
	border.set_gate_modifiers(0, {"cannot_break": true})
	var i := _point(border, 0)
	border.push.dent[i] = PushConfig.PUSH_DENT_MAX
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.breaks.size()).is_equal(0)
	assert_float(border.push.dent[i]).is_greater(PushConfig.PUSH_BREAK_DEPTH * 0.5)
	assert_float(border.push.bend_of_point(i)).is_equal(1.0)  # It reads as fully bent.
	# Another gate on the same line still snaps.
	var j := _point(border, 1)
	border.push.dent[j] = PushConfig.PUSH_DENT_MAX
	border.push.update(nobody, DT, 1.0)
	assert_int(border.push.breaks.size()).is_equal(1)


func test_modifiers_stay_with_their_gate_across_a_retrace_and_go_when_it_closes() -> void:
	var border := _border()
	var closed: Array[int] = []
	border.gate_closed.connect(func(g: int) -> void: closed.append(g))
	var west := border.zone.nearest_gate(Vector2(-9.0, 0.0))
	var east := border.zone.nearest_gate(Vector2(9.0, 0.0))
	var west_key: String = west["key"]
	var west_id: int = west["id"]
	var east_id: int = east["id"]
	border.set_gate_modifiers(west_id, {"cannot_lose": true})
	border.set_gate_modifiers(east_id, {"strength_mult": 1.5})
	# Taking the cell east of the start square joins the street piece: the east side is no longer a gate.
	border.zone.take(EAST)
	border._trace()
	assert_array(closed).contains_exactly([east_id])
	var west_now := -1
	for g: int in range(border.zone.gates.size()):
		if border.zone.gates[g]["key"] == west_key:
			west_now = g
	assert_int(west_now).is_greater_equal(0)
	assert_bool(border.gate_modifiers(west_now)["cannot_lose"]).is_true()
	# Nothing else carries the east gate's strength.
	for g: int in range(border.zone.gates.size()):
		assert_float(border.gate_modifiers(g)["strength_mult"]).is_equal(1.0)
	# Taking it back (it cannot be lost to the gloom here, so use the zone) re-opens the east gate without the old mods.
	border.zone.lose(EAST)
	border._trace()
	for g: int in range(border.zone.gates.size()):
		assert_float(border.gate_modifiers(g)["strength_mult"]).is_equal(1.0)


# --- Lost cells (#13) -----------------------------------------------------------------------------------------------


func test_a_gate_broken_for_twelve_seconds_loses_the_cell_behind_it() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	var lost_seen: Array = []
	border.cells_lost.connect(func(cells: Array[Vector2i], gate: int) -> void: lost_seen.append([cells, gate]))
	var g := _gate_behind(border, FAR_EAST)
	assert_int(g).is_greater_equal(0)
	_break_gate(border, g)
	_wait(border, BorderConfig.GATE_LOST_SECONDS - 1.0)
	assert_bool(border.zone.has(FAR_EAST)).is_true()
	assert_float(border.broken_seconds(g)).is_equal_approx(BorderConfig.GATE_LOST_SECONDS - 1.0, 0.01)
	_wait(border, 1.5)
	assert_bool(border.zone.has(FAR_EAST)).is_false()
	assert_bool(border.zone.has(EAST)).is_true()
	assert_bool(border.zone.has(TownGrid.start_cell())).is_true()
	assert_int(lost_seen.size()).is_equal(1)
	var cells: Array = lost_seen[0][0]
	assert_array(cells).contains_exactly([FAR_EAST])
	assert_int(lost_seen[0][1]).is_equal(g)
	assert_int(border.last_loss["need"]).is_greater(0)
	assert_int(border.last_loss["members"]).is_equal(0)


func test_the_line_traces_again_and_the_pips_of_the_lost_cell_start_over() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	border.pips.counts[FAR_EAST] = 2  # (As if it had been rescued into earlier.)
	var before := border.zone.version
	_break_gate(border, _gate_behind(border, FAR_EAST))
	_wait(border, BorderConfig.GATE_LOST_SECONDS + 0.5)
	assert_int(border.zone.version).is_not_equal(before)
	assert_int(border.pips.filled(FAR_EAST)).is_equal(0)
	border._trace()
	assert_int(border.zone.held.size()).is_equal(2)
	# The lost cell is next to the zone again and may be taken back; the old break is gone with its gate.
	assert_bool(border.zone.can_take(FAR_EAST)).is_true()
	assert_int(border.push.breaks.size()).is_equal(0)


func test_a_cell_the_loss_cuts_off_from_the_start_is_lost_with_it() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	var lost_seen: Array = []
	border.cells_lost.connect(func(cells: Array[Vector2i], _gate: int) -> void: lost_seen.append(cells))
	_break_gate(border, _gate_behind(border, EAST))
	_wait(border, BorderConfig.GATE_LOST_SECONDS + 0.5)
	assert_bool(border.zone.has(EAST)).is_false()
	assert_bool(border.zone.has(FAR_EAST)).is_false()
	assert_int(border.zone.held.size()).is_equal(1)
	assert_int(lost_seen.size()).is_equal(1)
	assert_array(lost_seen[0]).contains_exactly_in_any_order([EAST, FAR_EAST])


func test_the_start_square_is_never_lost() -> void:
	var border := _border()
	_staff(border, 0.0)
	for g: int in range(border.zone.gates.size()):
		_break_gate(border, g)
	_wait(border, BorderConfig.GATE_LOST_SECONDS * 3.0)
	assert_int(border.zone.held.size()).is_equal(1)
	assert_bool(border.zone.has(TownGrid.start_cell())).is_true()


func test_a_gate_mended_in_time_keeps_its_cell_and_its_clock_starts_over() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	var g := _gate_behind(border, FAR_EAST)
	_break_gate(border, g)
	_wait(border, 8.0)
	assert_float(border.broken_seconds(g)).is_greater(7.0)
	border.push.breaks.clear()  # Mended.
	for i: int in range(border.push.broken.size()):
		border.push.broken[i] = false
	_wait(border, 1.0)
	assert_float(border.broken_seconds(g)).is_equal(0.0)
	_break_gate(border, g)
	_wait(border, 8.0)
	assert_bool(border.zone.has(FAR_EAST)).is_true()  # 8 s since it broke again, not 17.


func test_a_gate_that_cannot_be_lost_keeps_its_cell_however_long_it_stays_broken() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	var g := _gate_behind(border, FAR_EAST)
	border.set_gate_modifiers(g, {"cannot_lose": true})
	_break_gate(border, g)
	_wait(border, BorderConfig.GATE_LOST_SECONDS * 3.0)
	assert_bool(border.zone.has(FAR_EAST)).is_true()


func test_a_loss_that_would_take_a_protected_cell_with_it_is_refused() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	# The far cell is protected: losing the near one would cut it off, so the near one stays too.
	border.set_gate_modifiers(_gate_behind(border, FAR_EAST), {"cannot_lose": true})
	_break_gate(border, _gate_behind(border, EAST))
	_wait(border, BorderConfig.GATE_LOST_SECONDS * 2.0)
	assert_bool(border.zone.has(EAST)).is_true()
	assert_bool(border.zone.has(FAR_EAST)).is_true()


func test_the_cell_behind_a_street_mouth_is_the_one_farther_from_the_start() -> void:
	var border := _border([EAST])
	var mouths := 0
	for gate: Dictionary in border.zone.gates:
		var behind := border.zone.cells_behind(gate)
		if behind.size() == 2:
			mouths += 1
			assert_array(behind).contains_exactly_in_any_order([TownGrid.start_cell(), EAST])
			assert_bool(border.zone.cell_behind(gate) == EAST).is_true()
	assert_int(mouths).is_equal(2)  # The street piece's north and south mouths.


func test_the_clock_of_a_gate_that_vanishes_is_dropped_and_odd_gates_are_ignored() -> void:
	var border := _border([EAST, FAR_EAST])
	_staff(border, 0.0)
	_break_gate(border, _gate_behind(border, FAR_EAST))
	_wait(border, 3.0)
	assert_bool(border._broken_for.is_empty()).is_false()
	border.zone.lose(FAR_EAST)  # The cell goes some other way (the player's own doing) and the line is traced again.
	border._trace()
	border.push.breaks.clear()
	border._track_losses(1.0)
	assert_bool(border._broken_for.is_empty()).is_true()
	assert_float(border.broken_seconds(-1)).is_equal(0.0)
	assert_float(border.broken_seconds(99)).is_equal(0.0)
	# A zone with no cell has nothing behind a gate.
	var empty: Array[Vector2i] = []
	border.zone.held = empty
	assert_bool(border._lose_behind(0)).is_false()


# --- The banner and the pulse ---------------------------------------------------------------------------------------


func test_a_lost_cell_shows_a_slim_banner_and_pulses_grey() -> void:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(5)
	var td: TopDownMain = runner.scene()
	td.border.cells_lost.emit([EAST, FAR_EAST] as Array[Vector2i], 0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.LOST)
	assert_str(td.intro.current_text()).is_equal(BorderConfig.LOST_TEXT)
	assert_str(BorderConfig.LOST_TEXT).is_equal("The gloom took a block.")
	var pulse: LostPulse = td.events._pulse
	assert_int(pulse.count()).is_equal(2)
	var before := pulse.get_child(0) as MeshInstance3D
	var mat := before.material_override as StandardMaterial3D
	var start_alpha := mat.albedo_color.a
	pulse.update(BorderConfig.LOST_PULSE_SECONDS * 0.5)
	assert_float(mat.albedo_color.a).is_less(start_alpha)
	assert_float(mat.albedo_color.r).is_equal_approx(BorderConfig.LOST_PULSE_COLOUR.r, 0.0001)
	pulse.update(BorderConfig.LOST_PULSE_SECONDS)
	assert_int(pulse.count()).is_equal(0)
	assert_str(Intro.text_for(Intro.Prompt.LOST)).is_equal(BorderConfig.LOST_TEXT)
	assert_int(Intro.icon_for(Intro.Prompt.LOST)).is_equal(MoodIcons.Kind.CLOUD)
	await TopDownTestUtil.leave_loaded_scene(td)
