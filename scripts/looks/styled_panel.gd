class_name StyledPanel
extends Control

# Graphics checkpoint 3: a HUD panel that has a styled drawing and nothing in the placeholder look (where the HUD's
# Labels show the same information). One of three kinds: the landmark panel (top right), the dawn rating end screen or
# (graphics checkpoint 4) the alert banner (a claim, a loss or a relapse notice). The Hud feeds it the same data its
# Labels show and flips it with `rebuild_look()` when the look changes.

enum Kind { LANDMARKS, DAWN, ALERT, CUE }

var kind: int = Kind.LANDMARKS
# LANDMARKS: which landmarks are held, in Config.LANDMARK_NAMES order.
var held: Array[bool] = []
# DAWN: the end screen's title, detail text and rating (empty when the round was lost).
var title: String = ""
var detail: String = ""
var rating: Dictionary = {}
# ALERT: the notice and its colour (the Hud fades the panel with its modulate).
var alert_text: String = ""
var alert_colour: Color = Color.WHITE
# CUE (graphics checkpoint 5): the "F: patch" / "G: lift N" panel beside the spirit meter. `cue_ready` lights it gold;
# `cue_beat` (0 to 3) steps the pulse of its rim.
var cue_text: String = ""
var cue_ready: bool = false
var cue_beat: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_landmarks(flags: Array[bool]) -> void:
	if flags == held:
		return
	held = flags.duplicate()
	queue_redraw()


func set_dawn(new_title: String, new_detail: String, new_rating: Dictionary) -> void:
	title = new_title
	detail = new_detail
	rating = new_rating
	queue_redraw()


func set_alert(text: String, colour: Color) -> void:
	alert_text = text
	alert_colour = colour
	queue_redraw()


# Sets the cue panel's words, whether it is ready (gold) and the step of its pulse; redraws only when one changed.
func set_cue(text: String, ready: bool, beat: int) -> void:
	if text == cue_text and ready == cue_ready and beat == cue_beat:
		return
	cue_text = text
	cue_ready = ready
	cue_beat = beat
	queue_redraw()


# True when this panel is drawn (the styled look is on).
func is_drawn() -> bool:
	return Looks.is_styled()


# Redraws for the current look.
func rebuild_look() -> void:
	queue_redraw()


func _draw() -> void:
	if not Looks.is_styled():
		return
	if kind == Kind.LANDMARKS:
		StyleDawn.draw_landmarks(self, held)
	elif kind == Kind.ALERT:
		StyleDawn.draw_alert(self, alert_text, alert_colour)
	elif kind == Kind.CUE:
		StyleDawn.draw_cue(self, cue_text, cue_ready, cue_beat)
	else:
		StyleDawn.draw_dawn(self, title, detail, rating)
