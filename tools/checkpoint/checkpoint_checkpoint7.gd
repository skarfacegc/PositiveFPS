extends "res://tools/checkpoint/checkpoint_round20.gd"

# Graphics checkpoint 7 (`--set checkpoint7`, run by tools/checkpoint_shots.py): the look after checkpoint 7 in both looks.
# Calm opening (the first frames of a game, no ring yet), mid-night inside the zone and outside it (the living ground,
# the street props, the ambient life and the gloom mist), a push in progress (the pushers' lean and the fog at the pushed
# stretch) and dawn (the sky warming, the first-light front). For each look it builds fresh levels, so the states run in
# order. The rules are frozen (running = false) except for the short run that makes a push visible.
# This script extends checkpoint_round20.gd and carries its own copies of the few round 24 helpers it needs: the round 24
# script references a removed gap patch, so it does not load.

const C7_SHEET_CELL := Vector2i(640, 360)
# 0.3.1: the play-zoom views (full frame at the default zoom, the one the game is played at) have this prefix.
const C7_PLAY_NAMES: Array[String] = [
	"play_calm_opening",
	"play_midnight_inside_zone",
	"play_midnight_outside_zone",
	"play_push_in_progress",
	"play_props_bunting"
]
# The props view: a ring round two neighbouring blocks (BLOCK_POSITIONS 2 and 3, 18 m apart: bunting runs between them).
const C7_PROPS_BLOCKS: Array[int] = [2, 3]
const C7_PROPS_RING_RADIUS := 10.5
const C7_PROPS_RING_COUNT := 24

var play_only: bool = false  # `--play-only`: the styled look and the four play-zoom views only (for tuning rounds).


func _run_checkpoint7() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	play_only = "--play-only" in OS.get_cmdline_user_args()
	var modes: Array[int] = [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]
	if play_only:
		modes = [Looks.Mode.STYLED]
	for mode: int in modes:
		Looks.set_mode(mode)
		var label := Looks.mode_name().to_lower()
		await _c7_opening(label, "play_" if play_only else "")
		await _c7_midnight(label, "play_" if play_only else "")
		await _c7_push(label, "play_" if play_only else "")
		if play_only:
			await _c7_props(label)
		else:
			await _c7_opening(label, "play_")
			await _c7_midnight(label, "play_")
			await _c7_push(label, "play_")
			await _c7_props(label)
			await _c7_dawn(label)
		print("TIMING ", label, " fallback=", Looks.placeholder_fallback_count(), " ", Looks.fallback_summary())
	_write_play_sheet()
	if not play_only:
		_write_sheets_checkpoint7()
	print("SAVED ", out_dir)


# ---- Helpers (copies of the round 24 ones, see the note above) ---------------------------------------------------------


# A fresh level with the ring, the border redrawn from its settled state, the player not aiming.
func _c7_level() -> void:
	await _r20_new_level()
	main.player._has_aim = false
	main.border._draw_lines()
	await _settle(8)
	main.border._draw_lines()
	await _settle(8)


# The border's members in order of their angle round the centre (neighbours in the list are neighbours on the loop).
func _c7_ring_members() -> Array[Person]:
	var out: Array[Person] = []
	out.assign(main.border.members)
	var c := main.border.centre
	out.sort_custom(
		func(a: Person, b: Person) -> bool:
			return atan2(a.position.z - c.z, a.position.x - c.x) < atan2(b.position.z - c.z, b.position.x - c.x)
	)
	return out


# Saves the current frame (cut to `view`) as `view_name` in this look.
func _c7_shot(view_name: String, label: String, view: Dictionary = {}, frames: int = 8) -> void:
	_r20_hide_alert()
	await _settle(frames)
	var full := await _grab()
	_r20_note(view_name)
	_save(view_name, label, _cut(full, view))


func _c7_move_player(at: Vector3, frames: int = 40) -> void:
	main.player.global_position = Vector3(at.x, 0.0, at.z)
	await _settle(frames)


