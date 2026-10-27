class_name Config
extends RefCounted

# All tuning values for the prototype live here. Change a number and run the game to feel the difference.

# The three elements. Each person has an affinity for one of them. Every shot uses the target's element.
enum Element { MUSIC, ART, NATURE }
# Top-down targeting modes (see TD_TARGETING_MODE below).
enum TargetingMode { LOCK_ON, HOVER_STICKY, AUTO }

# ---- Round 13a: world scale. The plaza went from 70 m to 100 m across (WORLD_SCALE), with the same 60 people.
# THE RULE: a constant is multiplied by WORLD_SCALE if it is about TERRITORY (how big a land the rules cover: plaza,
# block and landmark positions, spawn margins and spacing, border spacing / gap / push / radii / bands / steps, cover,
# erosion, colour-zone and contagion radii, search and edge-pressure reach). It is left alone if it is about
# INTERACTION or a BODY (person and block sizes, projectile ranges and speeds, TD_AUTO_RANGE, GRAB_*, SHELTER_RADIUS,
# SKITTISH_RADIUS, hit and click radii, burst radius, press range). A per-metre rate is divided by WORLD_SCALE so the
# same fraction of the way across the land gives the same rate. Speeds are tuned by hand (player, dark drift +10%).
const WORLD_SCALE := 100.0 / 70.0

# Display names, in the same order as the Element enum.
const ELEMENT_NAMES: Array[String] = ["Music", "Art", "Nature"]

# Colours for each element, in the same order as the Element enum. They are used for the person's floating marker, the
# projectiles, the HUD text and the painted ground.
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
# Extra gloom per second for each metre from the nearest colour zone (round 13a: divided by WORLD_SCALE).
const GLOOM_GROWTH_PER_METER := 0.0008 / WORLD_SCALE
# Round 11: growth is multiplied by this while the person is at grey (level 1), so the grey -> dark step is slower.
# Light grey -> grey is unchanged (1.0 is the old rate). Applies to growth only, not spread or contagion.
const GLOOM_DARK_STEP_MULT := 0.65
const NO_ZONE_DISTANCE := 20.0 * WORLD_SCALE  # Gloom growth distance when nobody is rescued yet (no colour zones).
const ZONE_RADIUS := 6.0 * WORLD_SCALE  # Each rescued person creates a colour zone of this radius (metres).
const SPREAD_RADIUS := 6.0 * WORLD_SCALE  # How far darkness spreads from a dark person (metres).
const SPREAD_GLOOM_RATE := 0.03  # Gloom per second given to nearby unrescued people by a dark person.
const SPREAD_DRAIN_RATE := 60.0  # Joy per second drained from nearby rescued people by a dark person.

# The three visible grey levels. Gloom below the first step is light, below the second is grey, else dark.
const GLOOM_LEVEL_STEPS: Array[float] = [0.34, 0.67]
# Body colour for each level (0 light, 1 grey, 2 dark).
const LEVEL_COLORS: Array[Color] = [Color(0.82, 0.82, 0.82), Color(0.5, 0.5, 0.52), Color(0.16, 0.16, 0.18)]
# Joy needed at each level, as a multiple of JOY_MAX. Darker people need more joy.
# Round 14: dimmed 2.0 -> 1.6 (the counter to the midnight dimmed people; wistful and gloomy unchanged).
const LEVEL_JOY_MULT: Array[float] = [1.0, 1.5, 1.6]
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

# ---- Territory game (scripts/topdown_*.gd, joy_projectile.gd, bloom.gd, painted_ground.gd). Names start with TD_.
# ----

# Side length of the top-down plaza, in metres. Walls go around the edge.
const TD_PLAZA_SIZE := 100  # Round 13a: 70 x WORLD_SCALE.
# How many people are in the top-down plaza.
const TD_PEOPLE_COUNT := 60
# Seed for every gameplay random number (top-down placement and wandering, cosmetic jitter). Gameplay code uses its
# own seeded RandomNumberGenerator, never the global randf(), so a run is repeatable.
const RNG_SEED := 42
# Cover (round 7): each person's cover is the average paint weight of the ground within TD_COVER_RADIUS metres. Their
# protection is smoothstep(TD_COVER_EDGE, TD_COVER_FULL, cover): 0 at the edge of a painted area, 1 well inside it.
const TD_COVER_RADIUS := 3.0 * WORLD_SCALE
const TD_COVER_EDGE := 0.35
const TD_COVER_FULL := 0.85
# Joy contagion: with at least this much cover, an unrescued person's gloom drops by TD_CONTAGION_RATE per second
# (times their protection). That is about one grey level per ten seconds deep inside. It never adds joy or rescues.
const TD_CONTAGION_THRESHOLD := 0.6
const TD_CONTAGION_RATE := 0.034
# Top-down ground: painting in and fading back are separate speeds (per ground update). Painting is quick, but fading
# back is slow, so territory lags behind people and lingers after a relapse.
const TD_GROUND_SPREAD_SPEED := 0.05
const TD_GROUND_FADE_SPEED := 0.012
# Debug overlay (F3): height of the cover and protection labels above the ground, in metres (round 8: above joy
# labels).
const TD_DEBUG_LABEL_HEIGHT := 3.2
# Round 8: the F3 labels are sized in world units, not with TD_UI_SCALE, so they stay readable at the camera distance.
# Glyph height on screen is about font size times pixel size, in metres (0.86 m is about 24 px at 1280x720).
const TD_DEBUG_FONT_SIZE := 80
const TD_DEBUG_PIXEL_SIZE := 0.012

