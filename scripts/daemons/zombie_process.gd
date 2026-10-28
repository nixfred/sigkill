extends DaemonArt
## The zombie process (A2b, the "zombie" and "<defunct>" dummies: a defunct process is a zombie):
## dead, never reaped, and still walking. A tall hunched humanoid-ish wireframe, half derezzed: a
## solid obsidian pelvis, the rest crystal bones drawn as glowing amber wire, a ribcage round an
## amber ember that gutters, two broken shards jutting up off its back, arms hanging to its knees
## ending in claws, a faceless head hanging forward, sometimes solid, sometimes wire.
##
## It limps in a slow loop round its spot: a lurch on its good leg, then the bad one dragged along
## the ground, the pelvis dropping and the body leaning on it, the arms swinging out of step. It
## twitches: a head snapping round, an arm jerking up, the whole body glitching sideways for a
## moment. Its segments flicker in and out (the frailer ones, the left forearm worst, are missing
## more often than not), voxels drift up off it and fade, and three ghost copies trail behind it,
## each the same body some frames late (the pose of a moment ago, set back along its way), drawn as
## wire in the split's cyan and red, flickering. All of it is a function of its clock, so a ghost is
## its body at an earlier time and the same zombie moves the same way on every run. Its head stays
## inside the hit volume's head zone (it hunches; the shards on its back stand over it). Visual
## only: it never leaves its spot.
##
## Fighting back (C27b), its brain drives it: it shambles after its prey (its loop closes in to
## the daemon's own place and it faces the way the daemon goes, limping on; the ghosts trail
## behind along its way), and its tell is the right claw raised at its prey with the ember pulled
## out of its ribs into the claw, swelling and burning brighter; the strike throws it as an amber
## bolt (the brain's, scripts/fight/glitch_bolt.gd) and the arm drops back.

## Its bones, in order.
enum Bone { PELVIS, LUMBAR, CHEST, PLATE, NECK, HEAD, CLAV_L, CLAV_R, UPPER_L, UPPER_R, FORE_L, FORE_R, CLAW_L1, CLAW_L2, CLAW_R1, CLAW_R2, THIGH_L, THIGH_R, SHIN_L, SHIN_R, FOOT_L, FOOT_R, SPIKE_L, SPIKE_R }
const BONES := 24
## The bones drawn as gems (the rest are crystal shards).
const GEMS := [Bone.PELVIS, Bone.PLATE, Bone.HEAD]
## How often each bone is missing, from 0 (never) to 1 (more often than not), flickering in and out
## a few times a second.
const FRAILTY := [0.0, 0.05, 0.05, 0.15, 0.1, 0.12, 0.15, 0.15, 0.2, 0.2, 0.85, 0.3, 0.85, 0.85, 0.35, 0.35, 0.15, 0.15, 0.3, 0.3, 0.3, 0.3, 0.45, 0.45]
## Ticks a second the flicker rolls on.
const FLICKER_HZ := 6.0
## The limp: strides a second, strides round its loop, the loop's half-widths (x, z) in metres, how
## far behind the loop the pelvis walks (so the hunched head, ahead of it, stays over the hit
## volume), the pelvis's height above the ground.
const STRIDE_HZ := 0.6
const STRIDES_PER_LOOP := 6.0
const PATH := Vector2(0.22, 0.16)
const HUNCH_BACK := 0.26
const HIP_H := 0.9
## Limb lengths, in metres.
const THIGH := 0.48
const SHIN := 0.48
const UPPER := 0.56
const FORE := 0.52
## The ghosts: how many, how far behind in time (seconds) and how far set back along its way.
const GHOSTS := 3
const LAG_S := 0.3
const GHOST_BACK := 0.42
## The ribcage's ribs a side, and the voxels it sheds: how many, and how long each lives.
const RIBS := 3
const BITS := 10
const BIT_S := 1.7
## Twitches: about one every TWITCH_EVERY seconds.
const TWITCH_EVERY := 1.2

