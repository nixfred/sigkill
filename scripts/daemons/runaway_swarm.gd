extends DaemonArt
## The runaway (A2b, rebuilt in A5; the "runaway" dummy): a runaway process's swarm. One target (its
## hit volume is the dummy's, as ever, round the core); the swarm is its look: a flock of small solid
## drones, each a hex puck of near-black armour with two blade wings and a hot-magenta light in its
## middle, leaving a short magenta trail, flying round a bigger core drone: two armoured hex halves
## turning about a band of magenta light, its magenta heart showing through the gap (its weak point,
## weak()). Faceless: lights and armour, no feature.
##
## No two alike (A5): its seed sets how many drones it flies and the size of each, its wings' length
## and sweep, how wide its flock holds round the core, and, one in twelve, an elite: more drones, a
## bigger core with an armoured halo turning round it.
##
## They flock as boids: each steers toward its neighbours' middle, matches their heading and keeps
## its distance from the nearest, while the core pulls them back to a shell round it and spins them
## round an axis that slowly precesses, each on its own tilted orbit, so the swarm orbits as a cloud;
## every so often one (sometimes three) breaks off and dives at the ground round the core, then climbs
## back into the orbit. Now and then a drone glitches a hand's width off its place for a frame. A hit
## scatters them away from the shot before they regroup. They step at the game's pace (SIGSTOP slows
## them), seeded per daemon. Visual only.
##
## Killing the core scatters the swarm (A5): the runaway's death is its core's, and as the core
## bursts every drone flies off whole, out from the core in every direction, turning and falling a
## little as it derezzes (_scatter_groups(): the death's shatter, scripts/daemons/daemon_shatter.gd,
## flies each drone as one group). The death is the daemon's own (the host's word in a match), so
## every screen sees its swarm scatter when its core dies, and no drone outlives it.
##
## Fighting back (C27b), its brain flies the whole swarm: round its prey, then in dives at it.
## Each drone keeps a share of its own flight in the world as the daemon moves (they stream
## behind a fast move and catch up) and its trail follows where it truly went. The tell before
## every dive pulls the swarm into a tight ball, the core's band burning brighter; it stays tight
## through the dive; a scatter flings it wide.

## The flock: the shell they hold round the core, the neighbours' reach, the distance they keep, in
## metres; how hard each pull is; their slowest and fastest speed, in m/s; the longest step one frame
## may take, in seconds.
const ORBIT_M := 0.66
const HOLLOW_M := 0.48
const NEAR_M := 0.9
const APART_M := 0.32
const COHESION := 1.0
const ALIGN := 0.7
const SEPARATE := 4.0
const HOME := 12.0
const SPIN := 2.2
## How far each drone's own orbit leans off the swarm's axis (1 is 45 degrees at most).
const TILT := 1.3
const FLOOR_PUSH := 6.0
const SPEED_MIN := 1.0
const SPEED_MAX := 2.2
const STEP_MAX := 1.0 / 30.0
## Dives: one every DIVE_EVERY seconds (every third a group of three), each DIVE_S long, at a point
## on the ground between these radii round the core, with this pull.
const DIVE_EVERY := 0.45
const DIVE_S := 0.7
const DIVE_NEAR := 0.4
const DIVE_FAR := 1.1
const DIVE_PULL := 10.0
## A hit's scatter: the push, in m/s, its reach, in metres, and how long the swarm may fly faster
## than its top speed to get away, in seconds.
const SCATTER := 5.5
const SCATTER_M := 1.6
const SCATTER_S := 0.6
## Trails: how often each drone's trail takes a new point, in seconds; wing beats a second.
const TRAIL_STEP_S := 0.1
const WING_HZ := 11.0
## A drone's width across its corners and its thickness, and its wings' length, in metres, before
## its own size.
const DRONE_W := 0.2
const DRONE_H := 0.075
const WING_L := 0.22
## The core drone's width and each half's thickness, in metres.
const CORE_W := 0.46
const CORE_H := 0.13
## The share of its own flight a drone keeps in the world as the daemon moves (C27b), and the
## shell the tell pulls it into and a scatter throws it out to.
const INERTIA := 0.55
const TIGHT_M := 0.32
const WIDE_M := 1.3
## The death's scatter (A5): how fast each drone flies off, in m/s, and how much of its own flight it
## keeps.
const FLEE_LOW := 6.0
const FLEE_HIGH := 9.0
const FLEE_KEEP := 0.4