# Round 10: an orthographic camera, size TD_CAMERA_ORTHO_SIZE (the view height in metres at the focus), tilted down at
# TD_CAMERA_PITCH_DEG degrees. It sits TD_CAMERA_DISTANCE metres from its look point, which is the player plus
# TD_CAMERA_LOOK_OFFSET (2.4 m north, so the player sits a little below the centre of the screen).
# Round 14: the reference size is 19.5 (the default zoom, a little further out than 18). The mouse wheel zooms between
# TD_ZOOM_MIN and TD_ZOOM_MAX (see the zoom block below); TD_CAMERA_ORTHO_SIZE is the size at default zoom.
const TD_CAMERA_ORTHO_SIZE := 19.5
const TD_CAMERA_PITCH_DEG := 41.0
const TD_CAMERA_DISTANCE := 20.0
# Round 14: the offset is for the default zoom and scales with the zoom (-2.6 x 19.5 / 18), so the player keeps the
# same place on screen at every zoom.
const TD_CAMERA_LOOK_OFFSET := Vector3(0, 0, -2.82)
# Mouse-wheel zoom (round 14): the view height goes from TD_ZOOM_MIN (close) to TD_ZOOM_MAX (wide), one TD_ZOOM_STEP
# per wheel notch, eased at TD_ZOOM_EASE per second (an exponential approach).
const TD_ZOOM_MIN := 14.0
const TD_ZOOM_MAX := 26.0
const TD_ZOOM_STEP := 1.5
const TD_ZOOM_EASE := 8.0
# Walking speed, in metres per second.
const TD_MOVE_SPEED := 7.6  # Round 13a: +10% (6.9) to offset the longer walks.
# Speed while holding Shift, in metres per second. Round 11: walk and run are about 15% faster than round 10 (6.0, 9.5).
const TD_RUN_SPEED := 12.0  # Round 13a: +10% (10.9).
# A person can only be targeted (and shot at) while this close to the player, in metres. Round 11: 10.0 (was 8.6), the
# largest round value whose full ring still fits on a 1280x720 screen with the zoomed-out camera (see the camera test).
const TD_AUTO_RANGE := 10.0
# How the player picks a target. LOCK_ON: click a person to lock on. HOVER_STICKY: the person under the mouse is
# picked when there is no target, and then stays the target. AUTO: the most urgent person in range. The mode at the
# start of a top-down round. F2 cycles through the modes at runtime. Round 8: hover is the default (playtest 7
# preferred it).
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
# Joy added by a Nature shot (before the element multiplier and distance falloff). Other elements scale this by the
# inverse of their fire-rate multiplier (see TD_ELEMENT_FIRE_RATE_MULT), so every element delivers the same joy per
# second. Round 7: 170 (was 135).
const TD_JOY_PER_SHOT := 170.0
# Fire-rate multiplier per element (music, art, nature). Music fires twice as often as Nature, Art half as often. Joy
# per shot is divided by this, so the joy per second is the same for each element.
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
# Paint blobs are lobbed so they land on the target's position after this many seconds, under this gravity. Round 7:
# slower and higher arc (was 0.55 s).
const TD_PAINT_FLIGHT_TIME := 0.75
const TD_PAINT_GRAVITY := 18.0
# On a paint impact, people within this many metres (ground distance) get this fraction of the joy. Round 8: 1.1 (was
# 1.6). The splash ring on the ground is drawn at exactly this radius (see TD_SPLASH_RING_*).
const TD_PAINT_SPLASH_RADIUS := 1.1
const TD_PAINT_SPLASH_FRACTION := 0.5
# The brief splash ring: it fades out over TD_SPLASH_RING_SECONDS, and is this solid at the start.
const TD_SPLASH_RING_SECONDS := 0.35
const TD_SPLASH_RING_ALPHA := 0.175
# Flowers fly slower and turn more gently than notes (same units as above).
const TD_FLOWER_SPEED := 9.0
const TD_FLOWER_TURN_RATE := 2.0
# A flower that lands (or hits someone) leaves a bloom: it lasts this many seconds...
const TD_BLOOM_SECONDS := 2.5
# ...covers people within this radius of its centre, in metres...
const TD_BLOOM_RADIUS := 1.3
# Round 10: the patch is subtle. No outline ring, a faint fill (alpha at most 0.25), at most 4 flowers of 4 petals
# each.
const TD_BLOOM_FILL_ALPHA := 0.25
const TD_BLOOM_FLOWER_COUNT := 4
const TD_BLOOM_PETALS := 4
# ...gives them this much joy per second (element Nature, no distance falloff)...
const TD_BLOOM_JOY_PER_SEC := 120.0
# ...in pulses this long apart (joy is applied in pulses so each pulse shows one floating number)...
const TD_BLOOM_PULSE_SECONDS := 0.25
# ...and fades out over the last TD_BLOOM_FADE_FRACTION of its life (round 10: was a fixed 0.4 s). The whole patch
# fades together (alpha only, no shrink).
const TD_BLOOM_FADE_FRACTION := 0.4
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
# A Music hit (or landing) makes an expanding dusty-blue ring on the ground under the target (the "sound ring"). It
# grows from TD_SOUND_RING_START to TD_SOUND_RING_RADIUS metres over TD_SOUND_RING_SECONDS, then fades out.
const TD_SOUND_RING_COLOR := Color(0.42, 0.58, 0.78, 0.4)
const TD_SOUND_RING_START := 0.3
const TD_SOUND_RING_RADIUS := 1.4
const TD_SOUND_RING_SECONDS := 0.35
# A Nature hit also bursts a few petals outward from where the flower stopped. Each petal flies TD_PETAL_BURST_RANGE
# metres out over TD_PETAL_BURST_SECONDS, then fades and frees itself.
const TD_PETAL_BURST_COUNT := 8
const TD_PETAL_BURST_RANGE := 1.1
const TD_PETAL_BURST_SECONDS := 0.6
# Radius of the paint splat left by an Art projectile, in metres (round 8: smaller, was 1.0).
const TD_SPLAT_RADIUS := 0.42
# How solid the paint splat is (1 = solid, 0 = invisible).
const TD_SPLAT_ALPHA := 0.6
# Seconds for a paint splat to fade away.
const TD_SPLAT_FADE_TIME := 0.8
# Walking speed for wandering people, in metres per second.
const TD_WANDER_SPEED := 0.92  # Round 11: about 15% faster than round 10 (0.8).
# Wandering people pick a new spot within this distance of where they are, in metres.
const TD_WANDER_RANGE := 4.0
# A wandering person counts as having reached their spot when this close, in metres.
const TD_WANDER_REACH := 0.5
# Wandering people pick a new spot after a random time between these two values, in seconds.
const TD_WANDER_TIME_MIN := 3.0
const TD_WANDER_TIME_MAX := 6.0
# Dark people drift toward a rescued person at this speed, in metres per second (round 6: slowed from 1.3).
# Round 11: 0.92 (15% faster than round 10's 0.8). Round 13a: +10% again.
const TD_DARK_DRIFT_SPEED := 1.01
# Dark people stop drifting when this close to their rescued person, in metres.
const TD_DARK_STOP_DISTANCE := 2.5
# At most this many dark people may drift toward the same rescued person. Others pick the next-nearest rescued person
# with a free slot, or wander. This stops the crowd piling up on one person.
const TD_MAX_PURSUERS_PER_TARGET := 2
# Everyone steers away from people within this distance (metres). Dark and wandering people both do it.
const TD_SEPARATION_RADIUS := 2.2
# How strongly the separation push is added to a person's movement direction (before it is normalised).
const TD_SEPARATION_STRENGTH := 1.2
# Top-down joy drain is scaled by this. Dark people drain rescued joy at 0.4 of the round 6 rate (round 7). It is also
# scaled by (1 - protection) of the rescued person (see GloomSim), so cover makes it smaller.
const TD_DRAIN_MULTIPLIER := 0.4
# After a rescue, the person cannot be drained by nearby darkness for this many seconds (a warm halo shows it).
const TD_RESCUE_GRACE_SECONDS := 4.0
# The grace cue: a warm ring on the ground under a rescued person, pulsing in size, plus a soft glow on the body. Both
# fade out over the last GRACE_FADE_SECONDS of the grace period.
const GRACE_RING_COLOR := Color(1.0, 0.85, 0.45, 0.8)
const GRACE_RING_RADIUS := 0.9  # Metres.
# The ring pulses between 0.9 and 1.15 times its size (middle 1.025, swing 0.125), this many times a second.
const GRACE_RING_SCALE_MID := 1.025
const GRACE_RING_PULSE_AMPLITUDE := 0.125
const GRACE_RING_PULSE_HZ := 2.5
const GRACE_GLOW_COLOR := Color(1.0, 0.85, 0.45)
const GRACE_GLOW_ENERGY := 0.6  # Emission strength of the body glow at full strength.
const GRACE_FADE_SECONDS := 1.0  # The ring and glow fade out over this much of the grace period, at its end.
# Top-down projectiles (notes, paint, flowers) are drawn this many times bigger, so the element is easier to tell
# apart.
const TD_PROJECTILE_VISUAL_SCALE := 1.5
# Extra size per element on top of TD_PROJECTILE_VISUAL_SCALE (music, art, nature): notes are small and quick, paint
# blobs are big and slow. Round 8: paint 1.3 (was 2.0), so it no longer reads as an area weapon.
const TD_ELEMENT_VISUAL_SCALE: Array[float] = [0.8, 1.3, 1.0]
# Trails: small pieces left in the level behind each projectile. They fade and free themselves. Most trail pieces one
# projectile can leave behind (keeps many shots cheap).
const TD_TRAIL_MAX_PIECES := 12
# Music note trail: a wavy ribbon of small dusty-blue dots. Each dot lives this many seconds...
const TD_TRAIL_SECONDS := 0.35
# ...and a new dot is left every this many seconds.
const TD_TRAIL_INTERVAL := 0.04
const TD_TRAIL_RADIUS := 0.09
# Notes wave from side to side this many metres (the trail and the note together), this many radians a second. Round
# 7: a more pronounced ribbon (was 0.3 m scaled by the visual size).
const TD_NOTE_RIBBON_WAVE := 0.6
const TD_NOTE_WAVE_SPEED := 16.0
const TD_TRAIL_COLOR := Color(0.42, 0.58, 0.78)
# Art paint trail: warm rose or terracotta drips fall from the blob (a new drip every TD_DRIP_INTERVAL seconds).
const TD_DRIP_COLOR := Color(0.8, 0.42, 0.34)
const TD_DRIP_INTERVAL := 0.05
const TD_DRIP_RADIUS := 0.054  # Round 10: x0.6 (was 0.09).
# A drip takes this long to fall to the ground, where it leaves a small splat dot.
const TD_DRIP_FALL_SECONDS := 0.3
const TD_SPLAT_DOT_RADIUS := 0.042
# How long a splat dot takes to fade away, in seconds.
const TD_SPLAT_DOT_FADE_SECONDS := 0.8
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
const TD_SPAWN_EDGE := 3.0 * WORLD_SCALE
# People are never placed closer than this to the centre (where the player starts), in metres.
const TD_SPAWN_CENTRE_CLEAR := 5.0 * WORLD_SCALE
# Minimum distance between two people when placing them, in metres.
const TD_SPAWN_SPACING := 2.5 * WORLD_SCALE
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
# Round 14: the labels scale with the zoom (ui_scale = TD_UI_SCALE x size / TD_CAMERA_ORTHO_SIZE), so they keep the same
# size on screen at every zoom. 2.5675 = 2.37 x 19.5 / 18 keeps the round 13b size at the default zoom.
const TD_UI_SCALE := 2.5675

