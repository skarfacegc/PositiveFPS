class_name JoyProjectile
extends Node3D

# A joy projectile for top-down mode. It has no physics body: each physics frame it steers, moves, and checks
# for a wall (a ray from where it was to where it is now, ignoring people and the player), for a person whose chest
# is in reach, and for the floor. What happens on impact depends on the element:
#   Music: a small, quick note that homes in on its target and hits; where it stops it makes a dusty-blue ring pulse
#          on the ground.
#   Art: a big paint blob, lobbed so it lands on the target's spot; it splashes people nearby and leaves a splat.
#   Nature: a flower that drifts gently toward its target; where it lands it blooms (see bloom.gd) and bursts petals.
# Each element has its own fire rate and joy per shot (Config.TD_ELEMENT_FIRE_RATE_MULT), set by the player.
# Set element, velocity, shooter_pos, target, people and ignore_rids before adding it to the scene.

const BLOB_SCALE := Vector3(1.2, 0.8, 1.2)
const FLOWER_CENTRE_COLOR := Color(1.0, 0.9, 0.3)
const FIZZLE_COLOR := Color(0.6, 0.6, 0.6)
# Every trail piece is in this group (and tagged with its element), so tests and the level can find them.
const TRAIL_GROUP := "joy_trail"
# Every impact effect left in the level (sound ring, splat, petal burst) is in this group, and tagged with its kind
# in the "impact_kind" meta ("ring", "splat" or "petals"), so tests and the level can find them.
const IMPACT_GROUP := "joy_impact"

var element: int = Config.Element.MUSIC
# How many trail pieces this projectile has left behind so far. It stops at Config.TD_TRAIL_MAX_PIECES.
var trail_pieces: int = 0
# Current flight velocity, in metres per second. Set by the player (see launch_velocity).
var velocity := Vector3.ZERO
# Where the player stood when they fired. Joy falls off with distance from here.
var shooter_pos := Vector3.ZERO
# The person this projectile was fired at. Notes and flowers steer toward them. Null means fly straight.
var target: Person = null
# Everyone who can be hit, set by the player (the same array the player uses).
var people: Array[Person] = []
# Physics objects the wall ray ignores besides people (the player's own body).
var ignore_rids: Array[RID] = []
# Seconds before the projectile fizzles if it has not hit or landed.
var lifetime: float = Config.TD_PROJECTILE_LIFETIME

var _age := 0.0
var _done := false
var _body: Node3D
var _blob: MeshInstance3D
# Seconds until the next trail piece is left behind (see _update_trail).
var _trail_timer := 0.0


# Returns the launch velocity that carries a projectile of `element` from `from` to `to`.
# Paint is lobbed so it reaches `to` after TD_PAINT_FLIGHT_TIME under gravity; notes and flowers fly straight.
static func launch_velocity(element_kind: int, from: Vector3, to: Vector3) -> Vector3:
	var offset := to - from
	if element_kind == Config.Element.ART:
		var t := Config.TD_PAINT_FLIGHT_TIME
		var g := Config.TD_PAINT_GRAVITY
		return Vector3(offset.x / t, (offset.y + 0.5 * g * t * t) / t, offset.z / t)
	var speed := Config.TD_FLOWER_SPEED if element_kind == Config.Element.NATURE else Config.TD_NOTE_SPEED
	return offset.normalized() * speed


func _ready() -> void:
	# Bigger than before, so the three elements are easier to tell apart. Hit checks use world positions, so
	# they are unchanged.
	scale = Vector3.ONE * Config.TD_PROJECTILE_VISUAL_SCALE * Config.TD_ELEMENT_VISUAL_SCALE[element]
	_body = Node3D.new()
	add_child(_body)
	if element == Config.Element.MUSIC:
		_build_music()
	elif element == Config.Element.ART:
		_build_paint()
	else:
		_build_flower()


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	var prev := global_position
	_steer(delta)
	var next := prev + velocity * delta

	var wall: Dictionary = _wall_hit(prev, next)
	if not wall.is_empty():
		var wall_pos: Vector3 = wall["position"]
		_fizzle(wall_pos)
		return
	global_position = next
	_update_trail(delta)

	var direct: Person = _person_in_reach()
	if direct != null:
		_impact(direct)
		return
	if next.y <= Config.TD_LANDING_HEIGHT:
		_land()
		return
	if _age >= lifetime:
		_fizzle(global_position)


