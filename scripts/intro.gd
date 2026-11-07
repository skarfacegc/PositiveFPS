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

enum Prompt {
	GAP,
	GUARDED,
	SKITTISH,
	GLUM,
	SHELTERED,
	SPIRIT_LOW,
	DIM,
	DIM_HELP,
	BEACON_SPIRIT,
	BEACON_BORDER,
	BEACON_BLOCKED,
	BEACON_FELL_BACK,
	ZONE_PULLED_IN,
	PATCH_SPIRIT,
	PATCH_NONE,
	PATCH_ALREADY,
	PATCH_MAX,
	FIRST_LIGHT,  # Snag round: the notice when first light starts (first_light.gd).
	TIDE  # Round 25: the notice when a gloom tide is coming (gloom_tide.gd; the words name the side).
}

var enabled: bool = true
var night: NightCycle
# The prompt on show (a Prompt value, or -1 for none), the seconds it has left, and the ones waiting.
var current: int = -1
var time_left: float = 0.0
# Round 22: a notice (a refusal or a fall-back) stays NOTICE_SECONDS in a larger bar near the middle of the screen,
# and may
# carry its own words (the plan's reason). The ordinary prompts keep PROMPT_SECONDS.
var duration: float = Config.PROMPT_SECONDS
var big: bool = false
var custom_text: String = ""
var queue: Array[int] = []
# Where the current prompt points in the world (Vector3.INF for none: it sits at the bottom centre).
var anchor := Vector3.INF
# Every prompt that was shown or queued this level, so each appears once.
var shown: Dictionary = {}
var _queued_anchor: Dictionary = {}
var _check_timer: float = 0.0


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


# Asks to show prompt `id`. It is queued unless it was already shown or queued (returns false then, and always when
# the
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


# Round 19: shows prompt `id` now, every time it is asked (a notice, not a one-time lesson). Works with the intro
# off too, so tests can read `current`.
func notice(id: int, words: String = "") -> void:
	queue.erase(id)
	current = id
	anchor = Vector3.INF
	big = true
	custom_text = words
	duration = Config.NOTICE_SECONDS
	time_left = duration


# The words of the prompt on show (a notice may carry its own).
func current_text() -> String:
	return custom_text if custom_text != "" else text_for(current)


# Round 13b: asks for the one-time prompts when something first happens in `main`'s level. Checked every
# INTRO_CHECK_SECONDS. (Moved here from topdown_main.gd in round 19.)
func check_level(main: TopDownMain, delta: float) -> void:
	if not enabled:
		return
	_check_timer += delta
	if _check_timer < Config.INTRO_CHECK_SECONDS:
		return
	_check_timer = 0.0
	if dimmed_allowed() and not main.feedback.markers.is_empty():
		var faltering: Person = main.feedback.markers[0]["person"]
		request(Prompt.GAP, faltering.global_position)
	var view := main.get_viewport().get_visible_rect().grow(-40.0)
	for p: Person in main.people:
		if GloomSim.is_dimmed(p) and view.has_point(main.world_to_screen(p.global_position)):
			request(Prompt.DIM_HELP)
	for p: Person in main.people:
		if p.is_rescued:
			continue
		var m := p.active_mood()
		if (m == Person.Mood.NONE and not p.sheltered) or not view.has_point(main.world_to_screen(p.global_position)):
			continue
		if m != Person.Mood.NONE:
			request(prompt_for_mood(m))
		if p.sheltered:
			request(Prompt.SHELTERED)
	if main.player.is_dim:
		request(Prompt.DIM)
	elif main.player.spirit < Config.BURST_SPIRIT_COST:
		request(Prompt.SPIRIT_LOW)


# Counts the current prompt down and moves on to the next one in the queue.
func update(delta: float) -> void:
	if current < 0:
		return
	time_left -= delta
	if time_left <= 0.0:
		current = -1
		anchor = Vector3.INF
		_reset_look()
		_next()


func _next() -> void:
	if queue.is_empty():
		return
	current = queue.pop_front()
	_reset_look()
	time_left = duration
	anchor = _queued_anchor.get(current, Vector3.INF)


func _reset_look() -> void:
	big = false
	custom_text = ""
	duration = Config.PROMPT_SECONDS


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
			return "Sheltered — a little joy gets through; the umbrella breaks after a few hits"
		Prompt.SPIRIT_LOW:
			return "Spirit low — rescue people to refill"
		Prompt.DIM_HELP:
			return Config.DIM_HELP_TEXT
		Prompt.BEACON_SPIRIT:
			return Config.BEACON_NO_SPIRIT_TEXT
		Prompt.BEACON_BORDER:
			return Config.BEACON_NO_BORDER_TEXT
		Prompt.BEACON_BLOCKED:
			return Config.BEACON_BLOCKED_TEXT
		Prompt.BEACON_FELL_BACK:
			return Config.BEACON_FELL_BACK_TEXT
		Prompt.ZONE_PULLED_IN:
			return Config.BEACON_PULLED_IN_TEXT
		Prompt.PATCH_SPIRIT:
			return Config.PATCH_SPIRIT_TEXT
		Prompt.PATCH_NONE:
			return Config.PATCH_NONE_TEXT
		Prompt.PATCH_ALREADY:
			return Config.PATCH_ALREADY_TEXT
		Prompt.PATCH_MAX:
			return Config.PATCH_MAX_TEXT
		Prompt.FIRST_LIGHT:
			return Config.FIRST_LIGHT_TEXT
		Prompt.TIDE:
			return Config.TIDE_PLAIN_TEXT
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
		Prompt.TIDE:
			return MoodIcons.Kind.CLOUD
		Prompt.BEACON_SPIRIT, Prompt.BEACON_BORDER, Prompt.BEACON_BLOCKED, Prompt.BEACON_FELL_BACK, Prompt.ZONE_PULLED_IN:
			return MoodIcons.Kind.BANG
	return MoodIcons.Kind.NONE
