class_name Plaza
extends RefCounted

# The plaza: the floor and walls (collision only; the looks draw them), the obstacle blocks and the landmark blocks, and
# where people may stand. Owns the level's seeded random numbers (spawn spots, then the crowd's wandering).
# TopDownMain builds it as `plaza`.

# Walls and gates: Grid (0.4, #55). The twenty built blocks are the cells of the town grid (TownGrid) that are not the
# start square or a landmark square: each is a 12 x 3 x 12 solid block (a tight group of houses filling its cell), and
# the streets between them are 10 m wide. The centres are TownGrid.cell_centre of TownGrid.block_cells(), row by row
# (a test keeps this list and the grid in step).
const BLOCK_SIZE := Vector3(12, 3, 12)
const BLOCK_POSITIONS: Array[Vector3] = [
	Vector3(-44, 1.5, -44),
	Vector3(-22, 1.5, -44),
	Vector3(0, 1.5, -44),
	Vector3(22, 1.5, -44),
	Vector3(44, 1.5, -44),
	Vector3(-44, 1.5, -22),
	Vector3(0, 1.5, -22),
	Vector3(44, 1.5, -22),
	Vector3(-44, 1.5, 0),
	Vector3(-22, 1.5, 0),
	Vector3(22, 1.5, 0),
	Vector3(44, 1.5, 0),
	Vector3(-44, 1.5, 22),
	Vector3(0, 1.5, 22),
	Vector3(44, 1.5, 22),
	Vector3(-44, 1.5, 44),
	Vector3(-22, 1.5, 44),
	Vector3(0, 1.5, 44),
	Vector3(22, 1.5, 44),
	Vector3(44, 1.5, 44),
]
const BLOCK_COLOUR := Color(0.6, 0.6, 0.62)

var rng := RandomNumberGenerator.new()
var obstacles: Array[StaticBody3D] = []
var landmark_bodies: Array[StaticBody3D] = []
var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


# Floor, walls, blocks and landmark blocks, with the plaza look.
func build() -> void:
	var side := float(Config.TD_PLAZA_SIZE)
	var wall_at := side / 2.0 + 0.5

	# Floor: top surface at y = 0. The plaza look draws the floor and the walls; the bodies here are the collision.
	_main.add_child(make_body(Vector3(side, 1, side), Vector3(0, -0.5, 0)))

	# Walls around the edge.
	_main.add_child(make_body(Vector3(side + 2, 3, 1), Vector3(0, 1.5, -wall_at)))
	_main.add_child(make_body(Vector3(side + 2, 3, 1), Vector3(0, 1.5, wall_at)))
	_main.add_child(make_body(Vector3(1, 3, side + 2), Vector3(-wall_at, 1.5, 0)))
	_main.add_child(make_body(Vector3(1, 3, side + 2), Vector3(wall_at, 1.5, 0)))
	make_look()

	# Obstacle blocks. Each one is drawn by its Building's look (see Border.register_building).
	for pos: Vector3 in BLOCK_POSITIONS:
		var block := make_body(BLOCK_SIZE, pos)
		_main.add_child(block)
		obstacles.append(block)

	# The landmarks (round 19: three): blocks of their own height, far from the start.
	for k: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
		var at := LandmarkConfig.LANDMARK_POSITIONS[k]
		var lm_size := LandmarkConfig.LANDMARK_SIZES[k]
		var lm_body := make_body(lm_size, Vector3(at.x, lm_size.y / 2.0, at.z))
		_main.add_child(lm_body)
		obstacles.append(lm_body)
		landmark_bodies.append(lm_body)


# The floor and walls look for the current look mode (also called when F4 flips the look).
func make_look() -> void:
	_main.plaza_look = Looks.plaza_look()
	_main.add_child(_main.plaza_look)
	_main.plaza_look.setup(float(Config.TD_PLAZA_SIZE))


# Gives the border every block (and landmark block) it can beautify.
func register_buildings(border: Border) -> void:
	for body: StaticBody3D in obstacles:
		var lm_index := landmark_bodies.find(body)
		var is_landmark := lm_index >= 0
		var size := LandmarkConfig.LANDMARK_SIZES[lm_index] if is_landmark else BLOCK_SIZE
		var colour := LandmarkConfig.LANDMARK_COLOURS[lm_index] if is_landmark else BLOCK_COLOUR
		border.register_building(body, Vector2(size.x, size.z) * 0.5, is_landmark, size, colour)


# Creates a static body with a box collision shape (the drawing is done by looks).
static func make_body(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


# Makes the people (TD_PEOPLE_COUNT of them, on seeded spots) and hooks them to the level's events and gates.
func spawn_people() -> void:
	rng.seed = Config.RNG_SEED
	var placed: Array[Vector3] = []
	var events := _main.events
	for i: int in range(Config.TD_PEOPLE_COUNT):
		var pos := find_spot(placed)
		placed.append(pos)

		var p: Person = Person.new()
		p.affinity = i % 3
		p.look_seed = i
		p.gloom = rng.randf_range(PeopleConfig.GLOOM_START_MIN, PeopleConfig.GLOOM_START_MAX)
		p.position = pos
		p.ui_scale = PlayerConfig.TD_UI_SCALE
		p.grace_seconds = PeopleConfig.TD_RESCUE_GRACE_SECONDS
		_main.add_child(p)
		p.rescued.connect(events.on_person_rescued.bind(p))
		p.relapsed.connect(events.on_person_relapsed.bind(p))
		p.stage_changed.connect(events.on_stage_changed.bind(p))
		p.dim_gate = _main.dim_gate.ask
		p.relapse_gate = _main.relapse_wave.allow
		_main.people.append(p)


# Tries up to 200 random spots inside the plaza and returns the first that is clear of the
# centre, the blocks and the other people. If none is found, returns the last try.
func find_spot(placed: Array[Vector3]) -> Vector3:
	var limit := Config.TD_PLAZA_SIZE / 2.0 - PeopleConfig.TD_SPAWN_EDGE
	var candidate := Vector3.ZERO
	for attempt: int in range(200):
		candidate = Vector3(rng.randf_range(-limit, limit), 0.0, rng.randf_range(-limit, limit))
		if spot_ok(candidate, placed):
			return candidate
	return candidate


func spot_ok(p: Vector3, placed: Array[Vector3]) -> bool:
	if flat_dist(p, Vector3.ZERO) < PeopleConfig.TD_SPAWN_CENTRE_CLEAR:
		return false
	if near_block(p, PeopleConfig.TD_BLOCK_CLEARANCE):
		return false
	for other: Vector3 in placed:
		if flat_dist(p, other) < PeopleConfig.TD_SPAWN_SPACING:
			return false
	return true


# True if `p` is inside any block's footprint (the landmark included), grown by `margin` metres.
func near_block(p: Vector3, margin: float) -> bool:
	var reach := BLOCK_SIZE.x * 0.5 + margin
	for block: Vector3 in BLOCK_POSITIONS:
		if absf(p.x - block.x) < reach and absf(p.z - block.z) < reach:
			return true
	for k: int in range(LandmarkConfig.LANDMARK_POSITIONS.size()):
		var lm := LandmarkConfig.LANDMARK_POSITIONS[k]
		var lm_reach := LandmarkConfig.LANDMARK_SIZES[k].x * 0.5 + margin
		if absf(p.x - lm.x) < lm_reach and absf(p.z - lm.z) < lm_reach:
			return true
	return false


# Distance between two points, ignoring height.
static func flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
