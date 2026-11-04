class_name StyleReachTag
extends Control

# Graphics checkpoint 5: the small word that rides the stretching tip ("Stretching") in the styled look. World
# text turns to mush in the 640x360 view, so the word is a screen-space parchment tag in the HUD (cells lined
# up with the 3D pixels, like the other styled UI), placed over the tip by StyleReach.

const FONT_SIZE := 16
const PAD := 14.0

var text: String = ""
var _at := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


# Shows `words` centred above the screen point `at` (empty hides the tag).
func show_at(words: String, at: Vector2) -> void:
	if words == "":
		hide_tag()
		return
	if words == text and at.is_equal_approx(_at) and visible:
		return
	text = words
	_at = at
	visible = true
	queue_redraw()


func hide_tag() -> void:
	if visible:
		visible = false
		text = ""


func _draw() -> void:
	if text == "" or not Looks.is_styled():
		return
	var c := StyleUi.cell(self)
	var font := ThemeDB.fallback_font
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x + PAD * 2.0
	var rect := Rect2(_at + Vector2(-w * 0.5, -58.0), Vector2(w, 30.0))
	rect.position = (rect.position / c).floor() * c
	StyleUi.panel(self, rect, c, StyleUi.PARCHMENT)
	StyleUi.sparkle(self, Vector2(rect.position.x + 9.0, rect.position.y + 15.0), 1, c, StyleUi.AMBER)
	draw_string(
		font,
		Vector2(rect.position.x + PAD + 4.0, rect.position.y + 21.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		StyleUi.INK
	)
