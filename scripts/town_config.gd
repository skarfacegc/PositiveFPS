class_name TownConfig
extends RefCounted

# The town layout: streets, lamps, stalls and the landmark distances.

# The town is a main street along x (z = 0) and a cross street along z (x = 0), TOWN_STREET_HALF_WIDTH either side of
# the line. They cross at the player's start, which is the small square. Twenty blocks stand in rows on both sides of
# each street, in front of the pavement strip, and face the street. One landmark stands at the end of each street arm.
const TOWN_STREET_HALF_WIDTH := 5.0  # Metres from a street's centre line to its kerb.
const TOWN_KERB_OFFSET := 5.5  # Metres from the centre line: the lamps stand in the pavement strip at this distance.
const TOWN_LAMP_SPACING := 10.0  # Metres between the lamps along a kerb.
const TOWN_LAMP_FIRST := 10.0  # The first lamp stands this far from the crossing (the square is kept clear).
const TOWN_EDGE_CLEAR := 8.0  # Lamps stop this far from the plaza's edge.
const TOWN_STALL_OFFSET := 8.0  # The four stalls on the small square stand at (+-8, +-8) from the start.
const TOWN_BENCH_OFFSET := 2.9  # A block's bench stands this far in front of its centre (toward the street).
const TOWN_PLANTER_OFFSET := Vector2(2.7, 2.6)  # A block's planter: forward, then sideways.
const LANDMARK_NEAREST := 18.0  # Metres: every landmark stands between these two distances of the start.
const LANDMARK_FARTHEST := 32.0
