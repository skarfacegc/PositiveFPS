class_name Config
extends RefCounted

# All tuning values for the prototype live here. Change a number and run the game to feel the difference.

# The three elements. Each person has an affinity for one of them. Every shot uses the target's element.
enum Element { MUSIC, ART, NATURE }
# Top-down targeting modes (see TD_TARGETING_MODE below).
enum TargetingMode { LOCK_ON, HOVER_STICKY, AUTO }
# The three border shapes, chosen on the menu before the level loads (see border.gd).
enum BorderVariant { CIRCLE, ORGANIC, PAINT_EDGE }

# Display names, in the same order as the Element enum.
const ELEMENT_NAMES: Array[String] = ["Music", "Art", "Nature"]

# Colours for each element, in the same order as the Element enum.
# They are used for the person's floating marker, the projectiles, the HUD text and the painted ground.
const ELEMENT_COLORS: Array[Color] = [Color(0.25, 0.5, 1.0), Color(1.0, 0.4, 0.7), Color(0.3, 0.85, 0.35)]

# Joy needed for a person at light grey (darker levels need more, see LEVEL_JOY_MULT).
const JOY_MAX := 1000.0

# Damage multipliers for the element matchups (see multiplier() below).
const MATCH_MULT := 2.0  # Same element as the person's affinity.
const STRONG_MULT := 1.5  # The element beats the person's affinity.
const WEAK_MULT := 1.0  # The element loses to the person's affinity.

# Distance falloff: joy is strongest close up and weakens with distance (see falloff() below).
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

# Show the Borderlands-style floating joy numbers when a joy projectile hits someone.
const NUMBERS_ENABLED := true

# ---- Territory game (scripts/topdown_*.gd, joy_projectile.gd, bloom.gd, painted_ground.gd). Names start with TD_. ----

# Side length of the top-down plaza, in metres. Walls go around the edge.
const TD_PLAZA_SIZE := 70
# How many people are in the top-down plaza.
const TD_PEOPLE_COUNT := 60
# Seed for every gameplay random number (top-down placement and wandering, cosmetic jitter). Gameplay code
# uses its own seeded RandomNumberGenerator, never the global randf(), so a run is repeatable.
const RNG_SEED := 42
# Cover (round 7): each person's cover is the average paint weight of the ground within TD_COVER_RADIUS metres. Their
# protection is smoothstep(TD_COVER_EDGE, TD_COVER_FULL, cover): 0 at the edge of a painted area, 1 well inside it.
const TD_COVER_RADIUS := 3.0
const TD_COVER_EDGE := 0.35
const TD_COVER_FULL := 0.85
# Joy contagion: with at least this much cover, an unrescued person's gloom drops by TD_CONTAGION_RATE per second
# (times their protection). That is about one grey level per ten seconds deep inside. It never adds joy or rescues.
const TD_CONTAGION_THRESHOLD := 0.6
const TD_CONTAGION_RATE := 0.034
# Top-down ground: painting in and fading back are separate speeds (per ground update). Painting is quick, but
# fading back is slow, so territory lags behind people and lingers after a relapse.
const TD_GROUND_SPREAD_SPEED := 0.05
const TD_GROUND_FADE_SPEED := 0.012
# Debug overlay (F3): height of the cover and protection labels above the ground, in metres (round 8: above joy labels).
const TD_DEBUG_LABEL_HEIGHT := 3.2
# Round 8: the F3 labels are sized in world units, not with TD_UI_SCALE, so they stay readable at the camera distance.
# Glyph height on screen is about font size times pixel size, in metres (0.86 m is about 24 px at 1280x720).
const TD_DEBUG_FONT_SIZE := 80
const TD_DEBUG_PIXEL_SIZE := 0.012

