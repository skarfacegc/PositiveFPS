class_name StyleAmbient
extends Node3D

# Checkpoint 7: ambient life in the styled look. Butterflies by day and fireflies by night drift inside the zone, a bird
# lands on every beautified rooftop, and rescued people who stand still in the zone start a small idle action (sit on a
# bench, wave, tend a flower box). VISUAL ONLY: nothing here touches the simulation. It reads the paint weight, the
# buildings' state, the night's light and the people's state, uses its own random numbers, and the idle actions only
# draw small extras beside the person (and sink the person's drawing a little when sitting): a person's rule position
# never moves. Drawn through StyleProps.Layers (two MultiMeshes), soft alpha, no dithering.

enum Action { SIT, WAVE, TEND }

const WING_COLOURS: Array[Color] = [
	Color(0.98, 0.7, 0.25), Color(0.95, 0.5, 0.55), Color(0.55, 0.7, 0.98), Color(0.98, 0.95, 0.6)
]
const BIRD_COLOURS: Array[Color] = [Color(0.55, 0.62, 0.85), Color(0.85, 0.5, 0.4), Color(0.45, 0.45, 0.5)]
const FIREFLY := Color(0.85, 1.0, 0.4)
const SKIN := Color(0.95, 0.75, 0.6)
const WOOD := Color(0.72, 0.48, 0.28)
const WATER := Color(0.55, 0.8, 1.0)
const BANK_Y := 2.0  # The top of a block (metres): where the birds land.


# A butterfly or a firefly: drifts round its anchor while it has one, fades in and out.
class Flyer:
	extends RefCounted
	var anchor := Vector3.ZERO
	var live: bool = false
	var fade: float = 0.0
	var phase: float = 0.0
	var rate: float = 1.0
	var colour := Color.WHITE


# A bird for one block: flies in from `start` and lands on `roof` while the block is beautified.
class Bird:
	extends RefCounted
	var block: int = 0
	var roof := Vector3.ZERO
	var start := Vector3.ZERO
	var t: float = 0.0
	var phase: float = 0.0
	var colour := Color.WHITE


# One rescued person's idle action: how long they have stood still, which action, and how far into it they are.
class Idler:
	extends RefCounted
	var person: Person
	var last := Vector3.ZERO
	var still: float = 0.0
	var action: int = 0
	var ease_in: float = 0.0
	var wanted: bool = false


var main: TopDownMain
var layers: StyleProps.Layers
var butterflies: Array[Flyer] = []
var fireflies: Array[Flyer] = []
var birds: Array[Bird] = []
var idlers: Dictionary = {}
var time: float = 0.0
var day: float = 1.0
var _rng := RandomNumberGenerator.new()
var _anchor_timer: float = 0.0


# Builds the ambient life under `level` (TopDownMain keeps the node in `style_ambient`).
static func attach(level: TopDownMain) -> StyleAmbient:
	var sa := StyleAmbient.new()
	sa.main = level
	level.add_child(sa)
	return sa


func _ready() -> void:
	_rng.seed = Config.C7_SEED
	layers = StyleProps.make_layers(self)
	for i: int in range(Config.C7_BUTTERFLIES):
		butterflies.append(_flyer(WING_COLOURS[i % WING_COLOURS.size()]))
	for i: int in range(Config.C7_FIREFLIES):
		fireflies.append(_flyer(FIREFLY))
	for i: int in range(TopDownMain.BLOCK_POSITIONS.size()):
		var c := TopDownMain.BLOCK_POSITIONS[i]
		var b := Bird.new()
		b.block = i
		b.roof = Vector3(c.x + _rng.randf_range(-1.2, 1.2), BANK_Y, c.z + _rng.randf_range(-1.2, 1.2))
		b.start = b.roof + Basis(Vector3.UP, float(i) * 1.1) * Config.C7_BIRD_START
		b.phase = _rng.randf() * TAU
		b.colour = BIRD_COLOURS[i % BIRD_COLOURS.size()]
		birds.append(b)
	visible = false


func _exit_tree() -> void:
	release_idlers()


func _process(delta: float) -> void:
	visible = Looks.is_styled()
	if not visible:
		release_idlers()
		return
	step(delta)


# Moves everything `delta` seconds on and redraws it.
func step(delta: float) -> void:
	time += delta
	day = 1.0
	if main != null and main.night != null:
		day = StyleProps.day_factor(main.night.sun_energy())
	layers.begin()
	_anchor_timer += delta
	var pick := _anchor_timer >= Config.C7_ANCHOR_INTERVAL
	if pick:
		_anchor_timer = 0.0
	for f: Flyer in butterflies:
		_step_flyer(f, delta, pick)
		_draw_butterfly(f)
	for f: Flyer in fireflies:
		_step_flyer(f, delta, pick)
		_draw_firefly(f)
	for b: Bird in birds:
		_step_bird(b, delta)
	_step_idlers(delta)
	layers.finish()


