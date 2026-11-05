extends "res://tools/checkpoint/checkpoint_round20.gd"

# Graphics checkpoint 5 (`--set round24`, run by tools/checkpoint_shots.py): everything added since round 20, in both looks.
# Focus 1, reading the fight: gaps and strain rings, the gap patch (ward, pulse, "Held: N"), the burst and the people it
# lifts, the wobble (greying, shaking, closing ring), the reactions (hops, turns, glows), the cue panel and a notice.
# Focus 2, dawn: the first-light front at three moments, the ground it lifts, people lifted behind it, the minimap edge.
# Then the shape preview (in range, limited, stretching, finish pulse), dimmed people warming as joy builds and the dimmed
# walk and the player's jog (the round 20 walk strips). For each look it builds fresh levels, so the states run in order.
# The rules are frozen (running = false) except for short, explicit runs after an event, so the reaction can play.

const R24_SHEET_CELL := Vector2i(640, 360)

var r24_gap := Vector3.ZERO


func _run_round24() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	for mode: int in [Looks.Mode.PLACEHOLDER, Looks.Mode.STYLED]:
		Looks.set_mode(mode)
		var label := Looks.mode_name().to_lower()
		await _r24_fight(label)
		await _r24_wobble_and_warming(label)
		await _r24_reach(label)
		await _r24_dawn(label)
		await _r24_level()
		await _r20_walk_shots(label)
		print("TIMING ", label, " fallback=", Looks.placeholder_fallback_count(), " ", Looks.fallback_summary())
	_write_sheets_round24()
	print("SAVED ", out_dir)


# ---- Helpers ---------------------------------------------------------------------------------------------------------


# A fresh level (see checkpoint_round20.gd) with the border redrawn from its settled state: the rules are frozen, so the
# gaps of the loop's first moments (which the real game redraws every frame) would otherwise stay on screen.
func _r24_level() -> void:
	await _r20_new_level()
	main.player._has_aim = false
	main.border._draw_lines()
	await _settle(8)
	main.border._draw_lines()
	await _settle(8)


# The border's members, in order of their angle round the centre (so neighbours in the list are neighbours on the loop).
func _r24_ring_members() -> Array[Person]:
	var out: Array[Person] = []
	out.assign(main.border.members)
	var c := main.border.centre
	out.sort_custom(
		func(a: Person, b: Person) -> bool:
			return atan2(a.position.z - c.z, a.position.x - c.x) < atan2(b.position.z - c.z, b.position.x - c.x)
	)
	return out


# Takes a picture of the current frame after `frames` frames, cuts `view` from it and saves it as `view_name`.
func _r24_shot(view_name: String, label: String, view: Dictionary = {}, frames: int = 8) -> void:
	if not (view_name.begins_with("dawn_banner") or view_name.begins_with("fight_notice")):
		_r20_hide_alert()
	await _settle(frames)
	var full := await _grab()
	_r20_note(view_name)
	_save(view_name, label, _cut(full, view))


func _r24_move_player(at: Vector3, frames: int = 40) -> void:
	main.player.global_position = Vector3(at.x, 0.0, at.z)
	await _settle(frames)


# Sets a border member's joy so the warning's urgency is `urgency` (0 healthy .. 1 about to falter).
func _r24_strain(m: Person, urgency: float) -> void:
	var frac := Config.BORDER_WARN_START - urgency * (Config.BORDER_WARN_START - Config.MEMBER_FALTER_FRACTION)
	m.joy = m.joy_needed() * frac
	m._update_visuals()


# Runs the rules for `frames` frames (with the floating numbers cleared) and freezes them again.
func _r24_run(frames: int) -> void:
	_r20_run(frames)


# ---- Focus 1: reading the fight --------------------------------------------------------------------------------------------


