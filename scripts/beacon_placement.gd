class_name BeaconPlacement
extends RefCounted

# Round 19: E. Moved out of topdown_main.gd in round 22.
# Checkpoint 5 follow-up: hold to aim, release to place. Pressing E only shows the aim (ReachGuide.held); releasing
# it places the beacon exactly as a press did (try_place); right-click while held cancels with nothing spent.


# E pressed: the zone preview shows and follows the cursor until E is released.
static func press(main: TopDownMain) -> void:
	main.reach_guide.held = true


# E released: places the beacon at the cursor (the same refusals and costs as try_place). Does nothing unless E was
# held (a second release, or a release after a cancel, places nothing). Returns true when a beacon was placed.
static func release(main: TopDownMain) -> bool:
	if not main.reach_guide.held:
		return false
	main.reach_guide.held = false
	return try_place(main)


# Right-click while E is held, or the window losing focus (TopDownMain._notification): the aim ends, nothing is
# spent and the preview hides until E is pressed again.
static func cancel(main: TopDownMain) -> void:
	main.reach_guide.held = false


# Puts the spirit beacon at the cursor's ground point for BEACON_SPIRIT_COST spirit (the zone then stretches toward
# it). Refused (nothing changes, a short notice shows) without a border, without enough spirit, or when the stretch
# plan refuses. A new beacon replaces the old one and costs again. Returns true when it was placed.
static func try_place(main: TopDownMain) -> bool:
	var player := main.player
	if not main.running or not player.has_aim():
		return false
	if not main.border.formed:
		main.intro.notice(Intro.Prompt.BEACON_BORDER)
		return false
	if player.is_dim or player.spirit < BeaconConfig.BEACON_SPIRIT_COST:
		main.intro.notice(Intro.Prompt.BEACON_SPIRIT)
		return false
	var plan := main.border.plan_stretch(player.aim_point())
	if plan["refused"]:
		main.intro.notice(Intro.Prompt.BEACON_BLOCKED, str(plan["reason"]))
		return false
	player.lose_spirit(BeaconConfig.BEACON_SPIRIT_COST)
	main.border.place_beacon(player.aim_point())
	main.spirit_meter.moment(-BeaconConfig.BEACON_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	main.feedback.pulse_player(SpiritMeter.Moment.SPEND)
	main.beacon_placed.emit(main.border.beacon_pos(), BeaconConfig.BEACON_SPIRIT_COST, player.spirit)
	return true
