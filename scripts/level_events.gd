class_name LevelEvents
extends RefCounted

# What the level does when something happens: a person is rescued, relapses or changes stage, joy is blocked or lands,
# the burst fires, a grab lands, the player goes dim, a landmark is claimed or lost, the border's stretch ends.
# Each handler updates the count, the HUD, the spirit meter or the feedback layer. TopDownMain builds it as `events`
# and connects the signals in the order the level is made.

var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


# Round 20: a claim or a loss is announced on the HUD.
func wire_landmarks(landmarks: Landmarks) -> void:
	for lm: Landmark in landmarks.items:
		lm.claimed.connect(on_landmark_claimed.bind(lm))
		lm.lost.connect(on_landmark_lost.bind(lm))


# The border's stretch ending early, and the zone pulling in, are noticed in the prompt bar.
func wire_border(border: Border) -> void:
	var main := _main
	border.stretch_ended.connect(
		func(why: String) -> void:
			main.intro.notice(Intro.Prompt.BEACON_FELL_BACK, BeaconConfig.BEACON_FELL_BACK_TEXT + ": " + why)
	)
	border.zone_pulling_in.connect(func() -> void: main.intro.notice(Intro.Prompt.ZONE_PULLED_IN))


# Round 12b: someone sank or lifted a stage. The minimap shows a brief blip where a person became dimmed.
func on_stage_changed(_from_level: int, to_level: int, p: Person) -> void:
	if to_level >= 2 and not p.is_rescued:
		_main.minimap.add_blip(Vector2(p.position.x, p.position.z))


# A rescued person (`p`) was made: the border takes them in. The count goes up.
func on_person_rescued(p: Person) -> void:
	var main := _main
	main.rescued_count += 1
	main.border.on_rescue(p)
	main.hud.set_rescued(main.rescued_count, Config.TD_PEOPLE_COUNT)
	main.player.add_spirit(SpiritConfig.SPIRIT_PER_RESCUE)
	main.spirit_meter.moment(SpiritConfig.SPIRIT_PER_RESCUE, SpiritMeter.Moment.GAIN)
	main.feedback.pulse_player(SpiritMeter.Moment.GAIN)


# A rescued person (`p`) relapsed: they step out of the border, and the count goes down.
func on_person_relapsed(p: Person) -> void:
	var main := _main
	main.rescued_count -= 1
	main.border.on_relapse(p)
	main.hud.set_rescued(main.rescued_count, Config.TD_PEOPLE_COUNT)
	main.hud.show_alert("Someone lost their joy!")


# Round 20: a landmark was claimed (its boost is on) or lost (its boost is off): a notice across the top.
func on_landmark_claimed(lm: Landmark) -> void:
	_main.hud.show_alert(lm.claim_text(), LandmarkConfig.LANDMARK_CLAIM_COLOUR)


func on_landmark_lost(lm: Landmark) -> void:
	_main.hud.show_alert(lm.loss_text(), LandmarkConfig.LANDMARK_LOSS_COLOUR, LandmarkConfig.LANDMARK_LOSS_SECONDS)


func on_joy_blocked(reason: int, p: Person) -> void:
	_main.feedback.on_blocked(p, reason)
	if reason == Person.Block.SHELTERED:
		_main.intro.request(Intro.Prompt.SHELTERED)
	elif p.active_mood() == Person.Mood.GUARDED:
		_main.intro.request(Intro.Prompt.GUARDED)


# Round 14: joy landed on a dimmed person: their progress ring shows, and the one-time dimmed prompt.
func on_joy_landed(p: Person) -> void:
	if not GloomSim.is_dimmed(p):
		return
	_main.feedback.on_dim_joy(p)
	_main.intro.request(Intro.Prompt.DIM_HELP)


func on_burst_fired(_at: Vector3) -> void:
	_main.spirit_meter.moment(-SpiritConfig.BURST_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	_main.feedback.pulse_player(SpiritMeter.Moment.SPEND)


func on_player_dim_changed(dim: bool) -> void:
	if dim:
		_main.hud.show_alert("You went dim! Get inside the border to recover")
	else:
		_main.hud.show_alert("Your spirit is back")


func on_grab_landed(_p: Person) -> void:
	_main.hud.show_alert("Grabbed! -%d spirit" % roundi(SpiritConfig.GRAB_SPIRIT_DRAIN))
	_main.spirit_meter.moment(-SpiritConfig.GRAB_SPIRIT_DRAIN, SpiritMeter.Moment.LOSS)
	_main.feedback.pulse_player(SpiritMeter.Moment.LOSS)
