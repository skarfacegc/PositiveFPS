class_name PromptBar
extends Control

# Round 13b: the one-time prompt of the layered introduction (see intro.gd). A small rounded bar with an icon and one
# short line, bottom centre above the spirit meter (or near a point in the world, such as the first gap). It fades in
# and out, and shows only one prompt at a time. Screen-space UI, so it appears in both looks.

const FONT_SIZE := 20
const HEIGHT := 40.0
const BOTTOM_GAP := 150.0

# The text and icon on show, how visible they are (0 to 1) and which prompt (-1 for none).
var text: String = ""
var icon: int = MoodIcons.Kind.NONE
var alpha: float = 0.0
var prompt_id: int = -1
var intro: Intro
var main: TopDownMain
var _rect := Rect2()
var _showing: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# Reads the intro's current prompt and redraws. `screen` is the window rectangle.
func tick(screen: Rect2) -> void:
	if intro == null or intro.current < 0:
		prompt_id = -1
		alpha = 0.0
		text = ""
		if _showing:
			_showing = false
			queue_redraw()
		return
	_showing = true
	prompt_id = intro.current
	text = Intro.text_for(prompt_id)
	icon = Intro.icon_for(prompt_id)
	var fade := Config.PROMPT_FADE_SECONDS
	var elapsed := Config.PROMPT_SECONDS - intro.time_left
	alpha = clampf(minf(elapsed / fade, intro.time_left / fade), 0.0, 1.0)
	_rect = _place(screen)
	queue_redraw()


# The bar's rectangle: near the prompt's world point when it is on screen, otherwise bottom centre.
func _place(screen: Rect2) -> Rect2:
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + 90.0
	var size := Vector2(w, HEIGHT)
	var pos := Vector2(screen.size.x * 0.5 - w * 0.5, screen.size.y - BOTTOM_GAP)
	if main != null and intro.anchor != Vector3.INF:
		var sp := main.world_to_screen(intro.anchor)
		if screen.grow(-30.0).has_point(sp):
			pos = Vector2(sp.x - w * 0.5, sp.y - 90.0)
			pos.x = clampf(pos.x, 10.0, screen.size.x - w - 10.0)
			pos.y = clampf(pos.y, 80.0, screen.size.y - 200.0)
	return Rect2(pos, size)


func _draw() -> void:
	if alpha <= 0.0 or text == "":
		return
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.78 * alpha)
	style.set_corner_radius_all(int(HEIGHT * 0.5))
	style.border_color = Color(1.0, 0.88, 0.5, 0.55 * alpha)
	style.set_border_width_all(2)
	draw_style_box(style, _rect)
	var mid_y := _rect.position.y + HEIGHT * 0.5
	var text_x := _rect.position.x + 24.0
	if icon != MoodIcons.Kind.NONE:
		var col := MoodIcons.colour_for(icon)
		col.a = alpha
		MoodIcons.draw(self, icon, Vector2(_rect.position.x + 28.0, mid_y), 24.0, col)
		text_x = _rect.position.x + 56.0
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(text_x, mid_y + FONT_SIZE * 0.35),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		Color(1.0, 0.97, 0.88, alpha)
	)
