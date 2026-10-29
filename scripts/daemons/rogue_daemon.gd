extends DaemonArt
## The rogue daemon (A2b, armoured in A5; the "rogue.d" dummy): a black mantis-scorpion. A solid body
## of near-black armour: a flat hexagonal thorax under overlapping dorsal plates, a scorpion's tail of
## ribbed hex segments curling up over its back to a stinger, a low wedge of a head with one horizontal visor slit, two scythe
## arms folded in front, six thick jointed legs. Its light is crimson and only in its seams: a band
## between each tail segment, the knees, the elbows and wrists, the visor, the stinger's bulb (its
## weak points, weak()). Faceless: the visor is a slit of light, no eye.
##
## No two alike (A5): its seed sets its size, how many dorsal plates and tail segments it has, the
## length and hook of its scythes, its visor's width, its legs' thickness and spread, how low it
## crouches, its gait's timing, its battle damage (a chipped and scorched plate or two, a seam or
## three flickering) and, one in twelve, an elite: bigger, a second, smaller pair of scythes under the
## first, a crown of horns, a crimson seam down its back.
##
## It skitters: the body glides on a seeded loop round its spot, darting and pausing, turning as it
## goes, and the legs step to keep up, IK-style: each foot stays planted on the ground until the
## body has carried its home too far from it, then lifts and arcs to where its home will be, in an
## alternating tripod gait (three legs swinging while the other three hold). It crouches low; every
## few seconds, and at once when it is hit, it rears up tall before it strikes: the front of the body
## pitches up, the front legs lift off the ground, the scythes open high, the tail curls tight, the
## visor flares, it trembles, then lunges and slashes down and settles. The tail sways; now and then
## a leg fidgets a step. Visual only: it never leaves its spot (the hit volume), and the strike hits
## nothing.
##
## Fighting back (C27b), its brain drives it: it hunts on its legs (the body stops gliding and
## wandering and faces its prey, the feet stay planted in the world as the daemon moves and step
## to catch up), the rear-up is its tell (the visor burning brighter as it rises), then the lunge and
## the slash are its strike and it settles. Only practice, or no brain, keeps the threat display on
## its own clock. Its hit volume beyond the cylinder is the box round its body, head to tail
## (body_box()).

const LEGS := 6
## Each walking leg's hip on the thorax and its foot's home on the ground round the body (body
## space: +X right, -Z ahead, metres), and its tripod: legs of one tripod step together.
const HIPS := [Vector3(-0.22, -0.02, -0.22), Vector3(0.22, -0.02, -0.22), Vector3(-0.27, -0.04, 0.0), Vector3(0.27, -0.04, 0.0), Vector3(-0.22, -0.02, 0.22), Vector3(0.22, -0.02, 0.22)]
const HOMES := [Vector2(-0.84, -0.84), Vector2(0.84, -0.84), Vector2(-1.14, 0.05), Vector2(1.14, 0.05), Vector2(-0.88, 0.88), Vector2(0.88, 0.88)]
const TRIPOD := [0, 1, 1, 0, 0, 1]
## The leg's upper and lower lengths, in metres.
const FEMUR := 0.8
const TIBIA := 1.0
## The thorax's height above the ground (low: it crouches), and how far the body glides from its
## spot (x, z), in metres; how hard the skitter darts and pauses (0 steady, 1 stopping dead) and its
## period.
const BODY_H := 0.78
const GLIDE := Vector2(0.3, 0.22)
const SKITTER := 0.88
const SKITTER_S := 2.4
## A step: how far a foot may be from its home before it lifts, how long it swings, how high, and
## how far ahead of the moving home it lands, in seconds of the home's motion.
const STEP_AT := 0.24
const SWING_S := 0.16
const STEP_H := 0.2
const LEAD_S := 0.12
## The threat display: once every DISPLAY_EVERY seconds (and at a hit), DISPLAY_S long; how far
## the front pitches up (radians) about the pivot, how much the body lifts (it rears tall), how far
## it lunges.
const DISPLAY_EVERY := 6.0
const DISPLAY_S := 1.8
const REAR_PITCH := 0.72
const PIVOT := Vector3(0.0, 0.0, 0.3)
const LIFT := 0.38
const LUNGE := 0.28
## A ping's stagger (C28), at its start: how far the body drops, how far the front pitches down and
## rolls each way (radians), and how far it shudders side to side.
const STAGGER_DROP_M := 0.2
const STAGGER_PITCH := 0.35
const STAGGER_ROLL := 0.22
const STAGGER_SHAKE_M := 0.06
## The box round its body for a shot (C27b): head to tail, in body space (its centre) and its size.
const BOX_AT := Vector3(0.0, 0.12, 0.2)
const BOX_SIZE := Vector3(0.9, 1.0, 2.5)
## Where the scythes come down in the strike, in body space.
const STRIKE_AT := Vector3(0.0, -0.35, -1.25)
## The thorax plate (across, thick, long), the dorsal plates' run along the back, and the tail: the
## first segment's size (across, thick, long), how much smaller each next one is, how far each turns
## up from the one before (radians), more as it rears.
const THORAX := Vector3(0.86, 0.4, 0.92)
const DORSAL_FROM := -0.34
const DORSAL_TO := 0.3
const TAIL_FIRST := Vector3(0.42, 0.3, 0.3)
const TAIL_SHRINK := 0.09
const TAIL_CURL := 0.44
const TAIL_CURL_REAR := 0.14
## The visor's brightness at rest and its flare at the top of a rear.
const VISOR_GLOW := 1.1
const VISOR_FLARE := 2.6
## A leg fidgets a step once every FIDGET_EVERY seconds.
const FIDGET_EVERY := 2.0

