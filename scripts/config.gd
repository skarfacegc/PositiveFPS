class_name Config
extends ConfigBase

# Round 19 onward: tuning values and the tiny pure helpers. Older constants live in config_base.gd (ConfigBase) and are
# reached as Config.X all the same. NEW CONSTANTS GO AT THE END OF THE CONSTANTS, just above the helper functions.

# ---- Round 19: beacon (scripts/border_centre.gd, topdown_main.gd). ----
# The border's centre stays anchored once the border forms. E places a spirit beacon at the cursor's ground point for
# BEACON_SPIRIT_COST spirit; the centre walks toward it at BEACON_PULL_SPEED (m/s, territory) and the beacon clears
# when
# the centre is within BEACON_ARRIVE_RADIUS of it. One beacon at a time; a new one replaces the old (and costs again).
const BEACON_SPIRIT_COST := 50.0  # Round 20: was 30 (spirit sat near 90 in the round 19 playtest).
const BEACON_ARRIVE_RADIUS := 0.3
const BEACON_COLOUR := Color(0.55, 0.85, 1.0)
const BEACON_NO_SPIRIT_TEXT := "Not enough spirit"
const BEACON_NO_BORDER_TEXT := "Rescue three people to form a border first"

# ---- Round 20: stretching zone (scripts/border_centre.gd, reach_guide.gd). ----
# A beacon no longer walks the centre. The zone stretches: the body stays round the old centre and a tip reaches
# toward
# the beacon at BEACON_PULL_SPEED. The tip can go BEACON_REACH_BASE + BEACON_REACH_PER_PERSON x (people rescued)
# metres
# past the plain circle's edge. When it stops (at the beacon or at the maximum reach) the arm stays part of the zone
# (round 22: no hold, no snap) and the beacon clears. BEACON_TIP_WIDTH is the tip
# circle's radius as a share of the body radius. The loop's length is fixed by the people, so a longer tip squeezes
# the
# body: BEACON_BODY_MIN is how small the body may get (a share of the plain radius), which caps the reach. The rest is
# the placeholder look's reach guide.
const BEACON_TIP_WIDTH := 0.4
const BEACON_BODY_MIN := 0.4  # Round 23 (was 0.6): the arm may take more of the loop; see the Round 23 follow-up block.
const BEACON_GUIDE_Y := 0.18
const BEACON_GUIDE_RING_COLOUR := Color(0.55, 0.85, 1.0, 0.35)
const BEACON_GUIDE_PREVIEW_COLOUR := Color(0.55, 0.85, 1.0, 0.45)
const BEACON_GUIDE_CAPPED_COLOUR := Color(1.0, 0.6, 0.45, 0.8)
const BEACON_GUIDE_PATH_COLOUR := Color(0.75, 0.95, 1.0, 0.9)
const BEACON_GUIDE_TIP_COLOUR := Color(1.0, 1.0, 0.85, 0.95)

# ---- Round 21: stretch safety (scripts/border_centre.gd, reach_guide.gd). ----
# The round 20 playtest lost its border after a stretch. Reproduced headless: the tip swept over dimmed people, which
# put them INSIDE the border (nothing holds them back there and the new ground has no paint), they drained the
# members,
# members relapsed, the head count and the reach fell, and the loop shrank. A stretch now stops short of the dimmed:
# its tip keeps BEACON_DIM_CLEARANCE metres from every dimmed person it would otherwise swallow. A stretch that could
# gain less than BEACON_MIN_GAIN past the circle's edge for that reason is refused (no spirit spent). When people are
# lost the tip walks back at BEACON_PULL_SPEED instead of jumping, and the stretch ends once it
# is back inside BEACON_MIN_GAIN of the circle. BEACON_PLAN_SECONDS is how long a plan is reused (per-frame cost).
const BEACON_DIM_CLEARANCE := 1.5 * WORLD_SCALE
const BEACON_MIN_GAIN := 2.0 * WORLD_SCALE
const BEACON_PLAN_SECONDS := 0.1
const BEACON_DIM_TEXT := "Dimmed people are in the way"
const BEACON_BLOCKED_TEXT := "Dimmed people block the stretch"
const BEACON_FELL_BACK_TEXT := "The stretch fell back"
# The preview of the zone the stretch will make (reach_guide.gd, placeholder look): outline, fill, tip marker, label.
const BEACON_GUIDE_OUTLINE_WIDTH := 0.4
const BEACON_GUIDE_FILL_COLOUR := Color(0.55, 0.85, 1.0, 0.14)
const BEACON_GUIDE_LIMITED_FILL_COLOUR := Color(1.0, 0.3, 0.2, 0.12)
const BEACON_GUIDE_LABEL_COLOUR := Color(1.0, 1.0, 0.92)

