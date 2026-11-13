class_name Defences
extends Node3D

# Walls and gates: Defences (F, #15 and #16). Hold F, point at a gate and release to plant a defence there;
# right-click cancels. One defence per gate, DEFENCE_MAX in all. The nearest free member staffs it and leaves the
# line (Border.staffed). A type is unlocked by claiming its landmark (Landmarks.unlock_order) and the mouse wheel
# cycles the type while F is held (the default is the most recent unlock). The types, in landmark order:
#   Bandstand: pushers at this gate are weakened (strength_mult DEFENCE_BANDSTAND_MULT).
#   Garden: this gate bends but cannot break (cannot_break).
#   Bell tower: when this gate is pressed past DEFENCE_BELL_PRESS_FROM of the break depth the bell rings, a free
#     burst at the pressed point (cooldown DEFENCE_BELL_COOLDOWN).
#   Gallery: the cells beside this gate cannot be lost (cannot_lose).
# A defence whose gate closes (its street is now inside the zone) is handed back and its staff rejoin the line. The
# modifiers go to the border through Border.set_gate_modifiers; what they do to the push is the border's. The
# placeholder look is a simple post shape per type in its landmark's colour (both looks draw it). Also here: the
# people numbers the HUD line and the take preview share (people_numbers).

signal planted(info: Dictionary)
signal refused(reason: String, info: Dictionary)
signal returned(info: Dictionary)
signal bell_rang(info: Dictionary)

const NO_GATE := -1

var level: TopDownMain
var holding := false
# The type shown while aiming (a landmark index), or -1 when none is unlocked.
var aim_type := -1
# The gate id pointed at while holding (NO_GATE when none).
var target_gate := NO_GATE
# One entry per defence: {"key": gate key, "gate": gate id now, "type": int, "staff": Person, "bell_wait": float}.
var posts: Array[Dictionary] = []

var _root: Node3D
var _label: Label3D
var _mats: Dictionary = {}
var _drawn := ""
var _applied_version := -1
var _dirty := true
var _wheel_frame := -1


static func attach(main: TopDownMain) -> Defences:
	var node := Defences.new()
	node.name = "Defences"
	node.level = main
	node._root = Node3D.new()
	node._root.name = "Posts"
	node.add_child(node._root)
	node._label = Label3D.new()
	node._label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node._label.no_depth_test = true
	node._label.pixel_size = BorderConfig.GATE_COUNT_PIXEL_SIZE
	node._label.font_size = BorderConfig.GATE_COUNT_FONT_SIZE
	node._label.outline_size = 12
	node._label.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
	node._label.visible = false
	node.add_child(node._label)
	main.add_child(node)
	main.border.gate_closed.connect(node._on_gate_closed)
	return node


# The people numbers (pure): `rescued` people in all, `staffed` of them on defences, `need` the gates ask for together.
static func count_people(rescued: int, staffed: int, need: int) -> Dictionary:
	var avail := maxi(rescued - staffed, 0)
	return {
		"rescued": rescued,
		"staffed": staffed,
		"need": need,
		"available": avail,
		"on_line": mini(avail, need),
		"short": maxi(need - avail, 0),
		"spare": maxi(avail - need, 0),
	}


# The HUD line under the spirit meter, from count_people: "People: 31 on the line, 23 short".
static func people_text(n: Dictionary) -> String:
	var on_line: int = n["on_line"]
	var short: int = n["short"]
	var spare: int = n["spare"]
	var staffed: int = n["staffed"]
	var tail := "%d short" % short if short > 0 else ("%d spare" % spare if spare > 0 else "none spare")
	var text := "People: %d on the line, %s" % [on_line, tail]
	if staffed > 0:
		text += ", %d on defences" % staffed
	return text


# The people now: every rescued person, those on defences, and what the gates need.
func people_numbers() -> Dictionary:
	var rescued := 0
	for p: Person in level.people:
		if p.is_rescued:
			rescued += 1
	return count_people(rescued, posts.size(), level.border.zone.members_needed())


func _unhandled_input(event: InputEvent) -> void:
	if level == null or not level.player.active:
		return
	if event.is_action_pressed("defence"):
		_begin()
	elif event.is_action_released("defence"):
		_release()
	elif holding and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed:
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_cancel()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			get_viewport().set_input_as_handled()  # The wheel picks the type while F is held; it does not zoom.
			var frame := Engine.get_process_frames()
			if frame != _wheel_frame:  # A wheel step can arrive twice in one frame (see Known gotchas).
				_wheel_frame = frame
				cycle_type(1 if mb.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1)


func _process(delta: float) -> void:
	if level == null:
		return
	if holding:
		_refresh()
	_resync()
	if _dirty:
		_apply_modifiers()
	_move_staff(delta)
	_tick_bells(delta)
	_redraw()


