extends Node

# Renders the graphics checkpoint screenshots of the GAME (not design/style_test). Run by tools/checkpoint_shots.py:
#   Godot --path . res://tools/checkpoint/checkpoint_shots.tscn -- --out <dir> [--stats-only]
# It loads the real level, builds a fixed scenario through the game's own API (a seeded level; rescue a few people, form
# a border with a gap, a dimmed person pressing it, a beautified building, mid-night), freezes the rules, then takes the
# same shots in the placeholder look and, after flipping the look in place (F4), in the styled look. It also times the
# frames of each look. (Graphics checkpoint 2 adds the round 12b-17 cues to the scenario, several views and zoom levels,
# a second scenario for the sealed map edge, and a contact sheet.) The window is titled so nobody mistakes it for the game, never captures the mouse, and the
# process quits by itself.

const TITLE := "PositiveFPS — RENDERING CHECKPOINT SCREENSHOTS (closes automatically)"
const HARD_TIMEOUT := 170.0  # seconds before the run quits by itself (`--timeout` changes it)
const FAR := Vector3(31.0, 0.0, 31.0)
# The ring of rescued people: centre, radius and how many. With these numbers the border has one gap (see stats).

var out_dir: String = "res://design/renders/checkpoint_02"
var stats_only: bool = false
var hard_timeout: float = HARD_TIMEOUT
var scenario_set: String = "checkpoint2"
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
		if args[i] == "--timeout" and i + 1 < args.size():
			hard_timeout = float(args[i + 1])
		if args[i] == "--stats-only":
			stats_only = true
		if args[i] == "--set" and i + 1 < args.size():
			scenario_set = args[i + 1]
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
	get_tree().create_timer(hard_timeout).timeout.connect(_quit)
	DisplayServer.window_set_title(TITLE)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	DisplayServer.window_set_title(TITLE)
	await get_tree().process_frame
	if scenario_set == "round19":
		await _run_round19()
		_quit()
		return
	if scenario_set == "round20":
		await call("_run_round20")  # defined by checkpoint_round20.gd, which extends this script
		_quit()
		return
	if scenario_set == "round24":
		await call("_run_round24")  # defined by checkpoint_round24.gd, which extends checkpoint_round20.gd
		_quit()
		return
	if scenario_set == "checkpoint7":
		await call("_run_checkpoint7")  # defined by checkpoint_checkpoint7.gd, which extends checkpoint_round20.gd
		_quit()
		return
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
	main.night.elapsed = NightConfig.NIGHT_LENGTH * 0.5
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
	# A dimmed person pressing the first gap, and a couple more outside the loop.
	var gaps := main.border.gap_midpoints()
	print("GAPS ", gaps)
	var out_dir_v := Vector3(1.0, 0.0, 0.0)
	var centre := main.border.centre
	if gaps.size() > 0:
		gap_spot = gaps[0]
		out_dir_v = (gap_spot - centre).normalized()
		var side := Vector3(-out_dir_v.z, 0.0, out_dir_v.x)
		_make_dimmed(people[first_grey + 4], gap_spot + out_dir_v * 1.0)
		_make_dimmed(people[first_grey + 5], gap_spot + out_dir_v * 3.2 + side * 2.2)
		_make_dimmed(people[first_grey + 6], gap_spot + out_dir_v * 4.4 - side * 2.0)
		main.player.global_position = gap_spot - out_dir_v * 3.0
	_add_cues(first_grey)
	# The floating joy numbers of the rescues would still be mid-air (their tweens run in real time): remove them.
	for child: Node in main.get_children():
		if child is Label3D:
			child.queue_free()
	# Freeze the rules at the peak of the gap pulse, with the light of mid-night.
	main.running = false
	main.border._time = BorderConfig.BORDER_GAP_PULSE_SECONDS * 0.5
	main.border._draw_lines()
	main._update_light()
	for p: Person in people:
		p._update_visuals()


