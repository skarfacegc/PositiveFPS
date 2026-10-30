class_name TopDownMain
extends Node3D

# The territory level (round 9): a bigger plaza seen from above. Rescued people form a living border around a centre
# (see border.gd). Gloom cannot cross an intact stretch of it. Inside the border the ground and the blocks are
# beautified. The light goes from dusk to dawn (night.gd); the level ends at dawn (a win, rated in dawn lights, see
# dawn_rating.gd) or earlier when the border falls (lose). Round 19: three landmarks give boosts while held
# (landmarks.gd).

# Round 19: a spirit beacon was placed (where, its cost, and the spirit left).
signal beacon_placed(pos: Vector3, cost: float, spirit_after: float)

# Obstacle blocks are 4 x 2 x 4. Their centres are fixed (round 13a: the round 12 spots times Config.WORLD_SCALE,
# within +-36), and the middle stays clear.
const BLOCK_SIZE := Vector3(4, 2, 4)
const BLOCK_POSITIONS: Array[Vector3] = [
	Vector3(-20, 0, -18) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(-6, 0, -22) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(12, 0, -20) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(22, 0, -12) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(-22, 0, -2) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(20, 0, 4) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(-14, 0, 12) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(4, 0, 14) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(18, 0, 20) * Config.WORLD_SCALE + Vector3(0, 1, 0),
	Vector3(-6, 0, 24) * Config.WORLD_SCALE + Vector3(0, 1, 0),
]
const BLOCK_COLOUR := Color(0.6, 0.6, 0.62)
const HINT_PLAY := "WASD move | Shift run | Click to lock on | G/Q burst | E beacon"
const HINT := HINT_PLAY + " | R restart | M menu | [F4] look"

var ground: PaintedGround
var player: TopDownPlayer
var camera: Camera3D
var hud: Hud
# Round 10: the minimap (a circle, top-left) and the off-screen gap arrows (see minimap.gd and gap_arrows.gd).
var minimap: Minimap
var arrows: GapArrows
var border: Border
var beacon_marker: BeaconMarker  # Round 19: the beacon in the world (both looks).
var reach_guide: ReachGuide  # Round 20: the placeholder look's reach ring, preview and tip travel.
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
# The ring under the target's feet (see _update_highlight). Public so tests can check it.
var highlight: MeshInstance3D
var people: Array[Person] = []
var rescued_count: int = 0
var running: bool = true
# Round 18: the gameplay recorder, or null when recording is off.
var recorder: Recorder
# Tests only: when valid, called with the scene path (empty = restart) instead of changing scene.
var scene_switch: Callable
# The F3 debug overlay: cover and protection labels above each person, and the border labels. Off by default.
var debug_on: bool = false
var _sun: DirectionalLight3D
var _env: Environment
var _obstacles: Array[StaticBody3D] = []
var _landmark_bodies: Array[StaticBody3D] = []
var _rng := RandomNumberGenerator.new()
# Wander state for each person: a Dictionary of {"target": Vector3, "timer": float}.
var _wander: Dictionary = {}
var _highlight_mat: StandardMaterial3D
var _pulse_time := 0.0
# Seconds since the cover (see _update_cover) was last worked out. It is refreshed every GROUND_UPDATE_INTERVAL.
var _cover_timer := 0.0
# The frame F4 last flipped the look (the key press can arrive twice in one frame, see Known gotchas).
var _look_frame: int = -1
# Seconds since the intro last checked for its one-time prompts.
# Round 14: the wheel zoom. The ortho size the camera is easing toward, and the frame the last zoom step was taken (the
# key press can arrive twice in one frame, see Known gotchas).
var _zoom_target: float = Config.TD_CAMERA_ORTHO_SIZE
var _zoom_frame: int = -1
var _beacon_frame: int = -1
# The ortho size the label scales were last set for (they are only rewritten when the zoom moves).
var _scaled_for_size: float = -1.0
# Round 14: game time that passed in the night (the clock for the staggered arrivals) and the clock value when a person
# last sank to dimmed (-INF before anyone did).
var _dim_clock: float = 0.0
var _last_dim_sink: float = -INF


