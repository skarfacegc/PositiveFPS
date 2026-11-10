class_name Minimap
extends Control

# The round minimap (round 10), top-left, about TD_MINIMAP_WIDTH_FRACTION of the screen width. It shows the whole
# plaza in a circle: warm and grey ground, soft people clouds (round 20: where unrescued people cluster, binned into a
# coarse grid and recounted twice a second), buildings, the border line, the gaps (coral), the border members (cream
# dots), the dimmed people (dimmed dots), the landmark (a star), the player (a bright dot) and the camera's view
# rectangle.
#
# The picture is drawn into a small image (TD_MINIMAP_RESOLUTION pixels across, outside the circle left transparent)
# and shown scaled up with nearest-neighbour filtering. It is rebuilt about every TD_MINIMAP_REFRESH_SECONDS from the
# data model below, so tests can check what is on the map without reading pixels.

const RESOLUTION := HudConfig.TD_MINIMAP_RESOLUTION
const CLOUD_PROFILE_STEPS := 64

# ---- The data model (world metres, x and z; the plaza is centred on the origin) ---- The border loop, as points in
# order, and for each segment whether it is a gap.
var border_pts := PackedVector2Array()
var gap_flags: Array[bool] = []
# Round 16: for each segment, whether the map edge seals it (drawn in the look's seal colour, see MinimapLook).
var seal_flags: Array[bool] = []
# Border members, dimmed people, the landmark, the player, and the four corners of the camera's view on the ground.
var member_pts := PackedVector2Array()
var dimmed_pts := PackedVector2Array()
var landmark_pts := PackedVector2Array()
# Round 19: which of them are held right now (set by the level before each refresh).
var held_landmarks: Array[bool] = []
var player_pos := Vector2.ZERO
var view_pts := PackedVector2Array()
# Buildings: each block's footprint (world rectangle) and whether it is beautified (warm).
var building_rects: Array[Rect2] = []
var building_warm: Array[bool] = []
# Round 12b: brief blips where someone just became dimmed: each is {"pos": Vector2, "left": seconds}.
var blips: Array[Dictionary] = []
# Round 13b: a marker on each open gap, {"pos": Vector2, "urgency": 0..1}; it grows and brightens with urgency.
var gap_markers: Array[Dictionary] = []
# Round 20: the people clouds. Unrescued people binned into a coarse grid: for each cell with enough people, {"centre":
# Vector2 (world, the mean of its people, kept inside the map circle), "count": int, "radius": float (picture pixels),
# "peak": float (alpha at the centre)}. Recounted every MINIMAP_CLOUD_SECONDS (see tick).
var cloud_cells: Array[Dictionary] = []
# Round 24: the dawn front, as the half size (metres) of the square it has reached; people outside it are lit. Negative
# when first light has not begun (set by FirstLight).
var first_light_edge: float = -1.0
# Checkpoint 5: a pulsing blip on each rescued person who is wobbling ({"pos": Vector2, "urgency": 0..1}).
var wobble_marks: Array[Dictionary] = []
# Round 25: the gloom tide's fog edge: the side's unit direction, or Vector2.INF for none (set by GloomTide).
var tide_fog := Vector2.INF

# The look: the palette and the frame (see scripts/looks/minimap_look.gd). The picture itself is built here.
var look: MinimapLook
var _image: Image
var _texture: ImageTexture
var _ground: PaintedGround
var _timer: float = HudConfig.TD_MINIMAP_REFRESH_SECONDS
var _wobble_clock: float = 0.0  # Checkpoint 5: the clock for the wobble blips' pulse (see WobbleAlert.pulse_at).
# Round 20: the cloud's alpha for each picture pixel (RESOLUTION x RESOLUTION, row by row; 0 where there is none).
var _cloud_alpha := PackedFloat32Array()
var _cloud_age: float = 0.0
var _cloud_due: bool = true
# Round 21: each busy cell's blob. `_cloud_targets` holds where the last recount put it (cell index -> {"pos", "radius",
# "peak"}); `_cloud_shown` holds what is drawn now, which eases toward the targets every frame (see _ease_clouds).
var _cloud_targets: Dictionary = {}
var _cloud_shown: Dictionary = {}
# Set when the drawn clouds have changed, so the alpha map is only repainted then.
var _cloud_dirty: bool = false
# Round 21: seconds until the drawn clouds may be repainted in a picture refresh (see MINIMAP_CLOUD_PAINT_SECONDS).
var _cloud_paint_left: float = 0.0
# Round 21: the blob falloff table (see _build_cloud_profile), built on the first paint.
var _cloud_profile := PackedFloat32Array()
# Round 21: false until the first recount, which snaps its blobs into place (see refresh_clouds).
var _cloud_started: bool = false
# The cached ground layer (see _build_base) and what it was built from; `_cloud_version` counts cloud repaints.
var _base: Image
var _base_left: float = 0.0
var _base_look: MinimapLook
var _base_edge: float = -1.0
var _base_cloud_version: int = -1
var _base_ground: PaintedGround
var _cloud_version: int = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_image = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	if look == null:
		look = Looks.minimap_look()


