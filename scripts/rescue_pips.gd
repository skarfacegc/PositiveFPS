class_name RescuePips
extends RefCounted

# Walls and gates: Rescues pull the line (#11). A rescued person who belongs to a cell next to the zone (the cell
# their ground point is nearest to) fills one of that cell's pips. Grid fixes (#10): a cell never joins by itself. At
# BorderConfig.TAKE_RESCUES the cell is ready, and taking it with E is free (TakeBlock); any other cell costs spirit.
# Pips of a cell that joins, or stops being next to the zone, are cleared. `version` goes up on every change, so the
# look can tell when to redraw.

# The recorder listens: a pip was filled (`pips` now on `cell`) and a cell's pips just filled up (`cell_ready`).
signal pip_added(cell: Vector2i, pips: int)
signal cell_ready(cell: Vector2i)

# Cell -> pips filled (0 to TAKE_RESCUES).
var counts: Dictionary = {}
var version: int = 0


# A rescued person was made at ground point `pos`: the cell they belong to fills a pip (when it is next to the zone).
func on_rescue(zone: Zone, pos: Vector3) -> void:
	var cell := TownGrid.cell_of(pos)
	if not zone.can_take(cell):
		prune(zone)
		return
	var was := filled(cell)
	var now := mini(was + 1, BorderConfig.TAKE_RESCUES)
	counts[cell] = now
	version += 1
	pip_added.emit(cell, now)
	if now >= BorderConfig.TAKE_RESCUES and was < BorderConfig.TAKE_RESCUES:
		cell_ready.emit(cell)
	prune(zone)


# Clears the pips of every cell that is held now or is no longer next to the zone.
func prune(zone: Zone) -> void:
	for key: Variant in counts.keys():
		var cell: Vector2i = key
		if zone.has(cell) or not zone.can_take(cell):
			counts.erase(cell)
			version += 1


# Walls and gates: Pressure (#13). A cell the gloom took starts again: its pips go back to 0.
func reset(cell: Vector2i) -> void:
	if counts.has(cell):
		counts.erase(cell)
		version += 1


# The pips filled on `cell` (0 when none).
func filled(cell: Vector2i) -> int:
	var have: int = counts.get(cell, 0)
	return have


# True when `cell` has all its pips: taking it with E is free.
func is_ready(cell: Vector2i) -> bool:
	return filled(cell) >= BorderConfig.TAKE_RESCUES
