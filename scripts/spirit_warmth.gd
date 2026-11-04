class_name SpiritWarmth
extends Node

# Checkpoint 5: spare spirit warms the border. When the player's spirit is full, the spirit a rescue (or any other gain)
# would have added is not wasted: it goes into a pool (SPARE_POOL_MAX) that pours out slowly, one gift every
# SPARE_WARM_INTERVAL, into the border member who is most strained (the lowest share of the joy they need), at
# SPARE_WARM_RATE joy a second in all. A person who is given joy glows softly (Person.React.WARM). The pool does not
# grow while the meter has room, so keeping spirit full early pays off in midnight, and it is not a free win: the
# rate is fixed, only members under SPARE_WARM_CEILING get any, and the pool is capped.

signal warmed(person: Person, joy: float, spirit: float)

var main: TopDownMain
# Spirit waiting to be poured out (0 .. SPARE_POOL_MAX).
var pool: float = 0.0
var _since: float = 0.0


# Builds the node under `level` and listens for spirit that did not fit. One line in TopDownMain.
static func attach(level: TopDownMain) -> SpiritWarmth:
	var w := SpiritWarmth.new()
	w.main = level
	level.add_child(w)
	level.player.spirit_spilled.connect(w.add_spare)
	return w


# `amount` of spirit did not fit in the meter: it joins the pool.
func add_spare(amount: float) -> void:
	pool = minf(pool + maxf(amount, 0.0), Config.SPARE_POOL_MAX)


func _process(delta: float) -> void:
	step(delta)


# Pours one gift when the interval has passed. Returns the joy given this call (0 when none).
func step(delta: float) -> float:
	if pool <= 0.0 or main == null or not main.running:
		_since = 0.0
		return 0.0
	_since += delta
	if _since < Config.SPARE_WARM_INTERVAL:
		return 0.0
	_since = 0.0
	return pour()


# The most strained border member under SPARE_WARM_CEILING, or null.
func most_strained() -> Person:
	var best: Person = null
	var best_frac := Config.SPARE_WARM_CEILING
	for p: Person in main.border.members:
		if not is_instance_valid(p) or not p.is_rescued:
			continue
		var frac := p.joy / maxf(p.joy_needed(), 1.0)
		if frac < best_frac:
			best_frac = frac
			best = p
	return best


# Tops up a rescued person's joy by up to `amount` (never past what they need) and they glow softly. Returns the joy
# added. A hop or glow already running (a patch, a lift) is not interrupted.
static func warm(p: Person, amount: float) -> float:
	if not p.is_rescued:
		return 0.0
	var gain := clampf(p.joy_needed() - p.joy, 0.0, amount)
	if gain <= 0.0:
		return 0.0
	p.joy += gain
	if p.react_kind == Person.React.NONE or p.react_kind == Person.React.WARM:
		p.react(Person.React.WARM, Config.SPARE_GLOW_SECONDS)
	return gain


# One gift: SPARE_WARM_RATE x SPARE_WARM_INTERVAL joy (or what the pool and the person can take) to the most strained
# member. Returns the joy given.
func pour() -> float:
	var who := most_strained()
	if who == null:
		return 0.0
	var wanted := minf(Config.SPARE_WARM_RATE * Config.SPARE_WARM_INTERVAL, pool * Config.SPARE_JOY_PER_SPIRIT)
	var gave := warm(who, wanted)  # Always above 0: they are under the ceiling and the pool is not empty.
	var spent := gave / Config.SPARE_JOY_PER_SPIRIT
	pool = maxf(pool - spent, 0.0)
	warmed.emit(who, gave, spent)
	return gave
