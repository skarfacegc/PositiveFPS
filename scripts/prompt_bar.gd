class_name PromptBar
extends Control

# Round 13b: the one-time prompt of the layered introduction (see intro.gd). Round 26: a slim banner with an icon and
# one short line under the night bar (the notices and the help prompts share it). It fades in and out, and shows only
# one prompt at a time. Screen-space UI, so it appears in both looks.

const FONT_SIZE := 20
const HEIGHT := 40.0

# The text and icon on show, how visible they are (0 to 1) and which prompt (-1 for none).
var text: String = ""
var icon: int = MoodIcons.Kind.NONE
var alpha: float = 0.0
var prompt_id: int = -1
var intro: Intro
var main: TopDownMain
# Round 22: a refusal or fall-back notice, coral-edged. Checkpoint 6: a slim banner under the top bar.
var big: bool = true
var coral: bool = false
var font_px: int = FONT_SIZE  # The text size of the bar on show (a banner may shrink it to fit).
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
	coral = intro.coral
	icon = Intro.icon_for(prompt_id)
	var fade := HudConfig.PROMPT_FADE_SECONDS
	var elapsed := intro.duration - intro.time_left
	alpha = clampf(minf(elapsed / fade, intro.time_left / fade), 0.0, 1.0)
	_rect = _place(screen)
	queue_redraw()


# The bar's rectangle. Round 26: every prompt and notice is a slim banner under the night bar, one at a time.
func _place(screen: Rect2) -> Rect2:
	return _place_banner(screen, ThemeDB.fallback_font)


# Checkpoint 6: a notice is a slim banner at the top centre, just under the Dusk to Dawn bar (or under the HUD alert
# while one shows), no wider than CP6_BANNER_MAX_WIDTH: the text shrinks (to 11 px) to fit rather than run out.
func _place_banner(screen: Rect2, font: Font) -> Rect2:
	font_px = HudConfig.NOTICE_FONT_SIZE
	var extra := 62.0 if icon != MoodIcons.Kind.NONE else 44.0
	var avail := minf(HudConfig.CP6_BANNER_MAX_WIDTH, screen.size.x - 20.0)
	while font_px > 11 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x + extra > avail:
		font_px -= 1
	var w := minf(font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px).x + extra, avail)
	var top := HudConfig.CP6_BANNER_TOP
	if main != null and main.hud != null and main.hud.alert_showing():
		top += HudConfig.CP6_BANNER_HEIGHT + HudConfig.CP6_BANNER_GAP
	return Rect2(Vector2(screen.size.x * 0.5 - w * 0.5, top), Vector2(w, HudConfig.NOTICE_HEIGHT))


# The look was swapped (F4): draw again in the new style.
func rebuild_look() -> void:
	queue_redraw()


func _draw() -> void:
	if alpha <= 0.0 or text == "":
		return
	# Graphics checkpoint 2: the styled bar is an opaque parchment panel that fades with its self_modulate.
	if Looks.is_styled():
		self_modulate = Color(1.0, 1.0, 1.0, alpha)
		StyleHud.draw_prompt(self, _rect, text, icon, coral)
		return
	self_modulate = Color.WHITE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.12, 0.78 * alpha)
	style.set_corner_radius_all(int(_rect.size.y * 0.5))
	style.border_color = Color(1.0, 0.88, 0.5, 0.55 * alpha)
	style.set_border_width_all(2)
	if coral:
		style.bg_color = Color(0.16, 0.05, 0.05, 0.9 * alpha)
		style.border_color = HudConfig.NOTICE_COLOUR
		style.border_color.a = alpha
		style.set_border_width_all(2)
	draw_style_box(style, _rect)
	var mid_y := _rect.position.y + _rect.size.y * 0.5
	var fs := font_px
	var text_x := _rect.position.x + 24.0
	if icon != MoodIcons.Kind.NONE:
		var col := MoodIcons.colour_for(icon)
		col.a = alpha
		var icon_size := 18.0 if big else 24.0
		MoodIcons.draw(self, icon, Vector2(_rect.position.x + 28.0, mid_y), icon_size, col)
		text_x = _rect.position.x + 56.0 if not big else _rect.position.x + 50.0
	var font := ThemeDB.fallback_font
	draw_string(
		font, Vector2(text_x, mid_y + fs * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.97, 0.88, alpha)
	)
