extends DaemonArt
## The zombie process (A2b, rebuilt in A5; the "zombie" and "<defunct>" dummies: a defunct process
## is a zombie): dead, never reaped, and still walking. A hulking, hunched body of near-black armour,
## whole on its right side and coming apart on its left: a heavy chest and a hump of back plates, a
## low faceless head sunk between its shoulders, a great pauldron on its right shoulder, its right
## forearm a cannon ringed with three charge bands; on its left the armour is gone, its amber ember
## burning in the open cavity of its chest, its left arm only a column of loose voxels, and voxels
## peeling off that side all the time, drifting up and away as they derezz. Its light is amber and
## only in its seams: the elbow and knee bands, the cannon's charge bands and its muzzle, the ember
## (its weak points, weak()). Faceless: no eye, no mouth.
##
## No two alike (A5): its seed sets its size, its bulk, how many back plates and right-flank plates
## it wears, its pauldron's size and spikes, how many voxels its left arm keeps and how many it
## sheds, how far it hunches, its limp's pace (the lurch, the drag, its loop), its battle damage (a
## scorched plate, a flickering band) and, one in twelve, an elite: bigger and broader, three spikes
## on its back, a second plate on its pauldron.
##
## It limps in a slow loop round its spot: a lurch on its good (right) leg, the foot lifting and
## swinging ahead, then the bad (left) one dragged along the ground after it, the pelvis rising in
## the lurch and dropping as it drags, the body leaning onto the bad side. Its feet are planted: a
## foot stays where it stands until it steps or is dragged. At rest the limp is a function of its
## clock round its loop (the same zombie limps the same way on every run, SIGSTOP slowing it);
## driven, its planted feet are held in the world as the daemon moves under them and each lurch and
## drag goes to where its foot's home is now (A5: the slide C27b left, a loop on its own clock under
## a moving daemon, is gone). It twitches: its head snaps round,
## its voxel arm jerks, the whole body glitches sideways for a moment. Its head stays inside the hit
## volume's head zone (it hunches; its back plates stand over it). Visual only: it never leaves its
## spot.
##
## Fighting back (C27b), its brain drives it: it shambles after its prey (its loop closes in to the
## daemon's own place and it faces the way the daemon goes, its planted feet held in the world as
## the daemon moves, stepping and dragging to catch up), and its tell is its cannon raised at its
## prey, the charge bands lighting one after another and the muzzle swelling brighter; the strike
## throws its bolt from the muzzle (the brain's, scripts/fight/glitch_bolt.gd) and the arm drops back.

## Its pieces of armour, in order (the right flank's and the back's own come after).
enum Plate { PELVIS, BELLY, CHEST, HEAD, PAULDRON }
## The limbs: right upper arm, the cannon, both thighs and shins.
enum Limb { UPPER_R, CANNON, THIGH_L, THIGH_R, SHIN_L, SHIN_R }
## Its pelvis's height above the ground, its legs' lengths, its upper arm's, and the cannon's.
const HIP_H := 0.88
const THIGH := 0.46
const SHIN := 0.46
const UPPER := 0.46
const CANNON_L := 0.62
## How far behind its loop the pelvis walks (so the hunched head, ahead of it, stays over the hit
## volume), the loop's half-widths (x, z), in metres, and the strides round it.
const HUNCH_BACK := 0.24
const PATH := Vector2(0.24, 0.17)
const STRIDES_PER_LOOP := 6.0
## Where each foot plants round its stride's ground point (body space: +X right, -Z ahead): the
## left (the bad one, dragged), then the right (the good one, lurching).
const HOMES := [Vector3(-0.19, 0.0, 0.04), Vector3(0.16, 0.0, -0.1)]
## A stride: the lurch is its first share (the good foot swinging this high), the drag between
## these shares.
const LURCH_TO := 0.4
const DRAG_FROM := 0.45
const DRAG_TO := 0.95
const STEP_H := 0.13
## Driven (A5): its stride's length, so its strides come faster the faster it moves, and how far
## ahead of its home each lurch and drag lands, in strides of its motion.
const STRIDE_M := 0.7
const LEAD := 0.5
## The cannon's charge bands, and the voxel arm's longest and the most it sheds.
const BANDS := 3
const ARM_VOXELS := 9
const BITS_LAST := 18
## Each shed voxel lives this long, in seconds, drifting up and out.
const BIT_S := 1.6
## Twitches: about one every TWITCH_EVERY seconds.
const TWITCH_EVERY := 1.3
## A ping's stagger (C28), at its start: how far back it leans (radians), how far it is thrown back
## and down, and how far it shudders side to side.
const STAGGER_LEAN := 0.5
const STAGGER_BACK_M := 0.15
const STAGGER_DROP_M := 0.1
const STAGGER_SHAKE_M := 0.07

