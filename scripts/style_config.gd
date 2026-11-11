class_name StyleConfig
extends RefCounted

# Styled look numbers (scenery, atmosphere, props, ambient life, jog). The rules never read them.

# Visual numbers shared by the styled look's new pieces (the rules never read them).
# The placeholder look ignores all of them.
# Round 25: the strain rings and pings, the coral gap column, the patch posts, the lift column and the wobble's
# closing ring were removed (EdgeRibbon and EdgeMarkerFx replace them).
const CP5_WARM_TINT := 0.75  # How far a dimmed body's coat takes the affinity colour at full joy (styled look).
const CP5_FIRST_LIGHT_SKY := Color("#f2b886")  # The sky the styled view warms toward as first light moves in.
const CP5_FIRST_LIGHT_SKY_MIX := 0.5  # How much of it at dawn.

# The styled stipple was too strong: each one is cut to about half (the old value is in the comment). The shadow dither
# is set on every toon material (StyleKit.mat) and on the ground; the glow and ground dot shares on their shaders.
const STYLED_DITHER_LIGHT := 0.08  # The shadow band dither amount (was 0.16).

# The player's run (Shift) on top of the walk, applied through Gait.jog (the player only; people keep their gait).
const JOG_CADENCE := 1.15  # Step cycles per second at a full run are multiplied by this.
const JOG_CYCLE_CAP := 4.2  # The most step cycles per second the player's run may take (the walk's cap is 3.4).
const JOG_SWING_ANGLE := 1.25  # Radians the legs swing either way at a full run (the walk swings 1.0).
const JOG_LEAN := 0.14  # Extra forward lean at a full run (radians; the walk leans 0.03).
const JOG_BOB := 0.06  # Extra bounce at a full run (times the leg length; the walk bounces 0.03).
const JOG_DUST_MIN_RUN := 0.5  # How much of a run a footfall needs to raise a dust puff (styled look).
const JOG_DUST_SECONDS := 0.4  # How long a dust puff lasts.
const JOG_DUST_RADIUS := 0.7  # How far a dust puff spreads (metres).
const JOG_DUST_SIDE := 0.22  # How far a puff starts to the side of the player's centre (metres, at each foot).

# Scenery and ambient life only read the game (paint weight, a block's tint, the night's light); they own their random
# numbers and change nothing in the rules.
const C7_SEED := 7007  # The scenery's own random numbers (never the simulation's).
const C7_PROPS_INTERVAL := 0.1  # Seconds between two redraws of the street props.
const C7_BLOOM_SECONDS := 4.0  # Seconds a prop takes to go from bare to full bloom (and back).
const C7_LINE_MAX_DIST := 27.5  # Blocks closer than this (metres) get a bunting or washing line (Grid fixes: was 22).
const C7_LINE_SAG_GLOOM := 1.5  # How far a limp line hangs in gloom (metres).
const C7_LINE_SAG_BLOOM := 0.5  # How far a taut line hangs in bloom (metres).
const C7_LAMP_LEAN := 0.3  # Radians a broken lamp post leans in gloom.
const C7_DAY_ENERGY_LOW := 0.5  # Sun energy at or below this is night (ambient life); above LOW + RANGE, day.
const C7_DAY_ENERGY_RANGE := 0.35
const C7_AMBIENT_MIN_WEIGHT := 0.35  # Paint weight a spot needs for butterflies and fireflies to drift there.
const C7_BUTTERFLIES := 9  # (was 14, then 28 in 0.3.1; 0.3.1 playtest 2: fewer and larger, see L31_BUTTERFLY_SCALE)
const C7_FIREFLIES := 44  # (was 22)
const C7_DRIFT_RADIUS := 2.2  # How far a butterfly or firefly wanders from its anchor (metres).
const C7_ANCHOR_REACH := 7.0  # How far from a beautified block an anchor may be picked (metres).
const C7_ANCHOR_INTERVAL := 0.5  # Seconds between two tries to give an idle butterfly or firefly an anchor.
const C7_FADE_SECONDS := 1.5  # Seconds an ambient piece takes to fade in or out.
const C7_BIRD_SECONDS := 3.0  # Seconds a bird takes to fly in and land on a beautified roof.
const C7_BIRD_START := Vector3(5.0, 5.0, 3.0)  # Where a bird comes from, relative to its roof (turned per block).
const C7_IDLE_AFTER := 2.0  # Seconds a rescued person stands still before they start an idle action.
const C7_IDLE_STILL := 0.03  # The most a standing person may move between two checks (metres).
const C7_IDLE_MIN_WEIGHT := 0.4  # Paint weight needed under a person for an idle action.
const C7_IDLE_EASE := 0.8  # Seconds an idle action takes to start or stop.
const C7_SIT_DROP := 0.22  # How far the sitting person's drawing sinks (their rule position never moves).
const CP7_FIGURE_COLOUR := "#4a4560"  # The styled tide figures: dark violet, a little lighter than the ink.
const CP7_FIGURE_HEIGHT := 1.6  # Metres to a styled figure's head (placeholder: TIDE_FIGURE_HEIGHT).

