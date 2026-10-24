class_name MiniMap
extends Control
# UI mockup, drawn in the same low-res pixel pass as the 3D scene (so it is pixel-crisp too).
# Round parchment-framed minimap, top-left: whole-plaza top-down view, living border, landmark star, player,
# dark people, camera view. Plus one off-screen arrow pointing at a border gap.

const X0 := -22.0
const Z0 := -23.5
const K := 2.727           # map pixels per world unit
const C := Vector2(72, 72) # circle centre (internal px); 128 px diameter = 20% of the 640 px frame
const R := 64.0
const INNER := Rect2(12, 12, 120, 120)
const RIN := 58.0          # usable radius for content

var sc: StyleScene
var tex: ImageTexture
var show_border := false
var show_arrow := false
var show_players := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func w2m(x: float, z: float) -> Vector2:
	return INNER.position + Vector2((x - X0) * K, (z - Z0) * K)

func inside(p: Vector2, pad := 0.0) -> bool:
	return p.distance_to(C) < RIN - pad

func refresh(scene: StyleScene) -> void:
	sc = scene
	var img := Image.create(120, 120, false, Image.FORMAT_RGBA8)
	var grey_a := Color("#7f8896")
	var grey_b := Color("#757d8b")
	var warm_a := Color("#ead09a")
	var warm_b := Color("#e0c088")
	for py in range(120):
		for px in range(120):
			if Vector2(px + 0.5 - 60.0, py + 0.5 - 60.0).length() > RIN:
				img.set_pixel(px, py, Color(0, 0, 0, 0))
				continue
			var wx := X0 + (px + 0.5) / K
			var wz := Z0 + (py + 0.5) / K
			var f := sc.joy_field(Vector2(wx, wz), sc.cur_circles)
			var chk := ((px * 7 + py * 13) % 11) < 2
			var col: Color = (warm_a if not chk else warm_b) if f > 0.0 else (grey_a if not chk else grey_b)
			if f > 0.0 and f < 0.6:
				col = col.darkened(0.08)
			img.set_pixel(px, py, col)
	tex = ImageTexture.create_from_image(img)
	queue_redraw()

func _star(c: Vector2, r: float, fill: Color, line: Color) -> void:
	var pts := PackedVector2Array()
	for i in range(10):
		var rr := r if i % 2 == 0 else r * 0.45
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, line, 1.0)