# Swaps the look in place (F4): the data model is kept, the picture is redrawn with the new palette.
func rebuild_look() -> void:
	look = Looks.minimap_look()
	_render()
	queue_redraw()


# The minimap is a circle: the picture is clipped to it, and the frame is drawn round it.
func is_circular() -> bool:
	return true


# The circle's radius on screen, in pixels.
func radius() -> float:
	return size.x * 0.5


# Advances the refresh timer by `delta`. Returns true when the picture should be rebuilt now (about 10 times a
# second).
func tick(delta: float) -> bool:
	_wobble_clock += delta
	for i: int in range(blips.size() - 1, -1, -1):
		var left: float = blips[i]["left"] - delta
		blips[i]["left"] = left
		if left <= 0.0:
			blips.remove_at(i)
	_cloud_paint_left -= delta
	_base_left -= delta
	_cloud_age += delta
	if _cloud_age >= HudConfig.MINIMAP_CLOUD_SECONDS:
		_cloud_due = true
	_ease_clouds(delta)
	_timer += delta
	if _timer < HudConfig.TD_MINIMAP_REFRESH_SECONDS:
		return false
	_timer = 0.0
	return true


# Round 20: true when the people clouds are due a recount (at the next refresh_from).
func clouds_due() -> bool:
	return _cloud_due


# Reads the level into the data model and redraws the picture. `view_half` is the half size of the camera's view on
# the ground, in metres (x across, z along the ground).
func refresh_from(
	ground: PaintedGround,
	border: Border,
	people: Array[Person],
	player_at: Vector3,
	view_centre: Vector3,
	view_half: Vector2
) -> void:
	_ground = ground
	border_pts = border.polygon.duplicate()
	gap_flags.clear()
	seal_flags.clear()
	for j: int in range(border.polygon.size()):
		gap_flags.append(border.segment_is_gap(j))
		seal_flags.append(border.is_wall(j))  # A wall is drawn in the look's seal colour.
	gap_markers.clear()
	var mids := border.gap_midpoints_cached()
	var urgencies := border.gap_urgencies()
	for gi: int in range(mids.size()):
		var u := urgencies[gi] if gi < urgencies.size() else 0.0
		gap_markers.append({"pos": Vector2(mids[gi].x, mids[gi].z), "urgency": u})
	member_pts = PackedVector2Array()
	for m: Person in border.members:
		member_pts.append(Vector2(m.position.x, m.position.z))
	dimmed_pts = PackedVector2Array()
	for p: Person in people:
		if not p.is_rescued and GloomSim.is_dimmed(p):
			dimmed_pts.append(Vector2(p.position.x, p.position.z))
	landmark_pts = PackedVector2Array()
	for at: Vector3 in LandmarkConfig.LANDMARK_POSITIONS:
		landmark_pts.append(Vector2(at.x, at.z))
	player_at.y = 0.0
	player_pos = Vector2(player_at.x, player_at.z)
	var c := Vector2(view_centre.x, view_centre.z)
	view_pts = PackedVector2Array(
		[
			c + Vector2(-view_half.x, -view_half.y),
			c + Vector2(view_half.x, -view_half.y),
			c + Vector2(view_half.x, view_half.y),
			c + Vector2(-view_half.x, view_half.y),
		]
	)
	building_rects.clear()
	building_warm.clear()
	for b: Building in border.buildings:
		building_rects.append(Rect2(b.centre - b.half, b.half * 2.0))
		building_warm.append(b.beautified)
	wobble_marks.clear()
	for w: Person in people:
		if w.wobbling and w.is_rescued:
			wobble_marks.append({"pos": Vector2(w.position.x, w.position.z), "urgency": w.wobble_progress()})
	if _cloud_due:
		refresh_clouds(people)
	_render()


