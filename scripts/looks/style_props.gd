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
const BOX_CAPACITY := 5000
const BALL_CAPACITY := 1200
const LIGHT_CAPACITY := 300
const LINE_PIECES := 8
# 0.3.2 (#49): the iron and the vines of a lamp.
const IRON_COLD := Color(0.42, 0.45, 0.52)
const IRON_WARM := Color(0.36, 0.33, 0.34)
const GLASS_COOL := Color(0.78, 0.88, 0.98)
const GLASS_WARM := Color(1.0, 0.72, 0.28)
const VINE := Color(0.38, 0.74, 0.34)
const LEAF := Color(0.5, 0.86, 0.38)
const VINE_TURNS := 2.0
const VINE_STEPS := 8
# 0.3.2 (#50): the bench, riveted grey metal in gloom, wooden slats and a cushion in the earthy joy palette in bloom.
const BENCH_GREY := Color(0.38, 0.4, 0.45)
const BENCH_RIVET := Color(0.54, 0.56, 0.6)
const BENCH_WOOD := Color(0.56, 0.4, 0.27)
const BENCH_IRON := Color(0.25, 0.23, 0.25)
const CUSHIONS: Array[Color] = [Color(0.42, 0.56, 0.74), Color(0.76, 0.44, 0.34), Color(0.58, 0.68, 0.46)]
const SEAT_SLATS := 4
const BACK_SLATS := 3


# One piece of scenery: what it is, where it stands, and how bloomed it is now (0 bare to 1 full).
class Prop:
	extends RefCounted
	var kind: int = 0
	var pos := Vector3.ZERO
	var yaw: float = 0.0
	var block: int = 0
	var bloom: float = 0.0
	var plaza: bool = false  # 0.3.1 (#48): stands in the open plaza, not at a block (blooms by the paint alone).


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
	var cones: MultiMesh  # 0.3.2 (#49): soft cones of lamp light (null for StyleAmbient's layers).
	var pools: MultiMesh  # 0.3.2 (#49): soft pools of lamp light on the ground (null for StyleAmbient's layers).
	# What the last cone and pool were given (the headless renderer reads no transform back, so the tests read these).
	var last_cone := Transform3D.IDENTITY
	var last_pool := Transform3D.IDENTITY
	# Tests only: with `watch` on, every box also records its lowest and highest point (metres) in `spans`.
	var watch: bool = false
	var spans: Array[Vector2] = []
	var _nb: int = 0
	var _nl: int = 0
	var _nc: int = 0
	var _np: int = 0

	func begin() -> void:
		_nb = 0
		_nl = 0
		_nc = 0
		_np = 0
		spans.clear()

	func _note(t: Transform3D) -> void:
		if watch:
			var half := 0.5 * (absf(t.basis.x.y) + absf(t.basis.y.y) + absf(t.basis.z.y))
			spans.append(Vector2(t.origin.y - half, t.origin.y + half))

	func finish() -> void:
		boxes.visible_instance_count = _nb
		balls.visible_instance_count = _nl
		if cones != null:
			cones.visible_instance_count = _nc
			pools.visible_instance_count = _np

	func box_count() -> int:
		return _nb

	func ball_count() -> int:
		return _nl

	func cone_count() -> int:
		return _nc

	func pool_count() -> int:
		return _np

	# 0.3.2 (#49): a soft cone of light from `top` down to the ground height `ground_y`, `radius` wide at the ground
	# (the colour's alpha is its strength).
	func cone(top: Vector3, ground_y: float, radius: float, col: Color) -> void:
		var height := top.y - ground_y
		if cones == null or _nc >= cones.instance_count or height <= 0.01 or radius <= 0.001:
			return
		var bs := Basis().scaled(Vector3(radius * 2.0, height, radius * 2.0))
		last_cone = Transform3D(bs, Vector3(top.x, ground_y + height * 0.5, top.z))
		cones.set_instance_transform(_nc, last_cone)
		cones.set_instance_color(_nc, col)
		_nc += 1

	# 0.3.2 (#49): a soft pool of light flat on the ground at `pos`.
	func pool(pos: Vector3, radius: float, col: Color) -> void:
		if pools == null or _np >= pools.instance_count or radius <= 0.001:
			return
		last_pool = Transform3D(Basis().scaled(Vector3(radius * 2.0, 1.0, radius * 2.0)), pos)
		pools.set_instance_transform(_np, last_pool)
		pools.set_instance_color(_np, col)
		_np += 1

	# A box `size` across at `pos`, turned `yaw` about the vertical, then `tilt` about its own z and `pitch` about its x.
	func box(pos: Vector3, size: Vector3, col: Color, yaw: float = 0.0, tilt: float = 0.0, pitch: float = 0.0) -> void:
		if _nb >= boxes.instance_count:
			return
		var bs := Basis(Vector3.UP, yaw) * Basis(Vector3.BACK, tilt) * Basis(Vector3.RIGHT, pitch)
		var t := Transform3D(bs.scaled_local(size), pos)
		_note(t)
		boxes.set_instance_transform(_nb, t)
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
		var t := Transform3D(bs, (a + b) * 0.5)
		_note(t)
		boxes.set_instance_transform(_nb, t)
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


