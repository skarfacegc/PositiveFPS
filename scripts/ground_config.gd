class_name GroundConfig
extends RefCounted

# The painted ground: paint speeds, cover, contagion, erosion, territory edge and the floor effect cap.

# Painted ground: tiles around rescued people take on their element colour.
const GROUND_GREY := Color(0.5, 0.5, 0.5)  # Unpainted ground colour.
const GROUND_PAINT_STRENGTH := 0.75  # How strongly the paint colour shows right next to a rescued person (0-1).
const GROUND_PAINT_SPEED := 0.15  # How fast each tile moves toward its target colour per update (0-1).
const GROUND_UPDATE_INTERVAL := 0.1  # Seconds between ground colour updates.

# Cover (round 7): each person's cover is the average paint weight of the ground within TD_COVER_RADIUS metres. Their
# protection is smoothstep(TD_COVER_EDGE, TD_COVER_FULL, cover): 0 at the edge of a painted area, 1 well inside it.
const TD_COVER_RADIUS := 3.0 * Config.WORLD_SCALE
const TD_COVER_EDGE := 0.35
const TD_COVER_FULL := 0.85

# Joy contagion: with at least this much cover, an unrescued person's gloom drops by TD_CONTAGION_RATE per second
# (times their protection). That is about one grey level per ten seconds deep inside. It never adds joy or rescues.
const TD_CONTAGION_THRESHOLD := 0.6
const TD_CONTAGION_RATE := 0.034

# Top-down ground: painting in and fading back are separate speeds (per ground update). Painting is quick, but fading
# back is slow, so territory lags behind people and lingers after a relapse.
const TD_GROUND_SPREAD_SPEED := 0.05
const TD_GROUND_FADE_SPEED := 0.012

# Round 8: own paint does not protect. A rescued person's cover leaves out the paint made by their own soft circle
# (see PaintedGround.average_weight_excluding). Unrescued people still use the full cover.
#
# Round 8: gloom erodes paint at the edge of territory. Each unrescued dimmed person takes TD_ERODE_RATE weight per
# second off the edge tiles within TD_ERODE_RADIUS. A tile is edge unless it and all its neighbours are at least
# TD_ERODE_EDGE_MAX (deep interior tiles are immune). An eroded tile cannot regrow for TD_ERODE_HOLD seconds.
const TD_ERODE_RADIUS := 2.0 * Config.WORLD_SCALE
const TD_ERODE_RATE := 0.25
const TD_ERODE_EDGE_MAX := 0.9
const TD_ERODE_HOLD := 3.0

# The territory edge (for dimmed people with no one to chase) is painted tiles with weight in (TD_EDGE_MIN, EDGE_MAX).
const TD_EDGE_MIN := 0.05

# A dimmed person with no one to chase drifts to the nearest territory edge, and stops this close to it (metres).
const TD_EDGE_REACH := 0.5

# Round 10: the floor. Every floor overlay, with its draw priority (lower number = read first):
#   1  border line and gap glow (Border): always the clearest things on the floor.
#   2  target and threat (target highlight, the player's element ring and warm ring, grace rings on rescued people).
#   3  projectile effects, capped by TD_MAX_FLOOR_EFFECTS (oldest first): music sound rings, paint splats, splash
# rings,
#      petal bursts, blooms (Bloom) and trail pieces (note dots, drips, drip splat dots, petals). The joy burst ring
#      lasts 0.35 s and is not counted.
#   4  territory paint: the painted ground tiles (PaintedGround), drawn quietest.
# Impact puffs (1 s particle bursts) and the floating numbers are not floor overlays. The cap: when a new effect would
# exceed TD_MAX_FLOOR_EFFECTS, the oldest priority-3 effect is freed first.
const TD_MAX_FLOOR_EFFECTS := 40
