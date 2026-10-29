class_name MinimapLook
extends RefCounted

# The look of the minimap: the palette of its picture and the frame round it. The data model and the picture itself
# stay in minimap.gd; this decides the colours. A subclass overrides the colour functions, draw_frame and is_styled.


# True for the styled look.
func is_styled() -> bool:
	return false


# The colour of the ground at world point `w` (pixel `px`, `py` in the picture, for a texture pattern).
func ground_colour(_ground: PaintedGround, _w: Vector2, _px: int, _py: int) -> Color:
	return Color.WHITE


func building_colour(_warm: bool) -> Color:
	return Color.WHITE


func line_colour(_is_gap: bool) -> Color:
	return Color.WHITE


# Round 16: the colour of a stretch of the loop sealed by the map edge. The placeholder draws it like any intact
# stretch.
func seal_colour() -> Color:
	return line_colour(false)


# How many picture pixels thick a sealed stretch is drawn (1 = like the rest of the line).
func seal_width() -> int:
	return 1


func member_colour() -> Color:
	return Color.WHITE


func dimmed_colour() -> Color:
	return Color.WHITE


func landmark_colour() -> Color:
	return Color.WHITE


func player_colour() -> Color:
	return Color.WHITE


func view_colour() -> Color:
	return Color.WHITE


# The outline round a marker of this kind ("member", "dimmed" or "player"). Alpha 0 means none.
func halo_colour(_kind: String) -> Color:
	return Color(0, 0, 0, 0)


# Draws behind the picture (a backing disc), on `ctl`.
func draw_back(_ctl: Control) -> void:
	pass


# Draws the frame round the picture, over it, on `ctl` (a square Control; the circle fills it).
func draw_frame(_ctl: Control) -> void:
	pass