var _plates := PackedInt32Array()
var _back := PackedInt32Array()
var _flank := PackedInt32Array()
var _spikes := PackedInt32Array()
var _limbs := PackedInt32Array()
var _feet := PackedInt32Array()
var _neck: int
var _elbow: int
var _knees := PackedInt32Array()
var _bands := PackedInt32Array()
var _muzzle_glow: int
var _ember: int
var _arm := PackedInt32Array()
var _bits := PackedInt32Array()
var _p := PackedFloat32Array()

## Its build (A5): its bulk, its hunch, its pauldron's size, its voxel arm, its limp's pace.
var _bulk := 1.0
var _hunch := 0.5
var _pauldron := 1.0
var _stride_hz := 0.6
var _head_size := Vector3(0.27, 0.24, 0.3)

## The gait at the time last asked for: the stride's number and phase, the lurch and the drag (0
## to 1).
var _stride := 0.0
var _phase := 0.0
## Driven (A5): its strides so far, and its motion in art space (metres a second).
var _gait_s := 0.0
var _going := Vector3.ZERO
var _lurch := 0.0
var _drag := 0.0
## The feet (left, then right), art space: where each stands (planted, carried in the world while
## driven), where each is drawn now, where each lurch or drag started, the stride each last started
## and last landed in (driven), and whether it was driven a pose ago.
var _foot := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _drawn_at := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _from := PackedVector3Array([Vector3.ZERO, Vector3.ZERO])
var _began := PackedFloat32Array([-1.0, -1.0])
var _landed := PackedFloat32Array([-1.0, -1.0])
var _was_driven := false
## The pelvis, the head's centre and the muzzle as last posed (art space), for the checks and the
## bolt.
var _pelvis := Vector3.ZERO
var _right := Vector3.RIGHT
var _head := Vector3.ZERO
var _mouth := Vector3(0.3, 0.3, -0.5)


func _build() -> void:
	ai_kind = "zombie"
	core_color = Palette.HOSTILE_AMBER
	edge_color = Palette.HOSTILE_AMBER
	gutter = 1.0
	glyph_count = 5
	glyph_radius = 1.1
	glyph_low = -0.5
	glyph_high = 1.2
	glyph_size = 0.13
	glyph_turns = -0.02
	reach = AABB(Vector3(-2.0, -1.0, -2.0), Vector3(4.0, 3.4, 4.0))
	tag_height = 2.55
	budget_triangles = 3400
	budget_draw_calls = 14
	size_low = 0.94
	size_high = 1.05
	elite_size = 1.1
	for i in 5:
		_p.append(TAU * dice(i, 1))
	# The build's rolls (A5).
	_bulk = 1.15 if elite else lerpf(0.9, 1.1, dice(40, 0))
	_hunch = lerpf(0.4, 0.6, dice(41, 0))
	_pauldron = 1.25 if elite else lerpf(0.85, 1.15, dice(42, 0))
	_stride_hz = lerpf(0.5, 0.7, dice(43, 0))
	_head_size = Vector3(lerpf(0.24, 0.3, dice(46, 0)), lerpf(0.21, 0.26, dice(46, 1)), lerpf(0.27, 0.33, dice(46, 2)))
	for i in Plate.size():
		_plates.append(part(Shape.PLATE, Look.ARMOR))
	if elite:
		_plates.append(part(Shape.PLATE, Look.ARMOR))  # the pauldron's second plate
	for i in (3 if elite else pick(47, 0, 1, 3)):
		_back.append(part(Shape.PLATE, Look.ARMOR))
	for i in (2 if elite else pick(48, 0, 0, 2)):
		_flank.append(part(Shape.PLATE, Look.ARMOR))
	for i in (3 if elite else pick(49, 0, 0, 2)):
		_spikes.append(part(Shape.SHARD, Look.ARMOR))
	for i in Limb.size():
		_limbs.append(part(Shape.LIMB, Look.ARMOR))
	for i in 2:
		_feet.append(part(Shape.PLATE, Look.ARMOR))
	_neck = seam(part(Shape.RING, Look.CORE))
	_elbow = weak(seam(part(Shape.RING, Look.CORE)))
	for i in 2:
		_knees.append(weak(seam(part(Shape.RING, Look.CORE))))
	for i in BANDS:
		_bands.append(weak(part(Shape.RING, Look.CORE)))
	_muzzle_glow = weak(part(Shape.GEM, Look.CORE))
	_ember = weak(part(Shape.GEM, Look.CORE))
	for i in pick(50, 0, 6, ARM_VOXELS):
		_arm.append(part(Shape.CUBE, Look.SHELL))
	for i in (BITS_LAST if elite else pick(51, 0, 12, BITS_LAST)):
		_bits.append(part(Shape.CUBE, Look.SHELL))
	# Battle damage (A5): a plate scorched, the bad knee's band and another flickering.
	var armour: Array[int] = []
	armour.append_array(_plates)
	armour.append_array(_back)
	for i in pick(52, 0, 0, 2):
		scorch(armour[pick(53, i, 0, armour.size() - 1)], lerpf(0.5, 1.0, dice(54, i)))
	scorch(_limbs[Limb.THIGH_L], lerpf(0.3, 0.8, dice(55, 0)))
	flicker(_knees[0], lerpf(0.3, 0.7, dice(56, 0)))
	if dice(57, 0) < 0.5:
		flicker(_elbow, lerpf(0.2, 0.6, dice(57, 1)))


