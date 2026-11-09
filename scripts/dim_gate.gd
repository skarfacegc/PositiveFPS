class_name DimGate
extends RefCounted

# The midnight stagger (round 14): people sink to dimmed one at a time, and not at all during the calm opening.
# TopDownMain builds it as `dim_gate`; each person asks `ask` before sinking (Person.dim_gate).

# Round 14: game time that passed in the night (the clock for the staggered arrivals) and the clock value when a person
# last sank to dimmed (-INF before anyone did).
var clock: float = 0.0
var last_sink: float = -INF
var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


# Round 13b: nobody sinks to dimmed during the calm opening (they wait as gloomy: the cap holds them under the gloomy
# band's top). Round 14, the midnight surge is staggered by `ask` (asked from Person._check_level). Runs after
# GloomSim.update.
func hold_back(delta: float) -> void:
	clock += delta
	if not _main.intro.dimmed_allowed():
		for p: Person in _main.people:
			if not p.is_rescued and p.gloom > HudConfig.INTRO_DIM_CAP:
				p.gloom = HudConfig.INTRO_DIM_CAP


# Round 14, the midnight stagger: asked by a person who would sink to dimmed (Person._check_level), in the order the
# people tick. Yes only once dimmed people may emerge (after the calm opening) and DIM_ARRIVAL_MIN_GAP seconds
# have passed since the last one sank. The first to ask in a frame takes the gate, so array order decides who goes.
func ask() -> bool:
	# (Nobody gets this far during the calm opening: hold_back keeps them under the line until then.)
	if clock - last_sink < NightCycle.dim_gap_at(_main.night.progress()):  # Round 23: the gap follows the night.
		return false
	last_sink = clock
	return true
