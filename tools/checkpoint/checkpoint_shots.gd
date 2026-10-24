extends Node

# Renders the graphics checkpoint screenshots of the GAME (not design/style_test). Run by tools/checkpoint_shots.py:
#   Godot --path . res://tools/checkpoint/checkpoint_shots.tscn -- --out <dir> [--stats-only]
# It loads the real level, builds a fixed scenario through the game's own API (a seeded level; rescue a few people, form
# a border with a gap, a dark person pressing it, a beautified building, mid-night), freezes the rules, then takes the
# same shots in the placeholder look and, after flipping the look in place (F4), in the styled look. It also times the
# frames of each look. The window is titled so nobody mistakes it for the game, never captures the mouse, and the
# process quits by itself.

const TITLE := "PositiveFPS — RENDERING CHECKPOINT SCREENSHOTS (closes automatically)"
const HARD_TIMEOUT := 60.0
const FAR := Vector3(31.0, 0.0, 31.0)
# The ring of rescued people: centre, radius and how many. With these numbers the border has one gap (see stats).

var out_dir: String = "res://design/renders/checkpoint_01"
var stats_only: bool = false
var ring_radius: float = 6.6
var ring_count: int = 16
var ring_centre := Vector3(14.5, 0.0, -14.0)
var relapse_count: int = 0
var settle_frames: int = 480
var main: TopDownMain
var gap_spot := Vector3.ZERO
var timings: Dictionary = {}


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i: int in range(args.size()):
		if args[i] == "--out" and i + 1 < args.size():
			out_dir = args[i + 1]
		if args[i] == "--stats-only":
			stats_only = true
		if args[i] == "--count" and i + 1 < args.size():
			ring_count = int(args[i + 1])
		if args[i] == "--cx" and i + 1 < args.size():
			ring_centre.x = float(args[i + 1])
		if args[i] == "--cz" and i + 1 < args.size():
			ring_centre.z = float(args[i + 1])
		if args[i] == "--relapse" and i + 1 < args.size():
			relapse_count = int(args[i + 1])
		if args[i] == "--settle" and i + 1 < args.size():
			settle_frames = int(args[i + 1])
		if args[i] == "--radius" and i + 1 < args.size():
			ring_radius = float(args[i + 1])
	get_tree().create_timer(HARD_TIMEOUT).timeout.connect(_quit)
	DisplayServer.window_set_title(TITLE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	DisplayServer.window_set_title(TITLE)
	await get_tree().process_frame
	_build_scenario()
	if stats_only:
		_print_stats()
		_quit()
		return
	await _take_shots()
	_quit()


func _quit() -> void:
	get_tree().quit()


# ---- The scenario ------------------------------------------------------------------------------------------------


func _build_scenario() -> void:
	var people := main.people
	for p: Person in people:
		p.global_position = FAR
		p.gloom = 0.45
	# Some grey people standing about in view, away from the ring: a few light, a few grey.
	var greys: Array[Vector3] = [
		Vector3(24.0, 0.0, -6.0), Vector3(-2.0, 0.0, -8.0), Vector3(2.0, 0.0, -20.0), Vector3(21.0, 0.0, -22.0)
	]
	var first_grey := ring_count
	for i: int in range(greys.size()):
		var p := people[first_grey + i]
		p.global_position = greys[i]
		p.gloom = 0.2 if i % 2 == 0 else 0.5
		p.joy = 0.0
	# The rescued ring.
	for i: int in range(ring_count):
		var a := TAU * float(i) / float(ring_count) + 0.3
		var p := people[i]
		p.gloom = 0.0
		p.global_position = ring_centre + Vector3(cos(a), 0.0, sin(a)) * ring_radius
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	main.player.global_position = ring_centre + Vector3(0.5, 0.0, 1.5)
	main.night.elapsed = Config.NIGHT_LENGTH * 0.5
	for i: int in range(settle_frames):
		main._process(1.0 / 60.0)
	# The rules open every stretch of a loop at once (spacing over BORDER_MAX_GAP), so one gap on a healthy loop does not
	# happen by itself. For the shots two stretches are marked as gaps by hand: the nearer one to the player's side and
	# the one opposite (off screen, to test the arrow).
	var slots := main.border.segment_gap.size()
	var south := 0
	for k: int in range(slots):
		var here := main.border._point_at_arc((float(k) + 0.5) * main.border.spacing)
		var best := main.border._point_at_arc((float(south) + 0.5) * main.border.spacing)
		if here.y > best.y:
			south = k
	_force_gap(south)
	_force_gap((south + slots / 2) % slots)
	# A dark person pressing the first gap, and a couple more outside the loop.
	var gaps := main.border.gap_midpoints()
	print("GAPS ", gaps)
	var out_dir_v := Vector3(1.0, 0.0, 0.0)
	var centre := main.border.centre
	if gaps.size() > 0:
		gap_spot = gaps[0]
		out_dir_v = (gap_spot - centre).normalized()
		var side := Vector3(-out_dir_v.z, 0.0, out_dir_v.x)
		_make_dark(people[first_grey + 4], gap_spot + out_dir_v * 1.0)
		_make_dark(people[first_grey + 5], gap_spot + out_dir_v * 3.2 + side * 2.2)
		_make_dark(people[first_grey + 6], gap_spot + out_dir_v * 4.4 - side * 2.0)
		main.player.global_position = gap_spot - out_dir_v * 3.0
	# The floating joy numbers of the rescues would still be mid-air (their tweens run in real time): remove them.
	for child: Node in main.get_children():
		if child is Label3D:
			child.queue_free()
	# Freeze the rules at the peak of the gap pulse, with the light of mid-night.
	main.running = false
	main.border._time = Config.BORDER_GAP_PULSE_SECONDS * 0.5
	main.border._draw_lines()
	main._update_light()


# Marks slot stretch `k` of the border as a gap (a scripted state, see _build_scenario) and redraws the border.
func _force_gap(k: int) -> void:
	var b := main.border
	b.segment_gap[k] = true
	for j: int in range(b.polygon.size()):
		if mini(b.segment_gap.size() - 1, floori(b._arc[j] / b.spacing)) == k:
			b._sample_gap[j] = true
	b._draw_lines()


func _make_dark(p: Person, at: Vector3) -> void:
	p.global_position = Vector3(at.x, 0.0, at.z)
	p.gloom = 0.95
	p.level = 2
	p._update_visuals()


func _print_stats() -> void:
	var b := main.border
	print("STATS members=", b.member_count, " gaps=", b.gap_count(), " rescued=", main.rescued_count)
	print("STATS segment_gap=", b.segment_gap, " spacing=", b.spacing, " perimeter=", b.perimeter, " posts=", b.post_count)
	print("STATS beautified buildings=", b.beautified_building_count(), " landmark=", b.landmark_beautified())
	print("STATS landmark hold=", main.landmark.progress(), " gap_spot=", gap_spot, " player=", main.player.global_position)
	for g: Vector3 in b.gap_midpoints():
		print("STATS gap at ", g, " on screen ", main.world_to_screen(g))
	print("STATS landmark on screen ", main.world_to_screen(Config.BORDER_LANDMARK_POS))
	print("STATS plaza centre ", b.centre)


# ---- The shots ---------------------------------------------------------------------------------------------------


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var shots: Dictionary = {}
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		if Looks.mode != mode:
			main.set_look(mode)
		var label := Looks.mode_name().to_lower()
		await _settle(12)
		var frame_ms := await _time_frames(90)
		timings[label] = frame_ms
		var full := await _grab()
		shots[label] = full
		full.save_png(ProjectSettings.globalize_path("%s/overview_%s.png" % [out_dir, label]))
		var close := _closeup(full)
		close.save_png(ProjectSettings.globalize_path("%s/gap_closeup_%s.png" % [out_dir, label]))
		shots[label + "_close"] = close
		print("TIMING ", label, " ", snappedf(frame_ms, 0.01), " ms/frame, fallback=", Looks.placeholder_fallback_count())
	var styled: Image = shots["styled"]
	styled.save_png(ProjectSettings.globalize_path("%s/overview.png" % out_dir))
	var styled_close: Image = shots["styled_close"]
	styled_close.save_png(ProjectSettings.globalize_path("%s/gap_closeup.png" % out_dir))
	var compare := Image.create(2560, 720, false, Image.FORMAT_RGBA8)
	var left: Image = shots["placeholder"]
	compare.blit_rect(left, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	compare.blit_rect(styled, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
	compare.save_png(ProjectSettings.globalize_path("%s/compare.png" % out_dir))
	var f := FileAccess.open(ProjectSettings.globalize_path("%s/timings.txt" % out_dir), FileAccess.WRITE)
	f.store_string(JSON.stringify(timings))
	f.close()
	print("SAVED ", out_dir)


func _settle(frames: int) -> void:
	for i: int in range(frames):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	await _settle(2)
	var img := get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	return img


# Average milliseconds per frame over `frames` frames (vsync is off, so this is the real cost).
func _time_frames(frames: int) -> float:
	var t0 := Time.get_ticks_usec()
	for i: int in range(frames):
		await get_tree().process_frame
	return float(Time.get_ticks_usec() - t0) / 1000.0 / float(frames)


# A 3x nearest-neighbour zoom of the part of the screen round the gap.
func _closeup(full: Image) -> Image:
	var sp := main.world_to_screen(Vector3(gap_spot.x, 1.0, gap_spot.z))
	var w := 426
	var h := 240
	var x := clampi(int(sp.x) - w / 2, 0, 1280 - w)
	var y := clampi(int(sp.y) - h / 2, 0, 720 - h)
	var crop := full.get_region(Rect2i(x, y, w, h))
	crop.resize(w * 3, h * 3, Image.INTERPOLATE_NEAREST)
	return crop
