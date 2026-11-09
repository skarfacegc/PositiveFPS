class_name Hud
extends CanvasLayer

var night_label: Label
var night_bar: ProgressBar
var element_label: Label
var burst_label: Label
# Round 12a: spirit (a label and a bar above the burst indicator).
var spirit_label: Label
var spirit_bar: ProgressBar
var hint_label: Label
var rescued_label: Label
var targeting_label: Label
var alert_label: Label
var debug_hint_label: Label
# Round 10: the live floor-effect counts, shown under the F3 hint (see set_floor_text).
var floor_label: Label
var end_panel: ColorRect
var end_label: Label
# Round 18: the small "REC" mark shown while the gameplay recorder is on (built the first time it is needed).
var rec_label: Label
# Round 19: the held landmarks and their boosts (top right, under the REC mark).
var landmark_label: Label
# Graphics checkpoint 3: the styled drawings of the landmark panel and the end screen (nothing in the placeholder look).
var landmark_panel: StyledPanel
var dawn_panel: StyledPanel
# Graphics checkpoint 4: the styled banner that shows the alert's text (the placeholder look shows alert_label).
var alert_panel: StyledPanel
# Checkpoint 6: the styled look's versions of the HUD text lines (parchment panels; the Labels above show in the
# placeholder look). Each is fed the same text as its Label.
var rescued_panel: StyledPanel
var burst_panel: StyledPanel
var target_panel: StyledPanel
var targeting_panel: StyledPanel
var key_panel: StyledPanel
# Checkpoint 7: the styled Dusk to Dawn panel and spirit tag (drawn by StyleHud; the Labels and bars show in the
# placeholder look).
var night_view: Control
var spirit_view: Control
var _alert_tween: Tween
var _night_progress: float = 0.0
var _spirit_shown: bool = false
var _spirit_dim: bool = false
var _burst_on: bool = false
var _targeting_on: bool = false
# Round 12b: the target's element and mood, kept so either can change the label alone.
var _target_affinity: int = -1
var _target_mood: String = ""


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
	night_view = Control.new()
	night_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	night_view.set_anchors_preset(Control.PRESET_CENTER_TOP)
	night_view.offset_left = -HudConfig.CP7_NIGHT_WIDTH * 0.5
	night_view.offset_right = HudConfig.CP7_NIGHT_WIDTH * 0.5
	night_view.offset_top = 4
	night_view.offset_bottom = 4 + HudConfig.CP7_NIGHT_HEIGHT
	night_view.draw.connect(_draw_night_view)
	add_child(night_view)

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

	# Spirit (round 13b): a bigger bar at the bottom centre; SpiritMeter draws over the bar (ticks, flash, floating
	# numbers). The label and bar keep the values for the tests and for reading. Checkpoint 5 follow-up: the label sits
	# above the bar, centred on it, not to its left, where it ran into the burst line on the bottom left.
	var half := HudConfig.SPIRIT_METER_WIDTH * 0.5
	spirit_label = Label.new()
	spirit_label.add_theme_font_size_override("font_size", 20)
	spirit_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spirit_label.offset_left = -half
	spirit_label.offset_right = half
	spirit_label.offset_top = HudConfig.SPIRIT_LABEL_TOP
	spirit_label.offset_bottom = HudConfig.SPIRIT_LABEL_TOP + HudConfig.SPIRIT_LABEL_HEIGHT
	spirit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spirit_label.visible = false
	add_child(spirit_label)
	spirit_bar = ProgressBar.new()
	spirit_bar.min_value = 0.0
	spirit_bar.max_value = SpiritConfig.SPIRIT_MAX
	spirit_bar.show_percentage = false
	spirit_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spirit_bar.offset_left = -half
	spirit_bar.offset_right = half
	spirit_bar.offset_top = -110.0
	spirit_bar.offset_bottom = -110.0 + HudConfig.SPIRIT_METER_HEIGHT
	spirit_bar.visible = false
	add_child(spirit_bar)
	spirit_view = Control.new()
	spirit_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spirit_view.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	spirit_view.offset_left = -half
	spirit_view.offset_right = half
	spirit_view.offset_top = HudConfig.SPIRIT_LABEL_TOP
	spirit_view.offset_bottom = HudConfig.SPIRIT_LABEL_TOP + HudConfig.SPIRIT_LABEL_HEIGHT
	spirit_view.visible = false
	spirit_view.draw.connect(_draw_spirit_view)
	add_child(spirit_view)

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

	# Round 19: the held landmarks, top right under the targeting label and the REC mark.
	landmark_label = Label.new()
	landmark_label.add_theme_font_size_override("font_size", 18)
	landmark_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	landmark_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	landmark_label.add_theme_constant_override("outline_size", 5)
	landmark_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	landmark_label.offset_left = -360
	landmark_label.offset_right = -20
	landmark_label.offset_top = 90
	landmark_label.offset_bottom = 216  # Room for the header and four held lines (about 110 px; 0.3.3: the Gallery).
	landmark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(landmark_label)
	landmark_panel = StyledPanel.new()
	landmark_panel.kind = StyledPanel.Kind.LANDMARKS
	landmark_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	landmark_panel.offset_left = -270
	landmark_panel.offset_right = -20
	landmark_panel.offset_top = 90
	landmark_panel.offset_bottom = 90 + 44 + 40 * LandmarkConfig.LANDMARK_NAMES.size()  # The header and 40 px a landmark.
	add_child(landmark_panel)

	# Rescued counter. The level places it under the minimap (see place_rescued_below).
	rescued_label = Label.new()
	rescued_label.text = "Rescued: 0 / %d" % Config.TD_PEOPLE_COUNT
	rescued_label.add_theme_font_size_override("font_size", 24)
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

	floor_label = Label.new()
	floor_label.add_theme_font_size_override("font_size", 18)
	floor_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	floor_label.add_theme_constant_override("outline_size", 5)
	floor_label.position = Vector2(20, 90)
	floor_label.visible = false
	add_child(floor_label)

	# Relapse alert: a short orange message near the top that fades out (see show_alert).
	alert_label = Label.new()
	# Checkpoint 6: a slim line just under the night bar (it was a 34 px line near the middle of the play area).
	alert_label.position = Vector2(0, HudConfig.CP6_BANNER_TOP)
	alert_label.size = Vector2(1280, HudConfig.CP6_BANNER_HEIGHT)
	alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	alert_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	alert_label.add_theme_font_size_override("font_size", HudConfig.CP6_ALERT_FONT)
	alert_label.add_theme_color_override("font_color", Color(1, 0.6, 0.1))
	alert_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	alert_label.add_theme_constant_override("outline_size", 6)
	alert_label.modulate = Color(1, 1, 1, 0)
	add_child(alert_label)
	alert_panel = StyledPanel.new()
	alert_panel.kind = StyledPanel.Kind.ALERT
	alert_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	alert_panel.modulate = Color(1, 1, 1, 0)
	add_child(alert_panel)

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
	dawn_panel = StyledPanel.new()
	dawn_panel.kind = StyledPanel.Kind.DAWN
	dawn_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	end_panel.add_child(dawn_panel)
	rescued_panel = _make_line(StyledPanel.Kind.RESCUED)
	burst_panel = _make_line(StyledPanel.Kind.BURST)
	target_panel = _make_line(StyledPanel.Kind.TARGET)
	targeting_panel = _make_line(StyledPanel.Kind.TARGETING)
	key_panel = _make_line(StyledPanel.Kind.KEYS)
	_push_line(rescued_panel, rescued_label.text, StyleHudText.IDLE, StyleUi.GOLD)
	_refresh_target()
	rebuild_look()


