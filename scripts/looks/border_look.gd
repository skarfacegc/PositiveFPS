class_name BorderLook
extends Node3D

# The look of the living border. The rules (border.gd) own the loop, the members and the gaps; this node reads them and
# draws. Round 25: the border is one ribbon through its members (see EdgeRibbon), with a real break at every gap and
# inward dents where dimmed people press. A subclass overrides _build, refresh and is_styled.

var subject: Border
# Round 25: the ground positions of the dimmed people pressing on the line (EdgeRibbon.pressers), refreshed by GapPatch.
var pressers := PackedVector2Array()
# The ribbon as of the last rebuild (EdgeRibbon.build); tests read it.
var strips: Array[EdgeStrip] = []


func setup(border: Border) -> void:
	subject = border
	_build()


# True for the styled look.
func is_styled() -> bool:
	return false


# Redraws from the border's current state. Called by the border every update.
func refresh() -> void:
	pass


func _build() -> void:
	pass


# Works out the ribbon again (the looks do it every EDGE_RIBBON_REBUILD_FRAMES frames, not every frame).
func _rebuild_strips() -> void:
	strips = EdgeRibbon.build(subject, pressers)
