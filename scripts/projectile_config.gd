class_name ProjectileConfig
extends RefCounted

# Joy projectiles (notes, paint, flowers), blooms, trails and their effects.

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