func _make_line(kind: int) -> StyledPanel:
	var p := StyledPanel.new()
	p.kind = kind
	p.visible = false
	add_child(p)
	move_child(p, end_panel.get_index())  # Under the end screen's dimming, like the Labels.
	return p


# Checkpoint 6: feeds a styled line panel and fits its width to the text. The bottom-left lines (target, burst and keys)
# stack up from the bottom edge, the targeting line sits at the top right and the rescued line is placed by
# place_rescued_below.
func _push_line(p: StyledPanel, text: String, state: int, colour: Color) -> void:
	if not p.set_line(text, state, colour):
		return
	var w := StyleHudText.line_width(p.kind, text)
	var h := HudConfig.CP6_LINE_HEIGHT
	var m := HudConfig.CP6_LINE_MARGIN
	if p.kind == StyledPanel.Kind.RESCUED:
		p.size = Vector2(w, h)
	elif p.kind == StyledPanel.Kind.TARGETING:
		p.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		p.offset_right = -20.0
		p.offset_left = -20.0 - w
		p.offset_top = 18.0
		p.offset_bottom = 18.0 + h
	else:
		var slot := 0 if p.kind == StyledPanel.Kind.KEYS else (1 if p.kind == StyledPanel.Kind.BURST else 2)
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		p.offset_left = m
		p.offset_right = m + w
		p.offset_bottom = -6.0 - float(slot) * (h + HudConfig.CP6_LINE_GAP)
		p.offset_top = p.offset_bottom - h


