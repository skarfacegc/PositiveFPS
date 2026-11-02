class_name GapPatch
extends Node

# Round 22: the player's ways to fight back with spirit, wired in one place (TopDownMain only calls `attach`).
#  - F patches the gap (or strained spot) nearest the cursor: PATCH_SPIRIT_COST spirit seals it for PATCH_SECONDS. While
#    patched, the gap counts as intact (`apply`, called by Border.update after the slots are worked out: gloom does not
#    pass, dimmed people are pushed back) and members inside PATCH_RADIUS lose joy at PATCH_DRAIN_MULT of the rate.
#  - Border warning: every BORDER_WARN_INTERVAL the strained members are worked out (BorderWarning) and drawn by PatchFx
#    and the minimap; `warnings` is the list.
#  - The burst's report is turned into world marks and a recorder event; `burst_targets` is the HUD count.
# The patch is a short pause, not a cure: the member is not healed, and a patch runs out.

signal patched(pos: Vector3, cost: float, spirit_after: float)
signal expired(pos: Vector3)

var main: TopDownMain
var fx: PatchFx
var patch_label: Label
# Active patches: {"pos": Vector3, "left": float}.
var patches: Array[Dictionary] = []
# Strained border members (see BorderWarning.compute), refreshed every BORDER_WARN_INTERVAL.
var warnings: Array[Dictionary] = []
# Dimmed people a burst from the player's position would clear right now.
var burst_targets: int = 0
var _shielded: Array[Person] = []
var _timer: float = 0.0
var _last_press_frame: int = -1


# Builds the node under `level`, links the border and the player to it and returns it.
static func attach(level: TopDownMain) -> GapPatch:
	var g := GapPatch.new()
	g.main = level
	level.add_child(g)
	level.border.patch = g
	level.player.border = level.border
	g.fx = PatchFx.new()
	level.add_child(g.fx)
	level.player.burst_cleared.connect(g._on_burst_cleared)
	g._build_label()
	return g


func _build_label() -> void:
	patch_label = Label.new()
	patch_label.add_theme_font_size_override("font_size", Config.CUE_FONT_SIZE)
	patch_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	patch_label.add_theme_constant_override("outline_size", 4)
	patch_label.visible = false
	main.hud.add_child(patch_label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("patch_gap"):
		try_patch()


func _process(delta: float) -> void:
	_tick_patches(delta)
	_timer -= delta
	if _timer <= 0.0:
		_timer = Config.BORDER_WARN_INTERVAL
		warnings = BorderWarning.compute(main.border, main.people)
		burst_targets = BurstClear.count_targets(main.people, main.player.global_position, main.border)
	fx.sync(delta, warnings, patches)
	_update_label()


func _tick_patches(delta: float) -> void:
	for i: int in range(patches.size() - 1, -1, -1):
		var left: float = patches[i]["left"] - delta
		patches[i]["left"] = left
		if left <= 0.0:
			var pos: Vector3 = patches[i]["pos"]
			patches.remove_at(i)
			expired.emit(pos)


# Round 23: the cue. A small line by the player's feet, only when F or G/Q can be acted on right now:
#  - "F: patch" when a gap or strained spot lies under the cursor and spirit allows; "gap near: aim at it, F" when one
#    is near the player but not under the cursor;
#  - "G: lift N" when a burst would lift N dimmed people off the border.
# Nothing is shown otherwise.
func cue_text() -> String:
	var parts: Array[String] = []
	var patch := _patch_cue()
	if patch != "":
		parts.append(patch)
	if burst_targets > 0 and main.player.can_burst():
		parts.append(Config.CUE_BURST_TEXT % burst_targets)
	return "   ".join(parts)


func _patch_cue() -> String:
	var player := main.player
	if not main.running or player.is_dim or player.spirit < Config.PATCH_SPIRIT_COST:
		return ""
	if patches.size() >= Config.PATCH_MAX:
		return ""
	if player.has_aim() and not _spot_near(player.aim_point()).is_empty():
		return Config.CUE_PATCH_TEXT
	if not _spot_near(player.global_position, Config.CUE_PLAYER_RANGE).is_empty():
		return Config.CUE_PATCH_AIM_TEXT
	return ""


func _update_label() -> void:
	var text := cue_text()
	patch_label.visible = text != ""
	if text == "":
		return
	patch_label.text = text
	patch_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.85, Config.CUE_ALPHA))
	patch_label.position = main.world_to_screen(main.player.global_position) + Config.CUE_OFFSET


# F. Seals the gap or strained spot nearest the cursor. Returns true when a patch was made. Once per frame (the test
# runner delivers a key press twice). A refusal shows a notice and spends nothing.
func try_patch() -> bool:
	var frame := Engine.get_process_frames()
	if frame == _last_press_frame:
		return false
	_last_press_frame = frame
	if not main.running or not main.player.has_aim():
		return false
	var spot := _spot_near(main.player.aim_point())
	if spot.is_empty():
		var near_existing := _patched_near(main.player.aim_point(), Config.PATCH_REACH)
		main.intro.notice(Intro.Prompt.PATCH_ALREADY if near_existing else Intro.Prompt.PATCH_NONE)
		return false
	if main.player.is_dim or main.player.spirit < Config.PATCH_SPIRIT_COST:
		main.intro.notice(Intro.Prompt.PATCH_SPIRIT)
		return false
	if patches.size() >= Config.PATCH_MAX:
		main.intro.notice(Intro.Prompt.PATCH_MAX)
		return false
	var at: Vector3 = spot["pos"]
	var kind: String = spot["kind"]
	patch_at(at, kind)
	return true


