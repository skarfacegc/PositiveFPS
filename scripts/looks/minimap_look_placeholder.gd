class_name MinimapLookPlaceholder
extends MinimapLook

# The placeholder minimap: the game's current palette and a plain cream frame.


func ground_colour(ground: PaintedGround, w: Vector2, _px: int, _py: int) -> Color:
	if ground == null:
		return HudConfig.TD_MINIMAP_GREY_COLOUR
	return ground.paint_colour_at(Vector3(w.x, 0.0, w.y))


func building_colour(warm: bool) -> Color:
	return HudConfig.TD_MINIMAP_WARM_COLOUR if warm else HudConfig.TD_MINIMAP_GREY_COLOUR


func line_colour(is_gap: bool) -> Color:
	return BorderConfig.BORDER_GAP_COLOUR if is_gap else HudConfig.TD_MINIMAP_LINE_COLOUR


# Checkpoint 5: a wobbling person (`wobble_pulse` 0 to 1) is a warm amber blip whose alpha swells with its pulse.
func member_colour(wobble_pulse: float = -1.0) -> Color:
	if wobble_pulse < 0.0:
		return HudConfig.TD_MINIMAP_MEMBER_COLOUR
	var col := HudConfig.WOBBLE_BLIP_COLOUR
	col.a = lerpf(0.6, 1.0, wobble_pulse)
	return col


func dimmed_colour() -> Color:
	return HudConfig.TD_MINIMAP_DIMMED_COLOUR


func landmark_colour() -> Color:
	return HudConfig.TD_MINIMAP_LANDMARK_COLOUR


# Round 20: a held landmark is the gold star with its ring; one not held is a grey star with no ring.
func landmark_state_colour(held: bool) -> Color:
	return landmark_colour() if held else HudConfig.TD_MINIMAP_LANDMARK_UNHELD_COLOUR


# Round 22: an unheld landmark is a larger star with a pale ring round it, so it stands out from the grey ground.
func landmark_star_grow(held: bool) -> float:
	return 1.0 if held else HudConfig.TD_MINIMAP_LANDMARK_UNHELD_GROW


func unheld_landmark_ring_colour() -> Color:
	return HudConfig.TD_MINIMAP_LANDMARK_UNHELD_RING_COLOUR


func cloud_colour() -> Color:
	return Color(
		HudConfig.MINIMAP_CLOUD_COLOUR.r, HudConfig.MINIMAP_CLOUD_COLOUR.g, HudConfig.MINIMAP_CLOUD_COLOUR.b, 1.0
	)


func player_colour() -> Color:
	return HudConfig.TD_MINIMAP_PLAYER_COLOUR


func view_colour() -> Color:
	return HudConfig.TD_MINIMAP_VIEW_COLOUR


func draw_frame(ctl: Control) -> void:
	ctl.draw_arc(ctl.size * 0.5, ctl.size.x * 0.5 - 2.0, 0.0, TAU, 96, HudConfig.TD_MINIMAP_FRAME_COLOUR, 4.0, true)