func _pose(t: float, delta: float) -> void:
	var idle := 1.0 - _drive
	# Its loop round its spot (idle), or the daemon's own place (driven), and the way it faces. At
	# rest its strides are its clock's; driven they come as fast as it moves (A5).
	var progress: float
	if _drive <= 0.0:
		progress = _progress(t)
		_gait_s = _stride + _phase
		_going = Vector3.ZERO
	else:
		_going = -_carry.origin / delta if delta > 0.0 else Vector3.ZERO
		_going.y = 0.0
		_gait_s += (_stride_hz + _going.length() / STRIDE_M) * delta
		progress = _progress_of(_gait_s)
	var yaw := _yaw_at(progress)
	var turn := Basis(Vector3.UP, yaw)
	var root := _root_at(progress)
	_gait(root, turn)
	# Twitches: which kind, and how hard now.
	var tw := int(floor(t / TWITCH_EVERY))
	var tau := t - tw * TWITCH_EVERY - 0.5 * dice(tw, 10)
	var kind := int(dice(tw, 11) * 4.0)
	var amp := 0.0
	if tau >= 0.0:
		amp = tau / 0.04 if tau < 0.04 else exp(-(tau - 0.04) * 10.0)
	var sign := 1.0 if dice(tw, 12) < 0.5 else -1.0
	if kind == 3:
		turn = Basis(Vector3.UP, yaw + 0.2 * amp * sign)
	# A ping's stagger (C28): thrown back, leaning away, shuddering, its arms flung up.
	var reel := staggered()
	var body := turn * Basis(Vector3.BACK, -0.14 * _drag + 0.04 * _lurch) * Basis(Vector3.RIGHT, STAGGER_LEAN * reel)
	var jump := turn * Vector3(0.12 * sign, 0.0, 0.04) * (amp if kind == 3 and tau < 0.1 else 0.0)
	jump += turn * Vector3(STAGGER_SHAKE_M * sin(37.0 * t), -STAGGER_DROP_M, STAGGER_BACK_M) * reel
	var pelvis := root + Vector3(0.0, HIP_H + 0.06 * _lurch - 0.09 * _drag, 0.0) + jump + recoil()
	_pelvis = pelvis
	var breath := sin(TAU * 0.4 * t + _p[2])
	var right := body * Vector3.RIGHT
	_right = right
	var up := body * Vector3.UP
	var ahead := body * Vector3.FORWARD
	# The pelvis, the belly, and the chest hunched forward over them, breathing.
	var hunch := Basis(Vector3.RIGHT, -_hunch)
	lay(_plates[Plate.PELVIS], pelvis, body * Basis.from_scale(Vector3(0.46 * _bulk, 0.2, 0.32)))
	var belly := pelvis + body * Vector3(0.0, 0.22, -0.04)
	lay(_plates[Plate.BELLY], belly, body * Basis(Vector3.RIGHT, -0.2 * _hunch) * Basis.from_scale(Vector3(0.48 * _bulk, 0.26, 0.34)))
	var chest := pelvis + body * (Vector3(0.0, 0.55, -0.16) + Vector3(0.0, 0.0, -0.12) * (_hunch - 0.5))
	var chest_frame := body * hunch
	lay(_plates[Plate.CHEST], chest, chest_frame * Basis.from_scale(Vector3(0.82 * _bulk, 0.5 * (1.0 + 0.03 * breath), 0.5)))
	# The hump of back plates over the shoulders, standing over the head.
	for i in _back.size():
		var u := (i + 0.5) / _back.size()
		var at := chest + chest_frame * Vector3((u - 0.5) * 0.3 * _bulk, 0.25 + 0.05 * sin(TAU * u), 0.12 - 0.1 * u)
		lay(_back[i], at, chest_frame * Basis(Vector3.BACK, (u - 0.5) * 0.5) * Basis(Vector3.RIGHT, 0.4) * Basis.from_scale(Vector3(0.3 * _bulk, 0.09, 0.32)))
	for i in _spikes.size():
		var u := (i + 0.5) / _spikes.size()
		var base := chest + chest_frame * Vector3((u - 0.5) * 0.32 * _bulk, 0.3, 0.16)
		bone(_spikes[i], base, base + chest_frame * Vector3((u - 0.5) * 0.25, 0.42, 0.3), 0.08)
	# The head: low, heavy and faceless, sunk between the shoulders and hanging forward, an amber
	# band round its neck; it snaps round in a twitch.
	var head_side := 0.8 * amp * sign if kind == 0 else 0.0
	var neck := chest + chest_frame * Vector3(0.0, 0.2, -0.2)
	var head_way := (body * Vector3(sin(head_side) * 0.6, -0.55, -1.0)).normalized()
	var head_at := neck + head_way * 0.16
	_head = head_at
	orient(_neck, neck, head_way, 0.06, 0.18)
	lay(_plates[Plate.HEAD], head_at, plank(right, -head_way) * Basis.from_scale(_head_size))
	# The right shoulder under its great pauldron, the upper arm, an amber elbow, and the cannon:
	# hanging at rest, raised at its prey in the tell, its bands lighting one after another and its
	# muzzle swelling (C27b's tell, A5's charge).
	var shoulder := chest + chest_frame * Vector3(0.5 * _bulk, 0.12, 0.0)
	lay(_plates[Plate.PAULDRON], shoulder + chest_frame * Vector3(0.04, 0.12, 0.0), chest_frame * Basis(Vector3.BACK, -0.35) * Basis.from_scale(Vector3(0.42, 0.2, 0.5) * _pauldron))
	if _plates.size() > Plate.PAULDRON + 1:
		lay(_plates[Plate.PAULDRON + 1], shoulder + chest_frame * Vector3(0.12, 0.2, 0.0), chest_frame * Basis(Vector3.BACK, -0.6) * Basis.from_scale(Vector3(0.24, 0.12, 0.34) * _pauldron))
	var swing := 0.3 * sin(TAU * _phase + 0.5) * idle
	var hang := Vector3(0.25, -1.0, -0.2 + swing).normalized()
	var raise := _raise()
	var upper := hang.lerp(Vector3(0.25, 0.3, -1.0).normalized(), raise).normalized().lerp(Vector3(0.8, 0.7, 0.2).normalized(), reel).normalized()
	var fore := (upper + Vector3(0.0, 0.2, -0.6)).normalized().lerp(Vector3(0.02, 0.15, -1.0).normalized(), raise).normalized()
	var elbow := shoulder + body * upper * UPPER
	var mouth := elbow + body * fore * CANNON_L
	_mouth = mouth + body * fore * 0.06
	bone(_limbs[Limb.UPPER_R], shoulder, elbow, 0.2 * _bulk)
	orient(_elbow, elbow, body * upper, 0.06, 0.17 * _bulk)
	bone(_limbs[Limb.CANNON], elbow, mouth, 0.26 * _bulk)
	var charge := _charge()
	for k in BANDS:
		var u := 0.38 + 0.22 * k
		orient(_bands[k], elbow + body * fore * (CANNON_L * u), body * fore, 0.05, 0.29 * _bulk)
		brighten(_bands[k], 0.25 + 2.2 * clampf(charge * BANDS - k, 0.0, 1.0))
	orient(_muzzle_glow, _mouth, body * fore, 0.1 * (1.0 + 1.2 * charge), 0.1 * (1.0 + 1.2 * charge))
	brighten(_muzzle_glow, 0.5 + 3.0 * charge + (2.0 if act == Act.STRIKE else 0.0))
	# The right flank's own plates.
	for i in _flank.size():
		var at := chest + chest_frame * Vector3(0.36 * _bulk, -0.14 - 0.16 * i, -0.02)
		lay(_flank[i], at, chest_frame * Basis(Vector3.BACK, -0.5) * Basis.from_scale(Vector3(0.12, 0.08, 0.32)))
	# The open left side: the ember burning in the chest's cavity, guttering, and the left arm only a
	# column of voxels hanging from the bare shoulder, jerking in a twitch, flung up in a stagger.
	var cavity := chest + chest_frame * Vector3(-0.32 * _bulk, 0.02, -0.18)
	orient(_ember, cavity, up, 0.2 * (1.0 + 0.06 * breath), 0.17)
	brighten(_ember, 1.3 + 0.3 * breath)
	var left := chest + chest_frame * Vector3(-0.5 * _bulk, 0.1, 0.0)
	var jerk := amp if kind == 1 else 0.0
	var limp := Vector3(-0.35, -1.0, -0.1 - 0.15 * sin(TAU * _phase) * idle).normalized().lerp(Vector3(-1.0, 0.4, -0.6).normalized(), jerk).normalized().lerp(Vector3(-0.8, 0.7, 0.2).normalized(), reel).normalized()
	var tick := int(floor(t * 7.0))
	for i in _arm.size():
		var u := float(i) / maxf(_arm.size() - 1, 1.0)
		var at := left + body * limp * (0.95 * u) + body * Vector3(0.03 * sin(5.0 * t + i), 0.0, 0.03 * cos(4.0 * t + i * 2.0))
		var size := 0.15 * (1.0 - 0.35 * u)
		orient(_arm[i], at, body * Vector3(sin(i * 1.7 + t), 1.0, cos(i * 2.3)), size, size)
		present(_arm[i], 0.0 if dice(i + 300, tick) < 0.12 else 1.0)
	_pose_bits(t, chest, chest_frame, left, limp, body)
	# The legs: hips on the pelvis, the knees by two-bone IK (the bad one knocked in), each foot a
	# boot where the gait put it, the bad one's toe dragging down.
	for side in 2:
		var x := -1.0 if side == 0 else 1.0
		var hip := pelvis + body * Vector3(0.14 * x * _bulk, -0.04, 0.0)
		var foot := _drawn_at[side]
		var ankle := foot + Vector3(0.0, 0.1, 0.0)
		var reached := hip + (ankle - hip).limit_length(THIGH + SHIN - 0.002)
		var pole := ahead + body * Vector3(0.3 if side == 0 else 0.1, 0.0, 0.0)
		var knee := _knee_at(hip, reached, pole)
		bone(_limbs[Limb.THIGH_L + side], hip, knee, 0.17 * _bulk)
		bone(_limbs[Limb.SHIN_L + side], knee, reached, 0.14 * _bulk)
		orient(_knees[side], knee, knee - hip, 0.06, 0.17 * _bulk)
		var toe_down := 0.5 * _drag if side == 0 else 0.0
		lay(_feet[side], reached + Vector3(0.0, -0.05, 0.0) + ahead * 0.06, body * Basis(Vector3.RIGHT, -toe_down) * Basis.from_scale(Vector3(0.16 * _bulk, 0.1, 0.3)))


