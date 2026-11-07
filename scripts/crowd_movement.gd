class_name CrowdMovement
extends RefCounted

# Moves the unrescued people each frame (wander, pursuit, separation, the dimmed reach for the player). Moved out of
# topdown_main.gd in round 24; TopDownMain keeps thin wrappers for pursuit_assignments and _new_wander_target. The
# random numbers come from the level's _rng so the walk stays the same as before the move.

var main: TopDownMain
# Round 26: switches back to the all-pairs separation (for tests).
var brute_force: bool = false
# Wander state for each person: a Dictionary of {"target": Vector3, "timer": float}.
var _wander: Dictionary = {}
# Round 26: the separation grid. People are indexed by their place in `main.people`; a cell holds the indices of the
# people in it (cell size TD_SEPARATION_RADIUS).
var _cells: Dictionary = {}
var _cell_of: Array[Vector2i] = []
var _index: Dictionary = {}
var _grid_live: bool = false


func _init(level: TopDownMain) -> void:
	main = level


# Moves every unrescued person for this frame. Dimmed people drift toward the rescued person they are assigned to
# (see pursuit_assignments). A dimmed person with nobody to chase drifts to the nearest territory edge, and everyone
# else wanders. Everyone also steers away from close neighbours (_separation). Rescued people are moved by the border.
func update_people(delta: float) -> void:
	rebuild_grid()  # Round 26: the separation grid (see _separation).
	var pursuit: Dictionary = pursuit_assignments(main.people)
	for p: Person in main.people:
		p.shooter_pos = main.player.global_position  # Round 17: the guarded wedge asks whether a shot from here would land.
		if p.is_rescued:
			continue
		if main.grabs.is_grabbing(p):
			continue  # A grabber stands still through the wind-up and the lunge.
		if main.moods.is_fleeing(p):
			# Round 12b: a scared skittish person backs away.
			_step(p, main.moods.flee_dir(p), Config.SKITTISH_FLEE_SPEED, delta)
			continue
		if _reaches_for_player(p):
			var to_player: Vector3 = main.player.global_position - p.global_position
			to_player.y = 0.0
			var toward := Vector3.ZERO
			if to_player.length() > Config.GRAB_RANGE * 0.8:
				toward = to_player.normalized()
			_steer(p, toward, Config.TD_DIMMED_DRIFT_SPEED, delta)
		elif pursuit.has(p):
			var target_p: Person = pursuit[p]
			var to: Vector3 = target_p.global_position - p.global_position
			to.y = 0.0
			var desired := Vector3.ZERO
			if to.length() > _stop_distance(p, target_p):
				desired = to.normalized()
			_steer(p, desired, Config.TD_DIMMED_DRIFT_SPEED, delta)
		elif GloomSim.is_dimmed(p) and main.ground.has_edge():
			var to_edge: Vector3 = main.ground.nearest_edge_point(p.global_position) - p.global_position
			to_edge.y = 0.0
			var edge_desired := Vector3.ZERO
			if to_edge.length() > Config.TD_EDGE_REACH:
				edge_desired = to_edge.normalized()
			_steer(p, edge_desired, Config.TD_DIMMED_DRIFT_SPEED, delta)
		else:
			_steer(p, _wander_dir(p, delta), Config.TD_WANDER_SPEED, delta)
	_grid_live = false  # Positions change elsewhere before the next frame; a standalone _separation rebuilds the grid.


# How close a pursuing dimmed person walks to their target: right up to the line when they are outside the border and
# the target is a border member (they press it, Round 12b), otherwise TD_DIMMED_STOP_DISTANCE.
func _stop_distance(p: Person, target_p: Person) -> float:
	if main.border.active and main.border.members.has(target_p):
		if not BorderShape.is_inside(main.border.polygon, Vector2(p.position.x, p.position.z)):
			return Config.TD_DIMMED_PRESS_STOP
	return Config.TD_DIMMED_STOP_DISTANCE


# Round 12a: a dimmed person who notices a player that is not dim (within GRAB_NOTICE_RANGE) drifts toward them to grab.
# Dimmed people ignore a dim player and go back to pressing the border.
func _reaches_for_player(p: Person) -> bool:
	if not GloomSim.is_dimmed(p) or main.player.is_dim or not main.player.active:
		return false
	return main._flat_dist(p.global_position, main.player.global_position) <= Config.GRAB_NOTICE_RANGE


