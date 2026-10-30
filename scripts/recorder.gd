class_name Recorder
extends Node

# Round 18: the gameplay recorder. While it is on, each game writes a session folder with `events.jsonl` (one JSON
# object per line) and a screenshot every Config.RECORD_SHOT_SECONDS. tools/analyse_recording.py reads the folder.
#
# It only LISTENS: it connects to signals the game already has and polls a few public fields; it never changes game
# state, uses no random numbers and does no file I/O per frame (lines are buffered and written every
# Config.RECORD_FLUSH_SECONDS, on the end of the round, and when the node leaves the tree or the window is closed).
# To record a new event, call `emit_event("my_type", {"field": value})` from the code that knows about it, or connect a
# signal in `attach()`. Every line gets `t`, `night_phase`, `night` (seconds since dusk) and `type` for free.

const SETTINGS_PATH := "user://settings.cfg"
const STAGE_NAMES: Array[String] = ["wistful", "gloomy", "dimmed"]
const PHASE_NAMES: Array[String] = ["calm", "rising", "midnight", "easing"]

# Menu toggle (lasts for the session; persisted by save_setting). The `--record` user argument also turns it on.
static var enabled: bool = false
# Tests set this to put session folders somewhere else (a user:// path). Empty = the normal places.
static var base_dir_override: String = ""

# The session folder (absolute or user:// path) and the events file.
var session_dir: String = ""
var events_path: String = ""
# Why the session ended (set once): "win", "loss", "dawn", "restart", "menu", "quit" or "exit".
var ended_reason: String = ""
# Seconds of play so far (counted while the level runs).
var t: float = 0.0
var shots_taken: int = 0

var _main: TopDownMain
var _file: FileAccess
var _buf := PackedStringArray()
var _ids: Dictionary = {}
var _sample_timer: float = 0.0
var _poll_timer: float = 0.0
var _flush_timer: float = 0.0
var _shot_timer: float = 0.0
var _joy_landed: int = 0
var _last_target: Person = null
var _shield_down := PackedFloat32Array()
var _gap_pos: Array[Vector3] = []
var _gap_id: Array[int] = []
var _gap_opened: Array[float] = []
var _next_gap_id: int = 1
var _exit_reason: String = "exit"


# True when this game should record: the menu toggle or the `--record` user argument.
static func requested() -> bool:
	return enabled or "--record" in OS.get_cmdline_user_args()


# Loads the saved menu choice (not under automated tests, which must not read a player's settings).
static func load_setting() -> void:
	if Config.is_automated_test():
		return
	load_setting_from(SETTINGS_PATH)


# Reads the menu choice from the config file at `path` (a missing or unreadable file leaves it as it is).
static func load_setting_from(path: String) -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		enabled = cfg.get_value("recording", "enabled", false) == true


static func save_setting() -> void:
	if Config.is_automated_test():
		return
	save_setting_to(SETTINGS_PATH)