# Round 20: bins the unrescued people into the coarse grid and sets one blob per busy cell, at the mean of its people.
# Called by refresh_from when a recount is due (twice a second); tests call it directly. It only sets where the blobs
# should go (`_cloud_targets`): tick eases the drawn blobs toward them, and the picture repaints them.
# Round 21: the first recount of a level snaps the blobs into place; later new blobs fade in from nothing.
func refresh_clouds(people: Array[Person]) -> void:
	_cloud_due = false
	_cloud_age = 0.0
	var n := HudConfig.MINIMAP_CLOUD_CELLS
	var cell_m := float(Config.TD_PLAZA_SIZE) / float(n)
	var half := Config.TD_PLAZA_SIZE * 0.5
	var rim := half * HudConfig.MINIMAP_CLOUD_RIM
	var counts := PackedInt32Array()
	counts.resize(n * n)
	var sums := PackedVector2Array()
	sums.resize(n * n)
	for p: Person in people:
		if p.is_rescued:
			continue
		var ix := clampi(floori((p.position.x + half) / cell_m), 0, n - 1)
		var iz := clampi(floori((p.position.z + half) / cell_m), 0, n - 1)
		counts[iz * n + ix] += 1
		sums[iz * n + ix] += Vector2(p.position.x, p.position.z)
	cloud_cells.clear()
	_cloud_targets.clear()
	for idx: int in range(n * n):
		var count := counts[idx]
		if count < HudConfig.MINIMAP_CLOUD_MIN_COUNT:
			continue
		var centre := sums[idx] / float(count)
		# A crowd in a corner of the square is outside the map circle: its blob sits at the rim in that direction.
		if centre.length() > rim:
			centre = centre.normalized() * rim
		var radius := minf(
			HudConfig.MINIMAP_CLOUD_BASE_RADIUS_PX + HudConfig.MINIMAP_CLOUD_RADIUS_PER_PERSON_PX * sqrt(float(count)),
			HudConfig.MINIMAP_CLOUD_MAX_RADIUS_PX
		)
		var peak := (
			HudConfig.MINIMAP_CLOUD_MAX_ALPHA * minf(1.0, float(count) / float(HudConfig.MINIMAP_CLOUD_FULL_COUNT))
		)
		cloud_cells.append({"centre": centre, "count": count, "radius": radius, "peak": peak})
		_cloud_targets[idx] = {"pos": centre, "radius": radius, "peak": peak}
	if not _cloud_started:
		_cloud_started = true
		for idx: int in _cloud_targets:
			var goal: Dictionary = _cloud_targets[idx]
			_cloud_shown[idx] = goal.duplicate()
	_cloud_dirty = true


# Round 21: moves each drawn blob toward its target (exponential ease, time constant MINIMAP_CLOUD_EASE_SECONDS). A
# blob with no target fades out and is dropped. Sets `_cloud_dirty` only when something visibly moved.
func _ease_clouds(delta: float) -> void:
	if _cloud_targets.is_empty() and _cloud_shown.is_empty():
		return
	var k := 1.0 - exp(-delta / HudConfig.MINIMAP_CLOUD_EASE_SECONDS)
	for idx: int in _cloud_targets:
		if not _cloud_shown.has(idx):
			_cloud_shown[idx] = {
				"pos": _cloud_targets[idx]["pos"], "radius": _cloud_targets[idx]["radius"], "peak": 0.0
			}
	var moved := false
	for idx: int in _cloud_shown.keys():
		var s: Dictionary = _cloud_shown[idx]
		var t: Dictionary = _cloud_targets.get(idx, {"pos": s["pos"], "radius": s["radius"], "peak": 0.0})
		var pos: Vector2 = s["pos"]
		var radius: float = s["radius"]
		var peak: float = s["peak"]
		var goal_pos: Vector2 = t["pos"]
		var goal_radius: float = t["radius"]
		var goal_peak: float = t["peak"]
		var next_pos := pos.lerp(goal_pos, k)
		var next_radius := lerpf(radius, goal_radius, k)
		var next_peak := lerpf(peak, goal_peak, k)
		if not _cloud_targets.has(idx) and next_peak < 0.002:
			_cloud_shown.erase(idx)
			moved = true
			continue
		if (
			next_pos.distance_squared_to(pos) > 0.0001
			or absf(next_radius - radius) > 0.01
			or absf(next_peak - peak) > 0.001
		):
			moved = true
		s["pos"] = next_pos
		s["radius"] = next_radius
		s["peak"] = next_peak
	if moved:
		_cloud_dirty = true


