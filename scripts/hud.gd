# gdlint: ignore=max-public-methods
class_name Hud
extends CanvasLayer

var night_label: Label
var night_bar: ProgressBar
var burst_label: Label
# Round 12a: spirit (a label and a bar above the burst indicator).
var spirit_label: Label
var spirit_bar: ProgressBar
var hint_label: Label
var rescued_label: Label
# Walls and gates: Clean HUD (#92). The targeting mode line ("Targeting: Hover  [F2]") moved to the F3 overlay (the
# level reads it from here); the target line and the centre alert line are gone (events use the banner, PromptBar).
var targeting_text: String = ""
# Walls and gates: Capture polish (#75). The people line under the spirit meter.
var people_label: Label
var debug_hint_label: Label
# Round 10: the live floor-effect counts, shown under the F3 hint (see set_floor_text).
var floor_label: Label
var end_panel: ColorRect
var end_label: Label
# Round 18: the small "REC" mark shown while the gameplay recorder is on (built the first time it is needed).
var rec_label: Label
# Walls and gates: Recorder catch-up (#60). The "Marked" flash beside REC.
var mark_label: Label
# Round 19: the held landmarks and their boosts (top right, under the REC mark).
var landmark_label: Label
# Graphics checkpoint 3: the styled drawings of the landmark panel and the end screen (nothing in the placeholder look).
var landmark_panel: StyledPanel
var dawn_panel: StyledPanel
# Checkpoint 6: the styled look's versions of the HUD text lines (parchment panels; the Labels above show in the
# placeholder look). Each is fed the same text as its Label.
var rescued_panel: StyledPanel
var burst_panel: StyledPanel
var key_panel: StyledPanel
# Checkpoint 7: the styled Dusk to Dawn panel and spirit tag (drawn by StyleHud; the Labels and bars show in the
# placeholder look).
var night_view: Control
var spirit_view: Control
# Walls and gates: Recorder catch-up (#60). The tween that hides the "Marked" flash.
var _mark_tween: Tween
var _night_progress: float = 0.0
var _spirit_shown: bool = false
var _spirit_dim: bool = false
var _burst_on: bool = false
# Walls and gates: Clean HUD (#92). The controls strip shows for the first seconds of a night and while H is held.
var _controls_on: bool = true


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

	# Joy burst line, bottom left and above the spirit meter's row, so it never runs under the meter (it fits a 960 px
	# window). Only shown in top-down mode (see set_burst).
	burst_label = Label.new()
	burst_label.add_theme_font_size_override("font_size", 22)
	burst_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	burst_label.offset_left = 20.0
	burst_label.offset_right = 20.0
	burst_label.offset_bottom = -HudConfig.CLEAN_BURST_BOTTOM
	burst_label.offset_top = -HudConfig.CLEAN_BURST_BOTTOM - HudConfig.CLEAN_BURST_HEIGHT
	burst_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
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

	# Walls and gates: Capture polish (#75). One plain line under the spirit meter: the people on the line against the
	# people it needs (see Defences.people_text). Plain text in both looks.
	people_label = Label.new()
	people_label.add_theme_font_size_override("font_size", 16)
	people_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	people_label.add_theme_constant_override("outline_size", 5)
	# Walls and gates: Clean HUD (#92). A dark backing, as wide as its text and centred under the meter, below the meter's
	# moon marker (the marker hangs about 20 px under the bar).
	people_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	people_label.offset_left = 0.0
	people_label.offset_right = 0.0
	people_label.offset_top = -HudConfig.CLEAN_PEOPLE_TOP
	people_label.offset_bottom = -HudConfig.CLEAN_PEOPLE_BOTTOM
	people_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	people_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	people_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	people_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backing := StyleBoxFlat.new()
	backing.bg_color = HudConfig.CLEAN_PEOPLE_BACKING
	backing.set_corner_radius_all(6)
	backing.content_margin_left = HudConfig.CLEAN_PEOPLE_MARGIN_X
	backing.content_margin_right = HudConfig.CLEAN_PEOPLE_MARGIN_X
	backing.content_margin_top = HudConfig.CLEAN_PEOPLE_MARGIN_Y
	backing.content_margin_bottom = HudConfig.CLEAN_PEOPLE_MARGIN_Y
	people_label.add_theme_stylebox_override("normal", backing)
	add_child(people_label)

	# The controls strip on the bottom edge (set by the level, see set_hint; shown for the first seconds of a night and
	# while H is held, see show_controls).
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 16)
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint_label.offset_left = 20.0
	hint_label.offset_right = 20.0
	hint_label.offset_bottom = -HudConfig.CLEAN_HINT_BOTTOM
	hint_label.offset_top = -HudConfig.CLEAN_HINT_BOTTOM - HudConfig.CLEAN_HINT_HEIGHT
	hint_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hint_label)

	# Round 19: the held landmarks, top right under the REC mark.
	landmark_label = Label.new()
	landmark_label.add_theme_font_size_override("font_size", 18)
	landmark_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.5))
	landmark_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	landmark_label.add_theme_constant_override("outline_size", 5)
	landmark_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	landmark_label.offset_left = -360
	landmark_label.offset_right = -20
	landmark_label.offset_top = HudConfig.CLEAN_RIGHT_TOP
	# Room for the header and four held lines (about 110 px; 0.3.3: the Gallery).
	landmark_label.offset_bottom = HudConfig.CLEAN_RIGHT_TOP + 126.0
	landmark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(landmark_label)
	landmark_panel = StyledPanel.new()
	landmark_panel.kind = StyledPanel.Kind.LANDMARKS
	landmark_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	landmark_panel.offset_left = -270
	landmark_panel.offset_right = -20
	landmark_panel.offset_top = HudConfig.CLEAN_RIGHT_TOP
	# The header and 40 px a landmark.
	landmark_panel.offset_bottom = HudConfig.CLEAN_RIGHT_TOP + 44 + 40 * LandmarkConfig.LANDMARK_NAMES.size()
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
	key_panel = _make_line(StyledPanel.Kind.KEYS)
	_push_line(rescued_panel, rescued_label.text, StyleHudText.IDLE, StyleUi.GOLD)
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
	else:
		# The key strip sits on the bottom edge; the burst line sits above the spirit meter's row (Clean HUD, #92).
		p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		p.offset_left = m
		p.offset_right = m + w
		p.offset_bottom = -6.0 if p.kind == StyledPanel.Kind.KEYS else -HudConfig.CLEAN_BURST_BOTTOM
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
	_show_line(hint_label, key_panel, _controls_on)
	_show_line(burst_label, burst_panel, _burst_on)
	for p: StyledPanel in [rescued_panel, burst_panel, key_panel]:
		p.rebuild_look()
	night_label.visible = not styled
	night_bar.visible = not styled
	night_view.visible = styled
	_apply_spirit_look()
	landmark_label.visible = not styled
	end_label.visible = not styled
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