# Round 8: own paint does not protect. A rescued person's cover leaves out the paint made by their own soft circle
# (see PaintedGround.average_weight_excluding). Unrescued people still use the full cover.
#
# Round 8: darkness erodes paint at the edge of territory. Each unrescued dark person takes TD_ERODE_RATE weight per
# second off the edge tiles within TD_ERODE_RADIUS. A tile is edge unless it and all its neighbours are at least
# TD_ERODE_EDGE_MAX (deep interior tiles are immune). An eroded tile cannot regrow for TD_ERODE_HOLD seconds.
const TD_ERODE_RADIUS := 2.0 * WORLD_SCALE
const TD_ERODE_RATE := 0.25
const TD_ERODE_EDGE_MAX := 0.9
const TD_ERODE_HOLD := 3.0
# The territory edge (for dark people with no one to chase) is painted tiles with weight in (TD_EDGE_MIN, EDGE_MAX).
const TD_EDGE_MIN := 0.05
# Dark people chase the weakest rescued person (lowest protection, ties to the nearest) within this many metres.
const TD_PURSUIT_SEARCH_RADIUS := 25.0 * WORLD_SCALE
# A dark person with no one to chase drifts to the nearest territory edge, and stops this close to it (metres).
const TD_EDGE_REACH := 0.5