# 0.3.1 (#48): props in the open plaza, on a lattice `L31_PLAZA_SPACING` apart (offset half a step so the player's
# start is never on a spot). A spot is skipped when it is too near a block or a landmark (`L31_PLAZA_CLEAR`), the
# player's start (the middle, `L31_PLAZA_START_CLEAR`) or the plaza's edge. The kind and the turn follow the lattice
# position, so the layout is the same on every run.
static func layout_plaza(
	centres: Array[Vector3], landmarks: Array[Vector3], half: float, step: float = Config.L31_PLAZA_SPACING
) -> Array[Prop]:
	var out: Array[Prop] = []
	var n := floori(half / step)
	var kinds: Array[int] = [Kind.LAMP, Kind.BENCH, Kind.PLANTER, Kind.LAMP]
	for ix: int in range(-n, n):
		for iz: int in range(-n, n):
			var at := Vector3((float(ix) + 0.5) * step, 0.0, (float(iz) + 0.5) * step)
			if absf(at.x) > half - Config.L31_PLAZA_EDGE or absf(at.z) > half - Config.L31_PLAZA_EDGE:
				continue
			if _near(at, centres, Config.L31_PLAZA_CLEAR) or _near(at, landmarks, Config.L31_PLAZA_CLEAR):
				continue
			if at.length() < Config.L31_PLAZA_START_CLEAR:
				continue
			var k := posmod(ix * 2 + iz, 4)
			var p := _prop(kinds[k], at, float(posmod(ix + iz, 2)) * PI / 2.0, out.size())
			p.plaza = true
			out.append(p)
	return out


static func _near(at: Vector3, list: Array[Vector3], dist: float) -> bool:
	for c: Vector3 in list:
		if Vector2(at.x - c.x, at.z - c.z).length() < dist:
			return true
	return false


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
			# 0.3.1: the line's ends are the tops of two posts at roof height (the posts stand on the ground below).
			# 0.3.2 (#42): higher than the player's head (see line_low_point).
			l.a = Vector3(centres[i].x, Config.L32_LINE_POST_HEIGHT, centres[i].z) + d * Config.L31_LINE_POST_OFFSET
			l.b = Vector3(centres[j].x, Config.L32_LINE_POST_HEIGHT, centres[j].z) - d * Config.L31_LINE_POST_OFFSET
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


# The mesh layers under `parent`: opaque boxes with toon bands, and soft unlit balls. With `light`, also the soft cones
# and pools of the lamps' light (0.3.2, #49; shaders/style_lamp_light.gdshader).
static func make_layers(parent: Node3D, light: bool = false) -> Layers:
	var ls := Layers.new()
	ls.boxes = _make_multimesh(parent, false, BOX_CAPACITY)
	ls.balls = _make_multimesh(parent, true, BALL_CAPACITY)
	if light:
		ls.cones = _make_light_multimesh(parent, false)
		ls.pools = _make_light_multimesh(parent, true)
	return ls


