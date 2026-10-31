class_name CopyArt
extends DaemonArt
## The copy of you (C41; PRD 5.7, 1:10 to 1:35: "A daemon walks out wearing their username: a copy of them"; STORY.md:
## "the same hexagon as you, dark, with the prompt lit red"). Built on A5's kit as every daemon is (solid near-black
## armour, light only in its seams and weak points, a glitch that breaks it into cells), but a body of its own: a tall,
## broad, upright figure on two long legs, a twisted mirror of the player. Its head is the nixfred hexagon, pointy-top,
## a dark face plate with the prompt lit red on it, mirrored: `_<` (its cursor blinking); behind it the hexagon's ring
## of six bars as the brand draws it, a gap at the start of each side, lit red and slowly turning. A heavy armoured
## chest under broad layered pauldrons, a ridge of spines down its back, long arms ending in three claws, plated shins.
## Crimson in its seams (the knees, the elbows, the waist, the neck) and its heart; its armour's rim in the player's own
## teal, so it reads on the pit's red and is plainly theirs, gone wrong. Faceless: no eye, no mouth.
##
## The opener's pit beat (scripts/opener/pit_beat.gd) walks it and tells it, every frame before it is posed: how far it
## has walked (walk_m) and how fast (speed), the ground's slope under it (a stair of light rising out of the pit, then
## the floor), where its head looks (gaze, in its own space: at you while it walks, your look mirrored once it stands),
## the head's tilt, the opener's clock (time) and the plane it forms through (form_y: below it its parts are cells
## breaking up, above it whole, so it comes into being as it climbs over the pit's rim). Its gait plants its feet: each
## foot moves back under it at exactly its pace while down (STRIDE a step), so a foot never slides; the beat lays a hex
## of light where each one lands (footfalls()). Posed from those numbers alone, so the same opener poses it the same
## way every run. Visual only: no hit volume, no brain, no daemon behind it.

## Its build (art space: the ground at GROUND_Y, +X its right, -Z ahead): the pelvis's height over the ground, the
## legs, the shoulders and arms, the neck and the head (heights from the pelvis).
const HIP_H := 1.36
const HIP_X := 0.2
const THIGH := 0.76
const SHIN := 0.74
const ANKLE_H := 0.1
const SHOULDER_UP := 0.82
const SHOULDER_X := 0.5
const UPPER := 0.54
const FORE := 0.6
const CLAW := 0.34
const NECK_FROM := 0.86
const NECK_TO := 1.0
const HEAD_UP := 1.24
## The face's hexagon: its circumradius (corner to centre) and thickness; the crown's ring behind it.
const FACE_R := 0.34
const FACE_T := 0.1
const CROWN_R := 0.72
const CROWN_BACK := 0.14
const CROWN_TURN := 0.22
## A step: how far each foot moves while it is down (the body moves the same), and how high a foot lifts.
const STRIDE := 0.8287
const LIFT := 0.18
## How far it leans into its walk and its climb, radians.
const LEAN_WALK := 0.07
const LEAN_CLIMB := 0.16
## The prompt's strokes on its face, as the player sees them (x right, y up, metres from the face's centre): the
## cursor `_` on the left, the `<` on the right: the nixfred `>_` in a mirror.
const CURSOR := [Vector2(-0.2, -0.12), Vector2(-0.06, -0.12)]
const CHEVRON := [Vector2(0.18, 0.12), Vector2(0.03, 0.0), Vector2(0.18, -0.12)]
const STROKE := 0.06
const GLYPH_GLOW := 2.3
## The cursor's blink, a second.
const BLINK_HZ := 1.1
## The heart's light: a swell in time with its steps while it walks, slow once it stands.
const HEART_R := 0.12
## The column of hexagons from the pelvis up: [height, width across corners, tall].
const COLUMN := [[0.0, 0.58, 0.2], [0.21, 0.42, 0.16], [0.42, 0.7, 0.24], [0.66, 0.96, 0.42]]
## The spines down its back: [height on the column, length, lean back].
const SPINES := [[0.82, 0.42, 0.55], [0.64, 0.34, 0.75], [0.46, 0.24, 0.95]]