# Puts every sunk drawing back and forgets the idle actions.
func release_idlers() -> void:
	for id: Variant in idlers:
		_sink(idlers[id] as Idler, 0.0)
	idlers.clear()


func _flyer(col: Color) -> Flyer:
	var f := Flyer.new()
	f.phase = _rng.randf() * TAU
	f.rate = _rng.randf_range(0.6, 1.2)
	f.colour = col
	return f


func _weight(pos: Vector3) -> float:
	if main == null or main.ground == null:
		return 0.0
	return main.ground.paint_weight_at(pos)


# A spot inside the zone to drift round, or Vector3.INF when there is none.
func _pick_anchor() -> Vector3:
	if main == null or main.border == null:
		return Vector3.INF
	var centres: Array[Vector3] = []
	for b: Building in main.border.buildings:
		if b.tint > 0.5:
			centres.append(Vector3(b.centre.x, 0.0, b.centre.y))
	if centres.is_empty():
		for p: Person in main.people:
			if p.is_rescued:
				centres.append(p.global_position)
	if centres.is_empty():
		return Vector3.INF
	var c := centres[_rng.randi_range(0, centres.size() - 1)]
	var a := _rng.randf() * TAU
	var r := _rng.randf() * Config.C7_ANCHOR_REACH
	var half := float(Config.TD_PLAZA_SIZE) * 0.5 - 1.0
	var at := Vector3(clampf(c.x + cos(a) * r, -half, half), 0.0, clampf(c.z + sin(a) * r, -half, half))
	if _weight(at) < Config.C7_AMBIENT_MIN_WEIGHT:
		return Vector3.INF
	at.y = _rng.randf_range(0.8, 2.0)
	return at


func _step_flyer(f: Flyer, delta: float, pick: bool) -> void:
	if f.live and _weight(f.anchor) < Config.C7_AMBIENT_MIN_WEIGHT * 0.5:
		f.live = false
	if not f.live and pick:
		var at := _pick_anchor()
		if at != Vector3.INF:
			f.anchor = at
			f.live = true
	f.fade = move_toward(f.fade, 1.0 if f.live else 0.0, delta / maxf(Config.C7_FADE_SECONDS, 0.01))


# Where a flyer is now: a slow loop round its anchor.
func _flyer_pos(f: Flyer) -> Vector3:
	var t := time * f.rate + f.phase
	var r := Config.C7_DRIFT_RADIUS
	return f.anchor + Vector3(sin(t) * r, sin(t * 1.7) * 0.4, cos(t * 0.8 + f.phase) * r)


func _draw_butterfly(f: Flyer) -> void:
	var vis := f.fade * day
	if vis < 0.02:
		return
	var t := time * f.rate + f.phase
	var yaw := atan2(cos(t), -sin(t * 0.8 + f.phase) * 0.8)
	var pos := _flyer_pos(f)
	var flap := 0.3 + 0.9 * absf(sin(time * 12.0 + f.phase))
	var side := Basis(Vector3.UP, yaw) * Vector3(0.07, 0.0, 0.0)
	var wing := Vector3(0.14, 0.01, 0.1) * vis
	layers.box(pos + side, wing, f.colour, yaw, flap)
	layers.box(pos - side, wing, f.colour, yaw, -flap)


func _draw_firefly(f: Flyer) -> void:
	var vis := f.fade * (1.0 - day)
	if vis < 0.02:
		return
	var pos := _flyer_pos(f)
	var pulse := 0.5 + 0.5 * sin(time * 2.5 + f.phase)
	layers.ball(pos, 0.05, Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, vis))
	layers.ball(pos, 0.1 + 0.15 * pulse, Color(FIREFLY.r, FIREFLY.g, FIREFLY.b, 0.25 * vis * pulse))


func _building_beautified(block: int) -> bool:
	if main == null or main.border == null:
		return false
	var c := TopDownMain.BLOCK_POSITIONS[block]
	for b: Building in main.border.buildings:
		if b.centre.distance_to(Vector2(c.x, c.z)) < 1.0:
			return b.beautified
	return false


