class_name Config
extends RefCounted

# Shared tuning: the world scale, the elements and the joy matchups, and the tiny pure helpers. Every other
# system's numbers live in its own *_config.gd (BorderConfig, PushConfig, NightConfig, PeopleConfig ...): find a
# constant by name in SOURCE_MAP.md or by searching scripts/*_config.gd. New constants go in the config of the
# system they tune; a constant that reads another config's value names it (BorderConfig.X).

# The three elements. Each person has an affinity for one of them. Every shot uses the target's element.
enum Element { MUSIC, ART, NATURE }
# Top-down targeting modes (see PlayerConfig.TD_TARGETING_MODE).
enum TargetingMode { LOCK_ON, HOVER_STICKY, AUTO }

# Round 13a: world scale. The plaza went from 70 m to 100 m across (WORLD_SCALE), with the same 60 people.
# THE RULE: a constant is multiplied by WORLD_SCALE if it is about TERRITORY (how big a land the rules cover: plaza,
# block and landmark positions, spawn margins and spacing, border spacing / gap / push / radii / bands / steps, cover,
# erosion, colour-zone and contagion radii, search and edge-pressure reach). It is left alone if it is about
# INTERACTION or a BODY (person and block sizes, projectile ranges and speeds, TD_AUTO_RANGE, GRAB_*, SHELTER_RADIUS,
# SKITTISH_RADIUS, hit and click radii, burst radius, press range). A per-metre rate is divided by WORLD_SCALE so the
# same fraction of the way across the land gives the same rate. Speeds are tuned by hand (player, dimmed drift +10%).
const WORLD_SCALE := 100.0 / 70.0

# Display names, in the same order as the Element enum.
const ELEMENT_NAMES: Array[String] = ["Music", "Art", "Nature"]

# Colours for each element, in the same order as the Element enum. They are used for the person's floating marker, the
# projectiles, the HUD text and the painted ground.
const ELEMENT_COLORS: Array[Color] = [Color(0.25, 0.5, 1.0), Color(1.0, 0.4, 0.7), Color(0.3, 0.85, 0.35)]

# Joy needed for a person at light grey (dimmer levels need more, see LEVEL_JOY_MULT).
const JOY_MAX := 1000.0

# Damage multipliers for the element matchups (see multiplier() below).
const MATCH_MULT := 2.0  # Same element as the person's affinity.
const STRONG_MULT := 1.5  # The element beats the person's affinity.
const WEAK_MULT := 1.0  # The element loses to the person's affinity.

# Distance falloff: joy is strongest close up and weakens with distance (see falloff() below).
const FALLOFF_NEAR := 4.0  # Metres. Full strength at or closer than this.
const FALLOFF_FAR := 22.0  # Metres. Weakest strength at or beyond this.
const FALLOFF_MIN := 0.25  # Strength at or beyond FALLOFF_FAR (25%).

# The three visible grey levels. Gloom below the first step is light, below the second is grey, else dimmed.
const GLOOM_LEVEL_STEPS: Array[float] = [0.34, 0.67]

# Show the Borderlands-style floating joy numbers when a joy projectile hits someone.
const NUMBERS_ENABLED := true

# Side length of the top-down plaza, in metres. Walls go around the edge.
const TD_PLAZA_SIZE := 114  # The town grid's span (TownGrid.span: 4 x 12 + 18 + 4 x 12), 0.4 Grid fixes; was 100.

# How many people are in the top-down plaza.
const TD_PEOPLE_COUNT := 60

# Seed for every gameplay random number (top-down placement and wandering, cosmetic jitter). Gameplay code uses its
# own seeded RandomNumberGenerator, never the global randf(), so a run is repeatable.
const RNG_SEED := 42

# People stay this far inside the plaza walls, in metres.
const TD_EDGE_MARGIN := 2.0

# The renderer reserves this many vec4 of rendering/limits/global_shader_variables/buffer_size for every mesh whose
# material declares an `instance uniform` (a fixed engine cost, hidden meshes included).
const SNAG_INSTANCE_VEC4S := 16
const CP7_LOOK_ARG := "--look="  # The user argument that picks the starting look (--look=styled or placeholder).

static var intro_override: int = -1
static var tides_override: int = -1  # Round 25: as intro_override, for the gloom tides (see tides_on).

# The matchups form a soft cycle:
#   Music is strong against Art, Art is strong against Nature, Nature is strong against Music.
# Matching the affinity gives MATCH_MULT. The element that loses to the affinity gives WEAK_MULT.


# True when the layered introduction (round 13b) is on: always in the game, never under automated tests, unless a test
# sets `intro_override` to 1 (on) or 0 (off). -1 means no override.
static func intro_on() -> bool:
	if intro_override >= 0:
		return intro_override == 1
	return not is_automated_test()


# Round 25: the gloom tides run in the game and not under automated tests (like the intro), so the older scenario suites
# see no tide warnings or notices. A test sets `tides_override` to 1 (on) or 0 (off), and back to -1.
static func tides_on() -> bool:
	if tides_override >= 0:
		return tides_override == 1
	return not is_automated_test()


# Returns how much a hit with `element` is multiplied when the person has `affinity`.
static func multiplier(element: int, affinity: int) -> float:
	if element == affinity:
		return MATCH_MULT
	if affinity == (element + 1) % 3:
		return STRONG_MULT
	return WEAK_MULT


# Returns the strength of a hit at `distance` metres: 1.0 up close, falling to FALLOFF_MIN far away.
static func falloff(distance: float) -> float:
	if distance <= FALLOFF_NEAR:
		return 1.0
	if distance >= FALLOFF_FAR:
		return FALLOFF_MIN
	var t := (distance - FALLOFF_NEAR) / (FALLOFF_FAR - FALLOFF_NEAR)
	return lerpf(1.0, FALLOFF_MIN, t)


# Returns the visible grey level (0 light, 1 grey, 2 dimmed) for a hidden gloom value.
static func gloom_level(g: float) -> int:
	if g < GLOOM_LEVEL_STEPS[0]:
		return 0
	if g < GLOOM_LEVEL_STEPS[1]:
		return 1
	return 2


# True when the game is running under the automated tests (tools/run_tests.py): the POSITIVEFPS_TEST=1 environment
# variable, a "--automated-test" user argument, or a headless display. In that mode the game never captures the real
# OS mouse, so a test run can never grab a player's mouse.
static func is_automated_test() -> bool:
	return (
		OS.get_environment("POSITIVEFPS_TEST") == "1"
		or "--automated-test" in OS.get_cmdline_user_args()
		or DisplayServer.get_name() == "headless"
	)