# Marks slot stretch `k` of the border as a gap (a scripted state, see _build_scenario) and redraws the border.
func _force_gap(k: int) -> void:
	var b := main.border
	b.segment_gap[k] = true
	for j: int in range(b.polygon.size()):
		if mini(b.segment_gap.size() - 1, floori(b._arc[j] / b.spacing)) == k:
			b._sample_gap[j] = true
	b._draw_lines()


func _make_dimmed(p: Person, at: Vector3) -> void:
	p.global_position = Vector3(at.x, 0.0, at.z)
	p.gloom = 0.95
	p.level = 2
	p._update_visuals()


# ---- Graphics checkpoint 2: the cues of rounds 12b-17 in the scenario -----------------------------------------------
# Everything is placed relative to the player (the camera centre), spread so nothing overlaps at the default zoom.

var spot_open := Vector3.ZERO
var spot_closed := Vector3.ZERO
var spot_shelter := Vector3.ZERO
var guarded_open: Person
var guarded_closed: Person
var shield_pair: Array[Person] = []
var worn_pair: Array[Person] = []
var dim_hit: Person
var falterer: Person


func _add_cues(first: int) -> void:
	var people := main.people
	var at := main.player.global_position
	for k: int in range(4):
		people[first + k].mood = Person.Mood.NONE
	# A guarded person facing the player (a shot would land: bright wedge) and one turned away (dim wedge).
	spot_open = at + Vector3(-9.5, 0.0, 3.5)
	spot_closed = at + Vector3(-5.0, 0.0, 8.0)
	guarded_open = people[first + 7]
	guarded_closed = people[first + 8]
	_stand(guarded_open, spot_open, Person.Mood.GUARDED, at - spot_open)
	_stand(guarded_closed, spot_closed, Person.Mood.GUARDED, spot_closed - at)
	guarded_open.shooter_pos = at
	guarded_closed.shooter_pos = at
	# A skittish person and a glum one looking up.
	_stand(people[first + 9], at + Vector3(9.0, 0.0, 6.5), Person.Mood.SKITTISH, Vector3(1.0, 0.0, 1.0))
	_stand(people[first + 10], at + Vector3(4.5, 0.0, 8.5), Person.Mood.GLUM, Vector3(0.0, 0.0, -1.0))
	people[first + 10].glum_up = true
	# Two shields: a fresh one (a dimmed person and the wistful person they shelter) and one worn to the last hit.
	spot_shelter = at + Vector3(-13.5, 0.0, -1.0)
	shield_pair = _shelter(people[first + 11], people[first + 12], spot_shelter, 1)
	worn_pair = _shelter(people[first + 13], people[first + 14], at + Vector3(-12.0, 0.0, 7.5), MoodConfig.SHELTER_HITS - 1)
	# A faltering border member (the progress ring and the "!" badge) and a dimmed person hit by joy (their ring).
	falterer = main.border.members[3] if main.border.members.size() > 3 else null
	if falterer != null:
		falterer.joy = falterer.joy_needed() * 0.45
		main.border.faltering.append(falterer)
	dim_hit = people[first + 4]
	dim_hit.joy = dim_hit.joy_needed() * 0.4
	main.spirit_meter.set_values(72.0, false)


# Places `p` at `spot`, facing `dir`, with `mood`.
func _stand(p: Person, spot: Vector3, mood: int, dir: Vector3) -> void:
	p.global_position = Vector3(spot.x, 0.0, spot.z)
	p.gloom = 0.45
	p.joy = 0.0
	p.level = 1
	p.mood = mood
	p.mood_unlocked = true
	p.rotation.y = atan2(-dir.x, -dir.z)
	p._update_visuals()


# A dimmed person at `spot` sheltering a wistful person beside them, the shield worn by `hits`. Returns [dimmed, ward].
func _shelter(dimmed: Person, ward: Person, spot: Vector3, hits: int) -> Array[Person]:
	_make_dimmed(dimmed, spot)
	_stand(ward, spot + Vector3(1.4, 0.0, 0.5), Person.Mood.NONE, Vector3(-1.0, 0.0, 0.0))
	dimmed.shelter_ward = ward
	ward.shielder = dimmed
	ward.sheltered = true
	dimmed.shield_hits = hits
	return [dimmed, ward]