# ---- Round 22: shaped zone (scripts/border_centre.gd, reach_guide.gd, intro.gd, prompt_bar.gd). ----
# A finished stretch stays and the next grows from the shaped zone. The head count sets the loop length; the body never
# squeezes below BEACON_BODY_MIN, so a stretch is limited or refused at that length. Lose people and the arms
# retreat (round 24: one at a time, see the Round 24 block) while the loop is over by BEACON_PULL_IN_TOLERANCE.
const BEACON_PULL_IN_TOLERANCE := 0.04
const BEACON_ARM_MERGE := 0.3  # radians: a stretch this close to an arm updates it
const BEACON_MAX_ARMS := 6
const BEACON_FULL_TEXT := "The border is at its full length - rescue more people to stretch further"
const BEACON_INSIDE_TEXT := "That is inside the zone already"
const BEACON_PULLED_IN_TEXT := "People lost - the zone is pulling in"
# Refusals stay this long (seconds) in a larger bar; ordinary prompts keep PROMPT_SECONDS.
const NOTICE_SECONDS := 4.0
const NOTICE_COLOUR := Color(1.0, 0.62, 0.45)
const BEACON_PULSE_SECONDS := 1.8
const BEACON_GAIN_TEXT := "+%d sq m of ground"
const BEACON_LIMITED_OUTLINE_WIDTH := 0.6
const BEACON_LIMITED_COLOUR := Color(1.0, 0.35, 0.25, 0.95)

# ---- Round 22: gap patch (scripts/gap_patch.gd). ----
# F spends PATCH_SPIRIT_COST spirit to seal the gap (or the strained spot) nearest the cursor for PATCH_SECONDS. While
# patched, gloom does not pass the gap (it counts as intact: dimmed people are pushed back) and border members within
# PATCH_RADIUS of it lose joy at only PATCH_DRAIN_MULT of the usual rate. It buys time; it does not heal anyone.
const PATCH_SPIRIT_COST := 25.0
const PATCH_SECONDS := 12.0
const PATCH_RADIUS := 4.0 * WORLD_SCALE
const PATCH_REACH := 9.0 * WORLD_SCALE  # How far from the cursor the gap or strained spot may be.
const PATCH_DRAIN_MULT := 0.15
const PATCH_MAX := 4
const PATCH_COLOUR := Color(0.35, 0.95, 0.85)
const PATCH_SPIRIT_TEXT := "Patching a gap needs 25 spirit"
const PATCH_NONE_TEXT := "No gap or strained spot near the cursor"
const PATCH_ALREADY_TEXT := "That spot is already patched"
const PATCH_MAX_TEXT := "Too many patches at once"

# ---- Round 22: burst (scripts/burst_clear.gd, topdown_player.gd). ----
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
const BURST_CALM_SECONDS := 10.0
const BURST_FX_SECONDS := 0.9
const BURST_FX_COLOUR := Color(1.0, 0.9, 0.5)

# ---- Round 22: border warning (scripts/border_warning.gd, gap_patch.gd, minimap.gd). ----
# A border member whose joy has fallen below BORDER_WARN_START of the joy needed is under strain; the warning grows from
# 0 there to 1 at MEMBER_FALTER_FRACTION, where the gap opens. A dimmed person outside within BORDER_WARN_PRESS_RANGE of
# a member gives that member at least BORDER_WARN_PRESS_URGENCY. Worked out every BORDER_WARN_INTERVAL seconds.
const BORDER_WARN_START := 0.97
const BORDER_WARN_PRESS_RANGE := 4.0
const BORDER_WARN_PRESS_URGENCY := 0.3
const BORDER_WARN_INTERVAL := 0.1
const BORDER_WARN_COLOUR_LOW := Color(1.0, 0.85, 0.3)
const BORDER_WARN_COLOUR_HIGH := Color(1.0, 0.25, 0.2)