var _hull := PackedInt32Array()
var _wing := PackedInt32Array()
var _glint := PackedInt32Array()
var _trail := PackedInt32Array()
var _core_top: int
var _core_bottom: int
var _core_band: int
var _heart: int
var _halo := -1
## Each part's drone (-1 none): the parts its death flies off whole.
var _drone_of := PackedInt32Array()
## The flock: where each drone is and how fast it goes (art space), its trail's last two points,
## its size, its wings' phase, where and since when it dives (-1 not diving); the neighbour sums.
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _hist := PackedVector3Array()
var _size := PackedFloat32Array()
var _beat := PackedFloat32Array()
var _tilt := PackedVector3Array()
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
## Its build (A5): how many drones, its wings' length and sweep, its flock's shell, its core's size.
var _drones := 18
var _wing_l := 1.0
var _sweep := 0.06
var _orbit := ORBIT_M
var _core := 1.0


func _build() -> void:
	ai_kind = "swarm"
	core_color = Palette.HOT_MAGENTA
	edge_color = Palette.HOT_MAGENTA
	glyph_count = 6
	glyph_radius = 1.35
	glyph_low = -0.5
	glyph_high = 0.9
	glyph_size = 0.13
	glyph_turns = 0.14
	reach = AABB(Vector3(-2.3, -1.0, -2.3), Vector3(4.6, 3.4, 4.6))
	tag_height = 2.6
	budget_triangles = 6000
	budget_draw_calls = 10
	size_low = 0.92
	size_high = 1.06
	elite_size = 1.12
	for i in 3:
		_p.append(TAU * dice(i, 2))
	# The build's rolls (A5).
	_drones = 30 if elite else pick(60, 0, 14, 22)
	_wing_l = lerpf(0.8, 1.25, dice(61, 0))
	_sweep = lerpf(0.02, 0.12, dice(62, 0))
	_orbit = ORBIT_M * (1.15 if elite else lerpf(0.9, 1.1, dice(63, 0)))
	_core = 1.25 if elite else lerpf(0.9, 1.1, dice(64, 0))
	_core_top = part(Shape.HEX, Look.ARMOR)
	_core_bottom = part(Shape.HEX, Look.ARMOR)
	_core_band = weak(part(Shape.RING, Look.CORE))
	_heart = weak(part(Shape.GEM, Look.CORE))
	if elite:
		_halo = part(Shape.RING, Look.ARMOR)
	for i in _drones:
		_hull.append(part(Shape.HEX, Look.ARMOR))
		_wing.append(part(Shape.BLADE, Look.ARMOR))
		_wing.append(part(Shape.BLADE, Look.ARMOR))
		_glint.append(part(Shape.GEM, Look.CORE))
		_trail.append(part(Shape.STREAK, Look.TRAIL))
		_trail.append(part(Shape.STREAK, Look.TRAIL))
		_pos.append(Vector3.ZERO)
		_vel.append(Vector3.ZERO)
		_hist.append(Vector3.ZERO)
		_hist.append(Vector3.ZERO)
		_size.append(0.8 + 0.45 * dice(i, 3))
		_beat.append(TAU * dice(i, 4))
		# Each drone's own orbit, tilted off the swarm's axis, so the swarm is a cloud, not a ring.
		var lean := Vector3(dice(i, 8) - 0.5, 0.0, dice(i, 9) - 0.5)
		_tilt.append(lean.normalized() * TILT * (0.4 + 0.6 * dice(i, 10)) if lean.length_squared() > 0.0001 else Vector3.ZERO)
		_dive_to.append(Vector3.ZERO)
		_dive_at.append(-1.0)
		_coh.append(Vector3.ZERO)
		_ali.append(Vector3.ZERO)
		_sep.append(Vector3.ZERO)
		_count.append(0)
	# Battle damage (A5): a drone or two with its light flickering.
	for i in pick(65, 0, 0, 2):
		flicker(_glint[pick(66, i, 0, _drones - 1)], lerpf(0.4, 0.8, dice(67, i)))
	_drone_of.resize(part_count())
	_drone_of.fill(-1)
	for i in _drones:
		_drone_of[_hull[i]] = i
		_drone_of[_wing[i * 2]] = i
		_drone_of[_wing[i * 2 + 1]] = i
		_drone_of[_glint[i]] = i


