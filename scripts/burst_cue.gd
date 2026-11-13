class_name BurstCue
extends Node

# Round 22 (as GapPatch), round 26 (the F patch is gone): the burst's cue and marks, wired in one place (TopDownMain
# only calls `attach`).
#  - The cue beside the spirit meter ("G: lift N") glows when a burst would lift dimmed people right now.
#  - The burst's report is turned into world marks (BurstFx) and a recorder event; `burst_targets` is the HUD count.
#  - Every BORDER_WARN_INTERVAL the dimmed people outside the border are drawn faded (EdgeDim).

var main: TopDownMain
var fx: BurstFx
var cue_label: Label
var cue_panel: StyledPanel  # Graphics checkpoint 5: the styled look's cue (see StyleDawn.draw_cue).
# Dimmed people a burst from the player's position would clear right now.
var burst_targets: int = 0
# Round 24: true when the cue is ready to act on right now (a burst that would lift people).
var cue_ready: bool = false
var _cue_style := StyleBoxFlat.new()
var _timer: float = 0.0


# Builds the node under `level`, links the player to the border and returns it.
static func attach(level: TopDownMain) -> BurstCue:
	var g := BurstCue.new()
	g.main = level
	level.add_child(g)
	level.player.border = level.border
	g.fx = BurstFx.new()
	level.add_child(g.fx)
	level.player.burst_cleared.connect(g._on_burst_cleared)
	level.border.line_mended.connect(g.fx.add_mend)  # Walls and gates: Style update (#94): the styled mend mark.
	g._build_label()
	return g


func _build_label() -> void:
	cue_label = Label.new()
	cue_label.add_theme_font_size_override("font_size", HudConfig.CUE_FONT_SIZE)
	cue_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	cue_label.add_theme_constant_override("outline_size", 4)
	# Round 24: a small panel on the HUD beside the spirit meter; its border pulses while the cue is ready.
	_cue_style.bg_color = Color(0.08, 0.07, 0.12, 0.7)
	_cue_style.set_corner_radius_all(10)
	_cue_style.set_border_width_all(3)
	_cue_style.content_margin_left = 12.0
	_cue_style.content_margin_right = 12.0
	_cue_style.content_margin_top = 3.0
	_cue_style.content_margin_bottom = 3.0
	cue_label.add_theme_stylebox_override("normal", _cue_style)
	cue_label.visible = false
	main.hud.add_child(cue_label)
	# Graphics checkpoint 5: the styled look draws the same cue as a parchment panel (the Label stays for the placeholder).
	cue_panel = StyledPanel.new()
	cue_panel.kind = StyledPanel.Kind.CUE
	cue_panel.visible = false
	main.hud.add_child(cue_panel)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = BorderConfig.BORDER_WARN_INTERVAL
		burst_targets = BurstClear.count_targets(main.people, main.player.global_position, main.border)
		EdgeDim.update(main.border, main.people, BorderConfig.BORDER_WARN_INTERVAL)
	fx.sync(delta)
	_update_label()


# Round 23: the cue (round 24: on the HUD, just right of the spirit meter, glowing when ready), only when G/Q can be
# acted on right now: "G: lift N" when a burst would lift N dimmed people off the border. Nothing is shown otherwise.
func cue_text() -> String:
	cue_ready = false
	if main.player.can_burst() and main.border.push.breaks_in_reach(main.player.global_position) > 0:
		cue_ready = true  # Walls and gates: Loop tuning (#93): a break in reach is mended by the burst.
		return SpiritConfig.BURST_MEND_CUE_TEXT
	if burst_targets > 0 and main.player.can_burst():
		cue_ready = true
		return HudConfig.CUE_BURST_TEXT % burst_targets
	return ""


func _update_label() -> void:
	var text := cue_text()
	var styled := Looks.is_styled()
	cue_label.visible = text != "" and not styled
	cue_panel.visible = text != "" and styled
	if text == "":
		return
	var screen := main.get_viewport().get_visible_rect().size
	var at := Vector2(
		screen.x * 0.5 + HudConfig.SPIRIT_METER_WIDTH * 0.5 + HudConfig.CUE_HUD_GAP, screen.y + HudConfig.CUE_HUD_Y
	)
	if styled:
		var size := StyleDawn.cue_size(text)
		cue_panel.size = size
		cue_panel.position = Vector2(at.x, at.y - (size.y - 34.0) * 0.5)
		var beat := int(float(Engine.get_process_frames()) / 60.0 * HudConfig.CUE_PULSE_HZ * 4.0) % 4
		cue_panel.set_cue(text, cue_ready, beat)
		return
	cue_label.text = text
	cue_label.position = at
	var pulse := 0.5 + 0.5 * sin(float(Engine.get_process_frames()) / 60.0 * TAU * HudConfig.CUE_PULSE_HZ)
	var edge := HudConfig.CUE_READY_COLOUR
	edge.a = 0.55 + 0.45 * pulse
	_cue_style.border_color = edge
	_cue_style.bg_color = Color(0.2, 0.17, 0.05, 0.85)
	cue_label.add_theme_color_override("font_color", HudConfig.CUE_READY_COLOUR)


# The player's burst happened: draw the clearing, let the line near it spring back and tell the recorder what it did.
func _on_burst_cleared(report: Dictionary) -> void:
	var cleared: Array = report["cleared"]
	fx.add_burst(cleared)
	fx.add_lift_result(cleared)
	for c: Dictionary in cleared:  # Round 24: each lifted person perks up.
		(c["person"] as Person).react(Person.React.LIFT, PeopleConfig.REACT_LIFT_SECONDS)
	if main.recorder != null:
		var ids: Array = []
		for c: Dictionary in cleared:
			ids.append(main.people.find(c["person"]))
		(
			main
			. recorder
			. emit_event(
				"burst_clear",
				{
					"lifted": report["lifted"],
					"joy_hits": report["joy_hits"],
					"ids": ids,
					"gaps_open": main.border.gap_count(),
					"spirit_after": snappedf(main.player.spirit, 0.1),
				}
			)
		)