## Where its feet are drawn now (A5): at rest the limp's own, a function of its clock along its loop;
## driven, each planted foot held in the world as the daemon moves (C27b's carry), the good one
## lurching and the bad one dragged, each to where its home is now, on the same stride's clock.
func _gait(root: Vector3, turn: Basis) -> void:
	var n := _stride
	var f := _phase
	if _drive <= 0.0:
		_drawn_at[0] = _left_foot(n, f)
		_drawn_at[1] = _right_foot(n, f)
		_foot[0] = _drawn_at[0]
		_foot[1] = _drawn_at[1]
		_was_driven = false
		return
	if not _was_driven:
		# Taking over from the limp at rest: its feet where they stand, a stride in progress started.
		_was_driven = true
		for side in 2:
			_from[side] = _foot[side]
			_began[side] = n
			_landed[side] = n - 1.0
	if _carry != Transform3D.IDENTITY:
		for side in 2:
			_foot[side] = _carry * _foot[side]
			_foot[side].y = GROUND_Y
			_from[side] = _carry * _from[side]
			_from[side].y = GROUND_Y
	# The good foot: lifted at the stride's start, swinging to its home (ahead of it by its motion),
	# planted there at the lurch's end.
	var ahead := _going * (LEAD * STRIDE_M / maxf(_going.length(), STRIDE_M * _stride_hz))
	var home_r := root + turn * (HOMES[1] as Vector3) + ahead
	if f < LURCH_TO:
		if _began[1] != n:
			_began[1] = n
			_from[1] = _foot[1]
		var u := f / LURCH_TO
		_drawn_at[1] = _from[1].lerp(home_r, smoothstep(0.0, 1.0, u)) + Vector3.UP * (STEP_H * sin(PI * u))
	else:
		if _landed[1] != n and _began[1] == n:
			_landed[1] = n
			_foot[1] = Vector3(home_r.x, GROUND_Y, home_r.z)
		_drawn_at[1] = _foot[1]
	# The bad foot: dragged along the ground to its home in the drag, planted there after.
	var home_l := root + turn * (HOMES[0] as Vector3) + ahead
	if f >= DRAG_FROM and f < DRAG_TO:
		if _began[0] != n:
			_began[0] = n
			_from[0] = _foot[0]
		var u := (f - DRAG_FROM) / (DRAG_TO - DRAG_FROM)
		_drawn_at[0] = _from[0].lerp(home_l, u) + Vector3.UP * (0.02 * sin(PI * u))
	else:
		if f >= DRAG_TO and _landed[0] != n and _began[0] == n:
			_landed[0] = n
			_foot[0] = Vector3(home_l.x, GROUND_Y, home_l.z)
		_drawn_at[0] = _foot[0]


