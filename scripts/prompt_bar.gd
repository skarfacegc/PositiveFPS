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
var big: bool = false  # Round 22: a refusal or fall-back notice: larger, coral-edged, near the middle of the screen.
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
	text = intro.current_text()
	big = intro.big
	icon = Intro.icon_for(prompt_id)
	var fade := Config.PROMPT_FADE_SECONDS
	var elapsed := intro.duration - intro.time_left
	alpha = clampf(minf(elapsed / fade, intro.time_left / fade), 0.0, 1.0)
	_rect = _place(screen)
	queue_redraw()


# The bar's rectangle: near the prompt's world point when it is on screen, otherwise bottom centre.
func _place(screen: Rect2) -> Rect2:
	var font := ThemeDB.fallback_font
	var fs := Config.NOTICE_FONT_SIZE if big else FONT_SIZE
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 90.0
	var size := Vector2(w, Config.NOTICE_HEIGHT if big else HEIGHT)
	var pos := Vector2(screen.size.x * 0.5 - w * 0.5, screen.size.y - BOTTOM_GAP)
	if big:
		pos.y = screen.size.y * 0.3
	elif main != null and intro.anchor != Vector3.INF:
		var sp := main.world_to_screen(intro.anchor)
		if screen.grow(-30.0).has_point(sp):
			pos = Vector2(sp.x - w * 0.5, sp.y - 90.0)
			pos.x = clampf(pos.x, 10.0, screen.size.x - w - 10.0)
			pos.y = clampf(pos.y, 80.0, screen.size.y - 200.0)
	return Rect2(pos, size)


# The look was swapped (F4): draw again in the new style.
func rebuild_look() -> void:
	queue_redraw()


func _draw() -> void:
	if alpha <= 0.0 or text == "":
		return
	# Graphics checkpoint 2: the styled bar is an opaque parchment panel that fades with its self_modulate.
	if Looks.is_styled():
		self_modulate = Color(1.0, 1.0, 1.0, alpha)
		StyleHud.draw_prompt(self, _rect, text, icon)
		return
	self_modulate = Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.78 * alpha)
	style.set_corner_radius_all(int(_rect.size.y * 0.5))
	style.border_color = Color(1.0, 0.88, 0.5, 0.55 * alpha)
	style.set_border_width_all(2)
	if big:
		style.bg_color = Color(0.16, 0.05, 0.05, 0.9 * alpha)
		style.border_color = Config.NOTICE_COLOUR
		style.border_color.a = alpha
		style.set_border_width_all(4)
	draw_style_box(style, _rect)
	var mid_y := _rect.position.y + _rect.size.y * 0.5
	var fs := Config.NOTICE_FONT_SIZE if big else FONT_SIZE
	var text_x := _rect.position.x + 24.0
	if icon != MoodIcons.Kind.NONE:
		var col := MoodIcons.colour_for(icon)
		col.a = alpha
		MoodIcons.draw(self, icon, Vector2(_rect.position.x + 28.0, mid_y), 24.0, col)
		text_x = _rect.position.x + 56.0
	var font := ThemeDB.fallback_font
	draw_string(
		font, Vector2(text_x, mid_y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.97, 0.88, alpha)
	)
