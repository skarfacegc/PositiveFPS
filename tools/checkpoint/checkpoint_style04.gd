extends "res://tools/checkpoint/checkpoint_grid.gd"

# Walls and gates: Style update (#94, #74; `--set style04`, run by tools/checkpoint_shots.py): the styled look caught up
# with passes 2c and 3 and the Clean HUD, in both looks at play zoom: the calm HUD, the slim banner, the takeable cells
# and their tags, the take preview panel with the gate counts, a block taken and blooming, the gates with their lantern
# arches, planted defences, a lost cell cooling, the surge (the warning's pointer and radar mark, the storm front) and a
# break mending. The town coordinates are those of the pass 2c grid (an 18 m start square, 12 m cells and streets), read
# from TownGrid, not typed in. For each look it builds one fresh level and walks the states in order; the rules are
# frozen between states (running = false) except while a surge is shown (the fog needs the level running). The base
# script's dispatch calls _run_style04.

const S_EAST := Vector2i(3, 2)
const S_WEST := Vector2i(1, 2)
const S_NORTH := Vector2i(2, 1)

var s_labels: Array[String] = []


func _run_style04() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	Config.tides_override = 1
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		Looks.set_mode(mode)
		var label := Looks.mode_name().to_lower()
		await _g_new_level()
		await _set_zoom(PlayerConfig.TD_CAMERA_ORTHO_SIZE)
		await _s_hud(label)
		await _s_town(label)
		await _s_takeable(label)
		await _s_take(label)
		await _s_defences(label)
		await _s_lost(label)
		await _s_mend(label)
		await _s_surge(label)
		print("TIMING ", label, " fallback=", Looks.placeholder_fallback_count())
	Config.tides_override = -1
	_write_sheets_grid()
	print("SAVED ", out_dir)


# A shot that keeps the banner and the live effects (the plain _g_shot clears them first).
func _s_shot(view_name: String, label: String, view: Dictionary = {}, frames: int = 8, live: bool = false) -> void:
	main.running = live
	await _settle(frames)
	var full := await _grab()
	main.running = false
	if not g_names.has(view_name):
		g_names.append(view_name)
	_save(view_name, label, _cut(full, view))


func _s_close(cell: Vector2i, lift: float = 2.5) -> Dictionary:
	return {"world": TownGrid.cell_centre(cell) + Vector3(0.0, lift, 0.0), "size": Vector2i(426, 240), "scale": 3}


# The calm HUD: the people line, the burst line, the spirit meter, the controls strip (shown with H), then the one banner.
func _s_hud(label: String) -> void:
	await _g_move_player(Vector3.ZERO, 20)
	main.landmark_pointers.update_from(main)
	main.hud.show_controls(true)
	await _g_shot("hud_calm", label, {}, 20)
	main.hud.show_controls(false)
	main.intro.calm_notice(Intro.Prompt.SPIRIT_LOW, "Block taken (25 spirit): the line wants 20 people")
	main.running = true
	main._process(1.0 / 60.0)
	main._process(1.0 / 60.0)
	await _s_shot("banner", label, {"rect": Rect2i(240, 0, 800, 200), "scale": 1}, 10)
	main.intro.current = -1


# Unheld blocks (the cold industrial dressing) at play zoom and close.
func _s_town(label: String) -> void:
	await _g_move_player(Vector3(-15.0, 0.0, 0.0), 40)
	await _g_shot("town_unheld", label, {}, 20)
	await _g_shot("town_unheld_closeup", label, _s_close(S_WEST, 3.0), 4)


# Cells next to the zone are takeable: the east one is ready (all its pips, gold), the others cost spirit (blue).
func _s_takeable(label: String) -> void:
	main.border.pips.counts[S_EAST] = BorderConfig.TAKE_RESCUES
	main.border.pips.counts[S_NORTH] = 1
	main.border.pips.version += 1
	await _g_move_player(Vector3(11.0, 0.0, 3.0), 40)
	await _g_shot("takeable_cells", label, {}, 20)
	await _g_shot("cell_tags", label, _s_close(S_EAST, 3.0), 4)


