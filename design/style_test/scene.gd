class_name StyleScene
extends Node3D
# One scene, two parameters: joy level (0..1) and camera shot.

const MAXC := 24
var toon_shader: Shader = load("res://toon.gdshader")
var ground_shader: Shader = load("res://ground.gdshader")
var post_shader: Shader = load("res://post.gdshader")
var cache := {}
var all_mats: Array = []
var circles_override: Array = []
var people_defs: Array = []
var bldg_defs: Array = []
var cam: Camera3D
var post_mi: MeshInstance3D
var post_mat: ShaderMaterial
var light: DirectionalLight3D
var env: Environment
var player_node: Node3D
var joy_level := 0.0
var pixel_mode := true
var people_nodes: Array = []
var gloomy_nodes: Array = []
var glow_mat: ShaderMaterial
var dyn: Node3D
var border_info := {}
var dark_spots: Array = []
var lineup_nodes: Array = []
var smoke_mat: ShaderMaterial
var gap_mote_mat: ShaderMaterial
var gap_glow_mat: ShaderMaterial
var gap_motes: Array = []
var pulse := 0.0
var gap_glows: Array = []
var haze_mat: ShaderMaterial
var cur_circles: Array = []
var cam_size := 12.0
var cam_tgt := Vector3.ZERO
var cam_pitch := 0.0
var lineup_pos: Array = []
var lineup_circles: Array = []
var landmark := Vector2(8.0, -5.5)
var PLAYER_POS := Vector3(0.6, 0, 3.2)

# ---------------------------------------------------------------- helpers
func C(h: String) -> Color:
	return Color.html(h)

func mat(col: Color, mode := 0, grime := 0.0, emit := 0.0, anchor = null, pat := 0) -> ShaderMaterial:
	var key := "%s|%d|%.2f|%.2f|%s|%d" % [col.to_html(), mode, grime, emit, str(anchor), pat]
	if cache.has(key):
		return cache[key]
	var m := ShaderMaterial.new()
	m.shader = toon_shader
	m.set_shader_parameter("albedo", col)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("grime", grime)
	m.set_shader_parameter("emit", emit)
	m.set_shader_parameter("pat", pat)
	if anchor != null:
		m.set_shader_parameter("use_anchor", 1.0)
		m.set_shader_parameter("anchor", anchor)
	cache[key] = m
	all_mats.append(m)
	return m

func _mi(parent: Node, mesh: Mesh, m: Material, pos: Vector3, rot: Vector3, shadow := true) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.material_override = m
	n.position = pos
	n.rotation = rot
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)
	return n