# Sets the night clock to `progress` (0 = dusk, 0.5 = mid-night) and redraws the light.
func _c7_night(progress: float) -> void:
	main.night.elapsed = Config.NIGHT_LENGTH * progress
	main._update_light()
	main.hud.set_night_progress(main.night.progress())


# The first-light front at `progress` (0..1) of the last FIRST_LIGHT_SECONDS of the night.
func _c7_front(progress: float) -> void:
	main.night.elapsed = Config.NIGHT_LENGTH - Config.FIRST_LIGHT_SECONDS * (1.0 - progress)
	main._update_light()
	main.hud.set_night_progress(main.night.progress())
	main.first_light.step(0.0)
	main.minimap.refresh_clouds(main.people)


# ---- The views ---------------------------------------------------------------------------------------------------------


# The calm opening: a fresh level as the game starts (no ring, the intro and the first light of the night).
func _c7_opening(label: String, prefix: String = "") -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.running = false
	main.night.elapsed = 0.0
	main._update_light()
	await _set_zoom(Config.TD_CAMERA_ORTHO_SIZE)
	await _c7_shot(prefix + "calm_opening", label, {}, 40)


# Mid-night inside the zone (the player on the ring's centre) and outside it (the player away from the ring).
func _c7_midnight(label: String, prefix: String = "") -> void:
	await _c7_level()
	_c7_night(0.5)
	await _set_zoom(Config.TD_CAMERA_ORTHO_SIZE)
	await _c7_move_player(main.border.centre + Vector3(0.0, 0.0, 1.5))
	await _c7_shot(prefix + "midnight_inside_zone", label, {}, 20)
	await _c7_move_player(Vector3(-8.0, 0.0, -4.0))
	await _c7_shot(prefix + "midnight_outside_zone", label, {}, 20)


# 0.3.1 (#41, #42): mid-night at play zoom with two beautified blocks in frame inside the zone: their lamps, benches,
# planters and stalls, and the bunting strung on posts between them. The ring is moved round the two blocks for this view
# only (the rules are frozen, so the two buildings are set to their beautified state here, as the rules would have done).
func _c7_props(label: String) -> void:
	var saved_centre := ring_centre
	var saved_radius := ring_radius
	var saved_count := ring_count
	var a: Vector3 = TopDownMain.BLOCK_POSITIONS[C7_PROPS_BLOCKS[0]]
	var b: Vector3 = TopDownMain.BLOCK_POSITIONS[C7_PROPS_BLOCKS[1]]
	ring_centre = Vector3((a.x + b.x) * 0.5, 0.0, (a.z + b.z) * 0.5 + 1.0)
	ring_radius = C7_PROPS_RING_RADIUS
	ring_count = C7_PROPS_RING_COUNT
	await _c7_level()
	_c7_night(0.5)
	await _set_zoom(Config.TD_CAMERA_ORTHO_SIZE)
	for k: int in C7_PROPS_BLOCKS:
		var at: Vector3 = TopDownMain.BLOCK_POSITIONS[k]
		for bd: Building in main.border.buildings:
			if bd.centre.distance_to(Vector2(at.x, at.z)) < 1.0:
				bd.inside_time = Config.BORDER_BUILDING_SECONDS
				bd.beautified = true
				bd.tint = 1.0
	await _c7_move_player(ring_centre + Vector3(0.0, 0.0, 2.0))
	for i: int in range(int(Config.C7_BLOOM_SECONDS / Config.C7_PROPS_INTERVAL) + 8):
		main.style_props.refresh(Config.C7_PROPS_INTERVAL)
	await _c7_shot("play_props_bunting", label, {}, 8)
	ring_centre = saved_centre
	ring_radius = saved_radius
	ring_count = saved_count


