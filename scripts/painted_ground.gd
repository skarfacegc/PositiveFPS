class_name PaintedGround
extends MultiMeshInstance3D

# Painted ground: a square grid of flat tiles (1 m each) just above the floor, one colour per tile.
# Tiles near rescued people take on that person's element colour, with soft edges.
# Each tile also has a paint weight from 0 (unpainted) to 1 (fully painted). Top-down mode reads it as cover.
#
# Round 8: each tile remembers who painted it hardest (_top_owner) and the hardest paint from anyone else
# (_other_weights). That lets average_weight_excluding leave a person's own paint out of their cover. With `erodes`
# on (top-down), unrescued dark people take paint off the edge of the territory (see _erode).

# True when darkness erodes paint (top-down only). First person leaves it off.
var erodes: bool = false

var _size: int = 0
var _colors: Array[Color] = []
var _targets: Array[Color] = []
var _weights: Array[float] = []
# The strongest paint target on each tile, and the instance id of the rescued person behind it (0 = nobody).
var _target_weights: Array[float] = []
var _top_owner: Array[int] = []
# The strongest paint target on each tile from a rescued person other than _top_owner.
var _other_weights: Array[float] = []
# Seconds left before paint can regrow on each tile (set when darkness erodes it).
var _hold: Array[float] = []
# Tile centres on the territory edge, rebuilt with the targets (see _paint).
var _edge_points: Array[Vector3] = []
var _spread_speed: float = Config.GROUND_PAINT_SPEED
var _fade_speed: float = Config.GROUND_PAINT_SPEED
var _timer := 0.0


# Builds the tile grid: `size` tiles along each side, centred on the origin. Tiles move toward their target at
# `spread_speed` while they are getting more painted and at `fade_speed` while they are fading back (per update).
func setup(
	size: int,
	spread_speed: float = Config.GROUND_PAINT_SPEED,
	fade_speed: float = Config.GROUND_PAINT_SPEED,
	erodes_paint: bool = false
) -> void:
	_size = size
	_spread_speed = spread_speed
	_fade_speed = fade_speed
	erodes = erodes_paint
	var count := size * size
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = count
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	mm.mesh = plane

	var half := size / 2.0
	var i := 0
	for ix: int in range(size):
		for iz: int in range(size):
			var c := Vector3(-half + 0.5 + ix, 0.01, -half + 0.5 + iz)
			mm.set_instance_transform(i, Transform3D(Basis(), c))
			mm.set_instance_color(i, Config.GROUND_GREY)
			_colors.append(Config.GROUND_GREY)
			_targets.append(Config.GROUND_GREY)
			_weights.append(0.0)
			_target_weights.append(0.0)
			_top_owner.append(0)
			_other_weights.append(0.0)
			_hold.append(0.0)
			i += 1
	multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	material_override = mat


# Call every frame. Repaints the target colours every GROUND_UPDATE_INTERVAL seconds,
# and moves each tile's colour and weight a little toward its target every frame of that update.
func update_paint(people: Array, delta: float) -> void:
	_timer += delta
	if _timer < Config.GROUND_UPDATE_INTERVAL:
		return
	_timer = 0.0
	_paint(people)


# The paint weight (0 to 1) of the tile under `world_pos`. Positions off the grid have no paint (0).
func paint_weight_at(world_pos: Vector3) -> float:
	var half := _size / 2.0
	var ix := floori(world_pos.x + half)
	var iz := floori(world_pos.z + half)
	if ix < 0 or iz < 0 or ix >= _size or iz >= _size:
		return 0.0
	return _weights[ix * _size + iz]


# The average paint weight of the tiles whose centres are within `radius` metres of `world_pos` (flat distance).
# Returns 0 when no tile is in range. This counts everyone's paint (used for unrescued people).
func average_weight(world_pos: Vector3, radius: float) -> float:
	return _average(world_pos, radius, 0)


