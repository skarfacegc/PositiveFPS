class_name Moods
extends Node

# Round 12b, read the person: the moods of unrescued wistful and gloomy people, and the sheltering of dimmed people.
# The rules live here (and in Person.receive_joy, which turns joy away); the look only draws the tells.
#   Guarded: turns to keep their back to the player, at GUARDED_TURN_SPEED. Joy only lands from their front or side
#            (Person.is_open_to), otherwise it glances off.
#   Skittish: a player closer than SKITTISH_RADIUS who approaches faster than SKITTISH_SPEED_LIMIT (a run) scares them:
#             they back away at SKITTISH_FLEE_SPEED for SKITTISH_FLEE_SECONDS (the level moves them, see is_fleeing).
#   Glum: every GLUM_LOOKUP_INTERVAL seconds (plus or minus a seeded jitter) they look up for GLUM_LOOKUP_WINDOW
#         seconds; joy landing then counts GLUM_LOOKUP_MULT times (Person.glum_up).
#   Sheltering: no joy lands on a wistful or gloomy person while a dimmed person is within SHELTER_RADIUS of them
#         (Person.sheltered).
# Dimmed and rescued people have no active mood (Person.active_mood).

# Seeded, so the look-up rhythm repeats from run to run.
var _rng := RandomNumberGenerator.new()
# Per glum person: seconds until the next look-up, and seconds left of the one in progress.
var _next_lookup: Dictionary = {}
var _lookup_left: Dictionary = {}


func _init() -> void:
	_rng.seed = Config.RNG_SEED + 12


# Gives every person one mood, shuffled from a repeating bag (so the three moods are split evenly, within one) with a
# seeded generator. Returns nothing; it sets Person.mood.
static func assign(people: Array[Person], seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var bag: Array[int] = []
	for i: int in range(people.size()):
		bag.append(1 + i % 3)
	for i: int in range(bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := bag[i]
		bag[i] = bag[j]
		bag[j] = tmp
	for i: int in range(people.size()):
		people[i].mood = bag[i]


# Advances every mood by `delta`: sheltering flags, the guarded turn, the skittish scare and the glum look-ups.
func update(people: Array[Person], player: TopDownPlayer, delta: float) -> void:
	var shelterers: Array[Person] = []
	for p: Person in people:
		if GloomSim.is_dark(p):
			shelterers.append(p)
	for p: Person in people:
		if p.is_rescued:
			_clear(p)
			continue
		p.sheltered = _is_sheltered(p, shelterers)
		p.mood_phase += delta
		match p.active_mood():
			Person.Mood.GUARDED:
				_turn_away(p, player, delta)
			Person.Mood.SKITTISH:
				_scare(p, player, delta)
			Person.Mood.GLUM:
				_look_up(p, delta)
			_:
				_clear(p)


# True while `p` is backing away from the player (the level moves them, see TopDownMain._update_people).
func is_fleeing(p: Person) -> bool:
	return p.flee_left > 0.0 and p.active_mood() == Person.Mood.SKITTISH


# The flat direction `p` backs away in: straight away from the point they fled from.
func flee_dir(p: Person) -> Vector3:
	var away := p.global_position - p.flee_from
	away.y = 0.0
	if away.length() < 0.01:
		return Vector3.RIGHT
	return away.normalized()


func _clear(p: Person) -> void:
	p.glum_up = false
	p.flee_left = 0.0
	_next_lookup.erase(p)
	_lookup_left.erase(p)


func _is_sheltered(p: Person, shelterers: Array[Person]) -> bool:
	if Config.gloom_level(p.gloom) >= 2:
		return false
	for q: Person in shelterers:
		if q != p and GloomSim.flat_dist(p.global_position, q.global_position) <= Config.SHELTER_RADIUS:
			return true
	return false


# Guarded: turn slowly so the back stays toward the player.
func _turn_away(p: Person, player: TopDownPlayer, delta: float) -> void:
	var away := p.global_position - player.global_position
	away.y = 0.0
	if away.length() < 0.01:
		return
	# A look_at-style yaw: rotation.y = atan2(-x, -z) makes local forward (-Z) point along (x, z).
	var want := atan2(-away.x, -away.z)
	var diff := angle_difference(p.rotation.y, want)
	var step := clampf(diff, -Config.GUARDED_TURN_SPEED * delta, Config.GUARDED_TURN_SPEED * delta)
	p.rotation.y += step


# Skittish: a player within the radius who is coming closer faster than the limit sets off a flight.
func _scare(p: Person, player: TopDownPlayer, delta: float) -> void:
	var to_p := p.global_position - player.global_position
	to_p.y = 0.0
	var dist := to_p.length()
	if p.flee_left > 0.0:
		p.flee_left = maxf(0.0, p.flee_left - delta)
		p.flee_from = player.global_position
		return
	if dist > Config.SKITTISH_RADIUS or dist < 0.01:
		return
	var vel := Vector3(player.velocity.x, 0.0, player.velocity.z)
	var speed := vel.length()
	if speed <= Config.SKITTISH_SPEED_LIMIT:
		return
	if vel.dot(to_p / dist) <= 0.0:
		return  # Running away or past, not at them.
	p.flee_left = Config.SKITTISH_FLEE_SECONDS
	p.flee_from = player.global_position


# Glum: count down to the next look-up, hold it for GLUM_LOOKUP_WINDOW.
func _look_up(p: Person, delta: float) -> void:
	if not _next_lookup.has(p):
		_next_lookup[p] = _rng.randf_range(0.0, Config.GLUM_LOOKUP_INTERVAL)
		_lookup_left[p] = 0.0
	var window: float = _lookup_left[p]
	if window > 0.0:
		window -= delta
		_lookup_left[p] = window
		p.glum_up = window > 0.0
		if window <= 0.0:
			_next_lookup[p] = (
				Config.GLUM_LOOKUP_INTERVAL + _rng.randf_range(-Config.GLUM_LOOKUP_JITTER, Config.GLUM_LOOKUP_JITTER)
			)
		return
	var next: float = _next_lookup[p] - delta
	_next_lookup[p] = next
	p.glum_up = false
	if next <= 0.0:
		_lookup_left[p] = Config.GLUM_LOOKUP_WINDOW
		p.glum_up = true
