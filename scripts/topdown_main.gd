class_name TopDownMain
extends Node3D

# The territory level (round 9): a bigger plaza seen from above. Rescued people form a living border around a centre
# (see border.gd). Gloom cannot cross an intact stretch of it. Inside the border the ground and the blocks are
# beautified. The light goes from dusk to dawn (night.gd); the level ends at dawn (a win, rated in dawn lights, see
# dawn_rating.gd) or earlier when the border falls (lose). Round 19: three landmarks give boosts while held
# (landmarks.gd).
#
# Reorg (0.4 pass 1): this script only COORDINATES. `_ready` builds the systems in order and `_process` calls them in
# order; each system's set-up and per-frame work lives in its own script (Plaza, CameraRig, TargetHighlight, LevelHud,
# LevelEvents, DimGate, CoverUpdate, DimRecovery, LevelEnd, LookSwitch and the systems below). New features attach with
# `X.attach(main)` and are called from here by name; they should not add logic to this file.

var ground: PaintedGround
var player: TopDownPlayer
var camera: Camera3D
var hud: Hud
# Round 10: the minimap (a circle, top-left) and the off-screen gap arrows (see minimap.gd and gap_arrows.gd).
var minimap: Minimap
var arrows: GapArrows
var landmark_pointers: LandmarkPointers  # Round 22: the edge pointers toward unheld landmarks (placeholder look).
var border: Border
var burst_cue: BurstCue  # Round 22 (round 26: no patches): the burst cue and marks.
var gate_marks: GateMarks  # Grid fixes: the people count and the push glow on each gate (#56).
var take_block: TakeBlock  # Walls and gates: hold E to take a block (#10); the rescue pips (#11) are drawn here too.
var defences: Defences  # Walls and gates: hold F to plant a defence at a gate (#15, #16); the people numbers (#75).
var first_light: FirstLight  # Round 24: the dawn front of the last 45 s.
var wobble_alert: WobbleAlert  # Checkpoint 5: the edge pointers toward off-screen wobblers.
var spirit_warmth: SpiritWarmth  # Checkpoint 5: spare spirit warms the border.
var gloom_tide: GloomTide  # The night's one surge (warning, fog down one street, push on the gate it meets).
var landmarks: Landmarks  # Round 19: the three landmarks and their boosts.
var rating: Dictionary = {}  # Round 19: the dawn rating, set when the night ends (see DawnRating).
# Round 12a: the grabs of dimmed people (see grabs.gd).
var grabs: Grabs
# Round 12b: the moods of wistful and gloomy people and the sheltering of dimmed people (see moods.gd).
var moods: Moods
var night: NightCycle
# Round 13b: communication. The layer of screen-space markers, icons and effects, the spirit meter (bottom centre), the
# one-time prompt bar and the layered introduction through the night (see intro.gd).
var feedback: FeedbackLayer
var spirit_meter: SpiritMeter
var prompts: PromptBar
var intro: Intro
# The looks that are not owned by one object: the floor and walls, and the camera / post-process pipeline (see
# scripts/looks). F4 flips the look in place with toggle_look().
var plaza_look: PlazaLook
var pipeline: ViewPipeline
var style_props: StyleProps
var style_ambient: StyleAmbient
# The ring under the target's feet (see TargetHighlight). Public so tests can check it.
var highlight: TargetHighlight
var people: Array[Person] = []
var rescued_count: int = 0
var running: bool = true
# Round 18: the gameplay recorder, or null when recording is off.
var recorder: Recorder
# Tests only: when valid, called with the scene path (empty = restart) instead of changing scene.
var scene_switch: Callable
# The level's own helpers (each one's script says what it does).
var plaza := Plaza.new(self)  # Floor, walls, blocks, spawn spots and the level's random numbers.
var camera_rig := CameraRig.new(self)  # Environment, sun, camera and wheel zoom.
var events := LevelEvents.new(self)  # What happens when someone is rescued, joy lands, the burst fires ...
var level_hud := LevelHud.new(self)  # Builds and updates the HUD layer; the F3 debug overlay.
var level_end := LevelEnd.new(self)  # Win and lose, the rating, leaving the level.
var dim_gate := DimGate.new(self)  # The midnight stagger of people sinking to dimmed.
var cover_update := CoverUpdate.new(self)  # Every person's cover and protection.
var dim_recovery := DimRecovery.new(self)  # The dim player's spirit recovery.
var relapse_wave := RelapseWave.new()  # Round 24: lets one wobbling person relapse at a time.
var _crowd := CrowdMovement.new(self)  # Round 24: wander, pursuit and separation of the unrescued people.
# The frame F4 last flipped the look (the key press can arrive twice in one frame, see Known gotchas).
var _look_frame: int = -1


