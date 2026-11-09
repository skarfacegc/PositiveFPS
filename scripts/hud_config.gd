class_name HudConfig
extends RefCounted

# HUD, minimap, prompts and notices, intro, cue panel, edge pointers, debug overlay (screen-space numbers).

# Debug overlay (F3): height of the cover and protection labels above the ground, in metres (round 8: above joy
# labels).
const TD_DEBUG_LABEL_HEIGHT := 3.2

# Round 8: the F3 labels are sized in world units, not with TD_UI_SCALE, so they stay readable at the camera distance.
# Glyph height on screen is about font size times pixel size, in metres (0.86 m is about 24 px at 1280x720).
const TD_DEBUG_FONT_SIZE := 80
const TD_DEBUG_PIXEL_SIZE := 0.012

# Round 10: the readability visuals (placeholders for the locked style, design/style_test/REVIEW_NOTES.md). The
# minimap: a circle top-left, TD_MINIMAP_WIDTH_FRACTION of the screen width, drawn from TD_MINIMAP_RESOLUTION pixels
# and refreshed every TD_MINIMAP_REFRESH_SECONDS.
const TD_MINIMAP_WIDTH_FRACTION := 0.2
const TD_MINIMAP_RESOLUTION := 128
const TD_MINIMAP_REFRESH_SECONDS := 0.1
const TD_MINIMAP_FRAME_COLOUR := Color(0.93, 0.87, 0.72)
const TD_MINIMAP_LINE_COLOUR := Color(1.0, 0.82, 0.4)
const TD_MINIMAP_MEMBER_COLOUR := Color(0.99, 0.95, 0.85)
const TD_MINIMAP_DIMMED_COLOUR := Color(0.1, 0.1, 0.12)
const TD_MINIMAP_LANDMARK_COLOUR := Color(1.0, 0.85, 0.45)
const TD_MINIMAP_PLAYER_COLOUR := Color(1.0, 0.7, 0.15)
const TD_MINIMAP_VIEW_COLOUR := Color(1.0, 1.0, 1.0, 0.7)
const TD_MINIMAP_WARM_COLOUR := Color(0.93, 0.84, 0.66)
const TD_MINIMAP_GREY_COLOUR := Color(0.55, 0.55, 0.56)

# Off-screen gap arrows: a badge on the screen edge, this many pixels in from the edge, this big, and kept this far
# (pixels) clear of the minimap circle.
const OFFSCREEN_ARROW_MARGIN := 40.0
const OFFSCREEN_ARROW_SIZE := 14.0
const OFFSCREEN_ARROW_PAD := 16.0
const MINIMAP_BLIP_SECONDS := 2.5
const MINIMAP_BLIP_COLOUR := Color(0.7, 0.5, 0.95)

# Screen-space markers (pixels): the pulsing ring at a faltering person's feet, the progress ring, the "!" badge.
const FALTER_MARKER_RADIUS := 26.0
const FALTER_RING_RADIUS := 34.0
const FALTER_BADGE_SIZE := 26.0
const FALTER_PULSE_HZ_MIN := 1.0
const FALTER_PULSE_HZ_MAX := 3.2
const FALTER_CLOSED_SECONDS := 0.8
const FALTER_SEAL_COLOUR := Color(1.0, 0.9, 0.55)

# The spirit meter (bottom centre) and its moments.
const SPIRIT_METER_WIDTH := 360.0
const SPIRIT_METER_HEIGHT := 22.0
const SPIRIT_MOMENT_SECONDS := 1.1
const SPIRIT_GAIN_COLOUR := Color(1.0, 0.88, 0.4)
const SPIRIT_SPEND_COLOUR := Color(0.7, 0.55, 1.0)
const SPIRIT_LOSS_COLOUR := Color(1.0, 0.4, 0.38)

# Layered introduction through the night (driven by NightCycle progress). Dimmed people emerge at NIGHT_CALM_FRACTION;
# each mood becomes active at its fraction (indexed by Person.Mood: NONE, GUARDED, SKITTISH, GLUM). One-time prompts
# last PROMPT_SECONDS and never overlap. `intro_on()` is false in automated tests (they set `intro_override` to turn
# it
# on to test the intro).
const MOOD_INTRO_FRACTIONS: Array[float] = [0.0, 0.35, 0.5, 0.65]
const PROMPT_SECONDS := 4.0
const PROMPT_FADE_SECONDS := 0.5
const INTRO_CHECK_SECONDS := 0.2
const INTRO_DIM_CAP := 0.669

