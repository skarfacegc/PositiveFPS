class_name TopDownTestUtil
extends RefCounted

# Helpers shared by the top-down test suites. It has no test_ functions, so gdUnit does not run it as a suite.

const SCENE := "res://topdown.tscn"
# Where people are parked while a test is not using them: far from the player and out of the way.
const FAR := Vector3(30, 0, -30)


# Parks every person far away, so only the people a test places can take part.
static func send_everyone_away(td: TopDownMain) -> void:
	for p: Person in td.people:
		p.global_position = FAR


# Puts a person on the floor at `spot` with the given affinity (0 music, 1 art, 2 nature) and gloom level.
static func place(p: Person, spot: Vector3, affinity: int, gloom: float) -> void:
	p.affinity = affinity
	p.gloom = gloom
	p.joy = 0.0
	p.global_position = Vector3(spot.x, 0.0, spot.z)


# The screen position of the floor point under `spot`. A mouse there aims (or clicks) that spot.
static func screen_of(td: TopDownMain, spot: Vector3) -> Vector2:
	return td.camera.unproject_position(Vector3(spot.x, 0.0, spot.z))


# Every joy projectile currently in the level.
static func projectiles(td: TopDownMain) -> Array[JoyProjectile]:
	var out: Array[JoyProjectile] = []
	for child: Node in td.get_children():
		if child is JoyProjectile:
			out.append(child as JoyProjectile)
	return out


# Every bloom currently in the level.
static func blooms(td: TopDownMain) -> Array[Bloom]:
	var out: Array[Bloom] = []
	for child: Node in td.get_children():
		if child is Bloom:
			out.append(child as Bloom)
	return out