var _thorax: int
var _dorsal := PackedInt32Array()
var _spine_seam := -1
var _tail := PackedInt32Array()
var _tail_seam := PackedInt32Array()
var _sting: int
var _bulb: int
var _neck: int
var _neck_seam: int
var _head: int
var _visor: int
var _horns := PackedInt32Array()
var _femur := PackedInt32Array()
var _tibia := PackedInt32Array()
var _knee := PackedInt32Array()
## The scythes: each pair's upper arms, elbows, blades and wrists (the elite's second pair after the
## first).
var _arm := PackedInt32Array()
var _elbow := PackedInt32Array()
var _scythe := PackedInt32Array()
var _wrist := PackedInt32Array()

## Its build (A5): how many dorsal plates and tail segments, its scythes' length and hook, its
## visor's width, its legs' thickness and spread, its crouch, its gait's pace.
var _plates := 3
var _segments := 6
var _scythe_l := 1.0
var _hook := 0.0
var _visor_w := 0.26
var _leg_w := 1.0
var _spread := 1.0
var _crouch := 1.0
var _swing_s := SWING_S
var _step_at := STEP_AT

## The feet: where each is (art space), where a swing started and will land, when it lifted (-1
## planted), its home a frame ago, and how many steps it has finished.
var _foot := PackedVector3Array()
var _from := PackedVector3Array()
var _to := PackedVector3Array()
var _lift_at := PackedFloat32Array()
var _home_last := PackedVector3Array()
var _steps := PackedInt32Array()
var _feet_ready := false
var _fidget_n := -1
## A display a hit started, on the clock (-1 none).
var _forced_at := -1.0
## The seeded phases of its loop, its turning, its display and its tail.
var _p := PackedFloat32Array()
## The rear and the strike as last posed, for the checks.
var _rear := 0.0
var _strike := 0.0
## The body's turn and its centre as last posed (art space), for the box and the strike.
var _turn := Basis.IDENTITY
var _centre := Vector3.ZERO


