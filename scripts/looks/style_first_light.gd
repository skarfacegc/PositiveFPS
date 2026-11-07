class_name StyleFirstLight
extends RefCounted

# Graphics checkpoint 5: first light in the locked style. FirstLight (the rules and the placeholder ring)
# hands the front's position to this each frame in the styled look. The front is drawn by the ground itself
# (shaders/style_ground.gdshader: `dawn_front` warms the cobbles behind the front, lays a pale line on it and
# twinkles a few glints just behind), so it follows the true round front exactly (checkpoint 6: a circle).
# On top of that sit light motes that rise from the lit side of the front (a MultiMesh, only the stretch near
# the player), and the view's sky warms toward the peach of dawn as the front moves in. Pure visuals: the rules
# never read it.

const STEP := 1.35  # Metres between two motes along the front.
const SPAN := 24.0  # How far each side of the player the motes are laid.
const MOTE := Color("#ffe9a0")

var root: Node3D
var _motes: MultiMeshInstance3D
var _multi: MultiMesh
var _placed := PackedVector3Array()  # Where each shown mote was put this frame (the tests read it).


# Builds the motes under `parent`.
func build(parent: Node3D) -> void:
	root = Node3D.new()
	root.top_level = true
	parent.add_child(root)
	var mesh := SphereMesh.new()
	mesh.radius = 0.09
	mesh.height = 0.18
	mesh.radial_segments = 4
	mesh.rings = 2
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.mesh = mesh
	# Room for every mote of the whole circle (one per STEP metres of the starting circle, the most it ever lays).
	_multi.instance_count = ceili(TAU * Config.FIRST_LIGHT_START_RADIUS / STEP) + 4
	_multi.visible_instance_count = 0
	_motes = MultiMeshInstance3D.new()
	_motes.multimesh = _multi
	_motes.material_override = StyleKit.mat(MOTE, 0, 0.0, 2.2)
	_motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_motes.extra_cull_margin = 200.0
	root.add_child(_motes)


func hide() -> void:
	_multi.visible_instance_count = 0
	_placed.clear()


# The mote positions laid by the last sync (for the tests).
func mote_positions() -> PackedVector3Array:
	return _placed


# The number of motes showing (the tests read it).
func mote_count() -> int:
	return _multi.visible_instance_count


# One frame: `edge` is the front's radius (metres), `progress` 0..1 through first light, `focus` where the player is
# and `seconds` a clock. Lays the motes along the front near the focus.
func sync(edge: float, focus: Vector3, seconds: float) -> void:
	var n := 0
	_placed.clear()
	if edge > 0.5:
		# The motes sit at fixed angles (one per STEP metres of the starting circle) so they do not slide as the front
		# closes; each has a threshold and drops out as the circle shrinks, which keeps the spacing near STEP.
		var dtheta := STEP / Config.FIRST_LIGHT_START_RADIUS
		var total := ceili(TAU / dtheta)
		var around := atan2(focus.z, focus.x)
		var span := minf(PI, SPAN / edge)
		var k0 := floori((around - span) / dtheta)
		var k1 := ceili((around + span) / dtheta)
		if span >= PI:
			k0 = 0
			k1 = total - 1
		for k: int in range(k0, k1 + 1):
			var h1 := _hash(k)
			var h2 := _hash(k * 7 + 5)
			if _hash(k * 3 + 1) > edge / Config.FIRST_LIGHT_START_RADIUS + 0.15:
				continue
			var a := (float(k) + h1 - 0.5) * dtheta
			var r := edge + h2 * 2.4
			var rise := fposmod(seconds * (0.22 + 0.25 * h1) + h2, 1.0)
			var y := 0.25 + rise * 2.4
			var size := 1.0 - rise * 0.75
			var pos := Vector3(cos(a) * r, y, sin(a) * r)
			_multi.set_instance_transform(n, Transform3D(Basis.from_scale(Vector3.ONE * size), pos))
			_placed.append(pos)
			n += 1
			if n >= _multi.instance_count:
				break
	_multi.visible_instance_count = n


# The sky the styled view shows when first light is `progress` of the way in (STYLED_BACKGROUND at the start).
static func sky_at(progress: float) -> Color:
	return ViewPipeline.STYLED_BACKGROUND.lerp(Config.CP5_FIRST_LIGHT_SKY, Config.CP5_FIRST_LIGHT_SKY_MIX * progress)


static func _hash(k: int) -> float:
	return fposmod(sin(float(k) * 12.9898) * 43758.5453, 1.0)
