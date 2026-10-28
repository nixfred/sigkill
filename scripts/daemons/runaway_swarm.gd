extends DaemonArt
## The runaway (A2b, the "runaway" dummy): a runaway process's swarm. One target (its hit volume is
## the dummy's, as ever); the swarm is its look: thirty-six small glitch insects (an obsidian body
## edged in red, two blade wings beating, a glowing glint at the front) flocking round a pulsing
## nest core caged by four turning shards, each leaving a short light trail.
##
## They flock as boids: each steers toward its neighbours' middle, matches their heading and keeps
## its distance from the nearest, while the nest pulls them back to a shell round it and spins them
## round an axis that slowly precesses, so the swarm orbits; every so often one (sometimes three)
## breaks off and dives at the ground round the nest, then climbs back into the orbit. Now and then
## an insect glitches a hand's width off its place for a frame. A hit scatters them away from the
## shot before they regroup. They step at the game's pace (SIGSTOP slows them), seeded per daemon.
## Visual only.

const INSECTS := 36
## The flock: the shell they hold round the nest, the neighbours' reach, the distance they keep, in
## metres; how hard each pull is; their slowest and fastest speed, in m/s; the longest step one frame
## may take, in seconds.
const ORBIT_M := 0.62
const HOLLOW_M := 0.45
const NEAR_M := 0.9
const APART_M := 0.3
const COHESION := 1.0
const ALIGN := 0.7
const SEPARATE := 4.0
const HOME := 12.0
const SPIN := 2.2
const FLOOR_PUSH := 6.0
const SPEED_MIN := 1.0
const SPEED_MAX := 2.2
const STEP_MAX := 1.0 / 30.0
## Dives: one every DIVE_EVERY seconds (every third a group of three), each DIVE_S long, at a point
## on the ground between these radii round the nest, with this pull.
const DIVE_EVERY := 0.45
const DIVE_S := 0.7
const DIVE_NEAR := 0.4
const DIVE_FAR := 1.1
const DIVE_PULL := 10.0
## A hit's scatter, in m/s, and its reach, in metres.
const SCATTER := 4.5
const SCATTER_M := 1.6
## Trails: how often each insect's trail takes a new point, in seconds; wing beats a second.
const TRAIL_STEP_S := 0.1
const WING_HZ := 11.0
## An insect's length, width and wingspan, in metres, before its own size.
const BODY_L := 0.36
const BODY_W := 0.1
const WING_L := 0.27

var _body := PackedInt32Array()
var _wing := PackedInt32Array()
var _glint := PackedInt32Array()
var _trail := PackedInt32Array()
var _nest: int
var _cage := PackedInt32Array()
## The flock: where each insect is and how fast it goes (art space), its trail's last two points,
## its size, its wings' phase, where and since when it dives (-1 not diving); the neighbour sums.
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _hist := PackedVector3Array()
var _size := PackedFloat32Array()
var _beat := PackedFloat32Array()
var _dive_to := PackedVector3Array()
var _dive_at := PackedFloat32Array()
var _coh := PackedVector3Array()
var _ali := PackedVector3Array()
var _sep := PackedVector3Array()
var _count := PackedInt32Array()
var _hist_age := 0.0
var _dive_n := -1
var _flock_ready := false
var _anchor := Vector3.ZERO
var _p := PackedFloat32Array()


