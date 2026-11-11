class_name Landmarks
extends Node3D

# Round 19: the level's landmarks and what they give. Owns the Landmark nodes (`items`, in LandmarkConfig.LANDMARK_NAMES
# order: bandstand, garden, bell tower, gallery), updates their holds from the border, applies the boosts to the people
# and makes the lines of the HUD panel. (0.3.3: the gallery can be placed and claimed but gives nothing yet.)
#   Bandstand: music joy x LANDMARK_MUSIC_MULT.   Garden: nature joy x LANDMARK_NATURE_MULT.
#   Bell tower: border members within LANDMARK_BELL_RADIUS take x LANDMARK_BELL_LOSS_MULT of the gloom's drain.
# A boost applies only while its landmark is held; the next update after the border drops it takes it away.

# Walls and gates: Defences (#16). A landmark's defence type was unlocked by claiming it, for the rest of the night.
signal defence_unlocked(index: int)

const BANDSTAND := 0
const GARDEN := 1
const BELL_TOWER := 2
const GALLERY := 3

var items: Array[Landmark] = []
# Walls and gates: Defences (#16). The landmarks claimed so far, in the order they were claimed (a landmark that is
# lost again stays unlocked).
var unlock_order: Array[int] = []


# Creates the landmark nodes (call once, after adding this node to the level).
func build() -> void:
	for i: int in range(LandmarkConfig.LANDMARK_NAMES.size()):
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
		if lm.is_held():
			unlock(lm.index)


# Walls and gates: Defences (#16). Unlocks the defence of landmark `index` (once). Returns true when it was new.
func unlock(index: int) -> bool:
	if index < 0 or index >= items.size() or unlock_order.has(index):
		return false
	unlock_order.append(index)
	defence_unlocked.emit(index)
	return true


func is_unlocked(index: int) -> bool:
	return unlock_order.has(index)


# The unlocked defence types in landmark order.
func unlocked_types() -> Array[int]:
	var out: Array[int] = []
	for i: int in range(items.size()):
		if unlock_order.has(i):
			out.append(i)
	return out


# The most recently unlocked type, or -1 when none is.
func last_unlocked() -> int:
	return -1 if unlock_order.is_empty() else unlock_order[unlock_order.size() - 1]


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
	var music := LandmarkConfig.LANDMARK_MUSIC_MULT if is_held(BANDSTAND) else 1.0
	var nature := LandmarkConfig.LANDMARK_NATURE_MULT if is_held(GARDEN) else 1.0
	var bell := is_held(BELL_TOWER)
	var bell_at := LandmarkConfig.LANDMARK_POSITIONS[BELL_TOWER]
	for p: Person in people:
		p.joy_boost[Config.Element.MUSIC] = music
		p.joy_boost[Config.Element.NATURE] = nature
		var covered := (
			bell and border.members.has(p) and _flat(p.position, bell_at) <= LandmarkConfig.LANDMARK_BELL_RADIUS
		)
		p.loss_mult = LandmarkConfig.LANDMARK_BELL_LOSS_MULT if covered else 1.0


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
	for at: Vector3 in LandmarkConfig.LANDMARK_POSITIONS:
		if _flat(pos, at) <= radius:
			return true
	return false


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
