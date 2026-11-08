extends "res://tools/checkpoint/checkpoint_round20.gd"

# Graphics checkpoint 7 (`--set checkpoint7`, run by tools/checkpoint_shots.py): the look after checkpoint 7 in both looks.
# Calm opening (the first frames of a game, no ring yet), mid-night inside the zone and outside it (the living ground,
# the street props, the ambient life and the gloom mist), a push in progress (the pushers' lean and the fog at the pushed
# stretch) and dawn (the sky warming, the first-light front). For each look it builds fresh levels, so the states run in
# order. The rules are frozen (running = false) except for the short run that makes a push visible.
# This script extends checkpoint_round20.gd and carries its own copies of the few round 24 helpers it needs: the round 24
# script references a removed gap patch, so it does not load.

const C7_SHEET_CELL := Vector2i(640, 360)


func _run_checkpoint7() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		Looks.set_mode(mode)
		var label := Looks.mode_name().to_lower()
		await _c7_opening(label)
		await _c7_midnight(label)
		await _c7_push(label)
		await _c7_dawn(label)
		print("TIMING ", label, " fallback=", Looks.placeholder_fallback_count(), " ", Looks.fallback_summary())
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
func _c7_opening(label: String) -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.running = false
	main.night.elapsed = 0.0
	main._update_light()
	await _c7_shot("calm_opening", label, {}, 40)


# Mid-night inside the zone (the player on the ring's centre) and outside it (the player away from the ring).
func _c7_midnight(label: String) -> void:
	await _c7_level()
	_c7_night(0.5)
	await _c7_move_player(main.border.centre + Vector3(0.0, 0.0, 1.5))
	await _c7_shot("midnight_inside_zone", label, {}, 20)
	await _c7_move_player(Vector3(-8.0, 0.0, -4.0))
	await _c7_shot("midnight_outside_zone", label, {}, 20)


# A push in progress: two dimmed people lean on a stretch of the ring, the rules run a moment so the push builds.
func _c7_push(label: String) -> void:
	await _c7_level()
	_c7_night(0.5)
	var ring := _c7_ring_members()
	var centre := main.border.centre
	var out := (ring[10].position - centre).normalized()
	_make_dimmed(main.people[ring_count + 30], ring[10].position + out * 1.3)
	_make_dimmed(main.people[ring_count + 31], ring[10].position + out * 1.6 + Vector3(-out.z, 0.0, out.x) * 0.9)
	await _c7_move_player(centre + Vector3(0.0, 0.0, 1.5))
	_r20_run(45)
	await _c7_shot("push_in_progress", label, {}, 4)
	await _c7_shot(
		"push_closeup", label, {"world": ring[10].position + out * 0.8, "size": Vector2i(426, 240), "scale": 3}, 2
	)


# Dawn: the front has reached the middle of the map; the sky is warming and the ring sits in the light.
func _c7_dawn(label: String) -> void:
	await _c7_level()
	await _c7_move_player(Vector3(20.0, 0.0, 8.0))
	_c7_front(0.6)
	await _c7_shot("dawn", label, {}, 20)


# ---- Sheets ------------------------------------------------------------------------------------------------------------


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
