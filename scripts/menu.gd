extends Control

# The start menu: pick first person (main.tscn) or top-down (topdown.tscn).

const FIRST_PERSON_SCENE := "res://main.tscn"
const TOP_DOWN_SCENE := "res://topdown.tscn"


func _ready() -> void:
	Controls.setup()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
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
	box.add_child(_make_label("Pick a mode to playtest", 24))

	var first := _make_button("1 — First person")
	first.pressed.connect(_start.bind(FIRST_PERSON_SCENE))
	box.add_child(first)

	var top := _make_button("2 — Top-down")
	top.pressed.connect(_start.bind(TOP_DOWN_SCENE))
	box.add_child(top)

	box.add_child(_make_label("In game: R restart, M back to this menu", 18))


# Keys 1 and 2 also pick a mode.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("element_1"):
		_start(FIRST_PERSON_SCENE)
	elif event.is_action_pressed("element_2"):
		_start(TOP_DOWN_SCENE)


func _start(path: String) -> void:
	get_tree().change_scene_to_file(path)


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
