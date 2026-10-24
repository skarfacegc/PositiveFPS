class_name StylePeople
extends RefCounted

# The styled bodies (ported from design/style_test/scene.gd, per REVIEW_NOTES.md): chunky low-poly humans. Grey people
# are stiff and upright with a cap, a muted affinity scarf, a pip and a grey version of their object held up in front.
# Joyful people are relaxed and tilted, in their affinity colour with a playful hat and their object held high. Dark
# people are hunched in a heavy coat with a low cap, soot motes round them and a smoke haze on the ground. The player
# wears a wide-brim felt hat with a teal band and a glowing feather, a saffron coat, a teal scarf and a gold ring.
# Every body faces +z; the look turns it to the person's facing.

const AFF_COAT: Array[String] = ["#5f86b0", "#c4604f", "#7f9d62"]  # music dusty blue, art rose, nature sage
const AFF_PIP: Array[String] = ["#7fa6d6", "#e0806c", "#97b872"]  # the small affinity pip grey people carry
const GREY_COATS: Array[String] = ["#5b6370", "#4f5662", "#69707b"]
const JOY_TRIM: Array[String] = ["#f1dfbd", "#f1dfbd", "#8a6a45"]
const SKINS: Array[String] = ["#e2b18c", "#c98a63", "#a46a47", "#ecc19c"]

static var _smoke: ShaderMaterial


# ---- Grey person. `parts["pips"]` gets the meshes that brighten with the person's joy.
static func build_grey(root: Node3D, aff: int, v: int, parts: Dictionary) -> void:
	var skin := StyleKit.mat(StyleKit.hexc("#b4a9a1"))
	var coat := StyleKit.mat(StyleKit.hexc(GREY_COATS[v % 3]), 0, 0.5)
	var coat_d := StyleKit.mat(StyleKit.hexc("#3d434e"), 0, 0.4)
	var pants := StyleKit.mat(StyleKit.hexc("#383d47"), 0, 0.3)
	var cap := StyleKit.mat(StyleKit.hexc("#2b2f37"), 0, 0.3)
	var eye := StyleKit.mat(StyleKit.hexc("#1b1d22"))
	var brass := StyleKit.mat(StyleKit.hexc("#a9a28a"))
	var tint := StyleKit.hexc("#6a707c").lerp(StyleKit.hexc(AFF_PIP[aff]), 0.42)
	var scarf := StyleKit.mat(tint, 0, 0.0, 0.12)
	var pip := StyleKit.mat(StyleKit.hexc(AFF_PIP[aff]), 0, 0.0, 0.35)
	var pips: Array[MeshInstance3D] = []
	for sx: float in [-0.12, 0.12]:
		StyleKit.box(root, Vector3(0.2, 0.62, 0.22), Vector3(sx, 0.31, 0), pants)
		StyleKit.box(root, Vector3(0.22, 0.1, 0.3), Vector3(sx, 0.05, 0.04), cap)
	StyleKit.box(root, Vector3(0.54, 0.86, 0.36), Vector3(0, 1.0, 0), coat)
	StyleKit.box(root, Vector3(0.58, 0.14, 0.4), Vector3(0, 0.6, 0), coat_d)
	StyleKit.box(root, Vector3(0.62, 0.12, 0.36), Vector3(0, 1.38, 0), coat_d)
	StyleKit.box(root, Vector3(0.1, 0.5, 0.04), Vector3(0, 1.1, 0.19), coat_d, Vector3.ZERO, false)
	# muted affinity scarf (collar + a short tail down the chest)
	pips.append(StyleKit.box(root, Vector3(0.6, 0.14, 0.42), Vector3(0, 1.47, 0.0), scarf))
	pips.append(StyleKit.box(root, Vector3(0.12, 0.34, 0.05), Vector3(0.16, 1.26, 0.2), scarf, Vector3.ZERO, false))
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.37, 1.38, 0)
		root.add_child(arm)
		if sx > 0.0:
			# forearm bent forward, holding the object up
			arm.rotation.x = -1.3
			StyleKit.box(arm, Vector3(0.13, 0.74, 0.17), Vector3(0, -0.37, 0), coat)
			StyleKit.sph(arm, 0.08, Vector3(0, -0.78, 0), skin, Vector3.ONE, 5)
			var held := Node3D.new()
			held.position = Vector3(0, -0.8, 0.0)
			held.rotation.x = 4.7
			arm.add_child(held)
			held.rotation.z = -0.45
			_item(held, aff, true, 1.1, pips)
		else:
			arm.rotation.z = sx * 0.04
			StyleKit.box(arm, Vector3(0.13, 0.74, 0.17), Vector3(0, -0.37, 0), coat)
			StyleKit.sph(arm, 0.08, Vector3(0, -0.78, 0), skin, Vector3.ONE, 5)
	StyleKit.sph(root, 0.04, Vector3(0.14, 1.0, 0.19), brass, Vector3.ONE, 5, false)
	pips.append(StyleKit.sph(root, 0.09, Vector3(-0.15, 1.28, 0.2), pip, Vector3.ONE, 5, false))
	StyleKit.sph(root, 0.23, Vector3(0, 1.66, 0.01), skin, Vector3.ONE, 8)
	_face(root, 1.67, eye)
	StyleKit.cyl(root, 0.25, 0.1, Vector3(0, 1.85, 0), cap, Vector3.ZERO, -1.0, 8)
	pips.append(StyleKit.cyl(root, 0.26, 0.05, Vector3(0, 1.8, 0), scarf, Vector3.ZERO, -1.0, 8, false))
	StyleKit.box(root, Vector3(0.3, 0.03, 0.16), Vector3(0, 1.8, 0.23), cap, Vector3.ZERO, false)
	pips.append(StyleKit.sph(root, 0.06, Vector3(0.0, 1.86, 0.25), pip, Vector3.ONE, 5, false))
	parts["pips"] = pips