# Writes the menu choice into the config file at `path`, keeping whatever else that file holds.
static func save_setting_to(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	cfg.set_value("recording", "enabled", enabled)
	cfg.save(path)


# The night phase name for a night progress 0..1 (the calm opening, then thirds up to dawn).
static func phase_for(progress: float) -> String:
	if progress < Config.NIGHT_CALM_FRACTION:
		return PHASE_NAMES[0]
	if progress < 0.5:
		return PHASE_NAMES[1]
	if progress < 0.75:
		return PHASE_NAMES[2]
	return PHASE_NAMES[3]


# Starts a session for `main` (call at the end of its _ready). Returns false when it could not open a file.
func attach(main: TopDownMain) -> bool:
	_main = main
	if not _open_session():
		push_warning("Recorder: could not create a recording folder")
		return false
	for i: int in range(main.people.size()):
		var p: Person = main.people[i]
		_ids[p] = i
		p.stage_changed.connect(_on_stage_changed.bind(p))
		p.rescued.connect(_on_rescued.bind(p))
		p.relapsed.connect(_on_relapsed.bind(p))
		p.joy_blocked.connect(_on_joy_blocked.bind(p))
		p.joy_landed.connect(_on_joy_landed)
	_shield_down.resize(main.people.size())
	main.player.burst_fired.connect(_on_burst)
	main.player.dim_changed.connect(_on_player_dim)
	main.grabs.grab_landed.connect(_on_grab_landed)
	main.grabs.grab_avoided.connect(_on_grab_avoided)
	main.beacon_placed.connect(_on_beacon_placed)
	main.border.beacon_reached.connect(_on_beacon_reached)
	for lm: Landmark in main.landmarks.items:
		lm.claimed.connect(_on_landmark.bind(lm, "landmark_claimed"))
		lm.lost.connect(_on_landmark.bind(lm, "landmark_lost"))
	main.hud.set_recording(true)
	emit_event(
		"session_start",
		{
			"seed": Config.RNG_SEED,
			"version": str(ProjectSettings.get_setting("application/config/version", "")),
			"commit": OS.get_environment("POSITIVEFPS_COMMIT"),
			"look": Looks.mode_name(),
			"targeting_mode": Config.TargetingMode.find_key(main.player.targeting_mode),
			"zoom": snappedf(main.camera.size, 0.01),
			"people": main.people.size(),
			"night_length": Config.NIGHT_LENGTH,
			"headless": _headless(),
		}
	)
	_flush()
	print("Recording to ", session_dir)
	return true


func _on_beacon_placed(pos: Vector3, cost: float, spirit_after: float) -> void:
	emit_event("beacon_placed", {"pos": _pos(pos), "cost": cost, "spirit_after": snappedf(spirit_after, 0.1)})


func _on_landmark(lm: Landmark, type: String) -> void:
	emit_event(type, {"name": lm.landmark_name(), "held": _main.landmarks.held_count()})


func _on_beacon_reached() -> void:
	emit_event("beacon_reached", {"pos": _pos(_main.border.centre)})


func is_open() -> bool:
	return _file != null


func _process(delta: float) -> void:
	if _file == null or ended_reason != "" or not _main.running:
		return
	t += delta
	# Per-frame work is one comparison; everything else waits for its timer.
	var target: Person = _main.player.target
	if target != _last_target:
		_last_target = target
		emit_event("target_change", _target_fields())
	_poll_timer += delta
	if _poll_timer >= Config.RECORD_POLL_SECONDS:
		_poll_timer = 0.0
		_poll_gaps()
		_poll_shields()
	_sample_timer += delta
	if _sample_timer >= Config.RECORD_SAMPLE_SECONDS:
		_sample_timer -= Config.RECORD_SAMPLE_SECONDS
		_sample()
	_shot_timer += delta
	if _shot_timer >= Config.RECORD_SHOT_SECONDS:
		_shot_timer = 0.0
		_screenshot()
	_flush_timer += delta
	if _flush_timer >= Config.RECORD_FLUSH_SECONDS:
		_flush_timer = 0.0
		_flush()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_exit_reason = "quit"
		end("quit")


func _exit_tree() -> void:
	end(_exit_reason)


# Marks why the level is being left (the restart and menu keys call this just before changing scene).
func note_exit(reason: String) -> void:
	_exit_reason = reason


# Writes session_end (once) and closes the file. `reason` is "win", "loss", "dawn", "restart", "menu", "quit" or "exit".
func end(reason: String) -> void:
	if _file == null or ended_reason != "":
		return
	_poll_gaps_close_all()
	ended_reason = reason
	var outcome := "quit"
	if reason in ["win", "loss", "dawn"]:
		outcome = reason
	emit_event(
		"session_end",
		{
			"reason": reason,
			"outcome": outcome,
			"rescued": _main.rescued_count,
			"duration": snappedf(t, 0.01),
			"shots": shots_taken,
		}
	)
	_flush()
	_file.close()
	_file = null
	if is_instance_valid(_main) and is_instance_valid(_main.hud):
		_main.hud.set_recording(false)


# The round ended in `title` (TopDownMain._end_round): the loss or win event, then session_end. Reaching dawn is the win
# (round 19) and carries the rating and its parts.
func on_round_end(title: String) -> void:
	if _file == null or ended_reason != "":
		return
	var fields := {"title": title, "rescued": _main.rescued_count}
	var kind := "loss"
	if not title.begins_with("The border fell"):
		kind = "win"
		var r: Dictionary = _main.rating if not _main.rating.is_empty() else _main._current_rating()
		var people_share: float = r["people"]
		var ground_share: float = r["ground"]
		fields["lights"] = r["lights"]
		fields["people_share"] = snappedf(people_share, 0.01)
		fields["ground_share"] = snappedf(ground_share, 0.01)
		fields["landmarks_held"] = r["landmarks"]
	emit_event(kind, fields)
	end(kind)


# Adds one line: t, night_phase and night are filled in; `fields` are the rest. Cheap: one JSON string into a buffer.
func emit_event(type: String, fields: Dictionary = {}) -> void:
	if _file == null:
		return
	var night := _main.night
	var line := {
		"t": snappedf(t, 0.01),
		"night_phase": phase_for(night.progress()),
		"night": snappedf(night.elapsed, 0.01),
		"type": type,
	}
	line.merge(fields)
	_buf.append(JSON.stringify(line))


func _flush() -> void:
	if _file == null or _buf.is_empty():
		return
	for line: String in _buf:
		_file.store_line(line)
	_buf.clear()
	_file.flush()


# ---- the sample ------------------------------------------------------------------------------------------------------


func _sample() -> void:
	var border := _main.border
	var counts := {"wistful": 0, "gloomy": 0, "dimmed": 0, "rescued": 0}
	var pressers := 0
	var sheltered := 0
	var guarded := 0
	for p: Person in _main.people:
		if p.is_rescued:
			counts["rescued"] += 1
			continue
		counts[STAGE_NAMES[clampi(p.level, 0, 2)]] += 1
		if p.sheltered:
			sheltered += 1
		if p.active_mood() == Person.Mood.GUARDED:
			guarded += 1
	var assignments := _main.pursuit_assignments(_main.people)
	for p: Person in assignments:
		var ward: Person = assignments[p]
		if _flat(p.global_position, ward.global_position) <= Config.RECORD_PRESS_RADIUS:
			pressers += 1
	var open_len := 0.0
	var sealed_len := 0.0
	var poly := border.polygon
	for j: int in range(poly.size()):
		var seg := poly[j].distance_to(poly[(j + 1) % poly.size()])
		if border.is_sealed(j):
			sealed_len += seg
		else:
			open_len += seg
	var ids: Array[int] = []
	ids.assign(_gap_id)
	var fields := {
		"border_open": snappedf(open_len, 0.1),
		"border_sealed": snappedf(sealed_len, 0.1),
		"members": border.members.size(),
		"gaps": ids.size(),
		"gap_regions": border.gap_region_count(),
		"gap_ids": ids,
		"stages": counts,
		"spirit": snappedf(_main.player.spirit, 0.1),
		"player_dim": _main.player.is_dim,
		"player_pos": _pos(_main.player.global_position),
		"joy_landed": _joy_landed,
		"pressers": pressers,
		"sheltered": sheltered,
		"guarded": guarded,
		"zoom": snappedf(_main.camera.size, 0.01),
	}
	fields.merge(_target_fields())
	_joy_landed = 0
	emit_event("sample", fields)


func _target_fields() -> Dictionary:
	var tgt: Person = _main.player.target
	if not is_instance_valid(tgt):
		return {"target": -1, "target_stage": ""}
	var stage := "rescued" if tgt.is_rescued else STAGE_NAMES[clampi(tgt.level, 0, 2)]
	return {"target": _id(tgt), "target_stage": stage}


# ---- polled events: gaps and umbrellas -------------------------------------------------------------------------------


# Matches this poll's gap middles to last poll's (nearest within GAP_TRACK_RADIUS) so a gap keeps its id while open.
func _poll_gaps() -> void:
	var mids := _main.border.gap_midpoints_cached()
	var taken: Dictionary = {}
	var new_pos: Array[Vector3] = []
	var new_id: Array[int] = []
	var new_opened: Array[float] = []
	for mid: Vector3 in mids:
		var best := -1
		var best_d := Config.GAP_TRACK_RADIUS
		for i: int in range(_gap_pos.size()):
			var d := _flat(mid, _gap_pos[i])
			if d < best_d and not taken.has(i):
				best_d = d
				best = i
		new_pos.append(mid)
		if best >= 0:
			taken[best] = true
			new_id.append(_gap_id[best])
			new_opened.append(_gap_opened[best])
		else:
			new_id.append(_next_gap_id)
			new_opened.append(t)
			emit_event("gap_open", {"gap": _next_gap_id, "pos": _pos(mid), "open_gaps": mids.size()})
			_next_gap_id += 1
	for i: int in range(_gap_pos.size()):
		if not taken.has(i):
			var dur := t - _gap_opened[i]
			emit_event("gap_close", {"gap": _gap_id[i], "duration": snappedf(dur, 0.01), "open_gaps": mids.size()})
	_gap_pos = new_pos
	_gap_id = new_id
	_gap_opened = new_opened


# The session is ending: gaps still open are closed with the duration so far (flagged as cut short by the end).
func _poll_gaps_close_all() -> void:
	for i: int in range(_gap_pos.size()):
		emit_event("gap_close", {"gap": _gap_id[i], "duration": snappedf(t - _gap_opened[i], 0.01), "ended": true})
	_gap_pos.clear()
	_gap_id.clear()
	_gap_opened.clear()


# An umbrella pops when a dimmed person's shield_down_left jumps up from (about) zero.
func _poll_shields() -> void:
	for i: int in range(_main.people.size()):
		var p: Person = _main.people[i]
		var now: float = p.shield_down_left
		if now > _shield_down[i] + 0.5 * Config.SHELTER_REGROW:
			emit_event("umbrella_pop", {"id": i, "pos": _pos(p.global_position)})
		_shield_down[i] = now


# ---- signal handlers ------------------------------------------------------------------------------------------------


func _on_stage_changed(from_level: int, to_level: int, p: Person) -> void:
	if p.is_rescued:
		return
	var kind := "sink" if to_level > from_level else "lift"
	emit_event(
		kind,
		{
			"id": _id(p),
			"from": STAGE_NAMES[clampi(from_level, 0, 2)],
			"to": STAGE_NAMES[clampi(to_level, 0, 2)],
			"pos": _pos(p.global_position),
		}
	)


func _on_rescued(p: Person) -> void:
	emit_event("rescue", {"id": _id(p), "total": _main.rescued_count, "pos": _pos(p.global_position)})


func _on_relapsed(p: Person) -> void:
	emit_event("relapse", {"id": _id(p), "pos": _pos(p.global_position)})


func _on_joy_landed() -> void:
	_joy_landed += 1


func _on_joy_blocked(reason: int, p: Person) -> void:
	var kind := "shelter_block" if reason == Person.Block.SHELTERED else "guarded_glance"
	emit_event(kind, {"id": _id(p)})


func _on_burst(at: Vector3) -> void:
	emit_event("burst", {"pos": _pos(at)})


func _on_player_dim(dim: bool) -> void:
	emit_event("player_dim", {"dim": dim, "spirit": snappedf(_main.player.spirit, 0.1)})


func _on_grab_landed(p: Person) -> void:
	emit_event("grab", {"id": _id(p), "spirit": snappedf(_main.player.spirit, 0.1)})


func _on_grab_avoided(p: Person) -> void:
	emit_event("grab_avoided", {"id": _id(p)})


# ---- files -----------------------------------------------------------------------------------------------------------


# Creates recordings/YYYYMMDD-HHMMSS/ (in the project folder when run from the editor, else user://recordings) and opens
# events.jsonl.
func _open_session() -> bool:
	var stamp := Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "-")
	for base: String in _base_dirs():
		var dir := base.path_join(stamp)
		var n := 2
		while DirAccess.dir_exists_absolute(dir):
			dir = base.path_join("%s-%d" % [stamp, n])
			n += 1
		if DirAccess.make_dir_recursive_absolute(dir) != OK:
			continue
		var file := FileAccess.open(dir.path_join("events.jsonl"), FileAccess.WRITE)
		if file == null:
			continue
		session_dir = dir
		events_path = dir.path_join("events.jsonl")
		_file = file
		return true
	return false


