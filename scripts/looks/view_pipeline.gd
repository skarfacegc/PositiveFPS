class_name ViewPipeline
extends Node

# The camera and post-process pipeline. In the placeholder look the 3D world is drawn straight into the window by the
# game camera. The styled look draws it into a small pixel-sized SubViewport instead (see ViewPipelineStyled in the
# styled commit). This base class is the placeholder: nothing is changed, and window and view coordinates are the same.


# Switches the pipeline for the current look (see Looks.mode). Called by TopDownMain at the start and on F4.
func apply(_main: TopDownMain) -> void:
	pass


# A window position as the camera sees it (the camera's own view size). Identity here.
func window_to_view(window_pos: Vector2) -> Vector2:
	return window_pos


# A camera view position as a window position (the opposite of window_to_view).
func view_to_window(view_pos: Vector2) -> Vector2:
	return view_pos


# Window pixels per camera view pixel (x, y). One in the placeholder look.
func view_scale() -> Vector2:
	return Vector2.ONE
