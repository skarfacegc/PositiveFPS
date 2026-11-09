class_name EdgeDim
extends RefCounted

# Round 25 (edge cleanup): dimmed people who are still outside the border are drawn at lower contrast, so the
# members and the ribbon stand out from the crowd pressing on them. Only the look changes: each person's look has
# `outside_fade` (0 normal, 1 fully faded, shown as EDGE_OUT_FADE of the way toward the ground). BurstCue calls
# `update` every BORDER_WARN_INTERVAL.


# True when `p` is a dimmed person outside an active border (the people who are faded).
static func is_faded(border: Border, p: Person) -> bool:
	if p.is_rescued or not border.active or not GloomSim.is_dimmed(p):
		return false
	return not BorderShape.is_inside(border.polygon, Vector2(p.position.x, p.position.z))


# Moves each person's fade toward its target over EDGE_OUT_FADE_SECONDS (`delta` is the time since the last update).
static func update(border: Border, people: Array[Person], delta: float) -> void:
	var step := delta / maxf(BorderConfig.EDGE_OUT_FADE_SECONDS, 0.01)
	for p: Person in people:
		var look: PersonLook = p.look
		if look == null:
			continue
		var target := 1.0 if is_faded(border, p) else 0.0
		look.outside_fade = move_toward(look.outside_fade, target, step)


# The body colour of a person at `fade`: `col` moved toward the ground tone by EDGE_OUT_FADE x fade.
static func faded(col: Color, fade: float) -> Color:
	return col.lerp(BorderConfig.EDGE_OUT_GROUND, BorderConfig.EDGE_OUT_FADE * clampf(fade, 0.0, 1.0))
