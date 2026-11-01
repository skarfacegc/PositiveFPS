class_name BeaconPlacement
extends RefCounted

# Round 19: E. Moved out of topdown_main.gd in round 22.


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
	if player.is_dim or player.spirit < Config.BEACON_SPIRIT_COST:
		main.intro.notice(Intro.Prompt.BEACON_SPIRIT)
		return false
	var plan := main.border.plan_stretch(player.aim_point())
	if plan["refused"]:
		main.intro.notice(Intro.Prompt.BEACON_BLOCKED, str(plan["reason"]))
		return false
	player.lose_spirit(Config.BEACON_SPIRIT_COST)
	main.border.place_beacon(player.aim_point())
	main.spirit_meter.moment(-Config.BEACON_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	main.feedback.pulse_player(SpiritMeter.Moment.SPEND)
	main.beacon_placed.emit(main.border.beacon_pos(), Config.BEACON_SPIRIT_COST, player.spirit)
	return true
