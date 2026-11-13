class_name BorderConfig
extends RefCounted

# The living border: members, slots, gaps, ribbon, edge pressure, zone control around blocks.

# Rescued people needed before a border forms. Below this count the border collapses once it has formed.
const BORDER_MIN_PEOPLE := 3

# Walls and gates: Take a block (#10, #11). Holding E and releasing takes the cell pointed at, for TAKE_SPIRIT_COST
# spirit (refused when spirit is short; Grid fixes: free when its pips are full). A cell next to the zone fills a pip
# with each rescued person who belongs to it; at TAKE_RESCUES it is ready (it never joins by itself).
const TAKE_SPIRIT_COST := 25.0
const TAKE_RESCUES := 3

# Walls and gates: Line (0.4, #56). The line is the outline of the zone (Zone); only its gates carry members and the
# push. A gate has a point of the traced line every GATE_POINT_STEP metres (so a dent shows); a gate needs its length
# over BORDER_TARGET_SPACING members, rounded up (a 10 m street mouth 2, a 12 m square side 2, the start square's
# 18 m side 3). People who are not on a gate stand on the zone's open ground, GATE_INNER_INSET metres in from the edges
# of its rectangles.
const GATE_POINT_STEP := 2.0
const BORDER_MAP_LIMIT := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN  # People stay inside this (x and z).
const GATE_INNER_INSET := 2.4
const BORDER_SWEEP_BAND := 0.35  # A dimmed person caught this close inside an intact gate is swept back outside it.
const GATE_MOUTH_OUTSIDE := 3.0  # Metres outside a gate's middle: where a dimmed person heading for the gate aims.
const GATE_MOUTH_REACH := 4.0  # Within this many metres of a gate a dimmed person is at its mouth: straight on.

# Members stand this far apart along a gate, in metres. A gate's member count is its length / this, rounded up. Round
# 10: 3.0 (was 2.2), so growing is easier. Walls and gates: Loop tuning (#93): one member per 6 m on the ground (was
# 2.6 x WORLD_SCALE, about 3.7 m), so a new cell wants about 12 people, not 20.
const BORDER_TARGET_SPACING := 4.2 * Config.WORLD_SCALE

# Members walk to their slot at this speed, in metres per second.
const BORDER_WALK_SPEED := 3.0

# A dimmed person outside the border drains the nearest member within this distance, in metres.
const BORDER_PRESS_RANGE := 1.5

# Cover from the border: 0 on the line, 1 this many metres inside it (so a grey person there can be lightened).
const BORDER_EDGE_BAND := 1.0 * Config.WORLD_SCALE

# A member who relapses steps this far outward through their gate (metres).
const BORDER_OUTWARD_STEP := 1.0 * Config.WORLD_SCALE

# A building is beautified after this many seconds with at least this fraction of its footprint inside the border.
const BORDER_BUILDING_SECONDS := 3.0
const BORDER_BUILDING_INSIDE := 0.7

# The warm tint takes this long to fade in (and out), in seconds.
const BORDER_TINT_SECONDS := 2.0

# Beautified buildings go this warm colour. Mechanical blocks keep their grey.
const BORDER_BUILDING_COLOUR := Color(0.92, 0.7, 0.55)

# The ground inside the border goes this colour (warm cream), and outside it stays grey.
const BORDER_GROUND_COLOUR := Color(0.93, 0.84, 0.66)

# The border line: intact is warm gold, a gap flickers between grey and red.
const BORDER_INTACT_COLOUR := Color(1.0, 0.82, 0.4)

# Round 10: a gap glows coral and pulses softly (p = 0.5 - 0.5 cos(2 pi t / 1.2)). The glow band is
# BORDER_GAP_GLOW_WIDTH metres wide and fades between BORDER_GAP_GLOW_ALPHA_MIN and BORDER_GAP_GLOW_ALPHA_MAX with the
# pulse. It is never a hard line.
const BORDER_GAP_COLOUR := Color(0.95, 0.42, 0.36)
const BORDER_GAP_PULSE_SECONDS := 1.2
const BORDER_GAP_GLOW_WIDTH := 1.2
const BORDER_GAP_GLOW_ALPHA_MIN := 0.15
const BORDER_GAP_GLOW_ALPHA_MAX := 0.7

# How far above the ground the border line is drawn, in metres.
const BORDER_LINE_HEIGHT := 0.08

# An intact stretch is not drained: dimmed people pressing on it are pushed outward at this speed (metres per second).
const BORDER_PUSHBACK_SPEED := 0.35

# Round 11: dimmed people pressing an intact stretch also drain the nearest member, at this fraction of the gap drain
# rate (gaps keep the full rate). It makes the border feel at risk again without letting it fall to one press.
const BORDER_INTACT_DRAIN_FRACTION := 0.25