# Like average_weight, but leaves out the paint that `exclude` made (round 8: a rescued person's own paint does not
# protect them). For each tile the weight is min(current weight, the strongest paint from the other rescued people),
# so the slow ground still matters: a tile only counts while it is painted now and someone else's paint is there.
# Tiles that only `exclude` painted count as 0.
func average_weight_excluding(world_pos: Vector3, radius: float, exclude: Person) -> float:
	return _average(world_pos, radius, exclude.get_instance_id())


# True when some tile is on the territory edge (see _paint). Dark people with no one to chase walk there.
func has_edge() -> bool:
	return not _edge_points.is_empty()


# The edge tile centre nearest to `from` (ground distance). Returns `from` itself when there is no edge.
func nearest_edge_point(from: Vector3) -> Vector3:
	var best := from
	var best_d := INF
	for pt: Vector3 in _edge_points:
		var d := Vector2(pt.x - from.x, pt.z - from.z).length()
		if d < best_d:
			best_d = d
			best = pt
	return best


# Shared body of average_weight and average_weight_excluding. `owner_id` 0 means leave nobody out.
func _average(world_pos: Vector3, radius: float, owner_id: int) -> float:
	var half := _size / 2.0
	var reach := ceili(radius) + 1
	var cx := floori(world_pos.x + half)
	var cz := floori(world_pos.z + half)
	var total := 0.0
	var count := 0
	for ix: int in range(cx - reach, cx + reach + 1):
		for iz: int in range(cz - reach, cz + reach + 1):
			if ix < 0 or iz < 0 or ix >= _size or iz >= _size:
				continue
			var c := Vector2(-half + 0.5 + ix - world_pos.x, -half + 0.5 + iz - world_pos.z)
			if c.length() > radius:
				continue
			var idx := ix * _size + iz
			if owner_id == 0:
				total += _weights[idx]
			else:
				var others: float = _other_weights[idx] if _top_owner[idx] == owner_id else _target_weights[idx]
				total += minf(_weights[idx], others)
			count += 1
	if count == 0:
		return 0.0
	return total / count


# Works out each tile's target colour and target weight. Only tiles inside the square around each rescued person
# are checked, so this stays fast on big maps. A tile keeps the most painted (nearest) person's colour.
func _paint(people: Array) -> void:
	var count := _size * _size
	for i: int in range(count):
		_targets[i] = Config.GROUND_GREY
		_target_weights[i] = 0.0
		_top_owner[i] = 0
		_other_weights[i] = 0.0

	var half := _size / 2.0
	var r := Config.ZONE_RADIUS
	for p: Person in people:
		if not p.is_rescued:
			continue
		var owner := p.get_instance_id()
		var pos: Vector3 = p.global_position
		var paint_col: Color = Config.ELEMENT_COLORS[p.affinity]
		var x_min := clampi(floori(pos.x + half - r) - 1, 0, _size - 1)
		var x_max := clampi(floori(pos.x + half + r) + 1, 0, _size - 1)
		var z_min := clampi(floori(pos.z + half - r) - 1, 0, _size - 1)
		var z_max := clampi(floori(pos.z + half + r) + 1, 0, _size - 1)
		for ix: int in range(x_min, x_max + 1):
			for iz: int in range(z_min, z_max + 1):
				var c := Vector3(-half + 0.5 + ix, 0.0, -half + 0.5 + iz)
				var d := Vector2(c.x - pos.x, c.z - pos.z).length()
				if d > r:
					continue
				var k := 1.0 - smoothstep(r * 0.6, r, d)
				_add_contribution(ix * _size + iz, owner, k, paint_col)

	var interval := Config.GROUND_UPDATE_INTERVAL
	for i: int in range(count):
		_hold[i] = maxf(0.0, _hold[i] - interval)
	if erodes:
		_erode(people)
	for i: int in range(count):
		# A held tile cannot grow: its target is capped at what it has now (its colour fades toward grey with it).
		if _hold[i] > 0.0:
			var before := _target_weights[i]
			_target_weights[i] = minf(before, _weights[i])
			var ratio := clampf(_weights[i] / maxf(before, 0.001), 0.0, 1.0)
			_targets[i] = Config.GROUND_GREY.lerp(_targets[i], ratio)

	var mm := multimesh
	for i: int in range(count):
		# Painting in uses the spread speed; fading back uses the fade speed.
		var rate := _spread_speed if _target_weights[i] > _weights[i] else _fade_speed
		_weights[i] = lerpf(_weights[i], _target_weights[i], rate)
		var next: Color = _colors[i].lerp(_targets[i], rate)
		_colors[i] = next
		mm.set_instance_color(i, next)
	_rebuild_edge()