# Checkpoint 7: cleanup and look (shaders/style_common, style_toon, style_glow, style_ring, style_wedge,
# style_outline, scripts/looks/looks.gd). Dithering is gone from the toon light, glows, rings, wedge and reach outlines.
const CP7_TOON_SOFT := 0.05  # Half the width (in light level) of the soft step between the toon shadow bands.

# Styled look only, scenery only: reads the night clock, the held landmarks and the paint weights, writes nothing.
const CP7_GROUND_GLOOM := 0.55  # How far the cold desaturated tint reaches over unpainted ground (0..1).

# How much of the living pieces: tufts, flowers, moss, puddles; cracks, litter, dead leaves (1 = as first built).
const CP7_GROUND_LIFE := 1.5
const CP7_MIST_STRENGTH := 0.4  # Peak alpha of the low mist over unpainted ground (the ground reads through it).
const CP7_MIST_SCALE := 0.07  # Noise scale of the mist (per metre; smaller = bigger banks).
const CP7_MIST_HEIGHT := 0.5  # Metres above the ground of the low layer (the high layer sits 2.4 times higher).
const CP7_MIST_COLOUR := Color(0.5, 0.56, 0.7)
const CP7_SKY_NIGHT_MIX := 0.8  # How far toward it the sky goes at midnight.
const CP7_SKYLINE_RADIUS := 66.0  # Metres from the centre: the rooftops round the plaza.
const CP7_SKYLINE_ROOFS := 10  # Houses in the sector behind each landmark.
const CP7_SKYLINE_ARC := 1.5  # Radians a sector spans.
const CP7_SKYLINE_EASE := 2.0  # Seconds a sector takes to light up or go grey.
const CP7_BODY_GREY := Color(0.36, 0.38, 0.46)
const CP7_ROOF_GREY := Color(0.30, 0.32, 0.40)
const CP7_ROOF_WARM := Color(1.0, 0.78, 0.42)

# The push fog is a low storm cloud band (shaders/style_cloud.gdshader, looks/style_push.gd): soft puffs in rows along
# the pushed stretch, dark in the core and pale at the edge.
const L31_FOG_EDGE := "#59557a"  # The violet grey at the cloud's edge.
const L31_FOG_CORE := "#14122a"  # The dark storm core.
const L31_FOG_ALPHA := 0.95  # The most opaque a puff gets (its edge falls off smoothly).
const L31_FOG_PUFF := 6.4  # Metres across one puff (was 5.2: the first cloud was too faint to pick out).
const L31_FOG_SPACING := 1.8  # Metres between two puffs along the band.
const L31_FOG_ROWS := 4  # Rows of puffs across the band's depth (was 3).
const L31_FOG_TOP := 3.2  # Metres: how high the tallest puff stands (low: the figures stay half in view).
const L31_FOG_MIN_LENGTH := 8.0  # Metres: the shortest the band gets.
const L31_FOG_CHURN := 0.55  # How far (a share of a puff) the puffs roll about.
const L31_SOFT_PRIORITY := 10  # Render priority of the mist and the storm cloud (the post-process quad is 0).