# Camera height above the player, in metres (round 8: closer, was 24; 15 put the range ring's near edge off screen).
const TD_CAMERA_HEIGHT := 18.0
# How far behind the player the camera sits, in metres. The camera looks down at the player (round 8: was 12).
const TD_CAMERA_BACK := 10.0
# Walking speed, in metres per second.
const TD_MOVE_SPEED := 6.0
# Speed while holding Shift, in metres per second.
const TD_RUN_SPEED := 9.5
# A person can only be targeted (and shot at) while this close to the player, in metres.
const TD_AUTO_RANGE := 11.0
# How the player picks a target. LOCK_ON: click a person to lock on. HOVER_STICKY: the person under the mouse
# is picked when there is no target, and then stays the target. AUTO: the most urgent person in range.
# The mode at the start of a top-down round. F2 cycles through the modes at runtime. Round 8: hover is the default
# (playtest 7 preferred it).
const TD_TARGETING_MODE := TargetingMode.HOVER_STICKY
# Short names for each TargetingMode, in the same order (shown on the HUD).
const TD_TARGETING_NAMES: Array[String] = ["Lock-on", "Hover", "Auto"]
# Lock-on: a click picks the valid person nearest the mouse ground point, if within this many metres.
const TD_CLICK_RADIUS := 1.6
# A lock (or a hover target) is dropped when the target is further than this from the player, in metres.
const TD_LOCK_BREAK_RANGE := 14.0
# Hover: with no target, the valid person nearest the mouse point within this many metres becomes the target.
const TD_AIM_ASSIST_RADIUS := 3.5
# Shots per second while there is a target in range.
const TD_SHOTS_PER_SECOND := 5.0
# Joy added by a Nature shot (before the element multiplier and distance falloff). Other elements scale this by
# the inverse of their fire-rate multiplier (see TD_ELEMENT_FIRE_RATE_MULT), so every element delivers the same joy
# per second. Round 7: 170 (was 135).
const TD_JOY_PER_SHOT := 170.0
# Fire-rate multiplier per element (music, art, nature). Music fires twice as often as Nature, Art half as often.
# Joy per shot is divided by this, so the joy per second is the same for each element.
const TD_ELEMENT_FIRE_RATE_MULT: Array[float] = [2.0, 0.5, 1.0]
# How long a joy projectile can fly before it fizzles, in seconds.
const TD_PROJECTILE_LIFETIME := 1.6
# A projectile hits a person when it passes within this distance of their chest, in metres.
const TD_PROJECTILE_HIT_RADIUS := 0.7
# A projectile at or below this height has landed, in metres.
const TD_LANDING_HEIGHT := 0.05
# Music notes fly at this speed (metres per second) and turn toward their target at this rate (radians per second).
const TD_NOTE_SPEED := 15.0
const TD_NOTE_TURN_RATE := 6.0
# Paint blobs are lobbed so they land on the target's position after this many seconds, under this gravity.
# Round 7: slower and higher arc (was 0.55 s).
const TD_PAINT_FLIGHT_TIME := 0.75
const TD_PAINT_GRAVITY := 18.0
# On a paint impact, people within this many metres (ground distance) get this fraction of the joy. Round 8: 1.1 (was
# 1.6). The splash ring on the ground is drawn at exactly this radius (see TD_SPLASH_RING_*).
const TD_PAINT_SPLASH_RADIUS := 1.1
const TD_PAINT_SPLASH_FRACTION := 0.5
# The brief splash ring: it fades out over TD_SPLASH_RING_SECONDS, and is this solid at the start.
const TD_SPLASH_RING_SECONDS := 0.35
const TD_SPLASH_RING_ALPHA := 0.35
# Flowers fly slower and turn more gently than notes (same units as above).
const TD_FLOWER_SPEED := 9.0
const TD_FLOWER_TURN_RATE := 2.0
# A flower that lands (or hits someone) leaves a bloom: it lasts this many seconds...
const TD_BLOOM_SECONDS := 2.5
# ...covers people within this radius of its centre, in metres...
const TD_BLOOM_RADIUS := 1.3
# Round 8: the patch has a crisp edge: a thin darker sage outline at exactly TD_BLOOM_RADIUS, a nearly solid fill inside
# it (the fill stops TD_BLOOM_RING_WIDTH short of the outline), and no soft fade at the rim.
const TD_BLOOM_RING_COLOR := Color(0.2, 0.34, 0.18)
const TD_BLOOM_RING_WIDTH := 0.07
const TD_BLOOM_FILL_ALPHA := 0.9
# ...gives them this much joy per second (element Nature, no distance falloff)...
const TD_BLOOM_JOY_PER_SEC := 120.0
# ...in pulses this long apart (joy is applied in pulses so each pulse shows one floating number)...
const TD_BLOOM_PULSE_SECONDS := 0.25
# ...and fades out over this many seconds at the end. Round 8: the whole patch fades together (alpha only, no shrink).
const TD_BLOOM_FADE_SECONDS := 0.4
# Colour of the element ring under the player when there is no target.
const TD_NO_TARGET_COLOR := Color(0.92, 0.9, 0.82)
# The target highlight: a ring at the target's feet, its radius, colour, and how far it pulses (scale change).
const TD_HIGHLIGHT_RADIUS := 0.75
const TD_HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.5, 0.85)
const TD_HIGHLIGHT_PULSE := 0.05
# Pulse speed in radians per second (a slow pulse).
const TD_HIGHLIGHT_PULSE_SPEED := 3.0
# How far music notes wobble from side to side, in metres. Visual only: it does not change where they fly.
const TD_PROJECTILE_BOB := 0.3
# How fast flower projectiles spin, in radians per second.
const TD_FLOWER_SPIN := 8.0
# Flowers float: they bob up and down this many metres, this many radians a second (visual only).
const TD_FLOWER_BOB := 0.12
const TD_FLOWER_BOB_SPEED := 4.0
# A Music hit (or landing) makes an expanding dusty-blue ring on the ground under the target (the "sound ring").
# It grows from TD_SOUND_RING_START to TD_SOUND_RING_RADIUS metres over TD_SOUND_RING_SECONDS, then fades out.
const TD_SOUND_RING_COLOR := Color(0.42, 0.58, 0.78, 0.8)
const TD_SOUND_RING_START := 0.3
const TD_SOUND_RING_RADIUS := 1.4
const TD_SOUND_RING_SECONDS := 0.35
# A Nature hit also bursts a few petals outward from where the flower stopped. Each petal flies TD_PETAL_BURST_RANGE
# metres out over TD_PETAL_BURST_SECONDS, then fades and frees itself.
const TD_PETAL_BURST_COUNT := 8
const TD_PETAL_BURST_RANGE := 1.1
const TD_PETAL_BURST_SECONDS := 0.6
# Radius of the paint splat left by an Art projectile, in metres (round 8: smaller, was 1.0).
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
# Dark people drift toward a rescued person at this speed, in metres per second (round 6: slowed from 1.3).
const TD_DARK_DRIFT_SPEED := 0.8
# Dark people stop drifting when this close to their rescued person, in metres.
const TD_DARK_STOP_DISTANCE := 2.5
# At most this many dark people may drift toward the same rescued person. Others pick the next-nearest rescued
# person with a free slot, or wander. This stops the crowd piling up on one person.
const TD_MAX_PURSUERS_PER_TARGET := 2
# Everyone steers away from people within this distance (metres). Dark and wandering people both do it.
const TD_SEPARATION_RADIUS := 2.2
# How strongly the separation push is added to a person's movement direction (before it is normalised).
const TD_SEPARATION_STRENGTH := 1.2
# Top-down joy drain is scaled by this. Dark people drain rescued joy at 0.4 of the round 6 rate (round 7).
# It is also scaled by (1 - protection) of the rescued person (see GloomSim), so cover makes it smaller.
const TD_DRAIN_MULTIPLIER := 0.4
# After a rescue, the person cannot be drained by nearby darkness for this many seconds (a warm halo shows it).
const TD_RESCUE_GRACE_SECONDS := 4.0
# The grace cue: a warm ring on the ground under a rescued person, pulsing in size, plus a soft glow on the body.
# Both fade out over the last GRACE_FADE_SECONDS of the grace period.
const GRACE_RING_COLOR := Color(1.0, 0.85, 0.45, 0.8)
const GRACE_RING_RADIUS := 0.9  # Metres.
# The ring pulses between 0.9 and 1.15 times its size (middle 1.025, swing 0.125), this many times a second.
const GRACE_RING_SCALE_MID := 1.025
const GRACE_RING_PULSE_AMPLITUDE := 0.125
const GRACE_RING_PULSE_HZ := 2.5
const GRACE_GLOW_COLOR := Color(1.0, 0.85, 0.45)
const GRACE_GLOW_ENERGY := 0.6  # Emission strength of the body glow at full strength.
const GRACE_FADE_SECONDS := 1.0  # The ring and glow fade out over this much of the grace period, at its end.
# Top-down projectiles (notes, paint, flowers) are drawn this many times bigger, so the element is easier to tell apart.
const TD_PROJECTILE_VISUAL_SCALE := 1.5
# Extra size per element on top of TD_PROJECTILE_VISUAL_SCALE (music, art, nature): notes are small and quick,
# paint blobs are big and slow. Round 8: paint 1.3 (was 2.0), so it no longer reads as an area weapon.
const TD_ELEMENT_VISUAL_SCALE: Array[float] = [0.8, 1.3, 1.0]
# Trails: small pieces left in the level behind each projectile. They fade and free themselves.
# Most trail pieces one projectile can leave behind (keeps many shots cheap).
const TD_TRAIL_MAX_PIECES := 12
# Music note trail: a wavy ribbon of small dusty-blue dots. Each dot lives this many seconds...
const TD_TRAIL_SECONDS := 0.35
# ...and a new dot is left every this many seconds.
const TD_TRAIL_INTERVAL := 0.04
const TD_TRAIL_RADIUS := 0.09
# Notes wave from side to side this many metres (the trail and the note together), this many radians a second.
# Round 7: a more pronounced ribbon (was 0.3 m scaled by the visual size).
const TD_NOTE_RIBBON_WAVE := 0.6
const TD_NOTE_WAVE_SPEED := 16.0
const TD_TRAIL_COLOR := Color(0.42, 0.58, 0.78)
# Art paint trail: warm rose or terracotta drips fall from the blob (a new drip every TD_DRIP_INTERVAL seconds).
const TD_DRIP_COLOR := Color(0.8, 0.42, 0.34)
const TD_DRIP_INTERVAL := 0.05
const TD_DRIP_RADIUS := 0.09  # Heavier drips in round 7 (was 0.06).
# A drip takes this long to fall to the ground, where it leaves a small splat dot.
const TD_DRIP_FALL_SECONDS := 0.3
const TD_SPLAT_DOT_RADIUS := 0.07
# How long a splat dot takes to fade away, in seconds.
const TD_SPLAT_DOT_FADE_SECONDS := 1.5
# Nature flower trail: small petals shed every TD_PETAL_INTERVAL seconds. They alternate sage and pink.
const TD_PETAL_COLORS: Array[Color] = [Color(0.62, 0.74, 0.58), Color(0.92, 0.66, 0.74)]
const TD_PETAL_INTERVAL := 0.06
# Petals drift down by this many metres over their life (TD_PETAL_FADE_SECONDS) while turning.
const TD_PETAL_FALL := 0.5
const TD_PETAL_FADE_SECONDS := 0.8
const TD_PETAL_SIZE := Vector2(0.16, 0.12)
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
# Size multiplier for floating numbers and labels in top-down mode. Round 8: 1.9 (was 2.5), to match the closer camera
# so the labels keep about the same size on screen.
const TD_UI_SCALE := 1.9