# Shows `label` in the placeholder look and `panel` in the styled one (neither while `wanted` is false).
func _show_line(label: Label, panel: StyledPanel, wanted: bool) -> void:
	var styled := Looks.is_styled()
	label.visible = wanted and not styled
	panel.visible = wanted and styled


# Graphics checkpoint 3: in the styled look the landmark panel and the end screen are drawn by StyledPanel (pixel
# panels with icons) and the plain Labels are hidden; the placeholder look shows the Labels. Checkpoint 6: the same for
# the text lines (rescued, target, burst, targeting and the key line).
func rebuild_look() -> void:
	var styled := Looks.is_styled()
	_show_line(rescued_label, rescued_panel, true)
	_show_line(element_label, target_panel, true)
	_show_line(hint_label, key_panel, true)
	_show_line(burst_label, burst_panel, _burst_on)
	_show_line(targeting_label, targeting_panel, _targeting_on)
	for p: StyledPanel in [rescued_panel, burst_panel, target_panel, targeting_panel, key_panel]:
		p.rebuild_look()
	night_label.visible = not styled
	night_bar.visible = not styled
	night_view.visible = styled
	_apply_spirit_look()
	landmark_label.visible = not styled
	end_label.visible = not styled
	alert_label.visible = not styled
	alert_panel.visible = styled
	alert_panel.rebuild_look()
	landmark_panel.visible = styled
	dawn_panel.visible = styled
	landmark_panel.rebuild_look()
	dawn_panel.rebuild_look()


# Shows how far the night has gone: 0 at dusk, 1 at dawn.
func set_night_progress(p: float) -> void:
	night_bar.value = clampf(p, 0.0, 1.0) * 100.0
	_night_progress = clampf(p, 0.0, 1.0)
	night_view.queue_redraw()


# Checkpoint 7: the styled Dusk to Dawn panel and the styled spirit tag, each shown only in the styled look.
func _draw_night_view() -> void:
	StyleHud.draw_night(night_view, _night_progress, night_label.text)


func _draw_spirit_view() -> void:
	StyleHud.draw_tag(spirit_view, spirit_label.text, _spirit_dim)


# The spirit label (placeholder) or its styled tag: both show once spirit has been set, one at a time by the look.
func _apply_spirit_look() -> void:
	var styled := Looks.is_styled()
	spirit_label.visible = _spirit_shown and not styled
	spirit_view.visible = _spirit_shown and styled


# Top-down: shows the target's element in its colour, or "No target" in cream. Pass -1 for no target.
func set_target(affinity: int) -> void:
	_target_affinity = affinity
	_refresh_target()


