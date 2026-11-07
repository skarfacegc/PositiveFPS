extends GdUnitTestSuite

# Round 22 follow-up: the edges of the shaped zone's arithmetic that the playtest-shaped suites do not reach: a merged
# or dropped arm when a tip arrives, a stretch that is still walking back, the idle guards, the centre before the border
# forms with posts about, and the body-radius cache.

const PEOPLE := 24
const CENTRE := Vector3(-11.7, 0.0, -6.5)


func after_test() -> void:
	Config.intro_override = -1


# A level with a settled border of 24 people round CENTRE and nobody else about.
func _setup() -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.border.buildings.clear()
	var r := BorderCentre.circle_radius(PEOPLE)
	for i: int in range(PEOPLE):
		var a := TAU * float(i) / float(PEOPLE)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, CENTRE + Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(600)
	return {"runner": runner, "td": td}


# The tip lands `reach` from the border's centre toward angle `ang`, as if a stretch had just arrived there.
func _land(ctl: BorderCentre, reach: float, ang: float) -> void:
	var c := ctl.b.centre
	ctl.tip = Vector3(c.x + cos(ang) * reach, 0.0, c.z + sin(ang) * reach)
	ctl._radii_at_start = ctl._polygon_radii()
	ctl._arrive()


# Merged (one settled border, no frames run between the parts; each part sets the controller's state itself): covers
# "with no stretch the target is the tip and pulling in with no arms does nothing", "a stretch whose tip is still
# walking back has not ended yet", "a tip that lands near an arm updates it and the farther reach wins" and "one arm
# too many drops the shortest".
func test_the_controller_edges_idle_walking_back_merging_arms_and_one_arm_too_many() -> void:
	var s: Dictionary = await _setup()
	var td: TopDownMain = s["td"]
	var ctl: BorderCentre = td.border._centre_ctl
	# With no stretch the target is the tip and pulling in with no arms does nothing.
	assert_bool(ctl.has_beacon()).is_false()
	assert_vector(ctl.target()).is_equal(ctl.tip)
	assert_int(ctl.arms.size()).is_equal(0)
	var idle_version := ctl.arm_version
	ctl.pull_in(0.5, 5.0)
	assert_int(ctl.arms.size()).is_equal(0)
	assert_int(ctl.arm_version).is_equal(idle_version)
	# A stretch whose tip is still walking back has not ended yet.
	var c := td.border.centre
	ctl.beacon = c + Vector3(0.0, 0.0, 30.0)
	ctl.stretching = true
	var goal := c + Vector3(0.0, 0.0, 6.0)
	var plan := {"reason": "the people can only hold so much border", "have": 6.0}
	# The limit has pulled the goal back to what the zone has, but the tip is still far out: keep walking.
	ctl.tip = c + Vector3(0.0, 0.0, 14.0)
	assert_bool(ctl._fell_back(goal, plan)).is_false()
	assert_bool(ctl.stretching).is_true()
	assert_bool(ctl.has_beacon()).is_true()
	# Once the tip is back at the goal the stretch ends.
	ctl.tip = goal
	assert_bool(ctl._fell_back(goal, plan)).is_true()
	assert_bool(ctl.stretching).is_false()
	assert_bool(ctl.has_beacon()).is_false()
	# A tip that lands near an arm updates it and the farther reach wins.
	var body := maxf(td.border.body_radius, td.border._mean_radius())
	ctl.arms = [Vector2(0.0, body * 2.0)]
	var version := ctl.arm_version
	# A shorter tip within the merge angle leaves the longer arm as it was.
	_land(ctl, body * 1.5, Config.BEACON_ARM_MERGE * 0.5)
	assert_int(ctl.arms.size()).is_equal(1)
	assert_float(ctl.arms[0].y).is_equal_approx(body * 2.0, 0.001)
	assert_float(ctl.arms[0].x).is_equal_approx(0.0, 0.001)
	# A longer one takes the arm over, at its own angle.
	_land(ctl, body * 2.6, Config.BEACON_ARM_MERGE * 0.5)
	assert_int(ctl.arms.size()).is_equal(1)
	assert_float(ctl.arms[0].y).is_equal_approx(body * 2.6, 0.01)
	assert_float(ctl.arms[0].x).is_equal_approx(Config.BEACON_ARM_MERGE * 0.5, 0.01)
	assert_int(ctl.arm_version).is_greater(version)
	# One arm too many drops the shortest.
	var full: Array[Vector2] = []
	for i: int in range(Config.BEACON_MAX_ARMS):
		full.append(Vector2(float(i), body * (1.5 + 0.1 * float(i))))
	ctl.arms = full
	# Half a radian from the first two arms, so it merges with neither.
	_land(ctl, body * 2.8, 0.5)
	assert_int(ctl.arms.size()).is_equal(Config.BEACON_MAX_ARMS)
	var reaches: Array[float] = []
	for a: Vector2 in ctl.arms:
		reaches.append(a.y)
	# The shortest (1.5 x the body) is gone and the new tip is in.
	assert_float(reaches.min()).is_greater(body * 1.55)
	assert_float(reaches.max()).is_equal_approx(body * 2.8, 0.01)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_before_the_border_forms_a_post_pulls_the_centre_like_three_people() -> void:
	var border: Border = auto_free(Border.new())
	var ctl: BorderCentre = border._centre_ctl
	var p: Person = auto_free(Person.new())
	p.position = Vector3(0.0, 0.0, 0.0)
	var rescued: Array[Person] = [p]
	border._post_points = [Vector3(8.0, 0.0, -4.0)]
	ctl._form(rescued, 0.1)
	var worth := float(Config.BORDER_POST_WORTH)
	assert_float(border.centre.x).is_equal_approx(8.0 * worth / (1.0 + worth), 0.001)
	assert_float(border.centre.z).is_equal_approx(-4.0 * worth / (1.0 + worth), 0.001)