## Path progress, in strides, at time `t`: quick in the lurch, slow in the drag. Sets the stride's
## number and phase, the lurch and the drag.
func _progress(t: float) -> float:
	return _progress_of(_stride_hz * t + 0.06 * sin(TAU * 0.17 * t + _p[0]))


## Path progress, in strides, `s` strides into its walk; sets the stride's number and phase, the
## lurch and the drag.
func _progress_of(s: float) -> float:
	var n := floorf(s)
	var f := s - n
	_stride = n
	_phase = f
	_lurch = sin(PI * f / LURCH_TO) if f < LURCH_TO else 0.0
	_drag = sin(PI * (f - DRAG_FROM) / (DRAG_TO - DRAG_FROM)) if f >= DRAG_FROM and f < DRAG_TO else 0.0
	return n + (0.7 * smoothstep(0.0, 1.0, f / LURCH_TO) if f < LURCH_TO else 0.7 + 0.3 * (f - LURCH_TO) / (1.0 - LURCH_TO))


## The ground point under its pelvis at progress `p`: on its loop round its spot, set back so its
## hunched head stands over the hit volume; driven, the daemon's own place.
func _root_at(p: float) -> Vector3:
	var a := p * TAU / STRIDES_PER_LOOP + _p[1]
	var idle := 1.0 - _drive
	return Vector3(PATH.x * cos(a) * idle, GROUND_Y, PATH.y * sin(a) * idle) + Basis(Vector3.UP, _yaw_at(p)) * Vector3(0.0, 0.0, HUNCH_BACK)