# Round 12b: the target's mood ("guarded", "skittish", "glum" or "" for none) after the element name.
func set_target_mood(mood: String) -> void:
	if mood == _target_mood:
		return
	_target_mood = mood
	_refresh_target()


func _refresh_target() -> void:
	if _target_affinity < 0:
		element_label.text = "No target"
		element_label.add_theme_color_override("font_color", PlayerConfig.TD_NO_TARGET_COLOR)
		_push_line(target_panel, element_label.text, StyleHudText.DIM, PlayerConfig.TD_NO_TARGET_COLOR)
	else:
		element_label.text = "Target: " + Config.ELEMENT_NAMES[_target_affinity]
		if _target_mood != "":
			element_label.text += " (" + _target_mood + ")"
		element_label.add_theme_color_override("font_color", Config.ELEMENT_COLORS[_target_affinity])
		_push_line(target_panel, element_label.text, StyleHudText.IDLE, Config.ELEMENT_COLORS[_target_affinity])


# Top-down: shows the targeting mode (see Config.TargetingMode) in the top right.
func set_targeting(mode: int) -> void:
	_targeting_on = true
	targeting_label.text = "Targeting: " + PlayerConfig.TD_TARGETING_NAMES[mode] + "  [F2]"
	_push_line(targeting_panel, targeting_label.text, StyleHudText.IDLE, StyleUi.AMBER)
	_show_line(targeting_label, targeting_panel, true)


func set_rescued(n: int, total: int) -> void:
	rescued_label.text = "Rescued: %d / %d" % [n, total]
	_push_line(rescued_panel, rescued_label.text, StyleHudText.IDLE, StyleUi.GOLD)


# Puts the Rescued counter at the left edge, `y` pixels from the top (the level passes the bottom of the minimap).
func place_rescued_below(y: float) -> void:
	rescued_label.position = Vector2(20, y)
	rescued_panel.position = Vector2(20, y)


# Checkpoint 6: true while the HUD alert (such as "Someone lost their joy!") is up or fading, so a notice banner moves
# down below it instead of covering it.
func alert_showing() -> bool:
	return alert_label.modulate.a > 0.02


# Shows the "[F3] debug" hint while the debug overlay is on.
func set_debug_on(on: bool) -> void:
	debug_hint_label.visible = on
	floor_label.visible = on


# Replaces the floor-effect counts line (round 10): the total against the cap, and each kind.
func set_floor_text(text: String) -> void:
	floor_label.text = text


# Replaces the text of the F3 hint (cover and protection key, plus the border counts).
func set_debug_text(text: String) -> void:
	debug_hint_label.text = text


# Replaces the controls hint text at the bottom of the screen.
func set_hint(text: String) -> void:
	hint_label.text = text
	_push_line(key_panel, text, StyleHudText.IDLE, StyleUi.AMBER)


# Round 19: the landmark panel: "Landmarks 1 of 3" and a line (with the boost) for each one held.
func set_landmarks(lines: Array[String], total: int, held: Array[bool] = []) -> void:
	landmark_panel.set_landmarks(held)
	var text := "Landmarks %d of %d" % [lines.size(), total]
	if not lines.is_empty():
		text += "\n" + "\n".join(lines)
	if landmark_label.text != text:
		landmark_label.text = text


# Round 18: shows or hides the red "REC" mark (top right, under the targeting label).
func set_recording(on: bool) -> void:
	if rec_label == null:
		if not on:
			return
		rec_label = Label.new()
		rec_label.text = "● REC"
		rec_label.add_theme_font_size_override("font_size", 20)
		rec_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		rec_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		rec_label.offset_left = -160
		rec_label.offset_right = -20
		rec_label.offset_top = 52
		rec_label.offset_bottom = 82
		rec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(rec_label)
	rec_label.visible = on