# ---- Round 19: landmarks (scripts/landmark.gd, landmarks.gd, topdown_main.gd). ----
# Three landmarks, far enough from the start that the natural ring (LANDMARK_START_REACH from the middle) cannot reach
# them: the player needs beacons. Each is held while beautified inside the border for BORDER_LANDMARK_HOLD seconds,
# and
# loses its boost the moment the border drops it. Index order: bandstand, garden, bell tower.
const LANDMARK_NAMES: Array[String] = ["Bandstand", "Garden", "Bell tower"]
# Round 24: the Garden (index 1) stands about 14 m from the start, within the first arm's reach (was (-29, 0, 17)).
const LANDMARK_POSITIONS: Array[Vector3] = [
	Vector3(27, 0, -21) * WORLD_SCALE, Vector3(-9, 0, 4) * WORLD_SCALE, Vector3(6, 0, 31) * WORLD_SCALE
]
# Collision size (footprint 4 x 4 like the other blocks) and plain colour of each landmark's block.
const LANDMARK_SIZES: Array[Vector3] = [Vector3(4, 2.6, 4), Vector3(4, 1.0, 4), Vector3(4, 7.0, 4)]
const LANDMARK_COLOURS: Array[Color] = [Color(0.55, 0.62, 0.85), Color(0.55, 0.8, 0.5), Color(0.85, 0.72, 0.4)]
const LANDMARK_START_REACH := 28.0 * WORLD_SCALE
# Boosts while held: music joy x2 (bandstand), nature joy x2 (garden), and border members within
# LANDMARK_BELL_RADIUS of the bell tower take x0.4 of the gloom's drain (bell tower).
const LANDMARK_MUSIC_MULT := 2.0
const LANDMARK_NATURE_MULT := 2.0
const LANDMARK_BELL_LOSS_MULT := 0.4
const LANDMARK_BELL_RADIUS := 12.0 * WORLD_SCALE
# Short boost text per landmark, for the HUD panel and the placeholder labels.
const LANDMARK_BOOST_TEXT: Array[String] = ["music x2", "nature x2", "gloom slowed x0.4 nearby"]

# ---- Round 19: dawn rating (scripts/dawn_rating.gd). ----
# The level is won by reaching dawn. 1 light for that; 2 lights when at least two of the three lower goals are met
# (share of people rescued, share of the plaza held, landmarks held); 3 lights when DAWN_PEOPLE_HIGH of the people are
# rescued AND DAWN_LANDMARKS_HIGH landmarks are held at dawn. (Round 18's quick push: 52% rescued and one landmark =
# 2.)
const DAWN_PEOPLE_LOW := 0.4
const DAWN_GROUND_LOW := 0.2
const DAWN_LANDMARKS_LOW := 1
const DAWN_PEOPLE_HIGH := 0.6
const DAWN_LANDMARKS_HIGH := 1

# ---- Round 20: landmark clarity (scripts/landmark.gd, landmarks.gd, looks/landmark_look_placeholder.gd, hud.gd,
# looks/minimap_look_placeholder.gd, topdown_main.gd). ----
# A claim or a loss shows a notice across the top (HUD alert). A loss is held longer and coloured as a break.
const LANDMARK_CLAIM_COLOUR := Color(1.0, 0.88, 0.5)
const LANDMARK_LOSS_COLOUR := Color(0.95, 0.42, 0.36)
const LANDMARK_LOSS_SECONDS := 2.5
# The minimap star of a landmark that is not held (a held one is gold with its ring), placeholder look.
const TD_MINIMAP_LANDMARK_UNHELD_COLOUR := Color(0.34, 0.32, 0.31)

# ---- Round 22: minimap clouds (scripts/minimap.gd, looks/minimap_look_placeholder.gd). ----
# Unrescued people are binned into a grid of the plaza; a cell with at least MINIMAP_CLOUD_MIN_COUNT people gets a small
# soft blob at their mean, kept inside the map at MINIMAP_CLOUD_RIM. 15 cells because the timing test's crowds must not
# straddle a cell edge. Radius = base + per-person x sqrt(count), capped; peak alpha = max x count / full, capped.
const MINIMAP_CLOUD_SECONDS := 0.5
const MINIMAP_CLOUD_CELLS := 15
const MINIMAP_CLOUD_MIN_COUNT := 2
const MINIMAP_CLOUD_FULL_COUNT := 4
const MINIMAP_CLOUD_BASE_RADIUS_PX := 6.0
const MINIMAP_CLOUD_RADIUS_PER_PERSON_PX := 1.5
const MINIMAP_CLOUD_MAX_RADIUS_PX := 12.0
const MINIMAP_CLOUD_MAX_ALPHA := 0.9
const MINIMAP_CLOUD_CORE := 0.55
const MINIMAP_CLOUD_EASE_SECONDS := 0.4
const MINIMAP_CLOUD_PAINT_SECONDS := 0.2
const MINIMAP_CLOUD_RIM := 0.9
const MINIMAP_CLOUD_COLOUR := Color(0.06, 0.1, 0.34)