func _pose(t: float, delta: float) -> void:
	_anchor = Vector3(0.0, 0.06 * sin(1.1 * t + _p[0]), 0.0) + recoil()
	if not _flock_ready:
		_seed_flock()
	elif _carry != Transform3D.IDENTITY:
		# The daemon moved: each drone keeps a share of its flight in the world, its trail all of it
		# (C27b).
		for i in _drones:
			_pos[i] = _pos[i].lerp(_carry * _pos[i], INERTIA)
			_hist[i * 2] = _carry * _hist[i * 2]
			_hist[i * 2 + 1] = _carry * _hist[i * 2 + 1]
	if delta > 0.0:
		_fly(t, minf(delta, STEP_MAX))
	var pulse := sin(TAU * 1.3 * t + _p[1])
	var hot := _tight()
	# The core drone: two armoured halves turning about its band of light, its heart in the gap.
	var spin := Basis(Vector3.UP, 0.9 * t + _p[2]) * Basis(Vector3.RIGHT, 0.12 * sin(0.7 * t))
	var w := CORE_W * _core
	var gap := 0.05 * _core * (1.0 + 0.4 * hot)
	lay(_core_top, _anchor + spin * Vector3(0.0, gap + CORE_H * 0.5 * _core, 0.0), spin * Basis.from_scale(Vector3(w, CORE_H * _core, w)))
	lay(_core_bottom, _anchor - spin * Vector3(0.0, gap + CORE_H * 0.5 * _core, 0.0), spin * Basis(Vector3.RIGHT, PI) * Basis.from_scale(Vector3(w, CORE_H * _core, w)))
	lay(_core_band, _anchor, spin * Basis.from_scale(Vector3(w * 0.92, gap * 1.6, w * 0.92)))
	brighten(_core_band, 1.1 + 0.3 * pulse + 1.6 * hot)
	orient(_heart, _anchor, spin * Vector3.UP, 0.3 * _core * (1.0 + 0.15 * pulse + 0.3 * hot), 0.24 * _core)
	brighten(_heart, 1.3 + 0.4 * pulse + 1.6 * hot)
	if _halo >= 0:
		var halo := Basis(Vector3.UP, -0.5 * t) * Basis(Vector3.RIGHT, 0.5 + 0.2 * sin(0.4 * t))
		lay(_halo, _anchor, halo * Basis.from_scale(Vector3(w * 1.9, 0.05, w * 1.9)))
	var tick := int(floor(t * 12.0))
	for i in _drones:
		var size := _size[i]
		var v := _vel[i]
		var ahead := v.normalized() if v.length_squared() > 0.0001 else Vector3.FORWARD
		var at := _pos[i]
		if dice(i, tick) < 0.02:
			at += Vector3(dice(i + 50, tick) - 0.5, dice(i + 90, tick) - 0.5, dice(i + 130, tick) - 0.5) * 0.2
		var side := ahead.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		var lift := side.cross(ahead)
		# The hull flies flat, edge first; its light shows top and bottom through its middle.
		lay(_hull[i], at, Basis(side * DRONE_W * size, lift * DRONE_H * size, -ahead * DRONE_W * size))
		orient(_glint[i], at, lift, DRONE_H * 1.7 * size, DRONE_W * 0.32 * size)
		var beat := 0.25 + 0.6 * sin(_beat[i])
		for k in 2:
			var x := -1.0 if k == 0 else 1.0
			var span := side * (x * cos(beat)) + lift * sin(beat)
			var root := at + side * (x * DRONE_W * 0.42 * size)
			bone(_wing[i * 2 + k], root, root + (span * WING_L * _wing_l - ahead * _sweep) * size, 0.016 * size, 0.07 * size, ahead)
		bone(_trail[i * 2], _hist[i * 2], at, 0.05 * size)
		bone(_trail[i * 2 + 1], _hist[i * 2 + 1], _hist[i * 2], 0.04 * size)
		brighten(_trail[i * 2 + 1], 0.5)


