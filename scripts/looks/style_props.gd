class_name StyleProps
extends Node3D

# Checkpoint 7: street props in the styled look. Lamp posts, benches, planters and market stalls round the blocks, and
# bunting and washing lines between them. In gloom they are dark, broken or bare; where the paint (or the nearest
# block's tint) is, the lamps glow warm, the lines unfurl their flags and the planters bloom. Scenery only: no
# collision, and it only reads the game (paint weight, a block's tint, the night's light). Everything is drawn through
# two MultiMeshes (boxes with smooth toon bands, and unlit soft balls) and redrawn every C7_PROPS_INTERVAL. Smooth
# bands and soft alpha, no dithering. StyleAmbient draws its creatures through the same `Layers`.

enum Kind { LAMP, BENCH, PLANTER, STALL }

const WOOD_BARE := Color(0.22, 0.2, 0.2)
const WOOD_WARM := Color(0.72, 0.48, 0.28)
const METAL_BARE := Color(0.17, 0.18, 0.21)
const METAL_WARM := Color(0.3, 0.33, 0.38)
const POT_BARE := Color(0.25, 0.22, 0.22)
const POT_WARM := Color(0.72, 0.4, 0.3)
const ROPE_BARE := Color(0.2, 0.2, 0.22)
const ROPE_WARM := Color(0.74, 0.66, 0.5)
const LAMP_OFF := Color(0.13, 0.13, 0.15, 1.0)
const LAMP_ON := Color(1.0, 0.82, 0.42, 1.0)
const STEM_DEAD := Color(0.3, 0.24, 0.18)
const STEM_LIVE := Color(0.3, 0.68, 0.34)
const FLOWERS: Array[Color] = [
	Color(0.95, 0.45, 0.4),
	Color(0.98, 0.78, 0.3),
	Color(0.75, 0.55, 0.9),
	Color(0.98, 0.6, 0.75),
	Color(0.3, 0.75, 0.7)
]
const CLOTHS: Array[Color] = [Color(0.95, 0.94, 0.9), Color(0.7, 0.85, 0.95), Color(0.98, 0.85, 0.7)]
const CREAM := Color(0.96, 0.92, 0.8)
const BOX_CAPACITY := 1800
const BALL_CAPACITY := 600
const LINE_PIECES := 8


# One piece of scenery: what it is, where it stands, and how bloomed it is now (0 bare to 1 full).
class Prop:
	extends RefCounted
	var kind: int = 0
	var pos := Vector3.ZERO
	var yaw: float = 0.0
	var block: int = 0
	var bloom: float = 0.0


# A bunting or washing line between two blocks.
class Line:
	extends RefCounted
	var a := Vector3.ZERO
	var b := Vector3.ZERO
	var block_a: int = 0
	var block_b: int = 0
	var washing: bool = false
	var unfurl: float = 0.0


# The two MultiMeshes and the writer that fills them (also used by StyleAmbient).
class Layers:
	extends RefCounted
	var boxes: MultiMesh
	var balls: MultiMesh
	var _nb: int = 0
	var _nl: int = 0

	func begin() -> void:
		_nb = 0
		_nl = 0

	func finish() -> void:
		boxes.visible_instance_count = _nb
		balls.visible_instance_count = _nl

	func box_count() -> int:
		return _nb

	func ball_count() -> int:
		return _nl

	# A box `size` across at `pos`, turned `yaw` about the vertical, then `tilt` about its own z and `pitch` about its x.
	func box(pos: Vector3, size: Vector3, col: Color, yaw: float = 0.0, tilt: float = 0.0, pitch: float = 0.0) -> void:
		if _nb >= boxes.instance_count:
			return
		var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt) * Basis(Vector3.RIGHT, pitch)
		boxes.set_instance_transform(_nb, Transform3D(bs.scaled_local(size), pos))
		boxes.set_instance_color(_nb, col)
		_nb += 1

	# A thin box from `a` to `b`.
	func seg(a: Vector3, b: Vector3, thick: float, col: Color) -> void:
		var d := b - a
		var length := d.length()
		if length < 0.001 or _nb >= boxes.instance_count:
			return
		var up := Vector3.RIGHT if absf(d.normalized().y) > 0.98 else Vector3.UP
		var bs := Basis.looking_at(d / length, up).scaled_local(Vector3(thick, thick, length))
		boxes.set_instance_transform(_nb, Transform3D(bs, (a + b) * 0.5))
		boxes.set_instance_color(_nb, col)
		_nb += 1

	# A soft unlit ball of `radius` (the colour's alpha is its opacity).
	func ball(pos: Vector3, radius: float, col: Color) -> void:
		if _nl >= balls.instance_count or radius <= 0.001:
			return
		balls.set_instance_transform(_nl, Transform3D(Basis().scaled(Vector3.ONE * radius * 2.0), pos))
		balls.set_instance_color(_nl, col)
		_nl += 1


