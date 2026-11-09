extends GdUnitTestSuite

# Checkpoint 5: a fully stretched border with no gloom pressure must not blink gaps.
#
# Cause (round 24 recording 20261104-094734, from 156 s): the loop is eased toward n x BORDER_TARGET_SPACING (n = people
# rescued), which is EXACTLY where slot_count_for() (a ceiling) steps from n to n + 1. A hair of noise in the length
# flipped the slot count, so with a post on the loop the border wanted 46 members one frame and 47 the next. The 47th
# is a benched (faltering) spare, who walks back into a slot and opens a gap on both sides, then leaves again.

const CENTRE := Vector3(-11.7, 0.0, -6.5)
const PEOPLE := 49


func after_test() -> void:
	Config.intro_override = -1


func _level() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	var r := BorderCentre.circle_radius(PEOPLE)
	for i: int in range(PEOPLE):
		var a := TAU * float(i) / float(PEOPLE)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(300)
	return {"runner": runner, "td": td}


# Sets the loop to a plain circle of this length (a hand-set loop, as the older border tests do) and runs the slot code.
func _assign_at(td: TopDownMain, rescued: Array[Person], length: float, delta: float) -> void:
	var b := td.border
	var n := Config.BORDER_SAMPLES
	var radius := length / (2.0 * float(n) * sin(PI / float(n)))
	b.polygon = BorderShape.circle_polygon(Vector2(CENTRE.x, CENTRE.z), radius, n)
	b._update_falter(rescued, delta)
	b._assign_members(rescued)


func _rescued(td: TopDownMain) -> Array[Person]:
	var out: Array[Person] = []
	for p: Person in td.people:
		if p.is_rescued:
			out.append(p)
	return out


# Runs the slot code through `steps` frames of 0.1 s with the loop length cycling through `lengths`. Returns the
# number of frames on which the set of gap segments changed, and the most members the border held.
func _blink(td: TopDownMain, lengths: Array[float], steps: int, settle: float = -1.0) -> Dictionary:
	var b := td.border
	var rescued := _rescued(td)
	b.active = true
	# One beautified block on the loop (a post), as in the recording, and six weak members (some become benched spares).
	var bld: Building = b.buildings[0]
	b.buildings.clear()
	b.buildings.append(bld)
	var first_len: float = settle if settle > 0.0 else lengths[0]
	var radius := first_len / (2.0 * float(Config.BORDER_SAMPLES) * sin(PI / float(Config.BORDER_SAMPLES)))
	bld.centre = Vector2(CENTRE.x + radius, CENTRE.z)
	bld.beautified = true
	# Round 26: a break made by pushing is the real gap that must not blink (faltering members no longer open gaps).
	for k: int in range(10, 13):
		b.push.broken[k] = true
	# Settle for 5 s at the first length.
	for s: int in range(50):
		_assign_at(td, rescued, first_len, 0.1)
	var changes := 0
	var most := 0
	var last := str(b.segment_gap)
	for s: int in range(steps):
		_assign_at(td, rescued, lengths[s % lengths.size()], 0.1)
		most = maxi(most, b.members.size())
		var sig := str(b.segment_gap)
		if sig != last:
			changes += 1
		last = sig
	return {"changes": changes, "most": most, "posts": b.post_count, "gaps": b.gap_count()}


func test_a_length_on_the_slot_step_does_not_blink_gaps() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var step := float(PEOPLE) * Config.BORDER_TARGET_SPACING
	# Before the fix: 59 changes in 60 frames, and the border held 47 members every other frame (46 with a post worth 3,
	# 48 worth 1).
	var out := await _blink(td, [step - 0.15, step + 0.15], 60)
	assert_int(out["posts"]).is_equal(1)
	assert_int(out["changes"]).is_equal(0)
	assert_int(out["most"]).is_equal(49 - Config.BORDER_POST_WORTH)
	# The break is still a real gap: the fix does not hide it.
	assert_int(out["gaps"]).is_greater(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_real_change_of_length_still_changes_the_gaps_once() -> void:
	var s: Dictionary = await _level()
	var td: TopDownMain = s["td"]
	var step := float(PEOPLE) * Config.BORDER_TARGET_SPACING
	# Well past the hold: one slot more is wanted, so the ring changes once and then stays.
	var out := await _blink(td, [step + 0.8 * Config.BORDER_TARGET_SPACING], 60, step - 0.15)
	assert_int(out["changes"]).is_between(1, 2)
	assert_int(out["most"]).is_equal(50 - Config.BORDER_POST_WORTH)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_held_slot_count_keeps_a_count_near_its_step_and_follows_a_real_change() -> void:
	var sp := Config.BORDER_TARGET_SPACING
	var hold := Config.BORDER_SLOT_COUNT_HOLD
	# No previous count: the plain ceiling.
	assert_int(BorderShape.held_slot_count(49.0 * sp + 0.1, 0)).is_equal(50)
	assert_int(BorderShape.held_slot_count(49.0 * sp - 0.1, 0)).is_equal(49)
	# On the step either way, 49 is kept.
	assert_int(BorderShape.held_slot_count(49.0 * sp + 0.1, 49)).is_equal(49)
	assert_int(BorderShape.held_slot_count(49.0 * sp + (hold - 0.05) * sp, 49)).is_equal(49)
	assert_int(BorderShape.held_slot_count(48.0 * sp - 0.1, 49)).is_equal(49)
	# Past the band it moves, up and down.
	assert_int(BorderShape.held_slot_count(49.0 * sp + (hold + 0.05) * sp, 49)).is_equal(50)
	assert_int(BorderShape.held_slot_count(48.0 * sp - (hold + 0.05) * sp, 49)).is_equal(48)
	# And the spacing stays under the gap threshold at the edge of the band.
	assert_float(49.0 * sp * (1.0 + hold / 49.0) / 49.0).is_less(Config.BORDER_MAX_GAP)
