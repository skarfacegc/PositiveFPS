extends Control

# The start menu. For now it has one entry: Play (top-down, topdown.tscn). Round 9 turns it into a variant picker.

const TOP_DOWN_SCENE := "res://topdown.tscn"


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
	box.add_child(_make_label("Press Play to start", 24))

	var play := _make_button("1 — Play")
	play.pressed.connect(_start)
	box.add_child(play)

	box.add_child(_make_label("In game: R restart, M back to this menu", 18))


# Key 1 also starts the level.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("choice_1"):
		_start()


func _start() -> void:
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
	btn.custom_minimum_size = Vector2(360, 60)
	btn.add_theme_font_size_override("font_size", 28)
	return btn