func _draw() -> void:
	if sc == null or tex == null:
		return
	draw_circle(C, R, Color("#3a2a20"))
	draw_texture(tex, INNER.position)
	# buildings
	for b in sc.bldg_defs:
		var c := w2m(b["x"], b["z"])
		if not inside(c, 4.0):
			continue
		var sz := Vector2(b["w"], b["d"]) * K
		var warm := sc.joy_field(Vector2(b["x"], b["z"]), sc.cur_circles) > 0.0
		var r := Rect2(c - sz * 0.5, sz)
		draw_rect(r, Color("#b8744d") if warm else Color("#4d5461"))
		draw_rect(r, Color("#2c211b"), false, 1.0)
	# camera view rectangle (what the main frame shows), dotted where it is inside the circle
	var hw := sc.cam_size * (16.0 / 9.0) * 0.5
	var hz := sc.cam_size * 0.5 / sin(sc.cam_pitch)
	var a := w2m(sc.cam_tgt.x - hw, sc.cam_tgt.z - hz)
	var b2 := w2m(sc.cam_tgt.x + hw, sc.cam_tgt.z + hz)
	var steps := 90
	for i in range(steps + 1):
		var t := float(i) / steps
		for pt in [Vector2(lerpf(a.x, b2.x, t), a.y), Vector2(lerpf(a.x, b2.x, t), b2.y), Vector2(a.x, lerpf(a.y, b2.y, t)), Vector2(b2.x, lerpf(a.y, b2.y, t))]:
			if inside(pt):
				draw_rect(Rect2(pt, Vector2(1, 1)), Color(1, 1, 1, 0.6))
	# living border
	if show_border and sc.border_info.size() > 0:
		for s in sc.border_info["segs"]:
			var p0 := w2m(s[0].x, s[0].y)
			var p1 := w2m(s[1].x, s[1].y)
			if inside(p0) and inside(p1):
				draw_line(p0, p1, Color("#3a2a20"), 4.0)
		for s in sc.border_info["segs"]:
			var p0 := w2m(s[0].x, s[0].y)
			var p1 := w2m(s[1].x, s[1].y)
			if inside(p0) and inside(p1):
				draw_line(p0, p1, Color("#e2402f") if s[2] else Color("#ffd24a"), 2.0)
		for g in sc.border_info["gaps"]:
			var gm := w2m(g.x, g.y)
			if inside(gm):
				draw_circle(gm, 3.6, Color("#3a2a20"))
				draw_circle(gm, 2.6, Color("#e2402f"))
		for p in sc.border_info["people"]:
			var pm := w2m(p.x, p.y)
			if inside(pm):
				draw_rect(Rect2(pm - Vector2(2, 2), Vector2(4, 4)), Color("#3a2a20"))
				draw_rect(Rect2(pm - Vector2(1.5, 1.5), Vector2(3, 3)), Color("#fff3c4"))
	# dark people
	var darks: Array = []
	for g in sc.gloomy_nodes:
		if is_instance_valid(g) and g.visible:
			darks.append(Vector2(g.position.x, g.position.z))
	for d in sc.dark_spots:
		darks.append(d)
	for d in darks:
		var dm := w2m(d.x, d.y)
		if inside(dm, 2.0):
			draw_circle(dm, 2.8, Color("#c9ced8"))
			draw_circle(dm, 2.0, Color("#16181d"))
	# landmark
	for b in sc.bldg_defs:
		if b["landmark"]:
			var lm := w2m(b["x"], b["z"]) + Vector2(0, 0.5)
			if inside(lm, 4.0):
				_star(lm, 5.2, Color("#ffd24a"), Color("#2c211b"))
	# player
	if show_players:
		var pm2 := w2m(sc.player_node.position.x, sc.player_node.position.z)
		draw_circle(pm2, 4.4, Color("#3a2a20"))
		draw_circle(pm2, 3.4, Color("#ffe27a"))
		draw_circle(pm2, 1.6, Color("#ffffff"))
	# round parchment frame
	draw_arc(C, R - 3.0, 0, TAU, 72, Color("#7a5538"), 2.0)
	draw_arc(C, R - 0.5, 0, TAU, 72, Color("#f0d9a8"), 3.0)
	draw_arc(C, R + 1.5, 0, TAU, 72, Color("#3a2a20"), 1.5)
	# off-screen arrow
	if show_arrow and sc.border_info.size() > 0 and sc.border_info["gaps"].size() > 1:
		var g: Vector2 = sc.border_info["gaps"][1]
		var sp := sc.cam.unproject_position(Vector3(g.x, 0.0, g.y))
		var view := Rect2(Vector2.ZERO, Vector2(640, 360))
		if not view.grow(-4).has_point(sp):
			var c := Vector2(320, 180)
			var dir := sp - c
			var m := 20.0
			var tx := (320.0 - m) / absf(dir.x) if absf(dir.x) > 0.001 else 1e9
			var ty := (180.0 - m) / absf(dir.y) if absf(dir.y) > 0.001 else 1e9
			var pos := c + dir * minf(tx, ty)
			# keep clear of the round minimap in the top-left corner
			if pos.distance_to(C) < R + 22.0:
				pos.y = C.y + R + 22.0
			var dn := dir.normalized()
			var nn := Vector2(-dn.y, dn.x)
			draw_circle(pos, 13.0, Color("#3a2a20"))
			draw_arc(pos, 12.0, 0, TAU, 28, Color("#f0d9a8"), 2.0)
			var tri := PackedVector2Array([pos + dn * 8.0, pos - dn * 4.0 + nn * 6.5, pos - dn * 1.0, pos - dn * 4.0 - nn * 6.5])
			draw_colored_polygon(tri, Color("#e2402f"))
			var cl := tri.duplicate()
			cl.append(tri[0])
			draw_polyline(cl, Color("#ffd9cf"), 1.0)