# ---- Joyful person. `parts["glow"]` gets the meshes that glow during the grace period.
static func build_joy(root: Node3D, aff: int, v: int, parts: Dictionary) -> void:
	var skin := StyleKit.mat(StyleKit.hexc(SKINS[(v + aff) % 4]), 0, 0.0, 0.0, 0, 1.0)
	var coat := StyleKit.mat(StyleKit.hexc(AFF_COAT[aff]), 0, 0.0, 0.0, 0, 1.0)
	var acc := StyleKit.mat(StyleKit.hexc(JOY_TRIM[aff]), 0, 0.0, 0.0, 0, 1.0)
	var pants := StyleKit.mat(StyleKit.hexc("#6d5a4b"), 0, 0.0, 0.0, 0, 1.0)
	var boots := StyleKit.mat(StyleKit.hexc("#5a3d2c"), 0, 0.0, 0.0, 0, 1.0)
	var eye := StyleKit.mat(StyleKit.hexc("#2a1f1c"))
	var glow: Array[MeshInstance3D] = []
	var lean := 1.0 if v % 2 == 0 else -1.0
	var hop := 0.14 if v == 0 else (0.0 if v == 1 else 0.07)
	for sx: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(sx * 0.14, 0.62 + hop, 0)
		leg.rotation.z = sx * (0.2 if v != 1 else 0.1) * lean
		leg.rotation.x = 0.35 if (sx > 0.0 and v == 0) else 0.0
		root.add_child(leg)
		StyleKit.box(leg, Vector3(0.22, 0.62, 0.24), Vector3(0, -0.31, 0), pants)
		StyleKit.box(leg, Vector3(0.24, 0.1, 0.3), Vector3(0, -0.57, 0.03), boots)
	var up := Node3D.new()
	up.position = Vector3(0, 0.62 + hop, 0)
	up.rotation.z = 0.15 * lean
	up.rotation.y = 0.25 * lean
	root.add_child(up)
	glow.append(StyleKit.box(up, Vector3(0.56, 0.74, 0.38), Vector3(0, 0.37, 0), coat))
	StyleKit.box(up, Vector3(0.58, 0.12, 0.4), Vector3(0, 0.04, 0), acc)
	StyleKit.box(up, Vector3(0.62, 0.16, 0.2), Vector3(0, 0.62, 0.12), acc)
	var holder := 1.0 if v % 2 == 0 else -1.0
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.37, 0.68, 0)
		var carrying := sx == holder
		if carrying:
			arm.rotation.z = sx * (2.55 if v != 1 else 2.0)
		else:
			arm.rotation.z = sx * (1.5 if v == 2 else 0.5)  # other arm flung out or relaxed
		up.add_child(arm)
		StyleKit.box(arm, Vector3(0.14, 0.62, 0.17), Vector3(0, -0.28, 0), coat)
		StyleKit.sph(arm, 0.085, Vector3(0, -0.62, 0), skin, Vector3.ONE, 5)
		if carrying:
			var held := Node3D.new()
			held.position = Vector3(0, -0.64, 0)
			arm.add_child(held)
			_item(held, aff, false, 1.0, glow)
	var head := Node3D.new()
	head.position = Vector3(0, 0.98, 0.02)
	head.rotation.z = -0.2 * lean
	up.add_child(head)
	StyleKit.sph(head, 0.23, Vector3.ZERO, skin, Vector3.ONE, 8)
	_face(head, 0.01, eye)
	StyleKit.sph(
		head, 0.05, Vector3(0.0, -0.07, 0.21), StyleKit.mat(StyleKit.hexc("#c4604f")), Vector3(1.8, 0.5, 0.6), 5, false
	)
	_hat_joy(head, aff)
	parts["glow"] = glow