## Set by the pit beat before each pose (see above).
var walk_m := 0.0
var speed := 0.0
var slope := 0.0
var gaze := Vector3.FORWARD
var tilt := 0.0
var time := 0.0
var form_y := 99.0

var _face: int
var _face_back: int
var _cursor: int
var _chevron: Array[int] = []
var _crown: Array[int] = []
var _neck: int
var _neck_ring: int
var _column: Array[int] = []
var _waist_rings: Array[int] = []
var _breast: int
var _pecs: Array[int] = []
var _pauldrons: Array[int] = []
var _spines: Array[int] = []
var _heart: int
var _thighs: Array[int] = []
var _cuisses: Array[int] = []
var _shins: Array[int] = []
var _knees: Array[int] = []
var _guards: Array[int] = []
var _feet: Array[int] = []
var _uppers: Array[int] = []
var _fores: Array[int] = []
var _bracers: Array[int] = []
var _elbows: Array[int] = []
var _claws: Array[int] = []


func _build() -> void:
	ai_kind = "copy"
	core_color = Palette.CRIMSON
	edge_color = Palette.TEAL
	gutter = 0.0
	glyph_count = 10
	glyph_radius = 1.05
	glyph_low = -0.2
	glyph_high = 1.8
	glyph_size = 0.13
	glyph_turns = 0.05
	reach = AABB(Vector3(-1.8, -1.2, -1.8), Vector3(3.6, 3.9, 3.6))
	tag_height = 2.62
	size_low = 1.0
	size_high = 1.0
	elite_size = 1.0
	# The head: the hexagon's face and its back, the prompt on it, the crown behind.
	_face = part(Shape.HEX, Look.ARMOR)
	_face_back = part(Shape.HEX, Look.ARMOR)
	_cursor = weak(part(Shape.CUBE, Look.CORE))
	for i in 2:
		_chevron.append(weak(part(Shape.CUBE, Look.CORE)))
	for i in 6:
		_crown.append(part(Shape.LIMB, Look.CORE))
	_neck = part(Shape.LIMB, Look.ARMOR)
	_neck_ring = seam(part(Shape.RING, Look.CORE))
	# The body: a column of hexagons narrowing to the waist and out to a broad chest, seams between, a breastplate and
	# two plates in a V over it, layered pauldrons, a ridge of spines down the back, the heart's light.
	for i in COLUMN.size():
		_column.append(part(Shape.HEX, Look.ARMOR))
	for i in 2:
		_waist_rings.append(seam(part(Shape.RING, Look.CORE)))
	_breast = part(Shape.PLATE, Look.ARMOR)
	for i in 2:
		_pecs.append(part(Shape.PLATE, Look.ARMOR))
	for i in 4:
		_pauldrons.append(part(Shape.PLATE, Look.ARMOR))
	for i in SPINES.size():
		_spines.append(part(Shape.SHARD, Look.ARMOR))
	_heart = weak(part(Shape.GEM, Look.CORE))
	# Two long legs and two long arms, crimson at the knees and the elbows, plated shins and forearms, three claws a hand.
	for side in 2:
		_thighs.append(part(Shape.LIMB, Look.ARMOR))
		_cuisses.append(part(Shape.PLATE, Look.ARMOR))
		_shins.append(part(Shape.LIMB, Look.ARMOR))
		_knees.append(weak(seam(part(Shape.RING, Look.CORE))))
		_guards.append(part(Shape.PLATE, Look.ARMOR))
		_feet.append(part(Shape.PLATE, Look.ARMOR))
		_uppers.append(part(Shape.LIMB, Look.ARMOR))
		_fores.append(part(Shape.LIMB, Look.ARMOR))
		_bracers.append(part(Shape.PLATE, Look.ARMOR))
		_elbows.append(seam(part(Shape.RING, Look.CORE)))
		for f in 3:
			_claws.append(part(Shape.SHARD, Look.ARMOR))


## Its head's centre over its art origin, standing tall (for the beat: where it looks from, where its name goes).
static func head_y() -> float:
	return GROUND_Y + HIP_H + HEAD_UP


## Where it is in its walk: its phase (whole steps of both feet, 0 to 1 a cycle).
func gait_phase() -> float:
	return walk_m / (2.0 * STRIDE)