func _build() -> void:
	ai_kind = "rogue"
	core_color = Palette.CRIMSON
	edge_color = Palette.CRIMSON
	glyph_count = 6
	glyph_radius = 1.3
	glyph_low = -0.3
	glyph_high = 1.3
	glyph_size = 0.13
	glyph_turns = 0.05
	reach = AABB(Vector3(-2.4, -1.0, -2.6), Vector3(4.8, 3.8, 5.2))
	tag_height = 2.75
	budget_triangles = 4200
	budget_draw_calls = 16
	size_low = 0.88
	size_high = 1.08
	elite_size = 1.18
	for i in 6:
		_p.append(TAU * dice(i, 0))
	# The build's rolls (A5).
	_plates = pick(20, 0, 2, 4)
	_segments = pick(21, 0, 5, 7)
	_scythe_l = lerpf(0.9, 1.15, dice(22, 0))
	_hook = lerpf(-0.15, 0.25, dice(23, 0))
	_visor_w = lerpf(0.2, 0.3, dice(24, 0))
	_leg_w = lerpf(0.88, 1.15, dice(25, 0))
	_spread = lerpf(0.94, 1.06, dice(26, 0))
	_crouch = lerpf(0.9, 1.08, dice(27, 0))
	_swing_s = SWING_S * lerpf(0.92, 1.06, dice(28, 0))
	_step_at = STEP_AT * lerpf(0.94, 1.08, dice(29, 0))
	if elite:
		_plates = 4
		_segments = 7
	_thorax = part(Shape.HEX, Look.ARMOR)
	for i in _plates:
		_dorsal.append(part(Shape.PLATE, Look.ARMOR))
	if elite:
		_spine_seam = weak(seam(part(Shape.CUBE, Look.CORE)))
	for i in _segments:
		_tail.append(part(Shape.HEX, Look.ARMOR))
		_tail_seam.append(weak(seam(part(Shape.RING, Look.CORE))))
	_sting = part(Shape.SHARD, Look.ARMOR)
	_bulb = weak(part(Shape.GEM, Look.CORE))
	_neck = part(Shape.LIMB, Look.ARMOR)
	_neck_seam = weak(seam(part(Shape.RING, Look.CORE)))
	_head = part(Shape.PLATE, Look.ARMOR)
	_visor = weak(part(Shape.CUBE, Look.CORE))
	var horns := 3 if elite else pick(30, 0, 0, 2)
	for i in horns:
		_horns.append(part(Shape.SHARD, Look.ARMOR))
	for i in LEGS:
		_femur.append(part(Shape.LIMB, Look.ARMOR))
		_tibia.append(part(Shape.LIMB, Look.ARMOR))
		_knee.append(weak(seam(part(Shape.RING, Look.CORE))))
	for i in (4 if elite else 2):
		_arm.append(part(Shape.LIMB, Look.ARMOR))
		_elbow.append(weak(seam(part(Shape.RING, Look.CORE))))
		_scythe.append(part(Shape.BLADE, Look.ARMOR))
		_wrist.append(weak(seam(part(Shape.RING, Look.CORE))))
	# Battle damage (A5): a plate or two chipped and scorched, a seam or three flickering.
	var armour: Array[int] = [_thorax]
	armour.append_array(_dorsal)
	armour.append_array(_tail)
	for i in pick(31, 0, 0, 2):
		scorch(armour[pick(32, i, 0, armour.size() - 1)], lerpf(0.5, 1.0, dice(33, i)))
	var seams: Array[int] = []
	seams.append_array(_tail_seam)
	seams.append_array(_knee)
	seams.append_array(_elbow)
	for i in pick(34, 0, 0, 3):
		flicker(seams[pick(35, i, 0, seams.size() - 1)], lerpf(0.3, 0.8, dice(36, i)))
	for i in LEGS:
		_foot.append(Vector3.ZERO)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
		_lift_at.append(-1.0)
		_home_last.append(Vector3.ZERO)
		_steps.append(0)


