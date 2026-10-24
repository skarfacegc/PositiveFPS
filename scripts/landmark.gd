class_name Landmark
extends Node3D

# The level's landmark: a taller block with a beacon pillar, away from the start. Its block is built by TopDownMain
# (it is an obstacle like the others); this node holds the rules (the hold timer) and its look draws the beacon and the
# hold ring (see scripts/looks/landmark_look.gd). The ring is a fixed outline with a disc inside it that grows with the
# hold progress, so the player can see how long is left.

# Seconds the landmark has been held (beautified and inside the border). Resets when it is lost.
var hold: float = 0.0
# True while the landmark block is beautified (the argument of the last update).
var beautified: bool = false
var look: LandmarkLook


func _ready() -> void:
	position = Config.BORDER_LANDMARK_POS
	_make_look()


# Swaps the look in place (F4).
func rebuild_look() -> void:
	if look != null:
		remove_child(look)
		look.queue_free()
	_make_look()


# Holds the landmark: while `is_beautified` (the landmark block is inside the border) the hold grows, otherwise it
# resets.
func update(delta: float, is_beautified: bool) -> void:
	beautified = is_beautified
	if is_beautified:
		hold = minf(hold + delta, Config.BORDER_LANDMARK_HOLD)
	else:
		hold = 0.0
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
