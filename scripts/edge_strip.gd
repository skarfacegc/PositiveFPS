class_name EdgeStrip
extends RefCounted

# Round 25: one unbroken run of the border ribbon (see EdgeRibbon). The arrays are parallel: one entry per point.

var pts := PackedVector2Array()
# Strain 0..1 at each point (colour and width), how much of the point lies on a stretch sealed by the map edge, and how
# faded it is (a retreating arm).
var strain := PackedFloat32Array()
var seal := PackedFloat32Array()
var fade := PackedFloat32Array()
# True for a loop with no gap: the last point joins the first.
var closed: bool = false


func add(p: Vector2, strain_at: float, seal_at: float, fade_at: float) -> void:
	pts.append(p)
	strain.append(strain_at)
	seal.append(seal_at)
	fade.append(fade_at)


func size() -> int:
	return pts.size()


# The point before and after `i` (wrapping on a closed strip, clamped on an open one).
func neighbours(i: int) -> Array[Vector2]:
	var m := pts.size()
	if closed:
		return [pts[(i - 1 + m) % m], pts[(i + 1) % m]]
	return [pts[maxi(i - 1, 0)], pts[mini(i + 1, m - 1)]]
