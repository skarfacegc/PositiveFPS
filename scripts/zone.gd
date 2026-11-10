class_name Zone
extends RefCounted

# Walls and gates: Grid and Line (0.4, #55, #56). The zone is the set of town cells you hold (TownGrid), plus the street
# pieces between two held cells (and the crossing where four held cells meet). It starts as the start square. Its line
# is the outline of that shape, traced exactly on the tile lattice and split into runs:
#  - a WALL runs along the face of a held built block, or along the map's edge: it holds firm and needs nobody;
#  - a GATE runs along an open side of a held square or across a street mouth: rescued people stand across it, and it
#    is the only place the gloom can push.
# The public API (the next pass builds "Take a block" and "Rescues pull the line" on it):
#   held                         the held cells, row by row
#   has(cell), can_take(cell)    is it held / may it be taken now (next to the zone, inside the grid, not held)
#   take(cell), lose(cell)       change the zone; both return the cells that changed (empty when refused)
#   preview(cell, adding)        what the change would do: the new gates, the gates it opens and closes, the members
#   gates, members_needed()      the gates of the line now (see _make_gate) and the members they need together
#   centre(), contains(pos)      the middle of the held cells; is a ground point inside the zone
# `version` goes up on every change, so a reader can tell when to rebuild.

enum Edge { WALL, GATE }

var held: Array[Vector2i] = []
var version: int = 0
# The outline of the zone, one run per straight stretch: {"a": Vector2, "b": Vector2, "gate": bool, "gate_id": int}.
# Runs follow the line clockwise (x right, z down), so the inside is to the right of a run's direction.
var runs: Array[Dictionary] = []
# The gates, in line order. {"id", "a", "b", "length", "mid", "out" (unit normal pointing outside), "key", "need"}.
var gates: Array[Dictionary] = []


func _init() -> void:
	held = [TownGrid.start_cell()]
	_rebuild()


func has(cell: Vector2i) -> bool:
	return held.has(cell)


# True when `cell` is inside the grid, not held yet, and shares a street with a held cell.
func can_take(cell: Vector2i) -> bool:
	if not TownGrid.in_grid(cell) or has(cell):
		return false
	for n: Vector2i in TownGrid.neighbours(cell):
		if has(n):
			return true
	return false


# Takes `cell`, and any cell the zone then surrounds (it joins by itself). Returns the cells added; empty when refused.
func take(cell: Vector2i) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	if not can_take(cell):
		return added
	added = _with_filled(held, cell)
	for c: Vector2i in added:
		held.append(c)
	_sort(held)
	_rebuild()
	return added


# Loses `cell` (never the start square) and any cell that is then cut off from the start. Returns the cells lost.
func lose(cell: Vector2i) -> Array[Vector2i]:
	var lost: Array[Vector2i] = []
	if not has(cell) or cell == TownGrid.start_cell():
		return lost
	var after := _without(held, cell)
	for c: Vector2i in held:
		if not after.has(c):
			lost.append(c)
	held = after
	_rebuild()
	return lost


# What taking (`adding`) or losing `cell` would do, without changing anything: {"valid", "cells" (held after), "added"
# (the cells that change), "gates" (after), "opened" (gates the change adds), "closed" (gates it removes),
# "members_needed" (all gates after), "members_added" (more members than now; negative for fewer)}.
func preview(cell: Vector2i, adding: bool = true) -> Dictionary:
	var out := {
		"valid": false,
		"cells": held.duplicate(),
		"added": [],
		"gates": gates,
		"opened": [],
		"closed": [],
		"members_needed": members_needed(),
		"members_added": 0,
	}
	var changed: Array[Vector2i] = []
	var after: Array[Vector2i] = []
	if adding:
		if not can_take(cell):
			return out
		changed = _with_filled(held, cell)
		after.assign(held)
		after.append_array(changed)
		_sort(after)
	else:
		if not has(cell) or cell == TownGrid.start_cell():
			return out
		after = _without(held, cell)
		for c: Vector2i in held:
			if not after.has(c):
				changed.append(c)
	var traced := outline(after)
	var new_gates: Array[Dictionary] = traced["gates"]
	var need := 0
	for g: Dictionary in new_gates:
		need += g["need"]
	out["valid"] = true
	out["cells"] = after
	out["added"] = changed
	out["gates"] = new_gates
	out["opened"] = _gates_not_in(new_gates, gates)
	out["closed"] = _gates_not_in(gates, new_gates)
	out["members_needed"] = need
	out["members_added"] = need - members_needed()
	return out


