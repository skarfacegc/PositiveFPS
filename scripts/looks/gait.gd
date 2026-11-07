class_name Gait
extends RefCounted

# Graphics checkpoint 4: the walk. One Gait follows one walker (a person or the player) and turns how it actually moved
# into a pose that a look applies to its body. Nothing here reads the rules except the position and facing it is given.
#
# - The step cycle is tied to ground distance, not to time: the phase advances by (distance moved / stride), so a foot
#   that is planted stays put on the ground. The legs swing along a stance line (the foot slides backward at a constant
#   rate relative to the hip, exactly the walker's speed) and then a quicker swing back, with the swing leg lifted.
# - The stride follows the speed (shorter, quicker steps when slow; longer when fast), so the swing angle is worked
#   out from the stride and the leg length. A run has a shorter stance, a bigger hop, more lean and bent-elbow swing.
# - The speed is smoothed, and everything fades with `move`, so a walker eases into the gait and settles out of it.
# - Standing still is not frozen: a slow weight shift from foot to foot.
# - The walker's heading is compared with its facing, so strafing and backing away swing the legs sideways or backwards
#   instead of sliding.
# - Each walker has its own cadence, phase, bounce, sway and arm swing, taken from a hash of its look seed (no random
#   numbers are drawn), so a crowd does not step in time and a run repeats exactly.
#
# All lengths in the pose are in the body's own units (the look scales them); the speed and distance are world metres.

const MAX_SPEED := 30.0  # faster than this in one step is a teleport, not a walk
const SPEED_TAU := 0.14  # seconds the speed takes to catch up
const MOVE_FROM := 0.15
const MOVE_FULL := 0.8
const MOVE_RATE := 5.0  # how fast `move` follows its target (per second)
const MAX_CYCLES := 3.4  # the step cycle never turns faster than this per second
const MAX_SWING := 1.0  # radians, the most a leg swings either way
const REST_STEP := 0.1  # seconds between updates of a walker standing still

# What kind of walker this is (set once by the look).
var leg_len: float = 0.62  # model units
var unit: float = 1.5  # world metres in one model unit
var run_from: float = 3.0  # m/s where a run begins and where it is complete
var run_full: float = 4.2
var heavy: float = 0.0  # 0 light, 1 a heavy shuffle (dimmed people)
var legs: bool = true  # false for a body with no legs or arms to pose (the placeholder capsule): they are skipped
# Checkpoint 6: 1 for the player, whose run is a jog (Config.JOG_*: more cadence, wider swing, more lean and bounce).
# 0 (people) keeps the walk and run they had.
var jog: float = 0.0

# This walker's own variety (from the look seed, see configure).
var cadence_var: float = 1.0
var phase_off: float = 0.0
var bounce_var: float = 1.0
var sway_var: float = 1.0
var arm_var: float = 1.0

# State.
var phase: float = 0.0
var speed: float = 0.0
var move: float = 0.0
var run: float = 0.0
var clock: float = 0.0
var stride: float = 1.0
var stance: float = 0.6
var rel: float = 0.0  # angle of the heading from straight ahead (0 ahead, PI/2 to the right, PI backward)

# The pose (angles in radians, lengths in model units). Index 0 and 1 are the two legs; leg 1 is the model's +x side.
var swing: Array[float] = [0.0, 0.0]  # leg swing, forward positive
var lift: Array[float] = [0.0, 0.0]  # how much the leg is drawn up while it swings forward, 0..1
var arm: Array[float] = [0.0, 0.0]  # arm swing, forward positive
var bob: float = 0.0
var sway: float = 0.0
var roll: float = 0.0
var pitch: float = 0.0  # forward positive
var yaw: float = 0.0
var dir_fwd: float = 1.0
var dir_side: float = 0.0

var _vel := Vector3.ZERO
var _last := Vector3.INF
var _rest: float = 0.0


