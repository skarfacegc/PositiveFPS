class_name LandmarkPointers
extends Control

# Round 22: an edge-of-screen pointer toward each landmark that is not held and is off screen. Each shows a small arrow
# and the landmark's name and boost in a few words ("Bandstand: music x1.5"). A pointer is hidden while its landmark
# is on
# screen, and it slides along the screen edge (the inset rectangle) to keep clear of the HUD panels. The rules are the
# static functions (edge_point, place); update_from() reads the level each frame. Placeholder look only: hidden in the
# styled look (see update_from).

var _hud: Hud
var _minimap: Control
var _shown: Array[Dictionary] = []
var _since: float = 1.0e9  # Round 23: seconds since the pointers were last worked out (see update_from)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# Takes the HUD panels to keep clear of (the counters, the bars and the alert line) and the minimap.
func setup(hud: Hud, minimap: Control) -> void:
	_hud = hud
	_minimap = minimap


# One pointer per landmark that is neither held nor on screen, placed clear of the HUD. Round 23: the level calls this
# every frame with its `delta`, and the work (0.18 ms) is done only every LANDMARK_POINTER_REFRESH seconds; a call
# without `delta` (the tests) always works it out.
func update_from(main: TopDownMain, delta: float = -1.0) -> void:
	if delta >= 0.0:
		_since += delta
		if _since < Config.LANDMARK_POINTER_REFRESH:
			return
	_since = 0.0
	_shown.clear()
	visible = not Looks.is_styled()
	var screen := get_viewport_rect().size
	# A window too small for the inset rectangle (the headless 64 x 64 window) shows no pointers.
	if not visible or main.landmarks == null or _hud == null or screen.x < 400.0 or screen.y < 300.0:
		queue_redraw()
		return
	var font := get_theme_default_font()
	var font_px := Config.LANDMARK_POINTER_FONT_SIZE
	var avoid := _avoid_rects(main)
	for k: int in range(Config.LANDMARK_POSITIONS.size()):
		if main.landmarks.is_held(k):
			continue
		var at := main.world_to_screen(Config.LANDMARK_POSITIONS[k])
		if on_screen(at, screen):
			continue
		var text := "%s: %s" % [Config.LANDMARK_NAMES[k], Config.LANDMARK_BOOST_TEXT[k]]
		var label_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px) + Vector2(12, 8)
		var placed := place(at, screen, label_size, avoid)
		placed["text"] = text
		_shown.append(placed)
	queue_redraw()


# How many pointers are shown now (tests read this).
func shown_count() -> int:
	return _shown.size()


# The pointer for the landmark at index `k` (empty dictionary if none is shown). Keys: "tip", "dir", "label", "box",
# "text".
func pointer_for(text_start: String) -> Dictionary:
	for s: Dictionary in _shown:
		var text: String = s["text"]
		if text.begins_with(text_start):
			return s
	return {}


func _draw() -> void:
	var font := get_theme_default_font()
	var font_px := Config.LANDMARK_POINTER_FONT_SIZE
	for s: Dictionary in _shown:
		var label: Rect2 = s["label"]
		var tip: Vector2 = s["tip"]
		var dir: Vector2 = s["dir"]
		var text: String = s["text"]
		draw_rect(label, Config.LANDMARK_POINTER_BG_COLOUR)
		draw_string(
			font,
			label.position + Vector2(6, 4 + font.get_ascent(font_px)),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			font_px,
			Config.LANDMARK_POINTER_COLOUR
		)
		var arrow := Config.LANDMARK_POINTER_ARROW
		var side := Vector2(-dir.y, dir.x)
		var base := tip - dir * arrow
		var points := PackedVector2Array([tip, base + side * arrow * 0.55, base - side * arrow * 0.55])
		draw_colored_polygon(points, Config.LANDMARK_POINTER_COLOUR)


# True when the window position `p` is inside the screen `screen` (the window size).
static func on_screen(p: Vector2, screen: Vector2) -> bool:
	return p.x >= 0.0 and p.y >= 0.0 and p.x <= screen.x and p.y <= screen.y


# Where the ray from the screen centre through `target` leaves the inset rectangle (the screen minus `inset` on each
# side). A target at the centre gives the centre.
static func edge_point(target: Vector2, screen: Vector2, inset: float) -> Vector2:
	var centre := screen * 0.5
	var dir := target - centre
	if dir.length() < 0.0001:
		return centre
	var half := centre - Vector2.ONE * inset
	var tx := INF
	var ty := INF
	if absf(dir.x) > 0.0001:
		tx = half.x / absf(dir.x)
	if absf(dir.y) > 0.0001:
		ty = half.y / absf(dir.y)
	return centre + dir * minf(tx, ty)