# Shows the player's spirit and whether they are dim (the bar and the label go grey).
func set_spirit(spirit: float, is_dim: bool) -> void:
	_spirit_shown = true
	_spirit_dim = is_dim
	_apply_spirit_look()
	spirit_view.queue_redraw()
	spirit_bar.visible = true
	spirit_bar.value = spirit
	if is_dim:
		spirit_label.text = ("DIM  spirit %d / %d" % [roundi(spirit), roundi(SpiritConfig.SPIRIT_MAX)])
		spirit_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	else:
		spirit_label.text = "Spirit %d / %d" % [roundi(spirit), roundi(SpiritConfig.SPIRIT_MAX)]
		spirit_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))


# Shows the joy burst cooldown: READY in green when it can be used, otherwise the seconds left in grey. `has_spirit`
# false (round 12a) shows that the burst needs spirit instead.
func set_burst(cooldown_left: float, has_spirit: bool = true, targets: int = 0) -> void:
	var state := StyleHudText.READY
	if not has_spirit:
		burst_label.text = "Joy burst [G]: needs %d spirit" % roundi(SpiritConfig.BURST_SPIRIT_COST)
		burst_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
		state = StyleHudText.WARN
	elif cooldown_left <= 0.0:
		burst_label.text = "Joy burst [G]: READY"
		burst_label.add_theme_color_override("font_color", Color(0.6, 1, 0.6))
		if targets > 0:  # Round 22: it clears dimmed people off the border; say how many are in reach.
			# Checkpoint 5 follow-up: short enough to end before the spirit bar (about 440 px at this size).
			burst_label.text = "Joy burst [G]: READY - clears %d dimmed" % targets
			burst_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.5))
	else:
		burst_label.text = "Joy burst [G]: %.1fs" % cooldown_left
		burst_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		state = StyleHudText.DIM
	_burst_on = true
	_push_line(burst_panel, burst_label.text, state, StyleUi.GOLD)
	_show_line(burst_label, burst_panel, true)


# Shows a short alert that waits `hold` seconds (0.8s by default), then fades out over 2s. Calling again restarts it.
# Round 20: `colour` is the text colour (the default orange; a landmark claim or loss passes its own).
func show_alert(text: String, colour: Color = Color(1, 0.6, 0.1), hold: float = 0.8) -> void:
	alert_label.text = text
	alert_label.add_theme_color_override("font_color", colour)
	alert_label.modulate = Color(1, 1, 1, 1)
	alert_panel.set_alert(text, colour)
	alert_panel.modulate = Color(1, 1, 1, 1)
	if _alert_tween != null and _alert_tween.is_valid():
		_alert_tween.kill()
	_alert_tween = create_tween()
	_alert_tween.tween_interval(hold)
	_alert_tween.tween_property(alert_label, "modulate:a", 0.0, 2.0)
	_alert_tween.parallel().tween_property(alert_panel, "modulate:a", 0.0, 2.0)


# Round 22: the HUD panels that an edge pointer keeps clear of (the landmark pointers, see landmark_pointers.gd).
func layout_controls() -> Array[Control]:
	var out: Array[Control] = [
		night_label,
		night_bar,
		element_label,
		burst_label,
		spirit_label,
		spirit_bar,
		hint_label,
		rescued_label,
		targeting_label,
		landmark_label,
		landmark_panel,
		alert_label,
		# Checkpoint 6: the styled look's lines (hidden, so not counted, in the placeholder look).
		rescued_panel,
		burst_panel,
		target_panel,
		targeting_panel,
		key_panel,
		# Checkpoint 7: the styled Dusk to Dawn panel and spirit tag (hidden in the placeholder look).
		night_view,
		spirit_view,
	]
	if rec_label != null:
		out.append(rec_label)
	return out


# Shows the end screen: a title, then the detail lines (dawn lights, the reasons, buildings).
func show_end(title: String, detail: String, rating: Dictionary = {}) -> void:
	dawn_panel.set_dawn(title, detail, rating)
	end_label.text = title + "\n\n" + detail + "\n\nPress R to play again, M for the menu"
	end_panel.visible = true
