class_name BorderWarning
extends RefCounted

# Round 22: where the border is about to break. A border member losing joy is under strain long before the gap opens
# (a member falters, and the gap opens, below MEMBER_FALTER_FRACTION of their joy needed). The warning grows from 0 at
# BORDER_WARN_START to 1 at that falter line, and a dimmed person pressing next to a member gives it a floor
# (BORDER_WARN_PRESS_URGENCY). The marks show where spirit is best spent (a patch or a burst).


# 0..1 for a rescued person's joy alone: 0 when healthy, 1 at the falter line.
static func joy_urgency(p: Person) -> float:
	if not p.is_rescued:
		return 0.0
	var frac := p.joy / maxf(p.joy_needed(), 0.001)
	var span := Config.BORDER_WARN_START - Config.MEMBER_FALTER_FRACTION
	return clampf((Config.BORDER_WARN_START - frac) / span, 0.0, 1.0)


# The strained spots right now: Array of {"person": Person, "pos": Vector3, "urgency": float}, strongest first not
# guaranteed. Members under a patch are safe and left out.
static func compute(border: Border, people: Array[Person]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not border.active:
		return out
	var pressing: Array[Person] = []
	for p: Person in people:
		if not p.is_rescued and GloomSim.is_dimmed(p):
			pressing.append(p)
	var range2 := Config.BORDER_WARN_PRESS_RANGE * Config.BORDER_WARN_PRESS_RANGE
	for m: Person in border.members:
		if m.patch_mult < 1.0:
			continue
		var u := joy_urgency(m)
		for d: Person in pressing:
			var off := Vector2(d.position.x - m.position.x, d.position.z - m.position.z)
			if off.length_squared() <= range2:
				u = maxf(u, Config.BORDER_WARN_PRESS_URGENCY)
				break
		if u > 0.0:
			out.append({"person": m, "pos": m.position, "urgency": u})
	return out


static func colour_for(urgency: float) -> Color:
	return Config.BORDER_WARN_COLOUR_LOW.lerp(Config.BORDER_WARN_COLOUR_HIGH, urgency)