# The short-lived effects (a prompt, a blocked spark, a dim ring, the spirit moment) are real-time timers, so they are
# lit again just before each shot.
func _refresh_effects() -> void:
	main.intro.enabled = true
	main.intro.current = Intro.Prompt.GUARDED
	main.intro.time_left = 2.0
	main.intro.anchor = Vector3.INF
	main.feedback.on_blocked(shield_pair[1], Person.Block.SHELTERED)
	main.feedback.on_blocked(guarded_closed, Person.Block.GUARDED)
	main.feedback.on_dim_joy(dim_hit)
	main.spirit_meter.moment(SpiritConfig.SPIRIT_PER_RESCUE, SpiritMeter.Moment.GAIN)
	main.spirit_meter.moment(-SpiritConfig.BURST_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	main.feedback.pulse_player(SpiritMeter.Moment.GAIN)


# ---- The edge scenario: a loop pressed against the east edge of the map, so a stretch of it is sealed by the map -------


func _build_edge_scenario() -> void:
	var people := main.people
	for p: Person in people:
		p.global_position = FAR
		p.gloom = 0.45
		p.mood = Person.Mood.NONE
	var centre := Vector3(32.0, 0.0, -6.0)
	for i: int in range(20):
		var a := TAU * float(i) / 20.0 + 0.3
		var p := people[i]
		p.gloom = 0.0
		p.global_position = centre + Vector3(cos(a), 0.0, sin(a)) * 7.0
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	main.player.global_position = Vector3(42.0, 0.0, -2.0)
	main.night.elapsed = NightConfig.NIGHT_LENGTH * 0.5
	for i: int in range(300):
		main._process(1.0 / 60.0)
	# Press the loop toward the east edge (the joy burst's shove), then let it settle.
	for k: int in range(14):
		main.border._push_at(0.0, RoundLoopConfig.BORDER_SHOVE_AMOUNT / maxf(main.border._scale, 0.01))
		for i: int in range(90):
			main._process(1.0 / 60.0)
	for i: int in range(600):
		main._process(1.0 / 60.0)
	var sealed := 0
	for j: int in range(main.border.polygon.size()):
		if main.border.is_sealed(j):
			sealed += 1
	print("SEALED segments=", sealed, " of ", main.border.polygon.size(), " members=", main.border.member_count)
	main.running = false
	main.border._time = BorderConfig.BORDER_GAP_PULSE_SECONDS * 0.5
	for p: Person in people:
		p._update_visuals()
	main._update_light()


func _print_stats() -> void:
	var b := main.border
	print("STATS members=", b.member_count, " gaps=", b.gap_count(), " rescued=", main.rescued_count)
	print("STATS segment_gap=", b.segment_gap, " spacing=", b.spacing, " perimeter=", b.perimeter, " posts=", b.post_count)
	print("STATS beautified buildings=", b.beautified_building_count(), " landmark=", b.landmark_beautified())
	print("STATS landmark hold=", main.landmarks.items[0].progress(), " gap_spot=", gap_spot, " player=", main.player.global_position)
	for g: Vector3 in b.gap_midpoints():
		print("STATS gap at ", g, " on screen ", main.world_to_screen(g))
	print("STATS landmark on screen ", main.world_to_screen(LandmarkConfig.LANDMARK_POSITIONS[0]))
	print("STATS plaza centre ", b.centre)


# ---- The shots ---------------------------------------------------------------------------------------------------

# The views of the main scenario, in the order they are taken. "world" or "rect" says where to cut a close-up from the
# 1280x720 window (a world point to centre on, or window pixels) and "scale" how much to enlarge it (nearest).
var views: Array[Dictionary] = []
# Every image taken: shots[view_name][look_name] = Image.
var shots: Dictionary = {}
var current_zoom: float = PlayerConfig.TD_CAMERA_ORTHO_SIZE


func _make_views() -> void:
	views = [
		{"name": "overview"},
		{"name": "gap_closeup", "world": gap_spot, "size": Vector2i(426, 240), "scale": 3},
		{"name": "wedge_closeup", "world": (spot_open + spot_closed) * 0.5, "size": Vector2i(426, 240), "scale": 3},
		{"name": "shield_closeup", "world": spot_shelter + Vector3(0.0, 0.0, 4.0), "size": Vector2i(426, 240), "scale": 3},
		{"name": "ui_closeup", "rect": Rect2i(300, 500, 680, 220), "scale": 2},
		{"name": "minimap_closeup", "rect": Rect2i(10, 10, 270, 270), "scale": 3},
		{"name": "zoom_min", "zoom": PlayerConfig.TD_ZOOM_MIN},
		{"name": "zoom_max", "zoom": PlayerConfig.TD_ZOOM_MAX},
	]


func _take_shots() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_make_views()
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		if Looks.mode != mode:
			main.set_look(mode)
		var label := Looks.mode_name().to_lower()
		await _set_zoom(PlayerConfig.TD_CAMERA_ORTHO_SIZE)
		await _settle(12)
		var frame_ms := await _time_frames(90)
		timings[label] = frame_ms
		main.feedback.visible = false
		main.spirit_meter.visible = false
		main.prompts.visible = false
		main.arrows.visible = false
		timings[label + "_no_overlays"] = await _time_frames(90)
		main.feedback.visible = true
		main.spirit_meter.visible = true
		main.prompts.visible = true
		main.arrows.visible = true
		for view: Dictionary in views:
			var view_name: String = view["name"]
			var zoom: float = view.get("zoom", PlayerConfig.TD_CAMERA_ORTHO_SIZE)
			await _set_zoom(zoom)
			_refresh_effects()
			var full := await _grab()
			_save(view_name, label, _cut(full, view))
		print("TIMING ", label, " ", snappedf(frame_ms, 0.01), " ms/frame, fallback=", Looks.placeholder_fallback_count())
	# The sealed map edge: a second level with its loop pressed against the east edge.
	await _set_zoom(PlayerConfig.TD_CAMERA_ORTHO_SIZE)
	main.queue_free()
	await get_tree().process_frame
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	_build_edge_scenario()
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		if Looks.mode != mode:
			main.set_look(mode)
		var label := Looks.mode_name().to_lower()
		await _settle(12)
		var full := await _grab()
		_save("sealed_edge", label, full)
		_save("sealed_minimap", label, _cut(full, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}))
	_write_sheets()
	var f := FileAccess.open(ProjectSettings.globalize_path("%s/timings.txt" % out_dir), FileAccess.WRITE)
	f.store_string(JSON.stringify(timings))
	f.close()
	print("SAVED ", out_dir)