# Works out which rescued person each dimmed person drifts toward (the weakest point). Each rescued person takes at most
# TD_MAX_PURSUERS_PER_TARGET dimmed people. A dimmed person takes the rescued person with the lowest protection within
# TD_PURSUIT_SEARCH_RADIUS (ties go to the nearer one). People are handled in array order, so the result is the same on
# every run. Returns a Dictionary of dimmed Person -> rescued Person. A dimmed person with no target is not in it.
func pursuit_assignments(list: Array[Person]) -> Dictionary:
	var rescued_list: Array[Person] = []
	for p: Person in list:
		if p.is_rescued:
			rescued_list.append(p)
	var slots: Dictionary = {}
	var out: Dictionary = {}
	for p: Person in list:
		if not GloomSim.is_dimmed(p):
			continue
		var best := _weakest_with_slot(p.global_position, rescued_list, slots)
		if best != null:
			out[p] = best
			var used: int = slots.get(best, 0)
			slots[best] = used + 1
	return out


# The rescued person a dimmed person at `pos` goes for: the lowest protection within TD_PURSUIT_SEARCH_RADIUS that
# still has a free pursuer slot (see pursuit_assignments). Ties go to the nearest. Null if there is none.
func _weakest_with_slot(pos: Vector3, rescued_list: Array[Person], slots: Dictionary) -> Person:
	var best: Person = null
	var best_u := -INF
	for r: Person in rescued_list:
		var used: int = slots.get(r, 0)
		if used >= Config.TD_MAX_PURSUERS_PER_TARGET:
			continue
		var d := main._flat_dist(pos, r.global_position)
		if d > Config.TD_PURSUIT_SEARCH_RADIUS:
			continue
		# Round 12b, edge pressure: among equally exposed people the newest and outermost stretch of the border is
		# worth EDGE_PRESSURE_REACH metres of walking; with no border this is plain distance.
		var u := main.border.edge_pressure(r.global_position) * Config.EDGE_PRESSURE_REACH - d
		if best == null or r.protection < best.protection - Config.EDGE_PROTECTION_TIE:
			best = r
			best_u = u
		elif absf(r.protection - best.protection) <= Config.EDGE_PROTECTION_TIE and u > best_u:
			best = r
			best_u = u
	return best


# Returns the flat direction a wandering person walks in this frame, or zero if they are standing still.
# They pick a new spot when they arrive or their time is up.
func _wander_dir(p: Person, delta: float) -> Vector3:
	if not _wander.has(p):
		_wander[p] = {"target": p.global_position, "timer": 0.0}
	var st: Dictionary = _wander[p]
	st["timer"] = st["timer"] - delta
	var here: Vector3 = p.global_position
	var to: Vector3 = st["target"] - here
	to.y = 0.0
	if st["timer"] <= 0.0 or to.length() <= Config.TD_WANDER_REACH:
		st["target"] = new_wander_target(here)
		st["timer"] = main._rng.randf_range(Config.TD_WANDER_TIME_MIN, Config.TD_WANDER_TIME_MAX)
		to = st["target"] - here
		to.y = 0.0
	if to.length() > 0.01:
		return to.normalized()
	return Vector3.ZERO


# Moves a person along `desired` (a flat direction, or zero to stand still) plus the push away from neighbours.
# The push is added before normalising, so the step is always speed * delta long and the speed cap holds.
func _steer(p: Person, desired: Vector3, speed: float, delta: float) -> void:
	var want := desired + _separation(p) * Config.TD_SEPARATION_STRENGTH
	want.y = 0.0
	if want.length() < 0.001:
		return
	_step(p, want.normalized(), speed, delta)


# The push away from each person within TD_SEPARATION_RADIUS: one unit of push per neighbour, away from it. A constant
# push (not a falloff) is stronger than a wander step, so people settle at about the radius apart instead of drifting
# back together. Two people standing exactly on the same spot are split by array order: the earlier one is pushed
# right, the later one left.
func _separation(p: Person) -> Vector3:
	var my_index: int = _index.get(p, -1)
	if brute_force or not _grid_live or my_index < 0:
		return separation_brute(p)  # No grid built for this frame (a standalone call): the reference version.
	# Round 26: only the neighbours in the nine cells around p are looked at, in array order (so the sum is added up in
	# the same order as the brute-force version and the result is identical).
	var near := _near_indices(p.global_position)
	var push := Vector3.ZERO
	for i: int in near:
		if i == my_index:
			continue
		push += _push_from(p, main.people[i], my_index, i)
	return push


# Round 26: the reference version (every person against every other, `people.find` for the index). Kept so a test can
# check the grid gives the same answer, and as the `brute_force` switch.
func separation_brute(p: Person) -> Vector3:
	var push := Vector3.ZERO
	var people := main.people
	var my_index := people.find(p)
	for i: int in range(people.size()):
		var q: Person = people[i]
		if q == p:
			continue
		push += _push_from(p, q, my_index, i)
	return push


