class_name BorderLook
extends Node3D

# The look of the living border. The rules (border.gd) own the loop, the members and the gaps; this node reads them and
# draws. Round 25: the border is one ribbon through its members (see EdgeRibbon), with a real break at every gap.
# Round 26: the line itself is bent inward where it is pushed (the loop and the members move), so the ribbon needs no
# dents of its own. A subclass overrides _build, refresh and is_styled.

var subject: Border
# The ribbon as of the last rebuild (EdgeRibbon.build); tests read it.
var strips: Array[EdgeStrip] = []
# The same without the walls (0.4, #58): the gates alone, which the styled look draws as the ribbon (a wall is a hedge).
var gate_strips: Array[EdgeStrip] = []


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
	strips = EdgeRibbon.build(subject)