func _pose(t: float, delta: float) -> void:
	var s := t + SKITTER * sin(TAU * t / SKITTER_S) * SKITTER_S / TAU
	if act == Act.IDLE and displays:
		_display_now(t)
	else:
		_act_now()
	var rear := _rear
	var strike := _strike
	# Driven, it stops wandering and faces its prey (the daemon's own -Z), and stops gliding round
	# its spot: the daemon itself moves.
	var idle := 1.0 - _drive
	var yaw := (_p[0] + 0.85 * sin(0.31 * t + _p[3]) + 0.35 * sin(0.9 * s)) * idle
	var turn := Basis(Vector3.UP, yaw)
	var breath := sin(TAU * 0.55 * t + _p[1])
	# A ping's stagger (C28): it cowers low, head down, shuddering side to side, never a rear-up.
	var reel := staggered()
	var tremble := sin(t * 61.0) * (0.014 + 0.02 * _drive) * rear * (1.0 - strike) + sin(t * 43.0) * STAGGER_SHAKE_M * reel
	var centre := Vector3(GLIDE.x * sin(1.25 * s + _p[1]) * idle + tremble, GROUND_Y + BODY_H * _crouch + 0.02 * breath + LIFT * rear - STAGGER_DROP_M * reel, GLIDE.y * sin(0.83 * s + _p[2]) * idle)
	centre += turn * Vector3.FORWARD * (LUNGE * strike) + recoil()
	_turn = turn
	_centre = centre
	var pitch := REAR_PITCH * rear * (1.0 - 0.7 * strike) - 0.25 * strike + 0.3 * jolt() - STAGGER_PITCH * reel
	var roll := sin(t * 29.0) * STAGGER_ROLL * reel
	var body := turn * Basis(Vector3.FORWARD, roll) * Basis(Vector3.RIGHT, pitch)
	var xf := Transform3D(body, centre + turn * PIVOT - body * PIVOT)
	var right := body * Vector3.RIGHT
	# The thorax and the dorsal plates over it, overlapping front to back like a carapace, breathing.
	lay(_thorax, xf * Vector3(0.0, 0.0, -0.04), body * Basis.from_scale(THORAX * Vector3(1.0, 1.0 + 0.03 * breath, 1.0)))
	for i in _plates:
		var u := (i + 0.5) / _plates
		var z := lerpf(DORSAL_FROM, DORSAL_TO, u)
		var w := THORAX.x * lerpf(0.82, 0.62, u)
		var tilt := Basis(Vector3.RIGHT, -0.16 + 0.05 * sin(2.0 * t + i))
		lay(_dorsal[i], xf * Vector3(0.0, 0.2 + 0.02 * i, z), body * tilt * Basis.from_scale(Vector3(w, 0.14, (DORSAL_TO - DORSAL_FROM) / _plates * 1.35)))
	if _spine_seam >= 0:
		lay(_spine_seam, xf * Vector3(0.0, 0.25 + 0.02 * _plates, (DORSAL_FROM + DORSAL_TO) * 0.5), body * Basis.from_scale(Vector3(0.025, 0.02, DORSAL_TO - DORSAL_FROM)))
	_pose_tail(t, xf, body, rear)
	# The neck, a crimson seam round it, and the head: a low faceless wedge, ahead and down, its visor
	# slit across its front burning brighter as it rears; it jerks now and then.
	var neck_from := Vector3(0.0, 0.04, -0.36)
	var neck_to := Vector3(0.0, 0.18 + 0.14 * rear, -0.66)
	bone(_neck, xf * neck_from, xf * neck_to, 0.2)
	orient(_neck_seam, xf * neck_from.lerp(neck_to, 0.5), body * (neck_to - neck_from), 0.06, 0.2)
	var jerk := _jerk(t)
	var head_way := (Vector3(jerk, -0.3 + 0.32 * rear, -1.0)).normalized()
	var head_at := neck_to + head_way * 0.14
	var back := body * -head_way
	var head_frame := plank(right, back)
	lay(_head, xf * head_at, head_frame * Basis.from_scale(Vector3(0.36, 0.2, 0.4)))
	lay(_visor, xf * head_at + head_frame * Vector3(0.0, 0.02, -0.2), head_frame * Basis.from_scale(Vector3(_visor_w, 0.035, 0.03)))
	brighten(_visor, VISOR_GLOW + (VISOR_FLARE - VISOR_GLOW) * rear * (1.0 - strike))
	for i in _horns.size():
		var x := (i - (_horns.size() - 1) * 0.5) * 0.12
		var root := xf * head_at + head_frame * Vector3(x, 0.09, 0.08)
		bone(_horns[i], root, root + head_frame * Vector3(x * 0.8, 0.22 + 0.05 * (1 - absf(x) * 6.0), 0.28), 0.06)
	_pose_scythes(t, xf, body, rear, strike, reel)
	_pose_legs(t, delta, xf, turn, centre, rear)