func box(p: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _mi(p, b, m, pos, rot, shadow)

func cyl(p: Node, r: float, h: float, pos: Vector3, m: Material, rot := Vector3.ZERO, r_top := -1.0, seg := 10, shadow := true) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.bottom_radius = r
	c.top_radius = r if r_top < 0.0 else r_top
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return _mi(p, c, m, pos, rot, shadow)

func sph(p: Node, r: float, pos: Vector3, m: Material, scl := Vector3.ONE, seg := 8, shadow := true) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(seg / 2, 3)
	var n := _mi(p, s, m, pos, Vector3.ZERO, shadow)
	n.scale = scl
	return n

func prism(p: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var pr := PrismMesh.new()
	pr.size = size
	return _mi(p, pr, m, pos, rot, shadow)

func torus(p: Node, ri: float, ro: float, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = ri
	t.outer_radius = ro
	t.rings = 10
	t.ring_segments = 6
	return _mi(p, t, m, pos, rot)

func seg(p: Node, a: Vector3, b: Vector3, r: float, m: Material, sides := 6, shadow := true) -> MeshInstance3D:
	if a.y > b.y:
		var t := a
		a = b
		b = t
	var d := b - a
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = d.length()
	c.radial_segments = sides
	c.rings = 1
	var n := MeshInstance3D.new()
	n.mesh = c
	n.material_override = m
	n.position = (a + b) * 0.5
	var dir := d.normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		n.basis = Basis(Quaternion(Vector3.UP, dir))
	if not shadow:
		n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(n)
	return n

func pipe_run(p: Node, pts: Array, r: float, m: Material, em: Material) -> void:
	for i in range(pts.size() - 1):
		seg(p, pts[i], pts[i + 1], r, m, 8)
	for i in range(pts.size()):
		sph(p, r * 1.25, pts[i], em, Vector3.ONE, 8)

func vine_run(p: Node, pts: Array, r: float, flowers: Array) -> void:
	var stem := mat(C("#56753f"), 2)
	var leaf := mat(C("#6f9552"), 2)
	var leaf2 := mat(C("#8aa55a"), 2)
	var k := 0
	for i in range(pts.size() - 1):
		seg(p, pts[i], pts[i + 1], r * 0.55, stem, 5)
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var L := a.distance_to(b)
		var steps := maxi(int(L / 0.42), 1)
		for s in range(steps + 1):
			var q := a.lerp(b, float(s) / float(steps))
			var off := Vector3(0.08 * (1 if s % 2 == 0 else -1), 0.05, 0.08)
			sph(p, 0.13, q + off, leaf if s % 2 == 0 else leaf2, Vector3(1, 0.55, 1), 6)
			if s % 3 == 1:
				k += 1
				sph(p, 0.1, q + Vector3(0, 0.1, 0.16), mat(flowers[k % flowers.size()], 2), Vector3.ONE, 6)

# ---------------------------------------------------------------- setup
func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.62, 0.72)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_light_color = Color(0.7, 0.72, 0.78)
	env.fog_density = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	light = DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.86, 0.68)
	light.light_energy = 1.0
	light.shadow_enabled = true
	light.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	light.directional_shadow_max_distance = 70.0
	light.shadow_bias = 0.04
	light.shadow_normal_bias = 1.2
	light.shadow_blur = 1.6
	add_child(light)
	light.transform = Transform3D(Basis.looking_at(Vector3(0.8, -0.5, -0.3).normalized()), Vector3(0, 20, 0))

	cam = Camera3D.new()
	cam.far = 160.0
	cam.near = 0.1
	add_child(cam)
	cam.current = true

	post_mat = ShaderMaterial.new()
	post_mat.shader = post_shader
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	post_mi = MeshInstance3D.new()
	post_mi.mesh = q
	post_mi.material_override = post_mat
	post_mi.extra_cull_margin = 16384.0
	post_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cam.add_child(post_mi)

	# ground
	var gm := ShaderMaterial.new()
	gm.shader = ground_shader
	all_mats.append(gm)
	var pl := PlaneMesh.new()
	pl.size = Vector2(160, 160)
	_mi(self, pl, gm, Vector3.ZERO, Vector3.ZERO, false)

	_build_world()
	set_joy(0.0)
	set_shot("topdown")

func _build_world() -> void:
	glow_mat = ShaderMaterial.new()
	glow_mat.shader = load("res://glow.gdshader")
	smoke_mat = ShaderMaterial.new()
	smoke_mat.shader = load("res://glow.gdshader")
	smoke_mat.set_shader_parameter("glow_color", Color(0.07, 0.07, 0.1))
	smoke_mat.set_shader_parameter("strength", 0.45)
	gap_mote_mat = mat(C("#ff7a66"), 0, 0.0, 1.2)
	gap_glow_mat = ShaderMaterial.new()
	gap_glow_mat.shader = load("res://glow.gdshader")
	gap_glow_mat.set_shader_parameter("glow_color", Color(1.0, 0.42, 0.34))
	haze_mat = ShaderMaterial.new()
	haze_mat.shader = load("res://haze.gdshader")
	# buildings: pos, w, d, h, opts, joy threshold, wash radius
	add_building(Vector3(-9.5, 0, -5.5), 7.0, 5.0, 4.0, {"stack": true, "tank": true, "nwin": 2, "roof": "#ad6249", "shutter": "#5f86b0", "door": "#5f86b0"}, 0.85, 6.5)
	add_building(Vector3(8.0, 0, -5.5), 5.4, 4.6, 3.4, {"tank": true, "nwin": 1, "roof": "#5f86b0", "shutter": "#c0604f", "door": "#c0604f", "tankside": -1, "landmark": true}, 0.4, 6.0)
	add_building(Vector3(-0.5, 0, -9.5), 4.2, 3.4, 2.8, {"kiosk": true, "nwin": 1, "roof": "#c0604f", "shutter": "#7f9d62", "door": "#7f9d62"}, 0.7, 5.0)

	# people: x, z, yaw, affinity (0 music, 1 art, 2 nature), pose variant, joy threshold
	add_person(3.6, 4.8, 0.5, 0, 0, 0.0)
	add_person(-3.0, 5.0, -0.4, 1, 1, 0.0)
	add_person(6.6, 1.6, 0.3, 2, 2, 0.3)
	add_person(-1.4, 0.8, 0.0, 2, 0, 0.45)
	add_person(5.6, 7.0, -0.2, 0, 1, 0.5)
	add_person(-6.6, 2.2, 0.6, 1, 2, 0.6)
	add_person(9.4, 4.4, -0.5, 0, 0, 0.7)
	add_person(-9.2, 5.6, 0.4, 2, 1, 0.8)
	add_person(1.4, -1.2, 0.2, 1, 2, 0.9)
	add_person(-5.0, -0.8, -0.3, 0, 2, 0.95)
	add_person(-1.2, 8.2, 0.1, 2, 2, 0.55)
	add_person(8.8, -0.4, 0.4, 1, 1, 0.65)
	for gp in [Vector3(-12.2, 0, 2.4), Vector3(11.6, 0, 7.8), Vector3(-3.4, 0, -1.6)]:
		add_gloomy(gp, 0.5 + gp.x * 0.1)
	player_node = add_player(PLAYER_POS)
	add_projectiles()

	# props
	for pp in [Vector3(-3.4, 0, 2.2), Vector3(9.8, 0, 3.2)]:
		add_grate_pair(pp)
	for lp in [Vector3(-5.8, 0, 7.5), Vector3(5.8, 0, -1.4), Vector3(13.0, 0, -1.0)]:
		add_lamp_pair(lp)
	for tp in [Vector3(-14.5, 0, -2.0), Vector3(14.5, 0, -8.0), Vector3(13.5, 0, 9.0), Vector3(-6.5, 0, -11.5)]:
		add_tree_pair(tp)
	add_far_skyline()
	build_lineup()

# ---------------------------------------------------------------- buildings
func add_building(pos: Vector3, w: float, d: float, h: float, o: Dictionary, thr: float, rad: float) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	build_industrial(root, w, d, h, o)
	build_whimsical(root, w, d, h, o)
	bldg_defs.append({"x": pos.x, "z": pos.z, "thr": thr, "r": rad, "w": w, "d": d, "landmark": o.get("landmark", false)})

func build_industrial(p: Node3D, w: float, d: float, h: float, o: Dictionary) -> void:
	var wall := mat(C("#8d95a1"), 1, 1.0)
	var dark := mat(C("#565d69"), 1, 1.0)
	var roof := mat(C("#4c525d"), 1, 1.0, 0.0, null, 2)
	var steel := mat(C("#a2aab5"), 1, 0.8)
	var pipem := mat(C("#6f7884"), 1, 1.0)
	var pipe_l := mat(C("#8b94a0"), 1, 1.0)
	var rust := mat(C("#7d4c34"), 1, 0.6)
	var hole := mat(C("#1d2129"), 1)
	var kiosk: bool = o.get("kiosk", false)
	box(p, Vector3(w + 0.3, 0.4, d + 0.3), Vector3(0, 0.2, 0), dark)
	box(p, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	var bands := [h * 0.36, h * 0.74]
	for fy in bands:
		box(p, Vector3(w + 0.1, 0.14, d + 0.1), Vector3(0, fy, 0), steel)
		var n := int(w / 0.55)
		for i in range(n):
			var x := -w * 0.5 + 0.3 + i * (w - 0.6) / float(n - 1)
			cyl(p, 0.06, 0.06, Vector3(x, fy, d * 0.5 + 0.07), rust, Vector3(PI / 2, 0, 0), -1.0, 6, false)
	# vertical seams
	var ns := int(w / 1.7)
	for i in range(1, ns):
		box(p, Vector3(0.1, h - 0.4, 0.06), Vector3(-w * 0.5 + i * w / float(ns), h * 0.5 + 0.2, d * 0.5 + 0.03), dark)
	# roof slab, rim, rooftop unit
	box(p, Vector3(w + 0.4, 0.28, d + 0.4), Vector3(0, h + 0.14, 0), roof)
	box(p, Vector3(w + 0.4, 0.18, 0.12), Vector3(0, h + 0.37, d * 0.5 + 0.14), dark)
	box(p, Vector3(w + 0.4, 0.18, 0.12), Vector3(0, h + 0.37, -d * 0.5 - 0.14), dark)
	box(p, Vector3(0.12, 0.18, d + 0.4), Vector3(w * 0.5 + 0.14, h + 0.37, 0), dark)
	box(p, Vector3(0.12, 0.18, d + 0.4), Vector3(-w * 0.5 - 0.14, h + 0.37, 0), dark)
	box(p, Vector3(1.3, 0.7, 1.0), Vector3(w * 0.22, h + 0.63, -d * 0.2), pipe_l)
	for k in range(3):
		box(p, Vector3(0.9, 0.3, 0.7), Vector3(-w * 0.3 + k * 1.1, h + 0.43, d * 0.2), pipe_l)
		box(p, Vector3(0.7, 0.05, 0.5), Vector3(-w * 0.3 + k * 1.1, h + 0.6, d * 0.2), hole)
	cyl(p, 0.3, 0.1, Vector3(w * 0.22, h + 1.02, -d * 0.2), hole)
	# door
	var dx := -w * 0.5 + 1.0
	box(p, Vector3(1.25, 2.15, 0.1), Vector3(dx, 1.075, d * 0.5 + 0.05), dark)
	box(p, Vector3(1.05, 2.0, 0.12), Vector3(dx, 1.0, d * 0.5 + 0.09), steel)
	box(p, Vector3(1.05, 0.12, 0.14), Vector3(dx, 0.6, d * 0.5 + 0.1), dark)
	box(p, Vector3(1.05, 0.12, 0.14), Vector3(dx, 1.5, d * 0.5 + 0.1), dark)
	sph(p, 0.07, Vector3(dx + 0.38, 1.0, d * 0.5 + 0.2), rust, Vector3.ONE, 6)
	# barred windows
	var nwin: int = o.get("nwin", 2)
	for i in range(nwin):
		var x := w * 0.5 - 1.2 - i * 1.9
		var y := h * 0.55
		box(p, Vector3(1.1, 1.0, 0.1), Vector3(x, y, d * 0.5 + 0.05), steel)
		box(p, Vector3(0.92, 0.82, 0.08), Vector3(x, y, d * 0.5 + 0.08), hole)
		for bx in [-0.27, 0.0, 0.27]:
			cyl(p, 0.035, 0.84, Vector3(x + bx, y, d * 0.5 + 0.14), pipe_l, Vector3.ZERO, -1.0, 5, false)
	# pipe run with elbows, valve
	var z := d * 0.5 + 0.28
	var x1 := -w * 0.5 + 2.4
	var x2 := w * 0.5 - 0.4
	if kiosk:
		x1 = -w * 0.5 + 1.8
		x2 = w * 0.5 - 0.35
	var pts := [Vector3(x1, 0.35, z), Vector3(x1, 1.0, z), Vector3(x2, 1.0, z), Vector3(x2, h - 0.45, z), Vector3(-w * 0.5 + 0.6, h - 0.45, z)]
	if kiosk:
		pts = [Vector3(x1, 0.35, z), Vector3(x1, 0.9, z), Vector3(x2, 0.9, z), Vector3(x2, h - 0.4, z)]
	pipe_run(p, pts, 0.11, pipem, pipe_l)
	var vx := (x1 + x2) * 0.5
	var vy: float = 1.0 if not kiosk else 0.9
	sph(p, 0.2, Vector3(vx, vy, z), rust, Vector3.ONE, 8)
	cyl(p, 0.06, 0.35, Vector3(vx, vy + 0.3, z), pipem)
	torus(p, 0.03, 0.17, Vector3(vx, vy + 0.5, z), rust)
	for bx in [x1 + 0.9, x2 - 0.9]:
		box(p, Vector3(0.12, 0.12, 0.26), Vector3(bx, vy, d * 0.5 + 0.12), dark)
	# exhaust fan
	var fx := -w * 0.5 + 1.7
	if kiosk:
		fx = -w * 0.5 + 0.75
	var fy := h - 1.15 if not kiosk else h - 0.7
	var fr := 0.5 if not kiosk else 0.36
	cyl(p, fr, 0.22, Vector3(fx, fy, d * 0.5 + 0.11), steel, Vector3(PI / 2, 0, 0), -1.0, 12)
	cyl(p, fr * 0.82, 0.05, Vector3(fx, fy, d * 0.5 + 0.23), hole, Vector3(PI / 2, 0, 0), -1.0, 12, false)
	box(p, Vector3(fr * 1.5, 0.12, 0.05), Vector3(fx, fy, d * 0.5 + 0.27), pipe_l, Vector3(0, 0, 0.5), false)
	box(p, Vector3(fr * 1.5, 0.12, 0.05), Vector3(fx, fy, d * 0.5 + 0.27), pipe_l, Vector3(0, 0, 0.5 + PI / 2), false)
	sph(p, 0.08, Vector3(fx, fy, d * 0.5 + 0.29), rust, Vector3.ONE, 6)
	# louvered vent
	var vxx := 0.0 if not kiosk else w * 0.5 - 1.3
	var vyy := h * 0.55 if not kiosk else h - 0.8
	if not kiosk:
		vxx = -0.3
	box(p, Vector3(0.95, 0.75, 0.1), Vector3(vxx, vyy, d * 0.5 + 0.05), dark)
	for i in range(4):
		box(p, Vector3(0.84, 0.06, 0.16), Vector3(vxx, vyy - 0.27 + i * 0.18, d * 0.5 + 0.12), pipe_l, Vector3(0.5, 0, 0), false)
	# smokestack
	if o.get("stack", false):
		var sx := -w * 0.5 + 0.9
		var sz := -d * 0.5 + 0.9
		var brick := mat(C("#767c87"), 1, 1.0)
		cyl(p, 0.62, 5.2, Vector3(sx, h + 0.28 + 2.6, sz), brick, Vector3.ZERO, 0.42, 10)
		for by in [1.2, 2.9]:
			cyl(p, 0.56, 0.16, Vector3(sx, h + 0.28 + by, sz), steel, Vector3.ZERO, -1.0, 10)
		cyl(p, 0.5, 0.22, Vector3(sx, h + 0.28 + 5.2, sz), mat(C("#2d3037"), 1), Vector3.ZERO, -1.0, 10)
		var smoke := mat(C("#4f5560"), 1, 0.0)
		sph(p, 0.55, Vector3(sx + 0.3, h + 6.2, sz), smoke, Vector3(1.2, 0.9, 1.0), 8, false)
		sph(p, 0.75, Vector3(sx + 1.0, h + 7.1, sz), smoke, Vector3(1.2, 0.9, 1.0), 8, false)
		sph(p, 0.95, Vector3(sx + 2.0, h + 7.8, sz), smoke, Vector3(1.3, 0.85, 1.0), 8, false)
	# gas tank
	if o.get("tank", false):
		var side: float = o.get("tankside", 1.0)
		var tx := side * (w * 0.5 + 1.5)
		var tz := d * 0.5 - 1.0
		var tank := mat(C("#7b838f"), 1, 1.0)
		cyl(p, 1.05, 2.5, Vector3(tx, 1.25, tz), tank, Vector3.ZERO, -1.0, 12)
		sph(p, 1.05, Vector3(tx, 2.5, tz), tank, Vector3(1, 0.45, 1), 12)
		for ty in [0.6, 1.9]:
			cyl(p, 1.09, 0.13, Vector3(tx, ty, tz), steel, Vector3.ZERO, -1.0, 12)
		# ladder
		box(p, Vector3(0.05, 2.5, 0.05), Vector3(tx - 0.2 + 0.0, 1.25, tz + 1.12), dark, Vector3(0.0, 0, 0), false)
		box(p, Vector3(0.05, 2.5, 0.05), Vector3(tx + 0.2, 1.25, tz + 1.12), dark, Vector3.ZERO, false)
		for ly in range(5):
			box(p, Vector3(0.45, 0.04, 0.05), Vector3(tx, 0.4 + ly * 0.5, tz + 1.12), dark, Vector3.ZERO, false)
		# connecting pipe + valve
		seg(p, Vector3(tx - side * 1.0, 0.9, tz - 0.4), Vector3(side * (w * 0.5), 0.9, tz - 0.4), 0.1, pipem, 8)
		sph(p, 0.18, Vector3(tx - side * 1.6, 0.9, tz - 0.4), rust)
		torus(p, 0.03, 0.16, Vector3(tx - side * 1.6, 1.25, tz - 0.4), rust)
		cyl(p, 0.05, 0.3, Vector3(tx - side * 1.6, 1.08, tz - 0.4), pipem)

func build_whimsical(p: Node3D, w: float, d: float, h: float, o: Dictionary) -> void:
	var kiosk: bool = o.get("kiosk", false)
	var plaster := mat(C("#f1dfbd"), 2)
	var timber := mat(C("#7d5438"), 2)
	var stone := mat(C("#bba88c"), 2)
	var roofm := mat(C(o.get("roof", "#ad6249")), 2, 0.0, 0.0, null, 1)
	var roof_dk := mat(C(o.get("roof", "#ad6249")).darkened(0.25), 2)
	var shut := mat(C(o.get("shutter", "#5f86b0")), 2)
	var glow := mat(C("#ffd88a"), 2, 0.0, 0.7)
	var leaf := mat(C("#6f9552"), 2)
	var flowers := [C("#d9667a"), C("#e5b04a"), C("#f3ead2"), C("#c0604f")]
	box(p, Vector3(w + 0.3, 0.4, d + 0.3), Vector3(0, 0.2, 0), stone)
	box(p, Vector3(w, h, d), Vector3(0, h * 0.5, 0), plaster)
	# timber frame
	var nposts := int(w / 1.7) + 1
	for i in range(nposts + 1):
		var x := -w * 0.5 + i * w / float(nposts)
		box(p, Vector3(0.16, h - 0.2, 0.1), Vector3(x, h * 0.5 + 0.1, d * 0.5 + 0.04), timber)
	box(p, Vector3(w + 0.1, 0.22, d + 0.1), Vector3(0, h - 0.1, 0), timber)
	# roof
	var rh := 1.9
	if kiosk:
		var rr := sqrt(w * w + d * d) * 0.5 + 0.15
		cyl(p, rr, 1.2, Vector3(0, h + 0.6, 0), roofm, Vector3.ZERO, 0.08, 8)
		sph(p, 0.18, Vector3(0, h + 1.32, 0), mat(C("#e5b04a"), 2), Vector3.ONE, 6)
		cyl(p, rr + 0.04, 0.12, Vector3(0, h + 0.06, 0), roof_dk, Vector3.ZERO, -1.0, 8)
	else:
		prism(p, Vector3(d + 1.1, rh, w + 1.0), Vector3(0, h + rh * 0.5, 0), roofm, Vector3(0, PI / 2, 0))
		cyl(p, 0.11, w + 1.1, Vector3(0, h + rh, 0), roof_dk, Vector3(0, 0, PI / 2), -1.0, 6)
		box(p, Vector3(w + 1.0, 0.14, 0.2), Vector3(0, h + 0.07, d * 0.5 + 0.5), roof_dk, Vector3(0.55, 0, 0) * 0.0)
	# chimney
	if o.get("stack", false):
		var cx := -w * 0.5 + 0.9
		var cz := -d * 0.5 + 0.9
		var ch := mat(C("#c4795a"), 2)
		var cc := mat(C("#f1dfbd"), 2)
		box(p, Vector3(0.85, 4.6, 0.85), Vector3(cx, h + 2.3, cz), ch)
		for by in [1.2, 2.6, 4.0]:
			box(p, Vector3(0.92, 0.28, 0.92), Vector3(cx, h + by, cz), cc)
		prism(p, Vector3(1.1, 0.5, 1.1), Vector3(cx, h + 4.85, cz), roof_dk)
		var puff := mat(C("#f6ecd8"), 2)
		sph(p, 0.45, Vector3(cx + 0.3, h + 5.9, cz), puff, Vector3(1.2, 0.9, 1.0), 8, false)
		sph(p, 0.62, Vector3(cx + 1.0, h + 6.7, cz), puff, Vector3(1.2, 0.9, 1.0), 8, false)
		sph(p, 0.8, Vector3(cx + 2.0, h + 7.3, cz), puff, Vector3(1.3, 0.85, 1.0), 8, false)
	if o.get("landmark", false):
		var gold_f := mat(C("#f2c14e"), 2, 0.0, 0.5)
		seg(p, Vector3(w * 0.5 - 0.5, h + 0.2, 0.0), Vector3(w * 0.5 - 0.5, h + 3.3, 0.0), 0.05, timber)
		prism(p, Vector3(0.9, 0.6, 0.05), Vector3(w * 0.5 - 0.05, h + 3.0, 0.0), gold_f, Vector3(0, 0, -PI / 2), false)
		sph(p, 0.1, Vector3(w * 0.5 - 0.5, h + 3.35, 0.0), gold_f, Vector3.ONE, 6, false)
	# door
	var dx := -w * 0.5 + 1.0
	var doorc := mat(C(o.get("door", "#5f86b0")), 2)
	cyl(p, 0.68, 0.1, Vector3(dx, 1.95, d * 0.5 + 0.05), timber, Vector3(PI / 2, 0, 0), -1.0, 12)
	box(p, Vector3(1.36, 1.95, 0.1), Vector3(dx, 0.975, d * 0.5 + 0.05), timber)
	cyl(p, 0.52, 0.12, Vector3(dx, 1.95, d * 0.5 + 0.09), doorc, Vector3(PI / 2, 0, 0), -1.0, 12)
	box(p, Vector3(1.04, 1.95, 0.12), Vector3(dx, 0.975, d * 0.5 + 0.09), doorc)
	sph(p, 0.07, Vector3(dx + 0.36, 1.0, d * 0.5 + 0.2), mat(C("#e5b04a"), 2), Vector3.ONE, 6)
	box(p, Vector3(1.5, 0.12, 0.5), Vector3(dx, 0.06, d * 0.5 + 0.35), stone)
	# lantern next to door
	var lx := dx + 1.0
	seg(p, Vector3(lx, 2.55, d * 0.5 + 0.02), Vector3(lx, 2.55, d * 0.5 + 0.4), 0.04, timber)
	box(p, Vector3(0.28, 0.4, 0.28), Vector3(lx, 2.25, d * 0.5 + 0.4), mat(C("#ffcf70"), 2, 0.0, 1.3))
	prism(p, Vector3(0.4, 0.2, 0.4), Vector3(lx, 2.55, d * 0.5 + 0.4), mat(C("#3f5a52"), 2))
	# windows with shutters and flower boxes
	var nwin: int = o.get("nwin", 2)
	for i in range(nwin):
		var x := w * 0.5 - 1.2 - i * 1.9
		var y := h * 0.55
		box(p, Vector3(1.1, 1.0, 0.1), Vector3(x, y, d * 0.5 + 0.05), timber)
		box(p, Vector3(0.9, 0.8, 0.08), Vector3(x, y, d * 0.5 + 0.08), glow)
		box(p, Vector3(0.06, 0.82, 0.05), Vector3(x, y, d * 0.5 + 0.13), timber)
		box(p, Vector3(0.92, 0.06, 0.05), Vector3(x, y, d * 0.5 + 0.13), timber)
		for sx in [-0.72, 0.72]:
			box(p, Vector3(0.32, 1.0, 0.08), Vector3(x + sx, y, d * 0.5 + 0.1), shut)
		box(p, Vector3(1.2, 0.26, 0.32), Vector3(x, y - 0.62, d * 0.5 + 0.18), timber)
		for k in range(5):
			var fxx := x - 0.46 + k * 0.23
			sph(p, 0.12, Vector3(fxx, y - 0.4, d * 0.5 + 0.2), leaf, Vector3(1, 0.8, 1), 6, false)
			sph(p, 0.1, Vector3(fxx, y - 0.28, d * 0.5 + 0.26), mat(flowers[(k + i) % flowers.size()], 2), Vector3.ONE, 6, false)
	# vines where pipes were
	var z := d * 0.5 + 0.2
	var x1 := -w * 0.5 + 2.4
	var x2 := w * 0.5 - 0.4
	if kiosk:
		x1 = -w * 0.5 + 1.8
		x2 = w * 0.5 - 0.35
	var pts := [Vector3(x1, 0.35, z), Vector3(x1, 1.0, z), Vector3(x2, 1.0, z), Vector3(x2, h - 0.45, z), Vector3(-w * 0.5 + 0.6, h - 0.45, z)]
	if kiosk:
		pts = [Vector3(x1, 0.35, z), Vector3(x1, 0.9, z), Vector3(x2, 0.9, z), Vector3(x2, h - 0.4, z)]
	vine_run(p, pts, 0.11, flowers)
	var vx := (x1 + x2) * 0.5
	var vy: float = 1.0 if not kiosk else 0.9
	for k in range(6):
		var a := k * TAU / 6.0
		sph(p, 0.11, Vector3(vx + cos(a) * 0.2, vy + 0.15 + sin(a) * 0.2, z + 0.12), mat(C("#f3ead2"), 2), Vector3.ONE, 6, false)
	sph(p, 0.1, Vector3(vx, vy + 0.15, z + 0.2), mat(C("#e5b04a"), 2), Vector3.ONE, 6, false)
	# pinwheel where the fan was
	var fx := -w * 0.5 + 1.7
	var fy := h - 1.15
	if kiosk:
		fx = -w * 0.5 + 0.75
		fy = h - 0.7
	seg(p, Vector3(fx, fy - 0.6, d * 0.5 + 0.1), Vector3(fx, fy, d * 0.5 + 0.35), 0.035, timber)
	var pw := [C("#d9667a"), C("#e5b04a"), C("#5f86b0"), C("#f3ead2")]
	for k in range(4):
		var a := k * PI / 2.0
		prism(p, Vector3(0.36, 0.36, 0.04), Vector3(fx + sin(-a) * 0.17, fy + cos(a) * 0.17, d * 0.5 + 0.4), mat(pw[k], 2), Vector3(0, 0, a), false)
	sph(p, 0.05, Vector3(fx, fy, d * 0.5 + 0.44), mat(C("#7d5438"), 2), Vector3.ONE, 6, false)
	# birdhouse where the vent was
	var bx := -0.3 if not kiosk else w * 0.5 - 1.3
	var by := h * 0.55 if not kiosk else h - 0.8
	box(p, Vector3(0.06, 0.12, 0.3), Vector3(bx, by - 0.28, d * 0.5 + 0.15), timber)
	box(p, Vector3(0.5, 0.5, 0.42), Vector3(bx, by, d * 0.5 + 0.3), mat(C("#d8a35a"), 2))
	prism(p, Vector3(0.7, 0.34, 0.55), Vector3(bx, by + 0.4, d * 0.5 + 0.3), mat(C("#5f86b0"), 2), Vector3.ZERO)
	cyl(p, 0.09, 0.04, Vector3(bx, by + 0.02, d * 0.5 + 0.52), mat(C("#2a1f1c"), 2), Vector3(PI / 2, 0, 0), -1.0, 8, false)
	cyl(p, 0.025, 0.2, Vector3(bx, by - 0.2, d * 0.5 + 0.58), timber, Vector3(PI / 2, 0, 0), -1.0, 5, false)
	# bunting along the eave
	var n := int(w / 0.42)
	var cols := [C("#d9667a"), C("#e5b04a"), C("#5f86b0"), C("#f3ead2"), C("#7f9d62")]
	var prev := Vector3.ZERO
	for i in range(n + 1):
		var t := float(i) / float(n)
		var xx := lerpf(-w * 0.5 + 0.1, w * 0.5 - 0.1, t)
		var yy := h - 0.28 - 0.4 * 4.0 * t * (1.0 - t)
		var pt := Vector3(xx, yy, d * 0.5 + 0.2)
		if i > 0:
			seg(p, prev, pt, 0.02, timber, 4, false)
			prism(p, Vector3(0.3, 0.34, 0.03), (prev + pt) * 0.5 + Vector3(0, -0.18, 0), mat(cols[i % cols.size()], 2), Vector3(0, 0, PI), false)
		prev = pt
	# kiosk: striped awning + kettle
	if kiosk:
		for i in range(8):
			var xs := -w * 0.5 + (i + 0.5) * w / 8.0
			box(p, Vector3(w / 8.0, 0.08, 1.0), Vector3(xs, h - 0.3, d * 0.5 + 0.55), mat(C("#d9667a") if i % 2 == 0 else C("#f3ead2"), 2), Vector3(0.35, 0, 0))
			cyl(p, w / 16.0, 0.08, Vector3(xs, h - 0.52, d * 0.5 + 1.0), mat(C("#d9667a") if i % 2 == 0 else C("#f3ead2"), 2), Vector3(PI / 2, 0, 0), -1.0, 8)
		box(p, Vector3(w * 0.9, 0.12, 0.5), Vector3(0, 1.05, d * 0.5 + 0.35), timber)
		sph(p, 0.26, Vector3(w * 0.25, 1.4, d * 0.5 + 0.4), mat(C("#c0604f"), 2), Vector3(1, 0.9, 1), 8)
		seg(p, Vector3(w * 0.25 + 0.2, 1.45, d * 0.5 + 0.4), Vector3(w * 0.25 + 0.42, 1.6, d * 0.5 + 0.4), 0.05, mat(C("#c0604f"), 2))
		sph(p, 0.07, Vector3(w * 0.25, 1.72, d * 0.5 + 0.4), mat(C("#e5b04a"), 2), Vector3.ONE, 6)
	# flower barrel where the tank was
	if o.get("tank", false):
		var side: float = o.get("tankside", 1.0)
		var tx := side * (w * 0.5 + 1.5)
		var tz := d * 0.5 - 1.0
		var wood := mat(C("#9a6a46"), 2)
		cyl(p, 0.8, 1.5, Vector3(tx, 0.75, tz), wood, Vector3.ZERO, 0.8, 12)
		sph(p, 0.98, Vector3(tx, 0.75, tz), wood, Vector3(1, 0.85, 1), 12)
		for ty in [0.35, 1.15]:
			cyl(p, 0.96, 0.1, Vector3(tx, ty, tz), mat(C("#4c4a50"), 2), Vector3.ZERO, -1.0, 12)
		sph(p, 1.0, Vector3(tx, 1.5, tz), leaf, Vector3(1, 0.55, 1), 10)
		for k in range(16):
			var a := k * 2.4
			var rr := 0.2 + 0.7 * fmod(k * 0.37, 1.0)
			sph(p, 0.16, Vector3(tx + cos(a) * rr, 1.8 + 0.1 * fmod(k * 0.7, 1.0), tz + sin(a) * rr), mat(flowers[k % flowers.size()], 2), Vector3.ONE, 6, false)

# ---------------------------------------------------------------- props
func add_grate_pair(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var dk := mat(C("#14171d"), 1)
	var st := mat(C("#6a727e"), 1, 0.8)
	box(root, Vector3(1.5, 0.06, 1.5), Vector3(0, 0.03, 0), dk)
	for i in range(6):
		box(root, Vector3(1.4, 0.05, 0.1), Vector3(0, 0.08, -0.55 + i * 0.22), st, Vector3.ZERO, false)
	var stone := mat(C("#bba88c"), 2)
	var soil := mat(C("#6d4a36"), 2)
	for s in [-1, 1]:
		box(root, Vector3(1.7, 0.28, 0.2), Vector3(0, 0.14, s * 0.75), stone)
		box(root, Vector3(0.2, 0.28, 1.4), Vector3(s * 0.75, 0.14, 0), stone)
	box(root, Vector3(1.3, 0.3, 1.3), Vector3(0, 0.15, 0), soil)
	var fl := [C("#d9667a"), C("#e5b04a"), C("#f3ead2"), C("#5f86b0"), C("#c0604f")]
	for k in range(12):
		var x := -0.5 + fmod(k * 0.37, 1.0)
		var z := -0.5 + fmod(k * 0.61, 1.0)
		seg(root, Vector3(x, 0.3, z), Vector3(x, 0.55 + 0.15 * fmod(k * 0.3, 1.0), z), 0.025, mat(C("#56753f"), 2), 4, false)
		sph(root, 0.12, Vector3(x, 0.62 + 0.15 * fmod(k * 0.3, 1.0), z), mat(fl[k % fl.size()], 2), Vector3.ONE, 6, false)
		sph(root, 0.15, Vector3(x * 0.8, 0.38, z * 0.8), mat(C("#6f9552"), 2), Vector3(1, 0.6, 1), 6, false)

func add_lamp_pair(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var dk := mat(C("#323741"), 1, 0.6)
	cyl(root, 0.2, 0.3, Vector3(0, 0.15, 0), dk, Vector3.ZERO, 0.12, 8)
	cyl(root, 0.08, 3.4, Vector3(0, 1.7, 0), dk, Vector3.ZERO, -1.0, 6)
	box(root, Vector3(0.8, 0.08, 0.08), Vector3(0.35, 3.4, 0), dk)
	cyl(root, 0.35, 0.28, Vector3(0.7, 3.25, 0), dk, Vector3.ZERO, 0.08, 8)
	sph(root, 0.14, Vector3(0.7, 3.08, 0), mat(C("#dfe8f2"), 1, 0.0, 1.0), Vector3.ONE, 6, false)
	var wood := mat(C("#7d5438"), 2)
	cyl(root, 0.1, 3.0, Vector3(0, 1.5, 0), wood, Vector3.ZERO, -1.0, 6)
	seg(root, Vector3(0, 3.0, 0), Vector3(0.45, 3.2, 0), 0.05, wood, 5)
	seg(root, Vector3(0.45, 3.2, 0), Vector3(0.45, 2.95, 0), 0.03, wood, 4)
	box(root, Vector3(0.32, 0.42, 0.32), Vector3(0.45, 2.7, 0), mat(C("#ffcf70"), 2, 0.0, 1.3))
	prism(root, Vector3(0.46, 0.22, 0.46), Vector3(0.45, 3.0, 0), mat(C("#3f5a52"), 2))
	var fl := [C("#d9667a"), C("#e5b04a"), C("#f3ead2")]
	box(root, Vector3(0.5, 0.25, 0.5), Vector3(0, 0.13, 0), mat(C("#ad6249"), 2))
	for k in range(5):
		sph(root, 0.11, Vector3(-0.17 + 0.085 * k, 0.34, 0.1 * ((k % 2) * 2 - 1)), mat(fl[k % 3], 2), Vector3.ONE, 6, false)

func add_tree_pair(pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var dead := mat(C("#272a31"), 1, 0.4)
	cyl(root, 0.28, 1.6, Vector3(0, 0.8, 0), dead, Vector3.ZERO, 0.16, 6)
	seg(root, Vector3(0, 1.3, 0), Vector3(0.6, 2.0, 0.1), 0.07, dead, 4)
	seg(root, Vector3(0, 1.1, 0), Vector3(-0.5, 1.8, -0.1), 0.06, dead, 4)
	var trunk := mat(C("#7d5438"), 2)
	cyl(root, 0.3, 2.0, Vector3(0, 1.0, 0), trunk, Vector3.ZERO, 0.2, 7)
	sph(root, 1.5, Vector3(0, 3.0, 0), mat(C("#7f9d62"), 2), Vector3(1, 0.9, 1), 9)
	sph(root, 1.1, Vector3(0.8, 3.6, 0.3), mat(C("#93ae6f"), 2), Vector3.ONE, 8)
	sph(root, 1.0, Vector3(-0.8, 2.7, 0.5), mat(C("#6f9552"), 2), Vector3.ONE, 8)
	for k in range(7):
		var a := k * 2.1
		sph(root, 0.14, Vector3(cos(a) * 1.3, 2.6 + fmod(k * 0.5, 1.2), sin(a) * 1.3 + 0.4), mat(C("#d9667a") if k % 2 == 0 else C("#f3ead2"), 2), Vector3.ONE, 6, false)

func add_far_skyline() -> void:
	var m := mat(C("#8d97a6"), 0)
	var m2 := mat(C("#7d8798"), 0)
	var xs := [-46, -36, -27, -18, -8, 4, 14, 24, 34, 44]
	for i in range(xs.size()):
		var hh := 6.0 + fmod(i * 7.3, 9.0)
		box(self, Vector3(8, hh, 6), Vector3(xs[i], hh * 0.5, -48), m if i % 2 == 0 else m2, Vector3.ZERO, false)
	for sx in [-30.0, 10.0, 38.0]:
		cyl(self, 1.2, 22.0, Vector3(sx, 11.0, -52), m2, Vector3.ZERO, 0.8, 8, false)


# ---------------------------------------------------------------- noise port (mirrors common.gdshaderinc)
# The joy field noise uses an integer hash so GDScript can compute exactly the same wash edge as the shaders.
# That lets the living border, the minimap and the people all agree with what the ground shows.
func ihash(x: int, y: int) -> float:
	var h: int = ((x & 0xFFFFFFFF) * 374761393 + (y & 0xFFFFFFFF) * 668265263) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h & 65535) / 65535.0

func vnoise_i(px: float, py: float) -> float:
	var fx0 := floorf(px)
	var fy0 := floorf(py)
	var ix := int(fx0)
	var iy := int(fy0)
	var fx := px - fx0
	var fy := py - fy0
	fx = fx * fx * (3.0 - 2.0 * fx)
	fy = fy * fy * (3.0 - 2.0 * fy)
	return lerpf(lerpf(ihash(ix, iy), ihash(ix + 1, iy), fx), lerpf(ihash(ix, iy + 1), ihash(ix + 1, iy + 1), fx), fy)

func joy_field(p: Vector2, cs: Array) -> float:
	var m := -100.0
	for c in cs:
		m = maxf(m, c.z - Vector2(c.x, c.y).distance_to(p))
	m += (vnoise_i(p.x * 0.55, p.y * 0.55) - 0.5) * 2.0 + (vnoise_i(p.x * 1.7, p.y * 1.7) - 0.5) * 0.55
	return m

# ---------------------------------------------------------------- people
const AFF_COAT := ["#5f86b0", "#c4604f", "#7f9d62"]   # music dusty blue, art rose/terracotta, nature sage
const AFF_PIP := ["#7fa6d6", "#e0806c", "#97b872"]    # the small affinity pip grey people carry
const AFF_NAME := ["music", "art", "nature"]

func bm(col: Color, grey: bool, a: Vector3, grime := 0.0, emit := 0.0) -> ShaderMaterial:
	return mat(col, 1 if grey else 2, grime, emit, a)

func add_person(x: float, z: float, yaw: float, aff: int, v: int, thr: float, parent: Node = null, register := true) -> Node3D:
	var pos := Vector3(x, 0, z)
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	if parent == null:
		parent = self
	parent.add_child(root)
	var g := Node3D.new()
	root.add_child(g)
	var j := Node3D.new()
	root.add_child(j)
	_body_grey(g, pos, aff, v)
	_body_joy(j, pos, aff, v)
	if register:
		people_defs.append({"x": x, "z": z, "thr": thr, "aff": aff})
		people_nodes.append(root)
	return root

func _face(p: Node3D, y: float, em: Material, scl := 1.0) -> void:
	for sx in [-0.085, 0.085]:
		sph(p, 0.04 * scl, Vector3(sx, y, 0.225), em, Vector3.ONE, 5, false)

# the thing a person carries, built along local -Y from the hand
func _item(parent: Node3D, aff: int, grey: bool, a: Vector3, scl: float) -> void:
	var n := Node3D.new()
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	var tint := C(AFF_PIP[aff])
	var g1 := C("#8c9098").lerp(tint, 0.3)
	var g2 := C("#6a6e76").lerp(tint, 0.2)
	match aff:
		0: # little brass horn
			var brass := bm(g1 if grey else C("#e8b24a"), grey, a, 0.0, 0.0 if grey else 0.12)
			cyl(n, 0.045, 0.3, Vector3(0, -0.15, 0), brass, Vector3.ZERO, -1.0, 6, false)
			cyl(n, 0.15, 0.2, Vector3(0, -0.4, 0), brass, Vector3.ZERO, 0.05, 8, false)
			sph(n, 0.06, Vector3(0, 0.0, 0), brass, Vector3.ONE, 5, false)
		1: # paintbrush
			var wood := bm(g2 if grey else C("#8a5a3a"), grey, a)
			var metal := bm(g1 if grey else C("#c9c2b0"), grey, a)
			var paint := bm(g1.lightened(0.1) if grey else C("#f2c04c"), grey, a, 0.0, 0.0 if grey else 0.2)
			cyl(n, 0.03, 0.44, Vector3(0, -0.22, 0), wood, Vector3.ZERO, -1.0, 5, false)
			cyl(n, 0.05, 0.1, Vector3(0, -0.47, 0), metal, Vector3.ZERO, -1.0, 6, false)
			sph(n, 0.08, Vector3(0, -0.58, 0), paint, Vector3(1.0, 1.5, 1.0), 6, false)
		2: # flower on a stem
			var stem := bm(g2 if grey else C("#56753f"), grey, a)
			var petal := bm(g1.lightened(0.08) if grey else C("#f08aa0"), grey, a, 0.0, 0.0 if grey else 0.12)
			var mid := bm(g2 if grey else C("#f2c04c"), grey, a)
			cyl(n, 0.025, 0.34, Vector3(0, -0.17, 0), stem, Vector3.ZERO, -1.0, 5, false)
			for k in range(6):
				var ang := k * TAU / 6.0
				sph(n, 0.085, Vector3(cos(ang) * 0.11, -0.38, sin(ang) * 0.11), petal, Vector3.ONE, 5, false)
			sph(n, 0.075, Vector3(0, -0.38, 0), mid, Vector3.ONE, 5, false)

func _body_grey(p: Node3D, a: Vector3, aff: int, v: int) -> void:
	# stiff, upright, drab: straight legs, flat cap. Affinity shows as a muted scarf, a cap band, a pip and a
	# grey version of their object held out in front at a readable size.
	var skin := bm(C("#b4a9a1"), true, a)
	var coat := bm(C(["#5b6370", "#4f5662", "#69707b"][v % 3]), true, a, 0.5)
	var coat_d := bm(C("#3d434e"), true, a, 0.4)
	var pants := bm(C("#383d47"), true, a, 0.3)
	var cap := bm(C("#2b2f37"), true, a, 0.3)
	var eye := bm(C("#1b1d22"), true, a)
	var brass := bm(C("#a9a28a"), true, a)
	var tint := C("#6a707c").lerp(C(AFF_PIP[aff]), 0.42)
	var scarf := bm(tint, true, a, 0.0, 0.12)
	var pip := bm(C(AFF_PIP[aff]), true, a, 0.0, 0.35)
	for sx in [-0.12, 0.12]:
		box(p, Vector3(0.2, 0.62, 0.22), Vector3(sx, 0.31, 0), pants)
		box(p, Vector3(0.22, 0.1, 0.3), Vector3(sx, 0.05, 0.04), cap)
	box(p, Vector3(0.54, 0.86, 0.36), Vector3(0, 1.0, 0), coat)
	box(p, Vector3(0.58, 0.14, 0.4), Vector3(0, 0.6, 0), coat_d)
	box(p, Vector3(0.62, 0.12, 0.36), Vector3(0, 1.38, 0), coat_d)
	box(p, Vector3(0.1, 0.5, 0.04), Vector3(0, 1.1, 0.19), coat_d, Vector3.ZERO, false)
	# muted affinity scarf (collar + a short tail down the chest)
	box(p, Vector3(0.6, 0.14, 0.42), Vector3(0, 1.47, 0.0), scarf)
	box(p, Vector3(0.12, 0.34, 0.05), Vector3(0.16, 1.26, 0.2), scarf, Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.37, 1.38, 0)
		p.add_child(arm)
		if sx > 0.0:
			# forearm bent forward, holding the object up
			arm.rotation.x = -1.3
			box(arm, Vector3(0.13, 0.74, 0.17), Vector3(0, -0.37, 0), coat)
			sph(arm, 0.08, Vector3(0, -0.78, 0), skin, Vector3.ONE, 5)
			var held := Node3D.new()
			held.position = Vector3(0, -0.8, 0.0)
			held.rotation.x = 4.7
			arm.add_child(held)
			held.rotation.z = -0.45
			_item(held, aff, true, a, 1.1)
		else:
			arm.rotation.z = sx * 0.04
			box(arm, Vector3(0.13, 0.74, 0.17), Vector3(0, -0.37, 0), coat)
			sph(arm, 0.08, Vector3(0, -0.78, 0), skin, Vector3.ONE, 5)
	sph(p, 0.04, Vector3(0.14, 1.0, 0.19), brass, Vector3.ONE, 5, false)
	sph(p, 0.09, Vector3(-0.15, 1.28, 0.2), pip, Vector3.ONE, 5, false)
	sph(p, 0.23, Vector3(0, 1.66, 0.01), skin, Vector3.ONE, 8)
	_face(p, 1.67, eye)
	cyl(p, 0.25, 0.1, Vector3(0, 1.85, 0), cap, Vector3.ZERO, -1.0, 8)
	cyl(p, 0.26, 0.05, Vector3(0, 1.8, 0), scarf, Vector3.ZERO, -1.0, 8, false)
	box(p, Vector3(0.3, 0.03, 0.16), Vector3(0, 1.8, 0.23), cap, Vector3.ZERO, false)
	sph(p, 0.06, Vector3(0.0, 1.86, 0.25), pip, Vector3.ONE, 5, false)

func _body_joy(p: Node3D, a: Vector3, aff: int, v: int) -> void:
	# relaxed, tilted, dancing; affinity-coloured coat, playful hat, carries their thing high
	var skins := ["#e2b18c", "#c98a63", "#a46a47", "#ecc19c"]
	var skin := bm(C(skins[(v + aff) % 4]), false, a)
	var coat := bm(C(AFF_COAT[aff]), false, a)
	var acc := bm(C(["#f1dfbd", "#f1dfbd", "#8a6a45"][aff]), false, a)
	var pants := bm(C("#6d5a4b"), false, a)
	var boots := bm(C("#5a3d2c"), false, a)
	var eye := bm(C("#2a1f1c"), false, a)
	var lean := 1.0 if v % 2 == 0 else -1.0
	var hop := 0.14 if v == 0 else (0.0 if v == 1 else 0.07)
	for sx in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.14, 0.62 + hop, 0)
		leg.rotation.z = sx * (0.2 if v != 1 else 0.1) * lean
		leg.rotation.x = (0.35 if (sx > 0.0 and v == 0) else 0.0)
		p.add_child(leg)
		box(leg, Vector3(0.22, 0.62, 0.24), Vector3(0, -0.31, 0), pants)
		box(leg, Vector3(0.24, 0.1, 0.3), Vector3(0, -0.57, 0.03), boots)
	var up := Node3D.new()
	up.position = Vector3(0, 0.62 + hop, 0)
	up.rotation.z = 0.15 * lean
	up.rotation.y = 0.25 * lean
	p.add_child(up)
	box(up, Vector3(0.56, 0.74, 0.38), Vector3(0, 0.37, 0), coat)
	box(up, Vector3(0.58, 0.12, 0.4), Vector3(0, 0.04, 0), acc)
	box(up, Vector3(0.62, 0.16, 0.2), Vector3(0, 0.62, 0.12), acc)
	var holder := 1.0 if v % 2 == 0 else -1.0
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.37, 0.68, 0)
		var carrying: bool = (sx == holder)
		if carrying:
			arm.rotation.z = sx * (2.55 if v != 1 else 2.0)
		else:
			arm.rotation.z = sx * (1.5 if v == 2 else 0.5)   # other arm flung out or relaxed
		up.add_child(arm)
		box(arm, Vector3(0.14, 0.62, 0.17), Vector3(0, -0.28, 0), coat)
		sph(arm, 0.085, Vector3(0, -0.62, 0), skin, Vector3.ONE, 5)
		if carrying:
			var held := Node3D.new()
			held.position = Vector3(0, -0.64, 0)
			arm.add_child(held)
			_item(held, aff, false, a, 1.0)
	var head := Node3D.new()
	head.position = Vector3(0, 0.98, 0.02)
	head.rotation.z = -0.2 * lean
	up.add_child(head)
	sph(head, 0.23, Vector3.ZERO, skin, Vector3.ONE, 8)
	_face(head, 0.01, eye)
	sph(head, 0.05, Vector3(0.0, -0.07, 0.21), bm(C("#c4604f"), false, a), Vector3(1.8, 0.5, 0.6), 5, false)   # smile
	_hat_joy(head, aff, a)

func _hat_joy(head: Node3D, aff: int, a: Vector3) -> void:
	match aff:
		0: # music: soft navy cap with a long cream feather
			var navy := bm(C("#3b5a82"), false, a)
			var navy_d := bm(C("#2c4566"), false, a)
			var cream := bm(C("#f3ead2"), false, a, 0.0, 0.1)
			sph(head, 0.27, Vector3(0.0, 0.2, 0.0), navy, Vector3(1.05, 0.62, 1.05), 8)
			box(head, Vector3(0.34, 0.035, 0.18), Vector3(0.0, 0.16, 0.23), navy_d, Vector3.ZERO, false)
			seg(head, Vector3(0.2, 0.28, 0.0), Vector3(0.34, 0.72, -0.1), 0.04, cream, 4, false)
			sph(head, 0.06, Vector3(0.35, 0.74, -0.1), cream, Vector3(0.8, 1.6, 0.8), 5, false)
		1: # art: tilted terracotta beret with a nub
			var ber := bm(C("#9a3f31"), false, a)
			var nub := bm(C("#5b2219"), false, a)
			var b := sph(head, 0.32, Vector3(-0.05, 0.25, 0.0), ber, Vector3(1.1, 0.42, 1.1), 8)
			b.rotation.z = 0.28
			sph(head, 0.045, Vector3(0.0, 0.37, 0.0), nub, Vector3.ONE, 5, false)
		2: # nature: straw brim, leafy crown, flower on top
			var straw := bm(C("#d8b97a"), false, a)
			var l1 := bm(C("#4f8a40"), false, a)
			var l2 := bm(C("#7fb04c"), false, a)
			var pink := bm(C("#f08aa0"), false, a, 0.0, 0.1)
			cyl(head, 0.44, 0.04, Vector3(0.0, 0.19, 0.0), straw, Vector3(0.16, 0, 0), -1.0, 10)
			cyl(head, 0.22, 0.16, Vector3(0.0, 0.29, 0.0), straw, Vector3.ZERO, -1.0, 8)
			for k in range(6):
				var ang := k * TAU / 6.0
				var lf := sph(head, 0.12, Vector3(cos(ang) * 0.2, 0.43, sin(ang) * 0.2), l1 if k % 2 == 0 else l2, Vector3(0.7, 0.4, 1.5), 5, false)
				lf.rotation.y = -ang
			sph(head, 0.09, Vector3(0.0, 0.42, 0.0), pink, Vector3.ONE, 5, false)

func add_gloomy(pos: Vector3, yaw := 0.5, parent: Node = null, register := true) -> Node3D:
	# Heavily gloomed but clearly human: hunched, long heavy coat, hood/cap pulled low, head down, hands hanging.
	# A smoky ground haze and drifting soot motes replace the old umbrella cloud.
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	if parent == null:
		parent = self
	parent.add_child(root)
	if register:
		gloomy_nodes.append(root)
	var coat := mat(C("#454a58"), 0)
	var coat_l := mat(C("#5a6070"), 0)
	var skin := mat(C("#9d958d"), 0)
	var cap := mat(C("#20222a"), 0)
	var boots := mat(C("#1d1f25"), 0)
	var soot := mat(C("#565b67"), 0)
	for sx in [-0.13, 0.13]:
		box(root, Vector3(0.2, 0.3, 0.26), Vector3(sx, 0.15, 0.0), boots)
	# long coat skirt
	box(root, Vector3(0.62, 0.62, 0.42), Vector3(0, 0.5, -0.02), coat)
	var up := Node3D.new()
	up.position = Vector3(0, 0.78, 0)
	up.rotation.x = 0.36
	root.add_child(up)
	box(up, Vector3(0.64, 0.8, 0.44), Vector3(0, 0.36, 0), coat)
	box(up, Vector3(0.7, 0.22, 0.5), Vector3(0, 0.74, 0), coat_l)     # heavy collar / shoulders
	box(up, Vector3(0.1, 0.8, 0.04), Vector3(0, 0.36, 0.23), coat_l, Vector3.ZERO, false)
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.4, 0.66, 0.02)
		arm.rotation.x = -0.35
		up.add_child(arm)
		box(arm, Vector3(0.15, 0.7, 0.18), Vector3(0, -0.34, 0), coat)
		sph(arm, 0.08, Vector3(0, -0.72, 0), skin, Vector3.ONE, 5)
	var head := Node3D.new()
	head.position = Vector3(0, 0.8, 0.12)
	head.rotation.x = 0.12
	up.add_child(head)
	sph(head, 0.22, Vector3.ZERO, skin, Vector3.ONE, 8)
	_face(head, 0.0, cap, 1.1)
	cyl(head, 0.24, 0.09, Vector3(0, 0.17, 0), cap, Vector3.ZERO, -1.0, 8)
	box(head, Vector3(0.34, 0.04, 0.2), Vector3(0, 0.1, 0.22), cap, Vector3(0.35, 0, 0), false)
	# drifting soot motes + smoky haze on the ground
	for k in range(9):
		var ang := k * 2.4
		var r := 0.45 + 0.35 * fmod(k * 0.37, 1.0)
		sph(root, 0.05 + 0.04 * fmod(k * 0.53, 1.0), Vector3(cos(ang) * r, 0.5 + 0.28 * k, sin(ang) * r), soot, Vector3.ONE, 4, false)
	var haze := MeshInstance3D.new()
	var hp := PlaneMesh.new()
	hp.size = Vector2(3.4, 3.4)
	haze.mesh = hp
	haze.material_override = smoke_mat
	haze.position = Vector3(0, 0.05, 0)
	haze.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(haze)
	return root

func add_player(pos: Vector3, parent: Node = null, yaw := 0.7, hat := 0) -> Node3D:
	# Findable at a glance: saffron coat, teal scarf (no NPC uses either), warm hat, satchel with three glowing
	# tubes, gold double ring + dithered glow on the ground.
	# hat 0 = A wide-brim felt hat with a glowing feather, 1 = B knit beanie with pom-pom, 2 = C flat cap with patch.
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	if parent == null:
		parent = self
	parent.add_child(root)
	var body := Node3D.new()
	body.scale = Vector3.ONE * 1.1
	root.add_child(body)
	var coat := mat(C("#f2a516"), 0, 0.0, 0.22)
	var coat_d := mat(C("#cf7f12"), 0, 0.0, 0.1)
	var skin := mat(C("#d9a47c"), 0)
	var pants := mat(C("#4c3a30"), 0)
	var teal := mat(C("#27b3a6"), 0, 0.0, 0.25)
	var gold := mat(C("#ffe08a"), 0, 0.0, 1.4)
	var wood_d := mat(C("#4a2418"), 0)
	var satchel := mat(C("#7a4a2c"), 0)
	var eye := mat(C("#2a1f1c"), 0)
	for sx in [-0.16, 0.16]:
		box(body, Vector3(0.25, 0.7, 0.27), Vector3(sx, 0.35, 0), pants)
		box(body, Vector3(0.27, 0.14, 0.34), Vector3(sx, 0.07, 0.03), wood_d)
	box(body, Vector3(0.66, 0.9, 0.44), Vector3(0, 1.1, 0), coat)
	box(body, Vector3(0.8, 0.42, 0.52), Vector3(0, 0.62, 0), coat_d)
	for sx in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.42, 1.45, 0)
		arm.rotation.z = -sx * 0.25
		arm.rotation.x = -0.5 if sx > 0 else 0.0
		body.add_child(arm)
		box(arm, Vector3(0.17, 0.7, 0.2), Vector3(0, -0.33, 0), coat)
		sph(arm, 0.095, Vector3(0, -0.72, 0), skin, Vector3.ONE, 5)
	sph(body, 0.26, Vector3(0, 1.78, 0.02), skin, Vector3.ONE, 8)
	_face(body, 1.8, eye, 1.2)
	# scarf: collar + streaming tails
	box(body, Vector3(0.74, 0.18, 0.54), Vector3(0, 1.54, 0.02), teal)
	box(body, Vector3(0.16, 0.5, 0.1), Vector3(0.28, 1.28, -0.3), teal, Vector3(0.25, 0, -0.2))
	box(body, Vector3(0.15, 0.5, 0.1), Vector3(0.4, 0.9, -0.5), teal, Vector3(0.5, 0, -0.45))
	box(body, Vector3(0.14, 0.4, 0.1), Vector3(0.62, 0.58, -0.7), teal, Vector3(0.75, 0, -0.7))
	match hat:
		0:
			var felt := mat(C("#8a5a3a"), 0)
			var felt_l := mat(C("#a8734a"), 0)
			var h1 := cyl(body, 0.56, 0.06, Vector3(0, 2.03, 0), felt, Vector3(0.08, 0, 0.1), -1.0, 12)
			cyl(body, 0.28, 0.3, Vector3(0, 2.2, 0), felt_l, Vector3(0.0, 0, 0.04), 0.25, 10)
			cyl(body, 0.295, 0.08, Vector3(0, 2.08, 0), teal, Vector3.ZERO, -1.0, 10)
			seg(body, Vector3(0.24, 2.18, -0.02), Vector3(0.58, 2.62, -0.12), 0.05, gold, 4, false)
			sph(body, 0.09, Vector3(0.6, 2.66, -0.13), gold, Vector3(0.8, 1.6, 0.8), 5, false)
		1:
			var wool := mat(C("#d8453a"), 0, 0.0, 0.1)
			var wool_d := mat(C("#b3342c"), 0)
			sph(body, 0.32, Vector3(0, 2.02, 0), wool, Vector3(1.0, 0.9, 1.0), 9)
			cyl(body, 0.31, 0.12, Vector3(0, 1.96, 0), wool_d, Vector3.ZERO, -1.0, 10)
			sph(body, 0.13, Vector3(0, 2.38, 0), gold, Vector3.ONE, 6, false)
		2:
			var cp := mat(C("#8a6a3a"), 0)
			var cp_d := mat(C("#5e4626"), 0)
			sph(body, 0.32, Vector3(0, 2.0, 0), cp, Vector3(1.05, 0.5, 1.1), 9)
			box(body, Vector3(0.4, 0.05, 0.26), Vector3(0, 1.96, 0.32), cp_d, Vector3.ZERO, false)
			box(body, Vector3(0.14, 0.14, 0.05), Vector3(0.29, 2.0, 0.05), teal, Vector3(0, 0.0, 0.0), false)
			box(body, Vector3(0.1, 0.45, 0.06), Vector3(-0.3, 1.78, -0.1), teal, Vector3(0.0, 0, 0.12), false)
	# satchel with three "joy tubes" (music blue, art rose, nature sage)
	box(body, Vector3(0.52, 0.6, 0.26), Vector3(0, 1.1, -0.35), satchel)
	var tubes := [C("#6ea0d8"), C("#e0806c"), C("#a8c868")]
	for k in range(3):
		var tx := -0.16 + k * 0.16
		cyl(body, 0.05, 0.5, Vector3(tx, 1.62, -0.38), mat(tubes[k], 0, 0.0, 0.7), Vector3(0.0, 0.0, (k - 1) * -0.18), -1.0, 5, false)
	# the ground marker: dithered glow, ring, outer ring
	var glow := MeshInstance3D.new()
	var gp := PlaneMesh.new()
	gp.size = Vector2(5.0, 5.0)
	glow.mesh = gp
	glow.material_override = glow_mat
	glow.position = Vector3(0, 0.06, 0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(glow)
	var gm := mat(C("#ffd466"), 0, 0.0, 1.2)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.84
	ring.outer_radius = 1.04
	ring.rings = 18
	ring.ring_segments = 5
	var rmi := _mi(root, ring, gm, Vector3(0, 0.08, 0), Vector3.ZERO, false)
	rmi.scale = Vector3(1, 0.3, 1)
	var ring2 := TorusMesh.new()
	ring2.inner_radius = 1.3
	ring2.outer_radius = 1.38
	ring2.rings = 20
	ring2.ring_segments = 4
	var rmi2 := _mi(root, ring2, mat(C("#ffd466"), 0, 0.0, 0.7), Vector3(0, 0.07, 0), Vector3.ZERO, false)
	rmi2.scale = Vector3(1, 0.25, 1)
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.8, 0.45)
	ol.light_energy = 0.9
	ol.omni_range = 4.2
	ol.shadow_enabled = false
	ol.position = Vector3(0, 1.8, 0.4)
	root.add_child(ol)
	return root

