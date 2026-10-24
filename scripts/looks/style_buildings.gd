class_name StyleBuildings
extends RefCounted

# The styled buildings (ported from design/style_test/scene.gd): an industrial version (steel, pipes, vents, rust) and a
# whimsical version (plaster, timber, shutters, flower boxes, bunting) of the same block. The look draws the one that
# matches `beautified` and dissolves between them. Options `o`: kiosk (the small block), stack (a smokestack or
# chimney), tank (a gas tank or a flower barrel), nwin, roof / shutter / door colours, tankside, landmark (a gold
# pennant). The model's origin is the middle of its base and it faces +z.


static func ind(hex: String, grime: float = 0.0, emit: float = 0.0, pat: int = 0) -> ShaderMaterial:
	return StyleKit.mat(StyleKit.hexc(hex), 1, grime, emit, pat)


static func whim(hex: String, emit: float = 0.0, pat: int = 0) -> ShaderMaterial:
	return StyleKit.mat(StyleKit.hexc(hex), 2, 0.0, emit, pat)


static func pipe_run(p: Node, pts: Array[Vector3], r: float, m: Material, em: Material) -> void:
	for i: int in range(pts.size() - 1):
		StyleKit.seg(p, pts[i], pts[i + 1], r, m, 8)
	for i: int in range(pts.size()):
		StyleKit.sph(p, r * 1.25, pts[i], em, Vector3.ONE, 8)


static func vine_run(p: Node, pts: Array[Vector3], r: float, flowers: Array[Color]) -> void:
	var stem := StyleKit.mat(StyleKit.hexc("#56753f"), 2)
	var leaf := StyleKit.mat(StyleKit.hexc("#6f9552"), 2)
	var leaf2 := StyleKit.mat(StyleKit.hexc("#8aa55a"), 2)
	var k := 0
	for i: int in range(pts.size() - 1):
		StyleKit.seg(p, pts[i], pts[i + 1], r * 0.55, stem, 5)
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var length := a.distance_to(b)
		var steps := maxi(int(length / 0.42), 1)
		for s: int in range(steps + 1):
			var q := a.lerp(b, float(s) / float(steps))
			var off := Vector3(0.08 * (1 if s % 2 == 0 else -1), 0.05, 0.08)
			StyleKit.sph(p, 0.13, q + off, leaf if s % 2 == 0 else leaf2, Vector3(1, 0.55, 1), 6)
			if s % 3 == 1:
				k += 1
				StyleKit.sph(
					p, 0.1, q + Vector3(0, 0.1, 0.16), StyleKit.mat(flowers[k % flowers.size()], 2), Vector3.ONE, 6
				)


