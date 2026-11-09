class_name WobbleAlert
extends Control

# Checkpoint 5: the wobble alert. A drained rescued person wobbles for about WOBBLE_SECONDS before they relapse (Person
# .wobbling), and a joy hit saves them. Wobbles used to start off screen and were lost before the player knew. This
# draws a pulsing pointer at the screen edge toward each cluster of off-screen wobblers (the most urgent clusters first,
# at most WOBBLE_ALERT_MAX). The pulse speeds up as wobble_left runs out. The pointers are worked out every
# WOBBLE_ALERT_REFRESH seconds (the pulse is redrawn every frame while one is shown), and they vanish when the person is
# saved, relapses, comes on screen, or the round ends. Snag round: a tip is never placed by a walk round the screen
# edge any more. It sits where the ray from the screen centre leaves the safe rectangle (safe_rect: the screen less the
# shown HUD panels, the minimap and the spirit cue), shrunk by WOBBLE_ALERT_REACH so the whole pointer stays inside it.
# The minimap blips are in minimap.gd. Placeholder look: a warm ring and arrow; styled look: the same, in StyleUi cells
# with an ink edge.

var main: TopDownMain
var _hud: Hud
var _minimap: Control
# Each pointer: place()'s tip, dir, label and box, plus "count" (wobblers it stands for) and "urgency" (0..1).
var _shown: Array[Dictionary] = []
var _since: float = 1.0e9
var _clock: float = 0.0


# Builds the node on the HUD and returns it. (The only wiring TopDownMain needs.)
static func attach(level: TopDownMain) -> WobbleAlert:
	var a := WobbleAlert.new()
	a.main = level
	level.hud.add_child(a)
	a.setup(level.hud, level.minimap)
	return a


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


# Takes the HUD panels to keep clear of (the same list the landmark pointers keep clear of) and the minimap.
func setup(hud: Hud, minimap: Control) -> void:
	_hud = hud
	_minimap = minimap


func _process(delta: float) -> void:
	_clock += delta
	_since += delta
	if _since >= HudConfig.WOBBLE_ALERT_REFRESH:
		update_now()
	elif not _shown.is_empty():
		queue_redraw()


# Works the pointers out now. The game calls it every WOBBLE_ALERT_REFRESH seconds (from _process); the tests call it
# directly. Nothing is shown while the round is not running, or in a window too small for the HUD (headless 64 x 64).
func update_now() -> void:
	_since = 0.0
	_shown.clear()
	var screen := get_viewport_rect().size
	if main != null and _hud != null and main.running and screen.x >= 400.0 and screen.y >= 300.0:
		var tips := safe_rect(screen).grow(-HudConfig.WOBBLE_ALERT_REACH)
		if tips.size.x > 0.0 and tips.size.y > 0.0:
			var clusters := group(_off_screen_entries(screen), HudConfig.WOBBLE_ALERT_CLUSTER_RADIUS)
			for ci: int in range(mini(clusters.size(), HudConfig.WOBBLE_ALERT_MAX)):
				var cluster: Dictionary = clusters[ci]
				var centre: Vector3 = cluster["pos"]
				var placed := tip_for(main.world_to_screen(centre), screen, tips)
				placed["count"] = cluster["count"]
				placed["urgency"] = cluster["urgency"]
				_shown.append(placed)
	queue_redraw()


# How many pointers are shown now (tests read this).
func shown_count() -> int:
	return _shown.size()


# Snag round: the rectangle the pointers stay in, for a window of size `screen`: the screen inset by
# WOBBLE_ALERT_SAFE_INSET, cut at the top by every shown HUD rectangle in the top half of the screen and at the bottom
# by every one in the bottom half (each with WOBBLE_ALERT_PANEL_GAP to spare). The rectangles come from the HUD itself
# (avoid_rects), so a panel that moves or is hidden moves or frees the rectangle with it.
func safe_rect(screen: Vector2) -> Rect2:
	return HudSafeArea.safe_rect(screen, avoid_rects())  # Checkpoint 6: shared with the gap and landmark pointers.


# The tip and outward direction for a wobbler at window position `target`: the point where the ray from the screen
# centre to it leaves `tips` (the safe rectangle shrunk by WOBBLE_ALERT_REACH; the centre is clamped into it first).
# Returns {"tip": Vector2, "dir": Vector2 (unit, outward)}.
static func tip_for(target: Vector2, screen: Vector2, tips: Rect2) -> Dictionary:
	var centre := screen * 0.5
	var dir := (target - centre).normalized() if (target - centre).length() > 0.0001 else Vector2.UP
	var origin := centre.clamp(tips.position, tips.end)
	var t := minf(
		_exit_param(origin.x, dir.x, tips.position.x, tips.end.x),
		_exit_param(origin.y, dir.y, tips.position.y, tips.end.y)
	)
	var tip := (origin + dir * t).clamp(tips.position, tips.end)
	return {"tip": tip, "dir": dir}


# How far along a ray from `origin` (one axis: `step` is its direction) it leaves [lo, hi]; INF when it never does.
static func _exit_param(origin: float, step: float, lo: float, hi: float) -> float:
	if step > 0.0001:
		return (hi - origin) / step
	if step < -0.0001:
		return (lo - origin) / step
	return INF


# The first pointer shown (empty dictionary if none), for tests and the styled look's checks.
func first_pointer() -> Dictionary:
	return _shown[0] if not _shown.is_empty() else {}


