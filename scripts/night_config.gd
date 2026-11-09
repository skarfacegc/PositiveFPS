class_name NightConfig
extends RefCounted

# The night: its length and strength curve, dimmed arrivals, first light and the gloom tides.

# Dusk to dawn: the level lasts NIGHT_LENGTH seconds. Grey strength is 1 at dusk and dawn and peaks at midnight.
const NIGHT_LENGTH := 180.0  # Round 11: 180 s (was 240).
const NIGHT_PEAK_EXTRA := 0.75

# Calm opening: the grey strength is NIGHT_CALM_STRENGTH for the first NIGHT_CALM_FRACTION of the night, then eases
# (smoothstep) into the curve above, which peaks at midnight.
const NIGHT_CALM_FRACTION := 0.25
const NIGHT_CALM_STRENGTH := 0.2

# Sheltering: a dimmed person shelters only the single nearest wistful or gloomy person within SHELTER_RADIUS.
# Midnight surge: a person may sink to dimmed only if this many seconds have passed since the last one did. Others
# wait just under the dimmed line (DIM_WAIT_GLOOM) and ask again each frame, so the first to ask when the gate
# is open goes.
# Round 17: DIM_ARRIVAL_MIN_GAP (round 14: 6 s) moved to the Round 17 block: 9 s.
# A person refused the midnight gate waits just under the dimmed threshold (0.67), so the next frame's growth takes
# them
# over it and they ask again: the gate goes to whoever asks first in the level's order.
const DIM_WAIT_GLOOM := 0.669999

# Midnight stagger (round 14: 6 s): the gap between two people sinking to dimmed.
const DIM_ARRIVAL_MIN_GAP := 9.0

# The round 22 playtests lost 20+ of 44 rescued people in the last 30 s. Cause, from the recordings: dimmed people
# arrived on a flat conveyor (the 9 s midnight gate, one every 9.0 s from 52 s to 151 s whatever the phase), so trouble
# came only as a growing stock of them; the grey strength was still 1.44 at 80% of the night (the "easing" phase was 82%
# of midnight's strength); and a dimmed person with a line of sight drains every rescued person within SPREAD_RADIUS at
# once, so a whole cohort passes the relapse line together about 14 s later.
# Dimmed arrivals: the gap between two sinks is DIM_GAP_RISING at the start of the rising phase and eases to
# DIM_ARRIVAL_MIN_GAP (9 s) at midnight, so trouble starts sooner; it holds there until DIM_GAP_EASE_START, then
# lengthens (smoothstep) to DIM_GAP_EASE_END seconds at dawn, so the easing phase brings few new dimmed people.
const DIM_GAP_RISING := 6.0
const DIM_GAP_EASE_START := 0.7
const DIM_GAP_EASE_END := 30.0

# Grey strength: the part above 1 fades out between NIGHT_EASE_START and dawn (smoothstep), so the last phase eases.
const NIGHT_EASE_START := 0.6

# The round 23 playtest called the end game unwinnable. Over the last FIRST_LIGHT_SECONDS of the night a front of dawn
# starts at the map edge and moves inward (a square, like the plaza), reaching the centre at dawn. People it has passed
# lose FIRST_LIGHT_LIFT_RATE gloom a second (dimmed lifts to gloomy, gloomy to wistful), nobody unrescued behind it
# sinks (they are calm), and rescued people behind it no longer drain (Person.dawn_lit). People ahead of it get none of
# this, so it helps but does not win the night alone.
const FIRST_LIGHT_SECONDS := 45.0
const FIRST_LIGHT_LIFT_RATE := 0.03  # Gloom per second (0 to 1 scale): a dimmed person is wistful after about 33 s.
const FIRST_LIGHT_CALM := 0.3  # Seconds of calm set on each unrescued person behind the front every frame.
const FIRST_LIGHT_BAND_WIDTH := 4.0  # Metres of warm band just inside the front.
const FIRST_LIGHT_Y := 0.05
const FIRST_LIGHT_TINT := Color(1.0, 0.86, 0.55, 0.1)  # The lit ground behind the front.
const FIRST_LIGHT_BAND_COLOUR := Color(1.0, 0.8, 0.45, 0.22)
const FIRST_LIGHT_MINIMAP_COLOUR := Color(1.0, 0.82, 0.45)
const FIRST_LIGHT_MINIMAP_TINT := 0.2  # How much of the warm colour the lit part of the minimap takes.
const FIRST_LIGHT_TEXT := "First light: dawn is coming in from the edges"  # The notice when it starts (Intro.notice).