# Round 8: own paint does not protect. A rescued person's cover leaves out the paint made by their own soft circle
# (see PaintedGround.average_weight_excluding). Unrescued people still use the full cover.
#
# Round 8: darkness erodes paint at the edge of territory. Each unrescued dark person takes TD_ERODE_RATE weight per
# second off the edge tiles within TD_ERODE_RADIUS. A tile is edge unless it and all its neighbours are at least
# TD_ERODE_EDGE_MAX (deep interior tiles are immune). An eroded tile cannot regrow for TD_ERODE_HOLD seconds.
const TD_ERODE_RADIUS := 2.0
const TD_ERODE_RATE := 0.25
const TD_ERODE_EDGE_MAX := 0.9
const TD_ERODE_HOLD := 3.0
# The territory edge (for dark people with no one to chase) is painted tiles with weight in (TD_EDGE_MIN, EDGE_MAX).
const TD_EDGE_MIN := 0.05
# Dark people chase the weakest rescued person (lowest protection, ties to the nearest) within this many metres.
const TD_PURSUIT_SEARCH_RADIUS := 25.0
# A dark person with no one to chase drifts to the nearest territory edge, and stops this close to it (metres).
const TD_EDGE_REACH := 0.5

# ---- Round 9: the living border (scripts/border.gd, building.gd, landmark.gd, night_cycle.gd). ----