# ---- Dark person. `parts["soot"]` is the node holding the drifting soot motes.
static func build_dark(root: Node3D, parts: Dictionary) -> void:
	var coat := StyleKit.mat(StyleKit.hexc("#454a58"))
	var coat_l := StyleKit.mat(StyleKit.hexc("#5a6070"))
	var skin := StyleKit.mat(StyleKit.hexc("#9d958d"))
	var cap := StyleKit.mat(StyleKit.hexc("#20222a"))
	var boots := StyleKit.mat(StyleKit.hexc("#1d1f25"))
	var soot_mat := StyleKit.mat(StyleKit.hexc("#6a707d"))
	for sx: float in [-0.13, 0.13]:
		StyleKit.box(root, Vector3(0.2, 0.3, 0.26), Vector3(sx, 0.15, 0.0), boots)
	# long coat skirt
	StyleKit.box(root, Vector3(0.62, 0.62, 0.42), Vector3(0, 0.5, -0.02), coat)
	var up := Node3D.new()
	up.position = Vector3(0, 0.78, 0)
	up.rotation.x = 0.36
	root.add_child(up)
	StyleKit.box(up, Vector3(0.64, 0.8, 0.44), Vector3(0, 0.36, 0), coat)
	StyleKit.box(up, Vector3(0.7, 0.22, 0.5), Vector3(0, 0.74, 0), coat_l)  # heavy collar / shoulders
	StyleKit.box(up, Vector3(0.1, 0.8, 0.04), Vector3(0, 0.36, 0.23), coat_l, Vector3.ZERO, false)
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.4, 0.66, 0.02)
		arm.rotation.x = -0.35
		up.add_child(arm)
		StyleKit.box(arm, Vector3(0.15, 0.7, 0.18), Vector3(0, -0.34, 0), coat)
		StyleKit.sph(arm, 0.08, Vector3(0, -0.72, 0), skin, Vector3.ONE, 5)
	var head := Node3D.new()
	head.position = Vector3(0, 0.8, 0.12)
	head.rotation.x = 0.12
	up.add_child(head)
	StyleKit.sph(head, 0.22, Vector3.ZERO, skin, Vector3.ONE, 8)
	_face(head, 0.0, cap, 1.1)
	StyleKit.cyl(head, 0.24, 0.09, Vector3(0, 0.17, 0), cap, Vector3.ZERO, -1.0, 8)
	StyleKit.box(head, Vector3(0.34, 0.04, 0.2), Vector3(0, 0.1, 0.22), cap, Vector3(0.35, 0, 0), false)
	# drifting soot motes + smoky haze on the ground
	var soot := Node3D.new()
	root.add_child(soot)
	for k: int in range(18):
		var ang := k * 2.4
		var r := 0.45 + 0.5 * fmod(k * 0.37, 1.0)
		StyleKit.sph(
			soot,
			0.06 + 0.05 * fmod(k * 0.53, 1.0),
			Vector3(cos(ang) * r, 0.4 + 0.15 * k, sin(ang) * r),
			soot_mat,
			Vector3.ONE,
			4,
			false
		)
	# Round 12a: a bigger, denser smoke pool and more soot, so a dimmed person stands apart from wistful and gloomy ones.
	var haze := StyleKit.glow_plane(root, smoke_material(), 5.0, Vector3(0, 0.05, 0))
	haze.name = "Smoke"
	parts["soot"] = soot
	parts["haze"] = haze


