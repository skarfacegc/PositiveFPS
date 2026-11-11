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
const FIRST_LIGHT_START_RADIUS := 81.0  # Metres: just over half the plaza's diagonal (57 x 1.414 = 80.6; Grid fixes).
const FIRST_LIGHT_RING_SEGMENTS := 72  # Straight pieces in the placeholder ring and in the minimap outline.

# Walls and gates: Pressure (#14). One surge a night replaces the two tides. It comes down one street (drawn from the
# level's seed, RNG_SEED + SURGE_SEED_OFFSET, among the streets that meet a gate of the zone when the warning starts)
# and peaks at midnight (the middle of the push is SURGE_PEAK_PROGRESS of the night). Warning (SURGE_WARN_SECONDS): fog
# gathers at the far end of that street, a mark on the minimap, one edge pointer, the light cools and a banner (again
# SURGE_SOON_SECONDS before the push). Surge (SURGE_SECONDS): the fog rolls down the street and pushes the gate it
# meets with SURGE_PUSH (times the night's strength) and the gates either side with SURGE_SIDE_SHARE of that. Aftermath
# (SURGE_AFTERMATH_SECONDS): the fog is gone, the light warms again and dimmed arrivals ease (the gap between two is
# SURGE_AFTERMATH_GAP_MULT times longer, easing back to normal).
const SURGE_SEED_OFFSET := 25
const SURGE_WARN_SECONDS := 40.0
const SURGE_SOON_SECONDS := 12.0
const SURGE_SECONDS := 50.0
const SURGE_PEAK_PROGRESS := 0.5
const SURGE_AFTERMATH_SECONDS := 30.0
const SURGE_AFTERMATH_GAP_MULT := 2.0
const SURGE_PUSH := 1.5
const SURGE_SIDE_SHARE := 0.5
const SURGE_ARRIVE := 0.4  # The front reaches the gate over this share of the surge; the push builds as it does.
const SURGE_FADE := 0.2  # The push (and the fog) fade over the last share of the surge.
const SURGE_STREET_REACH := 0.25  # Metres beyond half a street's width within which a gate counts as meeting it.
const SURGE_CHILL := 0.45  # How far the light cools toward SURGE_CHILL_COLOUR at the height of a warning or surge.
const SURGE_CHILL_COLOUR := Color(0.5, 0.62, 0.82)
const SURGE_FOG_WIDTH := 16.0  # Metres across the street the fog band spreads (a street is 12 m wide).
const SURGE_WARN_TEXT := "The gloom is gathering at the %s end of the %s street"  # %s: the end, then the street.
const SURGE_SOON_TEXT := "The gloom is close: hold the %s street"
const SURGE_START_TEXT := "The gloom is surging down the %s street"
const SURGE_PLAIN_TEXT := "A gloomy surge is coming"  # The prompt's own line, when no street is given.
const SURGE_MINIMAP_LENGTH := 30.0  # Metres of the street the minimap marks from its far end.
const SURGE_MINIMAP_BANDS := 3
const SURGE_MINIMAP_STEP := 1.2  # Metres between two bands of the mark.

# The fog band and its dark figures (the placeholder look; the styled look has its own, see StylePush).
const TIDE_HALF_WIDTH := PI / 4.0  # StylePush.fog_length: the stretch a cloud covers seen from the centre.
const TIDE_FIGURES := 9
const TIDE_FIGURE_HEIGHT := 1.7
const TIDE_FIGURE_SPREAD := 20.0  # Metres either side of the band's middle the figures spread.
const TIDE_FIGURE_COLOUR := Color(0.2, 0.22, 0.27, 0.85)
const TIDE_POINTER_REFRESH := 0.2  # Seconds between two works-out of the edge pointer.
const TIDE_POINTER_FAR := 100.0  # Metres out from the border's centre: the pointer uses only the direction.
const TIDE_POINTER_RING := 9.0  # Pixels, as WOBBLE_ALERT_RING.
const TIDE_POINTER_ARROW := 8.0  # Pixels, as WOBBLE_ALERT_ARROW.
const TIDE_POINTER_COLOUR := Color(0.74, 0.8, 0.86)  # A cool grey (gaps are coral, wobbles amber).
const TIDE_FOG_WIDTH := float(Config.TD_PLAZA_SIZE) * 0.9  # The band's length along the side.
const TIDE_FOG_DEPTH := 12.0 * Config.WORLD_SCALE  # The band's depth (metres).
const TIDE_FOG_Y := 0.06  # Height above the ground (just above the first light front's 0.05).
const TIDE_FOG_COLOUR := Color(0.6, 0.64, 0.7)
const TIDE_FOG_ALPHA := 0.42  # The band's most opaque alpha.
const TIDE_MINIMAP_COLOUR := Color(0.7, 0.74, 0.8, 0.9)  # The minimap's surge mark (the outer band; inner ones fade).
