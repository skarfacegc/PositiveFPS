class_name StyleFeedback
extends RefCounted

# Graphics checkpoint 2: the styled drawing of the FeedbackLayer (see StyleUi for the cell style). Same data model, same
# positions, same colours and timings as the placeholder drawing; the shapes are made of pixel cells with an ink
# edge and
# dithered tracks. The layer calls draw_under() (leaks, tethers, closed flashes, progress rings, faltering markers),
# then
# draws the mood icons itself (MoodIcons is styled too), then draw_over() (blocked sparks, the player's pulse rings).


static func draw_under(layer: FeedbackLayer) -> void:
	var c := StyleUi.cell(layer)
	_motes(layer, c)
	_tethers(layer, c)
	_closes(layer, c)
	_dim_rings(layer, c)
	for m: Dictionary in layer.markers:
		_marker(layer, c, m)


static func draw_over(layer: FeedbackLayer) -> void:
	var c := StyleUi.cell(layer)
	_sparks(layer, c)
	_player_pulses(layer, c)


# The gloom leaking through a gap: grey-violet squares that grow from one cell to three as they drift and fade.
static func _motes(layer: FeedbackLayer, c: float) -> void:
	for m: Dictionary in layer.motes:
		var age: float = m["age"]
		var life: float = m["life"]
		var t := age / life
		var pos: Vector3 = m["pos"]
		var col := BorderConfig.LEAK_COLOUR.lerp(StyleUi.INK, 0.15)
		col.a = 0.9 * minf(t / 0.15, 1.0) * (1.0 - t)
		var cells := 1 + int(t * 2.5)
		var at := StyleUi.cell_of(layer.main.world_to_screen(pos), c)
		layer.draw_rect(Rect2(Vector2(at) * c, Vector2(cells, cells) * c), col)


# Sheltering tethers: dotted violet lines with a small plus at each end; a snapped tether flies apart in cells.
static func _tethers(layer: FeedbackLayer, c: float) -> void:
	var col := MoodConfig.TETHER_COLOUR
	col.a = 0.8
	for t: Dictionary in layer.tethers:
		var a := layer.main.world_to_screen(_v3(t["a"]))
		var b := layer.main.world_to_screen(_v3(t["b"]))
		StyleUi.line(layer, a, b, c, col, 2)
		StyleUi.sparkle(layer, a, 1, c, col)
		StyleUi.sparkle(layer, b, 1, c, col)
	for s: Dictionary in layer.snaps:
		var left: float = s["left"]
		var f := left / MoodConfig.TETHER_SNAP_SECONDS
		var a := layer.main.world_to_screen(_v3(s["a"]))
		var b := layer.main.world_to_screen(_v3(s["b"]))
		var broken := MoodConfig.TETHER_COLOUR
		broken.a = 0.9 * f
		var gap := (1.0 - f) * 14.0
		var dir := (b - a).normalized() if (b - a).length() > 1.0 else Vector2.RIGHT
		var mid := (a + b) * 0.5
		StyleUi.line(layer, a, mid - dir * (4.0 + gap), c, broken, 2)
		StyleUi.line(layer, b, mid + dir * (4.0 + gap), c, broken, 2)
		for k: int in range(4):
			var ang := TAU * float(k) / 4.0 + 0.4
			var d := Vector2(cos(ang), sin(ang))
			StyleUi.put(layer, StyleUi.cell_of(mid + d * (6.0 + 12.0 * (1.0 - f)), c), c, broken)


# The "closed" flash where a faltering person recovered: gold seals along the gap links, a pixel ring and sparkles.
static func _closes(layer: FeedbackLayer, c: float) -> void:
	for cl: Dictionary in layer.closes:
		var left: float = cl["left"]
		var f := left / HudConfig.FALTER_CLOSED_SECONDS
		var at := layer.main.world_to_screen(_v3(cl["pos"]))
		var col := HudConfig.FALTER_SEAL_COLOUR
		col.a = f
		var links: Array = cl["links"]
		for g: Vector3 in links:
			var g_screen := layer.main.world_to_screen(g)
			StyleUi.line(layer, g_screen, at, c, col)
			StyleUi.line(layer, g_screen + Vector2(c, 0.0), at + Vector2(c, 0.0), c, col)
		StyleUi.ring(layer, at, lerpf(60.0, 20.0, f), c, col, 2, 1.0)
		var up := at + Vector2(0, -20)
		StyleUi.sparkle(layer, up, 2, c, col)
		StyleUi.sparkle(layer, up + Vector2(-16, 6), 1, c, col)
		StyleUi.sparkle(layer, up + Vector2(16, 4), 1, c, col)