# The three border shapes, chosen on the menu before the level loads (see border.gd).
const BORDER_VARIANT_NAMES: Array[String] = ["A — Circle", "B — Organic push (recommended)", "C — Paint edge"]
# Rescued people needed before a border forms. Below this count the border collapses once it has formed.
const BORDER_MIN_PEOPLE := 3
# The centre (the smoothed centroid of rescued people) moves toward the target centroid at this speed, in m/s.
const BORDER_CENTRE_FOLLOW := 0.5
# Members stand this far apart along the border, in metres. The slot count is perimeter / this, rounded up.
const BORDER_TARGET_SPACING := 2.2
# Members walk to their slot at this speed, in metres per second.
const BORDER_WALK_SPEED := 3.0
# A stretch of border between two members longer than this is a gap: darkness can pass through it.
const BORDER_MAX_GAP := 3.5
# A dark person outside the border drains the nearest member within this distance, in metres.
const BORDER_PRESS_RANGE := 1.5
# The border loop has this many points (one per angle), and is drawn as line segments.
const BORDER_SAMPLES := 48
# Circle and organic border radii are kept between these, in metres.
const BORDER_MIN_RADIUS := 3.0
const BORDER_MAX_RADIUS := 30.0
# Organic: each rescue pushes the border outward at its angle, by this much at the peak (metres).
const BORDER_PUSH := 1.6
# Organic: the push is spread over this many radians (a Gaussian), so the bump is smooth.
const BORDER_PUSH_WIDTH := 0.5
# Organic: the total size is eased toward the target perimeter over this many seconds.
const BORDER_NORMALISE_SECONDS := 2.0
# Paint edge: each rescued person paints a soft disc of this radius (metres). The border follows the painted region.
const BORDER_PAINT_RADIUS := 4.0
# Cover from the border: 0 on the line, 1 this many metres inside it (so a grey person there can be lightened).
const BORDER_EDGE_BAND := 1.0
# A member who relapses steps this far outward from the centre (metres).
const BORDER_OUTWARD_STEP := 1.0
# Inner members (rescued people beyond the slot count) stand in a spiral this much apart, in metres.
const BORDER_INNER_SPACING := 0.7
# A building is beautified after this many seconds with at least this fraction of its footprint inside the border.
const BORDER_BUILDING_SECONDS := 3.0
const BORDER_BUILDING_INSIDE := 0.7
# The warm tint takes this long to fade in (and out), in seconds.
const BORDER_TINT_SECONDS := 2.0
# Beautified buildings go this warm colour. Mechanical blocks keep their grey.
const BORDER_BUILDING_COLOUR := Color(0.92, 0.7, 0.55)
# The ground inside the border goes this colour (warm cream), and outside it stays grey.
const BORDER_GROUND_COLOUR := Color(0.93, 0.84, 0.66)
# The landmark: one special block away from the start. Win when it is beautified and held this long (seconds).
const BORDER_LANDMARK_POS := Vector3(18, 0, -16)
const BORDER_LANDMARK_SIZE := Vector3(4, 3.5, 4)
const BORDER_LANDMARK_HOLD := 10.0
const BORDER_LANDMARK_COLOUR := Color(0.78, 0.66, 0.6)
const BORDER_BEACON_COLOUR := Color(1.0, 0.85, 0.45)
# The border line: intact is warm gold, a gap flickers between grey and red.
const BORDER_INTACT_COLOUR := Color(1.0, 0.82, 0.4)
const BORDER_GAP_COLOUR := Color(0.6, 0.6, 0.62)
const BORDER_GAP_ALARM_COLOUR := Color(0.9, 0.3, 0.25)
const BORDER_GAP_FLICKER_HZ := 4.0
# How far above the ground the border line is drawn, in metres.
const BORDER_LINE_HEIGHT := 0.08