# A push in progress: two dimmed people lean on a stretch of the ring, the rules run a moment so the push builds. 0.3.1: a
# tide is forced to come from that side (tides are off in the shot run) and the rules keep running while the frame is
# taken, because the fog only shows while they run. The play-zoom view puts the player between the ring and the fog.
func _c7_push(label: String, prefix: String = "") -> void:
	await _c7_level()
	_c7_night(0.5)
	await _set_zoom(Config.TD_CAMERA_ORTHO_SIZE)
	var ring := _c7_ring_members()
	var centre := main.border.centre
	var out := (ring[10].position - centre).normalized()
	_make_dimmed(main.people[ring_count + 30], ring[10].position + out * 1.3)
	_make_dimmed(main.people[ring_count + 31], ring[10].position + out * 1.6 + Vector3(-out.z, 0.0, out.x) * 0.9)
	var player_at := centre + Vector3(0.0, 0.0, 1.5)
	if prefix != "":
		player_at = centre + out * 8.0
	await _c7_move_player(player_at)
	Config.tides_override = 1
	var tide := main.gloom_tide
	var angle := atan2(out.z, out.x)
	tide.tides[1]["angle"] = angle
	tide.tides[1]["side"] = GloomTide.side_name(angle)
	var tide_start: float = tide.tides[1]["start"]
	main.night.elapsed = tide_start + Config.TIDE_SECONDS * 0.5
	main.running = true
	tide.update(0.0)
	_r20_run(45)
	main.running = true
	tide.update(0.0)
	await _c7_shot(prefix + "push_in_progress", label, {}, 4)
	if prefix == "":
		await _c7_shot(
			"push_closeup", label, {"world": ring[10].position + out * 0.8, "size": Vector2i(426, 240), "scale": 3}, 2
		)
	main.running = false
	Config.tides_override = -1


# Dawn: the front has reached the middle of the map; the sky is warming and the ring sits in the light.
func _c7_dawn(label: String) -> void:
	await _c7_level()
	await _c7_move_player(Vector3(20.0, 0.0, 8.0))
	_c7_front(0.6)
	await _c7_shot("dawn", label, {}, 20)


# ---- Sheets ------------------------------------------------------------------------------------------------------------


# play_sheet.png: the four play-zoom views of the styled look in a 2 x 2 grid (one image to look at per tuning round).
func _write_play_sheet() -> void:
	var cell := Vector2i(800, 450)
	var sheet := Image.create(cell.x * 3, cell.y * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(C7_PLAY_NAMES.size()):
		if shots.has(C7_PLAY_NAMES[i]):
			var by_look: Dictionary = shots[C7_PLAY_NAMES[i]]
			_fit(by_look["styled"] as Image, sheet, Vector2i((i % 3) * cell.x, (i / 3) * cell.y), cell)
	sheet.save_png(ProjectSettings.globalize_path("%s/play_sheet.png" % out_dir))


# contact_sheet.png: the styled views in a grid; contact_sheet_compare.png: placeholder and styled side by side.
func _write_sheets_checkpoint7() -> void:
	var cell := C7_SHEET_CELL
	var names: Array[String] = r20_names.duplicate()
	var cols := 3
	var rows := ceili(float(names.size()) / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(names.size()):
		var by_look: Dictionary = shots[names[i]]
		_fit(by_look["styled"] as Image, sheet, Vector2i((i % cols) * cell.x, (i / cols) * cell.y), cell)
	sheet.save_png(ProjectSettings.globalize_path("%s/contact_sheet.png" % out_dir))
	var compare := Image.create(cell.x * 2, cell.y * names.size(), false, Image.FORMAT_RGBA8)
	compare.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(names.size()):
		var by_look: Dictionary = shots[names[i]]
		_fit(by_look["placeholder"] as Image, compare, Vector2i(0, i * cell.y), cell)
		_fit(by_look["styled"] as Image, compare, Vector2i(cell.x, i * cell.y), cell)
	compare.save_png(ProjectSettings.globalize_path("%s/contact_sheet_compare.png" % out_dir))