# The dawn front is a circle closing on the plaza centre. It starts at the radius of the plaza's corners (so it covers
# the whole play area) and reaches 0 at dawn; a person is passed once the front's radius is at or inside their distance.
const FIRST_LIGHT_START_RADIUS := 71.0  # Metres: just over half the plaza's diagonal (50 x 1.414 = 70.7).
const FIRST_LIGHT_RING_SEGMENTS := 72  # Straight pieces in the placeholder ring and in the minimap outline.

# Two tides a night: one in the rising phase and one at midnight. Each comes from an angle drawn from the level's seed
# (RNG_SEED + TIDE_SEED_OFFSET), starting at a time drawn inside its window (night progress). TIDE_WARN_SECONDS before
# it hits: a fog edge on the minimap, one edge pointer toward that side and a notice. While it passes (TIDE_SECONDS,
# constant) border members within TIDE_HALF_WIDTH of that direction (seen from the border's centre) drain joy
# TIDE_DRAIN_MULT times as fast (Person.tide_mult, on their normal drain only). Placeholder look: a grey fog band.
const TIDE_SEED_OFFSET := 25
const TIDE_RISING_FROM := 0.3  # Night progress window for the rising tide's start (the rising phase is 0.25 to 0.5).
const TIDE_RISING_TO := 0.42
const TIDE_MIDNIGHT_FROM := 0.5  # The midnight tide's window (the midnight phase is 0.5 to 0.75).
const TIDE_MIDNIGHT_TO := 0.6
const TIDE_WARN_SECONDS := 15.0
const TIDE_SECONDS := 12.0
const TIDE_HALF_WIDTH := PI / 4.0  # Radians either side of the tide's direction: a quarter of the compass (90 degrees).

# Round 26: the wave shoves instead of draining. TIDE_PUSH is the force it puts on the side it comes from once its front
# is TIDE_SHOVE_DEPTH metres past the line (it ramps in over TIDE_PUSH_REACH + TIDE_SHOVE_DEPTH of approach); the front
# arrives over the first TIDE_ARRIVE share of the passing. TIDE_FIGURES dark figures walk in the fog band.
const TIDE_PUSH := 2.0
const TIDE_PUSH_REACH := 4.0
const TIDE_SHOVE_DEPTH := 2.0
const TIDE_ARRIVE := 0.4
const TIDE_FIGURES := 9
const TIDE_FIGURE_HEIGHT := 1.7
const TIDE_FIGURE_SPREAD := 20.0  # Metres either side of the band's middle the figures spread.
const TIDE_FIGURE_COLOUR := Color(0.2, 0.22, 0.27, 0.85)
const TIDE_TEXT := "A gloomy tide is rolling in from the %s"  # The notice at the warning (%s is the side).
const TIDE_PLAIN_TEXT := "A gloomy tide is rolling in"  # The prompt's own line, when no side is given.
const TIDE_POINTER_REFRESH := 0.2  # Seconds between two works-out of the edge pointer.
const TIDE_POINTER_FAR := 100.0  # Metres out from the border's centre: the pointer uses only the direction.
const TIDE_POINTER_RING := 9.0  # Pixels, as WOBBLE_ALERT_RING.
const TIDE_POINTER_ARROW := 8.0  # Pixels, as WOBBLE_ALERT_ARROW.
const TIDE_POINTER_COLOUR := Color(0.74, 0.8, 0.86)  # A cool grey (gaps are coral, wobbles amber).
const TIDE_FOG_FAR := float(Config.TD_PLAZA_SIZE) * 0.6  # Metres from the centre: where the fog band starts (outside).
# Metres from the centre: where its drift in over the passing ends.
const TIDE_FOG_NEAR := float(Config.TD_PLAZA_SIZE) * 0.2
const TIDE_FOG_WIDTH := float(Config.TD_PLAZA_SIZE) * 0.9  # The band's length along the side.
const TIDE_FOG_DEPTH := 12.0 * Config.WORLD_SCALE  # The band's depth (metres).
const TIDE_FOG_Y := 0.06  # Height above the ground (just above the first light front's 0.05).
const TIDE_FOG_COLOUR := Color(0.6, 0.64, 0.7)
const TIDE_FOG_ALPHA := 0.42  # The band's most opaque alpha.
const TIDE_FOG_FADE := 0.15  # The share of the passing over which the band fades in and out.
const TIDE_MINIMAP_COLOUR := Color(0.7, 0.74, 0.8, 0.9)  # The minimap's fog edge (the outer band; inner ones fade).
const TIDE_MINIMAP_BANDS := 3  # Concentric arcs making the edge.
const TIDE_MINIMAP_BAND_STEP := 1.6  # Metres between two arcs of the edge (about two minimap pixels).
const TIDE_MINIMAP_SEGMENTS := 16  # Straight pieces per arc.