# ---- Round 10: the floor. Every floor overlay, with its draw priority (lower number = read first):
#   1  border line and gap glow (Border): always the clearest things on the floor.
#   2  target and threat (target highlight, the player's element ring and warm ring, grace rings on rescued people).
#   3  projectile effects, capped by TD_MAX_FLOOR_EFFECTS (oldest first): music sound rings, paint splats, splash rings,
#      petal bursts, blooms (Bloom) and trail pieces (note dots, drips, drip splat dots, petals). The joy burst ring
#      lasts 0.35 s and is not counted.
#   4  territory paint: the painted ground tiles (PaintedGround), drawn quietest.
# Impact puffs (1 s particle bursts) and the floating numbers are not floor overlays. The cap: when a new effect would
# exceed TD_MAX_FLOOR_EFFECTS, the oldest priority-3 effect is freed first.
const TD_MAX_FLOOR_EFFECTS := 40

# Round 10: the readability visuals (placeholders for the locked style, design/style_test/REVIEW_NOTES.md). The
# minimap: a circle top-left, TD_MINIMAP_WIDTH_FRACTION of the screen width, drawn from TD_MINIMAP_RESOLUTION pixels
# and refreshed every TD_MINIMAP_REFRESH_SECONDS.
const TD_MINIMAP_WIDTH_FRACTION := 0.2
const TD_MINIMAP_RESOLUTION := 128
const TD_MINIMAP_REFRESH_SECONDS := 0.1
const TD_MINIMAP_FRAME_COLOUR := Color(0.93, 0.87, 0.72)
const TD_MINIMAP_LINE_COLOUR := Color(1.0, 0.82, 0.4)
const TD_MINIMAP_MEMBER_COLOUR := Color(0.99, 0.95, 0.85)
const TD_MINIMAP_DARK_COLOUR := Color(0.1, 0.1, 0.12)
const TD_MINIMAP_LANDMARK_COLOUR := Color(1.0, 0.85, 0.45)
const TD_MINIMAP_PLAYER_COLOUR := Color(1.0, 0.7, 0.15)
const TD_MINIMAP_VIEW_COLOUR := Color(1.0, 1.0, 1.0, 0.7)
const TD_MINIMAP_WARM_COLOUR := Color(0.93, 0.84, 0.66)
const TD_MINIMAP_GREY_COLOUR := Color(0.55, 0.55, 0.56)
# The player marker: a saffron body no person uses, a warm double ring on the ground, and a soft glow under it.
const TD_PLAYER_COLOUR := Color(1.0, 0.62, 0.12)
const TD_PLAYER_RING_COLOUR := Color(1.0, 0.85, 0.5)
const TD_PLAYER_RING_RADII: Array[float] = [1.2, 1.4]
const TD_PLAYER_RING_WIDTH := 0.06
const TD_PLAYER_GLOW_RADIUS := 1.9
const TD_PLAYER_GLOW_ALPHA := 0.18
# People are drawn this many times bigger (visual only: their collision and hit radius do not change), and their joy
# label sits this high above the ground, in metres.
const PERSON_VISUAL_SCALE := 1.5
const PERSON_LABEL_HEIGHT := 3.9