## Part ids: the body's bones, then each ghost's, layer by layer.
var _bones := PackedInt32Array()
var _ribs := PackedInt32Array()
var _ember: int
var _joints := PackedInt32Array()
var _bits := PackedInt32Array()
var _p := PackedFloat32Array()
## The gait at the time last asked for: the stride's phase, the lurch and the drag (0 to 1).
var _phase := 0.0
var _lurch := 0.0
var _drag := 0.0
## Each layer's root as last posed (the body's, then each ghost's), for the checks.
var _roots := PackedVector3Array()
## The body's elbows and its head's centre as last posed (drawn or flickered out).
var _elbows := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _head := Vector3.ZERO
## The right claw's wrist as last posed (art space): where its bolt comes from.
var _wrist := Vector3(0.3, 0.3, -0.5)


func _build() -> void:
	ai_kind = "zombie"
	core_color = Palette.HOSTILE_AMBER
	edge_color = Palette.HOSTILE_AMBER
	gutter = 1.0
	glyph_count = 7
	glyph_radius = 1.05
	glyph_low = -0.6
	glyph_high = 1.2
	glyph_size = 0.15
	glyph_turns = -0.02
	reach = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 3.4, 4.0))
	tag_height = 2.75
	budget_triangles = 3600
	budget_draw_calls = 10
	for i in 4:
		_p.append(TAU * dice(i, 1))
	for layer in GHOSTS + 1:
		for b in BONES:
			var gem := GEMS.has(b)
			var wire := 0.0 if (b == Bone.PELVIS and layer == 0) else 1.0
			_bones.append(part(Shape.GEM if gem else Shape.SHARD, Look.SHELL, wire, layer / 4.0))
		_roots.append(Vector3.ZERO)
	for i in RIBS * 2:
		_ribs.append(part(Shape.SHARD, Look.SHELL, 1.0))
	_ember = part(Shape.GEM, Look.CORE)
	for i in 4:
		_joints.append(part(Shape.GEM, Look.CORE))
	for i in BITS:
		_bits.append(part(Shape.CUBE, Look.CORE))


func _pose(t: float, _delta: float) -> void:
	var now_yaw := _yaw_at(_progress(t))
	var back := Basis(Vector3.UP, now_yaw) * Vector3.BACK
	for layer in GHOSTS + 1:
		var lag := LAG_S * layer
		var shift := back * (GHOST_BACK * layer) + Basis(Vector3.UP, now_yaw) * Vector3(0.06 * layer * sin(9.0 * t + layer), 0.0, 0.0)
		var off := layer > 0 and dice(200 + layer, int(floor(t * 10.0))) < 0.18
		_skeleton(t - lag, layer, shift, off)
	_pose_bits(t)


