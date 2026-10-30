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

const RESOLUTION := Config.TD_MINIMAP_RESOLUTION

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
# Round 19: the spirit beacon (Vector2.INF when there is none).
var beacon_pos := Vector2.INF
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
# Vector2 (world), "count": int, "radius": float (picture pixels)}. Recounted every MINIMAP_CLOUD_SECONDS (see tick).
var cloud_cells: Array[Dictionary] = []

# The look: the palette and the frame (see scripts/looks/minimap_look.gd). The picture itself is built here.
var look: MinimapLook
var _image: Image
var _texture: ImageTexture
var _ground: PaintedGround
var _timer: float = Config.TD_MINIMAP_REFRESH_SECONDS
# Round 20: the cloud's alpha for each picture pixel (RESOLUTION x RESOLUTION, row by row; 0 where there is none).
var _cloud_alpha := PackedFloat32Array()
var _cloud_age: float = 0.0
var _cloud_due: bool = true


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
	for i: int in range(blips.size() - 1, -1, -1):
		var left: float = blips[i]["left"] - delta
		blips[i]["left"] = left
		if left <= 0.0:
			blips.remove_at(i)
	_cloud_age += delta
	if _cloud_age >= Config.MINIMAP_CLOUD_SECONDS:
		_cloud_due = true
	_timer += delta
	if _timer < Config.TD_MINIMAP_REFRESH_SECONDS:
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
		seal_flags.append(border.is_sealed(j))
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
	var bp := border.beacon_pos()
	beacon_pos = Vector2.INF if bp == Vector3.INF else Vector2(bp.x, bp.z)
	landmark_pts = PackedVector2Array()
	for at: Vector3 in Config.LANDMARK_POSITIONS:
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
	if _cloud_due:
		refresh_clouds(people)
	_render()


# Round 20: bins the unrescued people into the coarse grid and paints a soft blob for each busy cell. Called by
# refresh_from when a recount is due (twice a second); tests call it directly.
func refresh_clouds(people: Array[Person]) -> void:
	_cloud_due = false
	_cloud_age = 0.0
	var n := Config.MINIMAP_CLOUD_CELLS
	var cell_m := float(Config.TD_PLAZA_SIZE) / float(n)
	var half := Config.TD_PLAZA_SIZE * 0.5
	var counts := PackedInt32Array()
	counts.resize(n * n)
	for p: Person in people:
		if p.is_rescued:
			continue
		var ix := clampi(floori((p.position.x + half) / cell_m), 0, n - 1)
		var iz := clampi(floori((p.position.z + half) / cell_m), 0, n - 1)
		counts[iz * n + ix] += 1
	cloud_cells.clear()
	for iz: int in range(n):
		for ix: int in range(n):
			var count := counts[iz * n + ix]
			if count < Config.MINIMAP_CLOUD_MIN_COUNT:
				continue
			var centre := Vector2(-half + (ix + 0.5) * cell_m, -half + (iz + 0.5) * cell_m)
			var radius := minf(
				Config.MINIMAP_CLOUD_BASE_RADIUS_PX + Config.MINIMAP_CLOUD_RADIUS_PER_PERSON_PX * sqrt(float(count)),
				Config.MINIMAP_CLOUD_MAX_RADIUS_PX
			)
			cloud_cells.append({"centre": centre, "count": count, "radius": radius})
	_paint_clouds()


# Round 20: the alpha of the people clouds at picture pixel (px, py), 0 to 1. Zero outside every blob.
func cloud_alpha_at(px: int, py: int) -> float:
	if _cloud_alpha.size() != RESOLUTION * RESOLUTION or px < 0 or py < 0 or px >= RESOLUTION or py >= RESOLUTION:
		return 0.0
	return _cloud_alpha[py * RESOLUTION + px]


