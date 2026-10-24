extends Control

# The start menu: pick one of three border variants (see Config.BorderVariant). Keys 1, 2 and 3 pick too. The choice is
# stored in Config.border_variant before the level loads.

const TOP_DOWN_SCENE := "res://topdown.tscn"
const DESCRIPTIONS: Array[String] = [
	"A simple ring around the centre, sized by how many people you have rescued.",
	"The border bulges out where you rescue people, and wraps around buildings. Recommended.",
	"The border follows the painted region your rescued people spread.",
]


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
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	box.add_child(_make_label("PositiveFPS", 48))
	box.add_child(_make_label("Pick a border to try", 24))

	for i: int in range(Config.BORDER_VARIANT_NAMES.size()):
		var btn := _make_button(Config.BORDER_VARIANT_NAMES[i])
		btn.pressed.connect(_start.bind(i))
		box.add_child(btn)
		box.add_child(_make_label(DESCRIPTIONS[i], 16))

	box.add_child(_make_label("In game: R restart, M menu, F2 targeting, F3 debug", 18))


# Keys 1, 2 and 3 pick a variant.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("choice_1"):
		_start(Config.BorderVariant.CIRCLE)
	elif event.is_action_pressed("choice_2"):
		_start(Config.BorderVariant.ORGANIC)
	elif event.is_action_pressed("choice_3"):
		_start(Config.BorderVariant.PAINT_EDGE)


# Stores the chosen variant and starts the level.
func _start(variant: int) -> void:
	Config.border_variant = variant
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