func _r24_fight(label: String) -> void:
	await _r24_level()
	_r20_stage_hud()
	var ring := _r24_ring_members()
	var centre := main.border.centre
	# Three strained members (low, middle, high urgency) and a dimmed person pressing a fourth.
	_r24_strain(ring[2], 0.25)
	_r24_strain(ring[5], 0.62)
	_r24_strain(ring[8], 0.95)
	var out := (ring[12].position - centre).normalized()
	_make_dimmed(main.people[ring_count + 30], ring[12].position + out * 2.6)
	# An open gap on the far side from the strained ones.
	_force_gap(0)
	r24_gap = main.border.gap_midpoints()[0] if main.border.gap_midpoints().size() > 0 else centre
	await _r24_move_player(centre + Vector3(0.0, 0.0, 1.5))
	await _r24_shot("fight_strain", label, {}, 14)
	await _r24_shot("fight_gap_closeup", label, {"world": r24_gap, "size": Vector2i(426, 240), "scale": 3})
	await _r24_shot(
		"fight_strain_closeup",
		label,
		{"world": (ring[5].position + ring[8].position) * 0.5, "size": Vector2i(426, 240), "scale": 3}
	)
	# The cue panel: aimed at the gap it is ready (gold); not aimed it says to aim; nothing near, nothing.
	main.running = true
	_r20_aim(r24_gap)
	await _settle(10)
	await _r24_shot("fight_cue_ready", label, {"rect": Rect2i(560, 560, 600, 130), "scale": 2}, 3)
	main.running = false
	main.player._has_aim = false
	# The patch: F at the gap. Frames pass so the people hop, turn and glow; then the ward as it is mid-way.
	main.player.spirit = 90.0
	main.gap_patch.patch_at(r24_gap, "gap")
	_r24_run(20)
	await _r24_shot("fight_patch", label, {}, 4)
	await _r24_shot(
		"fight_patch_closeup", label, {"world": r24_gap, "size": Vector2i(426, 240), "scale": 3}, 2
	)
	_r24_run(18)
	await _r24_shot("fight_reactions_closeup", label, {"world": r24_gap, "size": Vector2i(426, 240), "scale": 3}, 2)
	# Nearly out: the ward flickers.
	main.gap_patch.patches[0]["left"] = 2.0
	_r24_run(6)
	await _r24_shot("fight_patch_ending", label, {"world": r24_gap, "size": Vector2i(640, 360), "scale": 2}, 2)
	await _r24_burst(label)
	await _r24_notice(label)


# The burst: dimmed people near the loop are lifted, with a streak, a ring and a column of light each.
func _r24_burst(label: String) -> void:
	var ring := _r24_ring_members()
	var centre := main.border.centre
	var cleared: Array[Dictionary] = []
	for i: int in range(4):
		var p: Person = main.people[ring_count + 20 + i]
		var m := ring[(i * 4 + 1) % ring.size()]
		var out := (m.position - centre).normalized()
		var side := Vector3(-out.z, 0.0, out.x)
		var from := m.position + out * 1.6 + side * float(i - 2) * 0.9
		var to := m.position + out * 5.2 + side * float(i - 2) * 1.6
		_make_dimmed(p, from)
		cleared.append({"person": p, "from": from, "to": to})
	main.player.global_position = Vector3(centre.x, 0.0, centre.z + 1.5)
	await _settle(30)
	await _r24_shot("fight_burst_before", label, {}, 4)
	for c: Dictionary in cleared:
		var p: Person = c["person"]
		var to: Vector3 = c["to"]
		p.global_position = Vector3(to.x, 0.0, to.z)
		p.gloom = Config.BURST_LIFT_GLOOM
		p.level = Config.gloom_level(p.gloom)
		p.joy = 0.0
		p.calm_left = Config.BURST_CALM_SECONDS
	main.gap_patch._on_burst_cleared({"cleared": cleared, "lifted": cleared.size(), "joy_hits": 0})
	main.player.look.play_burst(Config.BURST_CLEAR_RADIUS, Config.TD_BURST_TIME)
	_r24_run(14)
	await _r24_shot("fight_burst", label, {}, 3)
	var lifted: Dictionary = cleared[1]
	var lifted_at: Vector3 = lifted["to"]
	await _r24_shot("fight_burst_closeup", label, {"world": lifted_at, "size": Vector2i(426, 240), "scale": 3}, 2)


# A refusal notice (E or F pressed where it cannot be done).
func _r24_notice(label: String) -> void:
	main.intro.enabled = true
	main.intro.notice(Intro.Prompt.PATCH_NONE)
	main.intro.time_left = main.intro.duration - 1.0  # Past the fade-in: fully shown.
	await _r24_shot("fight_notice", label, {"rect": Rect2i(240, 180, 800, 140), "scale": 2}, 6)
	main.intro.notice(Intro.Prompt.BEACON_BLOCKED, Config.BEACON_DIM_TEXT)
	main.intro.time_left = main.intro.duration - 1.0
	await _settle(14)
	main.intro.enabled = false
	main.intro.current = -1


# ---- The wobble and a dimmed person warming ------------------------------------------------------------------------------------