# The preview panel and the gate counts while E is held on the east cell, then the take: the pulse, the bloom and the gates.
func _s_take(label: String) -> void:
	var at := TownGrid.cell_centre(S_EAST)
	main.take_block.holding = true
	main.player._aim_point = Vector3(at.x, 0.0, at.z)
	main.player._has_aim = true
	await _g_shot("take_preview", label, {}, 14)
	main.take_block.holding = false
	main.player._has_aim = false
	main.take_block.take_now(S_EAST)
	await _g_run(40)
	await _g_shot("taken_pulse", label, {}, 4)
	await _g_run(200)
	await _g_shot("bloom_mid", label, _s_close(S_EAST, 3.0), 4)
	await _g_run(160)
	await _g_move_player(Vector3(15.0, 0.0, 4.0), 40)
	await _g_shot("taken_block", label, {}, 20)
	var mouth := {"world": Vector3(15.0, 2.0, 9.0), "size": Vector2i(426, 240), "scale": 3}
	await _g_shot("gate_arch", label, mouth, 4)


# Defences planted on four gates, one of each type.
func _s_defences(label: String) -> void:
	for i: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
		if not main.landmarks.unlock_order.has(i):
			main.landmarks.unlock_order.append(i)
	var gates: Array[Dictionary] = main.border.zone.gates
	var planted := 0
	for g: int in range(gates.size()):
		if planted >= 4:
			break
		if main.defences.plant_now(g, planted):
			planted += 1
	await _g_run(120)
	if main.defences.posts.is_empty():
		return
	var first: int = main.defences.posts[0]["gate"]
	var spot := main.defences.post_position(first)
	await _g_move_player(spot + Vector3(0.0, 0.0, 0.0), 40)
	await _g_shot("defences", label, {}, 20)
	await _g_shot("defences_closeup", label, {"world": spot + Vector3(0.0, 1.5, 0.0), "size": Vector2i(426, 240), "scale": 3}, 4)


# The east block is lost: the cold pulse, then the block cooling again.
func _s_lost(label: String) -> void:
	await _g_move_player(Vector3(15.0, 0.0, 4.0), 30)
	main.border.zone.lose(S_EAST)
	main.events.on_cells_lost([S_EAST] as Array[Vector2i], 0)
	await _g_run(20)
	await _g_shot("lost_cell", label, {}, 3)
	await _g_run(100)
	await _g_shot("lost_cooling", label, _s_close(S_EAST, 3.0), 3)


# A break opens on a gate and a burst mends it: the line is open, then the ring closes on the spot.
func _s_mend(label: String) -> void:
	var gates: Array[Dictionary] = main.border.zone.gates
	var mid: Vector2 = gates[0]["mid"]
	var spot := Vector3(mid.x, 0.0, mid.y)
	await _g_move_player(spot + Vector3(0.0, 0.0, 0.0), 30)
	var i := main.border.nearest_point(mid)
	main.border.push._open_break(i)
	await _g_run(6)
	await _g_shot("break_open", label, {}, 8)
	main.border.push.relieve(spot)
	await _s_shot("break_mended", label, {}, 10)


# The surge: the warning (the edge pointer, the radar mark, the banner), then the storm front at the gate it meets.
func _s_surge(label: String) -> void:
	var tide := main.gloom_tide
	var start: float = tide.surge["start"]
	main.border.zone.take(S_EAST)
	await _g_move_player(Vector3.ZERO, 20)
	main.night.elapsed = start - NightConfig.SURGE_WARN_SECONDS + 4.0
	main.running = true
	for k: int in range(6):
		main._process(1.0 / 60.0)
	main.running = false
	await _s_shot("surge_warning", label, {}, 10, true)
	await _s_shot("surge_radar", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, 3, true)
	main.night.elapsed = start + NightConfig.SURGE_SECONDS * 0.3
	main.running = true
	for k: int in range(6):
		main._process(1.0 / 60.0)
	main.running = false
	var origin: Vector2 = tide.surge["origin"]
	var dir: Vector2 = tide.surge["dir"]
	var centre := origin + dir * (tide.front - NightConfig.TIDE_FOG_DEPTH * 0.5)
	var behind := Vector3(centre.x - dir.x * 7.0, 0.0, centre.y - dir.y * 7.0)
	await _g_move_player(behind, 40)
	main.night.elapsed = start + NightConfig.SURGE_SECONDS * 0.3
	await _s_shot("surge_front", label, {}, 10, true)
