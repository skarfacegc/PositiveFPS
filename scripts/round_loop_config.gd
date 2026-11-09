class_name RoundLoopConfig
extends RefCounted

# The round border loop: sampled radii, the drifting centre, the size ease, map-edge seals, burst shove.
# Kept as they were, untidied: pass 2 of 0.4 deletes this whole file.

# The centre (the smoothed centroid of rescued people) moves toward the target centroid at this speed, in m/s.
const BORDER_CENTRE_FOLLOW := 0.5

# The border loop has this many points (one per angle), and is drawn as line segments.
const BORDER_SAMPLES := 48

# The border never shrinks below a circle of this radius, in metres.
const BORDER_MIN_RADIUS := 3.0 * Config.WORLD_SCALE

# Each rescue pushes the border outward at its angle, by this much at the peak (metres). Round 10: 2.4 (was 1.6),
# which is about one member's spacing of perimeter (the Gaussian area is BORDER_PUSH x 1.25).
const BORDER_PUSH := 2.4 * Config.WORLD_SCALE

# The push is spread over this many radians (a Gaussian), so the bump is smooth.
const BORDER_PUSH_WIDTH := 0.5

# The total size is eased toward the target perimeter over this many seconds.
const BORDER_NORMALISE_SECONDS := 2.0

# The joy burst shoves the border outward toward the player when they are this close to it (metres), by this much.
const BORDER_SHOVE_RANGE := 4.0
const BORDER_SHOVE_AMOUNT := 1.5 * Config.WORLD_SCALE

# (Round 19: the centre no longer follows the centroid once the border forms; see "Round 19: beacon".)
# Raw radii ease toward the mean of their four neighbours at this rate, per second (bumps relax).
const BORDER_RELAX_RATE := 1.5

# Raw radii stop at this share of the way to the map edge again (1.1: just beyond it, so the loop still meets the
# edge).
const BORDER_WALL_SLACK := 1.1

# A block the loop wraps round lifts the samples beside it too, as a tent this many samples wide on each side.
const BORDER_WRAP_TENT := 3

# A stretch sealed by the map edge shorter than this is opened again (its neighbours would stand too close).
const BORDER_MIN_SEAL_RUN := BorderConfig.BORDER_TARGET_SPACING

# The border stays on the map: its loop is clamped to this distance from the middle (the same limit people wander to).
# Where it runs along the edge it is sealed (closed by the map, never a gap, no slots).
const BORDER_MAP_LIMIT := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN

# A loop segment counts as sealed by the map edge when both ends are on it; it fades in over this distance (metres
# from
# the edge) so the open length of the loop changes smoothly (a segment 2 m off the edge is fully open).
const BORDER_SEAL_BAND := 2.0 * Config.WORLD_SCALE