func _ready() -> void:
	Controls.setup()
	night = NightCycle.new()
	intro = Intro.new(night, Config.intro_on())
	pipeline = ViewPipeline.new()
	add_child(pipeline)
	_setup_environment()
	_build_level()

	ground = PaintedGround.new()
	add_child(ground)
	ground.setup(Config.TD_PLAZA_SIZE, Config.TD_GROUND_SPREAD_SPEED, Config.TD_GROUND_FADE_SPEED, true)

	border = Border.new()
	add_child(border)
	border.setup(ground)
	for body: StaticBody3D in _obstacles:
		var lm_index := _landmark_bodies.find(body)
		var is_landmark := lm_index >= 0
		var size := Config.LANDMARK_SIZES[lm_index] if is_landmark else BLOCK_SIZE
		var colour := Config.LANDMARK_COLOURS[lm_index] if is_landmark else BLOCK_COLOUR
		border.register_building(body, Vector2(BLOCK_SIZE.x, BLOCK_SIZE.z) * 0.5, is_landmark, size, colour)

	landmarks = Landmarks.new()
	add_child(landmarks)
	landmarks.build()
	for lm: Landmark in landmarks.items:  # Round 20: a claim or a loss is announced on the HUD.
		lm.claimed.connect(_on_landmark_claimed.bind(lm))
		lm.lost.connect(_on_landmark_lost.bind(lm))
	beacon_marker = BeaconMarker.new()
	add_child(beacon_marker)
	reach_guide = ReachGuide.new()
	add_child(reach_guide)

	grabs = Grabs.new()
	add_child(grabs)
	moods = Moods.new()
	add_child(moods)

	player = TopDownPlayer.new()
	add_child(player)
	player.burst_fired.connect(border.shove)
	player.burst_fired.connect(_on_burst_fired)
	player.dim_changed.connect(_on_player_dim_changed)
	grabs.grab_landed.connect(_on_grab_landed)

	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = Config.TD_CAMERA_ORTHO_SIZE
	camera.current = true
	add_child(camera)
	player.camera = camera

	_spawn_people()
	Moods.assign(people, Config.RNG_SEED + 3)
	player.people = people
	_build_highlight()

	hud = Hud.new()
	add_child(hud)
	# Round 10: the minimap (top-left circle, a fifth of the screen width) and the off-screen gap arrows, both on the HUD.
	var screen_w := get_viewport().get_visible_rect().size.x
	minimap = Minimap.new()
	minimap.size = Vector2.ONE * floorf(Config.TD_MINIMAP_WIDTH_FRACTION * screen_w)
	minimap.position = Vector2(16, 16)
	hud.add_child(minimap)
	hud.place_rescued_below(minimap.position.y + minimap.size.y + Config.RESCUED_BELOW_MINIMAP_GAP)
	arrows = GapArrows.new()
	hud.add_child(arrows)
	_build_feedback()
	hud.set_hint(HINT)
	hud.set_targeting(player.targeting_mode)
	player.target_changed.connect(hud.set_target)
	player.debug_toggled.connect(_toggle_debug)
	player.targeting_changed.connect(hud.set_targeting)
	hud.set_target(-1)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	hud.set_night_progress(0.0)
	_update_spirit_hud()
	_note_shared_placeholders()
	pipeline.apply(self)
	if Recorder.requested():
		recorder = Recorder.new()
		add_child(recorder)
		if not recorder.attach(self):
			recorder.queue_free()
			recorder = null


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_highlight(delta)
	_update_readability(delta)
	if not running:
		_update_feedback(delta)
		return
	night.update(delta)
	var strength := night.strength()
	hud.set_night_progress(night.progress())
	_update_light()
	_unlock_moods()
	border.update(people, delta, strength)
	_update_people(delta)
	moods.update(people, player, delta)
	_update_cover(delta)
	_update_dim(delta)
	GloomSim.update(people, delta, Config.TD_DRAIN_MULTIPLIER * border.loss_mult, strength, border)
	_hold_back_dimmed(delta)
	grabs.update(people, player, delta)
	for p: Person in people:
		p.tick(delta)
	ground.update_paint(people, delta)
	landmarks.update(delta, border)
	landmarks.apply_boosts(people, border)
	hud.set_landmarks(landmarks.held_lines(), Config.LANDMARK_NAMES.size(), landmarks.held_flags())
	beacon_marker.sync(border.beacon_pos(), delta, border.centre)
	reach_guide.sync(border, player)
	_update_spirit_hud()
	_update_target_mood()
	intro.check_level(self, delta)
	_update_feedback(delta)
	if debug_on:
		_update_debug_hint()
	_check_end()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_leave_level("restart", "")
	elif event.is_action_pressed("menu"):
		_leave_level("menu", "res://menu.tscn")
	elif event.is_action_pressed("toggle_look"):
		var frame := Engine.get_process_frames()
		if frame != _look_frame:
			_look_frame = frame
			toggle_look()
	elif event.is_action_pressed("place_beacon"):
		# gdUnit delivers a key press twice: one beacon per frame.
		var beacon_frame := Engine.get_process_frames()
		if beacon_frame != _beacon_frame:
			_beacon_frame = beacon_frame
			try_place_beacon()
	elif event.is_action_pressed("zoom_in") or event.is_action_pressed("zoom_out"):
		# Round 14: one wheel notch per frame (a repeated delivery in the same frame counts once).
		var frame := Engine.get_process_frames()
		if frame != _zoom_frame:
			_zoom_frame = frame
			var step := -Config.TD_ZOOM_STEP if event.is_action_pressed("zoom_in") else Config.TD_ZOOM_STEP
			_zoom_target = clampf(_zoom_target + step, Config.TD_ZOOM_MIN, Config.TD_ZOOM_MAX)


