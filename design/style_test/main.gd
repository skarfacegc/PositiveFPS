extends Node

const TITLE := "PositiveFPS — RENDERING STYLE SAMPLES (closes automatically)"
const OUT := "C:/Users/amw1/OneDrive/Documents/Development/PositiveFPS/design/renders/"
var sv: SubViewport
var sc: StyleScene

func _ready() -> void:
	DisplayServer.window_set_title(TITLE)
	DirAccess.make_dir_recursive_absolute(OUT)
	sv = SubViewport.new()
	sv.size = Vector2i(480, 270)
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_DISABLED
	add_child(sv)
	sc = StyleScene.new()
	sv.add_child(sc)
	var cl := CanvasLayer.new()
	add_child(cl)
	var tr := TextureRect.new()
	tr.texture = sv.get_texture()
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cl.add_child(tr)
	var lab := Label.new()
	lab.text = "RENDERING STYLE SAMPLES - this window closes by itself"
	lab.add_theme_font_size_override("font_size", 22)
	lab.add_theme_color_override("font_color", Color.WHITE)
	lab.add_theme_color_override("font_outline_color", Color.BLACK)
	lab.add_theme_constant_override("outline_size", 8)
	cl.add_child(lab)
	get_tree().create_timer(60.0).timeout.connect(func(): get_tree().quit())
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

func save_up(img: Image, fname: String) -> Image:
	var up := img.duplicate() as Image
	up.resize(1920, 1080, Image.INTERPOLATE_NEAREST)
	up.save_png(OUT + fname)
	print("saved ", fname)
	return up

func run() -> void:
	var shots := [
		["topdown_joy_000.png", "topdown", 0.0, []],
		["topdown_joy_050.png", "topdown", 0.5, []],
		["topdown_joy_100.png", "topdown", 1.0, []],
		["closeup_transformation.png", "closeup", 0.5, [Vector4(-17.5, -2.5, 8.6, 0), Vector4(-11.0, 2.8, 2.6, 0)]],
		["firstperson.png", "fps", 0.5, []],
	]
	var ups: Array = []
	for s in shots:
		sc.circles_override = s[3]
		sc.set_joy(s[2])
		sc.set_shot(s[1])
		var img := await grab()
		ups.append(save_up(img, s[0]))

	# comparison: smooth full-res vs pixel pipeline (same frame)
	sc.circles_override = []
	sc.set_joy(0.5)
	sc.set_shot("topdown")
	sc.set_pixel_mode(false)
	sv.size = Vector2i(960, 540)
	sv.msaa_3d = Viewport.MSAA_4X
	var smooth := await grab()
	sc.set_pixel_mode(true)
	sv.size = Vector2i(480, 270)
	sv.msaa_3d = Viewport.MSAA_DISABLED
	var pix := await grab()
	pix.resize(960, 540, Image.INTERPOLATE_NEAREST)
	var comp := Image.create(1920, 540, false, Image.FORMAT_RGBA8)
	comp.blit_rect(smooth, Rect2i(0, 0, 960, 540), Vector2i(0, 0))
	comp.blit_rect(pix, Rect2i(0, 0, 960, 540), Vector2i(960, 0))
	comp.save_png(OUT + "comparison_smooth_vs_pixel.png")
	print("saved comparison")

	# contact sheet 1-5
	var sheet := Image.create(1920, 740, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.09, 0.09, 0.1))
	for i in range(ups.size()):
		var t := (ups[i] as Image).duplicate() as Image
		t.resize(630, 354, Image.INTERPOLATE_LANCZOS)
		var col := i % 3
		var row := i / 3
		var ox := 10 + col * 640
		if row == 1:
			ox = 330 + col * 640
		sheet.blit_rect(t, Rect2i(0, 0, 630, 354), Vector2i(ox, 10 + row * 364))
	sheet.save_png(OUT + "contact_sheet.png")
	print("saved contact sheet")
	get_tree().quit()