func _ready() -> void:
	Looks.apply_start_mode()
	Controls.setup()
	night = NightCycle.new()
	intro = Intro.new(night, Config.intro_on())
	pipeline = ViewPipeline.new()
	add_child(pipeline)
	camera_rig.setup_environment()
	plaza.build()

	ground = PaintedGround.new()
	add_child(ground)
	ground.setup(Config.TD_PLAZA_SIZE, GroundConfig.TD_GROUND_SPREAD_SPEED, GroundConfig.TD_GROUND_FADE_SPEED, true)

	border = Border.new()
	add_child(border)
	border.setup(ground)
	plaza.register_buildings(border)

	landmarks = Landmarks.new()
	add_child(landmarks)
	landmarks.build()
	events.wire_landmarks(landmarks)

	grabs = Grabs.new()
	add_child(grabs)
	moods = Moods.new()
	add_child(moods)

	player = TopDownPlayer.new()
	add_child(player)
	player.burst_fired.connect(events.on_burst_fired)
	player.dim_changed.connect(events.on_player_dim_changed)
	grabs.grab_landed.connect(events.on_grab_landed)

	camera_rig.build()
	player.camera = camera

	plaza.spawn_people()
	Moods.assign(people, Config.RNG_SEED + 3)
	player.people = people
	highlight = TargetHighlight.attach(self)

	level_hud.build()
	burst_cue = BurstCue.attach(self)
	take_block = TakeBlock.attach(self)
	gate_marks = GateMarks.attach(self)
	defences = Defences.attach(self)
	first_light = FirstLight.attach(self)
	wobble_alert = WobbleAlert.attach(self)
	spirit_warmth = SpiritWarmth.attach(self)
	gloom_tide = GloomTide.attach(self)
	style_props = StyleProps.attach(self)  # Checkpoint 7: street props (styled look only).
	style_ambient = StyleAmbient.attach(self)  # Checkpoint 7: butterflies, birds, idling people (styled look only).
	level_hud.start()
	pipeline.apply(self)
	recorder = Recorder.start(self)


func _process(delta: float) -> void:
	camera_rig.update(delta)
	highlight.sync(delta)
	level_hud.update_readability(delta)
	if not running:
		level_hud.update_feedback(delta)
		return
	night.update(delta)
	var strength := night.strength()
	hud.set_night_progress(night.progress())
	camera_rig.update_light()
	Moods.unlock_for_intro(people, intro)
	border.update(people, delta, strength)
	_crowd.update_people(delta)
	moods.update(people, player, delta)
	cover_update.update(delta)
	dim_recovery.update(delta)
	GloomSim.update(people, delta, PeopleConfig.TD_DRAIN_MULTIPLIER * border.loss_mult, strength, border)
	dim_gate.hold_back(delta)
	relapse_wave.advance(delta)
	grabs.update(people, player, delta)
	for p: Person in people:
		p.tick(delta)
	ground.update_paint(people, delta)
	landmarks.update(delta, border)
	landmarks.apply_boosts(people, border)
	level_hud.update_landmarks()
	level_hud.update_spirit_hud()
	intro.check_level(self, delta)
	level_hud.update_feedback(delta)
	if level_hud.debug_on:
		level_hud.update_debug_hint()
	level_end.check()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		level_end.leave("restart", "")
	elif event.is_action_pressed("menu"):
		level_end.leave("menu", "res://menu.tscn")
	elif event.is_action_pressed("toggle_look"):
		var frame := Engine.get_process_frames()
		if frame != _look_frame:
			_look_frame = frame
			toggle_look()
	elif event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out"):
		camera_rig.handle_zoom(event)


# F4: flips between the placeholder and the styled look without touching the game state.
func toggle_look() -> void:
	set_look(Looks.toggle())


# Switches to `new_mode` (Looks.Mode) in place: every object keeps its rules state and rebuilds its visuals.
func set_look(new_mode: int) -> void:
	LookSwitch.apply(self, new_mode)


# The screen (window) position of a world point, whatever size the look draws the 3D view at.
func world_to_screen(world: Vector3) -> Vector2:
	return camera.unproject_position(world) * pipeline.view_scale()


func sun_light() -> DirectionalLight3D:
	return camera_rig.sun


func environment() -> Environment:
	return camera_rig.env


func view_half_extents() -> Vector2:
	return camera_rig.view_half_extents()


# Round 24: the crowd's movement lives in CrowdMovement; these two stay here because tests and the recorder call them.
func pursuit_assignments(list: Array[Person]) -> Dictionary:
	return _crowd.pursuit_assignments(list)


func _new_wander_target(from: Vector3) -> Vector3:
	return _crowd.new_wander_target(from)
