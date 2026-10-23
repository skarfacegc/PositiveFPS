class_name PaintedGround
extends MultiMeshInstance3D

# Painted ground: a square grid of flat tiles (1 m each) just above the floor, one colour per tile.
# Tiles near rescued people take on that person's element colour, with soft edges.
# Each tile also has a paint weight from 0 (unpainted) to 1 (fully painted). Top-down mode reads it as cover.

var _size: int = 0
var _colors: Array[Color] = []
var _targets: Array[Color] = []
var _weights: Array[float] = []
var _target_weights: Array[float] = []
var _spread_speed: float = Config.GROUND_PAINT_SPEED
var _fade_speed: float = Config.GROUND_PAINT_SPEED
var _timer := 0.0


# Builds the tile grid: `size` tiles along each side, centred on the origin. Tiles move toward their target at
# `spread_speed` while they are getting more painted and at `fade_speed` while they are fading back (per update).
func setup(
	size: int, spread_speed: float = Config.GROUND_PAINT_SPEED, fade_speed: float = Config.GROUND_PAINT_SPEED
) -> void:
	_size = size
	_spread_speed = spread_speed
	_fade_speed = fade_speed
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
# Returns 0 when no tile is in range.
func average_weight(world_pos: Vector3, radius: float) -> float:
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
			total += _weights[ix * _size + iz]
			count += 1
	if count == 0:
		return 0.0
	return total / count


# Works out each tile's target colour and target weight. Only tiles inside the square around each rescued person
# are checked, so this stays fast on big maps. A tile keeps the most painted (nearest) person.
func _paint(people: Array) -> void:
	var count := _size * _size
	for i: int in range(count):
		_targets[i] = Config.GROUND_GREY
		_target_weights[i] = 0.0

	var half := _size / 2.0
	var r := Config.ZONE_RADIUS
	for p: Person in people:
		if not p.is_rescued:
			continue
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
				var idx := ix * _size + iz
				if k > _target_weights[idx]:
					_target_weights[idx] = k
					_targets[idx] = Config.GROUND_GREY.lerp(paint_col, Config.GROUND_PAINT_STRENGTH * k)

	var mm := multimesh
	for i: int in range(count):
		# Painting in uses the spread speed; fading back uses the fade speed.
		var rate := _spread_speed if _target_weights[i] > _weights[i] else _fade_speed
		_weights[i] = lerpf(_weights[i], _target_weights[i], rate)
		var next: Color = _colors[i].lerp(_targets[i], rate)
		_colors[i] = next
		mm.set_instance_color(i, next)