# ---- Round 9: the living border (scripts/border.gd, building.gd, landmark.gd, night_cycle.gd). ----

# Rescued people needed before a border forms. Below this count the border collapses once it has formed.
const BORDER_MIN_PEOPLE := 3
# The centre (the smoothed centroid of rescued people) moves toward the target centroid at this speed, in m/s.
const BORDER_CENTRE_FOLLOW := 0.5
# Members stand this far apart along the border, in metres. The slot count is perimeter / this, rounded up. Round 10:
# 3.0 (was 2.2), so growing is easier.
const BORDER_TARGET_SPACING := 2.6 * WORLD_SCALE
# Members walk to their slot at this speed, in metres per second.
const BORDER_WALK_SPEED := 3.0
# A stretch of border between two members longer than this is a gap: darkness can pass through it.
const BORDER_MAX_GAP := 3.5 * WORLD_SCALE
# A dark person outside the border drains the nearest member within this distance, in metres.
const BORDER_PRESS_RANGE := 1.5
# The border loop has this many points (one per angle), and is drawn as line segments.
const BORDER_SAMPLES := 48
# The border never shrinks below a circle of this radius, in metres.
const BORDER_MIN_RADIUS := 3.0 * WORLD_SCALE
# Each rescue pushes the border outward at its angle, by this much at the peak (metres). Round 10: 2.4 (was 1.6),
# which is about one member's spacing of perimeter (the Gaussian area is BORDER_PUSH x 1.25).
const BORDER_PUSH := 2.4 * WORLD_SCALE
# The push is spread over this many radians (a Gaussian), so the bump is smooth.
const BORDER_PUSH_WIDTH := 0.5
# The total size is eased toward the target perimeter over this many seconds.
const BORDER_NORMALISE_SECONDS := 2.0
# Cover from the border: 0 on the line, 1 this many metres inside it (so a grey person there can be lightened).
const BORDER_EDGE_BAND := 1.0 * WORLD_SCALE
# A member who relapses steps this far outward from the centre (metres).
const BORDER_OUTWARD_STEP := 1.0 * WORLD_SCALE
# Inner members (rescued people beyond the slot count) stand in a spiral this much apart, in metres.
const BORDER_INNER_SPACING := 0.7 * WORLD_SCALE
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
const BORDER_LANDMARK_POS := Vector3(18, 0, -16) * WORLD_SCALE
const BORDER_LANDMARK_SIZE := Vector3(4, 3.5, 4)
const BORDER_LANDMARK_HOLD := 10.0
const BORDER_LANDMARK_COLOUR := Color(0.78, 0.66, 0.6)
const BORDER_BEACON_COLOUR := Color(1.0, 0.85, 0.45)
# The border line: intact is warm gold, a gap flickers between grey and red.
const BORDER_INTACT_COLOUR := Color(1.0, 0.82, 0.4)
# Round 10: a gap glows coral and pulses softly (p = 0.5 - 0.5 cos(2 pi t / 1.2)). The glow band is
# BORDER_GAP_GLOW_WIDTH metres wide and fades between BORDER_GAP_GLOW_ALPHA_MIN and BORDER_GAP_GLOW_ALPHA_MAX with the
# pulse. It is never a hard line.
const BORDER_GAP_COLOUR := Color(0.95, 0.42, 0.36)
const BORDER_GAP_PULSE_SECONDS := 1.2
const BORDER_GAP_GLOW_WIDTH := 1.2
const BORDER_GAP_GLOW_ALPHA_MIN := 0.15
const BORDER_GAP_GLOW_ALPHA_MAX := 0.7
# Off-screen gap arrows: a badge on the screen edge, this many pixels in from the edge, this big, and kept this far
# (pixels) clear of the minimap circle.
const OFFSCREEN_ARROW_MARGIN := 40.0
const OFFSCREEN_ARROW_SIZE := 14.0
const OFFSCREEN_ARROW_PAD := 16.0
# How far above the ground the border line is drawn, in metres.
const BORDER_LINE_HEIGHT := 0.08