# A ring of cells round a body: a dithered ink track, then the filled part of the arc over an ink edge.
static func _progress_ring(layer: FeedbackLayer, c: float, centre: Vector2, progress: float, alpha: float) -> void:
	var track := Color(0.1, 0.08, 0.14, 0.6 * alpha)
	StyleUi.ring(layer, centre, HudConfig.FALTER_RING_RADIUS, c, track, 3, 1.0, 0.0, TAU, true)
	if progress <= 0.0:
		return
	var edge := StyleUi.INK
	edge.a = 0.75 * alpha
	var a0 := -PI * 0.5
	var a1 := a0 + TAU * progress
	StyleUi.ring(layer, centre, HudConfig.FALTER_RING_RADIUS, c, edge, 5, 1.0, a0, a1)
	var pc := BorderConfig.BORDER_GAP_COLOUR.lerp(HudConfig.FALTER_SEAL_COLOUR, progress)
	pc.a = alpha
	StyleUi.ring(layer, centre, HudConfig.FALTER_RING_RADIUS, c, pc, 3, 1.0, a0, a1)


# The round-14 progress ring on a dimmed person hit by joy (fades in its last half second).
static func _dim_rings(layer: FeedbackLayer, c: float) -> void:
	for d: Dictionary in layer.dim_rings:
		var left: float = d["left"]
		var feet: Vector2 = d["feet"]
		var head: Vector2 = d["head"]
		var prog: float = d["progress"]
		_progress_ring(layer, c, (feet + head) * 0.5 + Vector2(0, 6), prog, clampf(left / 0.5, 0.0, 1.0))


# A faltering border person: the pulsing flattened ring at their feet, the progress ring and the "!" badge.
static func _marker(layer: FeedbackLayer, c: float, m: Dictionary) -> void:
	var u: float = m["urgency"]
	var feet: Vector2 = m["feet"]
	var head: Vector2 = m["head"]
	var prog: float = m["progress"]
	var clock := layer.clock()
	var wave := 0.5 - 0.5 * cos(TAU * clock * lerpf(HudConfig.FALTER_PULSE_HZ_MIN, HudConfig.FALTER_PULSE_HZ_MAX, u))
	var base := BorderConfig.BORDER_GAP_COLOUR.lerp(Color(1.0, 0.85, 0.75), u * 0.6)
	var radius := HudConfig.FALTER_MARKER_RADIUS * (0.85 + 0.3 * wave) * (1.0 + 0.3 * u)
	var edge := StyleUi.INK
	edge.a = 0.8
	StyleUi.ring(layer, feet, radius, c, edge, 4 + int(2.0 * u), 0.55)
	var ring := base
	ring.a = lerpf(0.55, 1.0, wave)
	StyleUi.ring(layer, feet, radius, c, ring, 2 + int(2.0 * u), 0.55)
	_progress_ring(layer, c, (feet + head) * 0.5 + Vector2(0, 6), prog, 1.0)
	var badge := HudConfig.FALTER_BADGE_SIZE * (1.0 + 0.35 * u) * (1.0 + 0.1 * wave)
	var badge_col := base
	badge_col.a = 1.0
	MoodIcons.draw(layer, MoodIcons.Kind.BANG, head + Vector2(0, -22.0 - 4.0 * wave), badge, badge_col)


# Joy turned away: eight rays of cells radiating from the chest.
static func _sparks(layer: FeedbackLayer, c: float) -> void:
	for s: Dictionary in layer.sparks:
		var left: float = s["left"]
		var f := left / MoodConfig.BLOCK_SPARK_SECONDS
		var t := 1.0 - f
		var at := layer.main.world_to_screen(_v3(s["pos"]))
		var col: Color = s["colour"]
		col.a = f
		var turn: float = s["turn"]
		for k: int in range(8):
			var a := turn + TAU * float(k) / 8.0
			var d := Vector2(cos(a), sin(a))
			StyleUi.line(layer, at + d * (8.0 + 12.0 * t), at + d * (16.0 + 24.0 * t), c, col)


# The ring that pulses round the player when spirit is gained (closing in), spent (opening out) or lost.
static func _player_pulses(layer: FeedbackLayer, c: float) -> void:
	for p: Dictionary in layer.player_pulses:
		var left: float = p["left"]
		var f := left / 0.5
		var kind: int = p["kind"]
		var col := HudConfig.SPIRIT_GAIN_COLOUR
		var radius := lerpf(70.0, 24.0, f)
		if kind == SpiritMeter.Moment.SPEND:
			col = HudConfig.SPIRIT_SPEND_COLOUR
			radius = lerpf(24.0, 70.0, f)
		elif kind == SpiritMeter.Moment.LOSS:
			col = HudConfig.SPIRIT_LOSS_COLOUR
			radius = lerpf(80.0, 22.0, f)
		col.a = f
		var at := layer.main.world_to_screen(layer.main.player.global_position)
		StyleUi.ring(layer, at, radius, c, col, 2, 0.6)


static func _v3(v: Variant) -> Vector3:
	var out: Vector3 = v
	return out
