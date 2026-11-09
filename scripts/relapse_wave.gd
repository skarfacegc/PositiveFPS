class_name RelapseWave
extends RefCounted

# Round 24: the gate a wobbling person asks before relapsing (Person.relapse_gate). Only one person may relapse per
# RELAPSE_GATE_GAP seconds, so a group that was drained together goes a few at a time (and each of them stays
# catchable by a joy hit until their turn comes). The level calls `advance` once a frame.

var _clock: float = 0.0
var _last: float = -INF


func advance(delta: float) -> void:
	_clock += delta


# True (and takes the slot) when enough time has passed since the last relapse.
func allow() -> bool:
	if _clock - _last < PeopleConfig.RELAPSE_GATE_GAP:
		return false
	_last = _clock
	return true
