extends GdUnitTestSuite

# Round 13b, the layered introduction through the night: dusk is only rescuing and growing (nobody sinks to dimmed, no
# mood is active); dimmed people emerge after the calm opening; moods switch on one type at a time; each one-time prompt
# shows once, one at a time, queued. The flag Config.intro_on() is off in automated tests (so older scenario tests
# keep their behaviour); these tests switch it on, and one checks that off really is the old behaviour.


func before_test() -> void:
	Config.intro_override = 1


func after_test() -> void:
	Config.intro_override = -1


# The level with everyone parked away and the player at the origin (lock-on targeting: nothing fires by itself).
func _start(progress: float = 0.0) -> Dictionary:
	var runner: GdUnitSceneRunner = await TopDownTestUtil.level_runner(self)
	await runner.simulate_frames(10)
	var td: TopDownMain = runner.scene()
	TopDownTestUtil.send_everyone_away(td)
	td.player.global_position = Vector3.ZERO
	td.player.targeting_mode = Config.TargetingMode.LOCK_ON
	td.night.elapsed = Config.NIGHT_LENGTH * progress
	return {"runner": runner, "td": td}


func _mooded(td: TopDownMain, index: int, spot: Vector3, mood: int) -> Person:
	var p: Person = td.people[index]
	TopDownTestUtil.place(p, spot, 0, 0.2)
	p.mood = mood
	return p


# Rescues `count` people on a ring around the origin and lets the border settle.
func _border(td: TopDownMain, runner: GdUnitSceneRunner, count: int, r: float) -> void:
	for i: int in range(count):
		var a := TAU * float(i) / float(count)
		var p: Person = td.people[i]
		TopDownTestUtil.place(p, Vector3(cos(a) * r, 0.0, sin(a) * r), p.affinity, 0.0)
		p.receive_joy(p.affinity, Config.JOY_MAX, 0.0)
	await runner.simulate_frames(600)


# --- Dusk, then dimmed people, then moods ---------------------------------------------------------------------------