var props: Array[Prop] = []
var lines: Array[Line] = []
var layers := Layers.new()
var time: float = 0.0
var main: TopDownMain
var _timer: float = 0.0
var _blocks: Array[Vector3] = []


# Builds the props under `level` (TopDownMain keeps the node in `style_props`).
static func attach(level: TopDownMain) -> StyleProps:
	var sp := StyleProps.new()
	sp.main = level
	level.add_child(sp)
	return sp


# 1 by day, 0 at night, for a sun energy (NightCycle.sun_energy).
static func day_factor(sun_energy: float) -> float:
	return clampf((sun_energy - Config.C7_DAY_ENERGY_LOW) / Config.C7_DAY_ENERGY_RANGE, 0.0, 1.0)


# The scenery of every block: a lamp, a bench, a planter and (every other block) a stall, from the block centres.
static func layout_props(centres: Array[Vector3]) -> Array[Prop]:
	var out: Array[Prop] = []
	for i: int in range(centres.size()):
		var c := Vector3(centres[i].x, 0.0, centres[i].z)
		out.append(_prop(Kind.LAMP, c + Vector3(2.9, 0.0, 2.9), 0.0, i))
		out.append(_prop(Kind.BENCH, c + Vector3(0.0, 0.0, 2.9), 0.0, i))
		out.append(_prop(Kind.PLANTER, c + Vector3(-2.6, 0.0, 2.7), 0.0, i))
		if i % 2 == 0:
			out.append(_prop(Kind.STALL, c + Vector3(3.6, 0.0, -0.8), -PI / 2.0, i))
		else:
			out.append(_prop(Kind.STALL, c + Vector3(-3.6, 0.0, -0.8), PI / 2.0, i))
	return out


# A line from each block to its two nearest neighbours that are closer than `max_dist` (no pair twice).
static func layout_lines(centres: Array[Vector3], max_dist: float) -> Array[Line]:
	var out: Array[Line] = []
	var done := {}
	for i: int in range(centres.size()):
		var order: Array[int] = []
		for j: int in range(centres.size()):
			if j != i:
				order.append(j)
		order.sort_custom(
			func(x: int, y: int) -> bool: return centres[i].distance_to(centres[x]) < centres[i].distance_to(centres[y])
		)
		for k: int in range(mini(2, order.size())):
			var j := order[k]
			var key := Vector2i(mini(i, j), maxi(i, j))
			if done.has(key) or centres[i].distance_to(centres[j]) > max_dist:
				continue
			done[key] = true
			var l := Line.new()
			var d := Vector3(centres[j].x - centres[i].x, 0.0, centres[j].z - centres[i].z).normalized()
			l.a = Vector3(centres[i].x, 2.4, centres[i].z) + d * 2.1
			l.b = Vector3(centres[j].x, 2.4, centres[j].z) - d * 2.1
			l.block_a = i
			l.block_b = j
			l.washing = (i + j) % 2 == 1
			out.append(l)
	return out


static func _prop(kind: int, pos: Vector3, yaw: float, block: int) -> Prop:
	var p := Prop.new()
	p.kind = kind
	p.pos = pos
	p.yaw = yaw
	p.block = block
	return p


# The mesh layers under `parent`: opaque boxes with toon bands, and soft unlit balls.
static func make_layers(parent: Node3D) -> Layers:
	var ls := Layers.new()
	ls.boxes = _make_multimesh(parent, false, BOX_CAPACITY)
	ls.balls = _make_multimesh(parent, true, BALL_CAPACITY)
	return ls