func _r24_wobble_and_warming(label: String) -> void:
	await _r24_level()
	_r20_stage_hud()
	var ring := _r24_ring_members()
	var progress: Array[float] = [0.04, 0.4, 0.72, 0.97]
	for i: int in range(progress.size()):
		var m := ring[2 + i]
		m.joy = m.joy_needed() * Config.RELAPSE_FRACTION * 0.4
		m._start_wobble()
		m.wobble_left = m.wobble_total * (1.0 - progress[i])
		m._update_visuals()
	_r24_strain(ring[8], 0.4)
	await _r24_move_player(main.border.centre + Vector3(0.0, 0.0, 1.5))
	await _r24_shot("wobble_overview", label, {}, 12)
	var mid := (ring[3].position + ring[4].position) * 0.5
	await _r24_shot("wobble_closeup", label, {"world": mid, "size": Vector2i(426, 240), "scale": 3}, 2)
	# Dimmed people at 0, 35, 70 and 95% of the joy they need: the body warms from the smoky coat to its own colour.
	var base := main.player.global_position + Vector3(-5.0, 0.0, -4.0)
	var fracs: Array[float] = [0.0, 0.35, 0.7, 0.95]
	for i: int in range(fracs.size()):
		var p: Person = main.people[ring_count + 30 + i]
		_make_dimmed(p, base + Vector3(float(i) * 2.6, 0.0, 0.0))
		p.rotation.y = 0.0
		p.joy = p.joy_needed() * fracs[i]
		p._update_visuals()
	await _r24_shot(
		"dimmed_warming", label, {"world": base + Vector3(3.9, 0.0, 0.0), "size": Vector2i(426, 240), "scale": 3}, 6
	)


# ---- The shape preview ---------------------------------------------------------------------------------------------------------


func _r24_reach(label: String) -> void:
	await _r24_level()
	_r20_stage_hud()
	var border := main.border
	var centre := border.centre
	var reach: float = border.stretch_info()["max"]
	var radius: float = border.stretch_info()["radius"]
	# The aim is out over open ground past the zone's body, so the preview is the new arm (a thin outline), not a copy of
	# the zone it already has.
	var out := Vector3(-1.0, 0.0, 0.3).normalized()
	var aim := centre + out * (radius + (reach - radius) * 0.4)
	await _r24_move_player(centre + Vector3(0.0, 0.0, 2.0))
	# The player's physics tick would take the aim from the real mouse, so the aim is pinned for these shots: `active`
	# false stops the aim update (the round-end freeze), and it is set back at the end.
	main.player.active = false
	_r20_aim(aim)
	# Checkpoint 5 follow-up: the preview shows only while E is held, so the shots hold E (BeaconPlacement.press).
	BeaconPlacement.press(main)
	main.reach_guide.sync(border, main.player)
	await _r24_shot("reach_preview", label, {}, 8)
	await _r24_shot("reach_preview_close", label, {"world": aim, "size": Vector2i(426, 240), "scale": 3}, 2)
	# Limited: the aim is inside the zone the border already has, so nothing can grow there (the quiet "no": a thin coral
	# outline and a small cross at the tip). The dimmed-people block is covered by stretch_safety_test instead: placing
	# dimmed people on the tip did not hold the stretch in this scenario.
	var inside := centre + out * (radius * 0.5)
	_r20_aim(inside)
	await _settle(4)
	main.reach_guide.sync(border, main.player)
	await _r24_shot("reach_limited", label, {}, 8)
	# Close-up of the tip, so the thin outline and the small cross can be read at pixel size.
	await _r24_shot("reach_limited_close", label, {"world": inside, "size": Vector2i(426, 240), "scale": 3}, 2)
	BeaconPlacement.cancel(main)
	# Stretching: a beacon far to the east-south, shot as the tip travels.
	for i: int in range(3):
		main.people[ring_count + 30 + i].global_position = FAR
	var target := centre + Vector3(reach * 1.5, 0.0, reach * 0.5)
	main.border.place_beacon(target)
	main.beacon_marker.sync(main.border.beacon_pos(), 0.3, main.border.centre)
	_r24_run(150)
	main.player.global_position = centre.lerp(main.border.beacon_pos(), 0.4)
	await _settle(40)
	main.reach_guide.sync(border, main.player)
	await _r24_shot("reach_stretching", label, {}, 8)
	var guard := 0
	while main.border.stretch_info()["on"] and guard < 40:
		_r24_run(60)
		guard += 1
	# The finish: the wave along the new arm and the ring at the tip, early in the pulse.
	main.reach_guide._on_zone_grew(
		42.0, Vector3(border.centre.x + reach * 1.1, 0.0, border.centre.z + reach * 0.3), 0.3
	)
	main.reach_guide._pulse_left = Config.BEACON_PULSE_SECONDS * 0.6
	await _settle(2)
	main.reach_guide.sync(border, main.player)
	await _r24_shot("reach_pulse", label, {}, 1)
	main.player.active = true


# ---- Focus 2: first light ----------------------------------------------------------------------------------------------------


# Puts the night at `progress` through first light and moves the front there (the rules are run by hand).
func _r24_front(progress: float) -> void:
	main.night.elapsed = Config.NIGHT_LENGTH - Config.FIRST_LIGHT_SECONDS * (1.0 - progress)
	main._update_light()
	main.hud.set_night_progress(main.night.progress())
	main.first_light.step(0.0)
	main.minimap.refresh_clouds(main.people)


