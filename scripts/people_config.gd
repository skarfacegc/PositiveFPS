class_name PeopleConfig
extends RefCounted

# People: gloom, joy fading, relapse and wobble, wandering, spawning, grace, stage changes and reactions.

# Gloom: a hidden 0.0 (light) to 1.0 (nearly black) value. It is shown as three stepped levels.
const GLOOM_START_MIN := 0.0  # Random starting gloom for each person, lowest...
const GLOOM_START_MAX := 0.5  # ...and highest.
const GLOOM_GROWTH := 0.006  # Gloom gained per second by an unrescued person, base rate.

# Extra gloom per second for each metre from the nearest colour zone (round 13a: divided by WORLD_SCALE).
const GLOOM_GROWTH_PER_METER := 0.0008 / Config.WORLD_SCALE

# Round 11: growth is multiplied by this while the person is at grey (level 1), so the grey -> dimmed step is slower.
# Light grey -> grey is unchanged (1.0 is the old rate). Applies to growth only, not spread or contagion.
const GLOOM_DIMMED_STEP_MULT := 0.65
# Gloom growth distance when nobody is rescued yet (no colour zones).
const NO_ZONE_DISTANCE := 20.0 * Config.WORLD_SCALE
const ZONE_RADIUS := 6.0 * Config.WORLD_SCALE  # Each rescued person creates a colour zone of this radius (metres).
const SPREAD_RADIUS := 6.0 * Config.WORLD_SCALE  # How far gloom spreads from a dimmed person (metres).
const SPREAD_GLOOM_RATE := 0.03  # Gloom per second given to nearby unrescued people by a dimmed person.
const SPREAD_DRAIN_RATE := 60.0  # Joy per second drained from nearby rescued people by a dimmed person.

# Body colour for each level (0 light, 1 grey, 2 dimmed).
const LEVEL_COLORS: Array[Color] = [Color(0.82, 0.82, 0.82), Color(0.5, 0.5, 0.52), Color(0.16, 0.16, 0.18)]

# Joy needed at each level, as a multiple of JOY_MAX. Dimmer people need more joy.
# Round 14: dimmed 2.0 -> 1.6 (the counter to the midnight dimmed people; wistful and gloomy unchanged).
const LEVEL_JOY_MULT: Array[float] = [1.0, 1.5, 1.6]

# Only people at this level or dimmer spread gloom (2 = only dimmed people).
const SPREAD_LEVEL := 2

# Joy fading: partly-helped people drain back toward grey if nobody keeps hitting them.
const JOY_FADE_DELAY := 1.5  # Seconds without a hit before an unrescued person's joy starts to fade.
const JOY_FADE_RATE := 120.0  # Joy lost per second while fading.

# Relapse: a rescued person whose joy falls below this fraction of their joy needed turns grey again.
const RELAPSE_FRACTION := 0.5

# Warning: below this fraction a rescued person starts flickering and shows "!" (before they relapse).
const WARN_FRACTION := 0.85

# Walking speed for wandering people, in metres per second.
const TD_WANDER_SPEED := 0.92  # Round 11: about 15% faster than round 10 (0.8).

# Wandering people pick a new spot within this distance of where they are, in metres.
const TD_WANDER_RANGE := 4.0

# A wandering person counts as having reached their spot when this close, in metres.
const TD_WANDER_REACH := 0.5

# Wandering people pick a new spot after a random time between these two values, in seconds.
const TD_WANDER_TIME_MIN := 3.0
const TD_WANDER_TIME_MAX := 6.0

# Dimmed people drift toward a rescued person at this speed, in metres per second (round 6: slowed from 1.3).
# Round 11: 0.92 (15% faster than round 10's 0.8). Round 13a: +10% again.
const TD_DIMMED_DRIFT_SPEED := 1.01

# Dimmed people stop drifting when this close to their rescued person, in metres.
const TD_DIMMED_STOP_DISTANCE := 2.5

# At most this many dimmed people may drift toward the same rescued person. Others pick the next-nearest rescued
# person
# with a free slot, or wander. This stops the crowd piling up on one person.
const TD_MAX_PURSUERS_PER_TARGET := 2

# Everyone steers away from people within this distance (metres). Dimmed and wandering people both do it.
const TD_SEPARATION_RADIUS := 2.2

# How strongly the separation push is added to a person's movement direction (before it is normalised).
const TD_SEPARATION_STRENGTH := 1.2

# Top-down joy drain is scaled by this. Dimmed people drain rescued joy at 0.4 of the round 6 rate (round 7). It is
# also
# scaled by (1 - protection) of the rescued person (see GloomSim), so cover makes it smaller.
const TD_DRAIN_MULTIPLIER := 0.4

# After a rescue, the person cannot be drained by nearby gloom for this many seconds (a warm halo shows it).
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

# People are placed at least this far from the plaza edge, in metres.
const TD_SPAWN_EDGE := 3.0 * Config.WORLD_SCALE