# The members the gates need together: each gate wants its width over BORDER_TARGET_SPACING, rounded up.
func members_needed() -> int:
	var total := 0
	for g: Dictionary in gates:
		total += g["need"]
	return total


# The middle of the held cells, on the ground.
func centre() -> Vector3:
	var sum := Vector3.ZERO
	for c: Vector2i in held:
		sum += TownGrid.cell_centre(c)
	return sum / float(maxi(held.size(), 1))


# True when the ground point `pos` lies inside the zone: on a held cell, or on a street piece or crossing it holds.
func contains(pos: Vector3) -> bool:
	var t := TownGrid.tile_of(pos)
	if absf(pos.x) > TownGrid.span() * 0.5 or absf(pos.z) > TownGrid.span() * 0.5:
		return false
	return tile_in(held, t.x, t.y)


# The ground rectangles of the open ground the zone holds (held squares first, then the street pieces and crossings),
# where the people who are not on the line stand.
func open_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for tx: int in range(TownGrid.tiles()):
		for tz: int in range(TownGrid.tiles()):
			if (tx % 2 == 0 and tz % 2 == 0) and TownGrid.is_block(Vector2i(tx >> 1, tz >> 1)):
				continue
			if tile_in(held, tx, tz):
				out.append(TownGrid.tile_rect(tx, tz))
	return out


