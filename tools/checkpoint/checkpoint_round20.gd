extends "res://tools/checkpoint/checkpoint_shots.gd"

# Graphics checkpoint 4 (`--set round20`, run by tools/checkpoint_shots.py): the round 20 pieces in both looks (the reach
# guide, the stretched zone and its snap, the minimap clouds and landmark stars, the claim and loss pulse and notice) and
# the walk (frames across a cycle for a wistful, a joyful and a dimmed person and for the player walking and running, and
# a crowd walking at once). For each look it builds a fresh level, so the states run in order: no beacon, a beacon
# stretching, the hold, the snap. The rules are frozen between states (running = false); the walkers are driven by hand.
# The base script's dispatch calls _run_round20.

const R20_FRAMES := 8
const R20_STRIP_CROP := Vector2i(220, 300)
const R20_LANDMARKS: Array[String] = ["bandstand", "garden", "bell"]

var r20_names: Array[String] = []
var r20_walk_names: Array[String] = []


func _run_round20() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		Looks.set_mode(mode)
		await _r20_new_level()
		var label := Looks.mode_name().to_lower()
		await _r20_reach_shots(label)
		await _r20_walk_shots(label)
	await _r20_flag_shots()
	_write_sheets_round20()
	print("SAVED ", out_dir)


# A fresh level in the current look with the ring of rescued people (the border), a cluster of unrescued people, frozen.
func _r20_new_level() -> void:
	if main != null:
		main.queue_free()
		await get_tree().process_frame
	main = (load("res://topdown.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
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
	# Unrescued people in a few groups, for the minimap clouds.
	var groups: Array[Vector3] = [Vector3(-22.0, 0.0, 6.0), Vector3(-6.0, 0.0, 30.0), Vector3(30.0, 0.0, 14.0)]
	for g: int in range(groups.size()):
		for j: int in range(6 + g * 2):
			var p := people[ring_count + g * 9 + j]
			var a := TAU * float(j) / 7.0
			p.global_position = groups[g] + Vector3(cos(a), 0.0, sin(a)) * (1.5 + 0.9 * float(j % 3))
			p.gloom = 0.25
			p.joy = 0.0
	main.player.global_position = ring_centre + Vector3(0.5, 0.0, 1.5)
	main.night.elapsed = NightConfig.NIGHT_LENGTH * 0.25
	for i: int in range(settle_frames):
		main._process(1.0 / 60.0)
	main.player.spirit = 90.0
	main.player.active = false
	for p: Person in people:
		p.grab_frac = 0.0
		p.grab_lunging = false
		p._update_visuals()
	for child: Node in main.get_children():
		if child is Label3D:
			child.queue_free()
	main.running = false
	await _settle(12)


# Aims the player's cursor at a point (the guide reads the aim only).
func _r20_aim(at: Vector3) -> void:
	main.player._aim_point = Vector3(at.x, 0.0, at.z)
	main.player._has_aim = true


# Runs the rules for `frames` frames of 1/60 s, then freezes them again.
func _r20_run(frames: int) -> void:
	main.running = true
	for i: int in range(frames):
		main._process(1.0 / 60.0)
	main.running = false
	for child: Node in main.get_children():
		if child is Label3D:
			child.queue_free()


func _r20_snap(view_name: String, label: String, view: Dictionary, aim: Vector3) -> void:
	if not (view_name.begins_with("alert") or view_name.begins_with("landmark")):
		_r20_hide_alert()
	for round_i: int in range(2):
		_r20_aim(aim)
		main.reach_guide.sync(main.border, main.player)
		await _settle(10 if round_i == 0 else 3)
	var full := await _grab()
	_r20_note(view_name)
	_save(view_name, label, _cut(full, view))


func _r20_hide_alert() -> void:
	if main.hud._alert_tween != null:
		main.hud._alert_tween.kill()
	main.hud.alert_label.modulate.a = 0.0
	main.hud.alert_panel.modulate.a = 0.0


func _r20_note(view_name: String) -> void:
	if not r20_names.has(view_name):
		r20_names.append(view_name)


func _r20_reach_shots(label: String) -> void:
	var border := main.border
	var centre := border.centre
	var reach: float = border.stretch_info()["max"]
	var inside := centre + Vector3(reach * 0.6, 0.0, -reach * 0.3)
	var beyond := centre + Vector3(reach * 1.6, 0.0, -reach * 0.5)
	main.player.global_position = centre + Vector3(0.0, 0.0, 2.0)
	_r20_stage_hud()
	await _settle(12)
	await _r20_snap("reach_in_range", label, {}, inside)
	await _r20_snap("reach_capped", label, {}, beyond)
	# The minimap: clouds where the unrescued stand, and the landmarks held and not.
	var held: Array[bool] = [true, false, true]
	for i: int in range(held.size()):
		var lm := main.landmarks.items[i]
		lm.hold = LandmarkConfig.BORDER_LANDMARK_HOLD if held[i] else 0.0
		lm.update(0.0, held[i])
	await _settle(30)
	main.minimap.refresh_clouds(main.people)
	main.minimap.held_landmarks = main.landmarks.held_flags()
	await _settle(8)
	await _r20_snap("minimap_clouds", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, inside)
	await _r20_landmark_pulses(label)
	# A beacon far to the east-south: the tip travels, falls short, holds, then the zone snaps back.
	var target := centre + Vector3(reach * 1.5, 0.0, reach * 0.5)
	main.border.place_beacon(target)
	main.beacon_marker.sync(main.border.beacon_pos(), 0.3, main.border.centre)
	_r20_run(240)
	main.beacon_marker.sync(main.border.beacon_pos(), 0.3, main.border.centre)
	main.player.global_position = centre.lerp(main.border.beacon_pos(), 0.4)
	await _settle(12)
	await _r20_snap("zone_travel", label, {}, target)
	var tip: Vector3 = main.border.stretch_info()["tip"]
	await _r20_snap("reach_travel_close", label, _r20_world_view(tip, 480, 270, 2), target)
	var guard := 0
	while main.border.stretch_info()["on"] and guard < 40:
		_r20_run(60)
		guard += 1
	main.player.global_position = centre.lerp(main.border.beacon_pos(), 0.4)
	await _settle(12)
	await _r20_snap("zone_hold", label, {}, target)
	_r20_run(30)
	_r20_run(480)
	main.player.global_position = main.border.centre + Vector3(0.0, 0.0, 2.0)
	await _settle(12)
	await _r20_snap("zone_snapped", label, {}, main.border.centre + Vector3(8.0, 0.0, 0.0))
	await _r20_snap("minimap_after", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, main.border.centre)


# A close-up cut around a world point, `w` x `h` window pixels, enlarged `k` times.
func _r20_world_view(at: Vector3, w: int, h: int, k: int) -> Dictionary:
	return {"world": at, "size": Vector2i(w, h), "scale": k}


# The claim and loss of the bandstand: the pulse ring and the notice, a moment after each.
func _r20_landmark_pulses(label: String) -> void:
	var lm := main.landmarks.items[0]
	var at: Vector3 = LandmarkConfig.LANDMARK_POSITIONS[0]
	main.player.global_position = at + Vector3(7.0, 0.0, -1.0)
	lm.hold = 0.0
	lm.update(0.0, false)
	await _settle(200)
	lm.hold = LandmarkConfig.BORDER_LANDMARK_HOLD - 0.01
	lm.update(0.02, true)
	await _settle(14)
	var view := _r20_world_view(Vector3(at.x, 3.0, at.z), 480, 300, 2)
	await _r20_snap("landmark_claimed", label, view, at)
	await _r20_snap("alert_claimed", label, {"rect": Rect2i(320, 170, 640, 90), "scale": 2}, at)
	await _settle(200)
	lm.update(0.0, false)
	await _settle(14)
	await _r20_snap("landmark_lost", label, view, at)
	await _r20_snap("alert_lost", label, {"rect": Rect2i(320, 170, 640, 90), "scale": 2}, at)
	await _settle(120)
	lm.hold = LandmarkConfig.BORDER_LANDMARK_HOLD
	lm.update(0.0, true)
	await _settle(60)


# Windows that cover the HUD with fresh state: no prompt bar.
func _r20_stage_hud() -> void:
	main.intro.enabled = false
	main.intro.current = -1


# ---- The walk ----------------------------------------------------------------------------------------------------------


func _r20_walk_shots(label: String) -> void:
	var people := main.people
	if main.hud._alert_tween != null:
		main.hud._alert_tween.kill()
	main.hud.alert_label.modulate.a = 0.0
	main.hud.alert_panel.modulate.a = 0.0
	var base := Vector3(-8.0, 0.0, -4.0)
	main.player.global_position = base + Vector3(4.0, 0.0, 6.0)
	await _set_zoom(14.0)
	var rows: Array[Dictionary] = [
		{"name": "walk_grey", "kind": "grey", "speed": 1.6, "index": 50},
		{"name": "walk_joy", "kind": "joy", "speed": 2.4, "index": 51},
		{"name": "walk_dimmed", "kind": "dim", "speed": 1.0, "index": 52},
	]
	for row: Dictionary in rows:
		var p: Person = people[row["index"]]
		var kind: String = row["kind"]
		var speed: float = row["speed"]
		var strip_name: String = row["name"]
		_r20_prepare_walker(p, kind, base)
		var frames := await _r20_walk_frames(p, speed, 60, 4)
		_r20_save_strip(strip_name, label, frames)
		p.global_position = FAR
	# The player: a walk, then a run.
	var player := main.player
	player.global_position = Vector3(2.0, 0.0, 14.0)
	var gaits: Array[Dictionary] = [
		{"name": "walk_player", "speed": PlayerConfig.TD_MOVE_SPEED}, {"name": "run_player", "speed": PlayerConfig.TD_RUN_SPEED}
	]
	for gait_row: Dictionary in gaits:
		var gait_speed: float = gait_row["speed"]
		var gait_name: String = gait_row["name"]
		player.global_position = Vector3(-14.0, 0.0, -4.0)
		player.rotation.y = -PI * 0.5
		var gait_frames := await _r20_walk_frames(player, gait_speed, 50, 3)
		_r20_save_strip(gait_name, label, gait_frames)
	await _set_zoom(PlayerConfig.TD_CAMERA_ORTHO_SIZE)
	await _r20_crowd(label)


func _r20_prepare_walker(p: Person, kind: String, at: Vector3) -> void:
	p.global_position = at
	p.mood = Person.Mood.NONE
	p.joy = 0.0
	if kind == "grey":
		p.gloom = 0.45
		p.level = 1
	elif kind == "dim":
		_make_dimmed(p, at)
	else:
		p.gloom = 0.0
		p.receive_joy(p.affinity, Config.JOY_MAX * 2.0, 0.0)
	p.rotation.y = -PI * 0.5
	p._update_visuals()


# Walks `walker` along +x at `speed` for `frames` simulated frames (1/60 s each), taking a picture every `every` frames
# after the first 20 (which let the gait build up). Returns the cropped pictures (R20_FRAMES of them).
func _r20_walk_frames(walker: Node3D, speed: float, warm: int, every: int) -> Array[Image]:
	var out: Array[Image] = []
	var look_node: Object = walker.get("look")
	var dt := 1.0 / 60.0
	var total := warm + every * R20_FRAMES
	for f: int in range(total):
		walker.position.x += speed * dt
		look_node.call("advance", dt)
		look_node.call("sync")
		if f >= warm and (f - warm) % every == 0:
			await _settle(2)
			var full := await _grab()
			out.append(_r20_crop_on(full, walker))
		else:
			await get_tree().process_frame
	return out


func _r20_crop_on(full: Image, walker: Node3D) -> Image:
	var sp := main.world_to_screen(Vector3(walker.global_position.x, 0.8, walker.global_position.z))
	var x := clampi(int(sp.x) - R20_STRIP_CROP.x / 2, 0, 1280 - R20_STRIP_CROP.x)
	var y := clampi(int(sp.y) - R20_STRIP_CROP.y / 2, 0, 720 - R20_STRIP_CROP.y)
	var crop := full.get_region(Rect2i(Vector2i(x, y), R20_STRIP_CROP))
	crop.resize(R20_STRIP_CROP.x * 2, R20_STRIP_CROP.y * 2, Image.INTERPOLATE_NEAREST)
	return crop


func _r20_save_strip(strip_name: String, label: String, frames: Array[Image]) -> void:
	var w := R20_STRIP_CROP.x * 2
	var h := R20_STRIP_CROP.y * 2
	var cols := 4
	var rows := ceili(float(frames.size()) / float(cols))
	var sheet := Image.create(w * cols, h * rows, false, Image.FORMAT_RGBA8)
	for i: int in range(frames.size()):
		sheet.blit_rect(frames[i], Rect2i(0, 0, w, h), Vector2i((i % cols) * w, (i / cols) * h))
	if not r20_walk_names.has(strip_name):
		r20_walk_names.append(strip_name)
	if not shots.has(strip_name):
		shots[strip_name] = {}
	var by_look: Dictionary = shots[strip_name]
	by_look[label] = sheet
	sheet.save_png(ProjectSettings.globalize_path("%s/%s_%s.png" % [out_dir, strip_name, label]))


# A crowd walking at once: twelve people from the same start, each with its own look seed, taken in one frame.
func _r20_crowd(label: String) -> void:
	var people := main.people
	var base := Vector3(-10.0, 0.0, 4.0)
	main.player.global_position = base + Vector3(10.0, 0.0, 0.0)
	var group: Array[Person] = []
	for i: int in range(12):
		var p: Person = people[20 + i]
		var kind := "joy" if i % 3 == 0 else ("grey" if i % 3 == 1 else "dim")
		_r20_prepare_walker(p, kind, base + Vector3(float(i % 4) * 3.2, 0.0, float(i / 4) * 3.4 - 3.4))
		group.append(p)
	var dt := 1.0 / 60.0
	for f: int in range(240):
		for i: int in range(group.size()):
			var p := group[i]
			p.position.x += (1.2 + 0.15 * float(i % 4)) * dt
			p.look.advance(dt)
			p.look.sync()
		await get_tree().process_frame
	await _settle(3)
	var full := await _grab()
	_r20_note("walk_crowd")
	_save("walk_crowd", label, _cut(full, {"rect": Rect2i(240, 120, 800, 480), "scale": 1}))


# ---- The round 19 flags, in the checkpoint 2 scenario (the shield, the canopy and the guarded icon) ------------------------


func _r20_flag_shots() -> void:
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		Looks.set_mode(mode)
		if main != null:
			main.queue_free()
			await get_tree().process_frame
		main = (load("res://topdown.tscn") as PackedScene).instantiate()
		add_child(main)
		await get_tree().process_frame
		_build_scenario()
		await _settle(12)
		var label := Looks.mode_name().to_lower()
		_make_views()
		for view: Dictionary in views:
			var view_name: String = view["name"]
			if not ["wedge_closeup", "shield_closeup", "ui_closeup"].has(view_name):
				continue
			_refresh_effects()
			var full := await _grab()
			_r20_note("flag_" + view_name)
			_save("flag_" + view_name, label, _cut(full, view))
		# The dawn rating (the suns) and the unheld bandstand (the ruin).
		main.queue_free()
		await get_tree().process_frame
		main = (load("res://topdown.tscn") as PackedScene).instantiate()
		add_child(main)
		await get_tree().process_frame
		_r20_flag_dawn(label)
		await _settle(10)
		var dawn := await _grab()
		_r20_note("flag_dawn")
		_save("flag_dawn", label, dawn)


func _r20_flag_dawn(_label: String) -> void:
	main.running = false
	var r := DawnRating.rate(42, Config.TD_PEOPLE_COUNT, 0.46, 3)
	main.rating = r
	main.hud.show_end("Dawn: %d of 3 dawn lights" % (r["lights"] as int), main.level_end.detail_text(), r)


func _write_sheets_round20() -> void:
	var cell := Vector2i(640, 360)
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
	# The walk strips, styled, one under another.
	var strip_w := R20_STRIP_CROP.x * 2 * 4
	var strip_h := R20_STRIP_CROP.y * 2 * 2
	var walk := Image.create(strip_w, strip_h * r20_walk_names.size(), false, Image.FORMAT_RGBA8)
	for i: int in range(r20_walk_names.size()):
		var by_look: Dictionary = shots[r20_walk_names[i]]
		var img: Image = by_look["styled"]
		walk.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(0, i * strip_h))
	walk.save_png(ProjectSettings.globalize_path("%s/walk_sheet.png" % out_dir))
	var both := Image.create(2560, 720, false, Image.FORMAT_RGBA8)
	var over: Dictionary = shots["zone_travel"]
	both.blit_rect(over["placeholder"] as Image, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	both.blit_rect(over["styled"] as Image, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
	both.save_png(ProjectSettings.globalize_path("%s/compare.png" % out_dir))
	(over["styled"] as Image).save_png(ProjectSettings.globalize_path("%s/overview.png" % out_dir))