# Steps `aim_type` to the next (`step` 1) or previous (-1) unlocked type. Does nothing when none is unlocked.
func cycle_type(step: int) -> void:
	var types := level.landmarks.unlocked_types()
	if types.is_empty():
		aim_type = -1
		return
	var at := types.find(aim_type)
	if at < 0:
		aim_type = types[0]
		return
	aim_type = types[posmod(at + step, types.size())]


# The post of gate `g`, or an empty Dictionary.
func post_at(g: int) -> Dictionary:
	for post: Dictionary in posts:
		var pg: int = post["gate"]
		if pg == g:
			return post
	return {}


# The member who would staff a post at gate `g`: the nearest member who is not staffing one, or null when there is none.
func free_member_for(g: int) -> Person:
	var gates: Array[Dictionary] = level.border.zone.gates
	if g < 0 or g >= gates.size():
		return null
	var mid: Vector2 = gates[g]["mid"]
	var best: Person = null
	var best_d := INF
	for m: Person in level.border.members:
		if not is_instance_valid(m) or not m.is_rescued or level.border.staffed.has(m):
			continue
		var d := Vector2(m.position.x, m.position.z).distance_squared_to(mid)
		if d < best_d:
			best_d = d
			best = m
	return best


# Plants a defence of landmark type `type` at gate `g`. Returns true when it was planted; otherwise says why in the slim
# banner (and through `refused`).
func plant_now(g: int, type: int) -> bool:
	var info := {"gate": g, "kind": _type_name(type), "defences": posts.size()}
	if type < 0 or not level.landmarks.is_unlocked(type):
		return _refuse("no_type", DefenceConfig.REFUSE_NO_TYPE, info)
	var gates: Array[Dictionary] = level.border.zone.gates
	if g < 0 or g >= gates.size():
		return _refuse("no_gate", DefenceConfig.REFUSE_NO_GATE, info)
	if not post_at(g).is_empty():
		return _refuse("gate_defended", DefenceConfig.REFUSE_DEFENDED, info)
	if posts.size() >= DefenceConfig.DEFENCE_MAX:
		return _refuse("all_used", DefenceConfig.REFUSE_ALL_USED % DefenceConfig.DEFENCE_MAX, info)
	var staff := free_member_for(g)
	if staff == null:
		return _refuse("no_member", DefenceConfig.REFUSE_NO_MEMBER, info)
	var key: String = gates[g]["key"]
	posts.append({"key": key, "gate": g, "type": type, "staff": staff, "bell_wait": 0.0})
	_sync_staffed()
	_dirty = true
	info["defences"] = posts.size()
	info["staff"] = level.people.find(staff)
	info["key"] = key
	level.intro.calm_notice(
		Intro.Prompt.SPIRIT_LOW, "%s post planted: %s" % [_type_name(type), DefenceConfig.DEFENCE_TEXT[type]]
	)
	planted.emit(info)
	return true


# Hands the defence at gate `g` back (its staff rejoin the line). `reason` goes to the recorder.
func hand_back(g: int, reason: String) -> bool:
	for i: int in range(posts.size()):
		var pg: int = posts[i]["gate"]
		if pg == g:
			_hand_back_index(i, reason)
			return true
	return false


func _hand_back_index(i: int, reason: String) -> void:
	var post := posts[i]
	posts.remove_at(i)
	_sync_staffed()
	_dirty = true
	var staff: Person = post["staff"]
	var g: int = post["gate"]
	var type: int = post["type"]
	(
		returned
		. emit(
			{
				"gate": g,
				"kind": _type_name(type),
				"reason": reason,
				"staff": level.people.find(staff) if is_instance_valid(staff) else -1,
				"defences": posts.size(),
			}
		)
	)


func _refuse(reason: String, words: String, info: Dictionary) -> bool:
	level.intro.notice(Intro.Prompt.SPIRIT_LOW, words)
	refused.emit(reason, info)
	return false


func _on_gate_closed(_g: int) -> void:
	_resync()


# Keeps each post on its gate by key (ids shift when the zone changes), and hands back a post whose gate has closed or
# whose staff is no longer rescued.
func _resync() -> void:
	var gates: Array[Dictionary] = level.border.zone.gates
	var i := 0
	while i < posts.size():
		var post := posts[i]
		var found := NO_GATE
		for g: int in range(gates.size()):
			if gates[g]["key"] == post["key"]:
				found = g
				break
		var staff: Person = post["staff"]
		var reason := ""
		if found == NO_GATE:
			reason = "gate_closed"
		elif not is_instance_valid(staff) or not staff.is_rescued:
			reason = "staff_lost"
		if reason != "":
			_hand_back_index(i, reason)
			continue
		var old_gate: int = post["gate"]
		if old_gate != found:
			post["gate"] = found
			_dirty = true
		i += 1
	if level.border.zone.version != _applied_version:
		_dirty = true


