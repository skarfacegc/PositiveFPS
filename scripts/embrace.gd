class_name Embrace
extends Node

# Round 25 part S: embrace. A gloomy or dimmed person who is not yet rescued but stands INSIDE the border loop is lifted
# by the people around them: one stage about every EMBRACE_STEP_SECONDS (dimmed to gloomy to wistful), and a wistful
# person inside is rescued after one step. The rescue is the ordinary one: Embrace sets the person's joy to what they
# need and ticks them, so Person._rescue runs and the level's rescued handler adds the border place, the count and the
# spirit exactly as for a joy hit.
#  - "Inside" is the border's own test (BorderShape.is_inside on Border.polygon); a dimmed person pressing from outside
#    is outside, so is never embraced. Before the loop exists nobody is.
#  - Leaving the loop (walking out, or the border shrinking past them) does not wipe the step at once: the seconds
#    gathered toward the next step fade at EMBRACE_DECAY_RATE a second, so a quick step out and back loses little,
#    a long absence loses it all. Stages already lifted stay lifted (their gloom then grows back as for anyone).
#  - While someone is embraced the EMBRACE_STRAIN_COUNT border members nearest each embraced person lose
#    EMBRACE_STRAIN_RATE joy a second (Person.drain_joy, so the rescue grace and first light's no-drain still hold).
#  - Gloom does not grow on an embraced person (Person.calm_left is kept up), and a person who has just relapsed is
#    left alone for EMBRACE_RELAPSE_PAUSE seconds, so a relapse inside the loop cannot be turned into a rescue loop.
#  - First light lowers gloom for people it has passed; Embrace works from the person's CURRENT stage at each step, so
#    someone first light already lifted needs fewer steps.
# The cue is EmbraceCue (a warm glow and a filling ring, placeholder look). Time is the fixed-step delta throughout.

signal started(person: Person)
signal lifted(person: Person, from_level: int, to_level: int)
signal rescued_by_embrace(person: Person, seconds: float)


# One embraced person: seconds gathered toward the next step, seconds since the embrace began, the cue node.
class Entry:
	extends RefCounted
	var progress: float = 0.0
	var age: float = 0.0
	var inside: bool = false
	var cue: EmbraceCue = null


var main: TopDownMain
var entries: Dictionary = {}  # Person -> Entry
# Totals for the night (tests and the recorder's summary).
var start_count: int = 0
var lift_count: int = 0
var rescue_count: int = 0
var _pause: Dictionary = {}  # Person -> seconds left before they can be embraced again (after a relapse).
var _clock: float = 0.0


# Builds the node under `level` and listens for relapses. One line in TopDownMain.
static func attach(level: TopDownMain) -> Embrace:
	var e := Embrace.new()
	e.main = level
	level.add_child(e)
	for p: Person in level.people:
		p.relapsed.connect(e._on_relapsed.bind(p))
	return e


func _process(delta: float) -> void:
	if main != null and main.running:
		step(delta)


# True when `p` stands inside the border loop and is not rescued.
func is_inside(p: Person) -> bool:
	var at := p.global_position
	return BorderShape.is_inside(main.border.polygon, Vector2(at.x, at.z))


# Number of people being embraced right now (inside the loop with an entry).
func embraced_count() -> int:
	var n := 0
	for e: Entry in entries.values():
		if e.inside:
			n += 1
	return n


# Progress (0..1) toward the next stage for `p`, or 0 when they are not being embraced.
func progress_of(p: Person) -> float:
	if not entries.has(p):
		return 0.0
	var e: Entry = entries[p]
	return clampf(e.progress / Config.EMBRACE_STEP_SECONDS, 0.0, 1.0)


# One frame: gathers or fades each person's step, lifts or rescues, strains the nearest members, moves the cues.
func step(delta: float) -> void:
	_clock += delta
	_tick_pauses(delta)
	for p: Person in main.people:
		if p.is_rescued:
			if entries.has(p):
				_drop(p)
			continue
		var inside := _eligible(p)
		if inside and not entries.has(p):
			_begin(p)
		if entries.has(p):
			var e: Entry = entries[p]
			_advance(p, e, inside, delta)
	_strain(delta)


