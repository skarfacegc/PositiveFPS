extends CanvasLayer

var crosshair: Label
var timer_label: Label
var element_label: Label
var hint_label: Label
var rescued_label: Label
var end_panel: ColorRect
var end_label: Label


func _ready() -> void:
	# Crosshair in the middle of the screen.
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 32)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -20
	crosshair.offset_right = 20
	crosshair.offset_top = -30
	crosshair.offset_bottom = 30
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(crosshair)

	# Countdown at the top centre.
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 36)
	timer_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	timer_label.offset_left = -150
	timer_label.offset_right = 150
	timer_label.offset_top = 10
	timer_label.offset_bottom = 60
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(timer_label)

	# Current element, bottom left.
	element_label = Label.new()
	element_label.add_theme_font_size_override("font_size", 28)
	element_label.position = Vector2(20, 640)
	add_child(element_label)

	# Controls hint under the element label.
	hint_label = Label.new()
	hint_label.text = "1 Music  2 Art  3 Nature  |  Shift run  |  Get close for more joy  |  Esc free mouse  |  R restart"
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.position = Vector2(20, 690)
	add_child(hint_label)

	# Rescued counter, top left.
	rescued_label = Label.new()
	rescued_label.text = "Rescued: 0 / 20"
	rescued_label.add_theme_font_size_override("font_size", 24)
	rescued_label.position = Vector2(20, 20)
	add_child(rescued_label)

	# End screen: a dark panel covering the whole screen, hidden until the round ends.
	end_panel = ColorRect.new()
	end_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.color = Color(0, 0, 0, 0.6)
	end_panel.visible = false
	add_child(end_panel)

	end_label = Label.new()
	end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_size_override("font_size", 32)
	end_panel.add_child(end_label)


# Shows the time left as M:SS.
func set_time(t: float) -> void:
	var secs := int(maxf(t, 0.0))
	timer_label.text = "%d:%02d" % [secs / 60, secs % 60]


# Shows the element the player is holding, in that element's colour.
func set_element(e: int) -> void:
	element_label.text = "Element: " + Config.ELEMENT_NAMES[e]
	element_label.add_theme_color_override("font_color", Config.ELEMENT_COLORS[e])


func set_rescued(n: int, total: int) -> void:
	rescued_label.text = "Rescued: %d / %d" % [n, total]


# Shows the end screen with the buildings that were unlocked.
func show_end(buildings: Array, title: String) -> void:
	var text := title + "\n\nBuildings restored:\n"
	if buildings.is_empty():
		text += "None yet — try again!"
	else:
		for b in buildings:
			text += str(b) + "\n"
	text += "\n\nPress R to play again"
	end_label.text = text
	end_panel.visible = true
