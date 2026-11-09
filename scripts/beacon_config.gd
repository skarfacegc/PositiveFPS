class_name BeaconConfig
extends RefCounted

# The beacon, its arms, the reach guide and border posts.
# Kept as they were, untidied: pass 2 of 0.4 deletes this whole file.

const BORDER_BEACON_COLOUR := Color(1.0, 0.85, 0.45)

# A beautified building whose footprint is this close to the loop (metres) is a border post.
const BORDER_POST_REACH := 2.0 * Config.WORLD_SCALE

# A post holds this many members' worth of perimeter, so the loop needs that many fewer people.
# 1 since 0.3.3 (#54): at 3, the ~6 posts of the street town held half the
# slots, leaving most rescued people inside instead of on the line.
const BORDER_POST_WORTH := 1

# Post visuals (placeholder): a warm lantern on the block, and a golden ring around its base.
const BORDER_POST_LANTERN_COLOUR := Color(1.0, 0.8, 0.45)
const BORDER_POST_RING_COLOUR := Color(1.0, 0.82, 0.3)
const BORDER_POST_RING_INNER := 2.3
const BORDER_POST_RING_OUTER := 2.6

# A block that was a post last frame stays one out to this many times BORDER_POST_REACH (no flicker at the edge).
const BORDER_POST_HOLD := 1.5

# The border's centre stays anchored once the border forms. E places a spirit beacon at the cursor's ground point for
# BEACON_SPIRIT_COST spirit; the centre walks toward it at BEACON_PULL_SPEED (m/s, territory) and the beacon clears
# when
# the centre is within BEACON_ARRIVE_RADIUS of it. One beacon at a time; a new one replaces the old (and costs again).
const BEACON_SPIRIT_COST := 50.0  # Round 20: was 30 (spirit sat near 90 in the round 19 playtest).
const BEACON_ARRIVE_RADIUS := 0.3
const BEACON_COLOUR := Color(0.55, 0.85, 1.0)
const BEACON_NO_SPIRIT_TEXT := "Not enough spirit"
const BEACON_NO_BORDER_TEXT := "Rescue three people to form a border first"

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
const BEACON_GUIDE_TIP_COLOUR := Color(1.0, 1.0, 0.85, 0.95)

# The round 20 playtest lost its border after a stretch. Reproduced headless: the tip swept over dimmed people, which
# put them INSIDE the border (nothing holds them back there and the new ground has no paint), they drained the
# members,
# members relapsed, the head count and the reach fell, and the loop shrank. A stretch now stops short of the dimmed:
# its tip keeps BEACON_DIM_CLEARANCE metres from every dimmed person it would otherwise swallow. A stretch that could
# gain less than BEACON_MIN_GAIN past the circle's edge for that reason is refused (no spirit spent). When people are
# lost the tip walks back at BEACON_PULL_SPEED instead of jumping, and the stretch ends once it
# is back inside BEACON_MIN_GAIN of the circle. BEACON_PLAN_SECONDS is how long a plan is reused (per-frame cost).
const BEACON_DIM_CLEARANCE := 1.5 * Config.WORLD_SCALE
const BEACON_MIN_GAIN := 2.0 * Config.WORLD_SCALE
const BEACON_PLAN_SECONDS := 0.1
const BEACON_DIM_TEXT := "Dimmed people are in the way"
const BEACON_BLOCKED_TEXT := "Dimmed people block the stretch"
const BEACON_FELL_BACK_TEXT := "The stretch fell back"

# The preview of the zone the stretch will make (reach_guide.gd, placeholder look): a thin outline, a tip marker, label.
# Checkpoint 5 follow-up: no fill (the outline only); the width is thin (see the "hold E" block).
const BEACON_GUIDE_OUTLINE_WIDTH := 0.2
const BEACON_GUIDE_LABEL_COLOUR := Color(1.0, 1.0, 0.92)

# A finished stretch stays and the next grows from the shaped zone. The head count sets the loop length; the body never
# squeezes below BEACON_BODY_MIN, so a stretch is limited or refused at that length. Lose people and the arms
# retreat (round 24: one at a time, see the Round 24 block) while the loop is over by BEACON_PULL_IN_TOLERANCE.
const BEACON_PULL_IN_TOLERANCE := 0.04
const BEACON_ARM_MERGE := 0.3  # radians: a stretch this close to an arm updates it
const BEACON_MAX_ARMS := 6
const BEACON_FULL_TEXT := "The border is at its full length - rescue more people to stretch further"
const BEACON_INSIDE_TEXT := "That is inside the zone already"
const BEACON_PULLED_IN_TEXT := "People lost - the zone is pulling in"
const BEACON_PULSE_SECONDS := 1.8
const BEACON_GAIN_TEXT := "+%d sq m of ground"
const BEACON_LIMITED_OUTLINE_WIDTH := 0.26  # Checkpoint 5 follow-up: thin, a touch wider than the normal outline.
const BEACON_LIMITED_COLOUR := Color(1.0, 0.35, 0.25, 0.95)

# The Round 22 playtest found reach too short and growth too slow, and the text and growth markers large and
# distracting. Reach is about 30% further (round 22: BEACON_REACH_BASE 3.0 and BEACON_REACH_PER_PERSON 0.35, times
# WORLD_SCALE) and the beacon walks about 50% faster (round 22: 0.8 times WORLD_SCALE). A far-away aim is no longer
# refused with a "too far" notice: the zone goes as far as the people allow. The notices (font, bar height), the
# preview label and the "+N sq m of ground" growth text and its pulse are smaller and quieter than in round 22
# (28 and 56, 0.05, 0.9 and 0.95).
const BEACON_REACH_BASE := 3.9 * Config.WORLD_SCALE
const BEACON_REACH_PER_PERSON := 0.455 * Config.WORLD_SCALE
const BEACON_PULL_SPEED := 1.2 * Config.WORLD_SCALE
const BEACON_PULL_IN_SQUEEZE := 1.1
const BEACON_PULL_IN_NOTICE_GAP := 8.0  # Seconds between two "pulling in" notices.
const BEACON_GUIDE_LABEL_SIZE := 0.012
const BEACON_GAIN_LABEL_SIZE := 0.03
const BEACON_GAIN_OUTLINE_SIZE := 8
const BEACON_PULSE_COLOUR := Color(1.0, 0.95, 0.6, 0.6)
const BEACON_PULSE_WIDTH := 0.6
const BEACON_PULSE_RING_START := 1.2
const BEACON_PULSE_RING_GROW := 4.0
const BEACON_PULL_CALM_RATE := 0.7 * Config.WORLD_SCALE  # m/s one arm walks in.
const BEACON_PULL_FADE_SECONDS := 2.0
const BEACON_PULL_FADE_ALPHA := 0.2  # The retreating arm's outline alpha once faded.
const BEACON_PULL_FADE_ANGLE := 0.5  # Radians either side of the arm that fade.
const BEACON_PULL_URGENT_RATIO := 1.2  # Loop over the people's length by this factor: hurry.
const BEACON_PULL_URGENT_MULT := 4.0

# E is hold to aim, release to place: the preview shows only while E is held and right-click cancels. The HUD's spirit
# label sits above its bar so the burst line on the left never runs into it.
const AIM_CROSS_SIZE := 1.1  # Half the length of the small cross at a limited preview's tip (metres, placeholder look).
const AIM_CROSS_WIDTH := 0.22  # The cross's stroke width (metres, placeholder look).