func _eligible(p: Person) -> bool:
	return not _pause.has(p) and is_inside(p)


func _begin(p: Person) -> void:
	var e := Entry.new()
	e.cue = EmbraceCue.new()
	p.add_child(e.cue)
	entries[p] = e
	start_count += 1
	started.emit(p)


func _advance(p: Person, e: Entry, inside: bool, delta: float) -> void:
	e.inside = inside
	e.age += delta
	if inside:
		e.progress += delta
		p.calm_left = maxf(p.calm_left, Config.EMBRACE_CALM)
		if e.progress >= Config.EMBRACE_STEP_SECONDS:
			e.progress -= Config.EMBRACE_STEP_SECONDS
			_finish_step(p, e)
			if p.is_rescued:
				return
	else:
		e.progress = maxf(0.0, e.progress - Config.EMBRACE_DECAY_RATE * delta)
		if e.progress <= 0.0:
			_drop(p)
			return
	e.cue.show_progress(e.progress / Config.EMBRACE_STEP_SECONDS, inside, _clock)


# One step is complete: a stage lifts, or (at wistful) the person is rescued.
func _finish_step(p: Person, e: Entry) -> void:
	var from_level := Config.gloom_level(p.gloom)
	if from_level > 0:
		var to_level := from_level - 1
		var lo := 0.0 if to_level == 0 else Config.GLOOM_LEVEL_STEPS[to_level - 1]
		p.gloom = minf(p.gloom, (lo + Config.GLOOM_LEVEL_STEPS[to_level]) * 0.5)
		p.joy = minf(p.joy, p.joy_needed() * Config.EMBRACE_JOY_CAP)
		lift_count += 1
		lifted.emit(p, from_level, to_level)
		return
	# Wistful: the ordinary rescue. Joy to what they need, and a zero-length tick runs Person's own check.
	var seconds := e.age
	p.joy = p.joy_needed()
	p.tick(0.0)
	if p.is_rescued:
		rescue_count += 1
		rescued_by_embrace.emit(p, seconds)
		_drop(p)


func _drop(p: Person) -> void:
	var e: Entry = entries.get(p)
	if e != null and e.cue != null and is_instance_valid(e.cue):
		e.cue.queue_free()
	entries.erase(p)


# The nearest EMBRACE_STRAIN_COUNT border members to each embraced person share a small extra drain.
func _strain(delta: float) -> void:
	var amount := Config.EMBRACE_STRAIN_RATE * delta
	var hit: Dictionary = {}
	for p: Person in entries:
		if not (entries[p] as Entry).inside:
			continue
		for m: Person in nearest_members(p, Config.EMBRACE_STRAIN_COUNT):
			hit[m] = true
	for m: Person in hit:
		m.drain_joy(amount)


# Up to `count` rescued border members nearest to `p`, nearest first (ties keep the border's own order).
func nearest_members(p: Person, count: int) -> Array[Person]:
	var found: Array[Person] = []
	var dists: Array[float] = []
	for m: Person in main.border.members:
		var d := GloomSim.flat_dist(m.global_position, p.global_position)
		var at := dists.size()
		while at > 0 and dists[at - 1] > d:
			at -= 1
		if at >= count:
			continue
		found.insert(at, m)
		dists.insert(at, d)
		if found.size() > count:
			found.pop_back()
			dists.pop_back()
	return found


func _on_relapsed(p: Person) -> void:
	_pause[p] = Config.EMBRACE_RELAPSE_PAUSE
	_drop(p)


func _tick_pauses(delta: float) -> void:
	for p: Person in _pause.keys():
		var left: float = _pause[p] - delta
		if left <= 0.0:
			_pause.erase(p)
		else:
			_pause[p] = left
