class_name SpiritConfig
extends RefCounted

# Spirit, going dim, grabs, the joy burst, spare spirit and the burst's result effects.

# Seconds before the joy burst can be used again.
const TD_BURST_COOLDOWN := 8.0

# Everyone this close to the player gets the burst, in metres.
const TD_BURST_RADIUS := 5.5

# Joy given to each person by a burst. They use their own element, so it always counts as a match.
const TD_BURST_JOY := 350.0

# How long the burst ring takes to expand and fade, in seconds.
const TD_BURST_TIME := 0.35

# Round 12a: spirit, going dim and grabs
# Spirit is the player's spendable resource (0..SPIRIT_MAX). Rescues fill it, the joy burst spends it, a grab drains
# it.
const SPIRIT_MAX := 100.0
const SPIRIT_START := 50.0
const SPIRIT_PER_RESCUE := 20.0
const BURST_SPIRIT_COST := 30.0

# Joy fire rate: full at this fraction of spirit or more, then down linearly to SPIRIT_MIN_FIRE_FRACTION at 0+.
const SPIRIT_FULL_FIRE_FRACTION := 0.5
const SPIRIT_MIN_FIRE_FRACTION := 0.4

# Going dim (spirit 0): half walk speed, no joy. Recovery only inside the border, or near the landmark before a
# border.
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

# G/Q clears dimmed people off the border: within BURST_CLEAR_RADIUS of the player, every dimmed person within
# BURST_BORDER_BAND of the line (outside pressing it, or inside through a gap) is pushed BURST_PUSH_DISTANCE away from
# the border and lifted to the gloomy band (gloom BURST_LIFT_GLOOM, joy 0, then calm). Border members and other
# people in range still get the joy hit (TD_BURST_JOY), so a strained stretch is topped up as well.
const BURST_CLEAR_RADIUS := 8.0
const BURST_BORDER_BAND := 3.5
const BURST_PUSH_DISTANCE := 4.0
const BURST_LIFT_GLOOM := 0.5

# A cleared person is calm this long (no gloom gain, from growth or from a dimmed neighbour), so they do not sink
# straight back and walk up to the line again.
const BURST_CALM_SECONDS := 16.0  # Round 24: was 10.0.
const BURST_FX_SECONDS := 0.6  # Round 25: was 0.9 (short effects).
const BURST_FX_COLOUR := Color(1.0, 0.9, 0.5)
const FX_TEXT_SECONDS := 1.1  # Round 25: was 1.6.
const FX_TEXT_RISE := 1.8
const FX_TEXT_SIZE := 0.012  # Label3D pixel_size; small.
const FX_HALO_SECONDS := 0.9  # Round 25: was 1.5.
const FX_LIFT_TEXT := "lifted %d"

# The round 23 playtests left the dimmed stock at about 6 from midnight on (7 bursts lifted 3 dimmed people in a game),
# and one dimmed person's drain tipped a whole group over the relapse line on the same frame.
# Beatable dimmed: a burst lifts every dimmed person within BURST_LIFT_RADIUS of the player (round 22: only those within
# BURST_BORDER_BAND of the line, inside BURST_CLEAR_RADIUS, 8 m). Those near the line are still pushed back. A lifted
# person stays calm BURST_CALM_SECONDS (16 s, was 10 s). Joy lands DIMMED_JOY_MULT times as hard on a dimmed person (so
# about 5 matching shots rescue them, was about 9) and fades DIMMED_FADE_MULT times as fast, so progress holds.
const BURST_LIFT_RADIUS := 14.0

# Spare spirit (scripts/spirit_warmth.gd): what a gain would have added past a full meter goes into a pool (at most
# SPARE_POOL_MAX spirit). The pool pours out at SPARE_WARM_RATE joy a second in all, one gift every
# SPARE_WARM_INTERVAL to the most strained border member (lowest joy share), SPARE_JOY_PER_SPIRIT joy for each spirit
# spent. A person is only warmed while under SPARE_WARM_CEILING of the joy they need. Joy needed is JOY_MAX (1000) or
# more, a dimmed person drains SPREAD_DRAIN_RATE (60) a second, so a rescue's 20 spare spirit (500 joy) is about eight
# seconds of one presser.
const SPARE_POOL_MAX := 40.0
const SPARE_JOY_PER_SPIRIT := 25.0
const SPARE_WARM_RATE := 80.0
const SPARE_WARM_INTERVAL := 0.5
const SPARE_WARM_CEILING := 0.9
const SPARE_GLOW_SECONDS := 1.4  # How long a warmed person is marked (Person.React.WARM; round 25: a gift marker).