## The way it faces at progress `p`: along its loop; driven, the daemon's own way (C27b).
func _yaw_at(p: float) -> float:
	var a := p * TAU / STRIDES_PER_LOOP + _p[1]
	return atan2(PATH.x * sin(a), -PATH.y * cos(a)) * (1.0 - _drive)


## The good foot at rest in stride `n` at phase `f`: swinging in the lurch, then planted.
func _right_foot(n: float, f: float) -> Vector3:
	var to := _plant(n + 0.7, 1)
	if f >= LURCH_TO:
		return to
	var u := f / LURCH_TO
	return _plant(n - 1.0 + 0.7, 1).lerp(to, smoothstep(0.0, 1.0, u)) + Vector3.UP * (STEP_H * sin(PI * u))


## The bad foot at rest: dragged along the ground in the drag, otherwise where it was left.
func _left_foot(n: float, f: float) -> Vector3:
	var was := _plant(n, 0)
	if f < DRAG_FROM:
		return was
	var to := _plant(n + 1.0, 0)
	if f >= DRAG_TO:
		return to
	var u := (f - DRAG_FROM) / (DRAG_TO - DRAG_FROM)
	return was.lerp(to, u) + Vector3.UP * (0.02 * sin(PI * u))


## Where foot `side` plants at progress `p` at rest: its home round the loop's point there.
func _plant(p: float, side: int) -> Vector3:
	return _root_at(p) + Basis(Vector3.UP, _yaw_at(p)) * (HOMES[side] as Vector3)


