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
# The preview of the zone the stretch will make (reach_guide.gd, placeholder look): a thin outline, a tip marker, label.
# Checkpoint 5 follow-up: no fill (the outline only); the width is thin (see the "hold E" block).
const BEACON_GUIDE_OUTLINE_WIDTH := 0.2
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
const BEACON_LIMITED_OUTLINE_WIDTH := 0.26  # Checkpoint 5 follow-up: thin, a touch wider than the normal outline.
const BEACON_LIMITED_COLOUR := Color(1.0, 0.35, 0.25, 0.95)

# The teal glow of Person.React.PATCH (a reaction the looks still draw; the F patch itself is gone in round 26).
const PATCH_COLOUR := Color(0.35, 0.95, 0.85)

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
const BURST_CALM_SECONDS := 16.0  # Round 24: was 10.0.
const BURST_FX_SECONDS := 0.6  # Round 25: was 0.9 (short effects).
const BURST_FX_COLOUR := Color(1.0, 0.9, 0.5)

# Round 26: the burst cue works out its count (and fades the people outside) every BORDER_WARN_INTERVAL seconds.
const BORDER_WARN_INTERVAL := 0.1

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
const DAWN_PEOPLE_HIGH := 0.75  # Checkpoint 5: was 0.6 (the Garden alone made 3 lights too easy).
const DAWN_LANDMARKS_HIGH := 2  # Checkpoint 5: was 1.

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
const NOTICE_FONT_SIZE := 15  # Checkpoint 6: a slim banner (was 16 and 34).
const NOTICE_HEIGHT := 32.0
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
# Landmarks: boosts doubled (LANDMARK_*_MULT, Round 19 block). The third light needs 75% rescued and 2 landmarks
# (checkpoint 5).
const CUE_FONT_SIZE := 18
const CUE_PLAYER_RANGE := 14.0 * WORLD_SCALE  # A gap or strain this close to the player counts as "near".
const CUE_ALPHA := 0.8
const CUE_BURST_TEXT := "G: lift %d"
const FX_TEXT_SECONDS := 1.1  # Round 25: was 1.6.
const FX_TEXT_RISE := 1.8
const FX_TEXT_SIZE := 0.012  # Label3D pixel_size; small.
const FX_HALO_SECONDS := 0.9  # Round 25: was 1.5.
const FX_LIFT_TEXT := "lifted %d"

# ---- Round 24: dimmed and waves (scripts/burst_clear.gd, person.gd, relapse_wave.gd, person_look*.gd). ----
# The round 23 playtests left the dimmed stock at about 6 from midnight on (7 bursts lifted 3 dimmed people in a game),
# and one dimmed person's drain tipped a whole group over the relapse line on the same frame.
# Beatable dimmed: a burst lifts every dimmed person within BURST_LIFT_RADIUS of the player (round 22: only those within
# BURST_BORDER_BAND of the line, inside BURST_CLEAR_RADIUS, 8 m). Those near the line are still pushed back. A lifted
# person stays calm BURST_CALM_SECONDS (16 s, was 10 s). Joy lands DIMMED_JOY_MULT times as hard on a dimmed person (so
# about 5 matching shots rescue them, was about 9) and fades DIMMED_FADE_MULT times as fast, so progress holds.
const BURST_LIFT_RADIUS := 14.0
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

# ---- Round 24: first light (scripts/first_light.gd, night_cycle.gd, person.gd, minimap.gd). ----
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
const REACT_PATCH_REACH := 4.0 * WORLD_SCALE * 1.3
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

