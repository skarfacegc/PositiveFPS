class_name Person
extends StaticBody3D

signal rescued
signal relapsed
# The visible stage changed (0 wistful, 1 gloomy, 2 dimmed): sank when `to_level` is higher, lifted when lower.
signal stage_changed(from_level: int, to_level: int)
# Round 13b: joy was turned away. `reason` is a Block value (the cause, so the screen can flash its icon).
signal joy_blocked(reason: int)
# Round 14: joy landed on an unrescued person (after the guard and sheltering checks). The level uses it to show a
# dimmed person's progress ring and the one-time dimmed prompt.
signal joy_landed

# Round 12b: the mood of an unrescued wistful or gloomy person (see scripts/moods.gd). Dimmed and rescued people act
# as if they had none (active_mood).
enum Mood { NONE, GUARDED, SKITTISH, GLUM }
# Round 13b: why joy was turned away (see joy_blocked).
enum Block { GUARDED, SHELTERED }

var affinity: int = 0
# A small number that picks cosmetic variety (the pose and outfit variant a styled look draws). Set by the level.
var look_seed: int = 0
var joy: float = 0.0
var is_rescued: bool = false
# Scales the joy label and floating numbers. Top-down mode sets this higher, because the camera is far away.
var ui_scale: float = 1.0
# Hidden darkness value, 0.0 (light) to 1.0 (nearly black). topdown_main.gd changes this each frame.
var gloom: float = 0.0
# The visible grey level (0 light, 1 grey, 2 dark). When it changes, a short moment plays.
var level: int = 0
# The look: draws this person from the state above (see scripts/looks/person_look.gd). Rebuilt by rebuild_look().
var look: PersonLook
# Seconds after a rescue during which nearby darkness cannot drain this person. 0 means no grace.
var grace_seconds: float = 0.0
# Seconds of grace left. The grace cue (ring and glow) is shown while this is above zero.
var grace_left: float = 0.0
# Cover (0..1): the average paint weight of the ground around this person. Set by topdown_main.gd.
var cover: float = 0.0
# Protection (0..1) from the cover: 0 at a painted edge, 1 deep inside. Darkness and joy fade scale by it.
var protection: float = 0.0
# Cover and protection labels, built the first time the F3 debug overlay is turned on (see set_debug_visible).
var debug_label: Label3D
# Seconds since the person was made (drives the grace ring's pulse, which the look draws).
var grace_time: float = 0.0
# Seconds left to show the sad face after a relapse.
var sad_left: float = 0.0
# Round 12a: the grab cue, set by Grabs. grab_frac is the wind-up progress (0 when not grabbing, up to 1),
# `grab_lunging` is true for the short lunge after it, and `grab_toward` is the flat direction to the player.
var grab_frac: float = 0.0
var grab_lunging: bool = false
var grab_toward := Vector3.FORWARD
# Round 12b: the mood, set at the start by Moods.assign. `glum_up` is true while a glum person is looking up (joy counts
# triple), `sheltered` while a dimmed person stands within SHELTER_RADIUS (joy glances off), `flee_left` the seconds a
# scared skittish person still backs away, `flee_from` the flat point they back away from. `glance_count` counts the
# shots that glanced off (for tests and the debug label). `mood_phase` is a cosmetic clock for the look.
var mood: int = Mood.NONE
var glum_up: bool = false
var sheltered: bool = false
# Round 14: the one wistful or gloomy person a dimmed person shelters (the nearest within SHELTER_RADIUS), or null.
# Set by Moods; the tether and the umbrella follow this one person only.
var shelter_ward: Person = null
# Round 15: the shield. On a sheltered person, `shielder` is the dimmed person whose shield it is (null otherwise). On a
# dimmed person, `shield_hits` counts the joy landings its shield has taken (0 to SHELTER_HITS; the shield belongs to
# this dimmed person, so it survives a change of ward), and `shield_down_left` is the seconds left before it may
# shelter again after a pop. Set by Moods; wear_shield() is called by the sheltered person's receive_joy.
var shielder: Person = null
var shield_hits: int = 0
var shield_down_left: float = 0.0
# Round 14: asked before this person sinks to dimmed (returns true to let them). Set by the level; invalid for a Person
# built by hand (tests), who then sink freely.
var dim_gate := Callable()
var flee_left: float = 0.0
var flee_from := Vector3.ZERO
var glance_count: int = 0
var mood_phase: float = 0.0
# Round 13b: false while the layered introduction (see intro.gd) keeps this person's mood dormant.
var mood_unlocked: bool = true
# Seconds since this person was last hit by a joy projectile.
var _since_hit: float = 99.0


func _ready() -> void:
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	collision.shape = capsule
	collision.position = Vector3(0, 0.9, 0)
	add_child(collision)

	# Everything drawn of this person is the look (the collision above is not scaled by it).
	look = Looks.person_look()
	add_child(look)
	look.setup(self)
	_update_visuals()


