class_name GroundLookStyled
extends GroundLook

# The styled ground: one big plane with the cobble shader (see shaders/style_ground.gdshader). The paint weight of
# every tile goes to the shader as a small greyscale texture; the shader dithers the edge between the grey and the warm
# cobbles. The paint colour is not used (the painted ground is always the warm cobble).

const SHADER := "res://shaders/style_ground.gdshader"
const PLANE_SIZE := 160.0

var _mat: ShaderMaterial
var _texture: ImageTexture
# The last weights picture sent to the shader (kept so it can be read back).
var _image: Image


func is_styled() -> bool:
	return true


func refresh(_colours: Array[Color], weights: Array[float]) -> void:
	var bytes := PackedByteArray()
	bytes.resize(grid_size * grid_size)
	for ix: int in range(grid_size):
		for iz: int in range(grid_size):
			bytes[iz * grid_size + ix] = clampi(roundi(weights[ix * grid_size + iz] * 255.0), 0, 255)
	var img := Image.create_from_data(grid_size, grid_size, false, Image.FORMAT_L8, bytes)
	_image = img
	if _texture == null:
		_texture = ImageTexture.create_from_image(img)
		_mat.set_shader_parameter("weights", _texture)
	else:
		_texture.update(img)


func _build() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load(SHADER)
	_mat.set_shader_parameter("plaza", float(grid_size))
	var plane := PlaneMesh.new()
	plane.size = Vector2(PLANE_SIZE, PLANE_SIZE)
	var inst := MeshInstance3D.new()
	inst.mesh = plane
	inst.material_override = _mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)
