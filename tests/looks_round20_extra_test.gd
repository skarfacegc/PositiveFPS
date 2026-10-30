extends GdUnitTestSuite

# Graphics checkpoint 4: looks that are not built yet or have no body to pose, and the walk pose guards.

const DT := 1.0 / 60.0


func after_test() -> void:
	Looks.set_mode(Looks.Mode.PLACEHOLDER)


func _person() -> Person:
	Looks.set_mode(Looks.Mode.STYLED)
	var p: Person = auto_free(Person.new())
	add_child(p)
	p.look.sync()
	return p


# --- Looks that are not built yet or have no body to pose ------------------------------------------------------------


func test_a_base_look_with_no_subject_ignores_a_walk_and_a_claim() -> void:
	var person_look: PersonLook = auto_free(PersonLook.new())
	person_look.advance(DT)
	person_look._pose_gait()
	var player_look: PlayerLook = auto_free(PlayerLook.new())
	player_look.advance(DT)
	player_look._pose_gait()
	var landmark_look: LandmarkLook = auto_free(LandmarkLook.new())
	landmark_look.play_change(true)
	landmark_look.play_change(false)
	assert_object(person_look.subject).is_null()
	assert_object(player_look.subject).is_null()


func test_a_styled_person_whose_body_is_not_built_is_not_posed() -> void:
	var p := _person()
	var look := p.look as PersonLookStyled
	look._holders[look.shown_kind()] = null
	look._pose_gait()
	assert_object(look._holders[look.shown_kind()]).is_null()


func test_a_body_with_no_rig_is_left_alone_and_a_styled_panel_draws_nothing_in_the_placeholder_look() -> void:
	StyleWalk.apply(Gait.new(), {})
	var panel: StyledPanel = auto_free(StyledPanel.new())
	add_child(panel)
	assert_bool(panel.is_drawn()).is_false()
	panel._draw()
	Looks.set_mode(Looks.Mode.STYLED)
	assert_bool(panel.is_drawn()).is_true()