func add_projectiles() -> void:
	var o := player_node.position
	_proj_note(o + Vector3(1.0, 1.75, -2.4), Vector3(0.5, 0.1, -1.0).normalized())
	_proj_blob(o + Vector3(-1.9, 1.55, -1.4), Vector3(-0.8, 0.0, -0.6).normalized())
	_proj_flower(o + Vector3(2.4, 1.9, -1.2), Vector3(0.6, 0.0, -0.8).normalized())

func _trail(pos: Vector3, dir: Vector3, col: Color, r: float) -> void:
	for i in range(1, 7):
		var f := 1.0 - i * 0.15
		sph(self, r * f, pos - dir * i * 0.3, mat(col, 0, 0.0, 0.8 - i * 0.08), Vector3.ONE, 6, false)

func _proj_note(pos: Vector3, dir: Vector3) -> void:
	var col := C("#6ea0d8")
	var m := mat(col, 0, 0.0, 0.9)
	_trail(pos, dir, col, 0.17)
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	sph(n, 0.2, Vector3.ZERO, m, Vector3(1.25, 0.85, 1.0), 8, false)
	box(n, Vector3(0.06, 0.62, 0.06), Vector3(0.2, 0.31, 0), m, Vector3.ZERO, false)
	box(n, Vector3(0.28, 0.1, 0.06), Vector3(0.34, 0.6, 0), m, Vector3(0, 0, -0.5), false)

