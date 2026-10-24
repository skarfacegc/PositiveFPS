extends Control

# The start menu: a title, one Play button and a hint line. Play is the button, key 1 or Enter (the "play" action).
# Round 10 retired the Circle and Paint edge border variants, so there is nothing to pick.

const TOP_DOWN_SCENE := "res://topdown.tscn"
const HINT := "Enter or 1 to play.  In game: R restart, M menu, F2 targeting, F3 debug"

# The look toggle (Placeholder / Styled). The choice lasts for the session (see Looks.mode).
var look_button: Button
# Set once Play is pressed, so a key and a click in the same frame start the level only once.
var _starting: bool = false


func _ready() -> void:
	Controls.setup()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)

	box.add_child(_make_label("PositiveFPS", 48))
	var play := _make_button("Play")
	play.pressed.connect(_start)
	box.add_child(play)
	look_button = _make_button(look_text())
	look_button.pressed.connect(_toggle_look)
	box.add_child(look_button)
	box.add_child(_make_label(HINT, 18))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("play"):
		_start()


# The text of the look button.
func look_text() -> String:
	return "Look: %s" % Looks.mode_name()


# Flips the look for the next level (and the rest of the session).
func _toggle_look() -> void:
	Looks.toggle()
	look_button.text = look_text()


# Starts the level.
func _start() -> void:
	if _starting:
		return
	_starting = true
	get_tree().change_scene_to_file(TOP_DOWN_SCENE)


func _make_label(text: String, font_size: int) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", font_size)
	return lbl


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(420, 52)
	btn.add_theme_font_size_override("font_size", 26)
	return btn