# Round 20: fills the cloud alpha map. Each blob falls off smoothly from its centre to its edge (1 - d^2)^2, and
# overlapping blobs combine (1 - (1 - a)(1 - b)), so a patch reads as one soft cloud, never as dots.
func _paint_clouds() -> void:
	_cloud_alpha.resize(RESOLUTION * RESOLUTION)
	_cloud_alpha.fill(0.0)
	for cell: Dictionary in cloud_cells:
		var at: Vector2 = cell["centre"]
		var c := _to_px(at)
		var r: float = cell["radius"]
		var count: int = cell["count"]
		var peak := Config.MINIMAP_CLOUD_MAX_ALPHA * minf(1.0, float(count) / float(Config.MINIMAP_CLOUD_FULL_COUNT))
		for py: int in range(maxi(0, floori(c.y - r)), mini(RESOLUTION, ceili(c.y + r) + 1)):
			for px: int in range(maxi(0, floori(c.x - r)), mini(RESOLUTION, ceili(c.x + r) + 1)):
				var d := Vector2(px + 0.5, py + 0.5).distance_to(c) / r
				if d >= 1.0:
					continue
				var f := 1.0 - d * d
				var i := py * RESOLUTION + px
				_cloud_alpha[i] = 1.0 - (1.0 - _cloud_alpha[i]) * (1.0 - peak * f * f)


# Round 12b: a blip at a world point (x, z) for MINIMAP_BLIP_SECONDS, drawn as a ring (someone became dimmed).
func add_blip(world: Vector2) -> void:
	blips.append({"pos": world, "left": Config.MINIMAP_BLIP_SECONDS})


# ---- Drawing
# -------------------------------------------------------------------------------------------------------------


func _draw() -> void:
	look.draw_back(self)
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	look.draw_frame(self)


# Rebuilds the image from the data model: the ground inside the circle, then the buildings, the border, the people,
# the landmark, the player and the view.
func _render() -> void:
	if _image == null:
		return
	_image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var cloud := look.cloud_colour()
	var clouds_on := cloud.a > 0.0 and _cloud_alpha.size() == RESOLUTION * RESOLUTION
	for py: int in range(RESOLUTION):
		for px: int in range(RESOLUTION):
			if _in_circle(Vector2(px + 0.5, py + 0.5)):
				var w := _to_world(Vector2(px + 0.5, py + 0.5))
				var col := _ground_colour(w, px, py)
				# Round 20: the people clouds sit on the ground, under the buildings and every marker.
				if clouds_on and _cloud_alpha[py * RESOLUTION + px] > 0.0:
					col = col.lerp(cloud, _cloud_alpha[py * RESOLUTION + px] * cloud.a)
				_image.set_pixel(px, py, col)
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
	for m: Vector2 in member_pts:
		_marker(m, 1.6, look.member_colour(), "member")
	for d: Vector2 in dimmed_pts:
		_marker(d, 1.3, look.dimmed_colour(), "dimmed")
	for b: Dictionary in blips:
		var at: Vector2 = b["pos"]
		var left: float = b["left"]
		_ring(at, 2.0 + 3.0 * (1.0 - left / Config.MINIMAP_BLIP_SECONDS), Config.MINIMAP_BLIP_COLOUR)
	for gm: Dictionary in gap_markers:
		var u: float = gm["urgency"]
		var at: Vector2 = gm["pos"]
		_marker(at, 1.4 + 1.8 * u, look.line_colour(true).lerp(Color(1.0, 0.9, 0.82), u * 0.8), "gap")
		if u > 0.5:
			_ring(at, 3.4 + 2.0 * u, look.line_colour(true))
	for k: int in range(landmark_pts.size()):
		var held := k < held_landmarks.size() and held_landmarks[k]
		var star_halo := look.halo_colour("landmark")
		if star_halo.a > 0.0:
			_star(landmark_pts[k], star_halo, 1.4)
		_star(landmark_pts[k], look.landmark_state_colour(held))
		if held:
			_ring(landmark_pts[k], 5.6, look.landmark_colour())
	if beacon_pos != Vector2.INF:
		var beacon_halo := look.halo_colour("beacon")
		if beacon_halo.a > 0.0:
			_ring(beacon_pos, 4.3, beacon_halo)
		_ring(beacon_pos, 3.4, look.beacon_colour())
		_marker(beacon_pos, 1.4, look.beacon_colour(), "beacon")
	_marker(player_pos, 2.2, look.player_colour(), "player")
	for k: int in range(view_pts.size()):
		_line(view_pts[k], view_pts[(k + 1) % view_pts.size()], look.view_colour())
	_texture.update(_image)


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