## The tail: segments of armour on a curve that rises from the back of the thorax and curls up and
## over the body, each a little smaller, a crimson seam band between each and the next; the stinger
## at its end and the crimson bulb at the stinger's root. It sways side to side and curls tighter as
## it rears.
func _pose_tail(t: float, xf: Transform3D, body: Basis, rear: float) -> void:
	var at := Vector3(0.0, 0.05, THORAX.z * 0.5 - 0.06)
	var angle := 0.32
	var sway := 0.12 * sin(1.3 * t + _p[5])
	var size := TAIL_FIRST
	for k in _segments:
		var way := Vector3(sin(sway * (k + 1) * 0.3), sin(angle), cos(angle)).normalized()
		var mid := at + way * size.z * 0.5
		var up := way.cross(Vector3.RIGHT).normalized()
		# A ribbed hex segment, its axis along the tail (right-handed: across, along, under).
		var frame := Basis(Vector3.RIGHT, way, -up).orthonormalized()
		lay(_tail[k], xf * mid, body * frame * Basis.from_scale(Vector3(size.x, size.z, size.y)))
		orient(_tail_seam[k], xf * (at + way * 0.01), body * way, 0.05, size.x * 0.82)
		at = mid + way * (size.z * 0.5 + 0.035)
		size *= 1.0 - TAIL_SHRINK
		angle += TAIL_CURL + TAIL_CURL_REAR * rear + 0.04 * sin(1.7 * t + k)
	var sting_way := Vector3(0.0, sin(angle + 0.3), cos(angle + 0.3)).normalized()
	orient(_bulb, xf * at, body * sting_way, 0.16, 0.13)
	brighten(_bulb, 1.2 + 0.6 * rear)
	bone(_sting, xf * at, xf * (at + sting_way * 0.32), 0.08)


## The scythe arms: folded in prayer at rest, raised high and open in the display, slashing down at
## the strike, thrown out to the sides in a stagger; the elite's second pair lower and shorter, a
## beat behind. Each: an upper arm, a crimson elbow, the blade, a crimson wrist where it joins.
func _pose_scythes(t: float, xf: Transform3D, body: Basis, rear: float, strike: float, reel: float) -> void:
	for k in _arm.size():
		var side := k % 2
		var pair := k / 2
		var x := -1.0 if side == 0 else 1.0
		var low := 0.14 * pair
		var shoulder := Vector3(0.14 * x, 0.12 - low, -0.5 + 0.08 * pair)
		var r := rear * (1.0 - strike) * (1.0 - 0.3 * pair)
		var sway := 0.06 * sin(1.7 * t + side * 1.3 + pair)
		var d1 := Vector3(0.18 * x, -0.05 + sway, -1.0).lerp(Vector3(0.55 * x, 1.1, -0.45), r).lerp(Vector3(0.08 * x, -0.55, -1.0), strike).lerp(Vector3(0.9 * x, -0.3, -0.35), reel).normalized()
		var length := (0.56 - 0.12 * pair) * _scythe_l
		var elbow := shoulder + d1 * length
		var d2 := Vector3(0.0, -0.75, 0.65 + _hook).lerp(Vector3(0.25 * x, 0.25, -1.0), r).lerp(Vector3(0.0, -1.0, -0.25), strike).normalized()
		var tip := elbow + d2 * (0.82 - 0.18 * pair) * _scythe_l
		bone(_arm[k], xf * shoulder, xf * elbow, 0.11 - 0.02 * pair)
		orient(_elbow[k], xf * elbow, body * d1, 0.05, 0.12 - 0.02 * pair)
		# The blade's spine to the outside and up, its edge to the inside: it cuts as it comes down.
		var spine := (body * Vector3(x, 0.6, 0.0)).normalized()
		bone(_scythe[k], xf * elbow, xf * tip, 0.08 - 0.01 * pair, 0.27 - 0.04 * pair, spine)
		orient(_wrist[k], xf * (elbow + d2 * 0.04), body * d2, 0.04, 0.1 - 0.02 * pair)