# Round 20: the alpha of the people clouds at picture pixel (px, py), 0 to 1. Zero outside every blob.
func cloud_alpha_at(px: int, py: int) -> float:
	_update_cloud_alpha(true)
	if _cloud_alpha.size() != RESOLUTION * RESOLUTION or px < 0 or py < 0 or px >= RESOLUTION or py >= RESOLUTION:
		return 0.0
	return _cloud_alpha[py * RESOLUTION + px]


# Round 21: repaints the cloud alpha map only when the drawn clouds have changed since the last paint.
func _update_cloud_alpha(force: bool = false) -> void:
	if _cloud_dirty and (force or _cloud_paint_left <= 0.0):
		_paint_clouds()
		_cloud_dirty = false
		_cloud_version += 1
		_cloud_paint_left = HudConfig.MINIMAP_CLOUD_PAINT_SECONDS


# Round 20: fills the cloud alpha map from the drawn blobs. Each blob is solid to MINIMAP_CLOUD_CORE of its radius and
# then fades smoothly (smoothstep) to nothing at its edge, so it is a soft patch, not a dot. Overlapping blobs combine
# (1 - (1 - a)(1 - b)), so a crowd spread over two cells reads as one cloud.
# Round 21: painted from the eased blobs (`_cloud_shown`), and only when they changed (see `_cloud_dirty`).
func _paint_clouds() -> void:
	_cloud_alpha.resize(RESOLUTION * RESOLUTION)
	_cloud_alpha.fill(0.0)
	if _cloud_profile.size() != CLOUD_PROFILE_STEPS:
		_build_cloud_profile()
	for idx: int in _cloud_shown:
		var s: Dictionary = _cloud_shown[idx]
		var peak: float = s["peak"]
		if peak <= 0.0:
			continue
		var shown_at: Vector2 = s["pos"]
		var c := _to_px(shown_at)
		var r: float = s["radius"]
		var inv_r2 := 1.0 / (r * r)
		for py: int in range(maxi(0, floori(c.y - r)), mini(RESOLUTION, ceili(c.y + r) + 1)):
			var dy := float(py) + 0.5 - c.y
			for px: int in range(maxi(0, floori(c.x - r)), mini(RESOLUTION, ceili(c.x + r) + 1)):
				var dx := float(px) + 0.5 - c.x
				var d2 := (dx * dx + dy * dy) * inv_r2
				if d2 >= 1.0:
					continue
				var f := _cloud_profile[mini(int(d2 * CLOUD_PROFILE_STEPS), CLOUD_PROFILE_STEPS - 1)]
				var i := py * RESOLUTION + px
				_cloud_alpha[i] = 1.0 - (1.0 - _cloud_alpha[i]) * (1.0 - peak * f)


# Round 21: the blob's falloff, tabulated by squared distance from the centre (0 to 1 across the radius), so the paint
# loop needs no square root or smoothstep per pixel. Entry k is the falloff at the middle of its slice.
func _build_cloud_profile() -> void:
	_cloud_profile.resize(CLOUD_PROFILE_STEPS)
	var core := HudConfig.MINIMAP_CLOUD_CORE
	for k: int in range(CLOUD_PROFILE_STEPS):
		var d := sqrt((float(k) + 0.5) / float(CLOUD_PROFILE_STEPS))
		var t := clampf((d - core) / (1.0 - core), 0.0, 1.0)
		_cloud_profile[k] = 1.0 - t * t * (3.0 - 2.0 * t)