# Round 19: cleanup (scripts/hud.gd, topdown_main.gd)
# The Rescued counter sits this many pixels below the bottom of the minimap, so the minimap never covers it.
const RESCUED_BELOW_MINIMAP_GAP := 10.0

# Refusals stay this long (seconds) in a larger bar; ordinary prompts keep PROMPT_SECONDS.
const NOTICE_SECONDS := 4.0
const NOTICE_COLOUR := Color(1.0, 0.62, 0.45)

# The minimap star of a landmark that is not held (a held one is gold with its ring), placeholder look.
const TD_MINIMAP_LANDMARK_UNHELD_COLOUR := Color(0.34, 0.32, 0.31)

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

# The minimap's ground layer is rebuilt at most this often (a rebuild is about 8 ms).
const MINIMAP_GROUND_SECONDS := 0.5
const MINIMAP_CLOUD_RIM := 0.9
const MINIMAP_CLOUD_COLOUR := Color(0.06, 0.1, 0.34)

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

# Pull-in: arms retreat once the body scale is within this factor of the smallest it can reach (it lags the ease).
const LANDMARK_POINTER_REFRESH := 0.2  # Seconds between two works-out of the landmark pointers (5 a second).
const NOTICE_FONT_SIZE := 15  # Checkpoint 6: a slim banner (was 16 and 34).
const NOTICE_HEIGHT := 32.0

# Cue: a small line near the player, shown only when F (patch) or G/Q (burst) can be acted on right now.
# Result: a short rising count at the patched spot and at each person the burst lifted, with a halo on them.
# Landmarks: boosts doubled (LANDMARK_*_MULT, Round 19 block). The third light needs 75% rescued and 2 landmarks
# (checkpoint 5).
const CUE_FONT_SIZE := 18
const CUE_PLAYER_RANGE := 14.0 * Config.WORLD_SCALE  # A gap or strain this close to the player counts as "near".
const CUE_ALPHA := 0.8
const CUE_BURST_TEXT := "G: lift %d"
const CUE_HUD_GAP := 18.0  # Pixels between the spirit meter's right end and the cue.
const CUE_HUD_Y := -112.0  # Offset from the bottom of the screen (the meter's own top).
const CUE_READY_COLOUR := Color(1.0, 0.92, 0.5)
const CUE_PULSE_HZ := 1.6

# A wobble (a drained rescued person, about WOBBLE_SECONDS before a relapse) used to start off screen and go unseen. Now
# a pulsing pointer sits on the screen edge toward each cluster of off-screen wobblers (most urgent first, at most
# WOBBLE_ALERT_MAX). It pulses faster as the wobble runs out, and it is smaller than the gap arrows' urgency pulse but
# warmer than the landmark pointers. On the minimap each wobbler is a pulsing blip.
const WOBBLE_ALERT_REFRESH := 0.2  # Seconds between two works-out of the pointers (the pulse is redrawn every frame).

# Off-screen wobblers this close (on the ground) share a pointer.
const WOBBLE_ALERT_CLUSTER_RADIUS := 12.0 * Config.WORLD_SCALE
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
const SPIRIT_LABEL_TOP := -146.0  # The spirit label's top, in pixels above the bottom of the screen (above the bar).
const SPIRIT_LABEL_HEIGHT := 28.0

# The wobble pointers keep clear of the HUD: each tip sits in the safe rectangle (the screen less the shown HUD panels,
# WobbleAlert.safe_rect), and the whole pointer (ring, arrow and count) stays WOBBLE_ALERT_REACH inside it.
const WOBBLE_ALERT_SAFE_INSET := 8.0  # Pixels between the safe rectangle and the screen edge.
const WOBBLE_ALERT_PANEL_GAP := 6.0  # Pixels a pointer keeps from a HUD panel.
const WOBBLE_ALERT_REACH := 34.0  # Pixels from a tip to the furthest part of its pointer (ring, arrow and count).

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
const CP7_NIGHT_WIDTH := 400.0  # The styled Dusk to Dawn panel: its width (centred at the top; the bar fills its base).
const CP7_NIGHT_HEIGHT := 52.0
const CP7_NIGHT_BAR_INSET := 14.0  # The bar's side margins and its height, within the panel.
const CP7_NIGHT_BAR_HEIGHT := 12.0
const CP7_NIGHT_FONT := 16
const CP7_NIGHT_TEXT_Y := 18.0  # The panel's label baseline (from its top).
const CP7_TAG_FONT := 16  # The styled spirit label (a parchment tag over the spirit meter).
const CP7_TAG_TEXT_Y := 19.0
const CP7_NIGHT_SKY := Color(0.30, 0.34, 0.48)  # The sky at midnight, before first light warms it.