## The body (layer 0) or ghost `layer` at time `t`, set off by `shift`; `off` hides the whole
## layer (a ghost dropping a frame).
func _skeleton(t: float, layer: int, shift: Vector3, off: bool) -> void:
	var first := layer * BONES
	if off:
		for b in BONES:
			conceal(_bones[first + b])
		return
	var p := _progress(t)
	var f := _phase
	var lurch := _lurch
	var drag := _drag
	var n := floorf(STRIDE_HZ * t + 0.06 * sin(TAU * 0.17 * t + _p[0]))
	# Twitches: which kind, and how hard now.
	var tw := int(floor(t / TWITCH_EVERY))
	var tau := t - tw * TWITCH_EVERY - 0.5 * dice(tw, 10)
	var kind := int(dice(tw, 11) * 4.0)
	var amp := 0.0
	if tau >= 0.0:
		amp = tau / 0.04 if tau < 0.04 else exp(-(tau - 0.04) * 10.0)
	var sign := 1.0 if dice(tw, 12) < 0.5 else -1.0
	var root := _root_at(p)
	var yaw := _yaw_at(p) + (0.25 * amp * sign if kind == 3 else 0.0)
	var turn := Basis(Vector3.UP, yaw)
	var body := turn * Basis(Vector3.BACK, 0.16 * drag)
	var jump := turn * Vector3(0.14 * sign, 0.0, 0.05) * (amp if kind == 3 and tau < 0.1 else 0.0)
	var pelvis := root + Vector3(0.0, HIP_H + 0.05 * lurch - 0.1 * drag, 0.0) + shift + jump
	if layer == 0:
		pelvis += recoil()
	_roots[layer] = pelvis
	var breath := sin(TAU * 0.4 * t + _p[1])
	# The spine, hunched forward, bent toward the bad side as it drags.
	var bend := 0.12 * sin(TAU * f)
	var s0 := pelvis + body * Vector3(0.0, 0.07, 0.0)
	var s1 := s0 + body * _lean(0.25 + 0.1 * drag, bend) * 0.3
	var s2 := s1 + body * _lean(0.62 + 0.12 * drag + 0.03 * breath, bend) * 0.42
	var head_side := 0.9 * amp * sign if kind == 0 else 0.0
	var s3 := s2 + body * _lean(1.0, bend) * 0.17
	var head_way := body * _lean(1.75, head_side + bend)
	var head_at := s3 + head_way * 0.15
	var up := body * Vector3.UP
	var ahead := body * Vector3.FORWARD
	orient(_bones[first + Bone.PELVIS], pelvis, up, 0.18, 0.34, 0.22, ahead)
	bone(_bones[first + Bone.LUMBAR], s0, s1, 0.09)
	bone(_bones[first + Bone.CHEST], s1, s2, 0.12)
	var plate_at := (s1 + s2) * 0.5 + ahead * 0.07
	orient(_bones[first + Bone.PLATE], plate_at, s2 - s1, 0.44 * (1.0 + 0.04 * breath), 0.38, 0.24, ahead)
	bone(_bones[first + Bone.NECK], s2, s3, 0.07)
	orient(_bones[first + Bone.HEAD], head_at, head_way, 0.3, 0.22, 0.24, ahead)
	if layer == 0:
		_head = head_at
	# The shoulders, hunched up round the head, and the broken shards on its back over them.
	for side in 2:
		var x := -1.0 if side == 0 else 1.0
		var shoulder := s2 + body * Vector3(0.3 * x, 0.12, 0.05)
		bone(_bones[first + Bone.CLAV_L + side], s2, shoulder, 0.06)
		bone(_bones[first + Bone.SPIKE_L + side], s2 + body * Vector3(0.12 * x, 0.02, 0.12), s2 + body * Vector3(0.34 * x, 0.86, 0.46), 0.09)
		# The arms hang to the knees and swing out of step; the bad (left) one hangs limp and out;
		# a twitch jerks one up.
		var swing := 0.15 * sin(TAU * f + PI) if side == 0 else 0.35 * sin(TAU * f + 0.5)
		var hang := Vector3((0.45 if side == 0 else 0.3) * x, -1.0, -0.15 + swing).normalized()
		var jerk := amp if (kind == 1 and side == 0) or (kind == 2 and side == 1) else 0.0
		var upper := hang.lerp(Vector3(1.0 * x, 0.5, -0.6).normalized(), jerk).normalized()
		var fore := (upper + Vector3(0.0, 0.3, -0.55)).normalized()
		# The tell (C27b): the right claw raised at its prey, thrown forward in the strike.
		var raise := _raise() if side == 1 else 0.0
		if raise > 0.0:
			upper = upper.lerp(Vector3(0.3, 0.45, -1.0).normalized(), raise).normalized()
			fore = fore.lerp(Vector3(0.05, 0.25, -1.0).normalized(), raise).normalized()
		var elbow := shoulder + body * upper * UPPER
		var wrist := elbow + body * fore * FORE
		if side == 1 and layer == 0:
			_wrist = wrist
		bone(_bones[first + Bone.UPPER_L + side], shoulder, elbow, 0.075)
		bone(_bones[first + Bone.FORE_L + side], elbow, wrist, 0.06)
		for c in 2:
			var claw := (fore + Vector3((0.25 if c == 0 else -0.1) * x, -0.15, -0.1)).normalized()
			bone(_bones[first + Bone.CLAW_L1 + side * 2 + c], wrist, wrist + body * claw * 0.25, 0.035)
		_elbows[side] = elbow
	# The legs: the good (right) foot lifts and swings in its lurch, the bad (left) one drags along
	# the ground; knees by two-bone IK, the bad one knocked in.
	for side in 2:
		var x := -1.0 if side == 0 else 1.0
		var hip := pelvis + body * Vector3(0.13 * x, 0.0, 0.0)
		var foot := _left_foot(n, f) if side == 0 else _right_foot(n, f)
		foot += shift + jump
		var ankle := foot + Vector3(0.0, 0.08, 0.0)
		var reached := hip + (ankle - hip).limit_length(THIGH + SHIN - 0.002)
		var pole := ahead + body * Vector3(0.3 if side == 0 else 0.1, 0.0, 0.0)
		var knee := _knee_at(hip, reached, pole)
		bone(_bones[first + Bone.THIGH_L + side], hip, knee, 0.09)
		bone(_bones[first + Bone.SHIN_L + side], knee, reached, 0.07)
		var toe := reached + (ahead * 0.06 + Vector3(0.0, -0.08, 0.0) + turn * Vector3(0.05 * x, 0.0, 0.1) if side == 0 and drag > 0.0 else ahead * 0.2 + Vector3(0.0, -0.07, 0.0))
		bone(_bones[first + Bone.FOOT_L + side], reached, toe, 0.06)
		if layer == 0:
			orient(_joints[side], knee, knee - hip, 0.08, 0.06)
			orient(_joints[2 + side], _elbows[side], up, 0.07, 0.06)
	# The flicker: frail bones drop out and come back, more so in a glitching twitch; the head is
	# solid one moment and wire the next.
	var tick := int(floor(t * FLICKER_HZ))
	for b in BONES:
		var id := _bones[first + b]
		var frail: float = FRAILTY[b]
		if kind == 3 and tau >= 0.0 and tau < 0.12:
			frail = minf(frail * 3.0 + 0.2, 0.9)
		if dice(b + 40 * layer, tick + b * 3) < frail * 0.6:
			conceal(id)
		elif layer == 0 and b == Bone.HEAD:
			present(id, 1.0, 1.0 if dice(99, int(floor(t * 4.0))) < 0.5 else 0.0)
	if layer > 0:
		return
	for side in 2:
		var x := -1.0 if side == 0 else 1.0
		for k in RIBS:
			var base := s1.lerp(s2, 0.3 + 0.25 * k)
			bone(_ribs[side * RIBS + k], base, base + body * Vector3(0.22 * x, -0.1 + 0.03 * k, -0.16), 0.035)
	# The ember, pulled out into the raised claw and swelling in the tell (C27b).
	var charge := _charge()
	orient(_ember, plate_at.lerp(_wrist + ahead * 0.08, charge), s2 - s1, 0.2 * (1.0 + 0.9 * charge), 0.14 * (1.0 + 0.9 * charge))
	brighten(_ember, 1.1 + 0.3 * breath + 2.2 * charge)


