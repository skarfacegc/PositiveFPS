class_name LandmarkConfig
extends RefCounted

# Landmarks, their boosts and the dawn rating.

# The landmarks (round 19: three, see "Round 19: landmarks"). BORDER_LANDMARK_SIZE is the reference size the looks use
# for label heights; BORDER_LANDMARK_HOLD is the claim hold: seconds a landmark must stay beautified to be held.
const BORDER_LANDMARK_SIZE := Vector3(4, 3.5, 4)
const BORDER_LANDMARK_HOLD := 3.0
const BORDER_LANDMARK_COLOUR := Color(0.78, 0.66, 0.6)

# Landmarks (three in round 19, four since 0.3.3). Each is held while beautified inside the border for
# BORDER_LANDMARK_HOLD seconds, and loses its boost the moment the border drops it. Index order: bandstand, garden,
# bell tower, gallery. (The gallery has no boost yet.)
const LANDMARK_NAMES: Array[String] = ["Bandstand", "Garden", "Bell tower", "Gallery"]

# Walls and gates: Grid (0.4, #55): four landmarks, each standing in the middle of its own square, the four diagonal
# cells next to the start square (about 38 m from the start since Grid fixes; see TownConfig.TOWN_LANDMARK_CELLS and
# TownGrid).
const LANDMARK_POSITIONS: Array[Vector3] = [
	Vector3(27, 0, -27), Vector3(-27, 0, -27), Vector3(27, 0, 27), Vector3(-27, 0, 27)
]
# The colour of a held landmark's pillar and disc in the placeholder look.
const LANDMARK_LIT_COLOUR := Color(1.0, 0.85, 0.45)

# Collision size (footprint 4 x 4 like the other blocks) and plain colour of each landmark's block.
const LANDMARK_SIZES: Array[Vector3] = [Vector3(4, 2.6, 4), Vector3(4, 1.0, 4), Vector3(4, 7.0, 4), Vector3(4, 3.2, 4)]
const LANDMARK_COLOURS: Array[Color] = [
	Color(0.55, 0.62, 0.85), Color(0.55, 0.8, 0.5), Color(0.85, 0.72, 0.4), Color(0.8, 0.58, 0.78)
]

# Boosts while held: music joy x2 (bandstand), nature joy x2 (garden), and border members within
# LANDMARK_BELL_RADIUS of the bell tower take x0.4 of the gloom's drain (bell tower).
const LANDMARK_MUSIC_MULT := 2.0
const LANDMARK_NATURE_MULT := 2.0
const LANDMARK_BELL_LOSS_MULT := 0.4
const LANDMARK_BELL_RADIUS := 12.0 * Config.WORLD_SCALE

# Short boost text per landmark, for the HUD panel and the placeholder labels.
const LANDMARK_BOOST_TEXT: Array[String] = ["music x2", "nature x2", "gloom slowed x0.4 nearby", "art (no boost yet)"]

# The level is won by reaching dawn. 1 light for that; 2 lights when at least two of the three lower goals are met
# (share of people rescued, share of the plaza held, landmarks held); 3 lights when DAWN_PEOPLE_HIGH of the people are
# rescued AND DAWN_LANDMARKS_HIGH landmarks are held at dawn. (Round 18's quick push: 52% rescued and one landmark =
# 2.)
const DAWN_PEOPLE_LOW := 0.4
const DAWN_GROUND_LOW := 0.2
const DAWN_LANDMARKS_LOW := 1
const DAWN_PEOPLE_HIGH := 0.75  # Checkpoint 5: was 0.6 (the Garden alone made 3 lights too easy).
const DAWN_LANDMARKS_HIGH := 2  # Checkpoint 5: was 1.

# A claim or a loss shows a notice across the top (HUD alert). A loss is held longer and coloured as a break.
const LANDMARK_CLAIM_COLOUR := Color(1.0, 0.88, 0.5)
const LANDMARK_LOSS_COLOUR := Color(0.95, 0.42, 0.36)
const LANDMARK_LOSS_SECONDS := 2.5
