class_name PaintedGround
extends MultiMeshInstance3D

# Painted ground: a square grid of flat tiles (1 m each) just above the floor, one colour per tile.
# Tiles near rescued people take on that person's element colour, with soft edges.

var _size: int = 0
var _colors: Array[Color] = []
var _targets: Array[Color] = []
var _weights: Array[float] = []
var _timer := 0.0


# Builds the tile grid: `size` tiles along each side, centred on the origin.
func setup(size: int) -> void:
	_size = size
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
			i += 1
	multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	material_override = mat


# Call every frame. Repaints the target colours every GROUND_UPDATE_INTERVAL seconds,
# and moves each tile's colour a little toward its target every frame of that update.
func update_paint(people: Array, delta: float) -> void:
	_timer += delta
	if _timer < Config.GROUND_UPDATE_INTERVAL:
		return
	_timer = 0.0
	_paint(people)


# Works out each tile's target colour. Only tiles inside the square around each rescued person
# are checked, so this stays fast on big maps. A tile keeps the most painted (nearest) person.
func _paint(people: Array) -> void:
	var count := _size * _size
	for i: int in range(count):
		_targets[i] = Config.GROUND_GREY
		_weights[i] = 0.0

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
				var k := Config.GROUND_PAINT_STRENGTH * (1.0 - smoothstep(r * 0.6, r, d))
				var idx := ix * _size + iz
				if k > _weights[idx]:
					_weights[idx] = k
					_targets[idx] = Config.GROUND_GREY.lerp(paint_col, k)

	var mm := multimesh
	for i: int in range(count):
		var current: Color = _colors[i]
		var next: Color = current.lerp(_targets[i], Config.GROUND_PAINT_SPEED)
		_colors[i] = next
		mm.set_instance_color(i, next)
