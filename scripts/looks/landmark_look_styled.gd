class_name LandmarkLookStyled
extends LandmarkLook

# The styled landmark (graphics checkpoint 3): its own building in the locked style (see StyleLandmarks) instead of the
# generic kiosk. Unheld it is a grey, weathered, still ruin; the claim hold blends it into the warm version as the
# hold grows, and once held it is lit and alive: a gold beam, a lit ring and a small cue of its boost (drifting notes
# over the bandstand, petals over the garden, a swinging bell and a soft calming ring round the bell tower). The label
# carries the real name.

const INK := Color("#3a2a20")
const CREAM := Color("#fff3c4")
const UNHELD_RING := Color("#8d95a1")
const HELD_RING := Color("#ffe08a")
const MOTES := 6
const BELL_RING_FADE_SECONDS := 3.0
const PULSE_RADIUS := 8.0
const PULSE_SECONDS := 1.2

var ruin: Node3D
var alive: Node3D
var _glow: MeshInstance3D
var _glow_mat: ShaderMaterial
var _label: Label3D
var _ring_mat: ShaderMaterial
var _beam: MeshInstance3D
var _parts: Dictionary = {}
var _motes: Array[MeshInstance3D] = []
var _calm_ring: MeshInstance3D
var _calm_mat: ShaderMaterial
var _pulse_ring: MeshInstance3D
var _pulse_mat: ShaderMaterial
var _applied: float = -1.0
var _held: bool = false


func is_styled() -> bool:
	return true


func sync() -> void:
	if _glow == null:
		return
	var frac := subject.progress()
	_glow.visible = frac > 0.0
	_glow.scale = Vector3(maxf(frac, 0.01), 1.0, maxf(frac, 0.01)) * (RING_INNER / 2.5)
	var shown := subject.beautified or subject.hold > 0.0
	var held := subject.is_held()
	var title := subject.landmark_name()
	if held:
		_label.text = "%s: %s" % [title, subject.boost_text()]
	elif shown:
		_label.text = "%s %d%%" % [title, roundi(frac * 100.0)]
	else:
		_label.text = title
	if not is_equal_approx(frac, _applied):
		_applied = frac
		_set_dissolve(ruin, frac)
		_set_dissolve(alive, frac)
		ruin.visible = frac < 1.0
		alive.visible = frac > 0.0
	if held != _held:
		_held = held
		_show_held(held)
	if held:
		_animate(float(Engine.get_process_frames()) / 60.0)


# Graphics checkpoint 4: a claim sends a gold ring out from the landmark (and the beam flares); a loss sends a
# grey-violet ring with a coral rim in toward it. The ring is a short-lived node in the "landmark_pulse" group.
func play_change(held: bool) -> void:
	var fill := Color("#ffe08a") if held else Color("#9c97ad")
	var rim := Color("#fffbe8") if held else Color("#e8453b")
	var mat := StyleCues.ring_material(fill, rim, 0.55, 0.78)
	mat.set_shader_parameter("rim_width", 0.035)
	var ring := MeshInstance3D.new()
	ring.mesh = StyleCues.ring_mesh()
	ring.material_override = mat
	ring.position = Vector3(0, 0.1, 0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_to_group("landmark_pulse")
	add_child(ring)
	var from_r := 1.5 if held else PULSE_RADIUS
	var to_r := PULSE_RADIUS if held else 1.5
	ring.scale = Vector3(from_r, 1.0, from_r)
	var set_fade := func(v: float) -> void: mat.set_shader_parameter("fade", v)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector3(to_r, 1.0, to_r), PULSE_SECONDS)
	t.tween_method(set_fade, 1.0, 0.0, PULSE_SECONDS)
	t.chain().tween_callback(ring.queue_free)


# True while the held cues (beam, lit ring, boost cue) are on.
func is_lit() -> bool:
	return _held