# Dusk to dawn: the level lasts NIGHT_LENGTH seconds. Grey strength is 1 at dusk and dawn and peaks at midnight.
const NIGHT_LENGTH := 180.0  # Round 11: 180 s (was 240).
const NIGHT_PEAK_EXTRA := 0.75

# ---- Round 10: easier growth (scripts/border.gd, building.gd, night_cycle.gd, topdown_player.gd). ----

# Calm opening: the grey strength is NIGHT_CALM_STRENGTH for the first NIGHT_CALM_FRACTION of the night, then eases
# (smoothstep) into the curve above, which peaks at midnight.
const NIGHT_CALM_FRACTION := 0.25
const NIGHT_CALM_STRENGTH := 0.2
# A beautified building whose footprint is this close to the loop (metres) is a border post.
const BORDER_POST_REACH := 2.0 * WORLD_SCALE
# A post holds this many members' worth of perimeter, so the loop needs that many fewer people.
const BORDER_POST_WORTH := 3
# Post visuals (placeholder): a warm lantern on the block, and a golden ring around its base.
const BORDER_POST_LANTERN_COLOUR := Color(1.0, 0.8, 0.45)
const BORDER_POST_RING_COLOUR := Color(1.0, 0.82, 0.3)
const BORDER_POST_RING_INNER := 2.3
const BORDER_POST_RING_OUTER := 2.6
# An intact stretch is not drained: dark people pressing on it are pushed outward at this speed (metres per second).
const BORDER_PUSHBACK_SPEED := 0.35
# Round 11: dark people pressing an intact stretch also drain the nearest member, at this fraction of the gap drain rate
# (gaps keep the full rate). It makes the border feel at risk again without letting it fall to one press.
const BORDER_INTACT_DRAIN_FRACTION := 0.25
# The joy burst shoves the border outward toward the player when they are this close to it (metres), by this much.
const BORDER_SHOVE_RANGE := 4.0
const BORDER_SHOVE_AMOUNT := 1.5 * WORLD_SCALE

# ---- Round 12a: spirit, going dim, grabs and the twirl
# Spirit is the player's spendable resource (0..SPIRIT_MAX). Rescues fill it, the joy burst spends it, a grab drains it.
const SPIRIT_MAX := 100.0
const SPIRIT_START := 50.0
const SPIRIT_PER_RESCUE := 20.0
const BURST_SPIRIT_COST := 30.0
# Joy fire rate: full at this fraction of spirit or more, then down linearly to SPIRIT_MIN_FIRE_FRACTION at 0+.
const SPIRIT_FULL_FIRE_FRACTION := 0.5
const SPIRIT_MIN_FIRE_FRACTION := 0.4
# Going dim (spirit 0): half walk speed, no joy. Recovery only inside the border, or near the landmark before a border.
const DIM_MOVE_MULT := 0.5
const DIM_RECOVER_RATE := 10.0  # Spirit per second, times (DIM_RECOVER_BASE + DIM_RECOVER_DEPTH * depth protection).
const DIM_RECOVER_BASE := 0.3
const DIM_RECOVER_DEPTH := 0.7
const LANDMARK_RECOVER_RADIUS := 6.0
const DIM_EXIT_SPIRIT := 30.0
# While the player is dim the border loses ground this much faster, and its line flickers.
const DIM_LOSS_MULT := 1.5
const DIM_FLICKER_SECONDS := 0.5
const DIM_FLICKER_MIN := 0.2
const DIM_PLAYER_GREY := Color(0.5, 0.5, 0.52)
# Dimmed people reach for a player who is not dim. They notice the player from this far (metres).
const GRAB_NOTICE_RANGE := 7.0
const GRAB_RANGE := 2.0
const GRAB_HIT_RANGE := 1.3
const GRAB_WINDUP := 0.7
const GRAB_LUNGE_TIME := 0.15
# The lunge carries the grabber toward where the player stood when it began, by at most this far and never closer than
# GRAB_LUNGE_STOP. The grab lands if the player is within GRAB_HIT_RANGE of the grabber at the end of the lunge.
const GRAB_LUNGE_DISTANCE := 1.0
const GRAB_LUNGE_STOP := 0.7
const GRAB_COOLDOWN := 2.5
const GRAB_SPIRIT_DRAIN := 25.0
const GRAB_LEAN := 0.5  # Radians the grabber leans back at the end of the wind-up.
const GRAB_RING_COLOUR := Color(0.85, 0.2, 0.25, 0.5)
# The twirl (Space): a short dash with a cooldown. Twirling within TWIRL_PERFECT_WINDOW before a grab would land avoids
# it and gives a small joy burst (radius and half the normal joy, no spirit cost).
const TWIRL_DISTANCE := 3.0
const TWIRL_TIME := 0.2
const TWIRL_COOLDOWN := 1.5
const TWIRL_PERFECT_WINDOW := 0.25
const TWIRL_BURST_RADIUS := 2.5
const TWIRL_BURST_JOY_FRACTION := 0.5
# The dimmed-person haze of the placeholder look (a soft dark disc on the ground), radius in metres.
const DIM_AURA_RADIUS := 1.7
const DIM_AURA_COLOUR := Color(0.05, 0.05, 0.08, 0.38)