static func build_industrial(p: Node3D, w: float, d: float, h: float, o: Dictionary) -> void:
	var wall := ind("#8d95a1", 1.0)
	var dark := ind("#565d69", 1.0)
	var roof := ind("#4c525d", 1.0, 0.0, 2)
	var steel := ind("#a2aab5", 0.8)
	var pipem := ind("#6f7884", 1.0)
	var pipe_l := ind("#8b94a0", 1.0)
	var rust := ind("#7d4c34", 0.6)
	var hole := ind("#1d2129")
	var kiosk: bool = o.get("kiosk", false)
	StyleKit.box(p, Vector3(w + 0.3, 0.4, d + 0.3), Vector3(0, 0.2, 0), dark)
	StyleKit.box(p, Vector3(w, h, d), Vector3(0, h * 0.5, 0), wall)
	var bands: Array[float] = [h * 0.36, h * 0.74]
	for fy: float in bands:
		StyleKit.box(p, Vector3(w + 0.1, 0.14, d + 0.1), Vector3(0, fy, 0), steel)
		var n := int(w / 0.55)
		for i: int in range(n):
			var x := -w * 0.5 + 0.3 + i * (w - 0.6) / float(n - 1)
			StyleKit.cyl(p, 0.06, 0.06, Vector3(x, fy, d * 0.5 + 0.07), rust, Vector3(PI / 2, 0, 0), -1.0, 6, false)
	# vertical seams
	var ns := int(w / 1.7)
	for i: int in range(1, ns):
		StyleKit.box(
			p, Vector3(0.1, h - 0.4, 0.06), Vector3(-w * 0.5 + i * w / float(ns), h * 0.5 + 0.2, d * 0.5 + 0.03), dark
		)
	# roof slab, rim, rooftop unit
	StyleKit.box(p, Vector3(w + 0.4, 0.28, d + 0.4), Vector3(0, h + 0.14, 0), roof)
	StyleKit.box(p, Vector3(w + 0.4, 0.18, 0.12), Vector3(0, h + 0.37, d * 0.5 + 0.14), dark)
	StyleKit.box(p, Vector3(w + 0.4, 0.18, 0.12), Vector3(0, h + 0.37, -d * 0.5 - 0.14), dark)
	StyleKit.box(p, Vector3(0.12, 0.18, d + 0.4), Vector3(w * 0.5 + 0.14, h + 0.37, 0), dark)
	StyleKit.box(p, Vector3(0.12, 0.18, d + 0.4), Vector3(-w * 0.5 - 0.14, h + 0.37, 0), dark)
	StyleKit.box(p, Vector3(1.3, 0.7, 1.0), Vector3(w * 0.22, h + 0.63, -d * 0.2), pipe_l)
	for k: int in range(3):
		StyleKit.box(p, Vector3(0.9, 0.3, 0.7), Vector3(-w * 0.3 + k * 1.1, h + 0.43, d * 0.2), pipe_l)
		StyleKit.box(p, Vector3(0.7, 0.05, 0.5), Vector3(-w * 0.3 + k * 1.1, h + 0.6, d * 0.2), hole)
	StyleKit.cyl(p, 0.3, 0.1, Vector3(w * 0.22, h + 1.02, -d * 0.2), hole)
	# door
	var dx := -w * 0.5 + 1.0
	StyleKit.box(p, Vector3(1.25, 2.15, 0.1), Vector3(dx, 1.075, d * 0.5 + 0.05), dark)
	StyleKit.box(p, Vector3(1.05, 2.0, 0.12), Vector3(dx, 1.0, d * 0.5 + 0.09), steel)
	StyleKit.box(p, Vector3(1.05, 0.12, 0.14), Vector3(dx, 0.6, d * 0.5 + 0.1), dark)
	StyleKit.box(p, Vector3(1.05, 0.12, 0.14), Vector3(dx, 1.5, d * 0.5 + 0.1), dark)
	StyleKit.sph(p, 0.07, Vector3(dx + 0.38, 1.0, d * 0.5 + 0.2), rust, Vector3.ONE, 6)
	# barred windows
	var nwin: int = o.get("nwin", 2)
	for i: int in range(nwin):
		var x := w * 0.5 - 1.2 - i * 1.9
		var y := h * 0.55
		StyleKit.box(p, Vector3(1.1, 1.0, 0.1), Vector3(x, y, d * 0.5 + 0.05), steel)
		StyleKit.box(p, Vector3(0.92, 0.82, 0.08), Vector3(x, y, d * 0.5 + 0.08), hole)
		for bx: float in [-0.27, 0.0, 0.27]:
			StyleKit.cyl(p, 0.035, 0.84, Vector3(x + bx, y, d * 0.5 + 0.14), pipe_l, Vector3.ZERO, -1.0, 5, false)
	# pipe run with elbows, valve
	var z := d * 0.5 + 0.28
	var x1 := -w * 0.5 + 2.4
	var x2 := w * 0.5 - 0.4
	if kiosk:
		x1 = -w * 0.5 + 1.8
		x2 = w * 0.5 - 0.35
	var pts: Array[Vector3] = [
		Vector3(x1, 0.35, z),
		Vector3(x1, 1.0, z),
		Vector3(x2, 1.0, z),
		Vector3(x2, h - 0.45, z),
		Vector3(-w * 0.5 + 0.6, h - 0.45, z)
	]
	if kiosk:
		pts = [Vector3(x1, 0.35, z), Vector3(x1, 0.9, z), Vector3(x2, 0.9, z), Vector3(x2, h - 0.4, z)]
	pipe_run(p, pts, 0.11, pipem, pipe_l)
	var vx := (x1 + x2) * 0.5
	var vy: float = 1.0 if not kiosk else 0.9
	StyleKit.sph(p, 0.2, Vector3(vx, vy, z), rust, Vector3.ONE, 8)
	StyleKit.cyl(p, 0.06, 0.35, Vector3(vx, vy + 0.3, z), pipem)
	StyleKit.torus(p, 0.03, 0.17, Vector3(vx, vy + 0.5, z), rust)
	for bx: float in [x1 + 0.9, x2 - 0.9]:
		StyleKit.box(p, Vector3(0.12, 0.12, 0.26), Vector3(bx, vy, d * 0.5 + 0.12), dark)
	# exhaust fan
	var fx := -w * 0.5 + 1.7
	if kiosk:
		fx = -w * 0.5 + 0.75
	var fy := h - 1.15 if not kiosk else h - 0.7
	var fr := 0.5 if not kiosk else 0.36
	StyleKit.cyl(p, fr, 0.22, Vector3(fx, fy, d * 0.5 + 0.11), steel, Vector3(PI / 2, 0, 0), -1.0, 12)
	StyleKit.cyl(p, fr * 0.82, 0.05, Vector3(fx, fy, d * 0.5 + 0.23), hole, Vector3(PI / 2, 0, 0), -1.0, 12, false)
	StyleKit.box(p, Vector3(fr * 1.5, 0.12, 0.05), Vector3(fx, fy, d * 0.5 + 0.27), pipe_l, Vector3(0, 0, 0.5), false)
	StyleKit.box(
		p, Vector3(fr * 1.5, 0.12, 0.05), Vector3(fx, fy, d * 0.5 + 0.27), pipe_l, Vector3(0, 0, 0.5 + PI / 2), false
	)
	StyleKit.sph(p, 0.08, Vector3(fx, fy, d * 0.5 + 0.29), rust, Vector3.ONE, 6)
	# louvered vent
	var vxx := 0.0 if not kiosk else w * 0.5 - 1.3
	var vyy := h * 0.55 if not kiosk else h - 0.8
	if not kiosk:
		vxx = -0.3
	StyleKit.box(p, Vector3(0.95, 0.75, 0.1), Vector3(vxx, vyy, d * 0.5 + 0.05), dark)
	for i: int in range(4):
		StyleKit.box(
			p,
			Vector3(0.84, 0.06, 0.16),
			Vector3(vxx, vyy - 0.27 + i * 0.18, d * 0.5 + 0.12),
			pipe_l,
			Vector3(0.5, 0, 0),
			false
		)
	# smokestack
	if o.get("stack", false):
		var sx := -w * 0.5 + 0.9
		var sz := -d * 0.5 + 0.9
		var brick := ind("#767c87", 1.0)
		StyleKit.cyl(p, 0.62, 5.2, Vector3(sx, h + 0.28 + 2.6, sz), brick, Vector3.ZERO, 0.42, 10)
		for by: float in [1.2, 2.9]:
			StyleKit.cyl(p, 0.56, 0.16, Vector3(sx, h + 0.28 + by, sz), steel, Vector3.ZERO, -1.0, 10)
		StyleKit.cyl(p, 0.5, 0.22, Vector3(sx, h + 0.28 + 5.2, sz), ind("#2d3037"), Vector3.ZERO, -1.0, 10)
		var smoke := ind("#4f5560")
		StyleKit.sph(p, 0.55, Vector3(sx + 0.3, h + 6.2, sz), smoke, Vector3(1.2, 0.9, 1.0), 8, false)
		StyleKit.sph(p, 0.75, Vector3(sx + 1.0, h + 7.1, sz), smoke, Vector3(1.2, 0.9, 1.0), 8, false)
		StyleKit.sph(p, 0.95, Vector3(sx + 2.0, h + 7.8, sz), smoke, Vector3(1.3, 0.85, 1.0), 8, false)
	# gas tank
	if o.get("tank", false):
		var side: float = o.get("tankside", 1.0)
		var tx := side * (w * 0.5 + 1.5)
		var tz := d * 0.5 - 1.0
		var tank := ind("#7b838f", 1.0)
		StyleKit.cyl(p, 1.05, 2.5, Vector3(tx, 1.25, tz), tank, Vector3.ZERO, -1.0, 12)
		StyleKit.sph(p, 1.05, Vector3(tx, 2.5, tz), tank, Vector3(1, 0.45, 1), 12)
		for ty: float in [0.6, 1.9]:
			StyleKit.cyl(p, 1.09, 0.13, Vector3(tx, ty, tz), steel, Vector3.ZERO, -1.0, 12)
		# ladder
		StyleKit.box(p, Vector3(0.05, 2.5, 0.05), Vector3(tx - 0.2, 1.25, tz + 1.12), dark, Vector3.ZERO, false)
		StyleKit.box(p, Vector3(0.05, 2.5, 0.05), Vector3(tx + 0.2, 1.25, tz + 1.12), dark, Vector3.ZERO, false)
		for ly: int in range(5):
			StyleKit.box(
				p, Vector3(0.45, 0.04, 0.05), Vector3(tx, 0.4 + ly * 0.5, tz + 1.12), dark, Vector3.ZERO, false
			)
		# connecting pipe + valve
		StyleKit.seg(
			p, Vector3(tx - side * 1.0, 0.9, tz - 0.4), Vector3(side * (w * 0.5), 0.9, tz - 0.4), 0.1, pipem, 8
		)
		StyleKit.sph(p, 0.18, Vector3(tx - side * 1.6, 0.9, tz - 0.4), rust)
		StyleKit.torus(p, 0.03, 0.16, Vector3(tx - side * 1.6, 1.25, tz - 0.4), rust)
		StyleKit.cyl(p, 0.05, 0.3, Vector3(tx - side * 1.6, 1.08, tz - 0.4), pipem)