## A foot's place in art space, `side` 0 its left (+X is its right) and 1 its right, at gait phase `phase` on ground
## sloping `rise` metres a metre ahead: down and moving back under it for the first half of its cycle, then lifted and
## swung ahead.
static func foot_at(side: int, phase: float, rise: float) -> Vector3:
	var p := fposmod(phase + 0.5 * side, 1.0)
	var x := HIP_X * (-1.0 if side == 0 else 1.0)
	var z: float
	var lift := 0.0
	if p < 0.5:
		z = lerpf(-STRIDE * 0.5, STRIDE * 0.5, p / 0.5)
	else:
		var u := (p - 0.5) / 0.5
		var eased := u * u * (3.0 - 2.0 * u)
		z = lerpf(STRIDE * 0.5, -STRIDE * 0.5, eased)
		lift = LIFT * sin(PI * u)
	return Vector3(x, GROUND_Y + ANKLE_H + rise * -z + lift, z)


func _pose(_t: float, _delta: float) -> void:
	var phase := gait_phase()
	var walking := clampf(speed / 0.6, 0.0, 1.0)
	var climb := clampf(slope / 0.6, 0.0, 1.0)
	var swing := sin(TAU * phase)
	# The pelvis: a bob twice a step, a twist with the stride; the chest leaning into the walk and the climb, breathing.
	var bob := 0.04 * cos(TAU * phase * 2.0) * walking
	var pelvis := Vector3(0.0, GROUND_Y + HIP_H + bob - 0.05 * climb, 0.0)
	var lean := LEAN_WALK * walking + LEAN_CLIMB * climb
	var breathe := 0.014 * sin(time * 1.7)
	var hips := Basis(Vector3.UP, 0.08 * swing * walking)
	var chest := Basis(Vector3.UP, -0.1 * swing * walking) * Basis(Vector3.RIGHT, -lean)
	var up := chest * Vector3.UP
	var right := chest * Vector3.RIGHT
	var back := chest * Vector3.BACK
	for i in COLUMN.size():
		var basis := hips if i == 0 else chest
		var at: Vector3 = pelvis + (basis * Vector3.UP) * COLUMN[i][0] + (Vector3.UP * breathe if i == COLUMN.size() - 1 else Vector3.ZERO)
		orient(_column[i], at, basis * Vector3.UP, COLUMN[i][2], COLUMN[i][1], COLUMN[i][1] * 0.72)
	orient(_waist_rings[0], pelvis + up * 0.105, up, 0.06, 0.4)
	orient(_waist_rings[1], pelvis + up * 0.31, up, 0.06, 0.46)
	var chest_c: Vector3 = pelvis + up * COLUMN[3][0] + Vector3.UP * breathe
	# The breastplate over the chest's front, the two plates in a V over it, the heart's light between them.
	lay(_breast, chest_c - back * 0.31 + up * 0.02, plank(right, up) * Basis.from_scale(Vector3(0.56, 0.08, 0.44)))
	for side in 2:
		var s := -1.0 if side == 0 else 1.0
		var across := (right * s + up * -0.4).normalized()
		lay(_pecs[side], chest_c + right * (0.2 * s) - back * 0.36 + up * 0.08, plank(across, (up - back * 0.3).normalized()) * Basis.from_scale(Vector3(0.3, 0.07, 0.32)))
	var heart_glow := 0.5 + 0.5 * pow(0.5 + 0.5 * cos(TAU * (phase * 2.0 if walking > 0.1 else time * 0.6)), 3.0)
	orient(_heart, chest_c - back * 0.47 + up * 0.05, back, HEART_R * (1.0 + 0.2 * heart_glow), HEART_R)
	brighten(_heart, 0.4 + 0.35 * heart_glow)
	# The spines down its back, raked back.
	for i in SPINES.size():
		var root: Vector3 = pelvis + up * SPINES[i][0] + back * 0.26
		var way: Vector3 = (up + back * SPINES[i][2]).normalized()
		bone(_spines[i], root, root + way * SPINES[i][1], 0.12)
	# The shoulders and the arms: long, hanging a little ahead, swinging against the legs, three claws curled in.
	var shoulder_c := pelvis + up * SHOULDER_UP + Vector3.UP * breathe
	for side in 2:
		var s := -1.0 if side == 0 else 1.0
		var shoulder := shoulder_c + right * (SHOULDER_X * s)
		var slant := plank((right * s + up * -0.7).normalized(), back)
		lay(_pauldrons[side * 2], shoulder + up * 0.12 + right * (0.05 * s), slant * Basis.from_scale(Vector3(0.44, 0.11, 0.5)))
		lay(_pauldrons[side * 2 + 1], shoulder + up * 0.02 + right * (0.16 * s), plank((right * s + up * -1.4).normalized(), back) * Basis.from_scale(Vector3(0.3, 0.09, 0.42)))
		var arm_swing := -0.35 * swing * walking * (1.0 if side == 0 else -1.0)
		var reach_out := 0.12 + 0.06 * sin(time * 0.9 + side)
		var upper_dir := (Basis(right, arm_swing + reach_out) * (Vector3.DOWN + right * (0.14 * s))).normalized()
		var elbow := shoulder + upper_dir * UPPER
		var fore_dir := (Basis(right, arm_swing + reach_out + 0.35) * (Vector3.DOWN + right * (0.05 * s))).normalized()
		var hand := elbow + fore_dir * FORE
		bone(_uppers[side], shoulder, elbow, 0.2)
		bone(_fores[side], elbow, hand, 0.17)
		orient(_elbows[side], elbow, (upper_dir + fore_dir).normalized(), 0.07, 0.19)
		var outward := (right * s - fore_dir * fore_dir.dot(right * s)).normalized()
		lay(_bracers[side], elbow.lerp(hand, 0.5) + outward * 0.06, plank(outward.cross(fore_dir).normalized(), fore_dir) * Basis.from_scale(Vector3(0.16, 0.06, 0.42)))
		var curl := 0.5 + 0.15 * sin(time * 2.3 + side * 1.7)
		for f in 3:
			var spread := (float(f) - 1.0) * 0.34
			var claw := (Basis(fore_dir, spread) * Basis(right, curl) * fore_dir).normalized()
			bone(_claws[side * 3 + f], hand, hand + claw * CLAW, 0.06)
	# The legs: each foot where the gait puts it (on the slope; the beat stops it on a whole step, so standing it keeps
	# its last stride, its left foot ahead), the knee bent ahead between hip and ankle.
	for side in 2:
		var s := -1.0 if side == 0 else 1.0
		var hip := pelvis + (hips * Vector3.RIGHT) * (HIP_X * s) + Vector3.DOWN * 0.06
		var foot := foot_at(side, phase, slope)
		var knee := _knee(hip, foot, THIGH, SHIN)
		bone(_thighs[side], hip, knee, 0.27)
		var thigh_dir := (knee - hip).normalized()
		lay(_cuisses[side], hip.lerp(knee, 0.45) + Vector3.FORWARD * 0.13 + (hips * Vector3.RIGHT) * (0.03 * s), plank(hips * Vector3.RIGHT, thigh_dir) * Basis.from_scale(Vector3(0.3, 0.08, 0.5)))
		bone(_shins[side], knee, foot, 0.2)
		var shin_dir := (foot - knee).normalized()
		orient(_knees[side], knee, ((knee - hip).normalized() + shin_dir).normalized(), 0.08, 0.24)
		lay(_guards[side], knee.lerp(foot, 0.4) + Vector3.FORWARD * 0.1, plank(hips * Vector3.RIGHT, shin_dir) * Basis.from_scale(Vector3(0.22, 0.07, 0.44)))
		var ahead := Vector3(0.0, slope, -1.0).normalized()
		lay(_feet[side], foot + Vector3(0.0, -ANKLE_H * 0.55, 0.0) + ahead * 0.08, plank(Vector3.RIGHT, -ahead) * Basis.from_scale(Vector3(0.24, 0.09, 0.44)))
	# The neck and the head: the hexagon's face looking along gaze, tilted, the prompt on it, the crown behind.
	var neck_from := pelvis + up * NECK_FROM
	var neck_to := pelvis + up * NECK_TO
	bone(_neck, neck_from, neck_to, 0.16)
	orient(_neck_ring, neck_from.lerp(neck_to, 0.4), up, 0.05, 0.19)
	var head := pelvis + up * HEAD_UP
	var f := gaze.normalized() if gaze.length_squared() > 0.0001 else Vector3.FORWARD
	var r := f.cross(Vector3.UP)
	r = r.normalized() if r.length_squared() > 0.0001 else Vector3.RIGHT
	var u := r.cross(f).normalized()
	var turned := Basis(f, tilt)
	r = turned * r
	u = turned * u
	lay(_face, head, Basis(u * FACE_R * 2.0, f * FACE_T, -r * FACE_R * 2.0))
	lay(_face_back, head - f * (FACE_T * 0.95), Basis(u * FACE_R * 1.7, f * FACE_T * 1.3, -r * FACE_R * 1.7))
	var front := head + f * (FACE_T * 0.5 + 0.014)
	var blink := 1.0 if fposmod(time * BLINK_HZ, 1.0) < 0.55 else 0.0
	_stroke(_cursor, front, r, u, f, CURSOR[0], CURSOR[1])
	brighten(_cursor, GLYPH_GLOW * blink)
	_stroke(_chevron[0], front, r, u, f, CHEVRON[0], CHEVRON[1])
	_stroke(_chevron[1], front, r, u, f, CHEVRON[1], CHEVRON[2])
	for id in _chevron:
		brighten(id, GLYPH_GLOW)
	# The crown: the brand's hexagon ring of six bars, a gap at the start of each side, turning slowly.
	var crown_c := head - f * CROWN_BACK
	var spin := time * CROWN_TURN
	for k in 6:
		var a0 := PI / 2.0 - TAU * k / 6.0 - spin
		var a1 := a0 - TAU / 6.0
		var c0 := crown_c + (u * sin(a0) - r * cos(a0)) * CROWN_R
		var c1 := crown_c + (u * sin(a1) - r * cos(a1)) * CROWN_R
		bone(_crown[k], c0.lerp(c1, 0.16), c0.lerp(c1, 1.04), 0.06)
		brighten(_crown[k], 0.9)
	_form()


