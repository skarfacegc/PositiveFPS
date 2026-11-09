class_name EmbraceConfig
extends RefCounted

# Embrace: the border lifting unrescued people inside it.

# An unrescued person inside the border loop is lifted a stage every EMBRACE_STEP_SECONDS (dimmed 24 s, gloomy 16 s,
# wistful 8 s to a rescue). Outside, the seconds gathered toward the step fade at EMBRACE_DECAY_RATE a second.
# While anyone is embraced, the EMBRACE_STRAIN_COUNT members nearest each embraced person lose EMBRACE_STRAIN_RATE joy a
# second (a dimmed person drains 60 x TD_DRAIN_MULTIPLIER = 24, so this is about a third of that).
const EMBRACE_STEP_SECONDS := 8.0
const EMBRACE_DECAY_RATE := 0.25
const EMBRACE_STRAIN_COUNT := 3
const EMBRACE_STRAIN_RATE := 8.0
const EMBRACE_RELAPSE_PAUSE := 20.0  # A person who relapsed is not embraced for this long.
const EMBRACE_CALM := 0.5  # Person.calm_left kept up while embraced: no gloom grows on them.
const EMBRACE_JOY_CAP := 0.9  # A lift leaves joy at no more than this share of what the new stage needs.
const EMBRACE_GLOW_COLOUR := Color(1.0, 0.8, 0.45)
const EMBRACE_GLOW_ALPHA := 0.5
const EMBRACE_GLOW_RADIUS := 1.5
const EMBRACE_GLOW_Y := 0.07
const EMBRACE_PULSE_HZ := 0.6
const EMBRACE_OUTSIDE_FADE := 0.4  # The glow's strength share while they are outside the loop (progress fading).
const EMBRACE_RING_COLOUR := Color(1.0, 0.93, 0.62, 0.9)
const EMBRACE_RING_INNER := 1.05
const EMBRACE_RING_OUTER := 1.25
const EMBRACE_RING_Y := 0.1
const EMBRACE_RING_SEGMENTS := 48
