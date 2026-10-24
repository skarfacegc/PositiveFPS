class_name NightCycle
extends RefCounted

# Dusk to dawn. The level lasts Config.NIGHT_LENGTH seconds: dusk (warm light, grey normal) to midnight (dim blue, grey
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


func update(delta: float) -> void:
	elapsed = minf(elapsed + delta, Config.NIGHT_LENGTH)


# 0 at dusk, 1 at dawn.
func progress() -> float:
	return elapsed / Config.NIGHT_LENGTH


func is_over() -> bool:
	return elapsed >= Config.NIGHT_LENGTH


# How strong the grey is right now. Round 10: calm (NIGHT_CALM_STRENGTH) for the first NIGHT_CALM_FRACTION of the night,
# then it eases (smoothstep) into the curve 1 + NIGHT_PEAK_EXTRA * sin(PI * progress), which is 1 at dawn and peaks at
# midnight.
func strength() -> float:
	var p := progress()
	if p < Config.NIGHT_CALM_FRACTION:
		return Config.NIGHT_CALM_STRENGTH
	var curve := 1.0 + Config.NIGHT_PEAK_EXTRA * sin(PI * p)
	return lerpf(Config.NIGHT_CALM_STRENGTH, curve, smoothstep(Config.NIGHT_CALM_FRACTION, 0.5, p))


func sun_color() -> Color:
	return _key(DUSK_SUN, MIDNIGHT_SUN, DAWN_SUN)


func sun_energy() -> float:
	return _key_float(DUSK_ENERGY, MIDNIGHT_ENERGY, DAWN_ENERGY)


func ambient_color() -> Color:
	return _key(DUSK_AMBIENT, MIDNIGHT_AMBIENT, DAWN_AMBIENT)


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