func _process(delta: float) -> void:
	# Visual only: the note bobs side to side, the paint blob wobbles, the flower bobs and spins.
	if element == Config.Element.MUSIC:
		_body.position.x = sin(_age * Config.TD_NOTE_WAVE_SPEED) * Config.TD_PROJECTILE_BOB
	elif element == Config.Element.ART and _blob != null:
		_blob.scale = BLOB_SCALE * (1.0 + 0.12 * sin(_age * 14.0))
	elif element == Config.Element.NATURE:
		_body.position.y = sin(_age * Config.TD_FLOWER_BOB_SPEED) * Config.TD_FLOWER_BOB
		rotation.y += Config.TD_FLOWER_SPIN * delta


# Notes and flowers turn toward their target at a fixed rate. Paint only falls under gravity.
func _steer(delta: float) -> void:
	if element == Config.Element.ART:
		velocity.y -= Config.TD_PAINT_GRAVITY * delta
		return
	if not is_instance_valid(target):
		return
	var rate := Config.TD_NOTE_TURN_RATE if element == Config.Element.MUSIC else Config.TD_FLOWER_TURN_RATE
	_turn_toward(target.chest_position(), rate, delta)


# Turns the velocity toward `point` by at most `rate` radians per second. Speed stays the same.
func _turn_toward(point: Vector3, rate: float, delta: float) -> void:
	var speed := velocity.length()
	var want := point - global_position
	if speed <= 0.0 or want.length() <= 0.0001:
		return
	var dir := velocity / speed
	var want_dir := want.normalized()
	var angle := dir.angle_to(want_dir)
	var step := minf(1.0, rate * delta / maxf(angle, 0.0001))
	velocity = dir.slerp(want_dir, step) * speed


# The first wall the segment from `from` to `to` crosses, as a Dictionary (empty if none). People and the
# player are ignored, and so is the floor: landing is handled by height (see _land).
func _wall_hit(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _excluded_rids()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or _is_floor_hit(hit):
		return {}
	return hit


# True if the ray hit is the floor (an upward-facing surface at ground level).
func _is_floor_hit(hit: Dictionary) -> bool:
	var normal: Vector3 = hit["normal"]
	var pos: Vector3 = hit["position"]
	return normal.y > 0.9 and pos.y < 0.1


# Every body the wall ray must ignore: each person (they are StaticBody3D too) and the player.
func _excluded_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for rid: RID in ignore_rids:
		rids.append(rid)
	for p: Person in people:
		if is_instance_valid(p):
			rids.append(p.get_rid())
	return rids


# The first person whose chest is within TD_PROJECTILE_HIT_RADIUS of this projectile, or null.
func _person_in_reach() -> Person:
	for p: Person in people:
		if is_instance_valid(p) and p.chest_position().distance_to(global_position) <= Config.TD_PROJECTILE_HIT_RADIUS:
			return p
	return null


# Joy for one shot of this element. Notes hit half as hard as Nature, paint twice as hard (the fire rate differs).
func _shot_joy() -> float:
	return Config.TD_JOY_PER_SHOT / Config.TD_ELEMENT_FIRE_RATE_MULT[element]


# A direct hit: the person gets the joy, then the element's own impact happens where the projectile is.
func _impact(direct: Person) -> void:
	direct.receive_joy(element, _shot_joy(), _shooter_distance(direct))
	_element_impact(global_position, direct)


# Landing without a hit. Notes, paint and flowers all do their impact on the ground.
func _land() -> void:
	var ground := Vector3(global_position.x, 0.0, global_position.z)
	_element_impact(ground, null)


# What each element does where it stops: music rings the ground, paint splashes (except on a directly hit person),
# flowers bloom and burst petals.
func _element_impact(at: Vector3, direct: Person) -> void:
	if element == Config.Element.MUSIC:
		_spawn_sound_ring(at)
	elif element == Config.Element.ART:
		_splash(at, direct)
		_spawn_splat(at)
		_spawn_splash_ring(at)
	elif element == Config.Element.NATURE:
		_spawn_bloom(at)
		_spawn_petal_burst(at)
	_puff(Config.ELEMENT_COLORS[element], at)
	_free_self()


# Everyone near `at` (ground distance) except a directly hit person gets a share of the joy.
func _splash(at: Vector3, direct: Person) -> void:
	var joy := _shot_joy() * Config.TD_PAINT_SPLASH_FRACTION
	for p: Person in people:
		if not is_instance_valid(p) or p == direct:
			continue
		if GloomSim.flat_dist(at, p.global_position) <= Config.TD_PAINT_SPLASH_RADIUS:
			p.receive_joy(element, joy, _shooter_distance(p))


# Adds an impact effect to the level at `at`, tags it (group and kind), so it outlives this projectile.
func _add_impact_node(node: Node3D, at: Vector3, kind: String) -> void:
	node.add_to_group(IMPACT_GROUP)
	node.set_meta("impact_kind", kind)
	get_parent().add_child(node)
	node.global_position = at


# A flat, fading paint splat on the ground. It is added to the level so it outlives this projectile.
func _spawn_splat(at: Vector3) -> void:
	var splat := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = Config.TD_SPLAT_RADIUS
	cyl.bottom_radius = Config.TD_SPLAT_RADIUS
	cyl.height = 0.02
	splat.mesh = cyl
	var col: Color = Config.ELEMENT_COLORS[Config.Element.ART]
	col.a = Config.TD_SPLAT_ALPHA
	var mat := _make_mat(col)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	splat.material_override = mat
	_add_impact_node(splat, Vector3(at.x, 0.02, at.z), "splat")

	var t := splat.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_SPLAT_FADE_TIME)
	t.tween_callback(splat.queue_free)


