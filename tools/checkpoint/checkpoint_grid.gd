extends "res://tools/checkpoint/checkpoint_shots.gd"

# 0.4 pass 2b (`--set grid`, run by tools/checkpoint_shots.py): the town grid in both looks at play zoom. The start
# square with its gates, two taken blocks (one beautified) with walls and gates, the minimap of that zone, the rescue
# pips of a cell, the take preview, and a gate under push. For each look it builds one fresh level and walks through the
# states in order; the rules are frozen between states (running = false). The base script's dispatch calls _run_grid.

const G_RESCUED := 22
const G_NAMES: Array[String] = [
	"start_square", "gate_closeup", "taken_block", "taken_block_closeup", "taken_minimap", "rescue_pips", "take_preview", "gate_push"
]
const G_TAKEN: Array[Vector2i] = [Vector2i(3, 2), Vector2i(2, 3)]
const G_PIP_CELL := Vector2i(2, 1)
const G_NIGHT := 0.3

var g_names: Array[String] = []


func _run_grid() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		Looks.set_mode(mode)
		var label := Looks.mode_name().to_lower()
		await _g_new_level()
		await _set_zoom(PlayerConfig.TD_CAMERA_ORTHO_SIZE)
		await _g_start_square(label)
		await _g_taken(label)
		await _g_pips_and_preview(label)
		await _g_push(label)
		print("TIMING ", label, " fallback=", Looks.placeholder_fallback_count())
	_write_sheets_grid()
	print("SAVED ", out_dir)


# A fresh level in the current look: a crowd rescued round the start square (so the line has members), frozen.
func _g_new_level() -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	for p: Person in main.people:
		p.global_position = FAR
		p.gloom = 0.45
		p.mood = Person.Mood.NONE
	for i: int in range(G_RESCUED):
		var a := TAU * float(i) / float(G_RESCUED)
		var p := main.people[i]
		p.gloom = 0.0
		p.global_position = Vector3(cos(a), 0.0, sin(a)) * 4.0
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	main.player.global_position = Vector3.ZERO
	main.night.elapsed = NightConfig.NIGHT_LENGTH * G_NIGHT
	for i: int in range(settle_frames):
		main._process(1.0 / 60.0)
	main.player.spirit = 90.0
	main.player.active = false
	main.player._has_aim = false
	main.intro.enabled = false
	_g_clean()
	main.running = false
	main.camera_rig.update_light()
	await _settle(12)


# Runs the rules for `frames` frames of 1/60 s, then freezes them again.
func _g_run(frames: int) -> void:
	main.running = true
	for i: int in range(frames):
		main._process(1.0 / 60.0)
	main.running = false
	_g_clean()


# Removes the floating joy numbers and the alert (they run on real-time tweens).
func _g_clean() -> void:
	for child: Node in main.get_children():
		if child is Label3D:
			child.queue_free()
	if main.hud._alert_tween != null:
		main.hud._alert_tween.kill()
	main.hud.alert_label.modulate.a = 0.0
	main.hud.alert_panel.modulate.a = 0.0


func _g_move_player(at: Vector3, frames: int = 40) -> void:
	main.player.global_position = Vector3(at.x, 0.0, at.z)
	await _settle(frames)


func _g_shot(view_name: String, label: String, view: Dictionary = {}, frames: int = 8) -> void:
	_g_clean()
	await _settle(frames)
	var full := await _grab()
	if not g_names.has(view_name):
		g_names.append(view_name)
	_save(view_name, label, _cut(full, view))


func _g_start_square(label: String) -> void:
	await _g_move_player(Vector3(0.0, 0.0, 0.0))
	await _g_shot("start_square", label, {}, 20)
	var gate := {"world": Vector3(0.0, 0.2, 6.0), "size": Vector2i(426, 240), "scale": 3}
	await _g_shot("gate_closeup", label, gate, 4)


# Two blocks taken (an L round the start square), the east one beautified: walls on the faces, gates on the open sides.
func _g_taken(label: String) -> void:
	for c: Vector2i in G_TAKEN:
		main.border.zone.take(c)
	var east := TownGrid.cell_centre(G_TAKEN[0])
	for bd: Building in main.border.buildings:
		if bd.centre.distance_to(Vector2(east.x, east.z)) < 1.0:
			bd.inside_time = BorderConfig.BORDER_BUILDING_SECONDS
			bd.beautified = true
			bd.tint = 1.0
			bd.look.sync()
	await _g_run(300)
	await _g_move_player(Vector3(12.0, 0.0, 10.0))
	await _g_shot("taken_block", label, {}, 20)
	var close := {"world": east + Vector3(0.0, 1.5, 0.0), "size": Vector2i(426, 240), "scale": 3}
	await _g_shot("taken_block_closeup", label, close, 4)
	await _g_shot("taken_minimap", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, 4)


# The pips of a cell next to the zone (two of three lit), then the take preview on that cell.
func _g_pips_and_preview(label: String) -> void:
	main.border.pips.counts[G_PIP_CELL] = maxi(BorderConfig.TAKE_RESCUES - 1, 1)
	main.border.pips.version += 1
	var at := TownGrid.cell_centre(G_PIP_CELL)
	await _g_move_player(at + Vector3(0.0, 0.0, 7.5))
	await _g_shot("rescue_pips", label, {}, 20)
	main.take_block.holding = true
	main.player._aim_point = Vector3(at.x, 0.0, at.z)
	main.player._has_aim = true
	await _g_shot("take_preview", label, {}, 14)
	main.take_block.holding = false
	main.player._has_aim = false


# Three dimmed people lean on the start square's west gate; the dent in the line shows.
func _g_push(label: String) -> void:
	await _g_move_player(Vector3(0.0, 0.0, 0.0), 20)
	var spots: Array[Vector3] = [Vector3(-8.2, 0.0, 0.0), Vector3(-8.6, 0.0, 2.6), Vector3(-8.6, 0.0, -2.6)]
	for k: int in range(spots.size()):
		_make_dimmed(main.people[G_RESCUED + k], spots[k])
	await _g_run(150)
	await _g_move_player(Vector3(-2.0, 0.0, 0.0), 20)
	await _g_shot("gate_push", label, {}, 6)


# contact_sheet.png (styled), contact_sheet_compare.png (placeholder | styled) and compare.png (the taken block pair).
func _write_sheets_grid() -> void:
	var cell := Vector2i(640, 360)
	var cols := 3
	var rows := ceili(float(g_names.size()) / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.09, 0.12))
	var compare := Image.create(cell.x * 2, cell.y * g_names.size(), false, Image.FORMAT_RGBA8)
	compare.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(g_names.size()):
		var by_look: Dictionary = shots[g_names[i]]
		_fit(by_look["styled"] as Image, sheet, Vector2i((i % cols) * cell.x, (i / cols) * cell.y), cell)
		_fit(by_look["placeholder"] as Image, compare, Vector2i(0, i * cell.y), cell)
		_fit(by_look["styled"] as Image, compare, Vector2i(cell.x, i * cell.y), cell)
	sheet.save_png(ProjectSettings.globalize_path("%s/contact_sheet.png" % out_dir))
	compare.save_png(ProjectSettings.globalize_path("%s/contact_sheet_compare.png" % out_dir))
