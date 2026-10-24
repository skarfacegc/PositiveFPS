extends Node
# Renders the style samples. Internal pixel resolution 640x360, nearest-upscaled 3x to 1920x1080.

const TITLE := "PositiveFPS — RENDERING STYLE SAMPLES (closes automatically)"
const OUT := "C:/Users/amw1/OneDrive/Documents/Development/PositiveFPS/design/renders/"
const W := 640
const H := 360
var sv: SubViewport
var sc: StyleScene
var mm: MiniMap

func _ready() -> void:
	DisplayServer.window_set_title(TITLE)
	DirAccess.make_dir_recursive_absolute(OUT)
	sv = SubViewport.new()
	sv.size = Vector2i(W, H)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	add_child(sv)
	sc = StyleScene.new()
	sv.add_child(sc)
	var hud := CanvasLayer.new()
	sv.add_child(hud)
	mm = MiniMap.new()
	mm.size = Vector2(W, H)
	hud.add_child(mm)
	mm.visible = false
	var cl := CanvasLayer.new()
	add_child(cl)
	var tr := TextureRect.new()
	tr.texture = sv.get_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(tr)
	var lab := Label.new()
	lab.text = "RENDERING STYLE SAMPLES - this window closes by itself"
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 8)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(lab)
	get_tree().create_timer(120.0).timeout.connect(func(): get_tree().quit())
	run.call_deferred()

func settle(n := 8) -> void:
	for i in range(n):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func grab() -> Image:
	await settle()
	var img := sv.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img

func up3(img: Image) -> Image:
	var up := img.duplicate() as Image
	up.resize(W * 3, H * 3, Image.INTERPOLATE_NEAREST)
	return up

func save_up(img: Image, fname: String) -> Image:
	var up := up3(img)
	up.save_png(OUT + fname)
	print("saved ", fname)
	return up

func reset_scene() -> void:
	sc.clear_dynamic()
	sc.circles_override = []
	for n in sc.people_nodes:
		n.visible = true
	for n in sc.gloomy_nodes:
		n.visible = true
	mm.show_border = false
	mm.show_arrow = false
	mm.visible = false

func shot_plain(joy: float, with_gloomy: bool, with_hud: bool) -> Image:
	reset_scene()
	for n in sc.gloomy_nodes:
		n.visible = with_gloomy
	sc.set_joy(joy)
	sc.set_shot("topdown")
	mm.visible = with_hud
	if with_hud:
		mm.refresh(sc)
	return await grab()

func shot_border() -> Image:
	reset_scene()
	var cs := [Vector4(0.6, 3.2, 5.8, 0), Vector4(-6.0, 3.0, 4.6, 0), Vector4(6.4, 3.0, 4.6, 0), Vector4(-11.0, 2.5, 3.2, 0)]
	sc.circles_override = cs
	sc.set_joy(0.5)
	sc.build_border(cs, Vector2(0.5, 3.2), 16, [0, 8])
	var info: Dictionary = sc.border_info
	# regular people too close to the line would overlap the border people: hide them
	for n in sc.people_nodes:
		var q := Vector2(n.position.x, n.position.z)
		for p in info["people"]:
			if q.distance_to(p) < 2.3:
				n.visible = false
	for n in sc.people_nodes:
		var q2 := Vector2(n.position.x, n.position.z)
		for gp in info["gaps"]:
			if q2.distance_to(gp) < 4.2:
				n.visible = false
	for n in sc.gloomy_nodes:
		n.visible = false
	# dark people: one pushing through the visible gap, two lingering outside the line
	var g: Vector2 = info["gaps"][0]
	var o: Vector2 = info["gap_out"][0]
	var tang := Vector2(-o.y, o.x)
	var push := g + o * 0.2
	sc.add_gloomy(Vector3(push.x, 0, push.y), atan2(-o.x, -o.y) + 0.1, sc.dyn, false)
	sc.dark_spots.append(push)
	for off in [g + o * 2.8 - tang * 2.2]:
		sc.add_gloomy(Vector3(off.x, 0, off.y), atan2(-o.x, -o.y) + 0.3, sc.dyn, false)
		sc.dark_spots.append(off)
	var g2: Vector2 = info["gaps"][1]
	var o2: Vector2 = info["gap_out"][1]
	var off2 := g2 + o2 * 2.4
	sc.add_gloomy(Vector3(off2.x, 0, off2.y), atan2(-o2.x, -o2.y), sc.dyn, false)
	sc.dark_spots.append(off2)
	sc.set_joy(0.5)
	sc.set_shot("topdown")
	mm.visible = true
	mm.show_border = true
	mm.show_arrow = true
	mm.refresh(sc)
	sc.set_pulse(1.0)
	return await grab()