# The dark smoke haze under a dark person (one dithered dark glow, shared).
static func smoke_material() -> ShaderMaterial:
	if _smoke == null:
		_smoke = StyleKit.glow_mat(Color(0.05, 0.05, 0.08), 0.85)
	return _smoke


# ---- Player. `parts["ring"]` is the outer ring mesh (its colour shows the target's element), `parts["glow"]` the glow.
static func build_player(root: Node3D, parts: Dictionary) -> void:
	var body := Node3D.new()
	body.scale = Vector3.ONE * 1.1
	root.add_child(body)
	var coat := StyleKit.mat(StyleKit.hexc("#f2a516"), 0, 0.0, 0.22)
	var coat_d := StyleKit.mat(StyleKit.hexc("#cf7f12"), 0, 0.0, 0.1)
	var skin := StyleKit.mat(StyleKit.hexc("#d9a47c"))
	var pants := StyleKit.mat(StyleKit.hexc("#4c3a30"))
	var teal := StyleKit.mat(StyleKit.hexc("#27b3a6"), 0, 0.0, 0.25)
	var gold := StyleKit.mat(StyleKit.hexc("#ffe08a"), 0, 0.0, 1.4)
	var wood_d := StyleKit.mat(StyleKit.hexc("#4a2418"))
	var satchel := StyleKit.mat(StyleKit.hexc("#7a4a2c"))
	var eye := StyleKit.mat(StyleKit.hexc("#2a1f1c"))
	for sx: float in [-0.16, 0.16]:
		StyleKit.box(body, Vector3(0.25, 0.7, 0.27), Vector3(sx, 0.35, 0), pants)
		StyleKit.box(body, Vector3(0.27, 0.14, 0.34), Vector3(sx, 0.07, 0.03), wood_d)
	StyleKit.box(body, Vector3(0.66, 0.9, 0.44), Vector3(0, 1.1, 0), coat)
	StyleKit.box(body, Vector3(0.8, 0.42, 0.52), Vector3(0, 0.62, 0), coat_d)
	for sx: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(sx * 0.42, 1.45, 0)
		arm.rotation.z = -sx * 0.25
		arm.rotation.x = -0.5 if sx > 0 else 0.0
		body.add_child(arm)
		StyleKit.box(arm, Vector3(0.17, 0.7, 0.2), Vector3(0, -0.33, 0), coat)
		StyleKit.sph(arm, 0.095, Vector3(0, -0.72, 0), skin, Vector3.ONE, 5)
	StyleKit.sph(body, 0.26, Vector3(0, 1.78, 0.02), skin, Vector3.ONE, 8)
	_face(body, 1.8, eye, 1.2)
	# scarf: collar + streaming tails
	StyleKit.box(body, Vector3(0.74, 0.18, 0.54), Vector3(0, 1.54, 0.02), teal)
	StyleKit.box(body, Vector3(0.16, 0.5, 0.1), Vector3(0.28, 1.28, -0.3), teal, Vector3(0.25, 0, -0.2))
	StyleKit.box(body, Vector3(0.15, 0.5, 0.1), Vector3(0.4, 0.9, -0.5), teal, Vector3(0.5, 0, -0.45))
	StyleKit.box(body, Vector3(0.14, 0.4, 0.1), Vector3(0.62, 0.58, -0.7), teal, Vector3(0.75, 0, -0.7))
	# wide-brim felt hat with a teal band and a glowing feather
	var felt := StyleKit.mat(StyleKit.hexc("#8a5a3a"))
	var felt_l := StyleKit.mat(StyleKit.hexc("#a8734a"))
	StyleKit.cyl(body, 0.56, 0.06, Vector3(0, 2.03, 0), felt, Vector3(0.08, 0, 0.1), -1.0, 12)
	StyleKit.cyl(body, 0.28, 0.3, Vector3(0, 2.2, 0), felt_l, Vector3(0.0, 0, 0.04), 0.25, 10)
	StyleKit.cyl(body, 0.295, 0.08, Vector3(0, 2.08, 0), teal, Vector3.ZERO, -1.0, 10)
	StyleKit.seg(body, Vector3(0.24, 2.18, -0.02), Vector3(0.58, 2.62, -0.12), 0.05, gold, 4, false)
	StyleKit.sph(body, 0.09, Vector3(0.6, 2.66, -0.13), gold, Vector3(0.8, 1.6, 0.8), 5, false)
	# satchel with three "joy tubes" (music blue, art rose, nature sage)
	StyleKit.box(body, Vector3(0.52, 0.6, 0.26), Vector3(0, 1.1, -0.35), satchel)
	var tubes: Array[String] = ["#6ea0d8", "#e0806c", "#a8c868"]
	for k: int in range(3):
		var tx := -0.16 + k * 0.16
		var tube := StyleKit.mat(StyleKit.hexc(tubes[k]), 0, 0.0, 0.7)
		StyleKit.cyl(
			body, 0.05, 0.5, Vector3(tx, 1.62, -0.38), tube, Vector3(0.0, 0.0, (k - 1) * -0.18), -1.0, 5, false
		)
	# the ground marker: dithered glow, ring, outer ring (the outer ring shows the target's element)
	var glow_plane := StyleKit.glow_plane(
		root, StyleKit.glow_mat(Color(1.0, 0.82, 0.38), 0.62), 5.0, Vector3(0, 0.06, 0)
	)
	glow_plane.name = "Glow"
	var ring := TorusMesh.new()
	ring.inner_radius = 0.84
	ring.outer_radius = 1.04
	ring.rings = 18
	ring.ring_segments = 5
	var rmi := MeshInstance3D.new()
	rmi.mesh = ring
	rmi.material_override = StyleKit.mat(StyleKit.hexc("#ffd466"), 0, 0.0, 1.2)
	rmi.position = Vector3(0, 0.08, 0)
	rmi.scale = Vector3(1, 0.3, 1)
	rmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rmi)
	var ring2 := TorusMesh.new()
	ring2.inner_radius = 1.3
	ring2.outer_radius = 1.38
	ring2.rings = 20
	ring2.ring_segments = 4
	var rmi2 := MeshInstance3D.new()
	rmi2.mesh = ring2
	rmi2.position = Vector3(0, 0.07, 0)
	rmi2.scale = Vector3(1, 0.25, 1)
	rmi2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rmi2)
	parts["ring"] = rmi2
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.8, 0.45)
	ol.light_energy = 0.9
	ol.omni_range = 4.2
	ol.shadow_enabled = false
	ol.position = Vector3(0, 1.8, 0.4)
	root.add_child(ol)