# ---- Checkpoint 5: wobble alert (scripts/wobble_alert.gd, minimap.gd, looks/minimap_look*.gd). ----
# A wobble (a drained rescued person, about WOBBLE_SECONDS before a relapse) used to start off screen and go unseen. Now
# a pulsing pointer sits on the screen edge toward each cluster of off-screen wobblers (most urgent first, at most
# WOBBLE_ALERT_MAX). It pulses faster as the wobble runs out, and it is smaller than the gap arrows' urgency pulse but
# warmer than the landmark pointers. On the minimap each wobbler is a pulsing blip.
const WOBBLE_ALERT_REFRESH := 0.2  # Seconds between two works-out of the pointers (the pulse is redrawn every frame).
# Off-screen wobblers this close (on the ground) share a pointer.
const WOBBLE_ALERT_CLUSTER_RADIUS := 12.0 * WORLD_SCALE
const WOBBLE_ALERT_MAX := 3  # Most pointers on screen at once.
const WOBBLE_ALERT_BADGE := 20.0  # The size (pixels) of the count badge that the pointer's placement keeps clear.
const WOBBLE_ALERT_RING := 9.0  # The pointer's ring radius (pixels) before it pulses.
const WOBBLE_ALERT_ARROW := 8.0  # The arrow's length (pixels), between the ring and the screen edge.
const WOBBLE_ALERT_PULSE_GROW := 0.35  # The ring swells by this fraction at the top of each pulse.
const WOBBLE_ALERT_PULSE_HZ_CALM := 1.2  # Pulses a second for a wobble that has just begun.
const WOBBLE_ALERT_PULSE_HZ_URGENT := 3.4  # Pulses a second for a wobble about to relapse.
const WOBBLE_ALERT_COLOUR := Color(1.0, 0.74, 0.42)  # A gentle warm amber (not the coral of the gaps).
const WOBBLE_ALERT_FONT_SIZE := 12
const WOBBLE_BLIP_RADIUS := 2.6  # Minimap: the core radius (picture pixels) of a wobbling person's blip.
const WOBBLE_BLIP_PULSE_GROW := 2.0  # The blip's ring grows by this many pixels at the top of its pulse.
const WOBBLE_BLIP_COLOUR := Color(1.0, 0.74, 0.42)  # The placeholder minimap blip (the styled look has its own).

# ---- Checkpoint 5: rules (border_shape.gd, spirit_warmth.gd, dawn_rating.gd). ----
# End flicker: the loop is eased to exactly n x BORDER_TARGET_SPACING, which is where the slot count steps from n to
# n + 1, so noise in the length flipped the member count every frame or two. The count now holds until the length is
# BORDER_SLOT_COUNT_HOLD of a slot past the step (either way).
const BORDER_SLOT_COUNT_HOLD := 0.35
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

# ---- Checkpoint 5: styled catch-up (scripts/looks/style_fight.gd, style_first_light.gd, style_reach.gd). ----
# Visual numbers shared by the styled look's new pieces (the rules never read them).
# The placeholder look ignores all of them.
# Round 25: the strain rings and pings, the coral gap column, the patch posts, the lift column and the wobble's
# closing ring were removed (EdgeRibbon and EdgeMarkerFx replace them).
const CP5_WARM_TINT := 0.75  # How far a dimmed body's coat takes the affinity colour at full joy (styled look).
const CP5_FIRST_LIGHT_SKY := Color("#f2b886")  # The sky the styled view warms toward as first light moves in.
const CP5_FIRST_LIGHT_SKY_MIX := 0.5  # How much of it at dawn.

# ---- Snag round: shader instances (project.godot, tests/shader_instances_test.gd). ----
# The renderer reserves this many vec4 of rendering/limits/global_shader_variables/buffer_size for every mesh whose
# material declares an `instance uniform` (a fixed engine cost, hidden meshes included).
const SNAG_INSTANCE_VEC4S := 16

# ---- Checkpoint 5 follow-up: hold E (scripts/beacon_placement.gd, reach_guide.gd, controls.gd, hud.gd). ----
# E is hold to aim, release to place: the preview shows only while E is held and right-click cancels. The HUD's spirit
# label sits above its bar so the burst line on the left never runs into it.
const AIM_CROSS_SIZE := 1.1  # Half the length of the small cross at a limited preview's tip (metres, placeholder look).
const AIM_CROSS_WIDTH := 0.22  # The cross's stroke width (metres, placeholder look).
const SPIRIT_LABEL_TOP := -146.0  # The spirit label's top, in pixels above the bottom of the screen (above the bar).
const SPIRIT_LABEL_HEIGHT := 28.0

