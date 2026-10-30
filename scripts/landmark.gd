class_name Landmark
extends Node3D

# One of the level's landmarks (round 19: bandstand, garden, bell tower; see Config.LANDMARK_*). Its block is built by
# TopDownMain (an obstacle like the others); this node holds the rules (the claim hold) and its look draws the
# pillar and the hold ring (see scripts/looks/landmark_look.gd). The ring is a fixed outline with a disc inside that
# grows with the hold progress, so the player can see how long is left.

# The landmark was claimed (held for BORDER_LANDMARK_HOLD seconds) or lost (the border dropped it after holding it).
signal claimed
signal lost

# Which landmark this is: an index into Config.LANDMARK_NAMES / _POSITIONS / _BOOST_TEXT. Set before add_child.
var index: int = 0
# Seconds the landmark has been held (beautified and inside the border). Resets when it is lost.
var hold: float = 0.0
# True while the landmark block is beautified (the argument of the last update).
var beautified: bool = false
var look: LandmarkLook
var _was_held: bool = false


func _ready() -> void:
	position = Config.LANDMARK_POSITIONS[index]
	_make_look()


# Swaps the look in place (F4).
func rebuild_look() -> void:
	if look != null:
		remove_child(look)
		look.queue_free()
	_make_look()


func landmark_name() -> String:
	return Config.LANDMARK_NAMES[index]


# What holding it gives, such as "music joy x1.5".
func boost_text() -> String:
	return Config.LANDMARK_BOOST_TEXT[index]


# Round 20: the notice when it is claimed, and when the border drops it (names the boost that is gained or lost).
func claim_text() -> String:
	return "Claimed the %s: %s" % [landmark_name(), boost_text()]


func loss_text() -> String:
	return "Lost the %s boost: %s" % [landmark_name(), boost_text()]


# Holds the landmark: while `is_beautified` (the landmark block is inside the border) the hold grows, otherwise it
# resets (and the boost goes at once). Emits `claimed` and `lost` when the held state flips.
func update(delta: float, is_beautified: bool) -> void:
	beautified = is_beautified
	if is_beautified:
		hold = minf(hold + delta, Config.BORDER_LANDMARK_HOLD)
	else:
		hold = 0.0
	var held := is_held()
	if held != _was_held:
		_was_held = held
		if held:
			claimed.emit()
		else:
			lost.emit()
		if look != null:
			look.play_change(held)  # Round 20: the landmark itself reacts to the change (a pulse, placeholder look).
	if look != null:
		look.sync()


# How much of the hold is done, 0 to 1.
func progress() -> float:
	return hold / Config.BORDER_LANDMARK_HOLD


# True once the landmark has been held for BORDER_LANDMARK_HOLD seconds.
func is_held() -> bool:
	return hold >= Config.BORDER_LANDMARK_HOLD


func _make_look() -> void:
	look = Looks.landmark_look()
	add_child(look)
	look.setup(self)
