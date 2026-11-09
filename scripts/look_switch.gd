class_name LookSwitch
extends RefCounted

# F4: switches the level to `new_mode` (Looks.Mode) in place. Every object keeps its rules state and rebuilds its
# visuals. TopDownMain.set_look calls it.


static func apply(main: TopDownMain, new_mode: int) -> void:
	Looks.set_mode(new_mode)
	main.remove_child(main.plaza_look)
	main.plaza_look.queue_free()
	main.plaza.make_look()
	main.ground.rebuild_look()
	main.border.rebuild_look()
	for b: Building in main.border.buildings:
		b.rebuild_look()
	main.landmarks.rebuild_look()
	main.beacon_marker.rebuild_look()
	main.highlight.apply_look()
	main.player.rebuild_look()
	for p: Person in main.people:
		p.rebuild_look()
	main.minimap.rebuild_look()
	main.hud.rebuild_look()
	# Graphics checkpoint 2: the screen-space UI has a styled drawing too.
	main.feedback.rebuild_look()
	main.spirit_meter.rebuild_look()
	main.prompts.rebuild_look()
	main.arrows.rebuild_look()
	main.pipeline.apply(main)
	if main.level_hud.debug_on:
		main.level_hud.update_debug_hint()