func run() -> void:
	var ups: Array = []
	var names := ["topdown_joy_000.png", "topdown_joy_050.png", "topdown_joy_100.png", "closeup_transformation.png"]
	ups.append(save_up(await shot_plain(0.0, true, true), names[0]))
	ups.append(save_up(await shot_border(), names[1]))
	await make_gap_frames()
	ups.append(save_up(await shot_plain(1.0, false, true), names[2]))

	# close-up of the transformation edge (composition kept from review 1)
	reset_scene()
	for n in sc.gloomy_nodes:
		n.visible = false
	sc.circles_override = [Vector4(-17.5, -2.5, 8.6, 0), Vector4(-11.0, 2.8, 2.6, 0)]
	sc.set_joy(0.5)
	sc.set_shot("closeup")
	ups.append(save_up(await grab(), names[3]))

	await make_lineup()

	# comparison: smooth full-res vs pixel pipeline (same frame), 2 x 1280x720
	reset_scene()
	sc.set_joy(0.5)
	sc.set_shot("topdown")
	sc.set_pixel_mode(false)
	sv.size = Vector2i(1280, 720)
	sv.msaa_3d = Viewport.MSAA_4X
	var smooth := await grab()
	sc.set_pixel_mode(true)
	sv.size = Vector2i(W, H)
	sv.msaa_3d = Viewport.MSAA_DISABLED
	var pix := await grab()
	pix.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	var comp := Image.create(2560, 720, false, Image.FORMAT_RGBA8)
	comp.blit_rect(smooth, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	comp.blit_rect(pix, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
	comp.save_png(OUT + "comparison_smooth_vs_pixel.png")
	print("saved comparison")

	# contact sheet of the four main shots (2 x 2)
	var sheet := Image.create(1920, 1100, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.09, 0.09, 0.1))
	for i in range(ups.size()):
		var t := (ups[i] as Image).duplicate() as Image
		t.resize(940, 529, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(t, Rect2i(0, 0, 940, 529), Vector2i(10 + (i % 2) * 950, 10 + (i / 2) * 539))
	sheet.save_png(OUT + "contact_sheet.png")
	print("saved contact sheet")
	get_tree().quit()

# 8 crisp frames across one pulse period of the right-side gap (scene must still hold the border shot)
func make_gap_frames() -> void:
	var dir := OUT + "gap_pulse/"
	DirAccess.make_dir_recursive_absolute(dir)
	mm.visible = false
	var g: Vector2 = sc.border_info["gaps"][0]
	var sp := sc.cam.unproject_position(Vector3(g.x, 0.0, g.y))
	var rx := clampi(int(sp.x) - 160, 0, W - 320)
	var ry := clampi(int(sp.y) - 100, 0, H - 180)
	for i in range(8):
		sc.set_pulse(sc.pulse_value(i * 1.2 / 8.0))
		var img := await grab()
		var crop := img.get_region(Rect2i(rx, ry, 320, 180))
		crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
		crop.save_png(dir + "frame_%02d.png" % i)
	sc.set_pulse(1.0)
	mm.visible = true
	var f := FileAccess.open(OUT + "gap_pulse.html", FileAccess.WRITE)
	var strip := ""
	for i in range(8):
		strip += '<img src="gap_pulse/frame_%02d.png" alt="frame %d">' % [i, i]
	f.store_string("""<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Border gap pulse</title>
<style>
:root{--bg:#f3ecdf;--fg:#2b2018;--card:#e6dccb}
@media (prefers-color-scheme:dark){:root{--bg:#1b1613;--fg:#efe3d0;--card:#2a221d}}
body{margin:0;padding:16px;background:var(--bg);color:var(--fg);font-family:system-ui,sans-serif}
h1{font-size:1.1rem;margin:0 0 4px}p{margin:0 0 12px;opacity:.8;font-size:.9rem}
#main{display:block;width:100%;max-width:960px;image-rendering:pixelated;border-radius:6px;background:var(--card)}
#strip{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;max-width:960px;margin-top:12px}
#strip img{width:100%;image-rendering:pixelated;border-radius:4px;background:var(--card)}
</style></head><body>
<h1>Border gap pulse (review 4)</h1>
<p>8 frames across one 1.2 s period (150 ms each), eased in/out. Frame 4 is the peak, frame 0 the quiet trough.</p>
<img id="main" src="gap_pulse/frame_00.png" alt="gap pulse loop">
<div id="strip">""" + strip + """</div>
<script>
var i=0,m=document.getElementById('main');
setInterval(function(){i=(i+1)%8;m.src='gap_pulse/frame_0'+i+'.png';},150);
</script></body></html>""")
	f.close()
	print("saved gap frames")

# character sheet: gameplay-scale row of all 10, then three 2x-zoom rows, composed at 1920 px wide
func make_lineup() -> void:
	reset_scene()
	sc.circles_override = sc.lineup_circles.duplicate()
	sc.set_joy(0.5)
	var specs := [
		{"x": 0.0, "size": 14.5, "show": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]},
		{"x": -8.05, "size": 6.0, "show": [0, 1, 2, 3]},
		{"x": 0.0, "size": 6.0, "show": [4, 5, 6]},
		{"x": 7.6, "size": 6.0, "show": [7, 8, 9]},
	]
	var shots := []
	for sp in specs:
		for i in range(sc.lineup_nodes.size()):
			sc.lineup_nodes[i].visible = i in sp["show"]
		sc.set_shot("lineup", sp)
		var img := await grab()
		var proj := []
		for i in range(sc.lineup_pos.size()):
			proj.append(sc.cam.unproject_position(sc.lineup_pos[i]))
		shots.append({"img": img, "proj": proj})
	for n in sc.lineup_nodes:
		n.visible = true
	var rows := [
		{"s": 0, "y0": 130, "h": 90, "idx": [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "title": "GAMEPLAY SCALE (same zoom as the main frames)"},
		{"s": 1, "y0": 122, "h": 110, "idx": [0, 1, 2, 3], "title": "2x ZOOM - GREY: music (horn), art (brush), nature (flower), dark person"},
		{"s": 2, "y0": 108, "h": 118, "idx": [4, 5, 6], "title": "2x ZOOM - JOYFUL: music (horn), art (brush), nature (flower)"},
		{"s": 3, "y0": 80, "h": 160, "idx": [7, 8, 9], "title": "2x ZOOM - PLAYER OPTIONS (A is CHOSEN and used in all gameplay shots)"},
	]
	var total_h := 0
	for r in rows:
		total_h += r["h"] * 3
	var canvas := Image.create(1920, total_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color("#201a17"))
	var y := 0
	var label_specs: Array = []
	for r in rows:
		var img: Image = shots[r["s"]]["img"]
		var crop := img.get_region(Rect2i(0, r["y0"], W, r["h"]))
		crop.resize(W * 3, r["h"] * 3, Image.INTERPOLATE_NEAREST)
		canvas.blit_rect(crop, Rect2i(0, 0, W * 3, r["h"] * 3), Vector2i(0, y))
		label_specs.append({"y": y, "title": r["title"], "idx": r["idx"], "proj": shots[r["s"]]["proj"]})
		y += r["h"] * 3
	var lv := SubViewport.new()
	lv.size = Vector2i(1920, total_h)
	lv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(lv)
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(canvas)
	lv.add_child(tr)
	var names := ["music", "art", "nature", "dark person", "music", "art", "nature", "A: CHOSEN - wide-brim hat + feather", "B: knit beanie + pom-pom", "C: flat cap + patch"]
	for ls in label_specs:
		var t := Label.new()
		t.text = ls["title"]
		t.position = Vector2(12, ls["y"] + 6)
		_style_label(t, 22)
		lv.add_child(t)
		for i in ls["idx"]:
			var p: Vector2 = ls["proj"][i]
			var n := Label.new()
			n.text = names[i] if not (i >= 7 and ls["y"] == 0) else ["A", "B", "C"][i - 7]
			n.position = Vector2(p.x * 3.0 - (150.0 if (i >= 7 and ls["y"] != 0) else 40.0), ls["y"] + 36)
			_style_label(n, 20, Color("#ffe9b0"))
			lv.add_child(n)
	await settle()
	var out := lv.get_texture().get_image()
	out.convert(Image.FORMAT_RGBA8)
	out.save_png(OUT + "people_lineup.png")
	print("saved lineup")
	lv.queue_free()

func _style_label(l: Label, size: int, col := Color.WHITE) -> void:
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.07, 0.05))
	l.add_theme_constant_override("outline_size", 6)
