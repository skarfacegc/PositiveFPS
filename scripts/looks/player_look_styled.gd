class_name PlayerLookStyled
extends PlayerLook

# The styled player (see StylePeople.build_player): wide-brim felt hat with a teal band and a glowing feather, saffron
# coat, teal scarf, satchel with three glowing tubes, a gold double ring and a soft glow on the ground. The outer
# ring takes the colour of the target's element (cream with no target), as the placeholder ring does.

# Checkpoint 6: a dust puff at each footfall of a run (colours and ring look of the dust puffs).
const DUST_FILL := Color("#e9dcc0")
const DUST_RIM := Color("#fff8ea")
const DUST_DENSITY := 0.5
const DUST_RIM_WIDTH := 0.18

# How many dust puffs were raised (the tests read it).
var puffs_started: int = 0

var _ring: MeshInstance3D
var _last_affinity: int = -2
var _parts: Dictionary = {}
# The half cycle (one footfall) last seen.
var _last_step: int = -1


func is_styled() -> bool:
	return true


func sync() -> void:
	var aff := -1 if subject.target == null else subject.target.affinity
	if aff == _last_affinity:
		return
	_last_affinity = aff
	var col := PlayerConfig.TD_NO_TARGET_COLOR if aff < 0 else Config.ELEMENT_COLORS[aff]
	_ring.material_override = StyleKit.mat(col, 0, 0.0, 0.8)


# Graphics checkpoint 5: the joy burst is two gold rings that open from the feet (the second a beat behind) and
# thin away, with an ink pixel and a pale rim, instead of the placeholder's flat translucent disc.
func play_burst(radius: float, duration: float) -> void:
	var parent := subject.get_parent()
	if parent == null:
		return
	for k: int in range(2):
		var ring := StyleFight.ring_node(parent, 0.82 if k == 0 else 0.6, StyleFight.GOLD, StyleFight.GOLD_RIM, 0.7)
		ring.visible = true
		ring.global_position = Vector3(subject.global_position.x, 0.09 + 0.01 * k, subject.global_position.z)
		ring.scale = Vector3(0.3, 1.0, 0.3)
		var mat := ring.material_override as ShaderMaterial
		mat.set_shader_parameter("rim_width", 0.05)
		var set_fade := func(v: float) -> void: mat.set_shader_parameter("fade", v)
		var reach := radius * (1.0 if k == 0 else 0.7)
		var t := ring.create_tween()
		t.set_parallel(true)
		t.tween_property(ring, "scale", Vector3(reach, 1.0, reach), duration).set_delay(0.12 * k)
		t.tween_method(set_fade, 1.0, 0.0, duration).set_delay(0.12 * k)
		t.chain().tween_callback(ring.queue_free)


func _build_body() -> void:
	var model := Node3D.new()
	# The model faces +z; the player faces -z.
	model.rotation.y = PI
	add_child(model)
	StylePeople.build_player(model, _parts)
	_ring = _parts["ring"]
	sync()


func _pose_gait() -> void:
	StyleWalk.apply(gait, _parts)
	# Each half cycle is one footfall (the two legs take turns).
	var step := floori(gait.phase * 2.0)
	if step == _last_step:
		return
	var was := _last_step
	_last_step = step
	if was >= 0 and gait.run >= StyleConfig.JOG_DUST_MIN_RUN and gait.move > 0.5:
		_dust(step)


# A flat puff on the ground under the foot that just came down (the left or the right, by the half cycle).
func _dust(step: int) -> void:
	var parent := subject.get_parent()
	if parent == null:
		return
	var side := 1.0 if step == 0 else -1.0
	var at := subject.global_position + subject.global_transform.basis.x * StyleConfig.JOG_DUST_SIDE * side
	var puff := StyleFight.ring_node(parent, 0.0, DUST_FILL, DUST_RIM, DUST_DENSITY)
	StyleFight.set_ring(puff, DUST_FILL, DUST_DENSITY, DUST_RIM_WIDTH)
	puff.visible = true
	puff.global_position = Vector3(at.x, 0.05, at.z)
	puff.scale = Vector3(0.15, 1.0, 0.15)
	var mat := puff.material_override as ShaderMaterial
	var set_fade := func(v: float) -> void: mat.set_shader_parameter("fade", v)
	var t := puff.create_tween()
	t.set_parallel(true)
	var reach := StyleConfig.JOG_DUST_RADIUS
	t.tween_property(puff, "scale", Vector3(reach, 1.0, reach), StyleConfig.JOG_DUST_SECONDS)
	t.tween_method(set_fade, 1.0, 0.0, StyleConfig.JOG_DUST_SECONDS)
	t.chain().tween_callback(puff.queue_free)
	puffs_started += 1
