class_name Hud
extends CanvasLayer

var crosshair: Label
var timer_label: Label
var element_label: Label
var burst_label: Label
var hint_label: Label
var rescued_label: Label
var alert_label: Label
var end_panel: ColorRect
var end_label: Label
var _alert_tween: Tween


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

	# Joy burst cooldown, just above the element label. Only shown in top-down mode (see set_burst).
	burst_label = Label.new()
	burst_label.add_theme_font_size_override("font_size", 22)
	burst_label.position = Vector2(20, 606)
	burst_label.visible = false
	add_child(burst_label)

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

	# Relapse alert: a short orange message near the top that fades out (see show_alert).
	alert_label = Label.new()
	alert_label.position = Vector2(0, 200)
	alert_label.size = Vector2(1280, 60)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", 34)
	alert_label.add_theme_color_override("font_color", Color(1, 0.6, 0.1))
	alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	alert_label.add_theme_constant_override("outline_size", 8)
	alert_label.modulate = Color(1, 1, 1, 0)
	add_child(alert_label)

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


# Replaces the controls hint text at the bottom of the screen.
func set_hint(text: String) -> void:
	hint_label.text = text


# Hides or shows the crosshair in the middle of the screen.
func set_crosshair_visible(v: bool) -> void:
	crosshair.visible = v


# Shows the joy burst cooldown: READY in green when it can be used, otherwise the seconds left in grey.
func set_burst(cooldown_left: float) -> void:
	burst_label.visible = true
	if cooldown_left <= 0.0:
		burst_label.text = "Joy burst [G]: READY"
		burst_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
	else:
		burst_label.text = "Joy burst [G]: %.1fs" % cooldown_left
		burst_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))


# Shows a short alert that waits 0.8s, then fades out over 2s. Calling again restarts it.
func show_alert(text: String) -> void:
	alert_label.text = text
	alert_label.modulate = Color(1, 1, 1, 1)
	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_tween = create_tween()
	_alert_tween.tween_interval(0.8)
	_alert_tween.tween_property(alert_label, "modulate:a", 0.0, 2.0)


# Shows the end screen with the buildings that were unlocked.
func show_end(buildings: Array, title: String) -> void:
	var text := title + "\n\nBuildings restored:\n"
	if buildings.is_empty():
		text += "None yet — try again!"
	else:
		for b: String in buildings:
			text += str(b) + "\n"
	text += "\n\nPress R to play again"
	end_label.text = text
	end_panel.visible = true