# ---- Snag round: HUD snags (scripts/wobble_alert.gd, topdown_main.gd, first_light.gd). ----
# The wobble pointers keep clear of the HUD: each tip sits in the safe rectangle (the screen less the shown HUD panels,
# WobbleAlert.safe_rect), and the whole pointer (ring, arrow and count) stays WOBBLE_ALERT_REACH inside it.
const WOBBLE_ALERT_SAFE_INSET := 8.0  # Pixels between the safe rectangle and the screen edge.
const WOBBLE_ALERT_PANEL_GAP := 6.0  # Pixels a pointer keeps from a HUD panel.
const WOBBLE_ALERT_REACH := 34.0  # Pixels from a tip to the furthest part of its pointer (ring, arrow and count).

# ---- Checkpoint 6: first light ring (scripts/first_light.gd, looks/style_first_light.gd, minimap.gd). ----
# The dawn front is a circle closing on the plaza centre. It starts at the radius of the plaza's corners (so it covers
# the whole play area) and reaches 0 at dawn; a person is passed once the front's radius is at or inside their distance.
const FIRST_LIGHT_START_RADIUS := 71.0  # Metres: just over half the plaza's diagonal (50 x 1.414 = 70.7).
const FIRST_LIGHT_RING_SEGMENTS := 72  # Straight pieces in the placeholder ring and in the minimap outline.

# ---- Checkpoint 6: styled HUD (hud_safe_area.gd, gap_arrows.gd, prompt_bar.gd, hud.gd, looks/style_hud_text.gd). ----
# The edge pointers (gap arrows, landmark pointers, wobble pointers) keep inside HudSafeArea's rectangle. Notices (the
# prompt bar's refusals and fall-backs, and the HUD alert such as "Someone lost their joy!") are slim banners under the
# Dusk to Dawn bar instead of big panels over the play area. The styled look draws the HUD text lines (rescued, target,
# burst, targeting and the key line) as small parchment panels.
const CP6_GAP_ARROW_REACH := 30.0  # Pixels from a gap arrow's centre to the furthest part of it (with its ink edge).
const CP6_BANNER_TOP := 62.0  # Top of a notice banner: just under the night bar (which ends at 56).
const CP6_BANNER_HEIGHT := 32.0
const CP6_BANNER_GAP := 4.0  # Between two banners shown at once (the alert takes the top slot, the notice moves down).
const CP6_BANNER_MAX_WIDTH := 620.0
const CP6_ALERT_FONT := 20  # The placeholder alert label (the styled banner uses CP6_ALERT_STYLED_FONT).
const CP6_ALERT_STYLED_FONT := 18
const CP6_LINE_HEIGHT := 34.0  # The styled HUD text lines (parchment panels).
const CP6_LINE_FONT := 16
const CP6_KEY_FONT := 13
const CP6_LINE_MARGIN := 12.0  # From the left edge of the window (and 6 from the bottom).
const CP6_LINE_GAP := 4.0
const CP6_TARGET_RING_INNER := 0.72  # The styled target highlight: the ring's hole as a share of its radius.
const CP6_TARGET_RADIUS_SCALE := 1.2  # The styled ring's radius against TD_HIGHLIGHT_RADIUS.

# ---- Checkpoint 6: dithering and jog (shaders/style_glow, style_ground, scripts/looks/gait.gd, player_look*.gd). ----
# The styled stipple was too strong: each one is cut to about half (the old value is in the comment). The shadow dither
# is set on every toon material (StyleKit.mat) and on the ground; the glow and ground dot shares on their shaders.
const STYLED_DITHER_LIGHT := 0.08  # The shadow band dither amount (was 0.16).
# The player's run (Shift) on top of the walk, applied through Gait.jog (the player only; people keep their gait).
const JOG_CADENCE := 1.15  # Step cycles per second at a full run are multiplied by this.
const JOG_CYCLE_CAP := 4.2  # The most step cycles per second the player's run may take (the walk's cap is 3.4).
const JOG_SWING_ANGLE := 1.25  # Radians the legs swing either way at a full run (the walk swings 1.0).
const JOG_LEAN := 0.14  # Extra forward lean at a full run (radians; the walk leans 0.03).
const JOG_BOB := 0.06  # Extra bounce at a full run (times the leg length; the walk bounces 0.03).
const JOG_DUST_MIN_RUN := 0.5  # How much of a run a footfall needs to raise a dust puff (styled look).
const JOG_DUST_SECONDS := 0.4  # How long a dust puff lasts.
const JOG_DUST_RADIUS := 0.7  # How far a dust puff spreads (metres).
const JOG_DUST_SIDE := 0.22  # How far a puff starts to the side of the player's centre (metres, at each foot).