func _proj_blob(pos: Vector3, dir: Vector3) -> void:
	var col := C("#dd6a56")
	var m := mat(col, 0, 0.0, 0.9)
	_trail(pos, dir, col, 0.2)
	sph(self, 0.3, pos, m, Vector3(1.0, 0.9, 1.15), 8, false)
	sph(self, 0.12, pos + Vector3(0.2, -0.28, 0.05), m, Vector3.ONE, 6, false)
	sph(self, 0.09, pos + Vector3(-0.18, 0.26, 0.1), m, Vector3.ONE, 6, false)
	sph(self, 0.08, pos + Vector3(0.12, 0.3, -0.12), m, Vector3.ONE, 6, false)

func _proj_flower(pos: Vector3, dir: Vector3) -> void:
	var col := C("#a8c868")
	var m := mat(col, 0, 0.0, 0.8)
	_trail(pos, dir, col, 0.15)
	for k in range(6):
		var a := k * TAU / 6.0
		sph(self, 0.12, pos + Vector3(cos(a) * 0.22, sin(a) * 0.22, 0.0), m, Vector3.ONE, 6, false)
	sph(self, 0.12, pos, mat(C("#f2c04c"), 0, 0.0, 0.9), Vector3.ONE, 6, false)

# ---------------------------------------------------------------- lineup (character sheet), far away from the plaza
func build_lineup() -> void:
	# one row at z=42: grey music/art/nature + dark person, joyful music/art/nature, then 3 player hat options.
	var xs := [-11.5, -9.2, -6.9, -4.6, -2.3, 0.0, 2.3, 5.0, 7.6, 10.2]
	for i in range(xs.size()):
		var pos := Vector3(xs[i], 0, 42.0)
		lineup_pos.append(pos)
		var n: Node3D
		match i:
			0, 1, 2:
				n = add_person(pos.x, pos.z, 0.12, i, i, 2.0, null, false)
			3:
				n = add_gloomy(pos, 0.12, null, false)
			4, 5, 6:
				n = add_person(pos.x, pos.z, -0.12, i - 4, [0, 2, 1][i - 4], 2.0, null, false)
			_:
				n = add_player(pos, null, 0.2, i - 7)
		lineup_nodes.append(n)
	lineup_circles = [Vector4(4.5, 42.0, 9.5, 0)]