func _build() -> void:
	ruin = Node3D.new()
	add_child(ruin)
	StyleLandmarks.build(ruin, subject.index, true)
	alive = Node3D.new()
	add_child(alive)
	_parts = StyleLandmarks.build(alive, subject.index, false)
	_ring_mat = StyleKit.unique_mat(UNHELD_RING, 0.0)
	var ring := StyleKit.torus(self, RING_INNER, RING_OUTER, Vector3(0, 0.08, 0), _ring_mat)
	ring.scale = Vector3(1.0, 0.3, 1.0)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glow_mat = StyleKit.glow_mat(Color(1.0, 0.82, 0.38), 0.9)
	_glow = StyleKit.glow_plane(self, _glow_mat, 5.0, Vector3(0, 0.06, 0))
	var gold := StyleKit.mat(StyleKit.hexc("#ffe08a"), 0, 0.0, 1.4)
	var height := Config.LANDMARK_SIZES[subject.index].y
	_beam = StyleKit.cyl(self, 0.15, 9.0, Vector3(0, height + 4.5, 0), gold, Vector3.ZERO, -1.0, 6, false)
	_beam.visible = false
	_build_cue()
	_label = Label3D.new()
	_label.position = Vector3(0, height + 9.6, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.pixel_size = 0.012
	_label.no_depth_test = true
	_label.modulate = CREAM
	_label.outline_modulate = INK
	_label.outline_size = 36
	add_child(_label)
	_show_held(false)


# The boost cue: drifting motes (notes or petals) for the bandstand and the garden, a ring for the bell tower.
func _build_cue() -> void:
	if subject.index == Landmarks.BELL_TOWER:
		var r := Config.LANDMARK_BELL_RADIUS
		_calm_mat = StyleCues.ring_material(Color("#ffe9a8"), Color("#fffbe8"), 0.12, 0.96)
		_calm_ring = _flat_ring(_calm_mat, r)
		_pulse_mat = StyleCues.ring_material(Color("#ffe9a8"), Color("#fffbe8"), 0.3, 0.9)
		_pulse_ring = _flat_ring(_pulse_mat, r * 0.2)
		return
	var hexes: Array[String] = ["#ffd466", "#e8736a", "#fff3c4"]
	if subject.index == Landmarks.GARDEN:
		hexes = ["#e8736a", "#c9a0dc", "#f6ecd8"]
	for k: int in range(MOTES):
		var mote_m := StyleKit.mat(StyleKit.hexc(hexes[k % hexes.size()]), 0, 0.0, 1.1)
		var mote := StyleKit.sph(self, 0.14, Vector3(0, 3, 0), mote_m, Vector3(1.0, 0.8, 1.0), 6, false)
		mote.visible = false
		_motes.append(mote)


func _flat_ring(mat: ShaderMaterial, radius: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	ring.mesh = StyleCues.ring_mesh()
	ring.material_override = mat
	ring.position = Vector3(0, 0.05, 0)
	ring.scale = Vector3(radius, 1.0, radius)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.visible = false
	add_child(ring)
	return ring


# Lights or dims the cues that belong to the held state.
func _show_held(held: bool) -> void:
	_beam.visible = held
	_ring_mat.set_shader_parameter("albedo", HELD_RING if held else UNHELD_RING)
	_ring_mat.set_shader_parameter("emit", 1.2 if held else 0.0)
	for mote: MeshInstance3D in _motes:
		mote.visible = held
	if _calm_ring != null:
		_calm_ring.visible = held
		_pulse_ring.visible = held
	var lamp: MeshInstance3D = _parts.get("lamp")
	if lamp != null:
		lamp.visible = held


# Moves the held cues: motes rise and drift, the bell swings, the calming ring pulses outward.
func _animate(t: float) -> void:
	var height := Config.LANDMARK_SIZES[subject.index].y
	for k: int in range(_motes.size()):
		var phase := fposmod(t * 0.22 + float(k) / float(MOTES), 1.0)
		var a := t * 0.5 + TAU * float(k) / float(MOTES)
		var r := 1.4 + 0.5 * sin(t + float(k))
		_motes[k].position = Vector3(cos(a) * r, 1.2 + phase * (height + 2.0), sin(a) * r)
		_motes[k].scale = Vector3.ONE * (1.0 - absf(phase * 2.0 - 1.0) * 0.7)
	var bell: Node3D = _parts.get("bell")
	if bell != null:
		bell.rotation.z = sin(t * 2.4) * 0.35
	if _pulse_ring != null:
		var u := fposmod(t / BELL_RING_FADE_SECONDS, 1.0)
		var r := Config.LANDMARK_BELL_RADIUS * (0.2 + 0.8 * u)
		_pulse_ring.scale = Vector3(r, 1.0, r)
		_pulse_mat.set_shader_parameter("fade", 1.0 - u)


# Sets the dissolve (0 ruin .. 1 alive) on every mesh of a version.
func _set_dissolve(root: Node3D, amount: float) -> void:
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).set_instance_shader_parameter("dissolve", amount)
