class_name Config
extends RefCounted

# All tuning values for the prototype live here. Change a number and run the game to feel the difference.

# The three elements. Each person has an affinity for one of them, and the player picks one to shoot with.
enum Element { MUSIC, ART, NATURE }

# Display names, in the same order as the Element enum.
const ELEMENT_NAMES: Array[String] = ["Music", "Art", "Nature"]

# Colours for each element, in the same order as the Element enum.
# They are used for the person's floating marker, the beam, the HUD text and the painted ground.
const ELEMENT_COLORS: Array[Color] = [Color(0.25, 0.5, 1.0), Color(1.0, 0.4, 0.7), Color(0.3, 0.85, 0.35)]

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
const MATCH_MULT := 2.0  # Same element as the person's affinity.
const STRONG_MULT := 1.5  # The element beats the person's affinity.
const WEAK_MULT := 1.0  # The element loses to the person's affinity.

# Distance falloff: beam joy is strongest close up and weakens with distance (see falloff() below).
const FALLOFF_NEAR := 4.0  # Metres. Full strength at or closer than this.
const FALLOFF_FAR := 22.0  # Metres. Weakest strength at or beyond this.
const FALLOFF_MIN := 0.25  # Strength at or beyond FALLOFF_FAR (25%).

# Gloom: a hidden 0.0 (light) to 1.0 (nearly black) value. It is shown as three stepped levels.
const GLOOM_START_MIN := 0.0  # Random starting gloom for each person, lowest...
const GLOOM_START_MAX := 0.5  # ...and highest.
const GLOOM_GROWTH := 0.006  # Gloom gained per second by an unrescued person, base rate.
const GLOOM_GROWTH_PER_METER := 0.0008  # Extra gloom per second for each metre from the nearest colour zone.
const NO_ZONE_DISTANCE := 20.0  # Gloom growth distance when nobody is rescued yet (no colour zones).
const ZONE_RADIUS := 6.0  # Each rescued person creates a colour zone of this radius (metres).
const ZONE_HEAL := 0.02  # Gloom lost per second by unrescued people inside a colour zone.
const SPREAD_RADIUS := 6.0  # How far darkness spreads from a dark person (metres).
const SPREAD_GLOOM_RATE := 0.03  # Gloom per second given to nearby unrescued people by a dark person.
const SPREAD_DRAIN_RATE := 60.0  # Joy per second drained from nearby rescued people by a dark person.

# The three visible grey levels. Gloom below the first step is light, below the second is grey, else dark.
const GLOOM_LEVEL_STEPS: Array[float] = [0.34, 0.67]
# Body colour for each level (0 light, 1 grey, 2 dark).
const LEVEL_COLORS: Array[Color] = [Color(0.82, 0.82, 0.82), Color(0.5, 0.5, 0.52), Color(0.16, 0.16, 0.18)]
# Joy needed at each level, as a multiple of JOY_MAX. Darker people need more joy.
const LEVEL_JOY_MULT: Array[float] = [1.0, 1.5, 2.0]
# Only people at this level or darker spread darkness (2 = only dark people).
const SPREAD_LEVEL := 2

# Joy fading: partly-helped people drain back toward grey if nobody keeps hitting them.
const JOY_FADE_DELAY := 1.5  # Seconds without a hit before an unrescued person's joy starts to fade.
const JOY_FADE_RATE := 120.0  # Joy lost per second while fading.

# Relapse: a rescued person whose joy falls below this fraction of their joy needed turns grey again.
const RELAPSE_FRACTION := 0.5
# Warning: below this fraction a rescued person starts flickering and shows "!" (before they relapse).
const WARN_FRACTION := 0.85

# Painted ground: tiles around rescued people take on their element colour.
const GROUND_GREY := Color(0.5, 0.5, 0.5)  # Unpainted ground colour.
const GROUND_PAINT_STRENGTH := 0.75  # How strongly the paint colour shows right next to a rescued person (0-1).
const GROUND_PAINT_SPEED := 0.15  # How fast each tile moves toward its target colour per update (0-1).
const GROUND_UPDATE_INTERVAL := 0.1  # Seconds between ground colour updates.

# Show the Borderlands-style floating joy numbers when a beam hits someone.
const NUMBERS_ENABLED := true

# Buildings unlocked on the end screen. Each entry is [rescues needed, building name].
const BUILDING_THRESHOLDS := [[5, "Cafe"], [10, "Music Shop"], [15, "Community Garden"], [20, "Plaza Fountain"]]

# ---- Top-down mode (scripts/topdown_*.gd, joy_projectile.gd). All names start with TD_. ----

