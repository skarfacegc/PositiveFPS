class_name Grabs
extends Node

# Round 12a, dance with the gloom: dimmed people within GRAB_RANGE of a player who is not dim start a grab. A clear
# wind-up (GRAB_WINDUP: they lean back and a warning ring grows at their feet toward the player, both drawn by the
# person's look from Person.grab_frac) is followed by a short lunge toward the player (at most GRAB_LUNGE_DISTANCE).
# If the player is within GRAB_HIT_RANGE of the grabber when the lunge ends, the grab lands and drains GRAB_SPIRIT_DRAIN
# spirit. Each person then waits GRAB_COOLDOWN (counted from the end of the wind-up).
# The way to avoid a grab is to be out of reach when the lunge ends (the wind-up is the warning).

# A grab landed on the player.
signal grab_landed(person: Person)
# A lunge ended out of reach, so the grab missed.
signal grab_avoided(person: Person)

# Seconds into each grabber's wind-up, each lunge as {"from", "to", "left"}, and seconds left of each person's cooldown.
var _windup: Dictionary = {}
var _lunge: Dictionary = {}
var _cooldown: Dictionary = {}


# Advances every grab by `delta`. People are handled in array order, so runs repeat.
func update(people: Array[Person], player: TopDownPlayer, delta: float) -> void:
	for p: Person in people:
		if _cooldown.has(p):
			var left: float = _cooldown[p] - delta
			if left <= 0.0:
				_cooldown.erase(p)
			else:
				_cooldown[p] = left
		if _windup.has(p):
			_advance_windup(p, player, delta)
		elif _lunge.has(p):
			_advance_lunge(p, player, delta)
		elif _can_start(p, player):
			_windup[p] = 0.0
			_aim(p, player)


# True while `p` is winding up or lunging (the level keeps them standing still).
func is_grabbing(p: Person) -> bool:
	return _windup.has(p) or _lunge.has(p)


# True while `p` is in the wind-up (not yet landed or missed).
func is_winding_up(p: Person) -> bool:
	return _windup.has(p)


# Seconds left before `p` can grab again (0 when they can).
func cooldown_left(p: Person) -> float:
	return _cooldown.get(p, 0.0)


func _can_start(p: Person, player: TopDownPlayer) -> bool:
	if not GloomSim.is_dimmed(p) or player.is_dim or not player.active or _cooldown.has(p):
		return false
	return GloomSim.flat_dist(p.global_position, player.global_position) <= Config.GRAB_RANGE


func _advance_windup(p: Person, player: TopDownPlayer, delta: float) -> void:
	if not GloomSim.is_dimmed(p) or player.is_dim or not player.active:
		_cancel(p)
		return
	var t: float = _windup[p] + delta
	_aim(p, player)
	if t < Config.GRAB_WINDUP:
		_windup[p] = t
		p.grab_frac = t / Config.GRAB_WINDUP
		return
	_windup.erase(p)
	p.grab_frac = 0.0
	p.grab_lunging = true
	_cooldown[p] = Config.GRAB_COOLDOWN
	var reach := clampf(
		GloomSim.flat_dist(p.global_position, player.global_position) - Config.GRAB_LUNGE_STOP,
		0.0,
		Config.GRAB_LUNGE_DISTANCE
	)
	_lunge[p] = {"from": p.position, "to": p.position + p.grab_toward * reach, "left": Config.GRAB_LUNGE_TIME}


# Moves the grabber along its lunge; when it ends, the grab lands or misses.
func _advance_lunge(p: Person, player: TopDownPlayer, delta: float) -> void:
	var lunge: Dictionary = _lunge[p]
	var left: float = lunge["left"] - delta
	var from: Vector3 = lunge["from"]
	var to: Vector3 = lunge["to"]
	var t := 1.0 - clampf(left / Config.GRAB_LUNGE_TIME, 0.0, 1.0)
	p.position = from.lerp(to, t)
	if left > 0.0:
		lunge["left"] = left
		return
	_end_lunge(p)
	_resolve(p, player)


# The lunge ended: the grab lands when the player is still in reach, otherwise it misses.
func _resolve(p: Person, player: TopDownPlayer) -> void:
	if GloomSim.flat_dist(p.global_position, player.global_position) > Config.GRAB_HIT_RANGE:
		grab_avoided.emit(p)
		return
	player.lose_spirit(Config.GRAB_SPIRIT_DRAIN)
	grab_landed.emit(p)


# Turns the grabber toward the player and tells the look which way that is.
func _aim(p: Person, player: TopDownPlayer) -> void:
	var to := player.global_position - p.global_position
	to.y = 0.0
	if to.length() < 0.01:
		return
	p.grab_toward = to.normalized()
	p.look_at(p.global_position + p.grab_toward, Vector3.UP)


func _cancel(p: Person) -> void:
	_windup.erase(p)
	p.grab_frac = 0.0


func _end_lunge(p: Person) -> void:
	_lunge.erase(p)
	p.grab_lunging = false
