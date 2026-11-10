class_name PushConfig
extends RefCounted

# The physical push on the line (scripts/border_push.gd).

# Only visible things push the line. A dimmed person within PUSH_LEAN_RANGE outside it leans on it with force
# PUSH_PER_PERSON x the night's strength x their push strength (joy at them takes PUSH_JOY_WEAKEN off it for a while,
# and it comes back at PUSH_WEAKEN_RECOVER a second). A passing tide shoves the side it comes from with TIDE_PUSH
# (see the tide block). Force spreads along the loop (PUSH_SPREAD radians) and bows the line inward: the dent follows
# force x PUSH_DENT_PER_FORCE (at most PUSH_DENT_MAX metres), deepening at PUSH_GIVE_SPEED metres a second and springing
# back at PUSH_SPRING_SPEED when relieved. Joy at a bending member (or a burst near the spot) calms it: the force is cut
# by PUSH_CALM_CUT while the calm lasts (PUSH_CALM_SECONDS) and the spring is PUSH_CALM_SPRING times as fast. Past
# PUSH_BREAK_DEPTH the line snaps (a break, PUSH_BREAK_HALF samples either side); dimmed people then pass through.
# A break mends when no dimmed person is within PUSH_MEND_CLEAR of it and a member near it has had joy since it
# opened (PUSH_MEND_NEEDS_JOY; with it off, or after PUSH_MEND_AUTO seconds clear, it mends by itself).
const PUSH_PER_PERSON := 1.0
const PUSH_LEAN_RANGE := 1.8  # Metres outside the line a dimmed person still leans on it.
# Walls and gates: Line (0.4, #56). The push lives on gates only. Everything is kept per point of the traced line (a
# gate has a point every BorderConfig.GATE_POINT_STEP metres), so a spread is in metres and a break is in points.
const PUSH_SPREAD_METRES := 1.6  # Metres: one standard deviation of a pusher's force along a gate.
const PUSH_DENT_PER_FORCE := 0.85
const PUSH_DENT_MAX := 3.2
const PUSH_BREAK_DEPTH := 2.4  # Metres of dent at which the line snaps.
const PUSH_GIVE_SPEED := 0.55
const PUSH_SPRING_SPEED := 0.9
const PUSH_BREAK_HALF := 1  # Points either side of the deepest one that open (the break is 2 x this + 1 points wide).
const PUSH_JOY_WEAKEN := 0.4
const PUSH_WEAKEN_MIN := 0.25
const PUSH_WEAKEN_RECOVER := 0.06
const PUSH_CALM_SECONDS := 4.0
const PUSH_CALM_CUT := 0.7
const PUSH_CALM_SPRING := 2.5
const PUSH_BURST_CALM := 1.0  # A burst's calm strength (a joy hit gives PUSH_JOY_CALM).
const PUSH_JOY_CALM := 0.6
const PUSH_BURST_REACH := 8.0  # Metres: a burst relieves the line this close to it.
const PUSH_SOFT_BONUS := 0.5  # A tired member (low joy) gives this much more (times the share of joy missing).
const PUSH_MEND_CLEAR := 5.0  # Metres: no dimmed person this close to the break.
const PUSH_MEND_REACH := 6.0  # Metres: a joy hit on a member this close to the break counts as mending its ends.
const PUSH_MEND_NEEDS_JOY := true
const PUSH_MEND_AUTO := 25.0
const PUSH_BRACE_TARGET := 0.2  # A member braced this much (0 to 1) can be aimed at (joy makes them push back).
const PUSH_BRACE_LEAN := 0.5  # Radians of lean at full brace.
const PUSH_BRACE_SHAKE := 0.07  # Radians of struggle shake at full brace.
const PUSH_BRACE_WIDEN := 0.18  # How much wider the planted body is at full brace.
const PUSH_BRACE_SMOOTH := 6.0  # How fast the drawn brace follows (per second).
const PUSH_PROMPT_FRACTION := 0.4  # The line bent this share of the way to breaking: the first prompt.
const PUSH_NOTICE_TEXT := "It bends where they push: joy them"
const PUSH_BREAK_TEXT := "Broken! Joy the ends, lift who got in"