# Side length of the top-down plaza, in metres. Walls go around the edge.
const TD_PLAZA_SIZE := 70
# How many people are in the top-down plaza.
const TD_PEOPLE_COUNT := 60
# Length of a top-down round, in seconds.
const TD_ROUND_SECONDS := 150.0
# Seed for every gameplay random number (top-down placement and wandering, cosmetic jitter). Gameplay code
# uses its own seeded RandomNumberGenerator, never the global randf(), so a run is repeatable.
const RNG_SEED := 42
# Buildings unlocked on the top-down end screen. Same format as BUILDING_THRESHOLDS.
const TD_BUILDING_THRESHOLDS := [[15, "Cafe"], [30, "Music Shop"], [45, "Community Garden"], [60, "Plaza Fountain"]]
# Camera height above the player, in metres.
const TD_CAMERA_HEIGHT := 24.0
# How far behind the player the camera sits, in metres. The camera looks down at the player.
const TD_CAMERA_BACK := 12.0
# Walking speed, in metres per second.
const TD_MOVE_SPEED := 6.0
# Speed while holding Shift, in metres per second.
const TD_RUN_SPEED := 9.5
# Auto-fire reaches people this close, in metres.
const TD_AUTO_RANGE := 11.0
# If a person is this close to the mouse aim point, auto-fire picks them over the nearest person.
const TD_AIM_ASSIST_RADIUS := 3.5
# Auto-fire shots per second.
const TD_SHOTS_PER_SECOND := 5.0
# Joy added by each auto-fire shot (before the element multiplier and distance falloff).
const TD_JOY_PER_SHOT := 45.0
# Speed of the visual joy projectiles, in metres per second. Hits are instant; this only changes how they look.
const TD_PROJECTILE_SPEED := 16.0
# The shortest a projectile's flight can take, in seconds.
const TD_PROJECTILE_MIN_TIME := 0.08
# How high projectiles arc over their flight, in metres.
const TD_PROJECTILE_ARC := 0.8
# How far music notes wobble from side to side, in metres.
const TD_PROJECTILE_BOB := 0.3
# How fast flower projectiles spin, in radians per second.
const TD_FLOWER_SPIN := 8.0
# Radius of the paint splat left by an Art projectile, in metres.
const TD_SPLAT_RADIUS := 0.6
# How solid the paint splat is (1 = solid, 0 = invisible).
const TD_SPLAT_ALPHA := 0.6
# Seconds for a paint splat to fade away.
const TD_SPLAT_FADE_TIME := 2.5
# Walking speed for wandering people, in metres per second.
const TD_WANDER_SPEED := 0.8
# Wandering people pick a new spot within this distance of where they are, in metres.
const TD_WANDER_RANGE := 4.0
# A wandering person counts as having reached their spot when this close, in metres.
const TD_WANDER_REACH := 0.5
# Wandering people pick a new spot after a random time between these two values, in seconds.
const TD_WANDER_TIME_MIN := 3.0
const TD_WANDER_TIME_MAX := 6.0
# Dark people drift toward the nearest rescued person at this speed, in metres per second.
const TD_DARK_DRIFT_SPEED := 1.3
# Dark people stop drifting when this close to a rescued person, in metres.
const TD_DARK_STOP_DISTANCE := 2.0
# People stay this far inside the plaza walls, in metres.
const TD_EDGE_MARGIN := 2.0
# People are placed at least this far from the plaza edge, in metres.
const TD_SPAWN_EDGE := 3.0
# People are never placed closer than this to the centre (where the player starts), in metres.
const TD_SPAWN_CENTRE_CLEAR := 5.0
# Minimum distance between two people when placing them, in metres.
const TD_SPAWN_SPACING := 2.5
# Distance kept beyond an obstacle block's edge, for spawning and walking, in metres.
const TD_BLOCK_CLEARANCE := 1.5
# Seconds before the joy burst can be used again.
const TD_BURST_COOLDOWN := 8.0
# Everyone this close to the player gets the burst, in metres.
const TD_BURST_RADIUS := 5.5
# Joy given to each person by a burst. They use their own element, so it always counts as a match.
const TD_BURST_JOY := 350.0
# How long the burst ring takes to expand and fade, in seconds.
const TD_BURST_TIME := 0.35
# Size multiplier for floating numbers and labels in top-down mode (the camera is high up).
const TD_UI_SCALE := 2.5

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
# Pass a different thresholds array (same format) to use another mode's list.
static func buildings_for(count: int, thresholds: Array = BUILDING_THRESHOLDS) -> Array:
	var result: Array = []
	for entry: Array in thresholds:
		if entry[0] <= count:
			result.append(entry[1])
	return result


# True when the game is running under the automated tests (tools/run_tests.py): the POSITIVEFPS_TEST=1
# environment variable, a "--automated-test" user argument, or a headless display. In that mode the game
# never captures the real OS mouse, so a test run can never grab a player's mouse.
static func is_automated_test() -> bool:
	if OS.get_environment("POSITIVEFPS_TEST") == "1":
		return true
	if "--automated-test" in OS.get_cmdline_user_args():
		return true
	return DisplayServer.get_name() == "headless"