# ---- Checkpoint 7: props and ambient life (scripts/looks/style_props.gd, style_ambient.gd; styled look only). ----
# Scenery and ambient life only read the game (paint weight, a block's tint, the night's light); they own their random
# numbers and change nothing in the rules.
const C7_SEED := 7007  # The scenery's own random numbers (never the simulation's).
const C7_PROPS_INTERVAL := 0.1  # Seconds between two redraws of the street props.
const C7_BLOOM_SECONDS := 4.0  # Seconds a prop takes to go from bare to full bloom (and back).
const C7_LINE_MAX_DIST := 22.0  # Blocks closer than this (metres) get a bunting or washing line between them.
const C7_LINE_SAG_GLOOM := 1.5  # How far a limp line hangs in gloom (metres).
const C7_LINE_SAG_BLOOM := 0.5  # How far a taut line hangs in bloom (metres).
const C7_LAMP_LEAN := 0.3  # Radians a broken lamp post leans in gloom.
const C7_DAY_ENERGY_LOW := 0.5  # Sun energy at or below this is night (ambient life); above LOW + RANGE, day.
const C7_DAY_ENERGY_RANGE := 0.35
const C7_AMBIENT_MIN_WEIGHT := 0.35  # Paint weight a spot needs for butterflies and fireflies to drift there.
const C7_BUTTERFLIES := 14
const C7_FIREFLIES := 22
const C7_DRIFT_RADIUS := 2.2  # How far a butterfly or firefly wanders from its anchor (metres).
const C7_ANCHOR_REACH := 7.0  # How far from a beautified block an anchor may be picked (metres).
const C7_ANCHOR_INTERVAL := 0.5  # Seconds between two tries to give an idle butterfly or firefly an anchor.
const C7_FADE_SECONDS := 1.5  # Seconds an ambient piece takes to fade in or out.
const C7_BIRD_SECONDS := 3.0  # Seconds a bird takes to fly in and land on a beautified roof.
const C7_BIRD_START := Vector3(5.0, 5.0, 3.0)  # Where a bird comes from, relative to its roof (turned per block).
const C7_IDLE_AFTER := 2.0  # Seconds a rescued person stands still before they start an idle action.
const C7_IDLE_STILL := 0.03  # The most a standing person may move between two checks (metres).
const C7_IDLE_MIN_WEIGHT := 0.4  # Paint weight needed under a person for an idle action.
const C7_IDLE_EASE := 0.8  # Seconds an idle action takes to start or stop.
const C7_SIT_DROP := 0.22  # How far the sitting person's drawing sinks (their rule position never moves).

# ---- Round 25: embrace (scripts/embrace.gd, scripts/looks/embrace_cue.gd). ----
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