# A MultiMesh of soft light shapes: cones (a narrow top, wide bottom, open ends) or flat pools, drawn after the
# post-process quad like the soft balls.
static func _make_light_multimesh(parent: Node3D, pool: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	if pool:
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		mm.mesh = plane
	else:
		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.5
		cone.height = 1.0
		cone.radial_segments = 16
		cone.rings = 1
		cone.cap_top = false
		cone.cap_bottom = false
		mm.mesh = cone
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/style_lamp_light.gdshader" if pool else "res://shaders/style_lamp_cone.gdshader")
	mat.render_priority = Config.L31_SOFT_PRIORITY
	mm.instance_count = LIGHT_CAPACITY
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 40, 400))
	parent.add_child(mi)
	return mm


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
		# 0.3.1 (#48): drawn after the post-process quad (priority 0), which otherwise paints over every soft ball: the
		# lamp glows, planter flowers and fireflies were invisible in the styled look.
		mat.render_priority = Config.L31_SOFT_PRIORITY
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
	var landmarks: Array[Vector3] = []
	landmarks.assign(Config.LANDMARK_POSITIONS)
	props.append_array(layout_plaza(_blocks, landmarks, float(Config.TD_PLAZA_SIZE) * 0.5))
	lines = layout_lines(_blocks, Config.C7_LINE_MAX_DIST)
	layers = make_layers(self, true)
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
		p.bloom = move_toward(p.bloom, _target(p.pos, 0.0 if p.plaza else tints[p.block]), step)
	for l: Line in lines:
		var t := (_target(l.a, tints[l.block_a]) + _target(l.b, tints[l.block_b])) * 0.5
		l.unfurl = move_toward(l.unfurl, t, step)
	_redraw()


# The positions of the benches (scenery only; the ambient life reads them).
func bench_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Prop in props:
		if p.kind == Kind.BENCH and not p.plaza:
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


# 0.3.1: a prop's bare colour lifts toward its warm colour (by L31_PROP_LIFT at least) so it reads on the grey ground.
static func tone(bare: Color, warm: Color, bloom: float, lift: float = -1.0) -> Color:
	var base := Config.L31_PROP_LIFT if lift < 0.0 else lift
	return bare.lerp(warm, lerpf(base, 1.0, bloom))


# A local size or offset drawn L31_PROP_SCALE times bigger.
static func big(v: Vector3) -> Vector3:
	return v * Config.L31_PROP_SCALE


# A bench's local size or offset: L31_BENCH_SCALE bigger again than the other props.
static func bench_big(v: Vector3) -> Vector3:
	return v * Config.L31_PROP_SCALE * Config.L31_BENCH_SCALE


# 0.3.2 (#49): the colour of a lamp's light: cool pale blue-white in gloom, warm cheery amber in full bloom.
static func lamp_light_colour(bloom: float) -> Color:
	return Config.L32_LIGHT_COOL.lerp(Config.L32_LIGHT_WARM, smoothstep(0.1, 0.9, bloom))


# 0.3.2 (#49): how strongly a lamp's light shows (0 to 1): full at night, faint by day, a little less in gloom.
static func lamp_light_strength(bloom: float, night: float) -> float:
	return (
		lerpf(Config.L32_LIGHT_DAY, 1.0, clampf(night, 0.0, 1.0))
		* lerpf(Config.L32_LIGHT_GLOOM, 1.0, clampf(bloom, 0.0, 1.0))
	)


# 0.3.2 (#49): how far the vines have grown up a lamp post (0 bare to 1 in full leaf).
static func vine_amount(bloom: float) -> float:
	return smoothstep(0.2, 1.0, bloom)


# 0.3.2 (#49): how many of the VINE_STEPS pieces of vine a lamp at `bloom` shows.
static func vine_steps(bloom: float) -> int:
	return ceili(vine_amount(bloom) * float(VINE_STEPS))


# The height (metres) of a lamp's head, the middle of its glass.
static func lamp_head_height() -> float:
	return 2.3 * Config.L31_PROP_SCALE * Config.L31_LAMP_SCALE * Config.L31_LAMP_HEIGHT