# ---- Round 12b: moods, sheltering, edge pressure, local gaps, noticeable stage changes
# Every unrescued wistful or gloomy person has one mood (dimmed people have none). See scripts/moods.gd.
# Guarded: faces away from the player, turning at GUARDED_TURN_SPEED radians a second. Joy only lands when the angle
# between their facing and the direction to the shooter is at most GUARDED_ARC_DEG; otherwise it glances off.
const GUARDED_ARC_DEG := 110.0
const GUARDED_TURN_SPEED := 0.8
const GLANCE_COLOUR := Color(0.9, 0.9, 0.95)
# Skittish: a player closer than SKITTISH_RADIUS who moves faster than SKITTISH_SPEED_LIMIT (walk speed x 1.1, so a
# run) scares them into backing away at SKITTISH_FLEE_SPEED for SKITTISH_FLEE_SECONDS. Walking up does not.
const SKITTISH_RADIUS := 5.0
const SKITTISH_SPEED_LIMIT := TD_MOVE_SPEED * 1.1
const SKITTISH_FLEE_SPEED := 2.5
const SKITTISH_FLEE_SECONDS := 1.5
# Glum: slumped, but every GLUM_LOOKUP_INTERVAL seconds (plus or minus GLUM_LOOKUP_JITTER, seeded) they look up for
# GLUM_LOOKUP_WINDOW seconds. Joy that lands in that window counts GLUM_LOOKUP_MULT times.
const GLUM_LOOKUP_INTERVAL := 3.0
const GLUM_LOOKUP_JITTER := 0.8
const GLUM_LOOKUP_WINDOW := 0.8
const GLUM_LOOKUP_MULT := 3.0
const GLUM_GLINT_COLOUR := Color(1.0, 0.85, 0.45)
# Sheltering: joy does not land on a wistful or gloomy person while a dimmed person is this close (metres).
const SHELTER_RADIUS := 2.0
const SHELTER_COLOUR := Color(0.45, 0.45, 0.5)
# Placeholder mood tells: the jitter of a skittish person (metres). (The guarded crossed-arms bar was replaced by the
# shield icon in round 13b.)
const SKITTISH_JITTER := 0.05
const GLUM_SLUMP_SCALE := 0.8
# Edge pressure: dimmed people prefer the newest and outermost stretch of the border. A stretch's score is
# EDGE_RECENCY_WEIGHT x how recently it advanced (1 just pushed, 0 after EDGE_RECENT_SECONDS) plus the rest x how far
# out it is (0 innermost, 1 outermost). A score of 1 is worth EDGE_PRESSURE_REACH metres of walking.
const EDGE_RECENT_SECONDS := 60.0
const EDGE_RECENCY_WEIGHT := 0.6
const EDGE_PRESSURE_REACH := 12.0 * WORLD_SCALE
# A dimmed person outside the border whose target is a border member walks up to the line (stopping this far from the
# member, which the line itself holds them short of), so they really press it. (Before they stopped 2.5 m from the
# member, beyond BORDER_PRESS_RANGE of the line, and pressed only for a moment.)
const TD_DARK_PRESS_STOP := 0.6
# Protection values closer than this count as equal when a dimmed person picks a target.
const EDGE_PROTECTION_TIE := 0.05
# Local gaps: a border member drained below MEMBER_FALTER_FRACTION of their joy needed falters (steps back
# MEMBER_FALTER_STEP_BACK metres) and opens a gap on both sides of them. (The plan said 0.5, but a person relapses at
# RELAPSE_FRACTION 0.5, so faltering starts higher.) Spare inner members only take a faltering member's place after
# GAP_HEAL_DELAY seconds.
const MEMBER_FALTER_FRACTION := 0.75
const MEMBER_FALTER_STEP_BACK := 0.5
const GAP_HEAL_DELAY := 3.0
# Noticeable stage changes: a grey-violet (gloomy, not icy) puff and ripple when someone sinks a stage, a warm one when
# they lift. The minimap shows a blip for BLIP_SECONDS when someone becomes dimmed.
const STAGE_SINK_COLOUR := Color(0.42, 0.34, 0.55)
const STAGE_LIFT_COLOUR := Color(1.0, 0.82, 0.45)
const STAGE_PUFF_COUNT := 28
const STAGE_RIPPLE_RADIUS := 1.8
const STAGE_RIPPLE_SECONDS := 0.7
const MINIMAP_BLIP_SECONDS := 2.5
const MINIMAP_BLIP_COLOUR := Color(0.7, 0.5, 0.95)

