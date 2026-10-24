class_name Building
extends RefCounted

# One block the border can beautify. It is beautified after BORDER_BUILDING_SECONDS with enough of its footprint inside
# the border (see Border). Its colour fades toward warm over BORDER_TINT_SECONDS. Mechanical blocks keep their grey.
# Round 10: a beautified block on the border line is a post (see Border.post_count). Its placeholder visuals are a warm
# lantern on top and a golden ring around its base. attach() creates them on the block's body.

var centre := Vector2.ZERO
var half := Vector2.ONE
var mat: StandardMaterial3D
var base_colour := Color.WHITE
var is_landmark: bool = false
# Seconds this building has had enough of its footprint inside the border in a row.
var inside_time: float = 0.0
# 0 (mechanical grey) to 1 (fully beautified colour).
var tint: float = 0.0
var beautified: bool = false
# True while the border counts this block as a post (see Border._assign_members).
var post: bool = false
var _lantern: MeshInstance3D
var _ring: MeshInstance3D


# Adds the post visuals to the block's body (hidden until the block is a post).
func attach(body: StaticBody3D) -> void:
	var top := 1.0
	for child: Node in body.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			top = ((child as MeshInstance3D).mesh as BoxMesh).size.y / 2.0
	_lantern = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.7
	_lantern.mesh = sphere
	_lantern.position = Vector3(0.0, top + 0.6, 0.0)
	_lantern.material_override = _unshaded(Config.BORDER_POST_LANTERN_COLOUR)
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Config.BORDER_POST_RING_INNER
	torus.outer_radius = Config.BORDER_POST_RING_OUTER
	_ring.mesh = torus
	# The body sits at the block's centre, so the base is `top` below it.
	_ring.position = Vector3(0.0, -top + 0.06, 0.0)
	_ring.material_override = _unshaded(Config.BORDER_POST_RING_COLOUR)
	body.add_child(_lantern)
	body.add_child(_ring)
	set_post(false)


# Shows or hides the post visuals, and records whether this block is a post.
func set_post(on: bool) -> void:
	post = on
	if _lantern != null:
		_lantern.visible = on
		_ring.visible = on


# `inside_fraction` is the share of the footprint (0..1) inside the border this frame.
func update(delta: float, inside_fraction: float) -> void:
	if inside_fraction >= Config.BORDER_BUILDING_INSIDE:
		inside_time += delta
	else:
		inside_time = 0.0
	beautified = inside_time >= Config.BORDER_BUILDING_SECONDS
	var target := 1.0 if beautified else 0.0
	tint = move_toward(tint, target, delta / Config.BORDER_TINT_SECONDS)
	if mat != null:
		mat.albedo_color = base_colour.lerp(Config.BORDER_BUILDING_COLOUR, tint)


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = colour
	return m
