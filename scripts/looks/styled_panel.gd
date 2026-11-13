class_name StyledPanel
extends Control

# Graphics checkpoint 3: a HUD panel that has a styled drawing and nothing in the placeholder look (where the HUD's
# Labels show the same information). One of three kinds: the landmark panel (top right), the dawn rating end screen or
# (graphics checkpoint 4) the alert banner (a claim, a loss or a relapse notice). The Hud feeds it the same data its
# Labels show and flips it with `rebuild_look()` when the look changes.

# Walls and gates: Style update (#94): PEOPLE is the people line under the spirit meter (a text line like the others)
# and PREVIEW the take preview's small panel (several lines in `line_text`, a coral rim when `line_state` is WARN).
enum Kind { LANDMARKS, DAWN, ALERT, CUE, RESCUED, BURST, TARGET, TARGETING, KEYS, PEOPLE, PREVIEW }

var kind: int = Kind.LANDMARKS
# LANDMARKS: which landmarks are held, in LandmarkConfig.LANDMARK_NAMES order.
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
# Checkpoint 6, RESCUED / BURST / TARGET / TARGETING / KEYS: one line of HUD text with its state (StyleHudText.IDLE,
# READY, WARN or DIM) and the colour of its badge (the target's element, gold for the rescued count).
var line_text: String = ""
var line_state: int = 0
var line_colour: Color = Color.WHITE


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


# Sets a text line panel's words, state and badge colour. Returns true when one of them changed (it redraws then).
func set_line(text: String, state: int, colour: Color) -> bool:
	if text == line_text and state == line_state and colour == line_colour:
		return false
	line_text = text
	line_state = state
	line_colour = colour
	queue_redraw()
	return true


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
	elif kind == Kind.PREVIEW:
		StyleHud.draw_preview(self, line_text, line_state == StyleHudText.WARN)
	elif kind >= Kind.RESCUED:
		StyleHudText.draw(self, kind, line_text, line_state, line_colour)
	else:
		StyleDawn.draw_dawn(self, title, detail, rating)