## One step of the flock: the neighbour sums for every pair, then each drone's pulls, its speed
## kept between its bounds, its wings and its trail.
func _fly(t: float, dt: float) -> void:
	var n := int(floor(t / DIVE_EVERY))
	if n != _dive_n:
		_dive_n = n
		for d in (3 if n % 3 == 0 else 1):
			var i := int(dice(n, 20 + d) * _drones) % _drones
			var a := TAU * dice(n, 30 + d)
			var r := lerpf(DIVE_NEAR, DIVE_FAR, dice(n, 40 + d))
			_dive_to[i] = Vector3(cos(a) * r, GROUND_Y + 0.15, sin(a) * r)
			_dive_at[i] = t
	_coh.fill(Vector3.ZERO)
	_ali.fill(Vector3.ZERO)
	_sep.fill(Vector3.ZERO)
	_count.fill(0)
	var near2 := NEAR_M * NEAR_M
	for i in _drones:
		var p := _pos[i]
		for j in range(i + 1, _drones):
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
	# The shell they hold: tight in the tell and the dive, wide in a scatter (C27b).
	var hot := _tight()
	var orbit := lerpf(lerpf(_orbit, TIGHT_M, hot), WIDE_M, 1.0 if act == Act.SCATTER else 0.0)
	var hollow := minf(HOLLOW_M, orbit * 0.6)
	# Just after a hit the scatter may outrun the top speed, easing back to it.
	var fastest := SPEED_MAX + SCATTER * maxf(0.0, 1.0 - since(_hit_at) / SCATTER_S)
	for i in _drones:
		var p := _pos[i]
		var v := _vel[i]
		var force := _sep[i] * SEPARATE
		if _count[i] > 0:
			force += (_coh[i] / _count[i] - p) * COHESION + (_ali[i] / _count[i] - v) * ALIGN
		var out := p - _anchor
		var dist := out.length()
		var radial := out / dist if dist > 0.0001 else Vector3.UP
		var diving := _dive_at[i] >= 0.0 and since(_dive_at[i]) < DIVE_S and act == Act.IDLE
		if diving:
			force += (_dive_to[i] + _anchor * Vector3(1.0, 0.0, 1.0) - p).normalized() * DIVE_PULL
		else:
			_dive_at[i] = -1.0
			force -= radial * (dist - orbit) * HOME
			if dist < hollow:
				force += radial * (hollow - dist) * HOME * 2.0
			force += (axis + _tilt[i]).normalized().cross(radial) * SPIN
		var above := p.y - (GROUND_Y + 0.12)
		if above < 0.25:
			force += Vector3.UP * FLOOR_PUSH * (0.25 - above) / 0.25
		v += force * dt
		var speed := v.length()
		if speed > fastest:
			v *= fastest / speed
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
		for i in _drones:
			_hist[i * 2 + 1] = _hist[i * 2]
			_hist[i * 2] = _pos[i]


## The flock as it forms: every drone on a shell round the core, heading round it.
func _seed_flock() -> void:
	for i in _drones:
		var a := TAU * dice(i, 5)
		var y := lerpf(-0.7, 0.7, dice(i, 6))
		var flat := sqrt(1.0 - y * y)
		var out := Vector3(cos(a) * flat, y, sin(a) * flat)
		var r := lerpf(0.6, _orbit, dice(i, 7))
		_pos[i] = _anchor + out * r
		_vel[i] = Vector3.UP.cross(out).normalized() * SPEED_MIN * 1.5 if absf(out.y) < 0.99 else Vector3.RIGHT * SPEED_MIN
		_hist[i * 2] = _pos[i]
		_hist[i * 2 + 1] = _pos[i]
		_dive_at[i] = -1.0
	_flock_ready = true


func _on_hit() -> void:
	# The swarm scatters away from the shot: full force within the first part of its reach, easing
	# off to nothing at its edge.
	for i in _drones:
		var away := _pos[i] - _hit_point
		var d := away.length()
		if d < SCATTER_M:
			_vel[i] += (away / d if d > 0.0001 else Vector3.UP) * SCATTER * clampf(1.4 * (1.0 - d / SCATTER_M), 0.0, 1.0)


func _on_return() -> void:
	_flock_ready = false


## The core is dead (A5): every drone flies off whole, out from the core and up a little, at its own
## speed, keeping a share of its own flight (world space, for the death's shatter).
func _scatter_groups() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var to_world := global_transform if is_inside_tree() else transform
	for i in _drones:
		var away := _pos[i] - _anchor
		away.y = maxf(away.y, 0.0) * 0.5
		if away.length_squared() < 0.0001:
			away = Vector3(cos(TAU * dice(i, 70)), 0.0, sin(TAU * dice(i, 70)))
		var way := (away.normalized() + Vector3.UP * 0.35).normalized()
		var speed := lerpf(FLEE_LOW, FLEE_HIGH, dice(i, 71))
		# In m/s in the world at any size: turned into the world, never scaled.
		var vel := to_world.basis.orthonormalized() * (way * speed + _vel[i] * FLEE_KEEP)
		out.append({"at": to_world * _pos[i], "vel": vel})
	return out


func _group_of(id: int) -> int:
	return _drone_of[id] if id < _drone_of.size() else -1


## How tight and bright the swarm is pulled now, 0 to 1 (C27b): in through the tell, held in the
## dive, easing out in the recovery.
func _tight() -> float:
	match act:
		Act.TELL:
			return smoothstep(0.0, 0.8, act_u)
		Act.STRIKE:
			return 1.0
		Act.RECOVER:
			return 1.0 - act_u
	return 0.0


func _muzzle() -> Vector3:
	return _anchor


# --- For the checks. ---

## Where each drone is now (art space).
func boids() -> PackedVector3Array:
	return _pos


## How fast each drone goes now.
func velocities() -> PackedVector3Array:
	return _vel


## The core's centre now.
func nest_at() -> Vector3:
	return _anchor


## How many drones it flies (A5).
func drone_count() -> int:
	return _drones
