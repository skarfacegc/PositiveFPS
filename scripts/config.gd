class_name Config
extends RefCounted

# All tuning values for the prototype live here. Change a number and run the game to feel the difference.

# The three elements. Each person has an affinity for one of them, and the player picks one to shoot with.
enum Element { MUSIC, ART, NATURE }

# Display names, in the same order as the Element enum.
const ELEMENT_NAMES := ["Music", "Art", "Nature"]

# Colours for each element, in the same order as the Element enum.
# They are used for the person's floating marker, the beam, the HUD text and the painted ground.
const ELEMENT_COLORS := [Color(0.25, 0.5, 1.0), Color(1.0, 0.4, 0.7), Color(0.3, 0.85, 0.35)]

# Grey used for level geometry (the floor, walls and blocks use their own greys in main.gd).
const GREY := Color(0.55, 0.55, 0.55)

# How long one round lasts, in seconds (120 = 2 minutes).
const ROUND_SECONDS := 120.0

# How many people are spawned in the plaza. Rescuing all of them ends the round early.
const PEOPLE_COUNT := 20

# Joy needed for a person at light grey (darker levels need more, see LEVEL_JOY_MULT).
const JOY_MAX := 1000.0

# Base joy added by one beam hit, before the element multiplier and distance falloff are applied.
const JOY_PER_SHOT := 37.5

# How many beam shots the player can fire per second while holding the fire button.
const SHOTS_PER_SECOND := 8.0

# How far the beam reaches, in metres.
const BEAM_RANGE := 40.0

# Walking speed, in metres per second.
const WALK_SPEED := 5.0

# Speed while holding Shift, in metres per second.
const RUN_SPEED := 8.5

# How hard the player jumps. Higher means a higher jump.
const JUMP_VELOCITY := 4.5

# How fast the view turns with the mouse. Higher means faster turning.
const MOUSE_SENSITIVITY := 0.0025

# Damage multipliers for the element matchups (see multiplier() below).
const MATCH_MULT := 2.0   # Same element as the person's affinity.
const STRONG_MULT := 1.5  # The element beats the person's affinity.
const WEAK_MULT := 1.0    # The element loses to the person's affinity.

# Distance falloff: beam joy is strongest close up and weakens with distance (see falloff() below).
const FALLOFF_NEAR := 4.0    # Metres. Full strength at or closer than this.
const FALLOFF_FAR := 22.0    # Metres. Weakest strength at or beyond this.
const FALLOFF_MIN := 0.25    # Strength at or beyond FALLOFF_FAR (25%).

# Gloom: a hidden 0.0 (light) to 1.0 (nearly black) value. It is shown as three stepped levels.
const GLOOM_START_MIN := 0.0            # Random starting gloom for each person, lowest...
const GLOOM_START_MAX := 0.5            # ...and highest.
const GLOOM_GROWTH := 0.006             # Gloom gained per second by an unrescued person, base rate.
const GLOOM_GROWTH_PER_METER := 0.0008  # Extra gloom per second for each metre from the nearest colour zone.
const ZONE_RADIUS := 6.0                # Each rescued person creates a colour zone of this radius (metres).
const ZONE_HEAL := 0.02                 # Gloom lost per second by unrescued people inside a colour zone.
const SPREAD_RADIUS := 6.0              # How far darkness spreads from a dark person (metres).
const SPREAD_GLOOM_RATE := 0.03         # Gloom per second given to nearby unrescued people by a dark person.
const SPREAD_DRAIN_RATE := 60.0         # Joy per second drained from nearby rescued people by a dark person.

# The three visible grey levels. Gloom below the first step is light, below the second is grey, else dark.
const GLOOM_LEVEL_STEPS := [0.34, 0.67]
# Body colour for each level (0 light, 1 grey, 2 dark).
const LEVEL_COLORS := [Color(0.82, 0.82, 0.82), Color(0.5, 0.5, 0.52), Color(0.16, 0.16, 0.18)]
# Joy needed at each level, as a multiple of JOY_MAX. Darker people need more joy.
const LEVEL_JOY_MULT := [1.0, 1.5, 2.0]
# Only people at this level or darker spread darkness (2 = only dark people).
const SPREAD_LEVEL := 2

# Joy fading: partly-helped people drain back toward grey if nobody keeps hitting them.
const JOY_FADE_DELAY := 1.5             # Seconds without a hit before an unrescued person's joy starts to fade.
const JOY_FADE_RATE := 120.0            # Joy lost per second while fading.

# Relapse: a rescued person whose joy falls below this fraction of their joy needed turns grey again.
const RELAPSE_FRACTION := 0.5
# Warning: below this fraction a rescued person starts flickering and shows "!" (before they relapse).
const WARN_FRACTION := 0.85

# Painted ground: tiles around rescued people take on their element colour.
const GROUND_GREY := Color(0.5, 0.5, 0.5)  # Unpainted ground colour.
const GROUND_PAINT_STRENGTH := 0.75        # How strongly the paint colour shows right next to a rescued person (0-1).
const GROUND_PAINT_SPEED := 0.15           # How fast each tile moves toward its target colour per update (0-1).
const GROUND_UPDATE_INTERVAL := 0.1        # Seconds between ground colour updates.

# Show the Borderlands-style floating joy numbers when a beam hits someone.
const NUMBERS_ENABLED := true

# Buildings unlocked on the end screen. Each entry is [rescues needed, building name].
const BUILDING_THRESHOLDS := [[5, "Cafe"], [10, "Music Shop"], [15, "Community Garden"], [20, "Plaza Fountain"]]

# The matchups form a soft cycle:
#   Music is strong against Art, Art is strong against Nature, Nature is strong against Music.
# Matching the affinity gives MATCH_MULT. The element that loses to the affinity gives WEAK_MULT.


# Returns how much a hit with `element` is multiplied when the person has `affinity`.
static func multiplier(element: int, affinity: int) -> float:
	if element == affinity:
		return MATCH_MULT
	if affinity == (element + 1) % 3:
		return STRONG_MULT
	return WEAK_MULT


# Returns the strength of a beam hit at `distance` metres: 1.0 up close, falling to FALLOFF_MIN far away.
static func falloff(distance: float) -> float:
	if distance <= FALLOFF_NEAR:
		return 1.0
	if distance >= FALLOFF_FAR:
		return FALLOFF_MIN
	var t := (distance - FALLOFF_NEAR) / (FALLOFF_FAR - FALLOFF_NEAR)
	return lerpf(1.0, FALLOFF_MIN, t)


# Returns the visible grey level (0 light, 1 grey, 2 dark) for a hidden gloom value.
static func gloom_level(g: float) -> int:
	if g < GLOOM_LEVEL_STEPS[0]:
		return 0
	if g < GLOOM_LEVEL_STEPS[1]:
		return 1
	return 2


# Returns the names of all buildings unlocked by `count` rescued people.
static func buildings_for(count: int) -> Array:
	var result: Array = []
	for entry in BUILDING_THRESHOLDS:
		if entry[0] <= count:
			result.append(entry[1])
	return result