static func _face(p: Node3D, y: float, em: Material, scl: float = 1.0) -> void:
	for sx: float in [-0.085, 0.085]:
		StyleKit.sph(p, 0.04 * scl, Vector3(sx, y, 0.225), em, Vector3.ONE, 5, false)


# The thing a person carries, built along local -Y from the hand. `pips` collects the meshes that brighten with joy.
static func _item(parent: Node3D, aff: int, grey: bool, scl: float, pips: Array[MeshInstance3D]) -> void:
	var n := Node3D.new()
	n.scale = Vector3.ONE * scl
	parent.add_child(n)
	var tint := StyleKit.hexc(AFF_PIP[aff])
	var g1 := StyleKit.hexc("#8c9098").lerp(tint, 0.3)
	var g2 := StyleKit.hexc("#6a6e76").lerp(tint, 0.2)
	match aff:
		0:  # little brass horn
			var brass := StyleKit.mat(g1 if grey else StyleKit.hexc("#e8b24a"), 0, 0.0, 0.0 if grey else 0.12)
			StyleKit.cyl(n, 0.045, 0.3, Vector3(0, -0.15, 0), brass, Vector3.ZERO, -1.0, 6, false)
			StyleKit.cyl(n, 0.15, 0.2, Vector3(0, -0.4, 0), brass, Vector3.ZERO, 0.05, 8, false)
			StyleKit.sph(n, 0.06, Vector3(0, 0.0, 0), brass, Vector3.ONE, 5, false)
		1:  # paintbrush
			var wood := StyleKit.mat(g2 if grey else StyleKit.hexc("#8a5a3a"))
			var metal := StyleKit.mat(g1 if grey else StyleKit.hexc("#c9c2b0"))
			var paint := StyleKit.mat(
				g1.lightened(0.1) if grey else StyleKit.hexc("#f2c04c"), 0, 0.0, 0.0 if grey else 0.2
			)
			StyleKit.cyl(n, 0.03, 0.44, Vector3(0, -0.22, 0), wood, Vector3.ZERO, -1.0, 5, false)
			StyleKit.cyl(n, 0.05, 0.1, Vector3(0, -0.47, 0), metal, Vector3.ZERO, -1.0, 6, false)
			StyleKit.sph(n, 0.08, Vector3(0, -0.58, 0), paint, Vector3(1.0, 1.5, 1.0), 6, false)
		_:  # flower on a stem
			var stem := StyleKit.mat(g2 if grey else StyleKit.hexc("#56753f"))
			var petal := StyleKit.mat(
				g1.lightened(0.08) if grey else StyleKit.hexc("#f08aa0"), 0, 0.0, 0.0 if grey else 0.12
			)
			var mid := StyleKit.mat(g2 if grey else StyleKit.hexc("#f2c04c"))
			StyleKit.cyl(n, 0.025, 0.34, Vector3(0, -0.17, 0), stem, Vector3.ZERO, -1.0, 5, false)
			for k: int in range(6):
				var ang := k * TAU / 6.0
				var pm := StyleKit.sph(
					n, 0.085, Vector3(cos(ang) * 0.11, -0.38, sin(ang) * 0.11), petal, Vector3.ONE, 5, false
				)
				if grey:
					pips.append(pm)
			StyleKit.sph(n, 0.075, Vector3(0, -0.38, 0), mid, Vector3.ONE, 5, false)