## The voxels it sheds: each born at a spot on its body as it stood then, rising, turning and
## fading over BIT_S, then born again elsewhere.
func _pose_bits(t: float) -> void:
	for i in BITS:
		var cycle := t / BIT_S + i * 0.1
		var n := floorf(cycle)
		var u := cycle - n
		var born := (n - i * 0.1) * BIT_S
		var p := _progress(born)
		var spot := Vector3((dice(i, int(n)) - 0.5) * 0.5, 0.4 + dice(i + 20, int(n)) * 1.3, (dice(i + 40, int(n)) - 0.5) * 0.35)
		var at := _root_at(p) + Basis(Vector3.UP, _yaw_at(p)) * spot + Vector3(0.1 * sin(3.0 * u + i), 0.6 * u, 0.1 * cos(2.0 * u + i))
		var size := 0.075 * (1.0 - 0.7 * u)
		orient(_bits[i], at, Vector3(sin(i + u * 5.0), 1.0, cos(i * 2.0 + u * 4.0)), size, size)
		present(_bits[i], 1.0 - u * u)


## How far the right claw is raised now, from the brain's act (C27b): up through the tell, held in
## the strike, down in the recovery.
func _raise() -> float:
	match act:
		Act.TELL:
			return smoothstep(0.0, 0.45, act_u)
		Act.STRIKE:
			return 1.0
		Act.RECOVER:
			return 1.0 - smoothstep(0.0, 1.0, act_u)
	return 0.0


## How far the ember is out in the claw: through the tell; gone with the bolt in the strike.
func _charge() -> float:
	if act == Act.TELL:
		return smoothstep(0.15, 0.85, act_u)
	return 0.0


func _muzzle() -> Vector3:
	return _wrist + Vector3(0.0, 0.0, -0.12)