# Round 12b: a blip at a world point (x, z) for MINIMAP_BLIP_SECONDS, drawn as a ring (someone became dimmed).
func add_blip(world: Vector2) -> void:
	blips.append({"pos": world, "left": HudConfig.MINIMAP_BLIP_SECONDS})


# ---- Drawing
# -------------------------------------------------------------------------------------------------------------


func _draw() -> void:
	look.draw_back(self)
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	look.draw_frame(self)


# The ground layer (ground colour, dawn front and people clouds) is the costly part of a redraw: a per-pixel loop
# over the whole circle, about 8 ms. It is kept in `_base` and rebuilt only when the clouds repaint, the dawn front
# moves, the look changes, or MINIMAP_GROUND_SECONDS have passed (the painted ground changes slowly); every other
# redraw copies it.
func _base_is_current() -> bool:
	return (
		_base != null
		and _base_left > 0.0
		and _base_look == look
		and _base_edge == first_light_edge
		and _base_cloud_version == _cloud_version
		and _base_ground == _ground
	)


func _build_base() -> void:
	if _base == null:
		_base = Image.create(RESOLUTION, RESOLUTION, false, Image.FORMAT_RGBA8)
	_base.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cloud := look.cloud_colour()
	var clouds_on := cloud.a > 0.0 and _cloud_alpha.size() == RESOLUTION * RESOLUTION
	for py: int in range(RESOLUTION):
		for px: int in range(RESOLUTION):
			if _in_circle(Vector2(px + 0.5, py + 0.5)):
				var w := _to_world(Vector2(px + 0.5, py + 0.5))
				var col := _ground_colour(w, px, py)
				if first_light_edge >= 0.0 and w.length() >= first_light_edge:
					col = look.first_light("ground", col, px, py)
				# Round 20: the people clouds sit on the ground, under the buildings and every marker.
				if clouds_on and _cloud_alpha[py * RESOLUTION + px] > 0.0:
					col = col.lerp(cloud, _cloud_alpha[py * RESOLUTION + px] * cloud.a)
				_base.set_pixel(px, py, col)
	_base_left = HudConfig.MINIMAP_GROUND_SECONDS
	_base_look = look
	_base_edge = first_light_edge
	_base_cloud_version = _cloud_version
	_base_ground = _ground


# Rebuilds the image from the data model: the ground layer, then the buildings, the border, the people, the landmark,
# the player and the view.
func _render() -> void:
	if _image == null:
		return
	_update_cloud_alpha()
	if not _base_is_current():
		_build_base()
	_image.copy_from(_base)
	for i: int in range(building_rects.size()):
		_fill_rect(building_rects[i], look.building_colour(building_warm[i]))
	var n := border_pts.size()
	for j: int in range(n):
		var a := border_pts[j]
		var b := border_pts[(j + 1) % n]
		if j < seal_flags.size() and seal_flags[j]:
			_sealed_line(a, b)
		else:
			_line(a, b, look.line_colour(gap_flags[j]))
	if first_light_edge >= 0.0:
		_first_light_line()
	if tide_fog != Vector2.INF:
		_tide_fog_edge()
	for m: Vector2 in member_pts:
		_marker(m, 1.6, look.member_colour(), "member")
	for d: Vector2 in dimmed_pts:
		_marker(d, 1.3, look.dimmed_colour(), "dimmed")
	for b: Dictionary in blips:
		var at: Vector2 = b["pos"]
		var left: float = b["left"]
		_ring(at, 2.0 + 3.0 * (1.0 - left / HudConfig.MINIMAP_BLIP_SECONDS), HudConfig.MINIMAP_BLIP_COLOUR)
	for gm: Dictionary in gap_markers:
		var u: float = gm["urgency"]
		var at: Vector2 = gm["pos"]
		_marker(at, 1.4 + 1.8 * u, look.line_colour(true).lerp(Color(1.0, 0.9, 0.82), u * 0.8), "gap")
		if u > 0.5:
			_ring(at, 3.4 + 2.0 * u, look.line_colour(true))
	# Checkpoint 5: a wobbling person is a blip that pulses (faster as the wobble runs out); the look sets its colour.
	for wb: Dictionary in wobble_marks:
		var wpos: Vector2 = wb["pos"]
		var wurgency: float = wb["urgency"]
		var pulse := WobbleAlert.pulse_at(_wobble_clock, wurgency)
		var wcol := look.member_colour(pulse)
		if wcol.a > 0.0:
			_marker(wpos, HudConfig.WOBBLE_BLIP_RADIUS, wcol, "wobble")
			_ring(wpos, HudConfig.WOBBLE_BLIP_RADIUS + HudConfig.WOBBLE_BLIP_PULSE_GROW * pulse, wcol)
	for k: int in range(landmark_pts.size()):
		var held := k < held_landmarks.size() and held_landmarks[k]
		var star_halo := look.halo_colour("landmark")
		if star_halo.a > 0.0:
			_star(landmark_pts[k], star_halo, 1.4)
		_star(landmark_pts[k], look.landmark_state_colour(held), look.landmark_star_grow(held))
		if held:
			_ring(landmark_pts[k], 5.6, look.landmark_colour())
		else:
			# Round 22: an unheld landmark may carry a ring of its own (placeholder look), so it is easy to find.
			var unheld_ring := look.unheld_landmark_ring_colour()
			if unheld_ring.a > 0.0:
				_ring(landmark_pts[k], HudConfig.TD_MINIMAP_LANDMARK_UNHELD_RING_RADIUS, unheld_ring)
	_marker(player_pos, 2.2, look.player_colour(), "player")
	for k: int in range(view_pts.size()):
		_line(view_pts[k], view_pts[(k + 1) % view_pts.size()], look.view_colour())
	_texture.update(_image)


