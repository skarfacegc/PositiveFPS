extends Control

# The start menu: a title, one Play button, the Look toggle and a "How to play" panel. Play is the button,
# key 1 or Enter (the "play" action). Round 10 retired the Circle and Paint edge border variants.

const TOP_DOWN_SCENE := "res://topdown.tscn"
const STYLED_NOTE := "Styled look: visual test only — not the current game."
const HOW_TO_PLAY_WIDTH := 760
const HOW_TO_PLAY_FONT := 18
const HOW_TO_PLAY_TEXT := (
	"[center][font_size=26][b]How to play[/b][/font_size][/center]\n"
	+ "[b]Goal:[/b] Bring joy to the gloomy townsfolk. Everyone you help joins a living border around your town. "
	+ "Enclose the landmark (the beacon) and hold it for 10 seconds before dawn.\n"
	+ "[b]Helping:[/b] Point at a person and joy flies to them automatically. Guarded people only accept joy from "
	+ "the front, skittish people flee if you run at them, and glum people take extra joy when they look up.\n"
	+ "[b]The gloom:[/b] Dimmed people press on your border and reach for you. Where they push, border folk falter "
	+ "and gaps open. Re-joy a faltering person to close the gap.\n"
	+ "[b]Spirit:[/b] Helping people fills it; a joy burst costs some. At zero you go dim. Recover inside your border.\n"
	+ "[b]Icons:[/b] shield guarded · running feet skittish · cloud glum · umbrella sheltered · ! faltering.\n"
	+ "[b]Keys:[/b] WASD move · Shift run · Space twirl (dodge a grab) · G or Q joy burst · Mouse point at people "
	+ "(F2 changes targeting) · F3 debug · F4 switch look · R restart · M menu"
)

# The look toggle (Placeholder / Styled). The choice lasts for the session (see Looks.mode).
var look_button: Button
# Round 13b: a small note under the Look button, shown while the styled look is selected (it is a visual test only).
var look_note: Label
# The how-to-play panel (a RichTextLabel with the bbcode bold labels).
var how_to_play: RichTextLabel
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
	look_note = _make_label(STYLED_NOTE, 15)
	look_note.add_theme_color_override("font_color", Color(0.75, 0.7, 0.55))
	look_note.visible = Looks.is_styled()
	box.add_child(look_note)
	how_to_play = _make_how_to_play()
	box.add_child(how_to_play)


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
	look_note.visible = Looks.is_styled()


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


# The buttons keep their 420 px width and stay centred, even though the panel below is wider than they are.
func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(420, 52)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.add_theme_font_size_override("font_size", 26)
	return btn


# The how-to-play panel: a dark box with the text wrapped to HOW_TO_PLAY_WIDTH and centred under the buttons.
func _make_how_to_play() -> RichTextLabel:
	var panel := RichTextLabel.new()
	panel.name = "HowToPlay"
	panel.bbcode_enabled = true
	panel.text = HOW_TO_PLAY_TEXT
	panel.fit_content = true
	panel.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.custom_minimum_size = Vector2(HOW_TO_PLAY_WIDTH, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_font_size_override("normal_font_size", HOW_TO_PLAY_FONT)
	panel.add_theme_font_size_override("bold_font_size", HOW_TO_PLAY_FONT)
	var box_style := StyleBoxFlat.new()
	box_style.bg_color = Color(0.14, 0.14, 0.17)
	box_style.set_corner_radius_all(8)
	box_style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("normal", box_style)
	return panel