# People are never placed closer than this to the centre (where the player starts), in metres.
const TD_SPAWN_CENTRE_CLEAR := 5.0 * Config.WORLD_SCALE

# Minimum distance between two people when placing them, in metres.
const TD_SPAWN_SPACING := 2.5 * Config.WORLD_SCALE

# Distance kept beyond an obstacle block's edge, for spawning and walking, in metres.
const TD_BLOCK_CLEARANCE := 1.5

# Dimmed people chase the weakest rescued person (lowest protection, ties to the nearest) within this many metres.
const TD_PURSUIT_SEARCH_RADIUS := 25.0 * Config.WORLD_SCALE

# People are drawn this many times bigger (visual only: their collision and hit radius do not change), and their joy
# label sits this high above the ground, in metres.
const PERSON_VISUAL_SCALE := 1.5
const PERSON_LABEL_HEIGHT := 3.9

# The dimmed-person haze of the placeholder look (a soft dark disc on the ground), radius in metres.
const DIM_AURA_RADIUS := 1.7
const DIM_AURA_COLOUR := Color(0.05, 0.05, 0.08, 0.38)

# A dimmed person outside the border whose target is a border member walks up to the line (stopping this far from the
# member, which the line itself holds them short of), so they really press it. (Before they stopped 2.5 m from the
# member, beyond BORDER_PRESS_RANGE of the line, and pressed only for a moment.)
const TD_DIMMED_PRESS_STOP := 0.6

# Noticeable stage changes: a grey-violet (gloomy, not icy) puff and ripple when someone sinks a stage, a warm one
# when
# they lift. The minimap shows a blip for BLIP_SECONDS when someone becomes dimmed.
const STAGE_SINK_COLOUR := Color(0.42, 0.34, 0.55)
const STAGE_LIFT_COLOUR := Color(1.0, 0.82, 0.45)
const STAGE_PUFF_COUNT := 28
const STAGE_RIPPLE_RADIUS := 1.8
const STAGE_RIPPLE_SECONDS := 0.7

# A dimmed person hit by joy shows their progress ring for this long after the last hit.
const DIM_RING_SECONDS := 1.5
const DIM_HELP_TEXT := "Dimmed folk can be helped too — it takes longer"

# The teal glow of Person.React.PATCH (a reaction the looks still draw; the F patch itself is gone in round 26).
const PATCH_COLOUR := Color(0.35, 0.95, 0.85)
const DIMMED_JOY_MULT := 1.8
const DIMMED_FADE_MULT := 0.4
const DIMMED_PROGRESS_TINT := 0.95  # How far a dimmed body warms to its colour at full joy (0.6 for others).

# Catchable waves: a rescued person drained below the relapse line wobbles for WOBBLE_SECONDS first (varied per person
# and per wobble by +/- WOBBLE_JITTER), greying and swaying in the placeholder look (WOBBLE_SWAY radians, WOBBLE_RATE
# radians a second). A joy hit in that window saves them: their joy goes back to RELAPSE_FRACTION + WOBBLE_SAVE_JOY
# of what they need and drain skips them for WOBBLE_SAVE_GRACE seconds. When the wobble ends they relapse, but
# RelapseWave lets only one person relapse per RELAPSE_GATE_GAP seconds, so a group goes a few at a time.
const WOBBLE_SECONDS := 5.0
const WOBBLE_JITTER := 0.2
const WOBBLE_SAVE_JOY := 0.2
const WOBBLE_SAVE_GRACE := 4.0
const WOBBLE_SWAY := 0.35
const WOBBLE_RATE := 11.0
const WOBBLE_GREY_FROM := 0.35
const RELAPSE_GATE_GAP := 0.6

# Things react: a patch makes the border people at that spot hop, turn toward it and glow; a burst makes each lifted
# person hop and glow warm. The cues for F and G sit on the HUD beside the spirit meter and glow when ready. The reach
# preview has no hover words (a refusal shows only when E is pressed). A pull-in retreats one arm at a time: its outline
# fades for BEACON_PULL_FADE_SECONDS, then it walks in at BEACON_PULL_CALM_RATE; past BEACON_PULL_URGENT_RATIO of the
# length the people can hold it speeds up (and skips the fade) so the spacing stays under BORDER_MAX_GAP.
const REACT_PATCH_SECONDS := 1.2
const REACT_PATCH_HOPS := 2.0
const REACT_PATCH_HOP_HEIGHT := 0.55
const REACT_PATCH_MAX := 10  # Most border people that react to one patch.
const REACT_PATCH_REACH := 4.0 * Config.WORLD_SCALE * 1.3
const REACT_PATCH_STAGGER := 0.35  # Seconds of delay across the patch radius (nearest first).
const REACT_LIFT_SECONDS := 1.0
const REACT_LIFT_HOP_HEIGHT := 0.85
const REACT_GLOW_ENERGY := 1.8