# 0.3.2 (#49): a stiff iron gas lamp with a caged glass head. Bloom grows vines up the post (leaves, then a few small
# flowers near full bloom) and turns the glass from pale blue-white to amber. The light is a soft cone from the head to
# a pool on the ground (cool in gloom, warm in bloom; strongest at night) and a small glow at the head.
func _draw_lamp(p: Prop, night: float) -> void:
	var iron := IRON_COLD.lerp(IRON_WARM, p.bloom)
	var s := Config.L31_PROP_SCALE * Config.L31_LAMP_SCALE  # 0.3.1 (#48): lamps are bigger again.
	var top_y := lamp_head_height()  # Shorter and stouter: the head stays in the frame at play zoom.
	var post_top := top_y - 0.3 * s
	var post_h := post_top - 0.3 * s
	var strength := lamp_light_strength(p.bloom, night)
	var light := lamp_light_colour(p.bloom)
	layers.box(_at(p, Vector3(0.0, 0.07 * s, 0.0)), Vector3(0.42, 0.14, 0.42) * s, iron, p.yaw)
	layers.box(_at(p, Vector3(0.0, 0.22 * s, 0.0)), Vector3(0.28, 0.16, 0.28) * s, iron, p.yaw)
	layers.box(_at(p, Vector3(0.0, 0.3 * s + post_h * 0.5, 0.0)), Vector3(0.15 * s, post_h, 0.15 * s), iron, p.yaw)
	for band_y: float in [0.3 * s + post_h * 0.3, post_top - 0.04 * s]:
		layers.box(_at(p, Vector3(0.0, band_y, 0.0)), Vector3(0.23, 0.06, 0.23) * s, iron, p.yaw)
	# The caged glass: a lit glass globe, four corner bars (slimmer as it blooms), a base plate, a cap and a finial.
	var head := _at(p, Vector3(0.0, top_y, 0.0))
	var glass := GLASS_COOL.lerp(GLASS_WARM, smoothstep(0.1, 0.9, p.bloom))
	layers.ball(head, 0.17 * s, glass.darkened(0.3 * (1.0 - strength)))
	var bar := 0.035 * s * lerpf(1.0, 0.6, p.bloom)
	for sx: float in [-0.13, 0.13]:
		for sz: float in [-0.13, 0.13]:
			layers.box(_at(p, Vector3(sx * s, top_y, sz * s)), Vector3(bar, 0.42 * s, bar), iron, p.yaw)
	layers.box(_at(p, Vector3(0.0, top_y - 0.23 * s, 0.0)), Vector3(0.34, 0.05, 0.34) * s, iron, p.yaw)
	layers.box(_at(p, Vector3(0.0, top_y + 0.23 * s, 0.0)), Vector3(0.38, 0.06, 0.38) * s, iron, p.yaw)
	layers.box(_at(p, Vector3(0.0, top_y + 0.3 * s, 0.0)), Vector3(0.22, 0.08, 0.22) * s, iron, p.yaw)
	layers.box(_at(p, Vector3(0.0, top_y + 0.38 * s, 0.0)), Vector3(0.07, 0.1, 0.07) * s, iron, p.yaw)
	_draw_vines(p, s, post_top)
	var radius := Config.L32_POOL_RADIUS * lerpf(0.85, 1.0, p.bloom)
	layers.cone(head, 0.05, radius, Color(light.r, light.g, light.b, Config.L32_CONE_ALPHA * strength))
	layers.pool(
		Vector3(p.pos.x, 0.06, p.pos.z), radius, Color(light.r, light.g, light.b, Config.L32_POOL_ALPHA * strength)
	)
	layers.ball(head, 0.3 * s, Color(light.r, light.g, light.b, Config.L32_HEAD_ALPHA * strength))