# A brief thin ring drawn at exactly TD_PAINT_SPLASH_RADIUS, so the area on screen is the area that splashes people.
# It fades out over TD_SPLASH_RING_SECONDS. Tagged with the "splash" impact kind.
func _spawn_splash_ring(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Config.TD_PAINT_SPLASH_RADIUS
	disc.bottom_radius = Config.TD_PAINT_SPLASH_RADIUS
	disc.height = 0.02
	ring.mesh = disc
	var col: Color = Config.ELEMENT_COLORS[Config.Element.ART]
	col.a = Config.TD_SPLASH_RING_ALPHA
	var mat := _make_mat(col)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	_add_impact_node(ring, Vector3(at.x, 0.04, at.z), "splash")
	var t := ring.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_SPLASH_RING_SECONDS)
	t.tween_callback(ring.queue_free)


# Music impact: a dusty-blue ring on the ground that grows and fades out (the "sound ring"). Added to the level.
func _spawn_sound_ring(at: Vector3) -> void:
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.02
	ring.mesh = disc
	var mat := _make_mat(Config.TD_SOUND_RING_COLOR)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = mat
	ring.scale = Vector3(Config.TD_SOUND_RING_START, 1.0, Config.TD_SOUND_RING_START)
	_add_impact_node(ring, Vector3(at.x, 0.03, at.z), "ring")

	var grown := Vector3(Config.TD_SOUND_RING_RADIUS, 1.0, Config.TD_SOUND_RING_RADIUS)
	var t := ring.create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", grown, Config.TD_SOUND_RING_SECONDS)
	t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_SOUND_RING_SECONDS)
	t.chain().tween_callback(ring.queue_free)


# Nature impact: a quick burst of petals flying outward from the spot and falling to the ground, then fading.
func _spawn_petal_burst(at: Vector3) -> void:
	var colours: Array[Color] = Config.TD_PETAL_COLORS
	for i: int in range(Config.TD_PETAL_BURST_COUNT):
		var petal := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Config.TD_PETAL_SIZE
		petal.mesh = quad
		var mat := _make_mat(colours[i % colours.size()])
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		petal.material_override = mat
		petal.rotation.x = -PI / 2.0
		var a := TAU * i / float(Config.TD_PETAL_BURST_COUNT)
		var out := Vector3(cos(a), 0.0, sin(a)) * Config.TD_PETAL_BURST_RANGE
		_add_impact_node(petal, Vector3(at.x, 0.4, at.z), "petals")

		var end := Vector3(at.x + out.x, 0.03, at.z + out.z)
		var t := petal.create_tween()
		t.set_parallel(true)
		t.tween_property(petal, "global_position", end, Config.TD_PETAL_BURST_SECONDS)
		t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_PETAL_BURST_SECONDS)
		t.chain().tween_callback(petal.queue_free)


