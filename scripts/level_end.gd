class_name LevelEnd
extends RefCounted

# How a level ends and is left: the end conditions (the border falling loses; dawn is a win rated in dawn lights), the
# end screen's rating and detail lines, and leaving for a restart or the menu. TopDownMain builds it as `level_end`.

var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


# The end conditions, in order: the border falling loses, and dawn ends the level (a win, rated in dawn lights).
func check() -> void:
	var main := _main
	if main.border.formed and main.rescued_count < BorderConfig.BORDER_MIN_PEOPLE:
		end_round("The border fell")
	elif main.night.is_over():
		main.rating = current_rating()
		var lights: int = main.rating["lights"]
		end_round("Dawn: %d of 3 dawn lights" % lights)


func end_round(title: String) -> void:
	var main := _main
	if not main.running:
		return
	main.running = false
	if main.recorder != null:
		main.recorder.on_round_end(title)
	main.player.active = false
	main.hud.set_night_progress(main.night.progress())
	main.hud.show_end(title, detail_text(), main.rating)


# What the rating would be right now (people rescued, ground held, landmarks held).
func current_rating() -> Dictionary:
	var main := _main
	return DawnRating.rate(
		main.rescued_count, Config.TD_PEOPLE_COUNT, main.ground.beautified_fraction(), main.landmarks.held_count()
	)


# The lines on the end screen (built by DawnRating.detail_text).
func detail_text() -> String:
	return DawnRating.detail_text(_main)


# Leaves the level for `scene_path` (empty = start this level again) after telling the recorder why. Tests set
# `scene_switch` to catch the request instead of changing scene.
func leave(reason: String, scene_path: String) -> void:
	note_exit(reason)
	if _main.scene_switch.is_valid():
		_main.scene_switch.call(scene_path)
	elif scene_path == "":
		_main.get_tree().reload_current_scene()
	else:
		_main.get_tree().change_scene_to_file(scene_path)


# Round 18: tells the recorder why the level is being left.
func note_exit(reason: String) -> void:
	if _main.recorder != null:
		_main.recorder.note_exit(reason)