# Round 19: E. Puts the spirit beacon at the cursor's ground point for BEACON_SPIRIT_COST spirit (the zone then
# stretches toward it, round 20). Refused (nothing changes, a short notice shows) without a border or
# without enough spirit. A new beacon replaces the old one and costs again. Returns true when it was placed.
func try_place_beacon() -> bool:
	if not running or not player.has_aim():
		return false
	if not border.formed:
		intro.notice(Intro.Prompt.BEACON_BORDER)
		return false
	if player.is_dim or player.spirit < Config.BEACON_SPIRIT_COST:
		intro.notice(Intro.Prompt.BEACON_SPIRIT)
		return false
	player.lose_spirit(Config.BEACON_SPIRIT_COST)
	border.place_beacon(player.aim_point())
	spirit_meter.moment(-Config.BEACON_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	feedback.pulse_player(SpiritMeter.Moment.SPEND)
	beacon_placed.emit(border.beacon_pos(), Config.BEACON_SPIRIT_COST, player.spirit)
	return true


# Leaves the level for `scene_path` (empty = start this level again) after telling the recorder why. Tests set
# `scene_switch` to catch the request instead of changing scene.
func _leave_level(reason: String, scene_path: String) -> void:
	_note_exit(reason)
	if scene_switch.is_valid():
		scene_switch.call(scene_path)
	elif scene_path == "":
		get_tree().reload_current_scene()
	else:
		get_tree().change_scene_to_file(scene_path)


# Round 18: tells the recorder why the level is being left.
func _note_exit(reason: String) -> void:
	if recorder != null:
		recorder.note_exit(reason)


# F4: flips between the placeholder and the styled look without touching the game state.
func toggle_look() -> void:
	set_look(Looks.toggle())


# Switches to `new_mode` (Looks.Mode) in place: every object keeps its rules state and rebuilds its visuals.
func set_look(new_mode: int) -> void:
	Looks.set_mode(new_mode)
	remove_child(plaza_look)
	plaza_look.queue_free()
	_make_plaza_look()
	ground.rebuild_look()
	border.rebuild_look()
	for b: Building in border.buildings:
		b.rebuild_look()
	landmarks.rebuild_look()
	beacon_marker.rebuild_look()
	player.rebuild_look()
	for p: Person in people:
		p.rebuild_look()
	minimap.rebuild_look()
	hud.rebuild_look()
	# Graphics checkpoint 2: the screen-space UI has a styled drawing too.
	feedback.rebuild_look()
	spirit_meter.rebuild_look()
	prompts.rebuild_look()
	arrows.rebuild_look()
	pipeline.apply(self)
	if debug_on:
		_update_debug_hint()


# The screen (window) position of a world point, whatever size the look draws the 3D view at.
func world_to_screen(world: Vector3) -> Vector2:
	return camera.unproject_position(world) * pipeline.view_scale()


func sun_light() -> DirectionalLight3D:
	return _sun


func environment() -> Environment:
	return _env


# Objects the styled look does not redraw yet (they stay placeholder; see Looks.note_placeholder).
func _note_shared_placeholders() -> void:
	Looks.note_placeholder(highlight, "target highlight")
	Looks.note_placeholder(hud, "hud text")


# F3: flips the debug overlay. The player reads the key and emits debug_toggled.
func _toggle_debug() -> void:
	_set_debug(not debug_on)


# Turns the F3 debug overlay on or off: cover and protection labels above each person, border labels on the line,
# and a hint on the HUD.
func _set_debug(on: bool) -> void:
	debug_on = on
	for p: Person in people:
		p.set_debug_visible(on)
	border.set_debug(on)
	hud.set_debug_on(on)
	_update_debug_hint()


func _update_debug_hint() -> void:
	hud.set_floor_text(FloorEffects.summary(get_tree()) + "\n" + Looks.debug_line())
	hud.set_debug_text("[F3] debug: c = cover, p = protection.  " + border.debug_summary())


# Works out every person's cover and protection every GROUND_UPDATE_INTERVAL. With a border, cover is how far inside
# the loop a person is (see Border.cover_at). Before the border forms it is the paint around them (round 8 rules): a
# rescued person's cover leaves out their own paint, so only other people's paint protects them.
func _update_cover(delta: float) -> void:
	_cover_timer += delta
	if _cover_timer < Config.GROUND_UPDATE_INTERVAL:
		return
	_cover_timer = 0.0
	for p: Person in people:
		if border.active:
			p.cover = border.cover_at(p.global_position)
			p.protection = p.cover
		elif p.is_rescued:
			p.cover = ground.average_weight_excluding(p.global_position, Config.TD_COVER_RADIUS, p)
			p.protection = GloomSim.protection_for(p.cover)
		else:
			p.cover = ground.average_weight(p.global_position, Config.TD_COVER_RADIUS)
			p.protection = GloomSim.protection_for(p.cover)


# Round 12a: a dim player recovers spirit only inside the border (or near a landmark before a border exists), and a
# dim player makes the border and the paint lose ground faster.
func _update_dim(delta: float) -> void:
	border.set_player_dim(player.is_dim)
	ground.loss_mult = border.loss_mult
	if player.is_dim:
		player.add_spirit(dim_recovery_rate() * delta)


# Spirit per second the dim player recovers where they stand: DIM_RECOVER_RATE times (DIM_RECOVER_BASE plus
# DIM_RECOVER_DEPTH times the depth protection) inside the border, nothing outside it. Before any border exists, the
# full rate within LANDMARK_RECOVER_RADIUS of any landmark.
func dim_recovery_rate() -> float:
	var pos := player.global_position
	if border.active:
		if not Border.is_inside(border.polygon, Vector2(pos.x, pos.z)):
			return 0.0
		var depth := border.cover_at(pos)
		return Config.DIM_RECOVER_RATE * (Config.DIM_RECOVER_BASE + Config.DIM_RECOVER_DEPTH * depth)
	if Landmarks.near_any(pos, Config.LANDMARK_RECOVER_RADIUS):
		return Config.DIM_RECOVER_RATE
	return 0.0


# Round 12b: the target's mood next to its element on the HUD ("Target: Music (guarded)").
func _update_target_mood() -> void:
	var t: Person = player.target
	var mood_text := ""
	if is_instance_valid(t):
		mood_text = Person.mood_name(t.active_mood())
	hud.set_target_mood(mood_text)


func _update_spirit_hud() -> void:
	hud.set_spirit(player.spirit, player.is_dim)
	hud.set_burst(player.burst_cooldown, player.has_burst_spirit())
	spirit_meter.set_values(player.spirit, player.is_dim)


# Round 13b: builds the communication overlays on the HUD (the feedback layer sits behind the HUD text) and connects the
# things they react to.
func _build_feedback() -> void:
	feedback = FeedbackLayer.new()
	feedback.main = self
	hud.add_child(feedback)
	hud.move_child(feedback, 0)
	spirit_meter = SpiritMeter.new()
	hud.add_child(spirit_meter)
	prompts = PromptBar.new()
	prompts.intro = intro
	prompts.main = self
	hud.add_child(prompts)
	for p: Person in people:
		p.joy_blocked.connect(_on_joy_blocked.bind(p))
		p.joy_landed.connect(_on_joy_landed.bind(p))
		p.shield_popped.connect(feedback.on_shield_pop)


# Every frame, also after the round ends: the overlays advance and redraw.
func _update_feedback(delta: float) -> void:
	feedback.tick(delta)
	spirit_meter.tick(delta)
	if intro.enabled:
		intro.update(delta)
		prompts.tick(get_viewport().get_visible_rect())


func _on_joy_blocked(reason: int, p: Person) -> void:
	feedback.on_blocked(p, reason)
	if reason == Person.Block.SHELTERED:
		intro.request(Intro.Prompt.SHELTERED)
	elif p.active_mood() == Person.Mood.GUARDED:
		intro.request(Intro.Prompt.GUARDED)


# Round 14: joy landed on a dimmed person: their progress ring shows, and the one-time dimmed prompt.
func _on_joy_landed(p: Person) -> void:
	if not GloomSim.is_dimmed(p):
		return
	feedback.on_dim_joy(p)
	intro.request(Intro.Prompt.DIM_HELP)


func _on_burst_fired(_at: Vector3) -> void:
	spirit_meter.moment(-Config.BURST_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	feedback.pulse_player(SpiritMeter.Moment.SPEND)


# Round 13b, the layered introduction: a mood is dormant until its fraction of the night (the people keep their mood but
# it does nothing and shows nothing).
func _unlock_moods() -> void:
	if not intro.enabled:
		return
	for p: Person in people:
		p.mood_unlocked = intro.mood_active(p.mood)


# Round 13b: nobody sinks to dimmed during the calm opening (they wait as gloomy: the cap holds them under the gloomy
# band's top). Round 14, the midnight surge is staggered by _try_dim_sink (asked from Person._check_level). Runs after
# GloomSim.update.
func _hold_back_dimmed(delta: float) -> void:
	_dim_clock += delta
	if not intro.dimmed_allowed():
		for p: Person in people:
			if not p.is_rescued and p.gloom > Config.INTRO_DIM_CAP:
				p.gloom = Config.INTRO_DIM_CAP


# Round 14, the midnight stagger: asked by a person who would sink to dimmed (Person._check_level), in the order the
# people tick. Yes only once dimmed people may emerge (after the calm opening) and DIM_ARRIVAL_MIN_GAP seconds
# have passed since the last one sank. The first to ask in a frame takes the gate, so array order decides who goes.
func _try_dim_sink() -> bool:
	# (Nobody gets this far during the calm opening: _hold_back_dimmed keeps them under the line until then.)
	if _dim_clock - _last_dim_sink < Config.DIM_ARRIVAL_MIN_GAP:
		return false
	_last_dim_sink = _dim_clock
	return true


func _on_player_dim_changed(dim: bool) -> void:
	if dim:
		hud.show_alert("You went dim! Get inside the border to recover")
	else:
		hud.show_alert("Your spirit is back")


func _on_grab_landed(_p: Person) -> void:
	hud.show_alert("Grabbed! -%d spirit" % roundi(Config.GRAB_SPIRIT_DRAIN))
	spirit_meter.moment(-Config.GRAB_SPIRIT_DRAIN, SpiritMeter.Moment.LOSS)
	feedback.pulse_player(SpiritMeter.Moment.LOSS)


# The camera follows the player from above and behind, looking at a point just north of them (round 10: orthographic, at
# TD_CAMERA_PITCH_DEG degrees, so the player sits a little below the centre of the screen). Round 14: the ortho size
# eases toward the wheel's target, and the labels and the look offset scale with it (so they look the same on screen).
func _update_camera(delta: float) -> void:
	var size := lerpf(camera.size, _zoom_target, 1.0 - exp(-Config.TD_ZOOM_EASE * delta))
	if size != camera.size:
		camera.size = size
	if camera.size != _scaled_for_size:
		_scaled_for_size = camera.size
		var zoom := camera.size / Config.TD_CAMERA_ORTHO_SIZE
		for p: Person in people:
			p.set_ui_scale(Config.TD_UI_SCALE * zoom)
	var target := _view_centre()
	var pitch := deg_to_rad(Config.TD_CAMERA_PITCH_DEG)
	var d := Config.TD_CAMERA_DISTANCE
	camera.global_position = target + Vector3(0, d * sin(pitch), d * cos(pitch))
	camera.look_at(target, Vector3.UP)


# The point the camera looks at: the player plus TD_CAMERA_LOOK_OFFSET, scaled with the zoom (the player keeps the same
# place on screen at every zoom).
func _view_centre() -> Vector3:
	return player.global_position + Config.TD_CAMERA_LOOK_OFFSET * (camera.size / Config.TD_CAMERA_ORTHO_SIZE)


# The half size of the camera's view on the ground, in metres: x across the screen, z along the ground (the view is
# tilted, so the depth is stretched by 1 / sin(pitch)).
func view_half_extents() -> Vector2:
	var screen := get_viewport().get_visible_rect().size
	var aspect := screen.x / screen.y
	var pitch := deg_to_rad(Config.TD_CAMERA_PITCH_DEG)
	return Vector2(camera.size * aspect * 0.5, camera.size * 0.5 / sin(pitch))


# Each frame: the off-screen gap arrows. The minimap picture is refreshed about 10 times a second (see Minimap.tick).
func _update_readability(delta: float) -> void:
	var screen := get_viewport().get_visible_rect()
	if minimap.tick(delta):
		minimap.held_landmarks = landmarks.held_flags()
		minimap.refresh_from(ground, border, people, player.global_position, _view_centre(), view_half_extents())
	arrows.update_arrows(
		camera,
		screen,
		border.gap_midpoints_cached(),
		minimap.get_global_rect(),
		border.pulse(),
		pipeline.view_scale(),
		border.gap_urgencies(),
		delta
	)


# Builds the target highlight: a flat warm ring that is shown under the target, hidden when there is none.
func _build_highlight() -> void:
	highlight = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = Config.TD_HIGHLIGHT_RADIUS
	mesh.bottom_radius = Config.TD_HIGHLIGHT_RADIUS
	mesh.height = 0.02
	highlight.mesh = mesh
	_highlight_mat = StandardMaterial3D.new()
	_highlight_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_highlight_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_mat.albedo_color = Config.TD_HIGHLIGHT_COLOR
	highlight.material_override = _highlight_mat
	highlight.visible = false
	add_child(highlight)


# Moves the highlight to the target's feet and pulses it slowly. Hidden while there is no valid target.
func _update_highlight(delta: float) -> void:
	_pulse_time += delta
	if not is_instance_valid(player.target):
		highlight.visible = false
		return
	var t: Person = player.target
	highlight.visible = true
	highlight.global_position = Vector3(t.global_position.x, 0.03, t.global_position.z)
	var s := 1.0 + Config.TD_HIGHLIGHT_PULSE * sin(_pulse_time * Config.TD_HIGHLIGHT_PULSE_SPEED)
	highlight.scale = Vector3(s, 1.0, s)


func _setup_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.7, 0.72, 0.75)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.6, 0.6, 0.6)
	_env.ambient_light_energy = 0.6

	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-50, 30, 0)
	_sun.shadow_enabled = true
	add_child(_sun)