# Picks this walker's variety from `seed_id` and sets what kind of walker it is.
func configure(seed_id: int, leg: float, world_per_unit: float, run_start: float, run_end: float) -> void:
	leg_len = leg
	unit = world_per_unit
	run_from = run_start
	run_full = run_end
	cadence_var = 0.9 + 0.2 * hash01(seed_id, 1)
	phase_off = hash01(seed_id, 2)
	bounce_var = 0.75 + 0.5 * hash01(seed_id, 3)
	sway_var = 0.75 + 0.5 * hash01(seed_id, 4)
	arm_var = 0.8 + 0.4 * hash01(seed_id, 5)


# A repeatable number from 0 to 1 for (seed_id, k): the same every run.
static func hash01(seed_id: int, k: int) -> float:
	return fposmod(sin(float(seed_id) * 12.9898 + float(k) * 78.233) * 43758.5453, 1.0)


# The leg's swing at step time `t` (0 to 1) as -1..1, forward positive: the stance line down from +1 to -1 over the
# `stance` share of the cycle (the foot slides back at a steady rate), then a smooth swing back up.
static func wave(t: float, stance_share: float) -> float:
	t = fposmod(t, 1.0)
	if t < stance_share:
		return 1.0 - 2.0 * t / stance_share
	var s := (t - stance_share) / (1.0 - stance_share)
	return -cos(PI * s)


# How far through its forward swing the leg is at step time `t`, as a 0..1..0 hump (0 while it is on the ground).
static func lift_curve(t: float, stance_share: float) -> float:
	t = fposmod(t, 1.0)
	if t < stance_share:
		return 0.0
	return sin(PI * (t - stance_share) / (1.0 - stance_share))


# Follows `node` (a person or the player) over `delta` seconds. Reads its facing only when it is not standing still,
# since copying a basis for every standing person every frame is the dearest part of a standing walker.
func follow(node: Node3D, delta: float) -> bool:
	var pos := node.position
	if _last != Vector3.INF and pos.x == _last.x and pos.z == _last.z and speed < 0.01 and move == 0.0:
		return advance(pos, delta, Basis.IDENTITY)
	return advance(pos, delta, node.basis)


# Follows the walker to `pos` (world) over `delta` seconds; `basis` is its facing. Updates the state and the pose.
# Returns false when the pose did not change (a walker standing still only shifts its weight ten times a second, which
# keeps 60 standing people cheap), so the look can skip writing it.
func advance(pos: Vector3, delta: float, basis: Basis) -> bool:
	if delta <= 0.0:
		return false
	if _last != Vector3.INF and pos.x == _last.x and pos.z == _last.z and speed < 0.01 and move == 0.0:
		speed = 0.0
		_vel = Vector3.ZERO
		_rest += delta
		if _rest < REST_STEP:
			return false
		clock += _rest
		_rest = 0.0
		_idle()
		return true
	clock += delta
	var vx := 0.0
	var vz := 0.0
	var step := 0.0
	if _last != Vector3.INF:
		var dx := pos.x - _last.x
		var dz := pos.z - _last.z
		step = sqrt(dx * dx + dz * dz)
		if step <= MAX_SPEED * delta:
			vx = dx / delta
			vz = dz / delta
		else:
			step = 0.0
	_last = pos
	var k := 1.0 - exp(-delta / SPEED_TAU)
	_vel.x = lerpf(_vel.x, vx, k)
	_vel.z = lerpf(_vel.z, vz, k)
	speed = sqrt(_vel.x * _vel.x + _vel.z * _vel.z)
	if speed > 0.15:
		# The heading in the walker's own frame (the basis is a rotation, so its transpose is its inverse).
		var local_x := basis.x.x * _vel.x + basis.x.z * _vel.z
		var local_z := basis.z.x * _vel.x + basis.z.z * _vel.z
		rel = atan2(local_x, -local_z)
	dir_fwd = cos(rel)
	dir_side = sin(rel)
	var target := smoothstep(MOVE_FROM, MOVE_FULL, speed)
	move = move_toward(move, target, MOVE_RATE * delta)
	run = smoothstep(run_from, run_full, speed)
	_solve(step, delta)
	_pose()
	return true