# Round 24: the dawn front, a warm round outline two pixels thick (a circle since checkpoint 6).
func _first_light_line() -> void:
	var e := first_light_edge
	var px_metres := float(Config.TD_PLAZA_SIZE) / float(RESOLUTION)
	var ink := look.first_light("ink", Color.WHITE, 0, 0)
	if ink.a > 0.0:  # Graphics checkpoint 5: a dark line just ahead of the front (the styled look).
		_round_line(maxf(0.0, e - px_metres * 2.0), ink)
	for k: int in range(2):
		_round_line(maxf(0.0, e - px_metres * float(k)), look.first_light("line", Color.WHITE, 0, 0))


# Round 25: the gloom tide's fog edge: arcs on the rim of the plaza's circle, TIDE_MINIMAP_BANDS of them (each
# step inward fainter), spanning TIDE_HALF_WIDTH either side of the side the tide comes from.
func _tide_fog_edge() -> void:
	var rim := float(Config.TD_PLAZA_SIZE) * 0.5
	var mid := tide_fog.angle()
	var segs := NightConfig.TIDE_MINIMAP_SEGMENTS
	for k: int in range(NightConfig.TIDE_MINIMAP_BANDS):
		var r := rim - float(k) * NightConfig.TIDE_MINIMAP_BAND_STEP
		var col := NightConfig.TIDE_MINIMAP_COLOUR
		col.a *= 1.0 - float(k) / float(NightConfig.TIDE_MINIMAP_BANDS)
		for j: int in range(segs):
			var a0 := lerpf(
				mid - NightConfig.TIDE_HALF_WIDTH, mid + NightConfig.TIDE_HALF_WIDTH, float(j) / float(segs)
			)
			var a1 := lerpf(
				mid - NightConfig.TIDE_HALF_WIDTH, mid + NightConfig.TIDE_HALF_WIDTH, float(j + 1) / float(segs)
			)
			_line(Vector2(cos(a0), sin(a0)) * r, Vector2(cos(a1), sin(a1)) * r, col)


# A circle of `radius` metres about the centre, drawn as short straight pieces.
func _round_line(radius: float, col: Color) -> void:
	var segs := NightConfig.FIRST_LIGHT_RING_SEGMENTS
	for j: int in range(segs):
		var a0 := TAU * float(j) / float(segs)
		var a1 := TAU * float(j + 1) / float(segs)
		_line(Vector2(cos(a0), sin(a0)) * radius, Vector2(cos(a1), sin(a1)) * radius, col)


