class_name CoverUpdate
extends RefCounted

# Works out every person's cover and protection every GROUND_UPDATE_INTERVAL. With a border, cover is how far inside
# the loop a person is (see Border.cover_at). Before the border forms it is the paint around them (round 8 rules): a
# rescued person's cover leaves out their own paint, so only other people's paint protects them.
# TopDownMain builds it as `cover_update`.

# Seconds since the cover was last worked out. It is refreshed every GROUND_UPDATE_INTERVAL.
var _timer := 0.0
var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


func update(delta: float) -> void:
	_timer += delta
	if _timer < GroundConfig.GROUND_UPDATE_INTERVAL:
		return
	_timer = 0.0
	var border := _main.border
	var ground := _main.ground
	for p: Person in _main.people:
		if border.active:
			p.cover = border.cover_at(p.global_position)
			p.protection = p.cover
		elif p.is_rescued:
			p.cover = ground.average_weight_excluding(p.global_position, GroundConfig.TD_COVER_RADIUS, p)
			p.protection = GloomSim.protection_for(p.cover)
		else:
			p.cover = ground.average_weight(p.global_position, GroundConfig.TD_COVER_RADIUS)
			p.protection = GloomSim.protection_for(p.cover)