# 0.3.2 (#49): vines curl up a lamp post as it blooms; a leaf on every other turn of the vine and, near full bloom, a
# few small flowers.
func _draw_vines(p: Prop, s: float, post_top: float) -> void:
	var steps := vine_steps(p.bloom)
	if steps <= 0:
		return
	var y0 := 0.3 * s
	var y1 := post_top - 0.1 * s
	var r := 0.12 * s
	var prev := _at(p, Vector3(r, y0, 0.0))
	var flowers := smoothstep(0.7, 1.0, p.bloom)
	for i: int in range(1, steps + 1):
		var t := float(i) / float(VINE_STEPS)
		var a := t * TAU * VINE_TURNS
		var pt := _at(p, Vector3(cos(a) * r, lerpf(y0, y1, t), sin(a) * r))
		layers.seg(prev, pt, 0.06 * s, VINE)
		if i % 2 == 1:
			var out := _at(p, Vector3(cos(a) * (r + 0.1 * s), lerpf(y0, y1, t), sin(a) * (r + 0.1 * s)))
			layers.box(out, Vector3(0.2, 0.04, 0.13) * s, LEAF, p.yaw - a, 0.4)
		if i % 3 == 0 and flowers > 0.01:
			var tip := _at(p, Vector3(cos(a) * (r + 0.1 * s), lerpf(y0, y1, t) + 0.05 * s, sin(a) * (r + 0.1 * s)))
			layers.ball(tip, 0.08 * s * flowers, FLOWERS[(p.block + i) % FLOWERS.size()])
		prev = pt


# 0.3.2 (#50): how far a bench has turned from riveted grey metal (0) to wooden slats, iron curls and a cushion (1).
static func bench_joy(bloom: float) -> float:
	return smoothstep(0.25, 0.8, bloom)


# 0.3.2 (#50): the cushion's colour index (0 to 2), the same on every run for a bench in the same place.
static func cushion_index(pos: Vector3) -> int:
	return posmod(floori(pos.x + pos.z * 2.0), CUSHIONS.size())


# 0.3.2 (#50): in gloom a riveted grey metal bench: a solid seat and back (slats packed edge to edge), a plate at each
# end and rows of rivets. As it blooms the slats part and turn to wood, the ends narrow to iron legs with an arm and a
# curl, and a small cushion and folded blanket appear in the earthy joy palette (dusty blue, terracotta, sage). Nothing
# on it is a single bright colour.
func _draw_bench(p: Prop) -> void:
	var w := bench_joy(p.bloom)
	var seat := BENCH_GREY.lerp(BENCH_WOOD, w)
	var iron := BENCH_GREY.lerp(BENCH_IRON, w)
	var gap := 0.03 * w
	var slat := 0.5 / float(SEAT_SLATS)
	for k: int in range(SEAT_SLATS):
		var z := -0.25 + slat * (float(k) + 0.5)
		layers.box(
			_at(p, bench_big(Vector3(0.0, 0.45, z))), bench_big(Vector3(1.5, 0.1 - 0.03 * w, slat - gap)), seat, p.yaw
		)
	var rest := 0.36 / float(BACK_SLATS)
	for k: int in range(BACK_SLATS):
		var y := 0.6 + rest * (float(k) + 0.5)
		layers.box(
			_at(p, bench_big(Vector3(0.0, y, -0.22))), bench_big(Vector3(1.5, rest - gap, 0.06)), seat, p.yaw, 0.0, -0.1
		)
	var end_depth := lerpf(0.4, 0.12, w)
	for sx: float in [-0.62, 0.62]:
		layers.box(_at(p, bench_big(Vector3(sx, 0.22, 0.0))), bench_big(Vector3(0.1, 0.44, end_depth)), iron, p.yaw)
		layers.box(_at(p, bench_big(Vector3(sx, 0.62, -0.22))), bench_big(Vector3(0.1, 0.4, 0.08)), iron, p.yaw)
	if w < 0.4:
		_draw_rivets(p)
	else:
		_draw_bench_joy(p, w, iron)


# 0.3.2 (#50): rivets along the seat's front edge and the back's top, and on each end plate.
func _draw_rivets(p: Prop) -> void:
	for k: int in range(5):
		var x := -0.6 + 0.3 * float(k)
		layers.box(_at(p, bench_big(Vector3(x, 0.51, 0.2))), bench_big(Vector3(0.05, 0.03, 0.05)), BENCH_RIVET, p.yaw)
		layers.box(
			_at(p, bench_big(Vector3(x, 0.93, -0.185))), bench_big(Vector3(0.05, 0.05, 0.03)), BENCH_RIVET, p.yaw
		)
	for sx: float in [-0.68, 0.68]:
		for z: float in [-0.12, 0.12]:
			layers.box(
				_at(p, bench_big(Vector3(sx, 0.38, z))), bench_big(Vector3(0.03, 0.05, 0.05)), BENCH_RIVET, p.yaw
			)


