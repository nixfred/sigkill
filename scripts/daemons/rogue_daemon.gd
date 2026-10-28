extends DaemonArt
## The rogue daemon (A2b, the "rogue.d" dummy): a crystal-shard spider-mantis. Six jointed obsidian
## legs, their knees burning red, carry a segmented body (a thorax, a three-gem abdomen with a red
## heart glowing through its gaps and a tail spike, a long prothorax with a faceless wedge of a
## head); two scythe arms fold in front of it; six burning shards stand along its back.
##
## It skitters: the body glides on a seeded loop round its spot, darting and pausing, turning as it
## goes, and the legs step to keep up, IK-style: each foot stays planted on the ground until the
## body has carried its home too far from it, then lifts and arcs to where its home will be, in an
## alternating tripod gait (three legs swinging while the other three hold). Every few seconds, and
## at once when it is hit, it rears up before it strikes: the front of the body pitches up, the
## front legs lift off the ground, the scythes open high, it trembles, then lunges and slashes down
## and settles. The back shards flex in a wave and now and then one breaks away and re-forms; the
## abdomen breathes and its segments ripple; now and then a leg fidgets a step. Visual only: it
## never leaves its spot (the hit volume), and the strike hits nothing.

const LEGS := 6
## Each walking leg's hip on the thorax and its foot's home on the ground round the body (body
## space: +X right, -Z ahead, metres), and its tripod: legs of one tripod step together.
const HIPS := [Vector3(-0.2, 0.04, -0.22), Vector3(0.2, 0.04, -0.22), Vector3(-0.25, 0.02, 0.0), Vector3(0.25, 0.02, 0.0), Vector3(-0.2, 0.04, 0.22), Vector3(0.2, 0.04, 0.22)]
const HOMES := [Vector2(-0.95, -0.95), Vector2(0.95, -0.95), Vector2(-1.3, 0.05), Vector2(1.3, 0.05), Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]
const TRIPOD := [0, 1, 1, 0, 0, 1]
## The leg's upper and lower lengths, in metres.
const FEMUR := 0.85
const TIBIA := 1.1
## The thorax's height above the ground, and how far the body glides from its spot (x, z), in
## metres; how hard the skitter darts and pauses (0 steady, 1 stopping dead) and its period.
const BODY_H := 0.95
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
## the front pitches up (radians) about the pivot, how much the body lifts, how far it lunges.
const DISPLAY_EVERY := 6.0
const DISPLAY_S := 1.8
const REAR_PITCH := 0.62
const PIVOT := Vector3(0.0, 0.0, 0.3)
const LIFT := 0.22
const LUNGE := 0.28
## The abdomen's three gems: their lengths, widths and depths, in metres.
const ABDOMEN := [Vector3(0.36, 0.55, 0.42), Vector3(0.33, 0.46, 0.36), Vector3(0.3, 0.32, 0.26)]
## The back's burning shards: their bases (body space) and lengths.
const SPINES := [Vector4(0.0, 0.17, -0.18, 0.3), Vector4(0.0, 0.19, 0.06, 0.38), Vector4(0.0, 0.26, 0.36, 0.5), Vector4(0.0, 0.26, 0.62, 0.44), Vector4(0.0, 0.22, 0.88, 0.36), Vector4(0.0, 0.17, 1.08, 0.28)]
## A shard breaks away and re-forms once every REFORM_EVERY seconds, over REFORM_S.
const REFORM_EVERY := 1.5
const REFORM_S := 0.7
## A leg fidgets a step once every FIDGET_EVERY seconds.
const FIDGET_EVERY := 2.0

var _thorax: int
var _abdomen := PackedInt32Array()
var _head: int
var _neck: int
var _tail: int
var _crest := PackedInt32Array()
var _heart: int
var _neck_glow: int
var _femur := PackedInt32Array()
var _tibia := PackedInt32Array()
var _knee := PackedInt32Array()
var _arm := PackedInt32Array()
var _scythe := PackedInt32Array()
var _elbow := PackedInt32Array()
var _spine := PackedInt32Array()

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
## The seeded phases of its loop, its turning and its display.
var _p := PackedFloat32Array()
## The rear and the strike as last posed, for the checks.
var _rear := 0.0
var _strike := 0.0


