class_name NightCycle
extends RefCounted

# Dusk to dawn. The level lasts NIGHT_LENGTH seconds: dusk (warm light, grey normal) to midnight (dim blue, grey
# strongest) to dawn (soft light again). The level ends at dawn. Grey strength multiplies gloom growth, spread
# and drain.

# Light keyframes at dusk, midnight and dawn (sun colour, sun energy, ambient colour, ambient energy).
const DUSK_SUN := Color(1.0, 0.72, 0.45)
const MIDNIGHT_SUN := Color(0.35, 0.42, 0.7)
const DAWN_SUN := Color(1.0, 0.86, 0.74)
const DUSK_AMBIENT := Color(0.7, 0.62, 0.55)
const MIDNIGHT_AMBIENT := Color(0.28, 0.32, 0.45)
const DAWN_AMBIENT := Color(0.72, 0.7, 0.68)
const DUSK_ENERGY := 1.0
const MIDNIGHT_ENERGY := 0.35
const DAWN_ENERGY := 0.85

# Seconds since dusk.
var elapsed: float = 0.0
# Walls and gates: Pressure (#14). How much the surge cools the light now, 0 to 1 (set by GloomTide: it rises through
# the warning, holds through the surge and warms again over the aftermath).
var chill: float = 0.0
# How much longer than usual the gap between two dimmed arrivals is now (1 normally; the aftermath eases it).
var arrival_ease: float = 1.0


func update(delta: float) -> void:
	elapsed = minf(elapsed + delta, NightConfig.NIGHT_LENGTH)


# 0 at dusk, 1 at dawn.
func progress() -> float:
	return elapsed / NightConfig.NIGHT_LENGTH


# Round 24: 0 until the last FIRST_LIGHT_SECONDS of the night, then rising to 1 at dawn (the dawn front's progress).
func first_light_progress() -> float:
	var start := NightConfig.NIGHT_LENGTH - NightConfig.FIRST_LIGHT_SECONDS
	return clampf((elapsed - start) / NightConfig.FIRST_LIGHT_SECONDS, 0.0, 1.0)


# True from the start of the last FIRST_LIGHT_SECONDS.
func first_light_active() -> bool:
	return elapsed >= NightConfig.NIGHT_LENGTH - NightConfig.FIRST_LIGHT_SECONDS


func is_over() -> bool:
	return elapsed >= NightConfig.NIGHT_LENGTH


# How strong the grey is right now. Round 10: calm (NIGHT_CALM_STRENGTH) for the first NIGHT_CALM_FRACTION of the night,
# then it eases (smoothstep) into the curve 1 + NIGHT_PEAK_EXTRA * sin(PI * progress), which is 1 at dawn and peaks at
# midnight.
func strength() -> float:
	var p := progress()
	if p < NightConfig.NIGHT_CALM_FRACTION:
		return NightConfig.NIGHT_CALM_STRENGTH
	# Round 23: the part above 1 fades out from NIGHT_EASE_START, so the easing phase is easing (1.36 at 75%, was 1.53).
	var extra := NightConfig.NIGHT_PEAK_EXTRA * sin(PI * p) * (1.0 - smoothstep(NightConfig.NIGHT_EASE_START, 1.0, p))
	var curve := 1.0 + extra
	return lerpf(NightConfig.NIGHT_CALM_STRENGTH, curve, smoothstep(NightConfig.NIGHT_CALM_FRACTION, 0.5, p))


# Round 23: the seconds that must pass between two people sinking to dimmed at night progress `p` (see
# TopDownMain._try_dim_sink). Short in the rising phase, DIM_ARRIVAL_MIN_GAP from midnight, long in the easing phase.
static func dim_gap_at(p: float) -> float:
	var base := NightConfig.DIM_ARRIVAL_MIN_GAP
	if p < 0.5:
		return lerpf(NightConfig.DIM_GAP_RISING, base, smoothstep(NightConfig.NIGHT_CALM_FRACTION, 0.5, p))
	return lerpf(base, NightConfig.DIM_GAP_EASE_END, smoothstep(NightConfig.DIM_GAP_EASE_START, 1.0, p))


func sun_color() -> Color:
	return _key(DUSK_SUN, MIDNIGHT_SUN, DAWN_SUN).lerp(NightConfig.SURGE_CHILL_COLOUR, chill * NightConfig.SURGE_CHILL)


func sun_energy() -> float:
	return _key_float(DUSK_ENERGY, MIDNIGHT_ENERGY, DAWN_ENERGY)


func ambient_color() -> Color:
	return _key(DUSK_AMBIENT, MIDNIGHT_AMBIENT, DAWN_AMBIENT).lerp(
		NightConfig.SURGE_CHILL_COLOUR, chill * NightConfig.SURGE_CHILL * 0.6
	)


# Blends the three keyframes for the current progress (dusk to midnight, then midnight to dawn).
func _key(dusk: Color, midnight: Color, dawn: Color) -> Color:
	var p := progress()
	if p < 0.5:
		return dusk.lerp(midnight, p / 0.5)
	return midnight.lerp(dawn, (p - 0.5) / 0.5)


func _key_float(dusk: float, midnight: float, dawn: float) -> float:
	var p := progress()
	if p < 0.5:
		return lerpf(dusk, midnight, p / 0.5)
	return lerpf(midnight, dawn, (p - 0.5) / 0.5)