# Swaps the look in place (F4): the rules state is untouched, the visuals are rebuilt from it.
func rebuild_look() -> void:
	if look != null:
		remove_child(look)
		look.queue_free()
	look = Looks.person_look()
	add_child(look)
	look.setup(self)
	_update_visuals()


# Round 14: the label scale (the zoom, see TopDownMain._update_camera). Redraws the label only when the value changes.
func set_ui_scale(value: float) -> void:
	if value == ui_scale:
		return
	ui_scale = value
	if look != null:
		look.rescale()


# The joy this person needs to be rescued. Darker levels need more.
func joy_needed() -> float:
	return Config.JOY_MAX * Config.LEVEL_JOY_MULT[Config.gloom_level(gloom)]


# True when a rescued person is losing joy and close to relapsing (they flicker and show "!").
func is_warning() -> bool:
	return is_rescued and joy < joy_needed() * Config.WARN_FRACTION


# Round 12b: a rescued person drained below MEMBER_FALTER_FRACTION of their joy needed. A border member who falters
# steps back and opens a gap on both sides of them (see Border).
func is_faltering() -> bool:
	return is_rescued and joy < joy_needed() * Config.MEMBER_FALTER_FRACTION


# Where a joy projectile should land: a little above the feet, at chest height.
func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


# The mood that counts right now: none for rescued and dimmed people.
func active_mood() -> int:
	if is_rescued or Config.gloom_level(gloom) >= 2 or not mood_unlocked:
		return Mood.NONE
	return mood


static func mood_name(m: int) -> String:
	return ["", "guarded", "skittish", "glum"][clampi(m, 0, 3)]


# The flat direction this person faces (their local forward, -Z).
func facing_dir() -> Vector3:
	var f := -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD


# True when joy coming from `from` (a world point) would arrive at this person's front or side: the angle between
# their facing and the direction to `from` is at most GUARDED_ARC_DEG. A point on the person counts as the front.
func is_open_to(from: Vector3) -> bool:
	var to := from - global_position
	to.y = 0.0
	if to.length() < 0.01:
		return true
	return rad_to_deg(facing_dir().angle_to(to.normalized())) <= Config.GUARDED_ARC_DEG


# Called when a joy projectile (or a burst) hits this person. Works on rescued people too (top-up). `from` is where the
# joy comes from (the shooter, or the centre of a burst or bloom); Vector3.INF means no direction. Round 12b: an
# unrescued person can turn the joy away (guarded and shot from behind: it glances off with a small puff and gives no
# joy), and a glum person looking up counts it triple.
# Round 15: a sheltered person's shield takes each discrete landing (a projectile, a note, a burst hit): it puffs the
# blocked-joy feedback, wears the shield (wear_shield), and only SHELTER_LEAK of the amount gets through. The shield
# pops on its SHELTER_HITS-th landing. Continuous joy (a bloom's per-tick pulse) passes wears_shield = false: it still
# leaks, but it is not a landing, so it neither wears the shield nor puffs the feedback every tick.
func receive_joy(
	element: int, amount: float, distance: float, from: Vector3 = Vector3.INF, wears_shield: bool = true
) -> void:
	if not is_rescued:
		if sheltered:
			if wears_shield:
				_glance(Config.SHELTER_COLOUR)
				joy_blocked.emit(Block.SHELTERED)
				if shielder != null:
					shielder.wear_shield()
			amount *= Config.SHELTER_LEAK
		elif active_mood() == Mood.GUARDED and from != Vector3.INF and not is_open_to(from):
			_glance(Config.GLANCE_COLOUR)
			joy_blocked.emit(Block.GUARDED)
			return
		if active_mood() == Mood.GLUM and glum_up:
			amount *= Config.GLUM_LOOKUP_MULT
	var mult := Config.multiplier(element, affinity)
	var gain := amount * mult * Config.falloff(distance)
	joy = minf(joy + gain, joy_needed())
	_since_hit = 0.0
	if not is_rescued:
		joy_landed.emit()
	if Config.NUMBERS_ENABLED and look != null:
		look.show_number(gain, mult)
	if is_rescued:
		_update_visuals()
	elif joy >= joy_needed():
		_rescue()
	else:
		_update_visuals()


# Round 15: the share of this dimmed person's shield left: 1 when fresh, 0.25 after three hits, and so on.
func shield_left_frac() -> float:
	return 1.0 - float(shield_hits) / float(Config.SHELTER_HITS)


# Round 15: one joy landing on the person this dimmed person shelters wears the shield. On the SHELTER_HITS-th it pops:
# the ward is no longer sheltered (its puff shows), this person shelters no one for SHELTER_REGROW seconds, and the
# hit count starts again from zero. Returns true when it popped.
func wear_shield() -> bool:
	shield_hits += 1
	if shield_hits < Config.SHELTER_HITS:
		return false
	shield_hits = 0
	shield_down_left = Config.SHELTER_REGROW
	if shelter_ward != null:
		shelter_ward.sheltered = false
		shelter_ward.shielder = null
		shelter_ward._fx_puff(Config.SHELTER_COLOUR, Config.SHELTER_POP_PUFF)
	shelter_ward = null
	return true