# ---------------------------------------------------------------- living border
func clear_dynamic() -> void:
	if dyn != null:
		dyn.queue_free()
		dyn = null
	border_info = {}
	dark_spots = []
	gap_motes = []
	gap_glows = []

# soft haze band: vertex colour = tint, alpha = intensity; lateral falloff + dither happen in haze.gdshader
func _haze_mesh(samples: Array, half_w: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in samples:
		var a: Vector2 = q[0]
		var b: Vector2 = q[1]
		var col: Color = q[2]
		var dist: float = q[3]
		var t := (b - a).normalized()
		var n := Vector2(-t.y, t.x) * half_w
		var vs := [Vector3(a.x - n.x, 0.045, a.y - n.y), Vector3(a.x + n.x, 0.045, a.y + n.y), Vector3(b.x - n.x, 0.045, b.y - n.y), Vector3(b.x + n.x, 0.045, b.y + n.y)]
		var gw: float = q[4]
		var us := [Vector2(-1, dist), Vector2(1, dist), Vector2(-1, dist + 0.14), Vector2(1, dist + 0.14)]
		for tri in [[0, 1, 2], [2, 1, 3], [2, 1, 0], [3, 1, 2]]:
			for k in tri:
				st.set_normal(Vector3.UP)
				st.set_color(col)
				st.set_uv(us[k])
				st.set_uv2(Vector2(gw, 0.0))
				st.add_vertex(vs[k])
	return st.commit()

func build_border(cs: Array, center: Vector2, n_people: int, gaps: Array, level := 1.5) -> void:
	clear_dynamic()
	dyn = Node3D.new()
	add_child(dyn)
	# 1. trace the edge of the warm area (outermost point where the field is safely warm)
	var raw: Array = []
	for k in range(360):
		var ang := deg_to_rad(float(k))
		var d := Vector2(cos(ang), sin(ang))
		var t := 30.0
		while t > 0.0:
			if joy_field(center + d * t, cs) >= level:
				raw.append(center + d * t)
				break
			t -= 0.05
	var pts: Array = []
	for i in range(raw.size()):
		var acc := Vector2.ZERO
		for j in range(-5, 6):
			acc += raw[(i + j + raw.size()) % raw.size()]
		pts.append(acc / 11.0)
	var cum: Array = [0.0]
	for i in range(1, pts.size() + 1):
		cum.append(cum[i - 1] + (pts[i % pts.size()] as Vector2).distance_to(pts[i - 1]))
	var total: float = cum[cum.size() - 1]
	var step_len := total / float(n_people)
	var at := func(dist: float) -> Vector2:
		dist = fposmod(dist, total)
		var lo := 0
		var hi: int = cum.size() - 1
		while hi - lo > 1:
			var mid := (lo + hi) / 2
			if cum[mid] <= dist:
				lo = mid
			else:
				hi = mid
		var f: float = (dist - cum[lo]) / maxf(cum[hi] - cum[lo], 0.0001)
		return (pts[lo % pts.size()] as Vector2).lerp(pts[hi % pts.size()], f)
	# 2. people on the line (skip the gap slots)
	var people: Array = []
	var gap_pos: Array = []
	var gap_out: Array = []
	for i in range(n_people):
		var dist := (i + 0.5) * step_len
		var p2: Vector2 = at.call(dist)
		var tan2: Vector2 = ((at.call(dist + 0.4) as Vector2) - (at.call(dist - 0.4) as Vector2)).normalized()
		var out := Vector2(tan2.y, -tan2.x)
		if out.dot(p2 - center) < 0.0:
			out = -out
		if i in gaps:
			gap_pos.append(p2)
			gap_out.append(out)
			continue
		var aff := (i * 5 + 1) % 3
		var v := (i * 2) % 3
		add_person(p2.x, p2.y, atan2(out.x, out.y) + 0.2 * ((i % 3) - 1), aff, v, 0.0, dyn, false)
		people.append(p2)
	# 3. soft haze band that hints at the border; it thins out and turns cool-red across each gap
	var samples: Array = []
	var motes := RandomNumberGenerator.new()
	motes.seed = 7
	var d := 0.0
	var prev: Vector2 = at.call(0.0)
	var next_mote := 0.0
	while d < total - 0.01:
		d += 0.14
		var cur: Vector2 = at.call(d)
		var gt := 9.0
		for g in gaps:
			gt = minf(gt, absf(d - (g + 0.5) * step_len) / step_len)
		var k := smoothstep(0.35, 0.95, gt)          # 0 in the gap centre .. 1 on intact stretches
		var tint := Color("#ff6a58").lerp(Color("#e8963a"), smoothstep(0.2, 0.8, gt))
		var inten := lerpf(0.4, 1.0, k)
		samples.append([prev, cur, Color(tint.r, tint.g, tint.b, inten), d, 1.0 - k])
		if d > next_mote:
			var tan3 := (cur - prev).normalized()
			var nrm := Vector2(-tan3.y, tan3.x)
			var mp := cur + nrm * motes.randf_range(-0.7, 0.7)
			var gap_mote := k < 0.45
			if (not gap_mote) or motes.randf() < 0.75:
				if gap_mote:
					var gn := sph(dyn, 0.055, Vector3(mp.x, motes.randf_range(0.25, 1.5), mp.y), gap_mote_mat, Vector3.ONE, 4, false)
					gap_motes.append(gn)
				else:
					var mm2 := mat(C("#ffe28a"), 0, 0.0, 1.2)
					sph(dyn, 0.055, Vector3(mp.x, motes.randf_range(0.25, 1.5), mp.y), mm2, Vector3.ONE, 4, false)
			next_mote = d + (0.42 if not gap_mote else 0.6)
		prev = cur
	var hmi := MeshInstance3D.new()
	hmi.mesh = _haze_mesh(samples, 0.9)
	hmi.material_override = haze_mat
	hmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dyn.add_child(hmi)
	var segs: Array = []
	var dd := 0.0
	var pp: Vector2 = at.call(0.0)
	while dd < total - 0.01:
		dd += 0.7
		var cc: Vector2 = at.call(dd)
		var red := false
		for g in gaps:
			if absf(dd - (g + 0.5) * step_len) < 0.72 * step_len:
				red = true
		segs.append([pp, cc, red])
		pp = cc
	for gp2 in gap_pos:
		var gl := MeshInstance3D.new()
		var gpm := PlaneMesh.new()
		gpm.size = Vector2(5.0, 5.0)
		gl.mesh = gpm
		gl.material_override = gap_glow_mat
		gl.position = Vector3(gp2.x, 0.055, gp2.y)
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dyn.add_child(gl)
		gap_glows.append(gl)
	border_info = {"poly": pts, "segs": segs, "people": people, "gaps": gap_pos, "gap_out": gap_out, "total": total, "step": step_len, "center": center}

# ---------------------------------------------------------------- parameters
func set_joy(j: float) -> void:
	joy_level = j
	var cs: Array = []
	if circles_override.size() > 0:
		cs = circles_override.duplicate()
	else:
		var rr := 2.3 + 5.4 * j
		for p in people_defs:
			if j >= p["thr"] - 0.001:
				cs.append(Vector4(p["x"], p["z"], rr, 0))
		for b in bldg_defs:
			if j >= b["thr"] - 0.001:
				cs.append(Vector4(b["x"], b["z"], b["r"], 0))
	cur_circles = cs
	var arr := PackedVector4Array()
	for i in range(MAXC):
		arr.append(cs[i] if i < cs.size() else Vector4(0, 0, 0, 0))
	for m in all_mats:
		m.set_shader_parameter("circles", arr)
		m.set_shader_parameter("circle_count", mini(cs.size(), MAXC))
	env.background_color = Color(0.58, 0.63, 0.72).lerp(Color(0.97, 0.86, 0.68), j)
	env.fog_light_color = env.background_color

func set_pixel_mode(on: bool) -> void:
	pixel_mode = on
	post_mi.visible = on
	for m in all_mats:
		m.set_shader_parameter("smooth_mode", 0.0 if on else 1.0)

func place_camera(tgt: Vector3, size: float, pitch_deg := 41.0, yaw_deg := 0.0) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam_size = size
	cam_tgt = tgt
	cam_pitch = deg_to_rad(pitch_deg)
	var pitch := cam_pitch
	var yaw := deg_to_rad(yaw_deg)
	cam.look_at_from_position(tgt + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 40.0, tgt, Vector3.UP)
	post_mat.set_shader_parameter("dthr", 0.3)
	post_mat.set_shader_parameter("rel", 0.0)

func set_shot(name: String, extra := {}) -> void:
	player_node.visible = true
	env.fog_enabled = false
	light.directional_shadow_max_distance = 70.0
	match name:
		"topdown":
			# gameplay camera: follows the player in the middle of the plaza, about 1.8x closer than review 1
			place_camera(player_node.position + Vector3(0.0, 0.5, -2.4), 14.5)
		"closeup":
			place_camera(Vector3(-9.0, 1.6, -4.0), 10.5, 30.0, -22.0)
		"lineup":
			place_camera(Vector3(float(extra.get("x", 0.0)), 0.9, 42.0), float(extra.get("size", 12.0)))

# gap pulse: p in 0..1 (0 = trough, the quiet review-4 look; 1 = peak). Period in the real game ~1.2 s, eased.
func pulse_value(t: float, period := 1.2) -> float:
	return 0.5 - 0.5 * cos(TAU * t / period)

func set_pulse(p: float) -> void:
	pulse = p
	haze_mat.set_shader_parameter("gap_pulse", p)
	gap_mote_mat.set_shader_parameter("emit", 1.0 + 3.2 * p)
	gap_glow_mat.set_shader_parameter("strength", 0.05 + 0.44 * p)
	for n in gap_motes:
		if is_instance_valid(n):
			n.scale = Vector3.ONE * (0.8 + 1.3 * p)
	for g in gap_glows:
		if is_instance_valid(g):
			g.scale = Vector3(0.8 + 0.45 * p, 1, 0.8 + 0.45 * p)