# 0.3.2 (#50): the bloomed bench's arms, curled iron ends and cushion (`w` is bench_joy).
func _draw_bench_joy(p: Prop, w: float, iron: Color) -> void:
	var thick := bench_big(Vector3.ONE).x
	var grow := smoothstep(0.4, 1.0, w)
	for sx: float in [-0.62, 0.62]:
		layers.box(_at(p, bench_big(Vector3(sx, 0.66, 0.02))), bench_big(Vector3(0.09, 0.05, 0.46 * grow)), iron, p.yaw)
		# The curl: a short spiral in the plane of the end, at the front of the arm.
		var cy := 0.66 - 0.1 * grow
		var prev := _at(p, bench_big(Vector3(sx, 0.66, 0.25 * grow)))
		for k: int in range(1, 7):
			var a := float(k)
			var r := 0.1 * grow * (1.0 - float(k) / 8.0)
			var pt := _at(p, bench_big(Vector3(sx, cy + cos(a) * r, 0.25 * grow + sin(a) * r)))
			layers.seg(prev, pt, 0.045 * thick * grow, iron)
			prev = pt
	var cushion := CUSHIONS[cushion_index(p.pos)]
	var c := smoothstep(0.55, 0.9, p.bloom)
	if c > 0.01:
		layers.box(
			_at(p, bench_big(Vector3(-0.3, 0.52 + 0.03 * c, 0.0))),
			bench_big(Vector3(0.5, 0.1, 0.36) * c),
			cushion,
			p.yaw
		)
		var blanket := CUSHIONS[(cushion_index(p.pos) + 1) % CUSHIONS.size()].lerp(CREAM, 0.3)
		layers.box(
			_at(p, bench_big(Vector3(0.38, 0.51 + 0.02 * c, 0.02))),
			bench_big(Vector3(0.4, 0.06, 0.3) * c),
			blanket,
			p.yaw
		)


func _draw_planter(p: Prop) -> void:
	layers.box(
		_at(p, big(Vector3(0.0, 0.2, 0.0))), big(Vector3(0.9, 0.4, 0.5)), tone(POT_BARE, POT_WARM, p.bloom), p.yaw
	)
	var s := Config.L31_PROP_SCALE
	var stem := STEM_DEAD.lerp(STEM_LIVE, p.bloom)
	var top := 0.4 + lerpf(0.25, 0.12, p.bloom)
	var size := 0.14 * smoothstep(0.2, 1.0, p.bloom) * s
	var xs: Array[float] = [-0.3, -0.1, 0.12, 0.32]
	for i: int in range(xs.size()):
		var base := _at(p, big(Vector3(xs[i], 0.4, 0.0)))
		var tip := _at(p, big(Vector3(xs[i], top + 0.04 * float(i % 2), 0.0)))
		layers.seg(base, tip, 0.03 * s, stem)
		layers.ball(tip + Vector3(0, 0.03, 0), size, FLOWERS[(p.block + i) % FLOWERS.size()])


func _draw_stall(p: Prop) -> void:
	var wood := tone(WOOD_BARE, WOOD_WARM, p.bloom)
	var s := Config.L31_PROP_SCALE
	layers.box(_at(p, big(Vector3(0.0, 0.35, 0.0))), big(Vector3(1.8, 0.7, 0.9)), wood, p.yaw)
	for sx: float in [-0.85, 0.85]:
		layers.box(_at(p, big(Vector3(sx, 0.95, 0.4))), big(Vector3(0.08, 1.9, 0.08)), wood, p.yaw)
	var open := smoothstep(0.3, 0.7, p.bloom)
	if open < 0.01:
		layers.box(_at(p, big(Vector3(0.0, 1.75, 0.1))), big(Vector3(0.9, 0.04, 0.6)), ROPE_BARE, p.yaw, 0.0, 0.5)
	else:
		for k: int in range(4):
			var col := FLOWERS[0] if k % 2 == 0 else CREAM
			layers.box(
				_at(p, big(Vector3(-0.675 + 0.45 * float(k), 1.9, 0.0))),
				big(Vector3(0.45, 0.06, 1.2 * open)),
				col,
				p.yaw,
				0.0,
				-0.2
			)
	var goods := 0.1 * smoothstep(0.5, 0.9, p.bloom) * s
	for k: int in range(3):
		layers.ball(
			_at(p, big(Vector3(-0.5 + 0.5 * float(k), 0.8, 0.0))), goods, FLOWERS[(p.block + k + 1) % FLOWERS.size()]
		)