func _step_bird(b: Bird, delta: float) -> void:
	var target := 1.0 if _building_beautified(b.block) else 0.0
	b.t = move_toward(b.t, target, delta / maxf(Config.C7_BIRD_SECONDS, 0.01))
	if b.t <= 0.001:
		return
	var e := smoothstep(0.0, 1.0, b.t)
	var flying := b.t < 1.0 and b.t > 0.0
	var pos := b.start.lerp(b.roof, e)
	if not flying:
		pos.y += pow(maxf(0.0, sin(time * 1.7 + b.phase)), 10.0) * 0.07
	var heading := b.roof - b.start
	var yaw := atan2(heading.x, heading.z) if flying else b.phase
	var fwd := Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, 1.0)
	layers.box(pos + Vector3(0, 0.1, 0), Vector3(0.2, 0.14, 0.3), b.colour, yaw)
	layers.ball(pos + Vector3(0, 0.2, 0) + fwd * 0.16, 0.07, b.colour.lightened(0.15))
	layers.box(pos + Vector3(0, 0.1, 0) - fwd * 0.2, Vector3(0.07, 0.03, 0.16), b.colour.darkened(0.3), yaw)
	if flying:
		var flap := 0.9 * sin(time * 14.0 + b.phase)
		var side := Basis(Vector3.UP, yaw) * Vector3(0.14, 0.0, 0.0)
		layers.box(pos + Vector3(0, 0.15, 0) + side, Vector3(0.22, 0.02, 0.12), b.colour, yaw, flap)
		layers.box(pos + Vector3(0, 0.15, 0) - side, Vector3(0.22, 0.02, 0.12), b.colour, yaw, -flap)


func _step_idlers(delta: float) -> void:
	if main == null:
		return
	for p: Person in main.people:
		var id := p.get_instance_id()
		var eligible := p.is_rescued and not p.wobbling and _weight(p.global_position) >= Config.C7_IDLE_MIN_WEIGHT
		if not idlers.has(id):
			if not eligible:
				continue
			var fresh := Idler.new()
			fresh.person = p
			fresh.last = p.global_position
			fresh.action = posmod(p.look_seed + p.affinity, 3)
			idlers[id] = fresh
		var it: Idler = idlers[id]
		if p.global_position.distance_to(it.last) > Config.C7_IDLE_STILL:
			it.last = p.global_position
			it.still = 0.0
		else:
			it.still += delta
		it.wanted = eligible and it.still >= Config.C7_IDLE_AFTER
		it.ease_in = move_toward(it.ease_in, 1.0 if it.wanted else 0.0, delta / maxf(Config.C7_IDLE_EASE, 0.01))
		if it.ease_in <= 0.0 and not eligible:
			_sink(it, 0.0)
			idlers.erase(id)
			continue
		_draw_idle(it)


# Sinks the drawing of the person (their look node, a child) by `amount` of the sit drop; never their rule position.
func _sink(it: Idler, amount: float) -> void:
	if it == null or not is_instance_valid(it.person) or it.person.look == null:
		return
	it.person.look.position.y = -Config.C7_SIT_DROP * amount


func _draw_idle(it: Idler) -> void:
	var e := smoothstep(0.0, 1.0, it.ease_in)
	_sink(it, e if it.action == Action.SIT else 0.0)
	if e <= 0.0:
		return
	var base := it.person.global_position
	match it.action:
		Action.SIT:
			layers.box(base + Vector3(0, 0.3, 0), Vector3(1.0, 0.08, 0.4) * e, WOOD)
			layers.box(base + Vector3(-0.4, 0.14, 0), Vector3(0.08, 0.28, 0.34) * e, WOOD.darkened(0.3))
			layers.box(base + Vector3(0.4, 0.14, 0), Vector3(0.08, 0.28, 0.34) * e, WOOD.darkened(0.3))
		Action.WAVE:
			var hand := base + Vector3(0.34 + 0.12 * sin(time * 7.0), 1.62 + 0.05 * sin(time * 3.5), 0.05)
			var shoulder := base + Vector3(0.2, 1.25, 0.0)
			layers.seg(shoulder, shoulder.lerp(hand, e), 0.06, SKIN)
			layers.ball(hand, 0.07 * e, SKIN)
		_:
			layers.box(base + Vector3(0, 0.2, 0.55), Vector3(0.5, 0.22, 0.22) * e, WOOD.darkened(0.2))
			for k: int in range(3):
				var col := StyleProps.FLOWERS[(it.person.look_seed + k) % StyleProps.FLOWERS.size()]
				layers.ball(base + Vector3(-0.15 + 0.15 * float(k), 0.38, 0.55), 0.07 * e, col)
				var f := fposmod(time * 1.2 + float(k) / 3.0, 1.0)
				layers.ball(
					base + Vector3(0.15, 1.0 - 0.55 * f, 0.35 + 0.2 * f),
					0.035,
					Color(WATER.r, WATER.g, WATER.b, 0.8 * e)
				)