# The gate (a Dictionary from `gates`) nearest to the ground point `pos`, or an empty Dictionary when there is none.
func nearest_gate(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d := INF
	for g: Dictionary in gates:
		var ga: Vector2 = g["a"]
		var gb: Vector2 = g["b"]
		var c := Geometry2D.get_closest_point_to_segment(pos, ga, gb)
		var d := c.distance_squared_to(pos)
		if d < best_d:
			best_d = d
			best = g
	return best


# ---- Tracing (pure: a held set in, an outline out) ----------------------------------------------------------------


# True when tile (tx, tz) belongs to the zone made of the cells `cells`.
static func tile_in(cells: Array[Vector2i], tx: int, tz: int) -> bool:
	if tx < 0 or tz < 0 or tx >= TownGrid.tiles() or tz >= TownGrid.tiles():
		return false
	var ex := tx % 2 == 0
	var ez := tz % 2 == 0
	if ex and ez:
		return cells.has(Vector2i(tx >> 1, tz >> 1))
	if not ex and ez:
		return cells.has(Vector2i(tx >> 1, tz >> 1)) and cells.has(Vector2i((tx >> 1) + 1, tz >> 1))
	if ex and not ez:
		return cells.has(Vector2i(tx >> 1, tz >> 1)) and cells.has(Vector2i(tx >> 1, (tz >> 1) + 1))
	var cx := tx >> 1
	var cz := tz >> 1
	return (
		cells.has(Vector2i(cx, cz))
		and cells.has(Vector2i(cx + 1, cz))
		and cells.has(Vector2i(cx, cz + 1))
		and cells.has(Vector2i(cx + 1, cz + 1))
	)


# The outline of the zone made of `cells`: {"runs": Array[Dictionary], "gates": Array[Dictionary]} (see the fields at
# the top). Walls and gates alternate along the line; the outer loop only (a hole the zone surrounds is not traced).
static func outline(cells: Array[Vector2i]) -> Dictionary:
	var edges: Array[Dictionary] = []
	var starts: Dictionary = {}
	for tx: int in range(TownGrid.tiles()):
		for tz: int in range(TownGrid.tiles()):
			if not tile_in(cells, tx, tz):
				continue
			var is_cell := tx % 2 == 0 and tz % 2 == 0
			var open_cell := is_cell and not TownGrid.is_block(Vector2i(tx >> 1, tz >> 1))
			# Clockwise (x right, z down): top, right, bottom, left.
			var sides: Array[Array] = [
				[Vector2i(tx, tz), Vector2i(tx + 1, tz), Vector2i(tx, tz - 1)],
				[Vector2i(tx + 1, tz), Vector2i(tx + 1, tz + 1), Vector2i(tx + 1, tz)],
				[Vector2i(tx + 1, tz + 1), Vector2i(tx, tz + 1), Vector2i(tx, tz + 1)],
				[Vector2i(tx, tz + 1), Vector2i(tx, tz), Vector2i(tx - 1, tz)],
			]
			for s: Array in sides:
				var beyond: Vector2i = s[2]
				if tile_in(cells, beyond.x, beyond.y):
					continue
				var off_map := (
					beyond.x < 0 or beyond.y < 0 or beyond.x >= TownGrid.tiles() or beyond.y >= TownGrid.tiles()
				)
				var gate := not off_map and (open_cell or not is_cell)
				var e := {"a": s[0], "b": s[1], "gate": gate, "src": is_cell}
				starts[s[0]] = starts.get(s[0], []) + [edges.size()]
				edges.append(e)
	var loop := _longest_loop(edges, starts)
	return _runs_of(edges, loop)


# The edge indexes of the loop that encloses the most area (the zone's outer line).
static func _longest_loop(edges: Array[Dictionary], starts: Dictionary) -> Array[int]:
	var used: Dictionary = {}
	var best: Array[int] = []
	var best_area := -1.0
	for first: int in range(edges.size()):
		if used.has(first):
			continue
		var loop: Array[int] = []
		var cur := first
		while cur >= 0 and not used.has(cur):
			used[cur] = true
			loop.append(cur)
			var next := -1
			var after: Array = starts.get(edges[cur]["b"], [])
			for k: int in after:
				if not used.has(k):
					next = k
					break
			cur = next
		var area := 0.0
		for k: int in loop:
			var a: Vector2i = edges[k]["a"]
			var b: Vector2i = edges[k]["b"]
			area += float(a.x) * float(b.y) - float(b.x) * float(a.y)
		if absf(area) > best_area:
			best_area = absf(area)
			best = loop
	return best


# Joins the straight, same-kind edges of a loop into runs and lists the gates among them.
static func _runs_of(edges: Array[Dictionary], loop: Array[int]) -> Dictionary:
	var runs_out: Array[Dictionary] = []
	var gates_out: Array[Dictionary] = []
	var n := loop.size()
	if n == 0:
		return {"runs": runs_out, "gates": gates_out}
	# Start at an edge that does not continue the one before it, so no run is split across the start.
	var first := 0
	for i: int in range(n):
		if not _continues(edges[loop[(i + n - 1) % n]], edges[loop[i]]):
			first = i
			break
	var a_lat: Vector2i = edges[loop[first]]["a"]
	var gate: bool = edges[loop[first]]["gate"]
	var prev: Dictionary = edges[loop[first]]
	for step: int in range(1, n + 1):
		var cur: Dictionary = edges[loop[(first + step) % n]]
		if step == n or not _continues(prev, cur):
			var end_lat: Vector2i = prev["b"]
			_close_run(runs_out, gates_out, a_lat, end_lat, gate)
			a_lat = cur["a"]
			gate = cur["gate"]
		prev = cur
	return {"runs": runs_out, "gates": gates_out}


static func _continues(e: Dictionary, f: Dictionary) -> bool:
	if e["gate"] != f["gate"] or e["src"] != f["src"]:  # A square's side and a street mouth stay separate gates.
		return false
	var ea: Vector2i = e["a"]
	var eb: Vector2i = e["b"]
	var fa: Vector2i = f["a"]
	var fb: Vector2i = f["b"]
	return (eb - ea).sign() == (fb - fa).sign()


static func _close_run(
	runs_out: Array[Dictionary], gates_out: Array[Dictionary], a_lat: Vector2i, b_lat: Vector2i, gate: bool
) -> void:
	var a := Vector2(_coord(a_lat.x), _coord(a_lat.y))
	var b := Vector2(_coord(b_lat.x), _coord(b_lat.y))
	var run := {"a": a, "b": b, "gate": gate, "gate_id": -1}
	if gate:
		run["gate_id"] = gates_out.size()
		gates_out.append(_make_gate(gates_out.size(), a, b))
	runs_out.append(run)


# A gate: id, ends a and b, length, middle, the unit normal pointing outside and the members it needs.
static func _make_gate(id: int, a: Vector2, b: Vector2) -> Dictionary:
	var dir := (b - a).normalized()
	var length := a.distance_to(b)
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y))
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y))
	return {
		"id": id,
		"a": a,
		"b": b,
		"length": length,
		"mid": (a + b) * 0.5,
		"out": Vector2(dir.y, -dir.x),  # The inside is to the right of the direction (x right, z down).
		"key": "%d,%d,%d,%d" % [roundi(lo.x * 10.0), roundi(lo.y * 10.0), roundi(hi.x * 10.0), roundi(hi.y * 10.0)],
		"need": maxi(1, ceili(length / BorderConfig.BORDER_TARGET_SPACING - 0.001)),
	}