## The voxels it sheds off its open left side: each born on that side as it stands then (the
## shoulder, the voxel arm, the flank, the bad leg), rising, turning and fading over BIT_S, then
## born again elsewhere.
func _pose_bits(t: float, chest: Vector3, chest_frame: Basis, left: Vector3, limp: Vector3, body: Basis) -> void:
	for i in _bits.size():
		var cycle := t / BIT_S + i * 0.137
		var n := floorf(cycle)
		var u := cycle - n
		var where := dice(i, int(n))
		var spot: Vector3
		if where < 0.4:
			spot = left + body * limp * (0.9 * dice(i + 20, int(n)))
		elif where < 0.8:
			spot = chest + chest_frame * Vector3(-0.32 * _bulk, (dice(i + 40, int(n)) - 0.5) * 0.45, (dice(i + 60, int(n)) - 0.5) * 0.35)
		else:
			spot = _pelvis + body * Vector3(-0.16, -0.3 - 0.4 * dice(i + 80, int(n)), 0.0)
		var drift := body * Vector3(-0.35 - 0.3 * dice(i + 100, int(n)), 0.75, 0.12 * sin(i))
		var at := spot + drift * u + Vector3(0.05 * sin(3.0 * u + i), 0.0, 0.05 * cos(2.0 * u + i))
		var size := 0.085 * (1.0 - 0.6 * u)
		orient(_bits[i], at, Vector3(sin(i + u * 5.0), 1.0, cos(i * 2.0 + u * 4.0)), size, size)
		present(_bits[i], 1.0 - u * u)


## How far the cannon is raised now, from the brain's act (C27b): up through the tell, held in the
## strike, down in the recovery.
func _raise() -> float:
	match act:
		Act.TELL:
			return smoothstep(0.0, 0.45, act_u)
		Act.STRIKE:
			return 1.0
		Act.RECOVER:
			return 1.0 - smoothstep(0.0, 1.0, act_u)
	return 0.0


## How far the cannon is charged: through the tell, its bands lighting one after another (A5);
## spent with the bolt in the strike.
func _charge() -> float:
	if act == Act.TELL:
		return smoothstep(0.1, 0.9, act_u)
	return 0.0


func _muzzle() -> Vector3:
	return _mouth


func _on_return() -> void:
	_was_driven = false


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

## The pelvis now (art space).
func pelvis_at() -> Vector3:
	return _pelvis


## The head's centre now (art space): it stays over the hit volume's head zone.
func head_at() -> Vector3:
	return _head


## Where each foot is drawn now (art space; left, then right), and whether each is planted (the
## good one not lurching, the bad one not dragged).
func feet_at() -> PackedVector3Array:
	return _drawn_at


func planted() -> Array[bool]:
	return [_phase < DRAG_FROM or _phase >= DRAG_TO, _phase >= LURCH_TO]


## The cannon's charge now (0 to 1) and each band's brightness (A5).
func charge() -> float:
	return _charge()


func band_glow() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for id in _bands:
		out.append(part_custom(id).g)
	return out


## How many voxels hang in its arm, and how many are shed and drawn now (A5).
func arm_voxels() -> int:
	return _arm.size()


func shed_now() -> int:
	var count := 0
	for id in _bits:
		count += 1 if shown(id) else 0
	return count


## How far `point` (art space) is to its right of its pelvis, along its body's own right as last
## posed: below 0 on its open (left) side.
func side_of(point: Vector3) -> float:
	return (point - _pelvis).dot(_right)


## Where each shed voxel is now (art space).
func shed_at() -> PackedVector3Array:
	var out := PackedVector3Array()
	for id in _bits:
		out.append(part_transform(id).origin)
	return out
