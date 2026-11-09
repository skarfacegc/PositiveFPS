class_name MoodConfig
extends RefCounted

# Moods, sheltering, the shield and its readability (umbrella, pips, tethers, mood icons).

# Round 12b: moods, sheltering, edge pressure, local gaps, noticeable stage changes
# Every unrescued wistful or gloomy person has one mood (dimmed people have none). See scripts/moods.gd.
# Guarded: faces away from the player, turning at GUARDED_TURN_SPEED radians a second. Joy only lands when the angle
# between their facing and the direction to the shooter is at most GUARDED_ARC_DEG; otherwise it glances off.
const GUARDED_ARC_DEG := 110.0

# GUARDED_TURN_SPEED (round 12b: 0.8 rad/s) moved to the Round 17 block: slowed to 0.45 so a shot can be lined up.
const GLANCE_COLOUR := Color(0.9, 0.9, 0.95)

# Skittish: a player closer than SKITTISH_RADIUS who moves faster than SKITTISH_SPEED_LIMIT (walk speed x 1.1, so a
# run) scares them into backing away at SKITTISH_FLEE_SPEED for SKITTISH_FLEE_SECONDS. Walking up does not.
const SKITTISH_RADIUS := 5.0
const SKITTISH_SPEED_LIMIT := PlayerConfig.TD_MOVE_SPEED * 1.1
const SKITTISH_FLEE_SPEED := 2.5
const SKITTISH_FLEE_SECONDS := 1.5

# Glum: slumped, but every GLUM_LOOKUP_INTERVAL seconds (plus or minus GLUM_LOOKUP_JITTER, seeded) they look up for
# GLUM_LOOKUP_WINDOW seconds. Joy that lands in that window counts GLUM_LOOKUP_MULT times.
const GLUM_LOOKUP_INTERVAL := 3.0
const GLUM_LOOKUP_JITTER := 0.8
const GLUM_LOOKUP_WINDOW := 0.8
const GLUM_LOOKUP_MULT := 3.0
const GLUM_GLINT_COLOUR := Color(1.0, 0.85, 0.45)

# Sheltering: joy does not land on a wistful or gloomy person while a dimmed person is this close (metres).
const SHELTER_RADIUS := 2.0
const SHELTER_COLOUR := Color(0.45, 0.45, 0.5)

# Placeholder mood tells: the jitter of a skittish person (metres). (The guarded crossed-arms bar was replaced by the
# shield icon in round 13b.)
const SKITTISH_JITTER := 0.05
const GLUM_SLUMP_SCALE := 0.8

# Mood icons (screen-space, pixels) and the blocked-joy flash.
const MOOD_ICON_SIZE := 26.0
const MOOD_ICON_COLOURS: Array[Color] = [
	Color(1, 1, 1),
	Color(0.55, 0.65, 1.0),
	Color(1.0, 0.72, 0.3),
	Color(0.68, 0.74, 0.86),
	Color(0.78, 0.6, 1.0),
]
const GLUM_UP_ICON_COLOUR := Color(1.0, 0.9, 0.5)
const BLOCK_FLASH_SECONDS := 0.55
const BLOCK_SPARK_SECONDS := 0.4
const TETHER_COLOUR := Color(0.72, 0.6, 0.95, 0.4)
const TETHER_SNAP_SECONDS := 0.45

# The umbrella stays nearly opaque however worn it is: the wear shows as pips (below), not as a fade. The styled
# look keeps its own floor (its holes already show the wear).
const UMBRELLA_MIN_ALPHA := 0.85
const STYLED_UMBRELLA_MIN_ALPHA := 0.6

# A worn umbrella shrinks a little (1 fresh, this much smaller about to pop).
const UMBRELLA_MIN_SCALE := 0.9

# Wear pips under the umbrella: one per shield hit (SHELTER_HITS). Filled = hits left, hollow = used. Pixels, centre
# to
# centre; the row sits PIP_LIFT pixels under the icon.
const PIP_RADIUS := 3.0
const PIP_SPACING := 8.0
const PIP_LIFT := 6.0
const PIP_HOLLOW_ALPHA := 0.5

# The tether from a dimmed person to who they shelter: thicker, steady, in the umbrella's colour (placeholder look).
const SHELTER_TETHER_COLOUR := Color(0.78, 0.6, 1.0, 0.85)
const SHELTER_TETHER_WIDTH := 4.0

# A small canopy drawn over a sheltered person's head (pixels): its width, and how far above the head it sits.
const SHELTER_CANOPY_WIDTH := 30.0
const SHELTER_CANOPY_LIFT := 26.0

# The pop: a burst ring (pixels, from POP_RING_MIN out to POP_RING_MAX) and the pip emptying, over POP_SECONDS.
const SHELTER_POP_SECONDS := 0.5
const SHELTER_POP_RING_MIN := 12.0
const SHELTER_POP_RING_MAX := 46.0

# The regrow ring: a faint arc round a dimmed person during their SHELTER_REGROW cooldown (fills as it passes).
const REGROW_RING_RADIUS := 44.0
const REGROW_RING_WIDTH := 2.5
const REGROW_RING_ALPHA := 0.5

# Guarded: a wedge on the ground shows the open side, the arc where joy lands. It is centred on the person's facing
# and
# spans GUARDED_ARC_DEG either side of it (the same arc Person.is_open_to uses), so its edges are the edges of the
# rule. A body-sized radius in metres (not scaled by WORLD_SCALE). It is brighter while a shot from the player would
# land now.
const GUARDED_WEDGE_RADIUS := 2.0
const GUARDED_WEDGE_SEGMENTS := 24
const GUARDED_WEDGE_COLOUR := Color(1.0, 0.93, 0.7, 0.2)
const GUARDED_WEDGE_OPEN_COLOUR := Color(1.0, 0.93, 0.7, 0.5)

# Guarded turning, slowed from 0.8 rad/s so the player can line up a shot before they turn away.
const GUARDED_TURN_SPEED := 0.45

# A dimmed person's shield: joy that hits the person it shelters still lets SHELTER_LEAK of its amount through. Each
# landing (one Person.receive_joy call on that person) wears the shield; on the SHELTER_HITS-th it pops.
const SHELTER_LEAK := 0.25
const SHELTER_HITS := 4

# After a pop the dimmed person cannot shelter anyone for this many seconds. Then, if still dimmed, a fresh shield.
const SHELTER_REGROW := 8.0

# Particles in the puff where a shield pops (on the sheltered person).
const SHELTER_POP_PUFF := 16