# The ground coordinate of lattice line `i` (the start of tile i; the last line is the end of the last tile).
static func _coord(i: int) -> float:
	if i >= TownGrid.tiles():
		return TownGrid.tile_hi(TownGrid.tiles() - 1)
	return TownGrid.tile_lo(i)


static func _gates_not_in(these: Array[Dictionary], those: Array[Dictionary]) -> Array[Dictionary]:
	var keys: Dictionary = {}
	for g: Dictionary in those:
		keys[g["key"]] = true
	var out: Array[Dictionary] = []
	for g: Dictionary in these:
		if not keys.has(g["key"]):
			out.append(g)
	return out


# ---- Growing and shrinking ----------------------------------------------------------------------------------------


# `cell` and every cell that the zone with it would surround (all the neighbours of an unheld cell held, at least two of
# them): they join together.
static func _with_filled(base: Array[Vector2i], cell: Vector2i) -> Array[Vector2i]:
	var now: Array[Vector2i] = []
	now.assign(base)
	var added: Array[Vector2i] = [cell]
	now.append(cell)
	var again := true
	while again:
		again = false
		for c: Vector2i in TownGrid.all_cells():
			if now.has(c):
				continue
			var near := TownGrid.neighbours(c)  # Every cell of the grid has at least two.
			var all_held := true
			for n: Vector2i in near:
				if not now.has(n):
					all_held = false
					break
			if all_held:
				now.append(c)
				added.append(c)
				again = true
	_sort(added)
	return added


# `base` less `cell`, and less every cell that can then no longer be reached from the start square.
static func _without(base: Array[Vector2i], cell: Vector2i) -> Array[Vector2i]:
	var rest: Array[Vector2i] = []
	for c: Vector2i in base:
		if c != cell:
			rest.append(c)
	var seen: Array[Vector2i] = [TownGrid.start_cell()]
	var head := 0
	while head < seen.size():
		for n: Vector2i in TownGrid.neighbours(seen[head]):
			if rest.has(n) and not seen.has(n):
				seen.append(n)
		head += 1
	_sort(seen)
	return seen


static func _sort(list: Array[Vector2i]) -> void:
	list.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))


func _rebuild() -> void:
	var traced := outline(held)
	runs = traced["runs"]
	gates = traced["gates"]
	version += 1