# Eases the camera to the ortho size `size` (the mouse wheel's target) and waits for it to arrive.
func _set_zoom(size: float) -> void:
	if is_equal_approx(current_zoom, size):
		return
	current_zoom = size
	main._zoom_target = size
	await _settle(100)


func _save(view_name: String, label: String, img: Image) -> void:
	if not shots.has(view_name):
		shots[view_name] = {}
	var by_look: Dictionary = shots[view_name]
	by_look[label] = img
	img.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [out_dir, view_name, label]))


# The close-up `view` describes (or the whole window).
func _cut(full: Image, view: Dictionary) -> Image:
	var scale_by: int = view.get("scale", 1)
	var rect := Rect2i(0, 0, 1280, 720)
	if view.has("world"):
		var w: Vector3 = view["world"]
		var size: Vector2i = view["size"]
		var sp := main.world_to_screen(Vector3(w.x, maxf(w.y, 1.0), w.z))
		var x := clampi(int(sp.x) - size.x / 2, 0, 1280 - size.x)
		var y := clampi(int(sp.y) - size.y / 2, 0, 720 - size.y)
		rect = Rect2i(x, y, size.x, size.y)
	elif view.has("rect"):
		rect = view["rect"]
	var crop := full.get_region(rect)
	if scale_by > 1:
		crop.resize(rect.size.x * scale_by, rect.size.y * scale_by, Image.INTERPOLATE_NEAREST)
	return crop