# ---- Round 22: landmark pointers (scripts/landmark_pointers.gd, looks/minimap_look_placeholder.gd). ----
# The landmarks were forgotten in round 21. Each landmark that is neither held nor on screen gets an edge pointer: a
# small
# arrow and "Name: boost" (a few words). The pointer sits on the screen edge inset by LANDMARK_POINTER_INSET and slides
# along that inset rectangle to keep clear of the HUD panels. On the minimap an unheld landmark is a larger star with a
# pale ring (placeholder look only; the styled look keeps its own).
const LANDMARK_POINTER_INSET := 44.0
const LANDMARK_POINTER_FONT_SIZE := 16
const LANDMARK_POINTER_ARROW := 8.0
const LANDMARK_POINTER_SLIDE_STEP := 10.0
const LANDMARK_POINTER_CLEAR_MARGIN := 4.0
const LANDMARK_POINTER_COLOUR := Color(1.0, 0.92, 0.7)
const LANDMARK_POINTER_BG_COLOUR := Color(0.0, 0.0, 0.0, 0.5)
const TD_MINIMAP_LANDMARK_UNHELD_GROW := 1.5
const TD_MINIMAP_LANDMARK_UNHELD_RING_COLOUR := Color(1.0, 0.95, 0.8)
const TD_MINIMAP_LANDMARK_UNHELD_RING_RADIUS := 6.4

# ---- Round 23: pressure curve (scripts/night_cycle.gd, topdown_main.gd). ----
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

# ---- Round 23: shaping tuning and quieter feedback (scripts/border_centre.gd, reach_guide.gd, prompt_bar.gd). ----
# The Round 22 playtest found reach too short and growth too slow, and the text and growth markers large and
# distracting. Reach is about 30% further (round 22: BEACON_REACH_BASE 3.0 and BEACON_REACH_PER_PERSON 0.35, times
# WORLD_SCALE) and the beacon walks about 50% faster (round 22: 0.8 times WORLD_SCALE). A far-away aim is no longer
# refused with a "too far" notice: the zone goes as far as the people allow. The notices (font, bar height), the
# preview label and the "+N sq m of ground" growth text and its pulse are smaller and quieter than in round 22
# (28 and 56, 0.05, 0.9 and 0.95).
const BEACON_REACH_BASE := 3.9 * WORLD_SCALE
const BEACON_REACH_PER_PERSON := 0.455 * WORLD_SCALE
const BEACON_PULL_SPEED := 1.2 * WORLD_SCALE
# Pull-in: arms retreat once the body scale is within this factor of the smallest it can reach (it lags the ease).
const LANDMARK_POINTER_REFRESH := 0.2  # Seconds between two works-out of the landmark pointers (5 a second).
const BEACON_PULL_IN_SQUEEZE := 1.1
const BEACON_PULL_IN_NOTICE_GAP := 8.0  # Seconds between two "pulling in" notices.
const NOTICE_FONT_SIZE := 16
const NOTICE_HEIGHT := 34.0
const BEACON_GUIDE_LABEL_SIZE := 0.012
const BEACON_GAIN_LABEL_SIZE := 0.03
const BEACON_GAIN_OUTLINE_SIZE := 8
const BEACON_PULSE_COLOUR := Color(1.0, 0.95, 0.6, 0.6)
const BEACON_PULSE_WIDTH := 0.6
const BEACON_PULSE_RING_START := 1.2
const BEACON_PULSE_RING_GROW := 4.0

# ---- Round 23: defences and landmarks (scripts/gap_patch.gd, patch_fx.gd, landmarks.gd, dawn_rating.gd). ----
# Cue: a small line near the player, shown only when F (patch) or G/Q (burst) can be acted on right now.
# Result: a short rising count at the patched spot and at each person the burst lifted, with a halo on them.
# Landmarks: boosts doubled (LANDMARK_*_MULT, Round 19 block); one landmark at dawn is enough for the third light.
const CUE_FONT_SIZE := 18
const CUE_PLAYER_RANGE := 14.0 * WORLD_SCALE  # A gap or strain this close to the player counts as "near".
const CUE_ALPHA := 0.8
const CUE_PATCH_TEXT := "F: patch"
const CUE_PATCH_AIM_TEXT := "gap near: aim at it, F"
const CUE_BURST_TEXT := "G: lift %d"
const FX_TEXT_SECONDS := 1.6
const FX_TEXT_RISE := 1.8
const FX_TEXT_SIZE := 0.012  # Label3D pixel_size; small.
const FX_HALO_SECONDS := 1.5
const FX_PATCH_PULSE_SECONDS := 0.8
const FX_PATCH_TEXT := "Held: %d"
const FX_LIFT_TEXT := "lifted %d"

