class_name RescuePips
extends RefCounted

# Walls and gates: Rescues pull the line (#11). A rescued person who belongs to a cell next to the zone (the cell
# their ground point is nearest to) fills one of that cell's pips. At BorderConfig.TAKE_RESCUES the cell joins the zone
# by itself (Zone.take), without E, when its preview is valid. Pips of a cell that joins, or stops being next to the
# zone, are cleared. `version` goes up on every change, so the look can tell when to redraw.

# Cell -> pips filled (0 to TAKE_RESCUES).
var counts: Dictionary = {}
var version: int = 0


# A rescued person was made at ground point `pos`. Returns the cells that joined the zone (empty when none).
func on_rescue(zone: Zone, pos: Vector3) -> Array[Vector2i]:
	var joined: Array[Vector2i] = []
	var cell := TownGrid.cell_of(pos)
	if not zone.can_take(cell):
		prune(zone)
		return joined
	var now := mini(filled(cell) + 1, BorderConfig.TAKE_RESCUES)
	counts[cell] = now
	version += 1
	if now >= BorderConfig.TAKE_RESCUES and _can_join(zone, cell):
		joined = zone.take(cell)
		counts.erase(cell)
		version += 1
	prune(zone)
	return joined


# Clears the pips of every cell that is held now or is no longer next to the zone.
func prune(zone: Zone) -> void:
	for key: Variant in counts.keys():
		var cell: Vector2i = key
		if zone.has(cell) or not zone.can_take(cell):
			counts.erase(cell)
			version += 1


# The pips filled on `cell` (0 when none).
func filled(cell: Vector2i) -> int:
	var have: int = counts.get(cell, 0)
	return have


# True when taking `cell` now is a valid take (Zone.preview).
func _can_join(zone: Zone, cell: Vector2i) -> bool:
	var pv: Dictionary = zone.preview(cell, true)
	var valid: bool = pv["valid"]
	return valid