func _build() -> void:
	core_color = Palette.HOSTILE_RED
	edge_color = Palette.HOSTILE_RED
	glyph_count = 8
	glyph_radius = 1.3
	glyph_low = -0.5
	glyph_high = 0.9
	glyph_size = 0.15
	glyph_turns = 0.14
	reach = AABB(Vector3(-2.3, -1.0, -2.3), Vector3(4.6, 3.4, 4.6))
	tag_height = 2.6
	budget_triangles = 5600
	budget_draw_calls = 8
	for i in 3:
		_p.append(TAU * dice(i, 2))
	_nest = part(Shape.GEM, Look.CORE)
	for i in 4:
		_cage.append(part(Shape.SHARD, Look.SHELL))
	for i in INSECTS:
		_body.append(part(Shape.SHARD, Look.SHELL))
		_wing.append(part(Shape.SHARD, Look.SHELL))
		_wing.append(part(Shape.SHARD, Look.SHELL))
		_glint.append(part(Shape.GEM, Look.CORE))
		_trail.append(part(Shape.STREAK, Look.TRAIL))
		_trail.append(part(Shape.STREAK, Look.TRAIL))
		_pos.append(Vector3.ZERO)
		_vel.append(Vector3.ZERO)
		_hist.append(Vector3.ZERO)
		_hist.append(Vector3.ZERO)
		_size.append(0.8 + 0.45 * dice(i, 3))
		_beat.append(TAU * dice(i, 4))
		_dive_to.append(Vector3.ZERO)
		_dive_at.append(-1.0)
		_coh.append(Vector3.ZERO)
		_ali.append(Vector3.ZERO)
		_sep.append(Vector3.ZERO)
		_count.append(0)


func _pose(t: float, delta: float) -> void:
	_anchor = Vector3(0.0, 0.06 * sin(1.1 * t + _p[0]), 0.0) + recoil()
	if not _flock_ready:
		_seed_flock()
	if delta > 0.0:
		_fly(t, minf(delta, STEP_MAX))
	var pulse := sin(TAU * 1.3 * t + _p[1])
	orient(_nest, _anchor, Vector3.UP, 0.36 * (1.0 + 0.15 * pulse), 0.28 * (1.0 + 0.15 * pulse))
	brighten(_nest, 1.2 + 0.4 * pulse)
	for k in 4:
		var a := TAU * k / 4.0 + 1.7 * t
		var out := Vector3(cos(a), 0.35 * sin(2.0 * t + k), sin(a)) * 0.3
		bone(_cage[k], _anchor + out * 0.5 - Vector3.UP * 0.18, _anchor + out + Vector3.UP * 0.22, 0.07)
	var tick := int(floor(t * 12.0))
	for i in INSECTS:
		var size := _size[i]
		var v := _vel[i]
		var ahead := v.normalized() if v.length_squared() > 0.0001 else Vector3.FORWARD
		var at := _pos[i]
		if dice(i, tick) < 0.02:
			at += Vector3(dice(i + 50, tick) - 0.5, dice(i + 90, tick) - 0.5, dice(i + 130, tick) - 0.5) * 0.2
		var length := BODY_L * size
		bone(_body[i], at - ahead * length * 0.55, at + ahead * length * 0.45, BODY_W * size)
		orient(_glint[i], at + ahead * length * 0.25, ahead, 0.08 * size, 0.05 * size)
		var side := ahead.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		var lift := side.cross(ahead)
		var beat := 0.35 + 0.8 * sin(_beat[i])
		for w in 2:
			var x := -1.0 if w == 0 else 1.0
			var span := side * (x * cos(beat)) + lift * sin(beat)
			var root := at + ahead * 0.02
			bone(_wing[i * 2 + w], root, root + (span * WING_L - ahead * 0.06) * size, 0.09 * size, 0.012, span.cross(ahead))
		bone(_trail[i * 2], _hist[i * 2], at, 0.06 * size)
		bone(_trail[i * 2 + 1], _hist[i * 2 + 1], _hist[i * 2], 0.045 * size)
		brighten(_trail[i * 2 + 1], 0.5)