# Every wobbling, rescued person whose spot is off screen, as {"pos": Vector3, "urgency": float}.
func _off_screen_entries(screen: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for p: Person in main.people:
		if not (p.wobbling and p.is_rescued):
			continue
		if LandmarkPointers.on_screen(main.world_to_screen(p.global_position), screen):
			continue
		out.append({"pos": p.global_position, "urgency": p.wobble_progress()})
	return out


# Groups the wobblers (entries {"pos": Vector3, "urgency": float}) into clusters. The most urgent entry goes first; each
# later one joins the first cluster whose first member is within `radius` metres on the ground, else starts its own.
# A cluster is {"pos": Vector3 (the mean of its members), "count": int, "urgency": float (the highest of its members)},
# and the clusters come most urgent first.
static func group(entries: Array[Dictionary], radius: float) -> Array[Dictionary]:
	var sorted: Array[Dictionary] = entries.duplicate()
	sorted.sort_custom(WobbleAlert._more_urgent)
	var seeds: Array[Vector3] = []
	var sums: Array[Vector3] = []
	var counts: Array[int] = []
	var peaks: Array[float] = []
	var out: Array[Dictionary] = []
	for e: Dictionary in sorted:
		var at: Vector3 = e["pos"]
		var urgency: float = e["urgency"]
		var found := -1
		for k: int in range(seeds.size()):
			if _flat_distance(seeds[k], at) <= radius:
				found = k
				break
		if found < 0:
			seeds.append(at)
			sums.append(Vector3.ZERO)
			counts.append(0)
			peaks.append(0.0)
			found = seeds.size() - 1
		sums[found] += at
		counts[found] += 1
		peaks[found] = maxf(peaks[found], urgency)
	for k: int in range(seeds.size()):
		out.append({"pos": sums[k] / float(counts[k]), "count": counts[k], "urgency": peaks[k]})
	return out


static func _more_urgent(a: Dictionary, b: Dictionary) -> bool:
	var ua: float = a["urgency"]
	var ub: float = b["urgency"]
	return ua > ub


# Flat distance on the ground (x and z), in metres.
static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


# The pulse rate (per second) for a wobble at `urgency` (0 just begun, 1 about to relapse).
static func hz_for(urgency: float) -> float:
	return lerpf(
		HudConfig.WOBBLE_ALERT_PULSE_HZ_CALM, HudConfig.WOBBLE_ALERT_PULSE_HZ_URGENT, clampf(urgency, 0.0, 1.0)
	)


# The pulse at clock time `t` for `urgency`: 0 at rest, 1 at the top of each beat.
static func pulse_at(t: float, urgency: float) -> float:
	return 0.5 - 0.5 * cos(TAU * t * hz_for(urgency))


# The pointer's colour: the warm amber, brighter as the pulse rises and as the wobble nears its end.
static func colour_at(urgency: float, pulse: float) -> Color:
	var col := HudConfig.WOBBLE_ALERT_COLOUR
	col.a = lerpf(0.55 + 0.35 * clampf(urgency, 0.0, 1.0), 1.0, pulse)
	return col


func _draw() -> void:
	var font := get_theme_default_font()
	for s: Dictionary in _shown:
		var tip: Vector2 = s["tip"]
		var dir: Vector2 = s["dir"]
		var count: int = s["count"]
		var urgency: float = s["urgency"]
		var pulse := pulse_at(_clock, urgency)
		var ring := HudConfig.WOBBLE_ALERT_RING * (1.0 + HudConfig.WOBBLE_ALERT_PULSE_GROW * pulse)
		var centre := tip - dir * (HudConfig.WOBBLE_ALERT_ARROW + HudConfig.WOBBLE_ALERT_RING)
		var col := colour_at(urgency, pulse)
		if Looks.is_styled():
			_draw_styled(centre, tip, dir, ring, col)
		else:
			draw_circle(centre, ring, Color(col.r, col.g, col.b, col.a * 0.2))
			draw_arc(centre, ring, 0.0, TAU, 24, col, 2.0, true)
			var side := Vector2(-dir.y, dir.x)
			var base := tip - dir * HudConfig.WOBBLE_ALERT_ARROW
			var a := HudConfig.WOBBLE_ALERT_ARROW * 0.6
			draw_colored_polygon(PackedVector2Array([tip, base + side * a, base - side * a]), col)
		if count > 1:
			var shade := StyleUi.INK if Looks.is_styled() else Color(0.0, 0.0, 0.0, col.a)
			draw_string(
				font,
				centre + Vector2(-4.0, 4.0),
				str(count),
				HORIZONTAL_ALIGNMENT_LEFT,
				-1,
				HudConfig.WOBBLE_ALERT_FONT_SIZE,
				shade
			)


# Graphics checkpoint 5 (styled look): a pixel ring with an ink edge and a stepped arrow, in StyleUi's cells.
func _draw_styled(centre: Vector2, tip: Vector2, dir: Vector2, ring: float, col: Color) -> void:
	var cell := StyleUi.cell(self)
	var edge := StyleUi.INK
	edge.a = col.a
	StyleUi.ring(self, centre, ring, cell, edge, 2)
	StyleUi.ring(self, centre, ring, cell, col, 1)
	var side := Vector2(-dir.y, dir.x)
	var base := tip - dir * HudConfig.WOBBLE_ALERT_ARROW
	var a := HudConfig.WOBBLE_ALERT_ARROW * 0.6
	StyleUi.poly(self, PackedVector2Array([tip, base + side * (a + cell), base - side * (a + cell)]), cell, edge)
	StyleUi.poly(self, PackedVector2Array([tip, base + side * a, base - side * a]), cell, col)


# The HUD rectangles a pointer must keep clear of: the HUD panels that are shown (Hud.layout_controls), the minimap, and
# the spirit cue beside the spirit meter (BurstCue's panel and label, which the HUD does not list). A control at zero
# alpha (the placeholder alert line between alerts) does not count. Tests read this too.
func avoid_rects() -> Array[Rect2]:
	return HudSafeArea.avoid_rects(_hud, _minimap, main)