static func _make_multimesh(parent: Node3D, ball: bool, capacity: int) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	if ball:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 8
		sphere.rings = 4
		mm.mesh = sphere
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE
		mm.mesh = cube
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		mat.roughness = 1.0
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 40, 400))
	parent.add_child(mi)
	return mm


func _ready() -> void:
	for c: Vector3 in TopDownMain.BLOCK_POSITIONS:
		_blocks.append(c)
	props = layout_props(_blocks)
	lines = layout_lines(_blocks, Config.C7_LINE_MAX_DIST)
	layers = make_layers(self)
	visible = false


func _process(delta: float) -> void:
	visible = Looks.is_styled()
	if not visible:
		return
	time += delta
	_timer += delta
	if _timer >= Config.C7_PROPS_INTERVAL:
		refresh(_timer)
		_timer = 0.0


# Moves every prop's bloom `delta` seconds toward its target and redraws all the props.
func refresh(delta: float) -> void:
	var step := delta / maxf(Config.C7_BLOOM_SECONDS, 0.01)
	var tints := _block_tints()
	for p: Prop in props:
		p.bloom = move_toward(p.bloom, _target(p.pos, tints[p.block]), step)
	for l: Line in lines:
		var t := (_target(l.a, tints[l.block_a]) + _target(l.b, tints[l.block_b])) * 0.5
		l.unfurl = move_toward(l.unfurl, t, step)
	_redraw()


# The positions of the benches (scenery only; the ambient life reads them).
func bench_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Prop in props:
		if p.kind == Kind.BENCH:
			out.append(p.pos)
	return out


# The bloom a prop at `pos` heads for: the paint weight under it or its block's tint, whichever is more.
func _target(pos: Vector3, tint: float) -> float:
	var w := 0.0
	if main != null and main.ground != null:
		w = main.ground.paint_weight_at(pos)
	return clampf(maxf(w, tint), 0.0, 1.0)


# The tint (0..1) of each block, by index, read from the border's buildings.
func _block_tints() -> Array[float]:
	var out: Array[float] = []
	for c: Vector3 in _blocks:
		var best := 0.0
		if main != null and main.border != null:
			for b: Building in main.border.buildings:
				if b.centre.distance_to(Vector2(c.x, c.z)) < 1.0:
					best = b.tint
		out.append(best)
	return out


func _night_amount() -> float:
	if main == null or main.night == null:
		return 0.5
	return 1.0 - day_factor(main.night.sun_energy())


func _redraw() -> void:
	layers.begin()
	var night := _night_amount()
	for p: Prop in props:
		match p.kind:
			Kind.LAMP:
				_draw_lamp(p, night)
			Kind.BENCH:
				_draw_bench(p)
			Kind.PLANTER:
				_draw_planter(p)
			_:
				_draw_stall(p)
	for i: int in range(lines.size()):
		_draw_line(lines[i], i)
	layers.finish()


func _at(p: Prop, local: Vector3) -> Vector3:
	return p.pos + Basis(Vector3.UP, p.yaw) * local


func _draw_lamp(p: Prop, night: float) -> void:
	var lean := lerpf(Config.C7_LAMP_LEAN, 0.0, p.bloom) * (1.0 if p.block % 2 == 0 else -1.0)
	var metal := METAL_BARE.lerp(METAL_WARM, p.bloom)
	var up := Vector3(-sin(lean), cos(lean), 0.0)
	layers.box(_at(p, up * 1.1), Vector3(0.12, 2.2, 0.12), metal, p.yaw, lean)
	layers.box(_at(p, Vector3(0.0, 0.05, 0.0)), Vector3(0.34, 0.1, 0.34), metal, p.yaw)
	var head := _at(p, up * 2.3)
	var glow := p.bloom * (0.55 + 0.45 * night)
	layers.ball(head, 0.2, LAMP_OFF.lerp(LAMP_ON, glow))
	if glow > 0.05:
		layers.ball(head, 0.75, Color(LAMP_ON.r, LAMP_ON.g, LAMP_ON.b, 0.2 * glow))