# A flower patch where the flower stopped. It is added to the level so it outlives this projectile.
func _spawn_bloom(at: Vector3) -> void:
	var bloom := Bloom.new()
	bloom.people = people
	get_parent().add_child(bloom)
	bloom.global_position = Vector3(at.x, 0.0, at.z)


# Distance from where the player fired to a person, ignoring height (joy falls off with it).
func _shooter_distance(p: Person) -> float:
	return GloomSim.flat_dist(shooter_pos, p.global_position)


func _fizzle(at: Vector3) -> void:
	_puff(FIZZLE_COLOR, at)
	_free_self()


func _free_self() -> void:
	_done = true
	queue_free()


# A tiny one-shot burst of particles, freed after one second. It is added to the level, not to this projectile.
func _puff(color: Color, at: Vector3) -> void:
	var puff := CPUParticles3D.new()
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.amount = 10
	puff.lifetime = 0.6
	puff.spread = 180.0
	puff.initial_velocity_min = 1.5
	puff.initial_velocity_max = 3.0
	puff.gravity = Vector3(0, -2, 0)
	var m := SphereMesh.new()
	m.radius = 0.06
	m.height = 0.12
	m.material = _make_mat(color)
	puff.mesh = m
	get_parent().add_child(puff)
	puff.global_position = at
	puff.emitting = true
	get_tree().create_timer(1.0).timeout.connect(puff.queue_free)


# Leaves a trail piece every so often while in flight, up to Config.TD_TRAIL_MAX_PIECES per projectile.
func _update_trail(delta: float) -> void:
	if trail_pieces >= Config.TD_TRAIL_MAX_PIECES:
		return
	_trail_timer -= delta
	if _trail_timer > 0.0:
		return
	_trail_timer = _trail_interval()
	trail_pieces += 1
	if element == Config.Element.MUSIC:
		_spawn_note_dot()
	elif element == Config.Element.ART:
		_spawn_drip()
	else:
		_spawn_petal()


func _trail_interval() -> float:
	if element == Config.Element.MUSIC:
		return Config.TD_TRAIL_INTERVAL
	if element == Config.Element.ART:
		return Config.TD_DRIP_INTERVAL
	return Config.TD_PETAL_INTERVAL


# Adds a trail piece to the level at `at` (not to this projectile), so it outlives the projectile.
func _add_trail_node(node: Node3D, at: Vector3) -> void:
	node.add_to_group(TRAIL_GROUP)
	node.set_meta("trail_element", element)
	get_parent().add_child(node)
	node.global_position = at


# Fades a trail piece to nothing over `seconds`, then frees it.
func _fade_and_free(node: Node3D, mat: StandardMaterial3D, seconds: float) -> void:
	var t := node.create_tween()
	t.tween_property(mat, "albedo_color:a", 0.0, seconds)
	t.tween_callback(node.queue_free)


# Music trail: a dusty-blue dot. The sideways wobble matches the note's own, so the dots form a wavy ribbon.
func _spawn_note_dot() -> void:
	var dot := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Config.TD_TRAIL_RADIUS
	sphere.height = Config.TD_TRAIL_RADIUS * 2.0
	dot.mesh = sphere
	var mat := _make_mat(Config.TD_TRAIL_COLOR)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material_override = mat
	var wobble := Vector3(sin(_age * Config.TD_NOTE_WAVE_SPEED) * Config.TD_NOTE_RIBBON_WAVE, 0.0, 0.0)
	_add_trail_node(dot, global_position + wobble)
	_fade_and_free(dot, mat, Config.TD_TRAIL_SECONDS)