func _sync_staffed() -> void:
	var list: Array[Person] = []
	for post: Dictionary in posts:
		var staff: Person = post["staff"]
		list.append(staff)
	level.border.staffed = list


# Gives the border the modifiers of every gate (the defended ones, and plain ones for the rest).
func _apply_modifiers() -> void:
	_dirty = false
	_applied_version = level.border.zone.version
	var border := level.border
	for g: int in range(border.zone.gates.size()):
		border.set_gate_modifiers(g, modifiers_of(post_at(g)))


# The modifiers a post asks for ({} for no post).
static func modifiers_of(post: Dictionary) -> Dictionary:
	if post.is_empty():
		return {}
	var type: int = post["type"]
	match type:
		Landmarks.BANDSTAND:
			return {"strength_mult": DefenceConfig.DEFENCE_BANDSTAND_MULT}
		Landmarks.GARDEN:
			return {"cannot_break": true}
		Landmarks.GALLERY:
			return {"cannot_lose": true}
	return {}


# Where the post stands (just inside the middle of its gate) and where its staff stand.
func post_position(g: int, inset: float = 0.6) -> Vector3:
	var gates: Array[Dictionary] = level.border.zone.gates
	if g < 0 or g >= gates.size():
		return Vector3.ZERO
	var mid: Vector2 = gates[g]["mid"]
	var out: Vector2 = gates[g]["out"]
	var at := mid - out * inset
	return Vector3(at.x, 0.0, at.y)


func staff_position(g: int) -> Vector3:
	return post_position(g, DefenceConfig.DEFENCE_POST_INSET)


func _move_staff(delta: float) -> void:
	for post: Dictionary in posts:
		var staff: Person = post["staff"]
		if not is_instance_valid(staff):
			continue
		var g: int = post["gate"]
		var to := staff_position(g)
		var flat := Vector3(staff.position.x, 0.0, staff.position.z)
		var at := flat.move_toward(to, DefenceConfig.DEFENCE_STAFF_SPEED * delta)
		staff.position = Vector3(at.x, staff.position.y, at.z)


func _tick_bells(delta: float) -> void:
	for post: Dictionary in posts:
		var type: int = post["type"]
		if type != Landmarks.BELL_TOWER:
			continue
		var left: float = post["bell_wait"]
		var wait := maxf(0.0, left - delta)
		post["bell_wait"] = wait
		if wait > 0.0:
			continue
		var g: int = post["gate"]
		var d := level.border.gate_deepest(g)
		var bend: float = d["bend"]
		var at: Vector3 = d["at"]
		if bend >= DefenceConfig.DEFENCE_BELL_PRESS_FROM:
			ring_bell(post, at, bend)


# The bell at `post` rings: a free burst at `at` (the pressed point), then DEFENCE_BELL_COOLDOWN seconds before it can
# ring again. Returns the burst's report.
func ring_bell(post: Dictionary, at: Vector3, bend: float) -> Dictionary:
	post["bell_wait"] = DefenceConfig.DEFENCE_BELL_COOLDOWN
	var report := BurstClear.run(level.people, at, level.border)
	var lifted: int = report["lifted"]
	var g: int = post["gate"]
	level.player.burst_cleared.emit(report)  # The burst's marks, the lifted folk perk up (BurstCue); the recorder logs it.
	level.intro.calm_notice(Intro.Prompt.SPIRIT_LOW, "The bell rings: %d lifted" % lifted)
	bell_rang.emit({"gate": g, "bend": snappedf(bend, 0.01), "lifted": lifted})
	return report


func _type_name(type: int) -> String:
	if type < 0 or type >= LandmarkConfig.LANDMARK_NAMES.size():
		return "none"
	return LandmarkConfig.LANDMARK_NAMES[type]


# ---- Aiming (F) --------------------------------------------------------------------------------------------------


func _begin() -> void:
	holding = true
	aim_type = level.landmarks.last_unlocked()
	_refresh()


func _refresh() -> void:
	target_gate = _gate_at_aim()
	if aim_type >= 0 and not level.landmarks.is_unlocked(aim_type):
		aim_type = level.landmarks.last_unlocked()


