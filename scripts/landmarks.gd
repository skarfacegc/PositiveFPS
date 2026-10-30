class_name Landmarks
extends Node3D

# Round 19: the level's three landmarks and what they give. Owns the Landmark nodes (`items`, in Config.LANDMARK_NAMES
# order: bandstand, garden, bell tower), updates their holds from the border, applies the boosts to the people and
# makes the lines of the HUD panel.
#   Bandstand: music joy x LANDMARK_MUSIC_MULT.   Garden: nature joy x LANDMARK_NATURE_MULT.
#   Bell tower: border members within LANDMARK_BELL_RADIUS take x LANDMARK_BELL_LOSS_MULT of the gloom's drain.
# A boost applies only while its landmark is held; the next update after the border drops it takes it away.

const BANDSTAND := 0
const GARDEN := 1
const BELL_TOWER := 2

var items: Array[Landmark] = []


# Creates the landmark nodes (call once, after adding this node to the level).
func build() -> void:
	for i: int in range(Config.LANDMARK_NAMES.size()):
		var lm := Landmark.new()
		lm.index = i
		add_child(lm)
		items.append(lm)


# Swaps every look in place (F4).
func rebuild_look() -> void:
	for lm: Landmark in items:
		lm.rebuild_look()


# Every frame: each landmark's hold follows whether the border has beautified its block.
func update(delta: float, border: Border) -> void:
	for lm: Landmark in items:
		lm.update(delta, border.landmark_beautified(lm.index))


func is_held(index: int) -> bool:
	return index >= 0 and index < items.size() and items[index].is_held()


func held_count() -> int:
	var n := 0
	for lm: Landmark in items:
		if lm.is_held():
			n += 1
	return n


# Sets the boosts on everyone: the joy multiplier of each element and the bell tower's loss multiplier.
func apply_boosts(people: Array[Person], border: Border) -> void:
	var music := Config.LANDMARK_MUSIC_MULT if is_held(BANDSTAND) else 1.0
	var nature := Config.LANDMARK_NATURE_MULT if is_held(GARDEN) else 1.0
	var bell := is_held(BELL_TOWER)
	var bell_at := Config.LANDMARK_POSITIONS[BELL_TOWER]
	for p: Person in people:
		p.joy_boost[Config.Element.MUSIC] = music
		p.joy_boost[Config.Element.NATURE] = nature
		var covered := bell and border.members.has(p) and _flat(p.position, bell_at) <= Config.LANDMARK_BELL_RADIUS
		p.loss_mult = Config.LANDMARK_BELL_LOSS_MULT if covered else 1.0


# Which landmarks are held, in order (for the minimap).
func held_flags() -> Array[bool]:
	var flags: Array[bool] = []
	for lm: Landmark in items:
		flags.append(lm.is_held())
	return flags


# The HUD panel's lines: one per held landmark, with its boost.
func held_lines() -> Array[String]:
	var lines: Array[String] = []
	for lm: Landmark in items:
		if lm.is_held():
			lines.append("%s: %s" % [lm.landmark_name(), lm.boost_text()])
	return lines


# True when `pos` is within `radius` of any landmark.
static func near_any(pos: Vector3, radius: float) -> bool:
	for at: Vector3 in Config.LANDMARK_POSITIONS:
		if _flat(pos, at) <= radius:
			return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