# The stride for the current speed, and the cycle advanced by the distance walked.
func _solve(step: float, delta: float) -> void:
	var leg_world := leg_len * unit
	var vn := speed * 0.9 / leg_world
	var cycles := clampf(0.55 + 0.38 * vn - 0.012 * vn * vn, 0.5, 2.3 + 0.9 * run)
	cycles *= (1.0 - 0.18 * heavy) / cadence_var
	cycles *= lerpf(1.0, Config.JOG_CADENCE, run * jog)
	stride = maxf(speed / cycles, 0.05)
	stance = lerpf(0.62, 0.42, run) + 0.06 * heavy
	var cap := lerpf(MAX_CYCLES, Config.JOG_CYCLE_CAP, jog)
	phase = fposmod(phase + minf(step / stride, cap * delta), 1.0)


func _pose() -> void:
	var leg_world := leg_len * unit
	var vn := speed * 0.9 / leg_world
	# How far the legs swing: the foot's whole stance line (2 * leg * sin(angle)) is the stride's stance share. A
	# bounding run covers extra ground in the air, so the same angle goes further.
	var reach := 1.0 + 0.45 * smoothstep(3.0, 8.0, vn) + 0.5 * run
	var sin_a := clampf(stride * stance / (2.0 * leg_world * reach), 0.0, sin(MAX_SWING))
	# A jog swings the legs wider than the walk (Config.JOG_SWING_ANGLE at a full run, for the player only).
	var swing_angle := lerpf(asin(sin_a), Config.JOG_SWING_ANGLE, run * jog)
	var amp := swing_angle * move * (1.0 - 0.4 * heavy)
	var lift_amp := lerpf(0.16, 0.3, run) * move * (1.0 - 0.5 * heavy)
	var t0 := phase + phase_off
	if legs:
		for i: int in range(2):
			var t := t0 + 0.5 * float(i)
			swing[i] = amp * wave(t, stance)
			lift[i] = lift_amp * lift_curve(t, stance)
			arm[i] = -amp * (0.75 + 0.45 * run) * (1.0 - 0.5 * heavy) * arm_var * cos(TAU * t)
	# The body: lowest as a foot lands, highest at mid-stance (and a spring in the air for a run); shifting over the
	# standing leg; the hips and shoulders turning against each other; leaning into the way it is going.
	var mid := cos(4.0 * PI * (t0 - 0.5 * stance))
	var dip := leg_len * (1.0 - cos(amp)) * 0.85
	var spring := leg_len * (0.03 + 0.09 * run + Config.JOG_BOB * run * jog) * move * bounce_var
	bob = -dip * 0.5 * (1.0 - mid) + spring * 0.5 * (1.0 + mid)
	var over := cos(TAU * (t0 + 0.5 - 0.5 * stance))
	var s_amp := (1.0 + 0.5 * heavy) * sway_var * move
	sway = 0.05 * leg_len * s_amp * over
	roll = 0.045 * s_amp * over
	yaw = 0.07 * (1.0 + 0.5 * run) * move * dir_fwd * (swing[1] - swing[0]) * 0.5 / maxf(amp, 0.001)
	pitch = (0.03 + 0.07 * run + 0.06 * heavy + Config.JOG_LEAN * run * jog) * move * dir_fwd
	pitch += 0.012 * move * cos(4.0 * PI * t0)
	roll += dir_side * (0.03 + 0.06 * run) * move
	# Standing: a slow shift of weight from foot to foot.
	var rest := 1.0 - move
	var idle := sin(clock * 0.7 + phase_off * TAU)
	sway += 0.03 * leg_len * sway_var * rest * idle
	roll += 0.022 * sway_var * rest * idle


# The pose of a walker standing still: only the weight shift.
func _idle() -> void:
	for i: int in range(2):
		swing[i] = 0.0
		lift[i] = 0.0
		arm[i] = 0.0
	bob = 0.0
	yaw = 0.0
	pitch = 0.0
	dir_fwd = cos(rel)
	dir_side = sin(rel)
	var idle := sin(clock * 0.7 + phase_off * TAU)
	sway = 0.03 * leg_len * sway_var * idle
	roll = 0.022 * sway_var * idle
