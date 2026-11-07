extends GdUnitTestSuite

# Round 25, edge cleanup, what is left after round 26: the burst and lift marks replace each other instead of stacking
# and are short; the styled minimap draws sealed stretches, the tide's fog edge and the beacon's halo. (The ribbon is in
# edge_ribbon_test.gd, the faded people outside in edge_dim_test.gd.) Visuals only: nothing here changes a rule.


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func test_a_new_burst_or_lift_mark_replaces_one_at_the_same_spot() -> void:
	var fx := BurstFx.new()
	add_child(fx)
	var cleared: Array = [{"person": null, "from": Vector3(0, 0, 0), "to": Vector3(10, 0, 0)}]
	fx.add_lift_result(cleared)
	fx.add_lift_result(cleared)
	assert_int(fx.halo_count()).is_equal(1)
	assert_int(fx.result_text_count()).is_equal(1)
	fx.add_burst(cleared)
	fx.add_burst(cleared)
	fx.sync(0.016)
	assert_int(fx.streak_count()).is_equal(1)
	# Two people of one burst that land side by side are both kept.
	var pair: Array = [
		{"person": null, "from": Vector3(0, 0, 0), "to": Vector3(30, 0, 0)},
		{"person": null, "from": Vector3(0, 0, 1), "to": Vector3(30.5, 0, 0)},
	]
	fx.add_lift_result(pair)
	fx.add_burst(pair)
	fx.sync(0.016)
	assert_int(fx.halo_count()).is_equal(3)
	assert_int(fx.streak_count()).is_equal(3)
	fx.free()


func test_the_effects_are_short_and_no_light_column_is_left() -> void:
	assert_float(Config.BURST_FX_SECONDS).is_less_equal(0.6)
	assert_float(Config.FX_HALO_SECONDS).is_less_equal(1.0)
	assert_float(Config.FX_TEXT_SECONDS).is_less_equal(1.1)
	assert_float(Config.SPARE_GLOW_SECONDS).is_less_equal(1.5)
	# Styled marks are flat dithered rings: no node of the fight marks stands taller than a person.
	Looks.set_mode(Looks.Mode.STYLED)
	var fx := BurstFx.new()
	add_child(fx)
	var cleared: Array = [{"person": null, "from": Vector3(0, 0, 0), "to": Vector3(10, 0, 0)}]
	fx.add_lift_result(cleared)
	fx.sync(0.016)
	for child: Node in fx.get_children():
		if child is MeshInstance3D:
			var node := child as MeshInstance3D
			assert_float(node.mesh.get_aabb().size.y * node.scale.y).is_less(0.5)
	fx.free()


func test_a_lift_with_nobody_lifted_leaves_no_mark() -> void:
	var fx := BurstFx.new()
	add_child(fx)
	var nobody: Array = []
	fx.add_lift_result(nobody)
	assert_int(fx.halo_count()).is_equal(0)
	assert_int(fx.result_text_count()).is_equal(0)
	fx.free()


# --- Round 25: sealed stretches, the tide's fog edge and the beacon's halo ---------------------------


func _styled_map() -> Minimap:
	var m: Minimap = auto_free(Minimap.new())
	add_child(m)
	m.look = MinimapLookStyled.new()
	return m


func _count_not_equal(m: Minimap, before: PackedByteArray) -> int:
	var after := m._image.get_data()
	var n := 0
	for i: int in range(after.size()):
		if after[i] != before[i]:
			n += 1
	return n


func test_a_sealed_stretch_is_drawn_thicker_in_the_styled_look() -> void:
	var plain := _styled_map()
	plain.border_pts = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(0, 10)])
	plain.gap_flags = [false, false, false]
	plain._render()
	var plain_data := plain._image.get_data()
	var sealed := _styled_map()
	sealed.border_pts = plain.border_pts
	sealed.gap_flags = [false, false, false]
	sealed.seal_flags = [true, true, true]
	sealed._render()
	assert_bool(sealed._image.get_data() == plain_data).is_false()


func test_the_tide_fog_edge_is_drawn_on_the_rim_toward_the_tide() -> void:
	var m := _styled_map()
	m._render()
	var before := m._image.get_data()
	m.tide_fog = Vector2(1.0, 0.0)
	m._render()
	assert_int(_count_not_equal(m, before)).is_greater(10)


func test_the_beacon_gets_a_halo_ring_in_the_styled_look() -> void:
	var m := _styled_map()
	m._render()
	var before := m._image.get_data()
	m.beacon_pos = Vector2(10.0, 10.0)
	m._render()
	assert_int(_count_not_equal(m, before)).is_greater(10)