func _build() -> void:
	core_color = Palette.HOSTILE_RED
	edge_color = Palette.HOSTILE_RED
	glyph_count = 10
	glyph_radius = 1.25
	glyph_low = -0.3
	glyph_high = 1.2
	glyph_size = 0.16
	glyph_turns = 0.05
	reach = AABB(Vector3(-2.4, -1.0, -2.6), Vector3(4.8, 3.8, 5.2))
	tag_height = 2.85
	budget_triangles = 2000
	budget_draw_calls = 10
	for i in 5:
		_p.append(TAU * dice(i, 0))
	_thorax = part(Shape.GEM, Look.SHELL)
	for i in ABDOMEN.size():
		_abdomen.append(part(Shape.GEM, Look.SHELL))
	_head = part(Shape.GEM, Look.SHELL)
	_neck = part(Shape.SHARD, Look.SHELL)
	_tail = part(Shape.SHARD, Look.SHELL)
	for i in 2:
		_crest.append(part(Shape.SHARD, Look.SHELL))
	for i in LEGS:
		_femur.append(part(Shape.SHARD, Look.SHELL))
		_tibia.append(part(Shape.SHARD, Look.SHELL))
		_knee.append(part(Shape.GEM, Look.CORE))
	for i in 2:
		_arm.append(part(Shape.SHARD, Look.SHELL))
		_scythe.append(part(Shape.SHARD, Look.SHELL))
		_elbow.append(part(Shape.GEM, Look.CORE))
	_heart = part(Shape.GEM, Look.CORE)
	_neck_glow = part(Shape.GEM, Look.CORE)
	for i in SPINES.size():
		_spine.append(part(Shape.SHARD, Look.CORE))
	for i in LEGS:
		_foot.append(Vector3.ZERO)
		_from.append(Vector3.ZERO)
		_to.append(Vector3.ZERO)
		_lift_at.append(-1.0)
		_home_last.append(Vector3.ZERO)
		_steps.append(0)


func _pose(t: float, delta: float) -> void:
	var s := t + SKITTER * sin(TAU * t / SKITTER_S) * SKITTER_S / TAU
	_display_now(t)
	var rear := _rear
	var strike := _strike
	var yaw := _p[0] + 0.85 * sin(0.31 * t + _p[3]) + 0.35 * sin(0.9 * s)
	var turn := Basis(Vector3.UP, yaw)
	var breath := sin(TAU * 0.55 * t + _p[1])
	var tremble := sin(t * 61.0) * 0.014 * rear * (1.0 - strike)
	var centre := Vector3(GLIDE.x * sin(1.25 * s + _p[1]) + tremble, GROUND_Y + BODY_H + 0.025 * breath + LIFT * rear, GLIDE.y * sin(0.83 * s + _p[2]))
	centre += turn * Vector3.FORWARD * (LUNGE * strike) + recoil()
	var pitch := REAR_PITCH * rear * (1.0 - 0.7 * strike) - 0.25 * strike + 0.3 * jolt()
	var body := turn * Basis(Vector3.RIGHT, pitch)
	var xf := Transform3D(body, centre + turn * PIVOT - body * PIVOT)
	var up := body * Vector3.UP
	var ahead := body * Vector3.FORWARD
	# The thorax, and the abdomen behind it: three gems on a rising curve that ripples, curling
	# under as it rears, the heart glowing through their gaps, the tail spike at its end.
	orient(_thorax, xf * Vector3(0.0, 0.04, -0.05), ahead, 0.62, 0.5, 0.36, up)
	var at := Vector3(0.0, 0.06, 0.2)
	var heart_from := at
	for k in ABDOMEN.size():
		var size: Vector3 = ABDOMEN[k]
		var bend := 0.2 + 0.08 * k - 0.22 * rear * k + 0.07 * sin(2.2 * t - k * 0.9 + _p[2])
		var back := Vector3(0.0, sin(bend), cos(bend))
		var mid := at + back * (size.x * 0.5 + 0.03)
		var swell := 1.0 + 0.05 * breath * (1.0 - 0.3 * k)
		orient(_abdomen[k], xf * mid, body * -back, size.x * swell, size.y * swell, size.z * swell, up)
		at = mid + back * (size.x * 0.5 + 0.03)
		if k == 1:
			heart_from = mid
	orient(_heart, xf * heart_from, body * (at - heart_from), 0.95, 0.24)
	brighten(_heart, 1.2 + 0.4 * breath)
	var tail_way := Vector3(0.0, 0.55 - 0.4 * rear, 1.0).normalized()
	bone(_tail, xf * (at - Vector3(0.0, 0.0, 0.05)), xf * (at + tail_way * 0.42), 0.11)
	# The prothorax rising to the head, the head a faceless wedge pointing ahead and down, two crest
	# shards swept back off it; it jerks now and then.
	var neck_from := Vector3(0.0, 0.1, -0.3)
	var neck_to := Vector3(0.0, 0.34 + 0.12 * rear, -0.7)
	bone(_neck, xf * neck_from, xf * neck_to, 0.17)
	orient(_neck_glow, xf * neck_from, ahead, 0.18, 0.15)
	var jerk := _jerk(t)
	var head_way := (Vector3(jerk, -0.35 + 0.3 * rear, -1.0)).normalized()
	var head_at := neck_to + head_way * 0.12
	orient(_head, xf * head_at, body * head_way, 0.34, 0.27, 0.2, up)
	for side in 2:
		var x := -1.0 if side == 0 else 1.0
		bone(_crest[side], xf * (head_at + Vector3(0.06 * x, 0.07, 0.04)), xf * (head_at + Vector3(0.14 * x, 0.26 + 0.1 * rear, 0.24)), 0.045)
	# The scythe arms: folded in prayer at rest, raised high and open in the display, slashing down
	# at the strike.
	for side in 2:
		var x := -1.0 if side == 0 else 1.0
		var shoulder := Vector3(0.11 * x, 0.26, -0.55)
		var r := rear * (1.0 - strike)
		var sway := 0.06 * sin(1.7 * t + side * 1.3)
		var d1 := Vector3(0.18 * x, -0.05 + sway, -1.0).lerp(Vector3(0.55 * x, 1.1, -0.45), r).lerp(Vector3(0.08 * x, -0.55, -1.0), strike).normalized()
		var elbow := shoulder + d1 * 0.58
		var d2 := Vector3(0.0, -0.75, 0.65).lerp(Vector3(0.25 * x, 0.25, -1.0), r).lerp(Vector3(0.0, -1.0, -0.25), strike).normalized()
		var tip := elbow + d2 * 0.62
		bone(_arm[side], xf * shoulder, xf * elbow, 0.08)
		bone(_scythe[side], xf * elbow, xf * tip, 0.17, 0.035, body * Vector3.RIGHT)
		orient(_elbow[side], xf * elbow, body * d1, 0.12, 0.08)
	_pose_spines(t, xf, body, rear)
	_pose_legs(t, delta, xf, turn, centre, rear)