# Edge pressure: dimmed people prefer a member whose gate is already giving. A gate's score is how bent it is there
# (Border.edge_pressure, 0 flat to 1 at the break depth); a score of 1 is worth EDGE_PRESSURE_REACH metres of walking.
const EDGE_PRESSURE_REACH := 12.0 * Config.WORLD_SCALE

# Protection values closer than this count as equal when a dimmed person picks a target.
const EDGE_PROTECTION_TIE := 0.05

# Local gaps: a border member drained below MEMBER_FALTER_FRACTION of their joy needed falters and opens a gap on both
# sides of them. (The plan said 0.5, but a person relapses at RELAPSE_FRACTION 0.5, so faltering starts higher.)
const MEMBER_FALTER_FRACTION := 0.75

# Round 13b: communication (no new mechanics)
# Gaps: seconds a gap must stay open for its urgency to reach 1 (marker pulse, minimap marker and arrow intensify).
const GAP_URGENCY_SECONDS := 8.0

# A gap seen again within this many metres of where it was last frame is the same gap (its age carries over).
const GAP_TRACK_RADIUS := 6.0

# Gloom leaking in through an open gap: grey-violet motes drifting from the gap toward the border centre.
const LEAK_COLOUR := Color(0.55, 0.46, 0.7)
const LEAK_MOTES_PER_GAP := 8
const LEAK_MOTES_MAX := 120

# Only gaps within the view plus this many metres leak motes.
const LEAK_VIEW_MARGIN := 8.0
const LEAK_SPEED := 1.6
const LEAK_LIFE_SECONDS := 1.8

# Members walk at BORDER_WALK_SPEED, but at most this many times their distance to the slot per second (they ease in).
const BORDER_ARRIVE_GAIN := 4.0

# Round 26: the burst cue works out its count (and fades the people outside) every BORDER_WARN_INTERVAL seconds.
const BORDER_WARN_INTERVAL := 0.1

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

# People are not stopped by blocks (they are moved directly), so on the street grid slots and walks ran through the
# block footprints. Slots and targets are moved out of every footprint grown by this clearance, and a walking person
# slides round a footprint's face instead of through it. A body size, so it is not scaled by WORLD_SCALE.
const ZONE_BLOCK_CLEAR := 0.8  # Metres a person keeps from a block's face (the footprint grown by this on every side).
const ZONE_DETOUR_ARRIVE := 0.3  # Metres from the target at which a detour is dropped.
const ZONE_CORNER_OUT := 0.02  # Metres a detour's corner stands outside the grown footprint.
const ZONE_CORNER_LANE := 0.5  # Metres: the most a person's corner may lie beyond the grown footprint.
const ZONE_CORNER_REACHED := 0.01  # Metres from a corner at which it counts as reached (a step lands on it).
const ZONE_CORNER_SLACK := 0.03  # A straight walk to a corner may skim a footprint's edge by this much.

# Walls and gates: Grid fixes (#10, #56). Take by E only: a cell with all its pips (TAKE_RESCUES) is ready and E takes
# it free; any other cell next to the zone costs TAKE_SPIRIT_COST. People never refuse a take: each gate shows its
# members against its need (red when short) and the take preview shows the people the new gates need against the free
# ones. Cells you can take glow on the ground and on the minimap (one look for free, another for paid); a taken cell
# pulses.
const TAKE_MARK_FREE_COLOUR := Color(1.0, 0.86, 0.35, 0.5)
const TAKE_MARK_PAID_COLOUR := Color(0.45, 0.7, 1.0, 0.35)
const TAKE_MARK_INSET := 0.8  # Metres: the glow stops this far inside the cell edge.
const TAKE_MARK_Y := 0.12  # Metres above the ground.
const TAKE_PULSE_SECONDS := 1.0  # A taken cell pulses for this long.
const TAKE_PULSE_COLOUR := Color(1.0, 0.95, 0.7, 0.6)
# Walls and gates: Pressure (#13). A gate that stays broken for GATE_LOST_SECONDS loses the held cell behind it
# (never the start square; a cell the loss cuts off from the start goes with it). The cell's pips reset, nobody
# relapses, a slim banner says so and the cell pulses grey for LOST_PULSE_SECONDS (placeholder look).
const GATE_LOST_SECONDS := 12.0
const LOST_TEXT := "The gloom took a block."
const LOST_PULSE_SECONDS := 1.6
const LOST_PULSE_COLOUR := Color(0.55, 0.57, 0.6, 0.65)
const LOST_PULSE_Y := 0.14  # Metres above the ground.
const GATE_COUNT_HEIGHT := 1.6  # Metres above the ground: the members/need label on a gate.
const GATE_COUNT_OK_COLOUR := Color(1.0, 0.95, 0.8)
const GATE_COUNT_SHORT_COLOUR := Color(1.0, 0.3, 0.28)
const GATE_COUNT_PIXEL_SIZE := 0.012
const GATE_COUNT_FONT_SIZE := 64
const GATE_COUNT_OUT := 1.2  # Metres outside the gate line.