# Art trail: a rose or terracotta drip that falls from the blob to the ground, then leaves a small splat dot.
func _spawn_drip() -> void:
	var drip := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = Config.TD_DRIP_RADIUS
	sphere.height = Config.TD_DRIP_RADIUS * 2.0
	drip.mesh = sphere
	drip.material_override = _make_mat(Config.TD_DRIP_COLOR)
	_add_trail_node(drip, global_position)
	var t := drip.create_tween()
	t.tween_property(drip, "global_position:y", Config.TD_LANDING_HEIGHT, Config.TD_DRIP_FALL_SECONDS)
	t.tween_callback(_drip_landed.bind(drip))


# A drip has reached the ground: its splat dot takes its place, and the drip is freed.
func _drip_landed(drip: MeshInstance3D) -> void:
	var dot := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = Config.TD_SPLAT_DOT_RADIUS
	disc.bottom_radius = Config.TD_SPLAT_DOT_RADIUS
	disc.height = 0.01
	dot.mesh = disc
	var mat := _make_mat(Config.TD_DRIP_COLOR)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dot.material_override = mat
	_add_trail_node(dot, Vector3(drip.global_position.x, 0.01, drip.global_position.z))
	_fade_and_free(dot, mat, Config.TD_SPLAT_DOT_FADE_SECONDS)
	drip.queue_free()


# Nature trail: a small sage or pink petal that drifts down while turning, then fades.
func _spawn_petal() -> void:
	var petal := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Config.TD_PETAL_SIZE
	petal.mesh = quad
	var colours: Array[Color] = Config.TD_PETAL_COLORS
	var mat := _make_mat(colours[trail_pieces % colours.size()])
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	petal.material_override = mat
	# Lies flat, so it reads as a petal from the top-down camera.
	petal.rotation.x = -PI / 2.0
	_add_trail_node(petal, global_position)
	var fall_to := maxf(Config.TD_LANDING_HEIGHT, petal.global_position.y - Config.TD_PETAL_FALL)
	var t := petal.create_tween()
	t.set_parallel(true)
	t.tween_property(petal, "global_position:y", fall_to, Config.TD_PETAL_FADE_SECONDS)
	t.tween_property(petal, "rotation:y", petal.rotation.y + TAU, Config.TD_PETAL_FADE_SECONDS)
	t.tween_property(mat, "albedo_color:a", 0.0, Config.TD_PETAL_FADE_SECONDS)
	t.chain().tween_callback(petal.queue_free)


# Music note: a squashed sphere head with a stem on the upper right.
func _build_music() -> void:
	var mat := _make_mat(Config.ELEMENT_COLORS[element])

	var head := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.22
	sphere.height = 0.3
	head.mesh = sphere
	head.material_override = mat
	_body.add_child(head)

	var stem := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.06, 0.6, 0.06)
	stem.mesh = box
	stem.position = Vector3(0.18, 0.3, 0.0)
	stem.material_override = mat
	_body.add_child(stem)


# Paint blob: a squashed pink sphere that wobbles as it flies.
func _build_paint() -> void:
	var blob := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	blob.mesh = sphere
	blob.material_override = _make_mat(Config.ELEMENT_COLORS[element])
	blob.scale = BLOB_SCALE
	_body.add_child(blob)
	_blob = blob


# Flower: a yellow centre with five petals in a ring. The whole flower spins as it flies.
func _build_flower() -> void:
	var centre := MeshInstance3D.new()
	var centre_mesh := SphereMesh.new()
	centre_mesh.radius = 0.12
	centre_mesh.height = 0.24
	centre.mesh = centre_mesh
	centre.material_override = _make_mat(FLOWER_CENTRE_COLOR)
	_body.add_child(centre)

	var petal_mat := _make_mat(Config.ELEMENT_COLORS[element])
	for i: int in range(5):
		var a := TAU * i / 5.0
		var petal := MeshInstance3D.new()
		var petal_mesh := SphereMesh.new()
		petal_mesh.radius = 0.13
		petal_mesh.height = 0.26
		petal.mesh = petal_mesh
		petal.material_override = petal_mat
		petal.position = Vector3(cos(a) * 0.2, 0.0, sin(a) * 0.2)
		_body.add_child(petal)


func _make_mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = col
	return mat