## Path progress, in strides, at time `t`: quick in the lurch, slow in the drag. Sets the stride's
## phase, the lurch and the drag.
func _progress(t: float) -> float:
	var s := STRIDE_HZ * t + 0.06 * sin(TAU * 0.17 * t + _p[0])
	var n := floorf(s)
	var f := s - n
	_phase = f
	_lurch = sin(PI * f / 0.4) if f < 0.4 else 0.0
	_drag = sin(PI * (f - 0.45) / 0.5) if f >= 0.45 and f < 0.95 else 0.0
	return n + (0.7 * smoothstep(0.0, 1.0, f / 0.4) if f < 0.4 else 0.7 + 0.3 * (f - 0.4) / 0.6)


func _root_at(p: float) -> Vector3:
	var a := p * TAU / STRIDES_PER_LOOP + _p[1]
	var idle := 1.0 - _drive
	return Vector3(PATH.x * cos(a) * idle, GROUND_Y, PATH.y * sin(a) * idle) + Basis(Vector3.UP, _yaw_at(p)) * Vector3(0.0, 0.0, HUNCH_BACK)


## The way it faces at progress `p`: along its loop; driven, the daemon's own way (C27b).
func _yaw_at(p: float) -> float:
	var a := p * TAU / STRIDES_PER_LOOP + _p[1]
	return atan2(PATH.x * sin(a), -PATH.y * cos(a)) * (1.0 - _drive)


## The good foot in stride `n` at phase `f`: swinging in the lurch, then planted.
func _right_foot(n: float, f: float) -> Vector3:
	var to := _plant(n + 0.7, 0.16, 0.1)
	if f >= 0.4:
		return to
	var u := f / 0.4
	return _plant(n - 1.0 + 0.7, 0.16, 0.1).lerp(to, smoothstep(0.0, 1.0, u)) + Vector3.UP * (0.13 * sin(PI * u))


## The bad foot: dragged along the ground in the drag, otherwise where it was left.
func _left_foot(n: float, f: float) -> Vector3:
	var was := _plant(n, -0.19, -0.04)
	if f < 0.45:
		return was
	var to := _plant(n + 1.0, -0.19, -0.04)
	if f >= 0.95:
		return to
	var u := (f - 0.45) / 0.5
	return was.lerp(to, u) + Vector3.UP * (0.02 * sin(PI * u))


## Where a foot plants at progress `p`: `side` metres out to the right and `ahead` metres ahead.
func _plant(p: float, side: float, ahead: float) -> Vector3:
	return _root_at(p) + Basis(Vector3.UP, _yaw_at(p)) * Vector3(side, 0.0, -ahead)


## A direction leaning `lean` radians forward from up and `side` radians sideways (body space).
static func _lean(lean: float, side: float) -> Vector3:
	return Vector3(sin(side) * 0.5, cos(lean), -sin(lean)).normalized()


static func _knee_at(hip: Vector3, foot: Vector3, pole: Vector3) -> Vector3:
	var span := foot - hip
	var d := clampf(span.length(), absf(THIGH - SHIN) + 0.001, THIGH + SHIN - 0.001)
	var dir := span.normalized() if span.length_squared() > 0.000001 else Vector3.DOWN
	var x := (THIGH * THIGH - SHIN * SHIN + d * d) / (2.0 * d)
	var h := sqrt(maxf(THIGH * THIGH - x * x, 0.0))
	var side := pole - dir * pole.dot(dir)
	if side.length_squared() < 0.000001:
		side = Vector3.FORWARD
	return hip + dir * x + side.normalized() * h


# --- For the checks. ---

## How many of the body's own bones are drawn now.
func bones_shown() -> int:
	var count := 0
	for b in BONES:
		count += 1 if shown(_bones[b]) else 0
	return count


## Whether each of the body's bones is drawn now.
func bones_state() -> Array[bool]:
	var out: Array[bool] = []
	for b in BONES:
		out.append(shown(_bones[b]))
	return out


## Each ghost's pelvis set off from the body's (art space).
func ghost_offsets() -> PackedVector3Array:
	var out := PackedVector3Array()
	for layer in range(1, GHOSTS + 1):
		out.append(_roots[layer] - _roots[0])
	return out


## The body's pelvis now (art space).
func pelvis_at() -> Vector3:
	return _roots[0]


## The head's centre now (art space), drawn or not: it stays over the hit volume's head zone.
func head_at() -> Vector3:
	return _head