func test_the_body_radius_cache_empties_itself_before_it_grows_without_end() -> void:
	BorderCentre._body_cache.clear()
	var radius := 8.0
	var first := BorderCentre.body_for(radius, 30.0)
	for i: int in range(2100):
		BorderCentre.body_for(radius, 1.0 + float(i) * 0.1)
	assert_int(BorderCentre._body_cache.size()).is_less(2001)
	assert_int(BorderCentre._body_cache.size()).is_less(200)
	# The answer is the same whether it comes from the cache or is worked out again.
	assert_float(BorderCentre.body_for(radius, 30.0)).is_equal(first)
	assert_float(first).is_less_equal(radius)
	assert_float(first).is_greater_equal(radius * Config.BEACON_BODY_MIN)


# Checkpoint 5 follow-up: the preview no longer plans on every hover (only while E is held), so this guard needs its own
# test: arms that already use all of the loop's length leave no reach for another stretch.
func test_arms_that_already_use_the_whole_length_leave_no_reach_for_another() -> void:
	var border: Border = auto_free(Border.new())
	var ctl: BorderCentre = border._centre_ctl
	var radius := 8.0
	var long_arms: Array[Vector2] = []
	for i: int in range(Config.BEACON_MAX_ARMS):
		long_arms.append(Vector2(TAU * float(i) / float(Config.BEACON_MAX_ARMS), radius * 6.0))
	ctl.arms = long_arms
	assert_float(ctl.arm_cap(PI * 0.25, radius, radius * 3.0)).is_equal(0.0)
	# With no arms the same aim gets some reach.
	ctl.arms = []
	assert_float(ctl.arm_cap(PI * 0.25, radius, radius * 3.0)).is_greater(0.0)


func test_a_loop_that_fits_keeps_its_plain_body_radius_and_one_that_does_not_is_squeezed() -> void:
	var short_arm: Array[Vector2] = [Vector2(0.0, 4.0)]
	var fitted := 0
	for k: int in range(10, 200):
		var r := float(k) * 0.5
		var fits := (
			BorderCentre.profile_perimeter(BorderCentre.profile(r, short_arm, 0.0, PI)) <= BorderCentre.budget_of(r)
		)
		var body := BorderCentre.body_for_arms(r, short_arm, 0.0, PI)
		if fits:
			fitted += 1
			assert_float(body).is_equal(r)
		else:
			assert_float(body).is_less(r)
	# A circle is as long as the people can hold, so most radii fit (the rest differ only by rounding).
	assert_int(fitted).is_greater(10)