# A stretch of the loop sealed by the map edge (round 16): the look's seal colour, `seal_width()` pixels thick (the
# extra
# rows are shifted one pixel toward the middle of the map).
func _sealed_line(a: Vector2, b: Vector2) -> void:
	var col := look.seal_colour()
	_line(a, b, col)
	var px_metres := float(Config.TD_PLAZA_SIZE) / float(RESOLUTION)
	for k: int in range(1, look.seal_width()):
		var shift := -Vector2(signf(a.x + b.x), signf(a.y + b.y)) * px_metres * float(k)
		_line(a + shift, b + shift, col)


func _ground_colour(w: Vector2, px: int, py: int) -> Color:
	return look.ground_colour(_ground, w, px, py)


# A round marker, with the look's outline round it when it has one.
func _marker(w: Vector2, radius_px: float, col: Color, kind: String) -> void:
	var halo := look.halo_colour(kind)
	if halo.a > 0.0:
		_disc(w, radius_px + 0.9, halo)
	_disc(w, radius_px, col)


# Pixel coordinates (0 to RESOLUTION) of a world point (metres).
func _to_px(w: Vector2) -> Vector2:
	var half := Config.TD_PLAZA_SIZE * 0.5
	return (w + Vector2(half, half)) / float(Config.TD_PLAZA_SIZE) * float(RESOLUTION)


# The world point (metres) of a pixel position.
func _to_world(px: Vector2) -> Vector2:
	var half := Config.TD_PLAZA_SIZE * 0.5
	return px / float(RESOLUTION) * float(Config.TD_PLAZA_SIZE) - Vector2(half, half)


func _in_circle(px: Vector2) -> bool:
	var centre := Vector2(RESOLUTION, RESOLUTION) * 0.5
	return px.distance_to(centre) <= RESOLUTION * 0.5


# Sets one pixel, if it is on the image and inside the circle.
func _put(px: int, py: int, col: Color) -> void:
	if px < 0 or py < 0 or px >= RESOLUTION or py >= RESOLUTION:
		return
	if not _in_circle(Vector2(px + 0.5, py + 0.5)):
		return
	_image.set_pixel(px, py, col)


func _line(a_world: Vector2, b_world: Vector2, col: Color) -> void:
	var a := _to_px(a_world)
	var b := _to_px(b_world)
	var steps := int(maxf(absf(b.x - a.x), absf(b.y - a.y))) + 1
	for i: int in range(steps + 1):
		var t := float(i) / float(steps)
		var p := a.lerp(b, t)
		_put(floori(p.x), floori(p.y), col)


func _disc(w: Vector2, radius_px: float, col: Color) -> void:
	var c := _to_px(w)
	for py: int in range(floori(c.y - radius_px), ceili(c.y + radius_px) + 1):
		for px: int in range(floori(c.x - radius_px), ceili(c.x + radius_px) + 1):
			if Vector2(px + 0.5, py + 0.5).distance_to(c) <= radius_px:
				_put(px, py, col)


# A one-pixel ring of `radius_px` pixels.
func _ring(w: Vector2, radius_px: float, col: Color) -> void:
	var c := _to_px(w)
	for py: int in range(floori(c.y - radius_px) - 1, ceili(c.y + radius_px) + 2):
		for px: int in range(floori(c.x - radius_px) - 1, ceili(c.x + radius_px) + 2):
			if absf(Vector2(px + 0.5, py + 0.5).distance_to(c) - radius_px) <= 0.7:
				_put(px, py, col)


func _fill_rect(r: Rect2, col: Color) -> void:
	var a := _to_px(r.position)
	var b := _to_px(r.end)
	for py: int in range(floori(a.y), ceili(b.y)):
		for px: int in range(floori(a.x), ceili(b.x)):
			_put(px, py, col)


# A five-point star, drawn in pixels at the landmark.
func _star(w: Vector2, col: Color, grow: float = 1.0) -> void:
	var c := _to_px(w)
	var pts := PackedVector2Array()
	for i: int in range(10):
		var r := (3.6 if i % 2 == 0 else 1.6) * grow
		var a := -PI / 2.0 + TAU * float(i) / 10.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	var reach := 4.0 * grow
	for py: int in range(floori(c.y - reach), ceili(c.y + reach) + 1):
		for px: int in range(floori(c.x - reach), ceili(c.x + reach) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(px + 0.5, py + 0.5), pts):
				_put(px, py, col)