## The legs: the hips ride the body, the feet plant and step (see the header), the knees bend up
## and out by two-bone IK; the front pair lift off the ground while it rears. Thick armoured limbs,
## a crimson band at each knee.
func _pose_legs(t: float, delta: float, xf: Transform3D, turn: Basis, centre: Vector3, rear: float) -> void:
	var ground := Vector3(centre.x, GROUND_Y, centre.z)
	# Planted feet stay put in the world while the daemon moves under them (C27b).
	if _feet_ready and _carry != Transform3D.IDENTITY:
		for i in LEGS:
			_foot[i] = _carry * _foot[i]
			_from[i] = _carry * _from[i]
			_to[i] = _carry * _to[i]
			_home_last[i] = _carry * _home_last[i]
			_foot[i].y = GROUND_Y
			_to[i].y = GROUND_Y
	if not _feet_ready:
		for i in LEGS:
			var h: Vector2 = HOMES[i]
			_foot[i] = ground + turn * Vector3(h.x * _spread, 0.0, h.y * _spread)
			_home_last[i] = _foot[i]
			_lift_at[i] = -1.0
		_feet_ready = true
	var fidget := int(floor(t / FIDGET_EVERY))
	var fidget_leg := int(dice(fidget, 5) * LEGS) if fidget != _fidget_n else -1
	_fidget_n = fidget
	for i in LEGS:
		var h: Vector2 = HOMES[i]
		var home := ground + turn * Vector3(h.x * _spread, 0.0, h.y * _spread)
		var moving := (home - _home_last[i]) / delta if delta > 0.0 else Vector3.ZERO
		_home_last[i] = home
		var lifted := i < 2 and rear > 0.25
		if _lift_at[i] >= 0.0:
			if since(_lift_at[i]) >= _swing_s:
				_foot[i] = _to[i]
				_lift_at[i] = -1.0
				_steps[i] += 1
		elif delta > 0.0 and not lifted:
			var off := _foot[i].distance_to(home)
			var group: int = TRIPOD[i]
			var free := not _swinging(1 - group)
			if (off > _step_at and (free or off > _step_at * 2.2)) or (i == fidget_leg and free):
				_from[i] = _foot[i]
				var land := home + moving * LEAD_S
				if i == fidget_leg and off <= _step_at:
					land += turn * Vector3(0.12 * (dice(fidget, 6) - 0.5), 0.0, 0.12 * (dice(fidget, 7) - 0.5))
				land.y = GROUND_Y
				_to[i] = land
				_lift_at[i] = t
		var foot := _foot[i]
		if _lift_at[i] >= 0.0:
			var u := clampf(since(_lift_at[i]) / _swing_s, 0.0, 1.0)
			foot = _from[i].lerp(_to[i], smoothstep(0.0, 1.0, u)) + Vector3.UP * (STEP_H * sin(PI * u))
		if i < 2 and rear > 0.0:
			var x := -1.0 if i == 0 else 1.0
			var raised := xf * Vector3(0.55 * x, -0.1, -1.15)
			foot = foot.lerp(raised, smoothstep(0.25, 0.65, rear))
		var hip := xf * (HIPS[i] as Vector3)
		var out := hip - centre
		out.y = 0.0
		var reached := hip + (foot - hip).limit_length(FEMUR + TIBIA - 0.002)
		var knee := _knee_at(hip, reached, Vector3.UP + out.normalized() * 0.35)
		bone(_femur[i], hip, knee, 0.19 * _leg_w)
		bone(_tibia[i], knee, reached, 0.15 * _leg_w)
		orient(_knee[i], knee, knee - hip, 0.06, 0.19 * _leg_w)


func _on_hit() -> void:
	# A hit makes it rear up at once, unless it already is; never while its brain drives it, when
	# a rear-up is only ever its tell (C27b).
	if act == Act.IDLE and displays and since(_forced_at) >= DISPLAY_S and _rear < 0.05:
		_forced_at = _clock


func _on_return() -> void:
	_feet_ready = false
	_forced_at = -1.0