# Dusk to dawn: the level lasts NIGHT_LENGTH seconds. Grey strength is 1 at dusk and dawn and peaks at midnight.
const NIGHT_LENGTH := 240.0
const NIGHT_PEAK_EXTRA := 0.75

# The matchups form a soft cycle:
#   Music is strong against Art, Art is strong against Nature, Nature is strong against Music.
# Matching the affinity gives MATCH_MULT. The element that loses to the affinity gives WEAK_MULT.

# Returns how much a hit with `element` is multiplied when the person has `affinity`.
# The border variant for the next level. The menu sets it. A static var, so it survives the scene change.
static var border_variant: int = BorderVariant.ORGANIC


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


# Returns the visible grey level (0 light, 1 grey, 2 dark) for a hidden gloom value.
static func gloom_level(g: float) -> int:
	if g < GLOOM_LEVEL_STEPS[0]:
		return 0
	if g < GLOOM_LEVEL_STEPS[1]:
		return 1
	return 2


# True when the game is running under the automated tests (tools/run_tests.py): the POSITIVEFPS_TEST=1
# environment variable, a "--automated-test" user argument, or a headless display. In that mode the game
# never captures the real OS mouse, so a test run can never grab a player's mouse.
static func is_automated_test() -> bool:
	return (
		OS.get_environment("POSITIVEFPS_TEST") == "1"
		or "--automated-test" in OS.get_cmdline_user_args()
		or DisplayServer.get_name() == "headless"
	)
