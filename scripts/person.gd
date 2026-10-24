class_name Person
extends StaticBody3D

signal rescued
signal relapsed

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


# The joy this person needs to be rescued. Darker levels need more.
func joy_needed() -> float:
	return Config.JOY_MAX * Config.LEVEL_JOY_MULT[Config.gloom_level(gloom)]


# True when a rescued person is losing joy and close to relapsing (they flicker and show "!").
func is_warning() -> bool:
	return is_rescued and joy < joy_needed() * Config.WARN_FRACTION


# Where a joy projectile should land: a little above the feet, at chest height.
func chest_position() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)


# Called when a joy projectile (or a burst) hits this person. Works on rescued people too (top-up).
func receive_joy(element: int, amount: float, distance: float) -> void:
	var mult := Config.multiplier(element, affinity)
	var gain := amount * mult * Config.falloff(distance)
	joy = minf(joy + gain, joy_needed())
	_since_hit = 0.0
	if Config.NUMBERS_ENABLED and look != null:
		look.show_number(gain, mult)
	if is_rescued:
		_update_visuals()
	elif joy >= joy_needed():
		_rescue()
	else:
		_update_visuals()


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
	if new_level > level:
		_fx_slump(0.8, 0.35)
		_fx_puff(Color(0.15, 0.15, 0.18), 20)
	else:
		_fx_puff(Color(0.95, 0.95, 0.95), 10)
	level = new_level


# A squash and spring back of the body, and a puff of particles. Both are drawn by the look.
func _fx_slump(scale_y: float, duration: float) -> void:
	if look != null:
		look.play_slump(scale_y, duration)


func _fx_puff(color: Color, count: int) -> void:
	if look != null:
		look.play_puff(color, count)


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
