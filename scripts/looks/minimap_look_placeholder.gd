class_name MinimapLookPlaceholder
extends MinimapLook

# The placeholder minimap: the game's current palette and a plain cream frame.


func ground_colour(ground: PaintedGround, w: Vector2, _px: int, _py: int) -> Color:
	if ground == null:
		return Config.TD_MINIMAP_GREY_COLOUR
	return ground.paint_colour_at(Vector3(w.x, 0.0, w.y))


func building_colour(warm: bool) -> Color:
	return Config.TD_MINIMAP_WARM_COLOUR if warm else Config.TD_MINIMAP_GREY_COLOUR


func line_colour(is_gap: bool) -> Color:
	return Config.BORDER_GAP_COLOUR if is_gap else Config.TD_MINIMAP_LINE_COLOUR


func member_colour() -> Color:
	return Config.TD_MINIMAP_MEMBER_COLOUR


func dark_colour() -> Color:
	return Config.TD_MINIMAP_DARK_COLOUR


func landmark_colour() -> Color:
	return Config.TD_MINIMAP_LANDMARK_COLOUR


func player_colour() -> Color:
	return Config.TD_MINIMAP_PLAYER_COLOUR


func view_colour() -> Color:
	return Config.TD_MINIMAP_VIEW_COLOUR


func draw_frame(ctl: Control) -> void:
	ctl.draw_arc(ctl.size * 0.5, ctl.size.x * 0.5 - 2.0, 0.0, TAU, 96, Config.TD_MINIMAP_FRAME_COLOUR, 4.0, true)