# Top-down: keeps the targeting mode's line (see Config.TargetingMode); the F3 overlay shows it (the level reads it).
func set_targeting(mode: int) -> void:
	targeting_text = "Targeting: " + PlayerConfig.TD_TARGETING_NAMES[mode] + "  [F2]"


func set_rescued(n: int, total: int) -> void:
	rescued_label.text = "Rescued: %d / %d" % [n, total]
	_push_line(rescued_panel, rescued_label.text, StyleHudText.IDLE, StyleUi.GOLD)


# Puts the Rescued counter at the left edge, `y` pixels from the top (the level passes the bottom of the minimap).
func place_rescued_below(y: float) -> void:
	rescued_label.position = Vector2(20, y)
	rescued_panel.position = Vector2(20, y)


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


# Walls and gates: Clean HUD (#92). Shows or hides the controls strip (the level shows it for the first seconds of a
# night and while H is held).
func show_controls(on: bool) -> void:
	if on == _controls_on:
		return
	_controls_on = on
	_show_line(hint_label, key_panel, on)


# True while the controls strip is up.
func controls_shown() -> bool:
	return _controls_on


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
		rec_label.offset_top = HudConfig.CLEAN_REC_TOP
		rec_label.offset_bottom = HudConfig.CLEAN_REC_TOP + HudConfig.CLEAN_REC_HEIGHT
		rec_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		add_child(rec_label)
		# Walls and gates: Recorder catch-up (#60). "Marked" sits just left of REC for a moment after a mark.
		mark_label = Label.new()
		mark_label.text = "Marked"
		mark_label.add_theme_font_size_override("font_size", 20)
		mark_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.6))
		mark_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		mark_label.offset_left = -300
		mark_label.offset_right = -170
		mark_label.offset_top = HudConfig.CLEAN_REC_TOP
		mark_label.offset_bottom = HudConfig.CLEAN_REC_TOP + HudConfig.CLEAN_REC_HEIGHT
		mark_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mark_label.visible = false
		add_child(mark_label)
	rec_label.visible = on
	if not on and mark_label != null:
		mark_label.visible = false


# Walls and gates: Recorder catch-up (#60). Shows "Marked" next to REC for MARK_FLASH_SECONDS. Only while recording.
func flash_marked() -> void:
	if rec_label == null or not rec_label.visible or mark_label == null:
		return
	mark_label.visible = true
	if _mark_tween != null:
		_mark_tween.kill()
	_mark_tween = create_tween()
	_mark_tween.tween_interval(RecorderConfig.MARK_FLASH_SECONDS)
	_mark_tween.tween_callback(mark_label.hide)


# Walls and gates: Capture polish (#75). The people line ("People: 31 on the line, 23 short"), red while it is short.
func set_people(text: String, short: bool) -> void:
	if people_label.text != text:
		people_label.text = text
	var col := BorderConfig.GATE_COUNT_SHORT_COLOUR if short else BorderConfig.GATE_COUNT_OK_COLOUR
	people_label.add_theme_color_override("font_color", col)


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


# Round 22: the HUD panels that an edge pointer keeps clear of (the landmark pointers, see landmark_pointers.gd).
func layout_controls() -> Array[Control]:
	var out: Array[Control] = [
		night_label,
		night_bar,
		burst_label,
		spirit_label,
		spirit_bar,
		people_label,
		hint_label,
		rescued_label,
		landmark_label,
		landmark_panel,
		# Checkpoint 6: the styled look's lines (hidden, so not counted, in the placeholder look).
		rescued_panel,
		burst_panel,
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