# Dusk to dawn: the sun and the ambient light follow the night (see NightCycle).
func _update_light() -> void:
	_sun.light_color = night.sun_color()
	_sun.light_energy = night.sun_energy()
	_env.ambient_light_color = night.ambient_color()


func _build_level() -> void:
	var side := float(Config.TD_PLAZA_SIZE)
	var wall_at := side / 2.0 + 0.5

	# Floor: top surface at y = 0. The plaza look draws the floor and the walls; the bodies here are the collision.
	add_child(_make_body(Vector3(side, 1, side), Vector3(0, -0.5, 0)))

	# Walls around the edge.
	add_child(_make_body(Vector3(side + 2, 3, 1), Vector3(0, 1.5, -wall_at)))
	add_child(_make_body(Vector3(side + 2, 3, 1), Vector3(0, 1.5, wall_at)))
	add_child(_make_body(Vector3(1, 3, side + 2), Vector3(-wall_at, 1.5, 0)))
	add_child(_make_body(Vector3(1, 3, side + 2), Vector3(wall_at, 1.5, 0)))
	_make_plaza_look()

	# Obstacle blocks. Each one is drawn by its Building's look (see Border.register_building).
	for pos: Vector3 in BLOCK_POSITIONS:
		var block := _make_body(BLOCK_SIZE, pos)
		add_child(block)
		_obstacles.append(block)

	# The landmarks (round 19: three): blocks of their own height, far from the start.
	for k: int in range(Config.LANDMARK_NAMES.size()):
		var at := Config.LANDMARK_POSITIONS[k]
		var lm_size := Config.LANDMARK_SIZES[k]
		var lm_body := _make_body(lm_size, Vector3(at.x, lm_size.y / 2.0, at.z))
		add_child(lm_body)
		_obstacles.append(lm_body)
		_landmark_bodies.append(lm_body)