# ---- Round 25: gloom tides (scripts/gloom_tide.gd, tide_pointer.gd, minimap.gd, person.gd). ----
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
const TIDE_FOG_FAR := float(TD_PLAZA_SIZE) * 0.6  # Metres from the centre: where the fog band starts (outside).
const TIDE_FOG_NEAR := float(TD_PLAZA_SIZE) * 0.2  # Metres from the centre: where its drift in over the passing ends.
const TIDE_FOG_WIDTH := float(TD_PLAZA_SIZE) * 0.9  # The band's length along the side.
const TIDE_FOG_DEPTH := 12.0 * WORLD_SCALE  # The band's depth (metres).
const TIDE_FOG_Y := 0.06  # Height above the ground (just above the first light front's 0.05).
const TIDE_FOG_COLOUR := Color(0.6, 0.64, 0.7)
const TIDE_FOG_ALPHA := 0.42  # The band's most opaque alpha.
const TIDE_FOG_FADE := 0.15  # The share of the passing over which the band fades in and out.
const TIDE_MINIMAP_COLOUR := Color(0.7, 0.74, 0.8, 0.9)  # The minimap's fog edge (the outer band; inner ones fade).
const TIDE_MINIMAP_BANDS := 3  # Concentric arcs making the edge.
const TIDE_MINIMAP_BAND_STEP := 1.6  # Metres between two arcs of the edge (about two minimap pixels).
const TIDE_MINIMAP_SEGMENTS := 16  # Straight pieces per arc.

# ---- Round 25: edge cleanup (edge_ribbon.gd, edge_markers.gd, edge_marker_fx.gd, edge_dim.gd; both looks). ----
# The border is one ribbon through its members; pushes bow it inward; one marker per trouble spot (at most four); dimmed
# people outside it are drawn faded; the patch, burst and gift effects are short and replace each other.
const EDGE_RIBBON_WIDTH := 0.5  # Metres across a healthy ribbon.
const EDGE_RIBBON_THIN := 0.4  # The share of the width left at full strain (coral and thin near breaking).
const EDGE_RIBBON_STEP := 1.0  # Longest stretch (m) of ribbon between two points (so a dent can bend it smoothly).
const EDGE_RIBBON_CAP := 0.3  # The width share at the very end of a ribbon beside a gap (it tapers off).
const EDGE_RIBBON_GOLD := Color(1.0, 0.82, 0.4)
const EDGE_RIBBON_AMBER := Color(1.0, 0.5, 0.1)
const EDGE_RIBBON_CORAL := Color(1.0, 0.3, 0.28)
const EDGE_RIBBON_HONEY := Color(0.94, 0.66, 0.24)  # A stretch sealed by the map edge.
const EDGE_RIBBON_HALO := 2.4  # Styled look: the halo is this many times the ribbon's width.
const EDGE_RIBBON_REBUILD_FRAMES := 2
const EDGE_FX_MERGE := 3.0  # A new burst mark within this distance (m) replaces the earlier one.
const EDGE_OUT_FADE := 0.55  # How far a dimmed person outside the border is faded toward the ground (0 none, 1 gone).
const EDGE_OUT_FADE_SECONDS := 0.4  # How long the fade takes to come in or go.
const EDGE_OUT_GROUND := Color(0.5, 0.5, 0.5)  # The tone the fade moves toward (the placeholder floor's grey).

# ---- Round 26: physical push (scripts/border_push.gd, border.gd, gloom_tide.gd, person.gd, burst_clear.gd). ----
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
const PUSH_SPREAD := 0.2  # Radians: one standard deviation of a pusher's force along the loop.
const PUSH_DENT_PER_FORCE := 0.85
const PUSH_DENT_MAX := 3.2
const PUSH_BREAK_DEPTH := 2.4  # Metres of dent at which the line snaps.
const PUSH_GIVE_SPEED := 0.55
const PUSH_SPRING_SPEED := 0.9
const PUSH_BREAK_HALF := 1  # Samples either side of the deepest one that open (the break is 2 x this + 1 samples wide).
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