func _draw_bench(p: Prop) -> void:
	var wood := WOOD_BARE.lerp(WOOD_WARM, p.bloom)
	var broken := p.bloom < 0.25
	layers.box(_at(p, Vector3(0.0, 0.45, 0.0)), Vector3(1.5, 0.1, 0.5), wood, p.yaw, 0.0, 0.18 if broken else 0.0)
	if not broken:
		layers.box(_at(p, Vector3(0.0, 0.78, -0.22)), Vector3(1.5, 0.42, 0.07), wood, p.yaw)
	for sx: float in [-0.62, 0.62]:
		layers.box(_at(p, Vector3(sx, 0.22, 0.0)), Vector3(0.1, 0.44, 0.4), METAL_BARE.lerp(METAL_WARM, p.bloom), p.yaw)


func _draw_planter(p: Prop) -> void:
	layers.box(_at(p, Vector3(0.0, 0.2, 0.0)), Vector3(0.9, 0.4, 0.5), POT_BARE.lerp(POT_WARM, p.bloom), p.yaw)
	var stem := STEM_DEAD.lerp(STEM_LIVE, p.bloom)
	var top := 0.4 + lerpf(0.25, 0.12, p.bloom)
	var size := 0.14 * smoothstep(0.2, 1.0, p.bloom)
	var xs: Array[float] = [-0.3, -0.1, 0.12, 0.32]
	for i: int in range(xs.size()):
		var base := _at(p, Vector3(xs[i], 0.4, 0.0))
		var tip := _at(p, Vector3(xs[i], top + 0.04 * float(i % 2), 0.0))
		layers.seg(base, tip, 0.03, stem)
		layers.ball(tip + Vector3(0, 0.03, 0), size, FLOWERS[(p.block + i) % FLOWERS.size()])


func _draw_stall(p: Prop) -> void:
	var wood := WOOD_BARE.lerp(WOOD_WARM, p.bloom)
	layers.box(_at(p, Vector3(0.0, 0.35, 0.0)), Vector3(1.8, 0.7, 0.9), wood, p.yaw)
	for sx: float in [-0.85, 0.85]:
		layers.box(_at(p, Vector3(sx, 0.95, 0.4)), Vector3(0.08, 1.9, 0.08), wood, p.yaw)
	var open := smoothstep(0.3, 0.7, p.bloom)
	if open < 0.01:
		layers.box(_at(p, Vector3(0.0, 1.75, 0.1)), Vector3(0.9, 0.04, 0.6), ROPE_BARE, p.yaw, 0.0, 0.5)
	else:
		for k: int in range(4):
			var col := FLOWERS[0] if k % 2 == 0 else CREAM
			layers.box(
				_at(p, Vector3(-0.675 + 0.45 * float(k), 1.9, 0.0)),
				Vector3(0.45, 0.06, 1.2 * open),
				col,
				p.yaw,
				0.0,
				-0.2
			)
	var goods := 0.1 * smoothstep(0.5, 0.9, p.bloom)
	for k: int in range(3):
		layers.ball(
			_at(p, Vector3(-0.5 + 0.5 * float(k), 0.8, 0.0)), goods, FLOWERS[(p.block + k + 1) % FLOWERS.size()]
		)


func _draw_line(l: Line, index: int) -> void:
	var sag := lerpf(Config.C7_LINE_SAG_GLOOM, Config.C7_LINE_SAG_BLOOM, l.unfurl)
	var rope := ROPE_BARE.lerp(ROPE_WARM, l.unfurl)
	var flat := Vector3(l.b.x - l.a.x, 0.0, l.b.z - l.a.z)
	var yaw := atan2(flat.x, flat.z)
	var prev := l.a
	for i: int in range(1, LINE_PIECES + 1):
		var t := float(i) / float(LINE_PIECES)
		var pt := l.a.lerp(l.b, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		layers.seg(prev, pt, 0.04, rope)
		if i < LINE_PIECES and l.unfurl > 0.05:
			var h := (0.55 if l.washing else 0.28) * l.unfurl
			var w := 0.4 if l.washing else 0.2
			var col := CLOTHS[(index + i) % CLOTHS.size()] if l.washing else FLOWERS[(index + i) % FLOWERS.size()]
			var sway := sin(time * 1.5 + float(i) + float(index)) * 0.08 * l.unfurl
			layers.box(pt - Vector3(0.0, h * 0.5, 0.0), Vector3(0.03, h, w), col, yaw, sway)
		prev = pt
