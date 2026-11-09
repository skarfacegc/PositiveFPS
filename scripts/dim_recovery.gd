class_name DimRecovery
extends RefCounted

# Round 12a: a dim player recovers spirit only inside the border (or near a landmark before a border exists), and a
# dim player makes the border and the paint lose ground faster. TopDownMain builds it as `dim_recovery`.

var _main: TopDownMain


func _init(main: TopDownMain) -> void:
	_main = main


func update(delta: float) -> void:
	_main.border.set_player_dim(_main.player.is_dim)
	_main.ground.loss_mult = _main.border.loss_mult
	if _main.player.is_dim:
		_main.player.add_spirit(rate() * delta)


# Spirit per second the dim player recovers where they stand: DIM_RECOVER_RATE times (DIM_RECOVER_BASE plus
# DIM_RECOVER_DEPTH times the depth protection) inside the border, nothing outside it. Before any border exists, the
# full rate within LANDMARK_RECOVER_RADIUS of any landmark.
func rate() -> float:
	var border := _main.border
	var pos := _main.player.global_position
	if border.active:
		if not BorderShape.is_inside(border.polygon, Vector2(pos.x, pos.z)):
			return 0.0
		var depth := border.cover_at(pos)
		return SpiritConfig.DIM_RECOVER_RATE * (SpiritConfig.DIM_RECOVER_BASE + SpiritConfig.DIM_RECOVER_DEPTH * depth)
	if Landmarks.near_any(pos, SpiritConfig.LANDMARK_RECOVER_RADIUS):
		return SpiritConfig.DIM_RECOVER_RATE
	return 0.0
