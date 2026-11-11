class_name DefenceConfig
extends RefCounted

# Walls and gates: Defences (#15, #16). Posts planted at gates with F, one type per landmark.

# Defences in all, and the one-per-gate rule is in Defences. A defence is staffed by one member, who leaves the line.
const DEFENCE_MAX := 4
# How near (metres) the aim must be to a gate to point at it.
const DEFENCE_PICK_RANGE := 5.0
# Where the post and its staff stand: this far inside the middle of the gate (metres).
const DEFENCE_POST_INSET := 1.4
# The staff walk to the post at this speed (metres a second).
const DEFENCE_STAFF_SPEED := 6.0

# Bandstand: the gate is stronger against pushers (the gate's strength_mult).
const DEFENCE_BANDSTAND_MULT := 1.5
# Bell tower: the bell rings (a free burst at the pressed point) when the gate is bent this share of the break depth,
# and not again for DEFENCE_BELL_COOLDOWN seconds.
const DEFENCE_BELL_PRESS_FROM := 0.5
const DEFENCE_BELL_COOLDOWN := 20.0

# Placeholder look: a post shape per type in its landmark's colour (LandmarkConfig.LANDMARK_COLOURS), and the ghost
# shown while you aim.
const DEFENCE_POST_HEIGHT := 2.4
const DEFENCE_POST_WIDTH := 0.7
const DEFENCE_GHOST_ALPHA := 0.55
const DEFENCE_LABEL_HEIGHT := 3.4

# What each type does, for the aim label and the banner. Index order matches LandmarkConfig.LANDMARK_NAMES.
const DEFENCE_TEXT: Array[String] = [
	"weakens pushers here",
	"this gate bends but cannot break",
	"rings a free burst when pressed hard",
	"the cells beside this gate cannot be lost",
]

# Walls and gates: Capture polish (#75). A paid takeable cell is an outline this thick (metres); a free one is
# filled. The label on every cell next to the zone ("Free" or the price, then the pips as "2/3") floats at this height.
const CAPTURE_OUTLINE_WIDTH := 0.7
const CAPTURE_LABEL_HEIGHT := 2.4
const CAPTURE_LABEL_PIXEL_SIZE := 0.02
const CAPTURE_LABEL_FONT_SIZE := 64
const CAPTURE_FREE_TAG := "Free"
const CAPTURE_LABEL_NONE_COLOUR := Color(0.75, 0.75, 0.78)

# The banner words for each refusal.
const REFUSE_NO_TYPE := "No defence yet: claim a landmark to unlock one."
const REFUSE_NO_GATE := "Point at a gate to defend it."
const REFUSE_DEFENDED := "That gate already has a defence."
const REFUSE_ALL_USED := "All %d defences are in place."
const REFUSE_NO_MEMBER := "No free member to staff a defence."