func _base_dirs() -> Array[String]:
	var out: Array[String] = []
	if base_dir_override != "":
		out.append(base_dir_override)
		return out
	if OS.has_feature("editor"):
		out.append(ProjectSettings.globalize_path("res://recordings"))
	out.append("user://recordings")
	return out


func _headless() -> bool:
	return DisplayServer.get_name() == "headless"


# Grabs the frame, downsizes it and saves it as shot_0001.png... on a worker thread (the grab itself is the only cost
# on the main thread). Skipped headless (there is no picture).
func _screenshot() -> void:
	if _headless():
		return
	_record_shot(get_viewport().get_texture().get_image())


# Logs and saves one grabbed frame (nothing happens for a missing or empty picture).
func _record_shot(img: Image) -> void:
	if img == null or img.is_empty():
		return
	shots_taken += 1
	var file_name := "shot_%04d.png" % shots_taken
	emit_event("screenshot", {"file": file_name})
	WorkerThreadPool.add_task(_save_shot.bind(img, session_dir.path_join(file_name)))


static func _save_shot(img: Image, path: String) -> void:
	if img.get_width() > Config.RECORD_SHOT_WIDTH:
		var h := roundi(float(img.get_height()) * Config.RECORD_SHOT_WIDTH / float(img.get_width()))
		img.resize(Config.RECORD_SHOT_WIDTH, h, Image.INTERPOLATE_BILINEAR)
	img.save_png(path)


# ---- small helpers ---------------------------------------------------------------------------------------------------


func _id(p: Person) -> int:
	return _ids.get(p, -1)


static func _pos(v: Vector3) -> Array[float]:
	return [snappedf(v.x, 0.1), snappedf(v.z, 0.1)]


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
