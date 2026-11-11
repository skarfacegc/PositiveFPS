class_name LevelHud
extends RefCounted

# Builds the level's screen-space layer and keeps it up to date: the HUD with the minimap, the landmark pointers and
# the gap arrows, the feedback layer, the spirit meter and the prompt bar, plus the F3 debug overlay. The nodes stay
# public on TopDownMain (`hud`, `minimap`, `arrows`, `feedback`, ...); TopDownMain builds this as `level_hud`.

const HINT_PLAY := (
	"WASD move | Shift run | Click to lock on | G/Q burst | hold E to take a block, F to plant a defence, "
	+ "release to do it | Right-click cancels"
)
const HINT := HINT_PLAY + " | R restart | M menu | [F4] look"

# The F3 debug overlay: cover and protection labels above each person, and the border labels. Off by default.
var debug_on: bool = false
var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


# The HUD, the minimap (top-left circle, a fifth of the screen width) and the off-screen gap arrows (round 10), then the
# communication overlays (round 13b: the feedback layer sits behind the HUD text).
func build() -> void:
	var main := _main
	main.hud = Hud.new()
	main.add_child(main.hud)
	var screen_w := main.get_viewport().get_visible_rect().size.x
	main.minimap = Minimap.new()
	main.minimap.size = Vector2.ONE * floorf(HudConfig.TD_MINIMAP_WIDTH_FRACTION * screen_w)
	main.minimap.position = Vector2(16, 16)
	main.hud.add_child(main.minimap)
	main.hud.place_rescued_below(main.minimap.position.y + main.minimap.size.y + HudConfig.RESCUED_BELOW_MINIMAP_GAP)
	main.landmark_pointers = LandmarkPointers.new()
	main.hud.add_child(main.landmark_pointers)
	main.landmark_pointers.setup(main.hud, main.minimap)
	main.arrows = GapArrows.new()
	main.hud.add_child(main.arrows)
	_build_feedback()


# Round 13b: builds the communication overlays on the HUD and connects the things they react to.
func _build_feedback() -> void:
	var main := _main
	main.feedback = FeedbackLayer.new()
	main.feedback.main = main
	main.hud.add_child(main.feedback)
	main.hud.move_child(main.feedback, 0)
	main.spirit_meter = SpiritMeter.new()
	main.hud.add_child(main.spirit_meter)
	main.prompts = PromptBar.new()
	main.prompts.intro = main.intro
	main.prompts.main = main
	main.hud.add_child(main.prompts)
	for p: Person in main.people:
		p.joy_blocked.connect(main.events.on_joy_blocked.bind(p))
		p.joy_landed.connect(main.events.on_joy_landed.bind(p))
		p.shield_popped.connect(main.feedback.on_shield_pop)


# After the systems that draw on the HUD exist: the hint line, the targeting mode and the starting numbers.
func start() -> void:
	var main := _main
	main.hud.set_hint(HINT)
	main.hud.set_targeting(main.player.targeting_mode)
	main.player.target_changed.connect(main.hud.set_target)
	main.player.debug_toggled.connect(toggle_debug)
	main.player.targeting_changed.connect(main.hud.set_targeting)
	main.hud.set_target(-1)
	main.hud.set_rescued(main.rescued_count, Config.TD_PEOPLE_COUNT)
	main.hud.set_night_progress(0.0)
	update_spirit_hud()


# Each frame: the off-screen gap arrows. The minimap picture is refreshed about 10 times a second (see Minimap.tick).
func update_readability(delta: float) -> void:
	var main := _main
	var screen := main.get_viewport().get_visible_rect()
	if main.minimap.tick(delta):
		main.minimap.held_landmarks = main.landmarks.held_flags()
		main.minimap.take_marks = main.take_block.mark_rects()
		main.minimap.refresh_from(
			main.ground,
			main.border,
			main.people,
			main.player.global_position,
			main.camera_rig.view_centre(),
			main.camera_rig.view_half_extents()
		)
	# Grid fixes (#56): a gate bent past half the break depth gets a pointer too, after the breaks.
	var points: Array[Vector3] = main.border.gap_midpoints_cached().duplicate()
	var urgencies: Array[float] = main.border.gap_urgencies().duplicate()
	var pressed := GateMarks.pointers(main.border)
	var more_points: Array[Vector3] = pressed["points"]
	var more_urgencies: Array[float] = pressed["urgencies"]
	points.append_array(more_points)
	urgencies.append_array(more_urgencies)
	main.arrows.update_arrows(
		main.camera,
		screen,
		points,
		main.minimap.get_global_rect(),
		main.border.pulse(),
		main.pipeline.view_scale(),
		urgencies,
		delta,
		HudSafeArea.current(main, screen.size)  # Checkpoint 6: the arrows keep clear of the HUD.
	)
	main.landmark_pointers.update_from(main, delta)  # Round 22 edge pointers (throttled, round 23).


# The landmark panel: which are held and what they give.
func update_landmarks() -> void:
	var landmarks := _main.landmarks
	_main.hud.set_landmarks(landmarks.held_lines(), LandmarkConfig.LANDMARK_NAMES.size(), landmarks.held_flags())


func update_spirit_hud() -> void:
	var main := _main
	main.hud.set_spirit(main.player.spirit, main.player.is_dim)
	main.hud.set_burst(main.player.burst_cooldown, main.player.has_burst_spirit(), main.burst_cue.burst_targets)
	main.spirit_meter.set_values(main.player.spirit, main.player.is_dim)
	var people := main.defences.people_numbers()  # Walls and gates: Capture polish (#75).
	var short: int = people["short"]
	main.hud.set_people(Defences.people_text(people), short > 0)


# Round 12b: the target's mood next to its element on the HUD ("Target: Music (guarded)").
func update_target_mood() -> void:
	var t: Person = _main.player.target
	var mood_text := ""
	if is_instance_valid(t):
		mood_text = Person.mood_name(t.active_mood())
	_main.hud.set_target_mood(mood_text)


# Every frame, also after the round ends: the overlays advance and redraw.
func update_feedback(delta: float) -> void:
	var main := _main
	main.feedback.tick(delta)
	main.spirit_meter.tick(delta)
	if main.intro.enabled:
		main.intro.update(delta)
		main.prompts.tick(main.get_viewport().get_visible_rect())


# F3: flips the debug overlay. The player reads the key and emits debug_toggled.
func toggle_debug() -> void:
	set_debug(not debug_on)


# Turns the F3 debug overlay on or off: cover and protection labels above each person, border labels on the line,
# and a hint on the HUD.
func set_debug(on: bool) -> void:
	debug_on = on
	for p: Person in _main.people:
		p.set_debug_visible(on)
	_main.border.set_debug(on)
	_main.hud.set_debug_on(on)
	update_debug_hint()


func update_debug_hint() -> void:
	_main.hud.set_floor_text(FloorEffects.summary(_main.get_tree()) + "\n" + Looks.debug_line())
	_main.hud.set_debug_text("[F3] debug: c = cover, p = protection.  " + _main.border.debug_summary())