## The burning shards along the back: a flexing wave, standing up as it rears; one at a time
## breaks away and re-forms.
func _pose_spines(t: float, xf: Transform3D, body: Basis, rear: float) -> void:
	var n := int(floor(t / REFORM_EVERY))
	var tau := t - n * REFORM_EVERY
	var breaking := int(dice(n, 3) * SPINES.size()) if tau < REFORM_S else -1
	for i in SPINES.size():
		var s: Vector4 = SPINES[i]
		var lean := -0.55 + 0.4 * rear + 0.22 * sin(2.3 * t - i * 0.8 + _p[4])
		var way := Vector3(0.12 * sin(1.1 * t + i), cos(lean), -sin(lean)).normalized()
		var grown := 1.0
		if i == breaking:
			grown = 1.0 - tau / 0.15 if tau < 0.15 else clampf((tau - 0.2) / (REFORM_S - 0.2), 0.0, 1.0)
		if grown <= 0.001:
			conceal(_spine[i])
			continue
		var base := Vector3(s.x, s.y, s.z)
		bone(_spine[i], xf * base, xf * (base + way * s.w * (1.0 + 0.3 * rear) * grown), 0.09)
		present(_spine[i], grown)
		brighten(_spine[i], 0.9 + 0.5 * rear)


## The legs: the hips ride the body, the feet plant and step (see the header), the knees bend up
## and out by two-bone IK; the front pair lift off the ground while it rears.
func _pose_legs(t: float, delta: float, xf: Transform3D, turn: Basis, centre: Vector3, rear: float) -> void:
	var ground := Vector3(centre.x, GROUND_Y, centre.z)
	if not _feet_ready:
		for i in LEGS:
			var h: Vector2 = HOMES[i]
			_foot[i] = ground + turn * Vector3(h.x, 0.0, h.y)
			_home_last[i] = _foot[i]
			_lift_at[i] = -1.0
		_feet_ready = true
	var fidget := int(floor(t / FIDGET_EVERY))
	var fidget_leg := int(dice(fidget, 5) * LEGS) if fidget != _fidget_n else -1
	_fidget_n = fidget
	for i in LEGS:
		var h: Vector2 = HOMES[i]
		var home := ground + turn * Vector3(h.x, 0.0, h.y)
		var moving := (home - _home_last[i]) / delta if delta > 0.0 else Vector3.ZERO
		_home_last[i] = home
		var lifted := i < 2 and rear > 0.25
		if _lift_at[i] >= 0.0:
			if since(_lift_at[i]) >= SWING_S:
				_foot[i] = _to[i]
				_lift_at[i] = -1.0
				_steps[i] += 1
		elif delta > 0.0 and not lifted:
			var off := _foot[i].distance_to(home)
			var group: int = TRIPOD[i]
			var free := not _swinging(1 - group)
			if (off > STEP_AT and (free or off > STEP_AT * 2.2)) or (i == fidget_leg and free):
				_from[i] = _foot[i]
				var land := home + moving * LEAD_S
				if i == fidget_leg and off <= STEP_AT:
					land += turn * Vector3(0.12 * (dice(fidget, 6) - 0.5), 0.0, 0.12 * (dice(fidget, 7) - 0.5))
				land.y = GROUND_Y
				_to[i] = land
				_lift_at[i] = t
		var foot := _foot[i]
		if _lift_at[i] >= 0.0:
			var u := clampf(since(_lift_at[i]) / SWING_S, 0.0, 1.0)
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
		bone(_femur[i], hip, knee, 0.1)
		bone(_tibia[i], knee, reached, 0.075)
		orient(_knee[i], knee, knee - hip, 0.14, 0.1)


func _on_hit() -> void:
	# A hit makes it rear up at once, unless it already is.
	if since(_forced_at) >= DISPLAY_S and _rear < 0.05:
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
