class_name HudSafeArea
extends RefCounted

# Checkpoint 6: the rectangle the edge pointers stay in, shared by the wobble pointers (WobbleAlert), the gap arrows
# (GapArrows) and the landmark pointers (LandmarkPointers) so none of them sits over a HUD panel, in either look. It
# is the window less the HUD panels that are shown (Hud.layout_controls, which lists the styled panels while the
# styled look is on and the Labels while the placeholder look is), the minimap and the spirit cue beside the spirit
# meter.


# True for a window big enough to lay the HUD out in (not the headless 64 x 64 window).
static func usable(screen: Vector2) -> bool:
	return screen.x >= 400.0 and screen.y >= 300.0


# The HUD rectangles a pointer must keep clear of: the HUD panels that are shown (Hud.layout_controls), the minimap, and
# the spirit cue (GapPatch's panel and label, which the HUD does not list). A control at zero alpha (the placeholder
# alert line between alerts) does not count.
static func avoid_rects(hud: Hud, minimap: Control, main: TopDownMain = null) -> Array[Rect2]:
	var out: Array[Rect2] = []
	var controls: Array[Control] = hud.layout_controls()
	if minimap != null:
		controls.append(minimap)
	if main != null and main.gap_patch != null:
		if main.gap_patch.cue_panel != null:
			controls.append(main.gap_patch.cue_panel)
		if main.gap_patch.patch_label != null:
			controls.append(main.gap_patch.patch_label)
	for c: Control in controls:
		if c.is_visible_in_tree() and c.modulate.a > 0.0:
			out.append(c.get_global_rect())
	return out


# The window of size `screen` inset by WOBBLE_ALERT_SAFE_INSET, cut at the top by every rectangle in `avoid` whose
# centre is in the top half of the screen and at the bottom by every one in the bottom half (each with
# WOBBLE_ALERT_PANEL_GAP to spare).
static func safe_rect(screen: Vector2, avoid: Array[Rect2]) -> Rect2:
	var inset := Config.WOBBLE_ALERT_SAFE_INSET
	var top := inset
	var bottom := screen.y - inset
	var gap := Config.WOBBLE_ALERT_PANEL_GAP
	for r: Rect2 in avoid:
		if r.get_center().y < screen.y * 0.5:
			top = maxf(top, r.end.y + gap)
		else:
			bottom = minf(bottom, r.position.y - gap)
	return Rect2(inset, top, screen.x - inset * 2.0, bottom - top)


# The safe rectangle of `main`'s level now, or an empty Rect2 when the window is too small for the HUD or no room is
# left.
static func current(main: TopDownMain, screen: Vector2) -> Rect2:
	if not usable(screen) or main.hud == null:
		return Rect2()
	var safe := safe_rect(screen, avoid_rects(main.hud, main.minimap, main))
	if safe.size.x <= 0.0 or safe.size.y <= 0.0:
		return Rect2()
	return safe