# The push on `p` (index `my_index`) from `q` (index `i`): one unit away from q when q is inside TD_SEPARATION_RADIUS
# and the pair do not loom; zero otherwise.
func _push_from(p: Person, q: Person, my_index: int, i: int) -> Vector3:
	var diff: Vector3 = p.global_position - q.global_position
	diff.y = 0.0
	var d := diff.length()
	if d >= Config.TD_SEPARATION_RADIUS:
		return Vector3.ZERO
	if _may_loom(p, q):
		return Vector3.ZERO
	if d < 0.001:
		diff = Vector3.RIGHT if my_index < i else Vector3.LEFT
	return diff.normalized()


func _cell_key(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / Config.TD_SEPARATION_RADIUS), floori(pos.z / Config.TD_SEPARATION_RADIUS))


# Round 26: builds the grid (cell size = the separation radius) and the person -> index cache from the positions now.
func rebuild_grid() -> void:
	_cells.clear()
	_index.clear()
	_cell_of.clear()
	for i: int in range(main.people.size()):
		var q: Person = main.people[i]
		var key := _cell_key(q.global_position)
		_index[q] = i
		_cell_of.append(key)
		if not _cells.has(key):
			_cells[key] = PackedInt32Array()
		var list: PackedInt32Array = _cells[key]
		list.append(i)
		_cells[key] = list
	_grid_live = true


# Called after a person moves: puts them in their new cell.
func _regrid(p: Person) -> void:
	var i: int = _index.get(p, -1)
	if i < 0 or not _grid_live:
		return
	var key := _cell_key(p.global_position)
	if key == _cell_of[i]:
		return
	var old: PackedInt32Array = _cells[_cell_of[i]]
	old.remove_at(old.find(i))
	_cells[_cell_of[i]] = old
	if not _cells.has(key):
		_cells[key] = PackedInt32Array()
	var list: PackedInt32Array = _cells[key]
	list.append(i)
	_cells[key] = list
	_cell_of[i] = key


# The indices of the people in the nine cells round `pos`, in ascending (array) order.
func _near_indices(pos: Vector3) -> PackedInt32Array:
	var out := PackedInt32Array()
	var c := _cell_key(pos)
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var cell := Vector2i(c.x + dx, c.y + dz)
			if _cells.has(cell):
				var here: PackedInt32Array = _cells[cell]
				out.append_array(here)
	out.sort()
	return out


# Round 12b: a dimmed person and a wistful or gloomy one do not push each other apart, so a dimmed person can stand
# close enough (within SHELTER_RADIUS) to shelter someone. (Otherwise the crowd spacing, 2.2 m, would always undo it.)
# A dimmed person is not pushed off by a rescued member either, so they can walk up to the line and press it (the line
# itself, not the crowd spacing, holds them back; see _stop_distance).
func _may_loom(a: Person, b: Person) -> bool:
	if a.is_rescued or b.is_rescued:
		return GloomSim.is_dimmed(a) or GloomSim.is_dimmed(b)
	return GloomSim.is_dimmed(a) != GloomSim.is_dimmed(b)


# Picks a random spot within TD_WANDER_RANGE of `from`, inside the plaza and clear of blocks.
func new_wander_target(from: Vector3) -> Vector3:
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	for attempt: int in range(10):
		var angle := main._rng.randf() * TAU
		var dist := main._rng.randf() * Config.TD_WANDER_RANGE
		var c := from + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		c.x = clampf(c.x, -limit, limit)
		c.z = clampf(c.z, -limit, limit)
		if not main._near_block(c, Config.TD_BLOCK_CLEARANCE):
			return c
	return from


# Moves a person along a flat direction, keeping them inside the plaza and out of blocks, and turns them to face it.
# A dimmed person outside the border cannot cross an intact stretch: its move stops at the line (see Border.clip_move).
func _step(p: Person, dir: Vector3, speed: float, delta: float) -> void:
	var move := dir * speed * delta
	move.y = 0.0
	var next_pos: Vector3 = p.position + move
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	next_pos.x = clampf(next_pos.x, -limit, limit)
	next_pos.z = clampf(next_pos.z, -limit, limit)
	if GloomSim.is_dimmed(p):
		next_pos = main.border.clip_move(p.position, next_pos)
	if main._near_block(next_pos, Config.TD_BLOCK_CLEARANCE):
		# Blocked: make a wanderer choose a new target next time.
		if _wander.has(p):
			_wander[p]["timer"] = 0.0
		return
	p.position = next_pos
	_regrid(p)
	if p.active_mood() != Person.Mood.GUARDED:  # A guarded person keeps their back to the player (see Moods).
		p.look_at(next_pos + Vector3(dir.x, 0.0, dir.z), Vector3.UP)