static func build_whimsical(p: Node3D, w: float, d: float, h: float, o: Dictionary) -> void:
	var kiosk: bool = o.get("kiosk", false)
	var roof_hex: String = o.get("roof", "#ad6249")
	var plaster := whim("#f1dfbd")
	var timber := whim("#7d5438")
	var stone := whim("#bba88c")
	var roofm := whim(roof_hex, 0.0, 1)
	var roof_dk := StyleKit.mat(StyleKit.hexc(roof_hex).darkened(0.25), 2)
	var shutter_hex: String = o.get("shutter", "#5f86b0")
	var shut := whim(shutter_hex)
	var glow := whim("#ffd88a", 0.7)
	var leaf := whim("#6f9552")
	var flowers: Array[Color] = [
		StyleKit.hexc("#d9667a"), StyleKit.hexc("#e5b04a"), StyleKit.hexc("#f3ead2"), StyleKit.hexc("#c0604f")
	]
	StyleKit.box(p, Vector3(w + 0.3, 0.4, d + 0.3), Vector3(0, 0.2, 0), stone)
	StyleKit.box(p, Vector3(w, h, d), Vector3(0, h * 0.5, 0), plaster)
	# timber frame
	var nposts := int(w / 1.7) + 1
	for i: int in range(nposts + 1):
		var x := -w * 0.5 + i * w / float(nposts)
		StyleKit.box(p, Vector3(0.16, h - 0.2, 0.1), Vector3(x, h * 0.5 + 0.1, d * 0.5 + 0.04), timber)
	StyleKit.box(p, Vector3(w + 0.1, 0.22, d + 0.1), Vector3(0, h - 0.1, 0), timber)
	# roof
	var rh := 1.9
	if kiosk:
		var rr := sqrt(w * w + d * d) * 0.5 + 0.15
		StyleKit.cyl(p, rr, 1.2, Vector3(0, h + 0.6, 0), roofm, Vector3.ZERO, 0.08, 8)
		StyleKit.sph(p, 0.18, Vector3(0, h + 1.32, 0), whim("#e5b04a"), Vector3.ONE, 6)
		StyleKit.cyl(p, rr + 0.04, 0.12, Vector3(0, h + 0.06, 0), roof_dk, Vector3.ZERO, -1.0, 8)
	else:
		StyleKit.prism(p, Vector3(d + 1.1, rh, w + 1.0), Vector3(0, h + rh * 0.5, 0), roofm, Vector3(0, PI / 2, 0))
		StyleKit.cyl(p, 0.11, w + 1.1, Vector3(0, h + rh, 0), roof_dk, Vector3(0, 0, PI / 2), -1.0, 6)
	# chimney
	if o.get("stack", false):
		var cx := -w * 0.5 + 0.9
		var cz := -d * 0.5 + 0.9
		var ch := whim("#c4795a")
		var cc := whim("#f1dfbd")
		StyleKit.box(p, Vector3(0.85, 4.6, 0.85), Vector3(cx, h + 2.3, cz), ch)
		for by: float in [1.2, 2.6, 4.0]:
			StyleKit.box(p, Vector3(0.92, 0.28, 0.92), Vector3(cx, h + by, cz), cc)
		StyleKit.prism(p, Vector3(1.1, 0.5, 1.1), Vector3(cx, h + 4.85, cz), roof_dk)
		var puff := whim("#f6ecd8")
		StyleKit.sph(p, 0.45, Vector3(cx + 0.3, h + 5.9, cz), puff, Vector3(1.2, 0.9, 1.0), 8, false)
		StyleKit.sph(p, 0.62, Vector3(cx + 1.0, h + 6.7, cz), puff, Vector3(1.2, 0.9, 1.0), 8, false)
		StyleKit.sph(p, 0.8, Vector3(cx + 2.0, h + 7.3, cz), puff, Vector3(1.3, 0.85, 1.0), 8, false)
	if o.get("landmark", false):
		var gold_f := whim("#f2c14e", 0.5)
		StyleKit.seg(p, Vector3(w * 0.5 - 0.5, h + 0.2, 0.0), Vector3(w * 0.5 - 0.5, h + 3.3, 0.0), 0.05, timber)
		StyleKit.prism(
			p, Vector3(0.9, 0.6, 0.05), Vector3(w * 0.5 - 0.05, h + 3.0, 0.0), gold_f, Vector3(0, 0, -PI / 2), false
		)
		StyleKit.sph(p, 0.1, Vector3(w * 0.5 - 0.5, h + 3.35, 0.0), gold_f, Vector3.ONE, 6, false)
	# door
	var dx := -w * 0.5 + 1.0
	var door_hex: String = o.get("door", "#5f86b0")
	var doorc := whim(door_hex)
	StyleKit.cyl(p, 0.68, 0.1, Vector3(dx, 1.95, d * 0.5 + 0.05), timber, Vector3(PI / 2, 0, 0), -1.0, 12)
	StyleKit.box(p, Vector3(1.36, 1.95, 0.1), Vector3(dx, 0.975, d * 0.5 + 0.05), timber)
	StyleKit.cyl(p, 0.52, 0.12, Vector3(dx, 1.95, d * 0.5 + 0.09), doorc, Vector3(PI / 2, 0, 0), -1.0, 12)
	StyleKit.box(p, Vector3(1.04, 1.95, 0.12), Vector3(dx, 0.975, d * 0.5 + 0.09), doorc)
	StyleKit.sph(p, 0.07, Vector3(dx + 0.36, 1.0, d * 0.5 + 0.2), whim("#e5b04a"), Vector3.ONE, 6)
	StyleKit.box(p, Vector3(1.5, 0.12, 0.5), Vector3(dx, 0.06, d * 0.5 + 0.35), stone)
	# lantern next to door
	var lx := dx + 1.0
	StyleKit.seg(p, Vector3(lx, 2.55, d * 0.5 + 0.02), Vector3(lx, 2.55, d * 0.5 + 0.4), 0.04, timber)
	StyleKit.box(p, Vector3(0.28, 0.4, 0.28), Vector3(lx, 2.25, d * 0.5 + 0.4), whim("#ffcf70", 1.3))
	StyleKit.prism(p, Vector3(0.4, 0.2, 0.4), Vector3(lx, 2.55, d * 0.5 + 0.4), whim("#3f5a52"))
	# windows with shutters and flower boxes
	var nwin: int = o.get("nwin", 2)
	for i: int in range(nwin):
		var x := w * 0.5 - 1.2 - i * 1.9
		var y := h * 0.55
		StyleKit.box(p, Vector3(1.1, 1.0, 0.1), Vector3(x, y, d * 0.5 + 0.05), timber)
		StyleKit.box(p, Vector3(0.9, 0.8, 0.08), Vector3(x, y, d * 0.5 + 0.08), glow)
		StyleKit.box(p, Vector3(0.06, 0.82, 0.05), Vector3(x, y, d * 0.5 + 0.13), timber)
		StyleKit.box(p, Vector3(0.92, 0.06, 0.05), Vector3(x, y, d * 0.5 + 0.13), timber)
		for sx: float in [-0.72, 0.72]:
			StyleKit.box(p, Vector3(0.32, 1.0, 0.08), Vector3(x + sx, y, d * 0.5 + 0.1), shut)
		StyleKit.box(p, Vector3(1.2, 0.26, 0.32), Vector3(x, y - 0.62, d * 0.5 + 0.18), timber)
		for k: int in range(5):
			var fxx := x - 0.46 + k * 0.23
			StyleKit.sph(p, 0.12, Vector3(fxx, y - 0.4, d * 0.5 + 0.2), leaf, Vector3(1, 0.8, 1), 6, false)
			StyleKit.sph(
				p,
				0.1,
				Vector3(fxx, y - 0.28, d * 0.5 + 0.26),
				StyleKit.mat(flowers[(k + i) % flowers.size()], 2),
				Vector3.ONE,
				6,
				false
			)
	# vines where pipes were
	var z := d * 0.5 + 0.2
	var x1 := -w * 0.5 + 2.4
	var x2 := w * 0.5 - 0.4
	if kiosk:
		x1 = -w * 0.5 + 1.8
		x2 = w * 0.5 - 0.35
	var pts: Array[Vector3] = [
		Vector3(x1, 0.35, z),
		Vector3(x1, 1.0, z),
		Vector3(x2, 1.0, z),
		Vector3(x2, h - 0.45, z),
		Vector3(-w * 0.5 + 0.6, h - 0.45, z)
	]
	if kiosk:
		pts = [Vector3(x1, 0.35, z), Vector3(x1, 0.9, z), Vector3(x2, 0.9, z), Vector3(x2, h - 0.4, z)]
	vine_run(p, pts, 0.11, flowers)
	var vx := (x1 + x2) * 0.5
	var vy: float = 1.0 if not kiosk else 0.9
	for k: int in range(6):
		var a := k * TAU / 6.0
		StyleKit.sph(
			p,
			0.11,
			Vector3(vx + cos(a) * 0.2, vy + 0.15 + sin(a) * 0.2, z + 0.12),
			whim("#f3ead2"),
			Vector3.ONE,
			6,
			false
		)
	StyleKit.sph(p, 0.1, Vector3(vx, vy + 0.15, z + 0.2), whim("#e5b04a"), Vector3.ONE, 6, false)
	# pinwheel where the fan was
	var fx := -w * 0.5 + 1.7
	var fy := h - 1.15
	if kiosk:
		fx = -w * 0.5 + 0.75
		fy = h - 0.7
	StyleKit.seg(p, Vector3(fx, fy - 0.6, d * 0.5 + 0.1), Vector3(fx, fy, d * 0.5 + 0.35), 0.035, timber)
	var pw: Array[String] = ["#d9667a", "#e5b04a", "#5f86b0", "#f3ead2"]
	for k: int in range(4):
		var a := k * PI / 2.0
		StyleKit.prism(
			p,
			Vector3(0.36, 0.36, 0.04),
			Vector3(fx + sin(-a) * 0.17, fy + cos(a) * 0.17, d * 0.5 + 0.4),
			whim(pw[k]),
			Vector3(0, 0, a),
			false
		)
	StyleKit.sph(p, 0.05, Vector3(fx, fy, d * 0.5 + 0.44), timber, Vector3.ONE, 6)
	# birdhouse where the vent was
	var bx := -0.3 if not kiosk else w * 0.5 - 1.3
	var by := h * 0.55 if not kiosk else h - 0.8
	StyleKit.box(p, Vector3(0.06, 0.12, 0.3), Vector3(bx, by - 0.28, d * 0.5 + 0.15), timber)
	StyleKit.box(p, Vector3(0.5, 0.5, 0.42), Vector3(bx, by, d * 0.5 + 0.3), whim("#d8a35a"))
	StyleKit.prism(p, Vector3(0.7, 0.34, 0.55), Vector3(bx, by + 0.4, d * 0.5 + 0.3), whim("#5f86b0"))
	StyleKit.cyl(
		p, 0.09, 0.04, Vector3(bx, by + 0.02, d * 0.5 + 0.52), whim("#2a1f1c"), Vector3(PI / 2, 0, 0), -1.0, 8, false
	)
	StyleKit.cyl(p, 0.025, 0.2, Vector3(bx, by - 0.2, d * 0.5 + 0.58), timber, Vector3(PI / 2, 0, 0), -1.0, 5, false)
	# bunting along the eave
	var n := int(w / 0.42)
	var cols: Array[Color] = [
		StyleKit.hexc("#d9667a"),
		StyleKit.hexc("#e5b04a"),
		StyleKit.hexc("#5f86b0"),
		StyleKit.hexc("#f3ead2"),
		StyleKit.hexc("#7f9d62")
	]
	var prev := Vector3.ZERO
	for i: int in range(n + 1):
		var t := float(i) / float(n)
		var xx := lerpf(-w * 0.5 + 0.1, w * 0.5 - 0.1, t)
		var yy := h - 0.28 - 0.4 * 4.0 * t * (1.0 - t)
		var pt := Vector3(xx, yy, d * 0.5 + 0.2)
		if i > 0:
			StyleKit.seg(p, prev, pt, 0.02, timber, 4, false)
			StyleKit.prism(
				p,
				Vector3(0.3, 0.34, 0.03),
				(prev + pt) * 0.5 + Vector3(0, -0.18, 0),
				StyleKit.mat(cols[i % cols.size()], 2),
				Vector3(0, 0, PI),
				false
			)
		prev = pt
	# kiosk: striped awning + kettle
	if kiosk:
		for i: int in range(8):
			var xs := -w * 0.5 + (i + 0.5) * w / 8.0
			var stripe := whim("#d9667a") if i % 2 == 0 else whim("#f3ead2")
			StyleKit.box(
				p, Vector3(w / 8.0, 0.08, 1.0), Vector3(xs, h - 0.3, d * 0.5 + 0.55), stripe, Vector3(0.35, 0, 0)
			)
			StyleKit.cyl(
				p, w / 16.0, 0.08, Vector3(xs, h - 0.52, d * 0.5 + 1.0), stripe, Vector3(PI / 2, 0, 0), -1.0, 8
			)
		StyleKit.box(p, Vector3(w * 0.9, 0.12, 0.5), Vector3(0, 1.05, d * 0.5 + 0.35), timber)
		StyleKit.sph(p, 0.26, Vector3(w * 0.25, 1.4, d * 0.5 + 0.4), whim("#c0604f"), Vector3(1, 0.9, 1), 8)
		StyleKit.seg(
			p,
			Vector3(w * 0.25 + 0.2, 1.45, d * 0.5 + 0.4),
			Vector3(w * 0.25 + 0.42, 1.6, d * 0.5 + 0.4),
			0.05,
			whim("#c0604f")
		)
		StyleKit.sph(p, 0.07, Vector3(w * 0.25, 1.72, d * 0.5 + 0.4), whim("#e5b04a"), Vector3.ONE, 6)
	# flower barrel where the tank was
	if o.get("tank", false):
		var side: float = o.get("tankside", 1.0)
		var tx := side * (w * 0.5 + 1.5)
		var tz := d * 0.5 - 1.0
		var wood := whim("#9a6a46")
		StyleKit.cyl(p, 0.8, 1.5, Vector3(tx, 0.75, tz), wood, Vector3.ZERO, 0.8, 12)
		StyleKit.sph(p, 0.98, Vector3(tx, 0.75, tz), wood, Vector3(1, 0.85, 1), 12)
		for ty: float in [0.35, 1.15]:
			StyleKit.cyl(p, 0.96, 0.1, Vector3(tx, ty, tz), whim("#4c4a50"), Vector3.ZERO, -1.0, 12)
		StyleKit.sph(p, 1.0, Vector3(tx, 1.5, tz), leaf, Vector3(1, 0.55, 1), 10)
		for k: int in range(16):
			var a := k * 2.4
			var rr := 0.2 + 0.7 * fmod(k * 0.37, 1.0)
			StyleKit.sph(
				p,
				0.16,
				Vector3(tx + cos(a) * rr, 1.8 + 0.1 * fmod(k * 0.7, 1.0), tz + sin(a) * rr),
				StyleKit.mat(flowers[k % flowers.size()], 2),
				Vector3.ONE,
				6,
				false
			)