# ---- Round 24: reactions (person.gd, person_look*.gd, gap_patch.gd, reach_guide.gd, border_centre.gd). ----
# Things react: a patch makes the border people at that spot hop, turn toward it and glow; a burst makes each lifted
# person hop and glow warm. The cues for F and G sit on the HUD beside the spirit meter and glow when ready. The reach
# preview has no hover words (a refusal shows only when E is pressed). A pull-in retreats one arm at a time: its outline
# fades for BEACON_PULL_FADE_SECONDS, then it walks in at BEACON_PULL_CALM_RATE; past BEACON_PULL_URGENT_RATIO of the
# length the people can hold it speeds up (and skips the fade) so the spacing stays under BORDER_MAX_GAP.
const REACT_PATCH_SECONDS := 1.2
const REACT_PATCH_HOPS := 2.0
const REACT_PATCH_HOP_HEIGHT := 0.55
const REACT_PATCH_MAX := 10  # Most border people that react to one patch.
const REACT_PATCH_REACH := PATCH_RADIUS * 1.3
const REACT_PATCH_STAGGER := 0.35  # Seconds of delay across the patch radius (nearest first).
const REACT_LIFT_SECONDS := 1.0
const REACT_LIFT_HOP_HEIGHT := 0.85
const REACT_GLOW_ENERGY := 1.8
const CUE_HUD_GAP := 18.0  # Pixels between the spirit meter's right end and the cue.
const CUE_HUD_Y := -112.0  # Offset from the bottom of the screen (the meter's own top).
const CUE_READY_COLOUR := Color(1.0, 0.92, 0.5)
const CUE_PULSE_HZ := 1.6
const BEACON_PULL_CALM_RATE := 0.7 * WORLD_SCALE  # m/s one arm walks in.
const BEACON_PULL_FADE_SECONDS := 2.0
const BEACON_PULL_FADE_ALPHA := 0.2  # The retreating arm's outline alpha once faded.
const BEACON_PULL_FADE_ANGLE := 0.5  # Radians either side of the arm that fade.
const BEACON_PULL_URGENT_RATIO := 1.2  # Loop over the people's length by this factor: hurry.
const BEACON_PULL_URGENT_MULT := 4.0
const LANDMARK_NEAR_INDEX := 1  # The Garden: within the first arm's reach of the start (the other two stay far).

static var intro_override: int = -1

# The matchups form a soft cycle:
#   Music is strong against Art, Art is strong against Nature, Nature is strong against Music.
# Matching the affinity gives MATCH_MULT. The element that loses to the affinity gives WEAK_MULT.


# True when the layered introduction (round 13b) is on: always in the game, never under automated tests, unless a test
# sets `intro_override` to 1 (on) or 0 (off). -1 means no override.
static func intro_on() -> bool:
	if intro_override >= 0:
		return intro_override == 1
	return not is_automated_test()


# Returns how much a hit with `element` is multiplied when the person has `affinity`.
static func multiplier(element: int, affinity: int) -> float:
	if element == affinity:
		return MATCH_MULT
	if affinity == (element + 1) % 3:
		return STRONG_MULT
	return WEAK_MULT


# Returns the strength of a hit at `distance` metres: 1.0 up close, falling to FALLOFF_MIN far away.
static func falloff(distance: float) -> float:
	if distance <= FALLOFF_NEAR:
		return 1.0
	if distance >= FALLOFF_FAR:
		return FALLOFF_MIN
	var t := (distance - FALLOFF_NEAR) / (FALLOFF_FAR - FALLOFF_NEAR)
	return lerpf(1.0, FALLOFF_MIN, t)


# Returns the visible grey level (0 light, 1 grey, 2 dimmed) for a hidden gloom value.
static func gloom_level(g: float) -> int:
	if g < GLOOM_LEVEL_STEPS[0]:
		return 0
	if g < GLOOM_LEVEL_STEPS[1]:
		return 1
	return 2


# True when the game is running under the automated tests (tools/run_tests.py): the POSITIVEFPS_TEST=1 environment
# variable, a "--automated-test" user argument, or a headless display. In that mode the game never captures the real
# OS mouse, so a test run can never grab a player's mouse.
static func is_automated_test() -> bool:
	return (
		OS.get_environment("POSITIVEFPS_TEST") == "1"
		or "--automated-test" in OS.get_cmdline_user_args()
		or DisplayServer.get_name() == "headless"
	)
