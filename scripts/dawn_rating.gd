class_name DawnRating
extends RefCounted

# Round 19: the level is won by reaching dawn, and the end screen rates how well it was held: 1 to 3 "dawn lights", from
# people rescued, ground held and landmarks held (thresholds in Config "Round 19: dawn rating").
#   1 light: you reached dawn.
#   2 lights: at least two of the three goals at their lower marks (people, ground, one landmark).
#   3 lights: most people rescued AND at least DAWN_LANDMARKS_HIGH landmarks held.
# Pure rules: `rate()` takes the numbers and returns the lights and the lines that say why.


# `rescued` of `total` people, `ground` the beautified share of the plaza (0..1) and `landmarks` held at dawn.
# Returns {"lights": 1..3, "people": share, "ground": share, "landmarks": count, "lines": Array[String]}.
static func rate(rescued: int, total: int, ground: float, landmarks: int) -> Dictionary:
	var people := float(rescued) / float(maxi(total, 1))
	var goals := 0
	if people >= Config.DAWN_PEOPLE_LOW:
		goals += 1
	if ground >= Config.DAWN_GROUND_LOW:
		goals += 1
	if landmarks >= Config.DAWN_LANDMARKS_LOW:
		goals += 1
	var lights := 1
	if goals >= 2:
		lights = 2
	if people >= Config.DAWN_PEOPLE_HIGH and landmarks >= Config.DAWN_LANDMARKS_HIGH:
		lights = 3
	var lines: Array[String] = [
		"%d of %d people rescued (%d%%)" % [rescued, total, roundi(people * 100.0)],
		"%d%% of the plaza held" % roundi(ground * 100.0),
		"%d of %d landmarks held" % [landmarks, Config.LANDMARK_NAMES.size()],
	]
	return {"lights": lights, "people": people, "ground": ground, "landmarks": landmarks, "lines": lines}


# The lights drawn as text: "[*][*][ ]" for two.
static func lights_text(lights: int) -> String:
	var out := ""
	for i: int in range(3):
		out += "[*]" if i < lights else "[ ]"
	return out


# What the next light needs, for the end screen ("" at three lights).
static func hint_for(lights: int) -> String:
	if lights >= 3:
		return ""
	if lights == 2:
		return (
			"For three: %d%% of the people rescued and %d landmarks held at dawn"
			% [roundi(Config.DAWN_PEOPLE_HIGH * 100.0), Config.DAWN_LANDMARKS_HIGH]
		)
	return (
		"For two, meet two of: %d%% rescued, %d%% of the plaza held, %d landmark held"
		% [roundi(Config.DAWN_PEOPLE_LOW * 100.0), roundi(Config.DAWN_GROUND_LOW * 100.0), Config.DAWN_LANDMARKS_LOW]
	)


# The lines on the end screen (moved from TopDownMain in round 21): the dawn lights (at dawn) with the reasons, then the
# buildings beautified.
static func detail_text(main: TopDownMain) -> String:
	var r: Dictionary = main.rating if not main.rating.is_empty() else main._current_rating()
	var lights: int = r["lights"]
	var lines: Array[String] = []
	if not main.rating.is_empty():
		lines.append("Dawn lights: " + lights_text(lights))
	lines.append_array(r["lines"] as Array[String])
	lines.append(
		"%d of %d buildings beautified" % [main.border.beautified_building_count(), main.border.buildings.size()]
	)
	if not main.rating.is_empty():
		lines.append(hint_for(lights))
	return "\n".join(lines)