# The pointer for a target: its tip on the inset rectangle, and the arrow and label rectangles. The tip starts on the
# edge where the ray leaves the screen, then walks round the inset rectangle (alternately each way) to the nearest spot
# where the label clears every rectangle in `avoid`. If no spot is clear, it keeps the first one.
# Returns {"tip": Vector2, "dir": Vector2 (outward, unit), "label": Rect2, "box": Rect2 (arrow and label)}.
static func place(target: Vector2, screen: Vector2, label_size: Vector2, avoid: Array[Rect2]) -> Dictionary:
	var inset := Config.LANDMARK_POINTER_INSET
	var centre := screen * 0.5
	var dir := (target - centre).normalized() if (target - centre).length() > 0.0001 else Vector2.UP
	var rect := Rect2(Vector2.ONE * inset, screen - Vector2.ONE * inset * 2.0)
	var perimeter := 2.0 * (rect.size.x + rect.size.y)
	var start := _perimeter_param(edge_point(target, screen, inset), rect)
	var step := Config.LANDMARK_POINTER_SLIDE_STEP
	var first := {}
	var k := 0
	while k * step <= perimeter * 0.5:
		for direction: float in [1.0] if k == 0 else [1.0, -1.0]:
			var s := fposmod(start + direction * float(k) * step, perimeter)
			var tip := _perimeter_point(s, rect)
			var placed := _pointer_at(tip, dir, label_size, rect)
			var box: Rect2 = placed["box"]
			if first.is_empty():
				first = placed
			if _clear(box, avoid, screen):
				return placed
		k += 1
	return first


# The arrow and label rectangles of a tip on the inset rectangle `rect`. The label sits inward of the edge the tip is
# on.
static func _pointer_at(tip: Vector2, dir: Vector2, label_size: Vector2, rect: Rect2) -> Dictionary:
	var inward := Vector2.ZERO
	if tip.x <= rect.position.x + 0.01:
		inward = Vector2.RIGHT
	elif tip.x >= rect.end.x - 0.01:
		inward = Vector2.LEFT
	elif tip.y <= rect.position.y + 0.01:
		inward = Vector2.DOWN
	else:
		inward = Vector2.UP
	var gap := Config.LANDMARK_POINTER_ARROW + 4.0
	var label: Rect2
	if inward.x != 0.0:
		var lx := tip.x + gap if inward.x > 0.0 else tip.x - gap - label_size.x
		label = Rect2(lx, tip.y - label_size.y * 0.5, label_size.x, label_size.y)
	else:
		var ly := tip.y + gap if inward.y > 0.0 else tip.y - gap - label_size.y
		label = Rect2(tip.x - label_size.x * 0.5, ly, label_size.x, label_size.y)
	var arrow := Config.LANDMARK_POINTER_ARROW
	var box := Rect2(tip - Vector2.ONE * arrow, Vector2.ONE * arrow * 2.0).merge(label)
	return {"tip": tip, "dir": dir, "label": label, "box": box}


# True when `box` lies on the screen and touches none of the `avoid` rectangles (with a small margin).
static func _clear(box: Rect2, avoid: Array[Rect2], screen: Vector2) -> bool:
	if box.position.x < 0.0 or box.position.y < 0.0 or box.end.x > screen.x or box.end.y > screen.y:
		return false
	for r: Rect2 in avoid:
		if box.intersects(r.grow(Config.LANDMARK_POINTER_CLEAR_MARGIN)):
			return false
	return true


# Distance along the perimeter of `rect`, clockwise from its top left corner.
static func _perimeter_param(p: Vector2, rect: Rect2) -> float:
	var w := rect.size.x
	var h := rect.size.y
	var d_top := absf(p.y - rect.position.y)
	var d_right := absf(p.x - rect.end.x)
	var d_bottom := absf(p.y - rect.end.y)
	var d_left := absf(p.x - rect.position.x)
	var best := minf(minf(d_top, d_right), minf(d_bottom, d_left))
	if best == d_top:
		return clampf(p.x - rect.position.x, 0.0, w)
	if best == d_right:
		return w + clampf(p.y - rect.position.y, 0.0, h)
	if best == d_bottom:
		return w + h + clampf(rect.end.x - p.x, 0.0, w)
	return 2.0 * w + h + clampf(rect.end.y - p.y, 0.0, h)


# The point on the perimeter of `rect` at distance `s` from its top left corner (clockwise).
static func _perimeter_point(s: float, rect: Rect2) -> Vector2:
	var w := rect.size.x
	var h := rect.size.y
	if s < w:
		return Vector2(rect.position.x + s, rect.position.y)
	if s < w + h:
		return Vector2(rect.end.x, rect.position.y + (s - w))
	if s < 2.0 * w + h:
		return Vector2(rect.end.x - (s - w - h), rect.end.y)
	return Vector2(rect.position.x, rect.end.y - (s - 2.0 * w - h))


# The HUD rectangles a pointer must keep clear of: every visible HUD panel that has a place on screen.
func _avoid_rects(main: TopDownMain = null) -> Array[Rect2]:
	return HudSafeArea.avoid_rects(_hud, _minimap, main)  # Checkpoint 6: the same list the other edge pointers use.