func _r24_dawn(label: String) -> void:
	await _r24_level()
	_r20_stage_hud()
	var people := main.people
	# Wistful, gloomy and dimmed people across the east side, so the front passes some and not others.
	var spots: Array[Vector3] = [
		Vector3(33.0, 0.0, 6.0), Vector3(35.5, 0.0, 9.5), Vector3(30.0, 0.0, 12.0), Vector3(27.0, 0.0, 5.0),
		Vector3(38.0, 0.0, 3.0), Vector3(24.0, 0.0, 10.0),
	]
	for i: int in range(spots.size()):
		_make_dimmed(people[ring_count + 30 + i], spots[i])
	# Early: the front is near the edge of the map, east of the player.
	await _r24_move_player(Vector3(32.0, 0.0, 8.0))
	_r24_front(0.22)
	await _r24_shot("dawn_early", label, {}, 20)
	# The "First light" line (snag round: an intro notice in both looks).
	main.intro.notice(Intro.Prompt.FIRST_LIGHT)
	await _r24_shot("dawn_banner", label, {}, 3)
	await _r24_shot("dawn_minimap_early", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, 2)
	# Middle: the front has passed the nearer people; the ones behind it are lifted a stage (set by hand: the rules lift
	# 0.03 gloom a second, which takes tens of seconds).
	_r24_front(0.5)
	for p: Person in people:
		if not p.is_rescued and p.dawn_lit and p.gloom > 0.8:
			p.gloom = 0.55
			p.level = Config.gloom_level(p.gloom)
			p._update_visuals()
	await _r24_move_player(Vector3(20.0, 0.0, 8.0))
	await _r24_shot("dawn_mid", label, {}, 20)
	await _r24_shot("dawn_lifted_closeup", label, {"world": Vector3(30.0, 0.0, 8.0), "size": Vector2i(426, 240), "scale": 3}, 2)
	await _r24_shot("dawn_minimap_mid", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, 2)
	# Late: the front is near the middle; the ring of the border sits in the light.
	_r24_front(0.85)
	for p: Person in people:
		if not p.is_rescued and p.dawn_lit and p.gloom > 0.3:
			p.gloom = 0.2
			p.level = Config.gloom_level(p.gloom)
			p._update_visuals()
	await _r24_move_player(Vector3(8.0, 0.0, -6.0))
	await _r24_shot("dawn_late", label, {}, 20)
	await _r24_shot("dawn_minimap_late", label, {"rect": Rect2i(10, 10, 270, 270), "scale": 3}, 2)


# ---- Sheets ------------------------------------------------------------------------------------------------------------------


func _write_sheets_round24() -> void:
	var cell := R24_SHEET_CELL
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
	# Two focus sheets (styled only), 2 columns: the fight and the dawn.
	_focus_sheet("fight_sheet.png", names, "fight_")
	_focus_sheet("dawn_sheet.png", names, "dawn_")
	var strip_w := R20_STRIP_CROP.x * 2 * 4
	var strip_h := R20_STRIP_CROP.y * 2 * 2
	var walk := Image.create(strip_w, strip_h * r20_walk_names.size(), false, Image.FORMAT_RGBA8)
	for i: int in range(r20_walk_names.size()):
		var by_look: Dictionary = shots[r20_walk_names[i]]
		var img: Image = by_look["styled"]
		walk.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(0, i * strip_h))
	walk.save_png(ProjectSettings.globalize_path("%s/walk_sheet.png" % out_dir))
	var both := Image.create(2560, 720, false, Image.FORMAT_RGBA8)
	var over: Dictionary = shots["fight_patch"]
	both.blit_rect(over["placeholder"] as Image, Rect2i(0, 0, 1280, 720), Vector2i(0, 0))
	both.blit_rect(over["styled"] as Image, Rect2i(0, 0, 1280, 720), Vector2i(1280, 0))
	both.save_png(ProjectSettings.globalize_path("%s/compare.png" % out_dir))
	(over["styled"] as Image).save_png(ProjectSettings.globalize_path("%s/overview.png" % out_dir))


# A sheet of the styled views whose name starts with `prefix`, two to a row at 640x360.
func _focus_sheet(file_name: String, names: Array[String], prefix: String) -> void:
	var picked: Array[String] = []
	for n: String in names:
		if n.begins_with(prefix):
			picked.append(n)
	if picked.is_empty():
		return
	var cell := R24_SHEET_CELL
	var cols := 2
	var rows := ceili(float(picked.size()) / float(cols))
	var sheet := Image.create(cell.x * cols, cell.y * rows, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.1, 0.09, 0.12))
	for i: int in range(picked.size()):
		var by_look: Dictionary = shots[picked[i]]
		_fit(by_look["styled"] as Image, sheet, Vector2i((i % cols) * cell.x, (i / cols) * cell.y), cell)
	sheet.save_png(ProjectSettings.globalize_path("%s/%s" % [out_dir, file_name]))