# ---- Checkpoint 7: styled push and HUD (looks/style_push.gd, looks/style_hud.gd, hud.gd, gloom_tide.gd). ----
const CP7_FOG_COLOUR := "#b9b4c9"  # The styled tide fog: pale violet grey (a toon colour, no transparency).
const CP7_FOG_BANKS := 9  # Fog banks along the tide's front (pixel-style blocks, each a different height).
const CP7_FOG_BANK_HEIGHT := 2.2  # Metres: the tallest bank (the others are 60% to 100% of it).
const CP7_FIGURE_COLOUR := "#4a4560"  # The styled tide figures: dark violet, a little lighter than the ink.
const CP7_FIGURE_HEIGHT := 1.6  # Metres to a styled figure's head (placeholder: TIDE_FIGURE_HEIGHT).
const CP7_NIGHT_WIDTH := 400.0  # The styled Dusk to Dawn panel: its width (centred at the top; the bar fills its base).
const CP7_NIGHT_HEIGHT := 52.0
const CP7_NIGHT_BAR_INSET := 14.0  # The bar's side margins and its height, within the panel.
const CP7_NIGHT_BAR_HEIGHT := 12.0
const CP7_NIGHT_FONT := 16
const CP7_NIGHT_TEXT_Y := 18.0  # The panel's label baseline (from its top).
const CP7_TAG_FONT := 16  # The styled spirit label (a parchment tag over the spirit meter).
const CP7_TAG_TEXT_Y := 19.0

# ---- Checkpoint 7: cleanup and look (shaders/style_common, style_toon, style_glow, style_ring, style_wedge,
# style_outline, scripts/looks/looks.gd). Dithering is gone from the toon light, glows, rings, wedge and reach outlines.
const CP7_TOON_SOFT := 0.05  # Half the width (in light level) of the soft step between the toon shadow bands.
const CP7_LOOK_ARG := "--look="  # The user argument that picks the starting look (--look=styled or placeholder).

# ---- Checkpoint 7: living ground and atmosphere (shaders/style_ground, style_mist; looks/style_atmosphere.gd). ----
# Styled look only, scenery only: reads the night clock, the held landmarks and the paint weights, writes nothing.
const CP7_GROUND_GLOOM := 0.55  # How far the cold desaturated tint reaches over unpainted ground (0..1).
const CP7_GROUND_LIFE := 1.0  # Scale of the living pieces: tufts, flowers, moss, puddles; cracks, litter, dead leaves.
const CP7_MIST_STRENGTH := 0.42  # Peak alpha of the low mist over unpainted ground.
const CP7_MIST_SCALE := 0.07  # Noise scale of the mist (per metre; smaller = bigger banks).
const CP7_MIST_HEIGHT := 0.5  # Metres above the ground of the low layer (the high layer sits 2.4 times higher).
const CP7_MIST_COLOUR := Color(0.62, 0.68, 0.78)
const CP7_NIGHT_SKY := Color(0.30, 0.34, 0.48)  # The sky at midnight, before first light warms it.
const CP7_SKY_NIGHT_MIX := 0.8  # How far toward it the sky goes at midnight.
const CP7_SKYLINE_RADIUS := 66.0  # Metres from the centre: the rooftops round the plaza.
const CP7_SKYLINE_ROOFS := 10  # Houses in the sector behind each landmark.
const CP7_SKYLINE_ARC := 1.5  # Radians a sector spans.
const CP7_SKYLINE_EASE := 2.0  # Seconds a sector takes to light up or go grey.
const CP7_BODY_GREY := Color(0.36, 0.38, 0.46)
const CP7_ROOF_GREY := Color(0.30, 0.32, 0.40)
const CP7_ROOF_WARM := Color(1.0, 0.78, 0.42)

static var intro_override: int = -1
static var tides_override: int = -1  # Round 25: as intro_override, for the gloom tides (see tides_on).

# The matchups form a soft cycle:
#   Music is strong against Art, Art is strong against Nature, Nature is strong against Music.
# Matching the affinity gives MATCH_MULT. The element that loses to the affinity gives WEAK_MULT.


# True when the layered introduction (round 13b) is on: always in the game, never under automated tests, unless a test
# sets `intro_override` to 1 (on) or 0 (off). -1 means no override.
static func intro_on() -> bool:
	if intro_override >= 0:
		return intro_override == 1
	return not is_automated_test()


# Round 25: the gloom tides run in the game and not under automated tests (like the intro), so the older scenario suites
# see no tide warnings or notices. A test sets `tides_override` to 1 (on) or 0 (off), and back to -1.
static func tides_on() -> bool:
	if tides_override >= 0:
		return tides_override == 1
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