# Records one rescued person's paint strength `k` on tile `idx`. The strongest sets the tile's colour and target
# weight; the strongest from anyone else is kept in _other_weights, so their paint can be left out later.
# Each rescued person calls this at most once per tile in a paint update, so an owner never meets itself here.
func _add_contribution(idx: int, owner: int, k: float, paint_col: Color) -> void:
	if k > _target_weights[idx]:
		_other_weights[idx] = _target_weights[idx]
		_target_weights[idx] = k
		_top_owner[idx] = owner
		_targets[idx] = Config.GROUND_GREY.lerp(paint_col, Config.GROUND_PAINT_STRENGTH * k)
	elif k > _other_weights[idx]:
		_other_weights[idx] = k


# Darkness erodes paint (top-down only). Each unrescued dark person takes TD_ERODE_RATE weight per second off the
# edge tiles within TD_ERODE_RADIUS of them, and an eroded tile is held for TD_ERODE_HOLD seconds (see _paint).
# Deep interior tiles are immune. Tiles are checked before any are changed, so the order of people does not matter.
func _erode(people: Array) -> void:
	var r := Config.TD_ERODE_RADIUS
	var half := _size / 2.0
	var seen: Dictionary = {}
	var to_erode: Array[int] = []
	for p: Person in people:
		if not GloomSim.is_dark(p):
			continue
		var pos: Vector3 = p.global_position
		var x_min := clampi(floori(pos.x + half - r), 0, _size - 1)
		var x_max := clampi(floori(pos.x + half + r), 0, _size - 1)
		var z_min := clampi(floori(pos.z + half - r), 0, _size - 1)
		var z_max := clampi(floori(pos.z + half + r), 0, _size - 1)
		for ix: int in range(x_min, x_max + 1):
			for iz: int in range(z_min, z_max + 1):
				var c := Vector3(-half + 0.5 + ix, 0.0, -half + 0.5 + iz)
				if Vector2(c.x - pos.x, c.z - pos.z).length() > r:
					continue
				var idx := ix * _size + iz
				if seen.has(idx) or _weights[idx] <= 0.0 or _is_interior(ix, iz):
					continue
				seen[idx] = true
				to_erode.append(idx)
	for idx: int in to_erode:
		_weights[idx] = maxf(0.0, _weights[idx] - Config.TD_ERODE_RATE * Config.GROUND_UPDATE_INTERVAL)
		_hold[idx] = Config.TD_ERODE_HOLD


# A tile is interior when it and every neighbour inside the grid are at least TD_ERODE_EDGE_MAX painted.
func _is_interior(ix: int, iz: int) -> bool:
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			var nx := ix + dx
			var nz := iz + dz
			if nx < 0 or nz < 0 or nx >= _size or nz >= _size:
				continue
			if _weights[nx * _size + nz] < Config.TD_ERODE_EDGE_MAX:
				return false
	return true


# Rebuilds the list of territory edge tiles: painted, but not fully (weight between TD_EDGE_MIN and EDGE_MAX).
func _rebuild_edge() -> void:
	_edge_points.clear()
	var half := _size / 2.0
	for ix: int in range(_size):
		for iz: int in range(_size):
			var w := _weights[ix * _size + iz]
			if w > Config.TD_EDGE_MIN and w < Config.TD_ERODE_EDGE_MAX:
				_edge_points.append(Vector3(-half + 0.5 + ix, 0.0, -half + 0.5 + iz))