# Seals the stretch round `at`, paying for it. (Public so a test can place one without a cursor.)
func patch_at(at: Vector3, kind: String = "gap") -> void:
	main.player.lose_spirit(Config.PATCH_SPIRIT_COST)
	main.spirit_meter.moment(-Config.PATCH_SPIRIT_COST, SpiritMeter.Moment.SPEND)
	main.feedback.pulse_player(SpiritMeter.Moment.SPEND)
	patches.append({"pos": at, "left": Config.PATCH_SECONDS})
	fx.add_patch_result(at, _held_near(at))
	patched.emit(at, Config.PATCH_SPIRIT_COST, main.player.spirit)
	if main.recorder != null:
		(
			main
			. recorder
			. emit_event(
				"gap_patched",
				{
					"pos": [snappedf(at.x, 0.1), snappedf(at.z, 0.1)],
					"kind": kind,
					"cost": Config.PATCH_SPIRIT_COST,
					"spirit_after": snappedf(main.player.spirit, 0.1),
					"gaps_open": main.border.gap_count(),
				}
			)
		)


# Round 23: what a patch at `at` holds: open gaps and border members inside PATCH_RADIUS (at least 1).
func _held_near(at: Vector3) -> int:
	var n := 0
	for g: Vector3 in main.border.gap_midpoints():
		if GloomSim.flat_dist(at, g) <= Config.PATCH_RADIUS:
			n += 1
	for m: Person in main.border.members:
		if GloomSim.flat_dist(at, m.position) <= Config.PATCH_RADIUS:
			n += 1
	return maxi(n, 1)


# The nearest open gap middle or strained member to `aim` within PATCH_REACH that no patch already covers:
# {"pos": Vector3, "kind": "gap" | "strain"}, or an empty Dictionary.
func _spot_near(aim: Vector3, reach: float = Config.PATCH_REACH) -> Dictionary:
	var best: Dictionary = {}
	var best_d := reach
	for g: Vector3 in main.border.gap_midpoints():
		var d := GloomSim.flat_dist(aim, g)
		if d <= best_d and not is_patched(g):
			best_d = d
			best = {"pos": g, "kind": "gap"}
	for w: Dictionary in warnings:
		var at: Vector3 = w["pos"]
		var u: float = w["urgency"]
		var d := GloomSim.flat_dist(aim, at)
		if u >= Config.BORDER_WARN_PRESS_URGENCY and d <= best_d and not is_patched(at):
			best_d = d
			best = {"pos": at, "kind": "strain"}
	return best


func _patched_near(pos: Vector3, within: float) -> bool:
	for p: Dictionary in patches:
		var at: Vector3 = p["pos"]
		if GloomSim.flat_dist(pos, at) <= within:
			return true
	return false


func is_patched(pos: Vector3) -> bool:
	for p: Dictionary in patches:
		var at: Vector3 = p["pos"]
		if GloomSim.flat_dist(pos, at) <= Config.PATCH_RADIUS:
			return true
	return false


# Called by Border.update after the slots and gaps are worked out. Gap flags inside a patch are cleared (so the gap
# blocks gloom, is not drawn open and is not an arrow target) and members inside it are shielded. Does nothing when
# there are no patches.
func apply(b: Border) -> void:
	for p: Person in _shielded:
		if is_instance_valid(p):
			p.patch_mult = 1.0
	_shielded.clear()
	if patches.is_empty() or not b.active:
		return
	for k: int in range(b.segment_gap.size()):
		if b.segment_gap[k]:
			var mid: Vector2 = b._point_at_open(b._phase + (float(k) + 0.5) * b.spacing)
			if is_patched(Vector3(mid.x, 0.0, mid.y)):
				b.segment_gap[k] = false
	var n := b.polygon.size()
	for j: int in range(b._sample_gap.size()):
		if b._sample_gap[j]:
			var mid2 := (b.polygon[j] + b.polygon[(j + 1) % n]) * 0.5
			if is_patched(Vector3(mid2.x, 0.0, mid2.y)):
				b._sample_gap[j] = false
	for m: Person in b.members:
		if is_patched(m.position):
			m.patch_mult = Config.PATCH_DRAIN_MULT
			_shielded.append(m)


# The player's burst happened: draw the clearing and tell the recorder what it did.
func _on_burst_cleared(report: Dictionary) -> void:
	var cleared: Array = report["cleared"]
	fx.add_burst(cleared)
	fx.add_lift_result(cleared)
	if main.recorder != null:
		var ids: Array = []
		for c: Dictionary in cleared:
			ids.append(main.people.find(c["person"]))
		(
			main
			. recorder
			. emit_event(
				"burst_clear",
				{
					"lifted": report["lifted"],
					"joy_hits": report["joy_hits"],
					"ids": ids,
					"gaps_open": main.border.gap_count(),
					"spirit_after": snappedf(main.player.spirit, 0.1),
				}
			)
		)