## A stroke of the prompt from `a` to `b` (the player's view: x right, y up) on the face at `front`.
func _stroke(id: int, front: Vector3, r: Vector3, u: Vector3, f: Vector3, a: Vector2, b: Vector2) -> void:
	var pa := front - r * a.x + u * a.y
	var pb := front - r * b.x + u * b.y
	orient(id, (pa + pb) * 0.5, pb - pa, pa.distance_to(pb) + STROKE, STROKE, 0.02, f)


## The knee of a two-bone leg from `hip` to `foot`, bent ahead (-Z), its bones `a` and `b` long.
static func _knee(hip: Vector3, foot: Vector3, a: float, b: float) -> Vector3:
	var span := foot - hip
	var d := clampf(span.length(), 0.05, (a + b) * 0.999)
	var dir := span.normalized()
	var x := (a * a - b * b + d * d) / (2.0 * d)
	var h := sqrt(maxf(a * a - x * x, 0.0))
	var bend := Vector3.FORWARD - dir * Vector3.FORWARD.dot(dir)
	bend = bend.normalized() if bend.length_squared() > 0.0001 else Vector3.FORWARD
	return hip + dir * x + bend * h


## Every part whole above form_y and breaking into cells below it (it forms as it climbs through the pit's rim).
func _form() -> void:
	for id in part_count() - SPRAY:
		var y := part_transform(id).origin.y
		present(id, clampf((y - form_y + 0.15) / 0.6, 0.0, 1.0))
	if glyphs() != null:
		glyphs().visible = form_y < GROUND_Y


## Its footfalls from walk 0 to `total_m` metres: where each foot lands in art space as it lands, at walk distance d,
## with which side. The first two are where it stands at the start (its left ahead, its right behind).
static func footfalls(total_m: float) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"d": 0.0, "side": 0, "at": Vector3(-HIP_X, 0.0, -STRIDE * 0.5)})
	out.append({"d": 0.0, "side": 1, "at": Vector3(HIP_X, 0.0, STRIDE * 0.5)})
	var k := 1
	while k * STRIDE <= total_m + 0.001:
		# A whole number of steps: odd ones the right foot's landing, even ones the left's.
		out.append({"d": k * STRIDE, "side": k % 2, "at": Vector3(HIP_X * (1.0 if k % 2 == 1 else -1.0), 0.0, -STRIDE * 0.5)})
		k += 1
	return out
