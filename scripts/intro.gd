class_name Intro
extends RefCounted

# Round 13b, the layered introduction through the night. It is driven by the night's progress (NightCycle), so the
# game teaches one thing at a time:
#   dusk (until NIGHT_CALM_FRACTION): just rescuing and growing: nobody sinks to dimmed yet and no mood is active;
#   then dimmed people emerge and press (the first gap gets a prompt);
#   then moods switch on one type at a time (Config.MOOD_INTRO_FRACTIONS), each with a one-time prompt.
# This class holds the unlock rules and the prompt queue (one prompt at a time, each shown once per level,
# PROMPT_SECONDS long). The level asks for prompts when something first happens; PromptBar draws the current one.
# With `enabled` false (the default in automated tests, see Config.intro_on()) everything is available at once and
# no prompt ever shows.

enum Prompt { GAP, GUARDED, SKITTISH, GLUM, SHELTERED, SPIRIT_LOW, DIM }

var enabled: bool = true
var night: NightCycle
# The prompt on show (a Prompt value, or -1 for none), the seconds it has left, and the ones waiting.
var current: int = -1
var time_left: float = 0.0
var queue: Array[int] = []
# Where the current prompt points in the world (Vector3.INF for none: it sits at the bottom centre).
var anchor := Vector3.INF
# Every prompt that was shown or queued this level, so each appears once.
var shown: Dictionary = {}
var _queued_anchor: Dictionary = {}


func _init(night_cycle: NightCycle = null, is_enabled: bool = true) -> void:
	night = night_cycle
	enabled = is_enabled


# True once dimmed people may emerge (the calm opening is over). Always true when the intro is off.
func dimmed_allowed() -> bool:
	if not enabled:
		return true
	return night.progress() >= Config.NIGHT_CALM_FRACTION


# True when `mood` (a Person.Mood) is switched on. Always true when the intro is off.
func mood_active(mood: int) -> bool:
	if not enabled or mood == Person.Mood.NONE:
		return true
	return night.progress() >= Config.MOOD_INTRO_FRACTIONS[clampi(mood, 0, Config.MOOD_INTRO_FRACTIONS.size() - 1)]


# Asks to show prompt `id`. It is queued unless it was already shown or queued (returns false then, and always when the
# intro is off). `at` is an optional world point the prompt sits near.
func request(id: int, at: Vector3 = Vector3.INF) -> bool:
	if not enabled or shown.has(id):
		return false
	shown[id] = true
	_queued_anchor[id] = at
	queue.append(id)
	if current < 0:
		_next()
	return true


# Counts the current prompt down and moves on to the next one in the queue.
func update(delta: float) -> void:
	if current < 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		current = -1
		anchor = Vector3.INF
		_next()


func _next() -> void:
	if queue.is_empty():
		return
	current = queue.pop_front()
	time_left = Config.PROMPT_SECONDS
	anchor = _queued_anchor.get(current, Vector3.INF)


# The prompt for a mood (Person.Mood).
static func prompt_for_mood(mood: int) -> int:
	match mood:
		Person.Mood.GUARDED:
			return Prompt.GUARDED
		Person.Mood.SKITTISH:
			return Prompt.SKITTISH
	return Prompt.GLUM


# The short line of a prompt (the icon sits beside it).
static func text_for(id: int) -> String:
	match id:
		Prompt.GAP:
			return "A gap! Help the faltering one (!) to close it."
		Prompt.GUARDED:
			return "Guarded — reach them from the front"
		Prompt.SKITTISH:
			return "Skittish — walk, don't run"
		Prompt.GLUM:
			return "Glum — help when they look up"
		Prompt.SHELTERED:
			return "Sheltered — draw the dimmed one away"
		Prompt.SPIRIT_LOW:
			return "Spirit low — rescue people to refill"
	return "You're dim — rest inside your border"


# The icon (MoodIcons.Kind) that goes with a prompt.
static func icon_for(id: int) -> int:
	match id:
		Prompt.GAP:
			return MoodIcons.Kind.BANG
		Prompt.GUARDED:
			return MoodIcons.Kind.SHIELD
		Prompt.SKITTISH:
			return MoodIcons.Kind.FEET
		Prompt.GLUM:
			return MoodIcons.Kind.CLOUD
		Prompt.SHELTERED:
			return MoodIcons.Kind.UMBRELLA
	return MoodIcons.Kind.NONE