## The display now: how far it rears and how hard it strikes, from 0 to 1.
func _display_now(t: float) -> void:
	var tau := since(_forced_at)
	if tau >= DISPLAY_S:
		tau = fposmod(t - _p[4] / TAU * DISPLAY_EVERY, DISPLAY_EVERY)
	if tau >= DISPLAY_S:
		_rear = 0.0
		_strike = 0.0
		return
	_rear = smoothstep(0.0, 0.4, tau) * (1.0 - smoothstep(1.15, 1.8, tau))
	_strike = smoothstep(1.0, 1.1, tau) * (1.0 - smoothstep(1.15, 1.6, tau))


## The rear and the strike from the brain's act (C27b): the tell rears it up and holds it there
## trembling, the strike lunges and slashes down, the recovery settles it.
func _act_now() -> void:
	match act:
		Act.TELL:
			_rear = smoothstep(0.0, 0.7, act_u)
			_strike = 0.0
		Act.STRIKE:
			_rear = 1.0
			_strike = smoothstep(0.0, 0.5, act_u)
		Act.RECOVER:
			_rear = 1.0 - smoothstep(0.0, 1.0, act_u)
			_strike = 1.0 - smoothstep(0.0, 0.6, act_u)
		_:
			_rear = move_toward(_rear, 0.0, 0.08)
			_strike = move_toward(_strike, 0.0, 0.08)


func _muzzle() -> Vector3:
	return Transform3D(_turn, _centre) * STRIKE_AT


func body_box() -> Transform3D:
	return Transform3D(_turn, _centre + _turn * BOX_AT)


func body_box_size() -> Vector3:
	return BOX_SIZE


## The head's jerk now: a sharp sideways twitch every 0.7 s or so, sometimes.
func _jerk(t: float) -> float:
	var n := int(floor(t / 0.7))
	var tau := t - n * 0.7
	if dice(n, 8) < 0.5:
		return 0.0
	return (dice(n, 9) - 0.5) * 0.9 * exp(-tau * 14.0)


func _swinging(group: int) -> bool:
	for i in LEGS:
		if _lift_at[i] >= 0.0 and TRIPOD[i] == group:
			return true
	return false


## Where the knee goes for a leg from `hip` to `foot`: two-bone IK, bending toward `pole`.
static func _knee_at(hip: Vector3, foot: Vector3, pole: Vector3) -> Vector3:
	var span := foot - hip
	var d := clampf(span.length(), absf(FEMUR - TIBIA) + 0.001, FEMUR + TIBIA - 0.001)
	var dir := span.normalized() if span.length_squared() > 0.000001 else Vector3.DOWN
	var x := (FEMUR * FEMUR - TIBIA * TIBIA + d * d) / (2.0 * d)
	var h := sqrt(maxf(FEMUR * FEMUR - x * x, 0.0))
	var side := pole - dir * pole.dot(dir)
	if side.length_squared() < 0.000001:
		side = Vector3.UP - dir * dir.y
	return hip + dir * x + side.normalized() * h


# --- For the checks. ---

## Where each foot is drawn now (art space).
func feet() -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in LEGS:
		out.append(part_transform(_tibia[i]).origin + part_transform(_tibia[i]).basis.y)
	return out


## Whether each foot is planted now.
func planted() -> Array[bool]:
	var out: Array[bool] = []
	for i in LEGS:
		out.append(_lift_at[i] < 0.0 and not (i < 2 and _rear > 0.25))
	return out


## Whether each foot is in a step's swing now (a rearing front leg held up is not).
func swinging() -> Array[bool]:
	var out: Array[bool] = []
	for i in LEGS:
		out.append(_lift_at[i] >= 0.0)
	return out


## Steps each leg has finished.
func steps() -> PackedInt32Array:
	return _steps


func tripods() -> Array:
	return TRIPOD


func rear() -> float:
	return _rear


## The thorax's centre now (art space): where the body glides.
func body_at() -> Vector3:
	return part_transform(_thorax).origin


## The visor's brightness now (A5): it flares as the rogue rears in its tell.
func visor_glow() -> float:
	return part_custom(_visor).g


## Its build, for the checks (A5): dorsal plates, tail segments, scythes, horns.
func build_counts() -> Vector4i:
	return Vector4i(_plates, _segments, _arm.size(), _horns.size())