func test_dusk_has_no_dimmed_people_and_no_active_moods() -> void:
	var s: Dictionary = await _start(0.1)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_bool(td.intro.dimmed_allowed()).is_false()
	var deep := td.people[0]
	TopDownTestUtil.place(deep, Vector3(0, 0, -8), 0, 0.95)  # would be dimmed
	var guarded := _mooded(td, 1, Vector3(-4, 0, -8), Person.Mood.GUARDED)
	var skittish := _mooded(td, 2, Vector3(4, 0, -8), Person.Mood.SKITTISH)
	var glum := _mooded(td, 3, Vector3(8, 0, -8), Person.Mood.GLUM)
	await runner.simulate_frames(30)
	# They wait as gloomy: not dimmed, not spreading, not reaching for the player.
	assert_int(Config.gloom_level(deep.gloom)).is_equal(1)
	assert_bool(GloomSim.is_dark(deep)).is_false()
	for p: Person in [guarded, skittish, glum]:
		assert_int(p.active_mood()).is_equal(Person.Mood.NONE)
	assert_int(td.feedback.icons.size()).is_equal(0)
	# Shots from behind land on a guarded person at dusk: their mood is dormant.
	guarded.receive_joy(0, 10.0, 0.0, guarded.global_position + Vector3(0, 0, -5))
	assert_float(guarded.joy).is_greater(0.0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_dimmed_people_emerge_after_the_calm_opening_and_some_sink_with_a_puff() -> void:
	var s: Dictionary = await _start(0.1)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var deep := td.people[0]
	TopDownTestUtil.place(deep, Vector3(0, 0, -8), 0, 0.95)
	var sank: Array[int] = []
	deep.stage_changed.connect(func(_from: int, to: int) -> void: sank.append(to))
	# (Waiting as gloomy may still be a stage change to 1 for a moment; only a sink to dimmed (2) matters.)
	await runner.simulate_frames(20)
	assert_int(Config.gloom_level(deep.gloom)).is_equal(1)
	assert_bool(sank.has(2)).is_false()
	td.night.elapsed = Config.NIGHT_LENGTH * (Config.NIGHT_CALM_FRACTION + 0.02)
	assert_bool(td.intro.dimmed_allowed()).is_true()
	await runner.simulate_frames(240)
	assert_int(Config.gloom_level(deep.gloom)).is_equal(2)
	assert_bool(GloomSim.is_dark(deep)).is_true()
	assert_array(sank).contains([2])
	await TopDownTestUtil.leave_loaded_scene(td)


func test_moods_switch_on_one_type_at_a_time_at_their_fractions() -> void:
	var s: Dictionary = await _start(0.3)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var guarded := _mooded(td, 0, Vector3(-4, 0, -8), Person.Mood.GUARDED)
	var skittish := _mooded(td, 1, Vector3(0, 0, -8), Person.Mood.SKITTISH)
	var glum := _mooded(td, 2, Vector3(4, 0, -8), Person.Mood.GLUM)
	await runner.simulate_frames(3)
	assert_array([guarded.active_mood(), skittish.active_mood(), glum.active_mood()]).is_equal([0, 0, 0])
	td.night.elapsed = Config.NIGHT_LENGTH * (Config.MOOD_INTRO_FRACTIONS[Person.Mood.GUARDED] + 0.01)
	await runner.simulate_frames(3)
	assert_array([guarded.active_mood(), skittish.active_mood(), glum.active_mood()]).is_equal(
		[Person.Mood.GUARDED, 0, 0]
	)
	td.night.elapsed = Config.NIGHT_LENGTH * (Config.MOOD_INTRO_FRACTIONS[Person.Mood.SKITTISH] + 0.01)
	await runner.simulate_frames(3)
	assert_array([guarded.active_mood(), skittish.active_mood(), glum.active_mood()]).is_equal(
		[Person.Mood.GUARDED, Person.Mood.SKITTISH, 0]
	)
	td.night.elapsed = Config.NIGHT_LENGTH * (Config.MOOD_INTRO_FRACTIONS[Person.Mood.GLUM] + 0.01)
	await runner.simulate_frames(3)
	assert_array([guarded.active_mood(), skittish.active_mood(), glum.active_mood()]).is_equal(
		[Person.Mood.GUARDED, Person.Mood.SKITTISH, Person.Mood.GLUM]
	)
	await TopDownTestUtil.leave_loaded_scene(td)


# --- One-time prompts -----------------------------------------------------------------------------------------------


func test_the_first_gap_shows_one_prompt_near_it_and_never_again() -> void:
	var s: Dictionary = await _start(0.5)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _border(td, runner, 16, 6.0)
	assert_int(td.border.gap_count()).is_equal(0)
	assert_int(td.intro.current).is_equal(-1)
	var m: Person = td.border.members[3]
	m.joy = m.joy_needed() * 0.6
	await runner.simulate_frames(30)
	assert_int(td.border.gap_count()).is_greater(0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.GAP)
	assert_bool(td.intro.anchor != Vector3.INF).is_true()
	assert_str(td.prompts.text).contains("A gap!")
	assert_int(td.prompts.icon).is_equal(MoodIcons.Kind.BANG)
	assert_float(td.prompts.alpha).is_greater(0.0)
	# It fades in, holds, and fades out.
	await runner.simulate_frames(90)
	assert_float(td.prompts.alpha).is_equal(1.0)
	await runner.simulate_frames(int(Config.PROMPT_SECONDS * 60.0))
	assert_int(td.intro.current).is_equal(-1)
	assert_float(td.prompts.alpha).is_equal(0.0)
	# Recover, falter again: no second prompt.
	m.joy = m.joy_needed()
	await runner.simulate_frames(30)
	m.joy = m.joy_needed() * 0.6
	await runner.simulate_frames(60)
	assert_int(td.border.gap_count()).is_greater(0)
	assert_int(td.intro.current).is_equal(-1)
	assert_int(td.intro.queue.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_no_gap_prompt_before_dimmed_people_emerge() -> void:
	var s: Dictionary = await _start(0.1)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	await _border(td, runner, 16, 6.0)
	td.night.elapsed = Config.NIGHT_LENGTH * 0.1
	var m: Person = td.border.members[3]
	m.joy = m.joy_needed() * 0.6
	await runner.simulate_frames(60)
	assert_int(td.border.gap_count()).is_greater(0)
	assert_int(td.intro.current).is_equal(-1)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_a_mood_prompt_shows_the_first_time_that_mood_is_seen() -> void:
	var s: Dictionary = await _start(0.4)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_mooded(td, 0, Vector3(0, 0, -7), Person.Mood.GUARDED)
	await runner.simulate_frames(30)
	assert_int(td.intro.current).is_equal(Intro.Prompt.GUARDED)
	assert_str(td.prompts.text).contains("reach them from the front")
	assert_int(td.prompts.icon).is_equal(MoodIcons.Kind.SHIELD)
	# A skittish person is still dormant at 0.4, so only the guarded prompt exists.
	_mooded(td, 1, Vector3(4, 0, -7), Person.Mood.SKITTISH)
	await runner.simulate_frames(30)
	assert_int(td.intro.queue.size()).is_equal(0)
	td.night.elapsed = Config.NIGHT_LENGTH * 0.52
	await runner.simulate_frames(30)
	# It is queued behind the guarded prompt, which is still showing: one at a time.
	assert_int(td.intro.current).is_equal(Intro.Prompt.GUARDED)
	assert_array(td.intro.queue).is_equal([Intro.Prompt.SKITTISH])
	await runner.simulate_frames(int(Config.PROMPT_SECONDS * 60.0))
	assert_int(td.intro.current).is_equal(Intro.Prompt.SKITTISH)
	assert_str(td.prompts.text).contains("walk, don't run")
	assert_int(td.prompts.icon).is_equal(MoodIcons.Kind.FEET)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_glum_and_sheltered_prompts_have_their_icons() -> void:
	var s: Dictionary = await _start(0.7)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	_mooded(td, 0, Vector3(-4, 0, -8), Person.Mood.GLUM)
	await runner.simulate_frames(30)
	assert_int(td.intro.current).is_equal(Intro.Prompt.GLUM)
	assert_int(td.prompts.icon).is_equal(MoodIcons.Kind.CLOUD)
	assert_str(td.prompts.text).contains("when they look up")
	var wistful := _mooded(td, 1, Vector3(6, 0, -8), Person.Mood.NONE)
	TopDownTestUtil.place(td.people[2], Vector3(6.8, 0, -8), 1, 0.95)
	await runner.simulate_frames(12)
	assert_bool(wistful.sheltered).is_true()
	# Round 14: the dimmed person in view also queues the dimmed-help prompt, ahead of the sheltered one.
	assert_array(td.intro.queue).is_equal([Intro.Prompt.DIM_HELP, Intro.Prompt.SHELTERED])
	await runner.simulate_frames(int(Config.PROMPT_SECONDS * 60.0 * 2.0))
	assert_int(td.intro.current).is_equal(Intro.Prompt.SHELTERED)
	assert_int(td.prompts.icon).is_equal(MoodIcons.Kind.UMBRELLA)
	# Round 15: the prompt says the umbrella lets a little joy through and breaks after a few hits (it used to say to
	# draw the dimmed one away).
	assert_str(td.prompts.text).contains("a little joy gets through")
	await TopDownTestUtil.leave_loaded_scene(td)


func test_the_first_blocked_joy_asks_for_its_prompt_even_off_screen() -> void:
	var s: Dictionary = await _start(0.4)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	var guarded := _mooded(td, 0, TopDownTestUtil.FAR, Person.Mood.GUARDED)
	guarded.rotation.y = 0.0
	await runner.simulate_frames(3)
	assert_int(td.intro.current).is_equal(-1)
	# From the origin (south-west of them) a person facing north has joy arriving from behind.
	guarded.receive_joy(0, 10.0, 0.0, Vector3.ZERO)
	assert_int(guarded.glance_count).is_greater(0)
	assert_int(td.intro.current).is_equal(Intro.Prompt.GUARDED)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_spirit_low_and_dim_prompts_show_once() -> void:
	var s: Dictionary = await _start(0.1)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	td.player.spirit = Config.BURST_SPIRIT_COST - 5.0
	await runner.simulate_frames(30)
	assert_int(td.intro.current).is_equal(Intro.Prompt.SPIRIT_LOW)
	assert_str(td.prompts.text).contains("Spirit low")
	td.player.lose_spirit(100.0)
	await runner.simulate_frames(30)
	assert_bool(td.player.is_dim).is_true()
	assert_array(td.intro.queue).is_equal([Intro.Prompt.DIM])
	await runner.simulate_frames(int(Config.PROMPT_SECONDS * 60.0))
	assert_int(td.intro.current).is_equal(Intro.Prompt.DIM)
	assert_str(td.prompts.text).contains("rest inside your border")
	await runner.simulate_frames(int(Config.PROMPT_SECONDS * 60.0))
	assert_int(td.intro.current).is_equal(-1)
	# Back up and down again: nothing new.
	td.player.add_spirit(100.0)
	await runner.simulate_frames(30)
	td.player.lose_spirit(100.0)
	await runner.simulate_frames(60)
	assert_int(td.intro.current).is_equal(-1)
	assert_int(td.intro.queue.size()).is_equal(0)
	await TopDownTestUtil.leave_loaded_scene(td)


func test_prompts_queue_one_at_a_time_and_each_shows_once() -> void:
	var intro := Intro.new(NightCycle.new(), true)
	assert_bool(intro.request(Intro.Prompt.GUARDED)).is_true()
	assert_bool(intro.request(Intro.Prompt.SKITTISH)).is_true()
	assert_bool(intro.request(Intro.Prompt.GLUM)).is_true()
	assert_bool(intro.request(Intro.Prompt.GUARDED)).is_false()  # already shown
	assert_int(intro.current).is_equal(Intro.Prompt.GUARDED)
	assert_array(intro.queue).is_equal([Intro.Prompt.SKITTISH, Intro.Prompt.GLUM])
	for expected: int in [Intro.Prompt.SKITTISH, Intro.Prompt.GLUM]:
		for i: int in range(int(Config.PROMPT_SECONDS * 10.0) + 2):
			intro.update(0.1)
		assert_int(intro.current).is_equal(expected)
	for i: int in range(int(Config.PROMPT_SECONDS * 10.0) + 2):
		intro.update(0.1)
	assert_int(intro.current).is_equal(-1)
	assert_bool(intro.request(Intro.Prompt.GLUM)).is_false()  # still once per level
	# Every prompt has a line.
	for id: int in Intro.Prompt.values():
		assert_str(Intro.text_for(id)).is_not_empty()


# --- Off keeps the old behaviour ----------------------------------------------------------------------------------


func test_with_the_intro_off_everything_is_available_at_once_and_no_prompt_shows() -> void:
	Config.intro_override = 0
	var s: Dictionary = await _start(0.0)
	var runner: GdUnitSceneRunner = s["runner"]
	var td: TopDownMain = s["td"]
	assert_bool(td.intro.enabled).is_false()
	assert_bool(td.intro.dimmed_allowed()).is_true()
	var deep := td.people[0]
	TopDownTestUtil.place(deep, Vector3(0, 0, -8), 0, 0.95)
	var guarded := _mooded(td, 1, Vector3(-4, 0, -8), Person.Mood.GUARDED)
	td.player.spirit = 5.0
	await runner.simulate_frames(40)
	assert_bool(GloomSim.is_dark(deep)).is_true()
	assert_int(guarded.active_mood()).is_equal(Person.Mood.GUARDED)
	assert_int(td.intro.current).is_equal(-1)
	assert_bool(td.intro.request(Intro.Prompt.GAP)).is_false()
	await TopDownTestUtil.leave_loaded_scene(td)