static func _hat_joy(head: Node3D, aff: int) -> void:
	match aff:
		0:  # music: soft navy cap with a long cream feather
			var navy := StyleKit.mat(StyleKit.hexc("#3b5a82"), 0, 0.0, 0.0, 0, 1.0)
			var navy_d := StyleKit.mat(StyleKit.hexc("#2c4566"), 0, 0.0, 0.0, 0, 1.0)
			var cream := StyleKit.mat(StyleKit.hexc("#f3ead2"), 0, 0.0, 0.1)
			StyleKit.sph(head, 0.27, Vector3(0.0, 0.2, 0.0), navy, Vector3(1.05, 0.62, 1.05), 8)
			StyleKit.box(head, Vector3(0.34, 0.035, 0.18), Vector3(0.0, 0.16, 0.23), navy_d, Vector3.ZERO, false)
			StyleKit.seg(head, Vector3(0.2, 0.28, 0.0), Vector3(0.34, 0.72, -0.1), 0.04, cream, 4, false)
			StyleKit.sph(head, 0.06, Vector3(0.35, 0.74, -0.1), cream, Vector3(0.8, 1.6, 0.8), 5, false)
		1:  # art: tilted terracotta beret with a nub
			var ber := StyleKit.mat(StyleKit.hexc("#9a3f31"), 0, 0.0, 0.0, 0, 1.0)
			var nub := StyleKit.mat(StyleKit.hexc("#5b2219"))
			var b := StyleKit.sph(head, 0.32, Vector3(-0.05, 0.25, 0.0), ber, Vector3(1.1, 0.42, 1.1), 8)
			b.rotation.z = 0.28
			StyleKit.sph(head, 0.045, Vector3(0.0, 0.37, 0.0), nub, Vector3.ONE, 5, false)
		_:  # nature: straw brim, leafy crown, flower on top
			var straw := StyleKit.mat(StyleKit.hexc("#d8b97a"), 0, 0.0, 0.0, 0, 1.0)
			var l1 := StyleKit.mat(StyleKit.hexc("#4f8a40"))
			var l2 := StyleKit.mat(StyleKit.hexc("#7fb04c"))
			var pink := StyleKit.mat(StyleKit.hexc("#f08aa0"), 0, 0.0, 0.1)
			StyleKit.cyl(head, 0.44, 0.04, Vector3(0.0, 0.19, 0.0), straw, Vector3(0.16, 0, 0), -1.0, 10)
			StyleKit.cyl(head, 0.22, 0.16, Vector3(0.0, 0.29, 0.0), straw, Vector3.ZERO, -1.0, 8)
			for k: int in range(6):
				var ang := k * TAU / 6.0
				var lf := StyleKit.sph(
					head,
					0.12,
					Vector3(cos(ang) * 0.2, 0.43, sin(ang) * 0.2),
					l1 if k % 2 == 0 else l2,
					Vector3(0.7, 0.4, 1.5),
					5,
					false
				)
				lf.rotation.y = -ang
			StyleKit.sph(head, 0.09, Vector3(0.0, 0.42, 0.0), pink, Vector3.ONE, 5, false)