# 0.3.1: no bare line in gloom (a line over grey buildings read as a line on the ground). A line shows only once
# the paint has reached it (`unfurl` at least L31_LINE_SHOW); then two posts stand up from the ground and the
# bunting is strung between their tops at roof height.
static func line_shown(unfurl: float) -> bool:
	return unfurl >= Config.L31_LINE_SHOW


# How far the posts have grown (0 on the ground, 1 at roof height) for a line that is `unfurl` unfurled.
static func post_growth(unfurl: float) -> float:
	return smoothstep(Config.L31_LINE_SHOW, Config.L31_LINE_SHOW + Config.L32_LINE_RISE, unfurl)


# 0.3.2 (#42): how far a line that is `unfurl` unfurled hangs at its middle.
static func line_sag(unfurl: float) -> float:
	return lerpf(Config.L32_LINE_SAG_GLOOM, Config.L32_LINE_SAG_BLOOM, unfurl)


# 0.3.2 (#42): how long a flag hangs on a line that is `unfurl` unfurled (drawn size, washing is longer than bunting).
static func flag_length(unfurl: float, washing: bool) -> float:
	return (0.8 if washing else 0.5) * unfurl * Config.L31_LINE_BOLD


# 0.3.2 (#42): the lowest point (metres above the ground) a fully risen line of `unfurl` ever draws: its posts' height
# less its sag at the middle and the longest flag hanging there. Always above the player's height by a margin.
static func line_low_point(unfurl: float, washing: bool) -> float:
	return Config.L32_LINE_POST_HEIGHT - line_sag(unfurl) - flag_length(unfurl, washing)


func _draw_line(l: Line, index: int) -> void:
	if not line_shown(l.unfurl):
		return
	var grow := post_growth(l.unfurl)
	var rise := Vector3(0.0, l.a.y * (1.0 - grow), 0.0)  # The ends rise with the posts as the line unfurls.
	var sag := line_sag(l.unfurl)
	var rope := ROPE_BARE.lerp(ROPE_WARM, l.unfurl)
	var bold := Config.L31_LINE_BOLD
	for tip: Vector3 in [l.a, l.b]:
		var top := tip - rise
		var post_w := 0.18 * bold
		layers.box(
			Vector3(tip.x, top.y * 0.5, tip.z), Vector3(post_w, top.y, post_w), WOOD_BARE.lerp(WOOD_WARM, l.unfurl)
		)
		layers.ball(top + Vector3(0.0, 0.1, 0.0), 0.16 * bold, LAMP_ON.lerp(CREAM, 0.4))
	var flat := Vector3(l.b.x - l.a.x, 0.0, l.b.z - l.a.z)
	var yaw := atan2(flat.x, flat.z)
	var prev := l.a - rise
	for i: int in range(1, LINE_PIECES + 1):
		var t := float(i) / float(LINE_PIECES)
		var pt := (l.a - rise).lerp(l.b - rise, t) - Vector3(0.0, sag * 4.0 * t * (1.0 - t), 0.0)
		layers.seg(prev, pt, 0.04 * bold, rope)
		if i < LINE_PIECES and l.unfurl > 0.05:
			var h := flag_length(l.unfurl, l.washing)
			var w := (0.55 if l.washing else 0.4) * bold
			var col := CLOTHS[(index + i) % CLOTHS.size()] if l.washing else FLOWERS[(index + i) % FLOWERS.size()]
			var sway := sin(time * 1.5 + float(i) + float(index)) * 0.08 * l.unfurl
			layers.box(pt - Vector3(0.0, h * 0.5, 0.0), Vector3(0.03, h, w), col, yaw, sway)
		prev = pt