# contact_sheet.png: the styled views in a grid; contact_sheet_compare.png: placeholder and styled side by side.
func _write_sheets() -> void:
	var names: Array[String] = []
	for key: String in shots.keys():
		names.append(key)
	var cols := 3
	var cell := Vector2i(640, 360)
	var rows := ceili(float(names.size()) / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(names.size()):
		var by_look: Dictionary = shots[names[i]]
		var styled_img: Image = by_look["styled"]
		_fit(styled_img, sheet, Vector2i((i % cols) * cell.x, (i / cols) * cell.y), cell)
	sheet.save_png(ProjectSettings.globalize_path("%s/contact_sheet.png" % out_dir))
	var pair_names: Array[String] = ["overview", "wedge_closeup", "shield_closeup", "ui_closeup", "sealed_edge", "zoom_max"]
	var compare := Image.create(cell.x * 2, cell.y * pair_names.size(), false, Image.FORMAT_RGBA8)
	compare.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(pair_names.size()):
		var by_look: Dictionary = shots[pair_names[i]]
		var plain_img: Image = by_look["placeholder"]
		var styled_img: Image = by_look["styled"]
		_fit(plain_img, compare, Vector2i(0, i * cell.y), cell)
		_fit(styled_img, compare, Vector2i(cell.x, i * cell.y), cell)
	compare.save_png(ProjectSettings.globalize_path("%s/contact_sheet_compare.png" % out_dir))
	var both := Image.create(2560, 720, false, Image.FORMAT_RGBA8)
	var over: Dictionary = shots["overview"]
	var left: Image = over["placeholder"]
	var right: Image = over["styled"]
	both.blit_rect(left, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	both.blit_rect(right, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
	both.save_png(ProjectSettings.globalize_path("%s/compare.png" % out_dir))
	right.save_png(ProjectSettings.globalize_path("%s/overview.png" % out_dir))


# Scales `src` to fit the cell (keeping its shape) and puts it at `at` on `dst`.
func _fit(src: Image, dst: Image, at: Vector2i, cell: Vector2i) -> void:
	var img := src.duplicate() as Image
	var k := minf(float(cell.x) / float(img.get_width()), float(cell.y) / float(img.get_height()))
	img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	dst.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), at)


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


# ---- Graphics checkpoint 3: the round 19 scenario (spirit beacon, three landmarks, dawn rating screen) -------------------
# `--set round19`. A ring of rescued people forms the border; a beacon stands east of its centre with the pull line to
# it; the three landmarks are put in each state through their own API (unheld, claiming, held); the end screens are shown
# through the HUD with ratings made by DawnRating. The rules are frozen (running = false), so the states are scripted.

const R19_NAMES: Array[String] = ["bandstand", "garden", "bell"]
const R19_SHEET_PAIRS: Array[String] = [
	"overview",
	"beacon_closeup",
	"bandstand_held",
	"garden_held",
	"bell_held",
	"landmark_hud",
	"minimap_beacon",
	"dawn_3",
	"dawn_1"
]

var r19_beacon := Vector3.ZERO
var r19_views: Array[Dictionary] = []


func _run_round19() -> void:
	_build_round19_scenario()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	_make_round19_views()
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		if Looks.mode != mode:
			main.set_look(mode)
		var label := Looks.mode_name().to_lower()
		await _settle(12)
		for view: Dictionary in r19_views:
			var view_name: String = view["name"]
			var prep: String = view["prep"]
			var arg: int = view.get("arg", -1)
			_r19_prepare(prep, arg)
			await _settle(14)
			_r19_prepare(prep, arg)
			var full := await _grab()
			_save(view_name, label, _cut(full, view))
		print("TIMING ", label, " fallback=", Looks.placeholder_fallback_count())
	_write_sheets_round19()
	print("SAVED ", out_dir)


func _build_round19_scenario() -> void:
	var people := main.people
	for p: Person in people:
		p.global_position = FAR
		p.gloom = 0.45
		p.mood = Person.Mood.NONE
	for i: int in range(ring_count):
		var a := TAU * float(i) / float(ring_count) + 0.3
		var p := people[i]
		p.gloom = 0.0
		p.global_position = ring_centre + Vector3(cos(a), 0.0, sin(a)) * ring_radius
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	main.player.global_position = ring_centre + Vector3(0.5, 0.0, 1.5)
	main.night.elapsed = NightConfig.NIGHT_LENGTH * 0.25
	for i: int in range(settle_frames):
		main._process(1.0 / 60.0)
	main.running = false
	main.player.spirit = 80.0
	main.border.place_beacon(main.border.centre + Vector3(14.0, 0.0, 5.0))
	r19_beacon = main.border.beacon_pos()
	# Two wistful people beside each landmark, for scale.
	for k: int in range(R19_NAMES.size()):
		for j: int in range(2):
			var p := people[ring_count + k * 2 + j]
			p.global_position = LandmarkConfig.LANDMARK_POSITIONS[k] + Vector3(float(j * 2 - 1) * 3.4, 0.0, 3.8)
			p.gloom = 0.25
			p.joy = 0.0
	for child: Node in main.get_children():
		if child is Label3D:
			child.queue_free()
	main.border._time = BorderConfig.BORDER_GAP_PULSE_SECONDS * 0.5
	main.border._draw_lines()
	main._update_light()
	for p: Person in people:
		p._update_visuals()


func _make_round19_views() -> void:
	var mid_beacon := main.border.centre.lerp(r19_beacon, 0.5)
	r19_views = [
		{"name": "overview", "prep": "overview"},
		{"name": "beacon_closeup", "prep": "beacon", "world": mid_beacon, "size": Vector2i(640, 360), "scale": 2},
	]
	for k: int in range(R19_NAMES.size()):
		var at: Vector3 = LandmarkConfig.LANDMARK_POSITIONS[k]
		var mid := Vector3(at.x, LandmarkConfig.LANDMARK_SIZES[k].y * 0.8, at.z)
		for state: String in ["unheld", "claiming", "held"]:
			r19_views.append(
				{
					"name": "%s_%s" % [R19_NAMES[k], state],
					"prep": "landmark_" + state,
					"arg": k,
					"world": mid,
					"size": Vector2i(480, 300),
					"scale": 2
				}
			)
	r19_views.append({"name": "landmark_hud", "prep": "hud", "rect": Rect2i(980, 70, 300, 200), "scale": 3})
	r19_views.append({"name": "minimap_beacon", "prep": "hud", "rect": Rect2i(10, 10, 270, 270), "scale": 3})
	r19_views.append({"name": "dawn_3", "prep": "dawn", "arg": 3})
	r19_views.append({"name": "dawn_2", "prep": "dawn", "arg": 2})
	r19_views.append({"name": "dawn_1", "prep": "dawn", "arg": 1})
	r19_views.append({"name": "dawn_lost", "prep": "dawn", "arg": 0})


# Puts the scenario in the state a view needs. Called twice per view (before and after the settle frames).
func _r19_prepare(prep: String, arg: int) -> void:
	main.hud.end_panel.visible = false
	var held: Array[bool] = [false, false, false]
	var claiming := -1
	var show_beacon := false
	var focus := ring_centre + Vector3(0.5, 0.0, 1.5)
	if prep == "overview":
		held = [true, false, false]
		show_beacon = true
		focus = main.border.centre.lerp(r19_beacon, 0.4)
	elif prep == "beacon":
		show_beacon = true
		focus = main.border.centre.lerp(r19_beacon, 0.5)
	elif prep == "hud":
		held = [true, false, true]
		show_beacon = true
	elif prep == "dawn":
		held = [true, true, arg >= 3]
	elif prep.begins_with("landmark_"):
		var at: Vector3 = LandmarkConfig.LANDMARK_POSITIONS[arg]
		focus = at + Vector3(7.0, 0.0, -1.0)
		if prep == "landmark_held":
			held[arg] = true
		elif prep == "landmark_claiming":
			claiming = arg
	main.player.global_position = Vector3(focus.x, 0.0, focus.z)
	_r19_landmark_states(held, claiming)
	main.beacon_marker.sync(main.border.beacon_pos() if show_beacon else Vector3.INF, 0.3, main.border.centre)
	if prep == "dawn":
		_r19_show_end(arg)


func _r19_landmark_states(held: Array[bool], claiming: int) -> void:
	for i: int in range(held.size()):
		var lm := main.landmarks.items[i]
		if held[i]:
			lm.hold = LandmarkConfig.BORDER_LANDMARK_HOLD
			lm.update(0.0, true)
		elif i == claiming:
			lm.hold = LandmarkConfig.BORDER_LANDMARK_HOLD * 0.5
			lm.update(0.0, true)
		else:
			lm.hold = 0.0
			lm.update(0.0, false)
	main.hud.set_landmarks(main.landmarks.held_lines(), LandmarkConfig.LANDMARK_NAMES.size(), main.landmarks.held_flags())


# The end screen for `lights` dawn lights (0 for a lost round).
func _r19_show_end(lights: int) -> void:
	if lights == 0:
		main.rating = {}
		main.hud.show_end("The border fell", main._detail_text(), {})
		return
	var r: Dictionary = {}
	if lights == 3:
		r = DawnRating.rate(42, Config.TD_PEOPLE_COUNT, 0.46, 3)
	elif lights == 2:
		r = DawnRating.rate(31, Config.TD_PEOPLE_COUNT, 0.32, 1)
	else:
		r = DawnRating.rate(14, Config.TD_PEOPLE_COUNT, 0.1, 0)
	main.rating = r
	main.hud.show_end("Dawn: %d of 3 dawn lights" % (r["lights"] as int), main._detail_text(), r)


# contact_sheet.png (styled), contact_sheet_compare.png (placeholder | styled), compare.png (the overview pair) and
# landmarks_sheet.png (the three landmarks by state, styled).
func _write_sheets_round19() -> void:
	var names: Array[String] = []
	for view: Dictionary in r19_views:
		names.append(view["name"])
	var cols := 3
	var cell := Vector2i(640, 360)
	var rows := ceili(float(names.size()) / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(names.size()):
		var by_look: Dictionary = shots[names[i]]
		_fit(by_look["styled"] as Image, sheet, Vector2i((i % cols) * cell.x, (i / cols) * cell.y), cell)
	sheet.save_png(ProjectSettings.globalize_path("%s/contact_sheet.png" % out_dir))
	var compare := Image.create(cell.x * 2, cell.y * R19_SHEET_PAIRS.size(), false, Image.FORMAT_RGBA8)
	compare.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(R19_SHEET_PAIRS.size()):
		var by_look: Dictionary = shots[R19_SHEET_PAIRS[i]]
		_fit(by_look["placeholder"] as Image, compare, Vector2i(0, i * cell.y), cell)
		_fit(by_look["styled"] as Image, compare, Vector2i(cell.x, i * cell.y), cell)
	compare.save_png(ProjectSettings.globalize_path("%s/contact_sheet_compare.png" % out_dir))
	var landmarks_cell := Vector2i(640, 400)
	var lm_sheet := Image.create(landmarks_cell.x * 3, landmarks_cell.y * 3, false, Image.FORMAT_RGBA8)
	lm_sheet.fill(Color(0.1, 0.09, 0.12))
	var states: Array[String] = ["unheld", "claiming", "held"]
	for k: int in range(R19_NAMES.size()):
		for j: int in range(states.size()):
			var by_look: Dictionary = shots["%s_%s" % [R19_NAMES[k], states[j]]]
			_fit(by_look["styled"] as Image, lm_sheet, Vector2i(k * landmarks_cell.x, j * landmarks_cell.y), landmarks_cell)
	lm_sheet.save_png(ProjectSettings.globalize_path("%s/landmarks_sheet.png" % out_dir))
	var both := Image.create(2560, 720, false, Image.FORMAT_RGBA8)
	var over: Dictionary = shots["overview"]
	var left: Image = over["placeholder"]
	var right: Image = over["styled"]
	both.blit_rect(left, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	both.blit_rect(right, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
	both.save_png(ProjectSettings.globalize_path("%s/compare.png" % out_dir))
	right.save_png(ProjectSettings.globalize_path("%s/overview.png" % out_dir))