func _make_plaza_look() -> void:
	plaza_look = Looks.plaza_look()
	add_child(plaza_look)
	plaza_look.setup(float(Config.TD_PLAZA_SIZE))


# Creates a static body with a box collision shape (the drawing is done by looks).
func _make_body(size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body


func _spawn_people() -> void:
	_rng.seed = Config.RNG_SEED
	var placed: Array[Vector3] = []
	for i: int in range(Config.TD_PEOPLE_COUNT):
		var pos := _find_spot(placed)
		placed.append(pos)

		var p: Person = Person.new()
		p.affinity = i % 3
		p.look_seed = i
		p.gloom = _rng.randf_range(Config.GLOOM_START_MIN, Config.GLOOM_START_MAX)
		p.position = pos
		p.ui_scale = Config.TD_UI_SCALE
		p.grace_seconds = Config.TD_RESCUE_GRACE_SECONDS
		add_child(p)
		p.rescued.connect(_on_person_rescued.bind(p))
		p.relapsed.connect(_on_person_relapsed.bind(p))
		p.stage_changed.connect(_on_stage_changed.bind(p))
		p.dim_gate = _try_dim_sink
		people.append(p)


# Tries up to 200 random spots inside the plaza and returns the first that is clear of the
# centre, the blocks and the other people. If none is found, returns the last try.
func _find_spot(placed: Array[Vector3]) -> Vector3:
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_SPAWN_EDGE
	var candidate := Vector3.ZERO
	for attempt: int in range(200):
		candidate = Vector3(_rng.randf_range(-limit, limit), 0.0, _rng.randf_range(-limit, limit))
		if _spot_ok(candidate, placed):
			return candidate
	return candidate


func _spot_ok(p: Vector3, placed: Array[Vector3]) -> bool:
	if _flat_dist(p, Vector3.ZERO) < Config.TD_SPAWN_CENTRE_CLEAR:
		return false
	if _near_block(p, Config.TD_BLOCK_CLEARANCE):
		return false
	for other: Vector3 in placed:
		if _flat_dist(p, other) < Config.TD_SPAWN_SPACING:
			return false
	return true


# True if `p` is inside any block's footprint (the landmark included), grown by `margin` metres.
func _near_block(p: Vector3, margin: float) -> bool:
	var reach := BLOCK_SIZE.x * 0.5 + margin
	for block: Vector3 in BLOCK_POSITIONS:
		if absf(p.x - block.x) < reach and absf(p.z - block.z) < reach:
			return true
	for lm: Vector3 in Config.LANDMARK_POSITIONS:
		if absf(p.x - lm.x) < reach and absf(p.z - lm.z) < reach:
			return true
	return false


# Moves every unrescued person for this frame. Dimmed people drift toward the rescued person they are assigned to
# (see pursuit_assignments). A dimmed person with nobody to chase drifts to the nearest territory edge, and everyone
# else wanders. Everyone also steers away from close neighbours (_separation). Rescued people are moved by the border.
func _update_people(delta: float) -> void:
	var pursuit: Dictionary = pursuit_assignments(people)
	for p: Person in people:
		p.shooter_pos = player.global_position  # Round 17: the guarded wedge asks whether a shot from here would land.
		if p.is_rescued:
			continue
		if grabs.is_grabbing(p):
			continue  # A grabber stands still through the wind-up and the lunge.
		if moods.is_fleeing(p):
			_step(p, moods.flee_dir(p), Config.SKITTISH_FLEE_SPEED, delta)  # Round 12b: a scared skittish person backs away.
			continue
		if _reaches_for_player(p):
			var to_player: Vector3 = player.global_position - p.global_position
			to_player.y = 0.0
			var toward := Vector3.ZERO
			if to_player.length() > Config.GRAB_RANGE * 0.8:
				toward = to_player.normalized()
			_steer(p, toward, Config.TD_DIMMED_DRIFT_SPEED, delta)
		elif pursuit.has(p):
			var target_p: Person = pursuit[p]
			var to: Vector3 = target_p.global_position - p.global_position
			to.y = 0.0
			var desired := Vector3.ZERO
			if to.length() > _stop_distance(p, target_p):
				desired = to.normalized()
			_steer(p, desired, Config.TD_DIMMED_DRIFT_SPEED, delta)
		elif GloomSim.is_dimmed(p) and ground.has_edge():
			var to_edge: Vector3 = ground.nearest_edge_point(p.global_position) - p.global_position
			to_edge.y = 0.0
			var edge_desired := Vector3.ZERO
			if to_edge.length() > Config.TD_EDGE_REACH:
				edge_desired = to_edge.normalized()
			_steer(p, edge_desired, Config.TD_DIMMED_DRIFT_SPEED, delta)
		else:
			_steer(p, _wander_dir(p, delta), Config.TD_WANDER_SPEED, delta)


# How close a pursuing dimmed person walks to their target: right up to the line when they are outside the border and
# the target is a border member (they press it, Round 12b), otherwise TD_DIMMED_STOP_DISTANCE.
func _stop_distance(p: Person, target_p: Person) -> float:
	if border.active and border.members.has(target_p):
		if not Border.is_inside(border.polygon, Vector2(p.position.x, p.position.z)):
			return Config.TD_DIMMED_PRESS_STOP
	return Config.TD_DIMMED_STOP_DISTANCE


# Round 12a: a dimmed person who notices a player that is not dim (within GRAB_NOTICE_RANGE) drifts toward them to grab.
# Dimmed people ignore a dim player and go back to pressing the border.
func _reaches_for_player(p: Person) -> bool:
	if not GloomSim.is_dimmed(p) or player.is_dim or not player.active:
		return false
	return _flat_dist(p.global_position, player.global_position) <= Config.GRAB_NOTICE_RANGE


# Works out which rescued person each dimmed person drifts toward (the weakest point). Each rescued person takes at most
# TD_MAX_PURSUERS_PER_TARGET dimmed people. A dimmed person takes the rescued person with the lowest protection within
# TD_PURSUIT_SEARCH_RADIUS (ties go to the nearer one). People are handled in array order, so the result is the same on
# every run. Returns a Dictionary of dimmed Person -> rescued Person. A dimmed person with no target is not in it.
func pursuit_assignments(list: Array[Person]) -> Dictionary:
	var rescued_list: Array[Person] = []
	for p: Person in list:
		if p.is_rescued:
			rescued_list.append(p)
	var slots: Dictionary = {}
	var out: Dictionary = {}
	for p: Person in list:
		if not GloomSim.is_dimmed(p):
			continue
		var best := _weakest_with_slot(p.global_position, rescued_list, slots)
		if best != null:
			out[p] = best
			var used: int = slots.get(best, 0)
			slots[best] = used + 1
	return out


# The rescued person a dimmed person at `pos` goes for: the lowest protection within TD_PURSUIT_SEARCH_RADIUS that
# still has a free pursuer slot (see pursuit_assignments). Ties go to the nearest. Null if there is none.
func _weakest_with_slot(pos: Vector3, rescued_list: Array[Person], slots: Dictionary) -> Person:
	var best: Person = null
	var best_u := -INF
	for r: Person in rescued_list:
		var used: int = slots.get(r, 0)
		if used >= Config.TD_MAX_PURSUERS_PER_TARGET:
			continue
		var d := _flat_dist(pos, r.global_position)
		if d > Config.TD_PURSUIT_SEARCH_RADIUS:
			continue
		# Round 12b, edge pressure: among equally exposed people the newest and outermost stretch of the border is
		# worth EDGE_PRESSURE_REACH metres of walking; with no border this is plain distance.
		var u := border.edge_pressure(r.global_position) * Config.EDGE_PRESSURE_REACH - d
		if best == null or r.protection < best.protection - Config.EDGE_PROTECTION_TIE:
			best = r
			best_u = u
		elif absf(r.protection - best.protection) <= Config.EDGE_PROTECTION_TIE and u > best_u:
			best = r
			best_u = u
	return best


# Returns the flat direction a wandering person walks in this frame, or zero if they are standing still.
# They pick a new spot when they arrive or their time is up.
func _wander_dir(p: Person, delta: float) -> Vector3:
	if not _wander.has(p):
		_wander[p] = {"target": p.global_position, "timer": 0.0}
	var st: Dictionary = _wander[p]
	st["timer"] = st["timer"] - delta
	var here: Vector3 = p.global_position
	var to: Vector3 = st["target"] - here
	to.y = 0.0
	if st["timer"] <= 0.0 or to.length() <= Config.TD_WANDER_REACH:
		st["target"] = _new_wander_target(here)
		st["timer"] = _rng.randf_range(Config.TD_WANDER_TIME_MIN, Config.TD_WANDER_TIME_MAX)
		to = st["target"] - here
		to.y = 0.0
	if to.length() > 0.01:
		return to.normalized()
	return Vector3.ZERO


# Moves a person along `desired` (a flat direction, or zero to stand still) plus the push away from neighbours.
# The push is added before normalising, so the step is always speed * delta long and the speed cap holds.
func _steer(p: Person, desired: Vector3, speed: float, delta: float) -> void:
	var want := desired + _separation(p) * Config.TD_SEPARATION_STRENGTH
	want.y = 0.0
	if want.length() < 0.001:
		return
	_step(p, want.normalized(), speed, delta)


# The push away from each person within TD_SEPARATION_RADIUS: one unit of push per neighbour, away from it. A constant
# push (not a falloff) is stronger than a wander step, so people settle at about the radius apart instead of drifting
# back together. Two people standing exactly on the same spot are split by array order: the earlier one is pushed
# right, the later one left.
func _separation(p: Person) -> Vector3:
	var push := Vector3.ZERO
	var my_index := people.find(p)
	for i: int in range(people.size()):
		var q: Person = people[i]
		if q == p:
			continue
		var diff: Vector3 = p.global_position - q.global_position
		diff.y = 0.0
		var d := diff.length()
		if d >= Config.TD_SEPARATION_RADIUS:
			continue
		if _may_loom(p, q):
			continue
		if d < 0.001:
			diff = Vector3.RIGHT if my_index < i else Vector3.LEFT
		push += diff.normalized()
	return push


# Round 12b: a dimmed person and a wistful or gloomy one do not push each other apart, so a dimmed person can stand
# close enough (within SHELTER_RADIUS) to shelter someone. (Otherwise the crowd spacing, 2.2 m, would always undo it.)
# A dimmed person is not pushed off by a rescued member either, so they can walk up to the line and press it (the line
# itself, not the crowd spacing, holds them back; see _stop_distance).
func _may_loom(a: Person, b: Person) -> bool:
	if a.is_rescued or b.is_rescued:
		return GloomSim.is_dimmed(a) or GloomSim.is_dimmed(b)
	return GloomSim.is_dimmed(a) != GloomSim.is_dimmed(b)


# Picks a random spot within TD_WANDER_RANGE of `from`, inside the plaza and clear of blocks.
func _new_wander_target(from: Vector3) -> Vector3:
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	for attempt: int in range(10):
		var angle := _rng.randf() * TAU
		var dist := _rng.randf() * Config.TD_WANDER_RANGE
		var c := from + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		c.x = clampf(c.x, -limit, limit)
		c.z = clampf(c.z, -limit, limit)
		if not _near_block(c, Config.TD_BLOCK_CLEARANCE):
			return c
	return from


# Moves a person along a flat direction, keeping them inside the plaza and out of blocks, and turns them to face it.
# A dimmed person outside the border cannot cross an intact stretch: its move stops at the line (see Border.clip_move).
func _step(p: Person, dir: Vector3, speed: float, delta: float) -> void:
	var move := dir * speed * delta
	move.y = 0.0
	var next_pos: Vector3 = p.position + move
	var limit := Config.TD_PLAZA_SIZE / 2.0 - Config.TD_EDGE_MARGIN
	next_pos.x = clampf(next_pos.x, -limit, limit)
	next_pos.z = clampf(next_pos.z, -limit, limit)
	if GloomSim.is_dimmed(p):
		next_pos = border.clip_move(p.position, next_pos)
	if _near_block(next_pos, Config.TD_BLOCK_CLEARANCE):
		# Blocked: make a wanderer choose a new target next time.
		if _wander.has(p):
			_wander[p]["timer"] = 0.0
		return
	p.position = next_pos
	if p.active_mood() != Person.Mood.GUARDED:  # A guarded person keeps their back to the player (see Moods).
		p.look_at(next_pos + Vector3(dir.x, 0.0, dir.z), Vector3.UP)


# Distance between two points, ignoring height.
func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# Round 12b: someone sank or lifted a stage. The minimap shows a brief blip where a person became dimmed.
func _on_stage_changed(_from_level: int, to_level: int, p: Person) -> void:
	if to_level >= 2 and not p.is_rescued:
		minimap.add_blip(Vector2(p.position.x, p.position.z))


# A rescued person (`p`) was made: the border takes them in. The count goes up.
func _on_person_rescued(p: Person) -> void:
	rescued_count += 1
	border.on_rescue(p)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	player.add_spirit(Config.SPIRIT_PER_RESCUE)
	spirit_meter.moment(Config.SPIRIT_PER_RESCUE, SpiritMeter.Moment.GAIN)
	feedback.pulse_player(SpiritMeter.Moment.GAIN)


# A rescued person (`p`) relapsed: they step out of the border, and the count goes down.
func _on_person_relapsed(p: Person) -> void:
	rescued_count -= 1
	border.on_relapse(p)
	hud.set_rescued(rescued_count, Config.TD_PEOPLE_COUNT)
	hud.show_alert("Someone lost their joy!")


# Round 20: a landmark was claimed (its boost is on) or lost (its boost is off): a notice across the top.
func _on_landmark_claimed(lm: Landmark) -> void:
	hud.show_alert(lm.claim_text(), Config.LANDMARK_CLAIM_COLOUR)


func _on_landmark_lost(lm: Landmark) -> void:
	hud.show_alert(lm.loss_text(), Config.LANDMARK_LOSS_COLOUR, Config.LANDMARK_LOSS_SECONDS)


# The end conditions, in order: the border falling loses, and dawn ends the level (a win, rated in dawn lights).
func _check_end() -> void:
	if border.formed and rescued_count < Config.BORDER_MIN_PEOPLE:
		_end_round("The border fell")
	elif night.is_over():
		rating = _current_rating()
		var lights: int = rating["lights"]
		_end_round("Dawn: %d of 3 dawn lights" % lights)


func _end_round(title: String) -> void:
	if not running:
		return
	running = false
	if recorder != null:
		recorder.on_round_end(title)
	player.active = false
	hud.set_night_progress(night.progress())
	hud.show_end(title, _detail_text(), rating)


# What the rating would be right now (people rescued, ground held, landmarks held).
func _current_rating() -> Dictionary:
	return DawnRating.rate(rescued_count, Config.TD_PEOPLE_COUNT, ground.beautified_fraction(), landmarks.held_count())


# The lines on the end screen: the dawn lights (at dawn) with the reasons, then the buildings beautified.
func _detail_text() -> String:
	var r: Dictionary = rating if not rating.is_empty() else _current_rating()
	var lights: int = r["lights"]
	var lines: Array[String] = []
	if not rating.is_empty():
		lines.append("Dawn lights: " + DawnRating.lights_text(lights))
	lines.append_array(r["lines"] as Array[String])
	lines.append("%d of %d buildings beautified" % [border.beautified_building_count(), border.buildings.size()])
	if not rating.is_empty():
		lines.append(DawnRating.hint_for(lights))
	return "\n".join(lines)
