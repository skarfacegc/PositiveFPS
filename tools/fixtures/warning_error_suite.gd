extends GdUnitTestSuite

# Deliberately broken (tools/test_run_tests.py): int() on a Variant is a warning that project.godot makes an error,
# so Godot refuses to load this suite. Round 18 lost a suite this way. Kept outside tests/ so the real run is green.


func test_never_runs() -> void:
	var counts: Dictionary = {"shots": 1}
	var shots: int = int(counts["shots"])
	assert_int(shots).is_equal(1)
