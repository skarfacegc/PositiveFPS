class_name PlayerConfig
extends RefCounted

# The player and the camera: movement, zoom, targeting, hover, highlight and the player marker.

# Round 10: an orthographic camera, size TD_CAMERA_ORTHO_SIZE (the view height in metres at the focus), tilted down at
# TD_CAMERA_PITCH_DEG degrees. It sits TD_CAMERA_DISTANCE metres from its look point, which is the player plus
# TD_CAMERA_LOOK_OFFSET (2.4 m north, so the player sits a little below the centre of the screen).
# Round 14: the reference size is 19.5 (the default zoom, a little further out than 18). The mouse wheel zooms between
# TD_ZOOM_MIN and TD_ZOOM_MAX (see the zoom block below); TD_CAMERA_ORTHO_SIZE is the size at default zoom.
const TD_CAMERA_ORTHO_SIZE := 19.5
const TD_CAMERA_PITCH_DEG := 41.0
const TD_CAMERA_DISTANCE := 20.0

# Round 14: the offset is for the default zoom and scales with the zoom (-2.6 x 19.5 / 18), so the player keeps the
# same place on screen at every zoom.
const TD_CAMERA_LOOK_OFFSET := Vector3(0, 0, -2.82)

# Mouse-wheel zoom (round 14): the view height goes from TD_ZOOM_MIN (close) to TD_ZOOM_MAX (wide), one TD_ZOOM_STEP
# per wheel notch, eased at TD_ZOOM_EASE per second (an exponential approach).
const TD_ZOOM_MIN := 14.0
const TD_ZOOM_MAX := 26.0
const TD_ZOOM_STEP := 1.5
const TD_ZOOM_EASE := 8.0

# Walking speed, in metres per second.
const TD_MOVE_SPEED := 7.6  # Round 13a: +10% (6.9) to offset the longer walks.

# Speed while holding Shift, in metres per second. Round 11: walk and run are about 15% faster than round 10 (6.0,
# 9.5).
const TD_RUN_SPEED := 12.0  # Round 13a: +10% (10.9).

# A person can only be targeted (and shot at) while this close to the player, in metres. Round 11: 10.0 (was 8.6), the
# largest round value whose full ring still fits on a 1280x720 screen with the zoomed-out camera (see the camera
# test).
const TD_AUTO_RANGE := 10.0

# How the player picks a target. LOCK_ON: click a person to lock on. HOVER_STICKY: the person under the mouse is
# picked when there is no target, and then stays the target. AUTO: the most urgent person in range. The mode at the
# start of a top-down round. F2 cycles through the modes at runtime. Round 8: hover is the default (playtest 7
# preferred it).
const TD_TARGETING_MODE := Config.TargetingMode.HOVER_STICKY

# Short names for each TargetingMode, in the same order (shown on the HUD).
const TD_TARGETING_NAMES: Array[String] = ["Lock-on", "Hover", "Auto"]

# Lock-on: a click picks the valid person nearest the mouse ground point, if within this many metres.
const TD_CLICK_RADIUS := 1.6

# A lock (or a hover target) is dropped when the target is further than this from the player, in metres.
const TD_LOCK_BREAK_RANGE := 14.0

# Hover: with no target, the valid person nearest the mouse point within this many metres becomes the target.
const TD_AIM_ASSIST_RADIUS := 3.5

# Shots per second while there is a target in range.
const TD_SHOTS_PER_SECOND := 5.0

# Colour of the element ring under the player when there is no target.
const TD_NO_TARGET_COLOR := Color(0.92, 0.9, 0.82)

# The target highlight: a ring at the target's feet, its radius, colour, and how far it pulses (scale change).
const TD_HIGHLIGHT_RADIUS := 0.75
const TD_HIGHLIGHT_COLOR := Color(1.0, 0.85, 0.5, 0.85)
const TD_HIGHLIGHT_PULSE := 0.05

# Pulse speed in radians per second (a slow pulse).
const TD_HIGHLIGHT_PULSE_SPEED := 3.0

# Size multiplier for floating numbers and labels in top-down mode. Round 8: 1.9 (was 2.5), to match the closer camera
# so the labels keep about the same size on screen.
# Round 14: the labels scale with the zoom (ui_scale = TD_UI_SCALE x size / TD_CAMERA_ORTHO_SIZE), so they keep the
# same
# size on screen at every zoom. 2.5675 = 2.37 x 19.5 / 18 keeps the round 13b size at the default zoom.
const TD_UI_SCALE := 2.5675

# The player marker: a saffron body no person uses, a warm double ring on the ground, and a soft glow under it.
const TD_PLAYER_COLOUR := Color(1.0, 0.62, 0.12)
const TD_PLAYER_RING_COLOUR := Color(1.0, 0.85, 0.5)
const TD_PLAYER_RING_RADII: Array[float] = [1.2, 1.4]
const TD_PLAYER_RING_WIDTH := 0.06
const TD_PLAYER_GLOW_RADIUS := 1.9
const TD_PLAYER_GLOW_ALPHA := 0.18

# Hover targeting: the held target is kept for at most this long after the cursor stops being over or nearest to it.
# A person directly under the cursor (within HOVER_DIRECT_RADIUS metres of the aim point, a body size) takes over at
# once, with no wait.
const HOVER_STICK_SECONDS := 0.2
const HOVER_DIRECT_RADIUS := 1.0
const CP6_TARGET_RING_INNER := 0.72  # The styled target highlight: the ring's hole as a share of its radius.
const CP6_TARGET_RADIUS_SCALE := 1.2  # The styled ring's radius against TD_HIGHLIGHT_RADIUS.