## One step of the flock: the neighbour sums for every pair, then each insect's pulls, its speed
## kept between its bounds, its wings and its trail.
func _fly(t: float, dt: float) -> void:
	var n := int(floor(t / DIVE_EVERY))
	if n != _dive_n:
		_dive_n = n
		for d in (3 if n % 3 == 0 else 1):
			var i := int(dice(n, 20 + d) * INSECTS) % INSECTS
			var a := TAU * dice(n, 30 + d)
			var r := lerpf(DIVE_NEAR, DIVE_FAR, dice(n, 40 + d))
			_dive_to[i] = Vector3(cos(a) * r, GROUND_Y + 0.15, sin(a) * r)
			_dive_at[i] = t
	_coh.fill(Vector3.ZERO)
	_ali.fill(Vector3.ZERO)
	_sep.fill(Vector3.ZERO)
	_count.fill(0)
	var near2 := NEAR_M * NEAR_M
	for i in INSECTS:
		var p := _pos[i]
		for j in range(i + 1, INSECTS):
			var gap := _pos[j] - p
			var d2 := gap.length_squared()
			if d2 > near2 or d2 < 0.000001:
				continue
			_coh[i] += _pos[j]
			_coh[j] += p
			_ali[i] += _vel[j]
			_ali[j] += _vel[i]
			_count[i] += 1
			_count[j] += 1
			if d2 < APART_M * APART_M:
				var push := gap / d2 * 0.1
				_sep[i] -= push
				_sep[j] += push
	var axis := Vector3(0.4 * sin(0.3 * t + _p[2]), 1.0, 0.4 * cos(0.23 * t + _p[2])).normalized()
	for i in INSECTS:
		var p := _pos[i]
		var v := _vel[i]
		var force := _sep[i] * SEPARATE
		if _count[i] > 0:
			force += (_coh[i] / _count[i] - p) * COHESION + (_ali[i] / _count[i] - v) * ALIGN
		var out := p - _anchor
		var dist := out.length()
		var radial := out / dist if dist > 0.0001 else Vector3.UP
		var diving := _dive_at[i] >= 0.0 and since(_dive_at[i]) < DIVE_S
		if diving:
			force += (_dive_to[i] + _anchor * Vector3(1.0, 0.0, 1.0) - p).normalized() * DIVE_PULL
		else:
			_dive_at[i] = -1.0
			force -= radial * (dist - ORBIT_M) * HOME
			if dist < HOLLOW_M:
				force += radial * (HOLLOW_M - dist) * HOME * 2.0
			force += axis.cross(radial) * SPIN
		var above := p.y - (GROUND_Y + 0.12)
		if above < 0.25:
			force += Vector3.UP * FLOOR_PUSH * (0.25 - above) / 0.25
		v += force * dt
		var speed := v.length()
		if speed > SPEED_MAX:
			v *= SPEED_MAX / speed
		elif speed < SPEED_MIN:
			v = (v / speed if speed > 0.0001 else axis.cross(radial)) * SPEED_MIN
		p += v * dt
		p.y = maxf(p.y, GROUND_Y + 0.05)
		_vel[i] = v
		_pos[i] = p
		_beat[i] = fmod(_beat[i] + TAU * WING_HZ * dt, TAU)
	_hist_age += dt
	if _hist_age >= TRAIL_STEP_S:
		_hist_age = 0.0
		for i in INSECTS:
			_hist[i * 2 + 1] = _hist[i * 2]
			_hist[i * 2] = _pos[i]


## The flock as it forms: every insect on a shell round the nest, heading round it.
func _seed_flock() -> void:
	for i in INSECTS:
		var a := TAU * dice(i, 5)
		var y := lerpf(-0.7, 0.7, dice(i, 6))
		var flat := sqrt(1.0 - y * y)
		var out := Vector3(cos(a) * flat, y, sin(a) * flat)
		var r := lerpf(0.6, ORBIT_M, dice(i, 7))
		_pos[i] = _anchor + out * r
		_vel[i] = Vector3.UP.cross(out).normalized() * SPEED_MIN * 1.5 if absf(out.y) < 0.99 else Vector3.RIGHT * SPEED_MIN
		_hist[i * 2] = _pos[i]
		_hist[i * 2 + 1] = _pos[i]
		_dive_at[i] = -1.0
	_flock_ready = true


func _on_hit() -> void:
	# The swarm scatters away from the shot, the nearest hardest.
	for i in INSECTS:
		var away := _pos[i] - _hit_point
		var d := away.length()
		if d < SCATTER_M:
			_vel[i] += (away / d if d > 0.0001 else Vector3.UP) * SCATTER * (1.0 - d / SCATTER_M)


func _on_return() -> void:
	_flock_ready = false


# --- For the checks. ---

## Where each insect is now (art space).
func boids() -> PackedVector3Array:
	return _pos


## How fast each insect goes now.
func velocities() -> PackedVector3Array:
	return _vel


## The nest's centre now.
func nest_at() -> Vector3:
	return _anchor
