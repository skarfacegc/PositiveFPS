extends GdUnitTestSuite

# Checkpoint 7, part A: the starting look by context, and the dithering gone from the shaders of the people, the toon
# light, the glows, the rings, the wedge and the reach outlines.

const CLEAN_SHADERS: Array[String] = [
	"res://shaders/style_glow.gdshader",
	"res://shaders/style_ring.gdshader",
	"res://shaders/style_wedge.gdshader",
	"res://shaders/style_outline.gdshader",
	"res://shaders/style_toon.gdshader",
]


func test_a_look_argument_picks_the_starting_look() -> void:
	assert_int(Looks.start_mode(PackedStringArray(["--look=styled"]), false)).is_equal(Looks.Mode.STYLED)
	assert_int(Looks.start_mode(PackedStringArray(["--record", "--look=placeholder"]), true)).is_equal(
		Looks.Mode.PLACEHOLDER
	)
	assert_int(Looks.start_mode(PackedStringArray(["--look=STYLED"]), false)).is_equal(Looks.Mode.STYLED)


func test_without_an_argument_only_exported_builds_start_styled() -> void:
	assert_int(Looks.start_mode(PackedStringArray(), false)).is_equal(Looks.Mode.PLACEHOLDER)
	assert_int(Looks.start_mode(PackedStringArray(), true)).is_equal(Looks.Mode.STYLED)
	# An unknown value is ignored.
	assert_int(Looks.start_mode(PackedStringArray(["--look=neon"]), false)).is_equal(Looks.Mode.PLACEHOLDER)
	assert_int(Looks.start_mode(PackedStringArray(["--look=neon"]), true)).is_equal(Looks.Mode.STYLED)


func test_the_tests_run_in_the_placeholder_look() -> void:
	# Applying the start look in a test run (no argument, not exported) leaves the placeholder, and acts only once.
	Looks.apply_start_mode()
	Looks.apply_start_mode()
	assert_int(Looks.mode).is_equal(Looks.Mode.PLACEHOLDER)
	Looks.set_mode(Looks.Mode.STYLED)
	Looks.apply_start_mode()
	assert_int(Looks.mode).is_equal(Looks.Mode.STYLED)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	# The choice switches to styled for an argument or an exported build, and never back to placeholder.
	Looks.apply_start_choice(PackedStringArray(), false)
	assert_int(Looks.mode).is_equal(Looks.Mode.PLACEHOLDER)
	Looks.apply_start_choice(PackedStringArray(["--look=styled"]), false)
	assert_int(Looks.mode).is_equal(Looks.Mode.STYLED)
	Looks.apply_start_choice(PackedStringArray(["--look=placeholder"]), true)
	assert_int(Looks.mode).is_equal(Looks.Mode.STYLED)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)
	Looks.apply_start_choice(PackedStringArray(), true)
	assert_int(Looks.mode).is_equal(Looks.Mode.STYLED)
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func test_the_shaders_no_longer_dither() -> void:
	for path: String in CLEAN_SHADERS:
		var f := FileAccess.open(path, FileAccess.READ)
		assert_object(f).is_not_null()
		var src := f.get_as_text()
		assert_bool(src.contains("M4[")).override_failure_message(path + " still has a Bayer matrix").is_false()
		assert_bool(src.contains("bayer4(")).override_failure_message(path + " still calls bayer4").is_false()
	var inc := FileAccess.open("res://shaders/style_common.gdshaderinc", FileAccess.READ).get_as_text()
	assert_bool(inc.contains("dither_amt")).is_false()
	assert_bool(inc.contains("band_soft")).is_true()


func test_glow_and_toon_materials_carry_no_dither_parameters() -> void:
	var glow := StyleKit.glow_mat(Color.WHITE, 0.5)
	assert_object(glow.get_shader_parameter("dither_k")).is_null()
	assert_that(glow.get_shader_parameter("strength")).is_equal(0.5)
	var toon := StyleKit.mat(Color.RED)
	assert_object(toon.get_shader_parameter("dither_amt")).is_null()
	assert_that(toon.get_shader_parameter("band_soft")).is_equal(StyleConfig.CP7_TOON_SOFT)
