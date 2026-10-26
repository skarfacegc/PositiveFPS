class_name SpiritMeter
extends Control

# Round 13b: the spirit meter, bottom centre (SPIRIT_METER_WIDTH wide), drawn over the HUD's spirit bar. It shows
# spirit as a fill, a tick for what the joy burst costs (above the bar, a small burst glyph) and a tick for where dim
# ends (below the bar, a small moon), and a small arc beside it for the twirl cooldown. When spirit is gained (a
# rescue), spent (the burst) or lost (a grab) the meter flashes and a number floats up from it ("+20", "-30", "-25").
# Screen-space UI, so it shows in both looks.

enum Moment { GAIN, SPEND, LOSS }

const POPUP_FONT_SIZE := 26

var spirit: float = Config.SPIRIT_START
var is_dim: bool = false
# 0 while the twirl is cooling down, 1 when it is ready (the arc fills as the cooldown runs out).
var twirl_frac: float = 1.0
# The flash over the bar (0 to 1) and its colour, and the floating numbers: {"text", "colour", "left"}.
var flash: float = 0.0
var flash_colour := Color.WHITE
var popups: Array[Dictionary] = []
var _clock: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -Config.SPIRIT_METER_WIDTH * 0.5
	offset_right = Config.SPIRIT_METER_WIDTH * 0.5
	offset_top = -110.0
	offset_bottom = -110.0 + Config.SPIRIT_METER_HEIGHT


# Sets the numbers it draws and redraws. `twirl_cooldown` is the seconds left before the next twirl.
func set_values(new_spirit: float, dim: bool, twirl_cooldown: float) -> void:
	spirit = new_spirit
	is_dim = dim
	twirl_frac = 1.0 - clampf(twirl_cooldown / Config.TWIRL_COOLDOWN, 0.0, 1.0)
	queue_redraw()


# A spirit moment: flash the meter and float `amount` (positive or negative) up from it. `kind` is a Moment.
func moment(amount: float, kind: int) -> void:
	var colour := _moment_colour(kind)
	flash = 1.0
	flash_colour = colour
	var sign_text := "+" if amount > 0.0 else "−"
	popups.append(
		{"text": "%s%d" % [sign_text, roundi(absf(amount))], "colour": colour, "left": Config.SPIRIT_MOMENT_SECONDS}
	)
	if popups.size() > 4:
		popups.pop_front()


static func _moment_colour(kind: int) -> Color:
	match kind:
		Moment.GAIN:
			return Config.SPIRIT_GAIN_COLOUR
		Moment.SPEND:
			return Config.SPIRIT_SPEND_COLOUR
	return Config.SPIRIT_LOSS_COLOUR


# Advances the flash and the floating numbers.
func tick(delta: float) -> void:
	_clock += delta
	flash = maxf(0.0, flash - delta / 0.5)
	for i: int in range(popups.size() - 1, -1, -1):
		var left: float = popups[i]["left"] - delta
		popups[i]["left"] = left
		if left <= 0.0:
			popups.remove_at(i)
	queue_redraw()


# The x (in the meter's own pixels) of the tick for `value` spirit.
func tick_x(value: float) -> float:
	return size.x * clampf(value / Config.SPIRIT_MAX, 0.0, 1.0)


func burst_tick_x() -> float:
	return tick_x(Config.BURST_SPIRIT_COST)


func dim_tick_x() -> float:
	return tick_x(Config.DIM_EXIT_SPIRIT)


func _draw() -> void:
	var h := size.y
	var bar := Rect2(Vector2.ZERO, size)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(0.07, 0.06, 0.1, 0.92)
	back.set_corner_radius_all(int(h * 0.5))
	back.border_color = Color(0.93, 0.87, 0.72, 0.7)
	back.set_border_width_all(2)
	draw_style_box(back, bar.grow(2.0))
	var fill_w := size.x * clampf(spirit / Config.SPIRIT_MAX, 0.0, 1.0)
	var fill_col := Color(0.62, 0.62, 0.68) if is_dim else Color(1.0, 0.82, 0.36)
	if fill_w > 1.0:
		var fill := StyleBoxFlat.new()
		fill.bg_color = fill_col
		fill.set_corner_radius_all(int(h * 0.5))
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(fill_w, h), h)))
	if flash > 0.0:
		var f := flash_colour
		f.a = 0.55 * flash
		draw_rect(bar.grow(3.0 * flash), f)
	_draw_ticks(h)
	_draw_twirl(h)
	_draw_popups()


# The two ticks: the burst cost (a line and a small burst glyph above) and the dim exit (a line and a moon below).
func _draw_ticks(h: float) -> void:
	var bx := burst_tick_x()
	var can := not is_dim and spirit >= Config.BURST_SPIRIT_COST
	var burst_col := Color(1.0, 0.95, 0.75) if can else Color(0.85, 0.5, 0.45)
	draw_line(Vector2(bx, -5.0), Vector2(bx, h + 2.0), burst_col, 2.0)
	var gc := Vector2(bx, -14.0)
	for i: int in range(8):
		var a := TAU * float(i) / 8.0
		var r0 := 2.5
		var r1 := 7.0 if i % 2 == 0 else 4.5
		draw_line(gc + Vector2(cos(a), sin(a)) * r0, gc + Vector2(cos(a), sin(a)) * r1, burst_col, 1.8)
	var dx := dim_tick_x()
	var pulse := 0.5 + 0.5 * sin(_clock * TAU * 1.5)
	var dim_col := Color(0.72, 0.7, 0.85, 0.9)
	if is_dim:
		dim_col = Color(1.0, 0.95, 0.8, 0.6 + 0.4 * pulse)
	draw_line(Vector2(dx, -2.0), Vector2(dx, h + 5.0), dim_col, 2.0)
	var mc := Vector2(dx, h + 14.0)
	draw_circle(mc, 6.0, dim_col)
	draw_circle(mc + Vector2(2.6, -1.8), 5.2, Color(0.07, 0.06, 0.1, 1.0))


# The twirl cooldown: a ring beside the bar that fills as the twirl comes back, green and full when it is ready.
func _draw_twirl(h: float) -> void:
	var c := Vector2(size.x + 34.0, h * 0.5)
	var ready_now := twirl_frac >= 1.0
	draw_arc(c, 13.0, 0.0, TAU, 28, Color(0.3, 0.3, 0.34, 0.8), 3.0, true)
	var col := Color(0.6, 1.0, 0.65) if ready_now else Color(0.8, 0.8, 0.85)
	if twirl_frac > 0.0:
		draw_arc(c, 13.0, -PI * 0.5, -PI * 0.5 + TAU * twirl_frac, 28, col, 3.5, true)
	if ready_now:
		draw_circle(c, 4.0, col)


func _draw_popups() -> void:
	var font := ThemeDB.fallback_font
	for p: Dictionary in popups:
		var left: float = p["left"]
		var t := 1.0 - left / Config.SPIRIT_MOMENT_SECONDS
		var shown_text: String = p["text"]
		var col: Color = p["colour"]
		col.a = clampf(left / 0.4, 0.0, 1.0)
		var at := Vector2(size.x * 0.5 - 20.0, -26.0 - 34.0 * t)
		draw_string_outline(
			font, at, shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POPUP_FONT_SIZE, 6, Color(0, 0, 0, col.a)
		)
		draw_string(font, at, shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, POPUP_FONT_SIZE, col)
