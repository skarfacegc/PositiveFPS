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


func member_colour() -> Color:
	return Color.WHITE


func dark_colour() -> Color:
	return Color.WHITE


func landmark_colour() -> Color:
	return Color.WHITE


func player_colour() -> Color:
	return Color.WHITE


func view_colour() -> Color:
	return Color.WHITE


# The outline round markers. Alpha 0 means none.
func halo_colour() -> Color:
	return Color(0, 0, 0, 0)


# Draws the frame round the picture, over it, on `ctl` (a square Control; the circle fills it).
func draw_frame(_ctl: Control) -> void:
	pass