# The ground life, props and ambient life read at play zoom (19.5): tufts, flowers and moss are drawn this many times
# bigger than before (the shader's `life_size`), and creatures, props and extras are scaled up and lifted in colour.
const L31_GROUND_SIZE := 3.0
const L31_GROUND_CONTRAST := 0.55  # How far the living pieces' colours push toward bold (0 = as before, 1 = full).
const L31_AMBIENT_SCALE := 2.6  # Butterflies, fireflies, birds and the idle extras are drawn this many times bigger.
const L31_BUTTERFLY_SCALE := 4.2  # Butterflies only (fewer, larger: they hurt performance and read small at play zoom).
const L31_AMBIENT_RECHECK := 0.4  # Seconds between the ambient life's paint lookups (cached between).
const L31_PROP_SCALE := 1.8  # Street props are drawn this many times bigger (lamp heads, planter flowers, stall cloth).
const L31_PROP_LIFT := 0.55  # How far a bare prop's colour lifts toward its warm colour so it reads on grey ground.

# Props (#48): the playtest found no props in the play-zoom frame. Cause: placement (all of them stood at the blocks,
# 25 m or more from the middle where the night is played), then size and contrast. Lamps and benches are drawn bigger
# and warmer. (0.3.3: the props now follow the streets, see "Town layout" below.)
const L31_LAMP_SCALE := 1.35  # Lamps are drawn this many times bigger again than the other props.
const L31_LAMP_HEIGHT := 0.65  # A lamp post's height as a share of its drawn scale (its head was out of frame).
const L31_BENCH_SCALE := 1.4  # Benches too.
const L31_BENCH_LIFT := 0.8  # A bare bench lifts this far toward its warm colour.
const L31_LAMP_MIN_GLOW := 0.7  # A lamp's glow never falls below this, even in gloom, so it reads as a warm light.
const L31_LAMP_HALO := 0.5  # The lamp's halo radius as a share of the old 0.75 x scale (the soft balls now show).

# Wires: no bare line in gloom. Where the zone's paint is (the line's unfurl is at least L31_LINE_SHOW) the bunting is
# strung at roof height between two posts, each L31_LINE_POST_OFFSET metres from its block's centre.
const L31_LINE_POST_HEIGHT := 3.4  # Metres: the posts and the line's ends (a block is 3 m high).
const L31_LINE_POST_OFFSET := 2.5
const L31_LINE_SHOW := 0.3
const L31_LINE_BOLD := 1.8  # How much thicker the bunting posts and rope, and bigger its flags, are drawn.

# Wires (#42): the player's styled model is about 3.1 m tall to the tip of the hat feather (measured by a test from
# StylePeople.build_player). The bunting posts, the rope's lowest sag and the longest flag all stay above it.
const L32_PLAYER_HEIGHT := 3.1  # Metres: the styled player's height (the test measures the model and checks this).
const L32_LINE_CLEARANCE := 0.3  # Metres: the least the lowest bunting point stands above the player's height.
const L32_LINE_POST_HEIGHT := 5.3  # Metres: the posts and the line's ends (was L31_LINE_POST_HEIGHT 3.4).
const L32_LINE_RISE := 0.1  # A line's posts reach full height once it is this far past L31_LINE_SHOW (was 0.3).
const L32_LINE_SAG_GLOOM := 1.0  # How far a limp line hangs at its middle (was C7_LINE_SAG_GLOOM 1.5).
const L32_LINE_SAG_BLOOM := 0.4  # How far a taut line hangs at its middle (was C7_LINE_SAG_BLOOM 0.5).

# Lamps (#49): a cone of light from the head to a pool on the ground, and a small glow at the head. Cool pale blue-white
# in gloom, warm amber in full bloom; stronger at night, faint by day. The alphas are low on purpose: the light is
# drawn over the people and must not hide them or a gap.
const L32_LIGHT_COOL := Color(0.74, 0.88, 1.0)  # The light of a lamp in gloom (bloom 0).
const L32_LIGHT_WARM := Color(1.0, 0.74, 0.32)  # The light of a lamp in full bloom.
const L32_LIGHT_GLOOM := 0.75  # A gloom lamp's light strength as a share of a bloomed lamp's.
const L32_LIGHT_DAY := 0.12  # The light's strength by day, as a share of its strength at night.
const L32_CONE_ALPHA := 0.26  # The cone's alpha at the head at full strength.
const L32_POOL_ALPHA := 0.3  # The pool's alpha in its middle at full strength.
const L32_HEAD_ALPHA := 0.3  # The small glow at the head.
const L32_POOL_RADIUS := 3.0  # Metres: the pool on the ground (and the cone's width at the ground).
const L32_MAX_LIGHT_ALPHA := 0.35  # No light shape is ever more opaque than this (the test checks the constants).