# The gate the aim point is near (within DEFENCE_PICK_RANGE), or NO_GATE.
func _gate_at_aim() -> int:
	if not level.player.has_aim():
		return NO_GATE
	var aim := level.player.aim_point()
	var at := Vector2(aim.x, aim.z)
	var near := level.border.zone.nearest_gate(at)
	if near.is_empty():
		return NO_GATE
	var a: Vector2 = near["a"]
	var b: Vector2 = near["b"]
	if Geometry2D.get_closest_point_to_segment(at, a, b).distance_to(at) > DefenceConfig.DEFENCE_PICK_RANGE:
		return NO_GATE
	var id: int = near["id"]
	return id


func _release() -> void:
	if not holding:
		return
	_refresh()
	var g := target_gate
	var type := aim_type
	_stop_holding()
	plant_now(g, type)


func _cancel() -> void:
	refused.emit("cancelled", {"gate": target_gate, "kind": _type_name(aim_type), "defences": posts.size()})
	_stop_holding()


func _stop_holding() -> void:
	holding = false
	target_gate = NO_GATE
	aim_type = -1


# ---- Placeholder look --------------------------------------------------------------------------------------------


# Redraws the posts (and the ghost while aiming) when something changed.
func _redraw() -> void:
	var sig := "styled;" if Looks.is_styled() else ""  # Walls and gates: Style update (#94): redraw when the look flips.
	for post: Dictionary in posts:
		var pg: int = post["gate"]
		var pt: int = post["type"]
		sig += "%d:%d;" % [pg, pt]
	if holding and target_gate != NO_GATE and aim_type >= 0:
		sig += "ghost%d:%d" % [target_gate, aim_type]
	var text := _aim_text()
	if sig != _drawn:
		_drawn = sig
		for child: Node in _root.get_children():
			_root.remove_child(child)
			child.queue_free()
		for post: Dictionary in posts:
			var pg: int = post["gate"]
			var pt: int = post["type"]
			_root.add_child(_post_piece(pt, post_position(pg), 1.0))
		if holding and target_gate != NO_GATE and aim_type >= 0:
			_root.add_child(_post_piece(aim_type, post_position(target_gate), DefenceConfig.DEFENCE_GHOST_ALPHA))
	_label.visible = text != ""
	if text == "":
		return
	if _label.text != text:
		_label.text = text
	var at := post_position(target_gate)
	_label.position = Vector3(at.x, DefenceConfig.DEFENCE_LABEL_HEIGHT, at.z)
	# Walls and gates: Style update (#94): the styled look warms the label and gives it an ink edge.
	var plain: Color = (
		LandmarkConfig.LANDMARK_COLOURS[aim_type] if aim_type >= 0 else BorderConfig.GATE_COUNT_SHORT_COLOUR
	)
	StyleTags.apply(_label, StyleTags.Role.PLAIN if aim_type >= 0 else StyleTags.Role.GATE_SHORT, plain)


# What the label over the pointed gate says while F is held.
func _aim_text() -> String:
	if not holding or target_gate == NO_GATE:
		return ""
	if aim_type < 0:
		return "No defence unlocked"
	if not post_at(target_gate).is_empty():
		return "Already defended"
	return "%s post: %s" % [_type_name(aim_type), DefenceConfig.DEFENCE_TEXT[aim_type]]


# One planted piece: the placeholder's simple shape, or (Walls and gates: Style update, #94) the styled street furniture
# of the landmark. A ghost (alpha below 1) is the one being aimed.
func _post_piece(type: int, at: Vector3, alpha: float) -> Node3D:
	if Looks.is_styled():
		return StyleDefence.build(type, at, alpha < 1.0)
	return _post_node(type, at, alpha)


# One post: a simple shape per type in the landmark's colour.
func _post_node(type: int, at: Vector3, alpha: float) -> MeshInstance3D:
	var h := DefenceConfig.DEFENCE_POST_HEIGHT
	var w := DefenceConfig.DEFENCE_POST_WIDTH
	var mesh: Mesh
	var lift := h * 0.5
	match type:
		Landmarks.BANDSTAND:
			var box := BoxMesh.new()
			box.size = Vector3(w, h, w)
			mesh = box
		Landmarks.GARDEN:
			var ball := SphereMesh.new()
			ball.radius = w
			ball.height = w * 2.0
			mesh = ball
			lift = w
		Landmarks.BELL_TOWER:
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = w
			cone.height = h
			mesh = cone
		_:
			var slab := BoxMesh.new()
			slab.size = Vector3(w * 2.6, h * 0.45, w * 0.7)
			mesh = slab
			lift = h * 0.225
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at + Vector3(0.0, lift, 0.0)
	inst.material_override = _mat(type, alpha)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


func _mat(type: int, alpha: float) -> StandardMaterial3D:
	var key := "%d:%.2f" % [type, alpha]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var col := LandmarkConfig.LANDMARK_COLOURS[type] if type >= 0 else Color.WHITE
		col.a = alpha
		m.albedo_color = col
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]