# ---- Round 13b: communication (no new mechanics)
# Gaps: seconds a gap must stay open for its urgency to reach 1 (marker pulse, minimap marker and arrow intensify).
const GAP_URGENCY_SECONDS := 8.0
# A gap seen again within this many metres of where it was last frame is the same gap (its age carries over).
const GAP_TRACK_RADIUS := 6.0
# Screen-space markers (pixels): the pulsing ring at a faltering person's feet, the progress ring, the "!" badge.
const FALTER_MARKER_RADIUS := 26.0
const FALTER_RING_RADIUS := 34.0
const FALTER_BADGE_SIZE := 26.0
const FALTER_PULSE_HZ_MIN := 1.0
const FALTER_PULSE_HZ_MAX := 3.2
const FALTER_CLOSED_SECONDS := 0.8
const FALTER_SEAL_COLOUR := Color(1.0, 0.9, 0.55)
# Gloom leaking in through an open gap: grey-violet motes drifting from the gap toward the border centre.
const LEAK_COLOUR := Color(0.55, 0.46, 0.7)
const LEAK_MOTES_PER_GAP := 8
const LEAK_MOTES_MAX := 120
# Only gaps within the view plus this many metres leak motes.
const LEAK_VIEW_MARGIN := 8.0
const LEAK_SPEED := 1.6
const LEAK_LIFE_SECONDS := 1.8
# Mood icons (screen-space, pixels) and the blocked-joy flash.
const MOOD_ICON_SIZE := 26.0
const MOOD_ICON_COLOURS: Array[Color] = [
	Color(1, 1, 1),
	Color(0.55, 0.65, 1.0),
	Color(1.0, 0.72, 0.3),
	Color(0.68, 0.74, 0.86),
	Color(0.78, 0.6, 1.0),
]
const GLUM_UP_ICON_COLOUR := Color(1.0, 0.9, 0.5)
const BLOCK_FLASH_SECONDS := 0.55
const BLOCK_SPARK_SECONDS := 0.4
const TETHER_COLOUR := Color(0.72, 0.6, 0.95, 0.4)
const TETHER_SNAP_SECONDS := 0.45
# The spirit meter (bottom centre) and its moments.
const SPIRIT_METER_WIDTH := 360.0
const SPIRIT_METER_HEIGHT := 22.0
const SPIRIT_MOMENT_SECONDS := 1.1
const SPIRIT_GAIN_COLOUR := Color(1.0, 0.88, 0.4)
const SPIRIT_SPEND_COLOUR := Color(0.7, 0.55, 1.0)
const SPIRIT_LOSS_COLOUR := Color(1.0, 0.4, 0.38)
# Layered introduction through the night (driven by NightCycle progress). Dimmed people emerge at NIGHT_CALM_FRACTION;
# each mood becomes active at its fraction (indexed by Person.Mood: NONE, GUARDED, SKITTISH, GLUM). One-time prompts
# last PROMPT_SECONDS and never overlap. `intro_on()` is false in automated tests (they set `intro_override` to turn it
# on to test the intro).
const MOOD_INTRO_FRACTIONS: Array[float] = [0.0, 0.35, 0.5, 0.65]
const PROMPT_SECONDS := 4.0
const PROMPT_FADE_SECONDS := 0.5
const INTRO_CHECK_SECONDS := 0.2
const INTRO_DIM_CAP := 0.669
# ---- Round 14: balance (scripts/moods.gd, topdown_main.gd, feedback_layer.gd) ----
# Sheltering: a dimmed person shelters only the single nearest wistful or gloomy person within SHELTER_RADIUS.
# Midnight surge: a person may sink to dimmed only if this many seconds have passed since the last one did. Others
# wait just under the dimmed line (DIM_WAIT_GLOOM) and ask again each frame, so the first to ask when the gate
# is open goes.
const DIM_ARRIVAL_MIN_GAP := 6.0
# A person refused the midnight gate waits just under the dimmed threshold (0.67), so the next frame's growth takes them
# over it and they ask again: the gate goes to whoever asks first in the level's order.
const DIM_WAIT_GLOOM := 0.669999
# A dimmed person hit by joy shows their progress ring for this long after the last hit.
const DIM_RING_SECONDS := 1.5
const DIM_HELP_TEXT := "Dimmed folk can be helped too — it takes longer"

# ---- Round 15: the shield leaks and wears down (scripts/moods.gd, person.gd, feedback_layer.gd) ----
# A dimmed person's shield: joy that hits the person it shelters still lets SHELTER_LEAK of its amount through. Each
# landing (one Person.receive_joy call on that person) wears the shield; on the SHELTER_HITS-th it pops.
const SHELTER_LEAK := 0.25
const SHELTER_HITS := 4
# After a pop the dimmed person cannot shelter anyone for this many seconds. Then, if still dimmed, a fresh shield.
const SHELTER_REGROW := 8.0
# Particles in the puff where a shield pops (on the sheltered person).
const SHELTER_POP_PUFF := 16
# The umbrella icon's alpha when its shield is about to pop (a fresh shield is full alpha; it scales between the two).
const SHELTER_WORN_ALPHA := 0.35
static var intro_override: int = -1

# The matchups form a soft cycle:
#   Music is strong against Art, Art is strong against Nature, Nature is strong against Music.
# Matching the affinity gives MATCH_MULT. The element that loses to the affinity gives WEAK_MULT.


# True when the layered introduction (round 13b) is on: always in the game, never under automated tests, unless a test
# sets `intro_override` to 1 (on) or 0 (off). -1 means no override.
static func intro_on() -> bool:
	if intro_override >= 0:
		return intro_override == 1
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


# Returns the visible grey level (0 light, 1 grey, 2 dark) for a hidden gloom value.
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