# Joy glanced off: a small puff, no joy.
func _glance(colour: Color) -> void:
	glance_count += 1
	_fx_puff(colour, 8)


# Called every frame by topdown_main.gd: handles joy fading, level changes and visuals.
func tick(delta: float) -> void:
	_since_hit += delta
	grace_time += delta
	if sad_left > 0.0:
		sad_left -= delta
	if grace_left > 0.0:
		grace_left = maxf(0.0, grace_left - delta)
	if not is_rescued:
		if _since_hit > Config.JOY_FADE_DELAY:
			# Partial joy does not fade deep inside painted ground (protection 1).
			var exposure := 1.0 - protection
			joy = maxf(0.0, joy - Config.JOY_FADE_RATE * delta * exposure)
		if joy >= joy_needed():
			_rescue()
		else:
			_check_level()
	_update_visuals()
	_update_debug_label()


# Removes joy from a rescued person (used by nearby darkness). Relapses them if they drop too low.
func drain_joy(amount: float) -> void:
	if not is_rescued or grace_left > 0.0:
		return
	joy -= amount
	if joy < joy_needed() * Config.RELAPSE_FRACTION:
		_relapse()
	else:
		_update_visuals()


func _rescue() -> void:
	is_rescued = true
	gloom = 0.0
	level = 0
	grace_left = grace_seconds
	joy = minf(joy, Config.JOY_MAX)
	_update_visuals()

	# A little bounce: up and down twice.
	if look != null:
		look.play_bounce()

	rescued.emit()


func _relapse() -> void:
	is_rescued = false
	gloom = maxf(gloom, 0.6)
	level = Config.gloom_level(gloom)
	_since_hit = 0.0
	sad_left = 1.5
	_update_visuals()
	_fx_puff(Color(0.15, 0.15, 0.18), 30)
	_fx_slump(0.85, 0.3)
	relapsed.emit()


# Fires a moment when the visible grey level changes: darker is a slump and dark puff, lighter is a sparkle.
func _check_level() -> void:
	var new_level := Config.gloom_level(gloom)
	if new_level == level:
		return
	# Round 14: sinking to dimmed needs the midnight gate (see TopDownMain._try_dim_sink). Refused, the person waits at the
	# top of the gloomy band (gloomy, just under the dimmed threshold) and asks again on the next frame.
	if new_level >= 2 and level < 2 and dim_gate.is_valid() and not dim_gate.call():
		gloom = Config.DIM_WAIT_GLOOM
		new_level = 1
	if new_level == level:
		return
	var old_level := level
	level = new_level
	# Round 12b: a clear moment. Sinking is a grey-violet puff and ripple (not icy), lifting is a warm one.
	if new_level > old_level:
		_fx_slump(0.8, 0.35)
		_fx_puff(Config.STAGE_SINK_COLOUR, Config.STAGE_PUFF_COUNT)
		_fx_ripple(Config.STAGE_SINK_COLOUR)
	else:
		_fx_puff(Config.STAGE_LIFT_COLOUR, Config.STAGE_PUFF_COUNT)
		_fx_ripple(Config.STAGE_LIFT_COLOUR)
	stage_changed.emit(old_level, new_level)


# A squash and spring back of the body, and a puff of particles. Both are drawn by the look.
func _fx_slump(scale_y: float, duration: float) -> void:
	if look != null:
		look.play_slump(scale_y, duration)


func _fx_puff(color: Color, count: int) -> void:
	if look != null:
		look.play_puff(color, count)


func _fx_ripple(color: Color) -> void:
	if look != null:
		look.play_ripple(color)


# Tells the look to redraw from the current state.
func _update_visuals() -> void:
	if look != null:
		look.sync()


# Shows or hides the cover and protection labels above this person (the F3 debug overlay).
func set_debug_visible(on: bool) -> void:
	if debug_label == null and on:
		# Sized in metres (not ui_scale), so it reads at the top-down camera distance (see Config.TD_DEBUG_FONT_SIZE).
		debug_label = Label3D.new()
		debug_label.position = Vector3(0, Config.TD_DEBUG_LABEL_HEIGHT, 0)
		debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		debug_label.font_size = Config.TD_DEBUG_FONT_SIZE
		debug_label.pixel_size = Config.TD_DEBUG_PIXEL_SIZE
		debug_label.no_depth_test = true
		debug_label.outline_size = 12
		add_child(debug_label)
	if debug_label != null:
		debug_label.visible = on
	_update_debug_label()


# Writes the cover and protection percentages into the debug label (only while it is visible).
func _update_debug_label() -> void:
	if debug_label == null or not debug_label.visible:
		return
	debug_label.text = "c %d%%  p %d%%" % [roundi(cover * 100.0), roundi(protection * 100.0)]
	var m := active_mood()
	if m != Mood.NONE:
		debug_label.text += "  " + mood_name(m)
