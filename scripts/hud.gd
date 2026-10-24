class_name Hud
extends CanvasLayer

var night_label: Label
var night_bar: ProgressBar
var element_label: Label
var burst_label: Label
var hint_label: Label
var rescued_label: Label
var targeting_label: Label
var alert_label: Label
var debug_hint_label: Label
var end_panel: ColorRect
var end_label: Label
var _alert_tween: Tween


func _ready() -> void:
	# Dusk to dawn: a label and a progress bar at the top centre (the level ends at dawn).
	night_label = Label.new()
	night_label.text = "Dusk → Dawn"
	night_label.add_theme_font_size_override("font_size", 22)
	night_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	night_label.offset_left = -200
	night_label.offset_right = 200
	night_label.offset_top = 4
	night_label.offset_bottom = 34
	night_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(night_label)
	night_bar = ProgressBar.new()
	night_bar.min_value = 0.0
	night_bar.max_value = 100.0
	night_bar.show_percentage = false
	night_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	night_bar.offset_left = -200
	night_bar.offset_right = 200
	night_bar.offset_top = 36
	night_bar.offset_bottom = 56
	add_child(night_bar)

	# Target's element (or "No target"), bottom left.
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

	# Controls hint under the element label (set by the level, see set_hint).
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.position = Vector2(20, 690)
	add_child(hint_label)

	# Targeting mode, top right. Only shown in top-down mode (see set_targeting).
	targeting_label = Label.new()
	targeting_label.add_theme_font_size_override("font_size", 20)
	targeting_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	targeting_label.offset_left = -360
	targeting_label.offset_right = -20
	targeting_label.offset_top = 20
	targeting_label.offset_bottom = 50
	targeting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	targeting_label.visible = false
	add_child(targeting_label)

	# Rescued counter, top left.
	rescued_label = Label.new()
	rescued_label.text = "Rescued: 0 / %d" % Config.TD_PEOPLE_COUNT
	rescued_label.add_theme_font_size_override("font_size", 24)
	rescued_label.position = Vector2(20, 20)
	add_child(rescued_label)

	# Shows that the F3 debug overlay is on. Hidden unless it is (see set_debug_on).
	debug_hint_label = Label.new()
	debug_hint_label.text = "[F3] debug: c = cover, p = protection"
	debug_hint_label.add_theme_font_size_override("font_size", 22)
	debug_hint_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	debug_hint_label.add_theme_constant_override("outline_size", 6)
	debug_hint_label.position = Vector2(20, 56)
	debug_hint_label.visible = false
	add_child(debug_hint_label)

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


# Shows how far the night has gone: 0 at dusk, 1 at dawn.
func set_night_progress(p: float) -> void:
	night_bar.value = clampf(p, 0.0, 1.0) * 100.0


# Top-down: shows the target's element in its colour, or "No target" in cream. Pass -1 for no target.
func set_target(affinity: int) -> void:
	if affinity < 0:
		element_label.text = "No target"
		element_label.add_theme_color_override("font_color", Config.TD_NO_TARGET_COLOR)
	else:
		element_label.text = "Target: " + Config.ELEMENT_NAMES[affinity]
		element_label.add_theme_color_override("font_color", Config.ELEMENT_COLORS[affinity])


# Top-down: shows the targeting mode (see Config.TargetingMode) in the top right.
func set_targeting(mode: int) -> void:
	targeting_label.visible = true
	targeting_label.text = "Targeting: " + Config.TD_TARGETING_NAMES[mode] + "  [F2]"


func set_rescued(n: int, total: int) -> void:
	rescued_label.text = "Rescued: %d / %d" % [n, total]


# Shows the "[F3] debug" hint while the debug overlay is on.
func set_debug_on(on: bool) -> void:
	debug_hint_label.visible = on


# Replaces the text of the F3 hint (cover and protection key, plus the border counts).
func set_debug_text(text: String) -> void:
	debug_hint_label.text = text


# Replaces the controls hint text at the bottom of the screen.
func set_hint(text: String) -> void:
	hint_label.text = text


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


# Shows the end screen: a title, then the detail lines (landmark, beautified share, buildings, rescued).
func show_end(title: String, detail: String) -> void:
	end_label.text = title + "\n\n" + detail + "\n\nPress R to play again, M for the menu"
	end_panel.visible = true
