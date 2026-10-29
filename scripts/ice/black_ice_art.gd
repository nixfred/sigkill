extends IceArt
## Black ICE (I3): the machine's last line of defence, and the worst thing in the arena. Huge, solid and
## faceless: a black sun of ICE. A core of black crystal plates hovers over the floor round a dim cold
## heart, the heart's light showing only in the gaps between the plates and along a few thin veins; long
## black crystal spikes radiate from it in every direction, slowly breathing; spike legs reach down from
## it to the floor in a ring as wide as its touch, so what you see standing round it is what flatlines you.
## Its light is almost absent: ICE's crystal darker still (Palette.black_ice_crystal_material(): near-black
## glass that light falls into, a thin cold rim only where it turns away, so its silhouette reads against
## the dark it brings) and only a few cold slate lines: two seals, rings of light crossing round its core
## (its weak points: exploit's marks show them, and a brute charge thrown while that intruder's exploit
## runs breaks one), the veins, a dim heart, and a dashed ring on the floor at the reach of its touch.
##
## Its arrival (Act.TELL, u 0 to 1 over the tell): the floor ring first, then the plates closing into its
## core out of nothing over the ring, breaking up into being (ICE's presence), the spikes and the legs
## growing out of it, the seals lighting last. Moving (Act.MOVE): it rolls a little into its way and its
## legs step. A broken seal (Act.SCATTER, the reel): its spikes draw in and it shudders, the broken seal
## dark and flickering until it mends. Withdrawing (withdraw, 0 to 1): the arrival backwards.
##
## Its seed rolls its spikes (how many, which ways, how long, how they breathe), its legs (how many, where
## each stands), its core's plates and how it turns, the seals' tilt and turn, and which veins burn. Its
## body and its touch never change with the seed: they are the tuning's. Art space: the floor 0.9 under
## the origin, as a daemon's.

## Its touch's reach (the dashed ring on the floor and where its legs stand), set before setup().
var touch_m := 1.65
## How far through withdrawing it is (0 standing, 1 gone), set by the piece.
var withdraw := 0.0
## Its seals now: how many stand of how many (a broken one dark), set by the piece.
var seals_up := 2
var seals_all := 2

const SEAL_SEGMENTS := 8
const RING_SEGMENTS := 18
const SEAL_GLOW := 1.6
const SEAL_DEAD := 0.06
const HEART_GLOW := 0.9
const VEIN_GLOW := 0.5
const RING_GLOW := 0.4
## Its core's middle over the floor, the core's plates' reach and size, the spikes' roots.
const CORE_H := 2.45
const CORE_R := 0.95
const PLATE := 0.85
const ROOT_R := 0.7
## The spikes never point lower than this (the legs own the ground under it): the up part of their way.
const SPIKE_LOW := -0.35

var _heart := -1
var _plates: Array[int] = []
var _plate_way: Array[Vector3] = []
var _spikes: Array[int] = []
var _spike_way: Array[Vector3] = []
var _spike_len := PackedFloat32Array()
var _spike_w := PackedFloat32Array()
var _legs: Array[int] = []
var _leg_a := PackedFloat32Array()
var _leg_r := PackedFloat32Array()
var _veins: Array[int] = []
var _vein_way: Array[Vector3] = []
var _seals: Array = []  # per seal, its segments' ids
var _seal_tilt := PackedFloat32Array()
var _seal_turn := PackedFloat32Array()
var _ring: Array[int] = []
var _spin := 0.12
var _spin_axis := Vector3.UP
var _breath_hz := 0.3


func _build() -> void:
	ice_color = Palette.BLACK_ICE
	_ice_start()
	glyph_count = 0
	budget_triangles = 3200
	budget_draw_calls = 12
	ai_kind = "black"
	size_low = 1.0
	size_high = 1.0
	reach = AABB(Vector3(-3.6, GROUND_Y - 0.1, -3.6), Vector3(7.2, 7.6, 7.2))
	tag_height = CORE_H + 2.2 - 0.9
	_spin = lerpf(0.08, 0.18, dice(1, 0)) * (1.0 if dice(1, 1) < 0.5 else -1.0)
	_spin_axis = Vector3(lerpf(-0.25, 0.25, dice(1, 2)), 1.0, lerpf(-0.25, 0.25, dice(1, 3))).normalized()
	_breath_hz = lerpf(0.22, 0.4, dice(1, 4))
	_heart = weak(part(Shape.GEM, Look.ICE_LIGHT))
	# The core: plates on a sphere round the heart, facing out, gaps between them.
	var plates := pick(2, 0, 10, 12)
	for i in plates:
		_plates.append(part(Shape.FACET, Look.ICE))
		_plate_way.append(_sphere(i, plates, dice(3, i) * 0.3))
	# The spikes: every way but straight down, long and thin, some longer.
	var n := pick(4, 0, 18, 24)
	for i in n:
		_spikes.append(part(Shape.PRISM, Look.ICE))
		var way := _sphere(i, n, 0.5 + dice(5, i))
		way.y = maxf(way.y, SPIKE_LOW + 0.2 * dice(6, i))
		_spike_way.append(way.normalized())
		_spike_len.append(lerpf(1.3, 2.3, dice(7, i)) * (1.15 if dice(8, i) < 0.2 else 1.0))
		_spike_w.append(lerpf(0.16, 0.26, dice(9, i)))
	# The legs: down to the floor in a ring at its touch's reach.
	var legs := pick(10, 0, 6, 8)
	for i in legs:
		_legs.append(part(Shape.PRISM, Look.ICE))
		_leg_a.append(TAU * (i + 0.5) / legs + (dice(11, i) - 0.5) * 0.35)
		_leg_r.append(lerpf(0.82, 0.95, dice(12, i)))
	# The veins: a few thin lines of cold light out of the heart between the plates.
	for i in pick(13, 0, 3, 5):
		_veins.append(part(Shape.PRISM, Look.ICE_LIGHT))
		_vein_way.append(_sphere(i * 3 + 1, 15, dice(14, i)))
	# Two seals: rings of light crossing round its core, its weak points.
	for s in 2:
		var ring := []
		for k in SEAL_SEGMENTS:
			ring.append(weak(part(Shape.PRISM, Look.ICE_LIGHT)))
		_seals.append(ring)
	_seal_tilt.append(lerpf(0.15, 0.35, dice(15, 0)))
	_seal_tilt.append(lerpf(1.0, 1.3, dice(15, 1)))
	_seal_turn.append(lerpf(0.2, 0.35, dice(16, 0)))
	_seal_turn.append(-lerpf(0.15, 0.3, dice(16, 1)))
	for k in RING_SEGMENTS:
		_ring.append(part(Shape.PRISM, Look.ICE_LIGHT))


## Its own darker glass and dimmer light on its sets (the shared looks are every other ICE's).
func setup(target: Node3D, seed: int = -1) -> void:
	super(target, seed)
	for bin in _set_shape.size():
		if _set_look[bin] == Look.ICE:
			_set_node[bin].material_override = Palette.black_ice_crystal_material()
		elif _set_look[bin] == Look.ICE_LIGHT:
			_set_node[bin].material_override = Palette.black_ice_light_material()


## How many spikes radiate from it and how many legs it stands on (its build), for the checks.
func blade_count() -> int:
	return _spikes.size()


func halo_count() -> int:
	return _legs.size()


## How bright seal `s` burns now, for the checks (0 dark).
func seal_glow(s: int) -> float:
	return part_custom(_seals[s][0]).g if s >= 0 and s < _seals.size() else 0.0


## Way `i` of `n` spread evenly over a sphere (a golden spiral), turned by `twist`.
static func _sphere(i: int, n: int, twist: float) -> Vector3:
	var y := 1.0 - 2.0 * (i + 0.5) / n
	var r := sqrt(maxf(1.0 - y * y, 0.0))
	var a := PI * (3.0 - sqrt(5.0)) * i + twist * TAU
	return Vector3(cos(a) * r, y, sin(a) * r)


func _pose(t: float, _delta: float) -> void:
	var forming := act_u if act == Act.TELL else 1.0
	var reel := (1.0 - smoothstep(0.0, 1.0, act_u)) if act == Act.SCATTER else 0.0
	var moving := 1.0 if act == Act.MOVE else 0.0
	# Arriving and withdrawing are one motion: how far it has come out of nothing.
	var up := smoothstep(0.0, 1.0, clampf(forming, 0.0, 1.0)) * (1.0 - smoothstep(0.0, 1.0, withdraw))
	var floor_y := GROUND_Y
	var bob := 0.07 * sin(t * 0.7 + _seed * 7.0)
	var middle := Vector3(0.0, floor_y + CORE_H + bob - 0.25 * reel, 0.0)
	var turn := Basis(_spin_axis, t * _spin)
	var roll := Basis(Vector3.RIGHT, -0.06 * moving).rotated(Vector3.FORWARD, 0.18 * reel * sin(t * 23.0))
	var frame := roll * turn
	# The ring on the floor at its touch's reach: first to come, last to go.
	var ring_on := clampf(forming * 4.0, 0.0, 1.0) * (1.0 - clampf((withdraw - 0.7) / 0.3, 0.0, 1.0))
	for k in _ring.size():
		if k % 3 == 2 or ring_on <= 0.01:
			conceal(_ring[k])
			continue
		var a0 := TAU * k / _ring.size() + t * 0.05
		var a1 := a0 + TAU / _ring.size() * 0.8
		var r := touch_m * lerpf(0.4, 1.0, ring_on)
		bone(_ring[k], Vector3(sin(a0) * r, floor_y + 0.02, -cos(a0) * r), Vector3(sin(a1) * r, floor_y + 0.02, -cos(a1) * r), 0.05, 0.012, Vector3.UP)
		brighten(_ring[k], RING_GLOW * ring_on * (0.8 + 0.2 * sin(t * 1.3 + k)))
	# The core: its plates closing in from far out round the heart as it forms.
	var close := smoothstep(0.0, 0.6, up)
	for i in _plates.size():
		if close <= 0.01:
			conceal(_plates[i])
			continue
		var way: Vector3 = frame * _plate_way[i]
		var at := middle + way * CORE_R * lerpf(3.0, 1.0, close)
		var face := plank(way.cross(Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT).normalized(), way.cross(way.cross(Vector3.UP if absf(way.y) < 0.95 else Vector3.RIGHT)).normalized())
		lay(_plates[i], at, Basis(face.x * PLATE, way * 0.3, face.z * PLATE))
		present(_plates[i], close)
	# The spikes: out of the core, breathing; drawn in when it reels.
	var grow := smoothstep(0.35, 0.95, up) * (1.0 - 0.35 * reel)
	for i in _spikes.size():
		if grow <= 0.01:
			conceal(_spikes[i])
			continue
		var way: Vector3 = frame * _spike_way[i]
		var breath := 1.0 + 0.07 * sin(TAU * _breath_hz * t + i * 0.9)
		var root := middle + way * ROOT_R
		bone(_spikes[i], root, root + way * _spike_len[i] * grow * breath, _spike_w[i], _spike_w[i])
		present(_spikes[i], grow)
	# The legs: down from the core to the floor at its touch's reach, stepping a little as it moves.
	var stand := smoothstep(0.3, 0.9, up)
	for i in _legs.size():
		if stand <= 0.01:
			conceal(_legs[i])
			continue
		var a := _leg_a[i] + 0.06 * moving * sin(t * 5.0 + i * 2.1)
		var foot := Vector3(sin(a) * touch_m * _leg_r[i], floor_y + 0.04 + 0.08 * moving * maxf(sin(t * 5.0 + i * 2.1), 0.0), -cos(a) * touch_m * _leg_r[i])
		var hip := middle + Vector3(sin(a), -0.55, -cos(a)).normalized() * ROOT_R
		bone(_legs[i], hip, hip.lerp(foot, stand), 0.24, 0.24)
		present(_legs[i], stand)
	# The heart and its veins: dim cold light seen between the plates.
	var lit := clampf((forming - 0.7) / 0.3, 0.0, 1.0) * (1.0 - smoothstep(0.0, 0.6, withdraw))
	if lit > 0.01:
		orient(_heart, middle, frame * Vector3.UP, 0.75, 0.75)
		brighten(_heart, HEART_GLOW * lit * (0.85 + 0.15 * sin(t * 0.9)) * (1.0 + 2.0 * reel))
		for i in _veins.size():
			var way: Vector3 = frame * _vein_way[i]
			bone(_veins[i], middle + way * 0.25, middle + way * (CORE_R + 0.25), 0.03, 0.03)
			brighten(_veins[i], VEIN_GLOW * lit)
	else:
		conceal(_heart)
		for v in _veins:
			conceal(v)
	# The seals: two rings of light crossing round the core, turning, lit last; a broken one dark.
	for s in _seals.size():
		var ring: Array = _seals[s]
		var r := CORE_R + 0.32 + 0.12 * s
		var tilt := Basis(Vector3.UP, t * _seal_turn[s]) * Basis(Vector3.RIGHT, _seal_tilt[s])
		var broken := s >= seals_up
		var stutter := 1.0 if fmod(t * 7.0 + s, 1.0) >= 0.5 else 0.5
		var glow: float = (SEAL_DEAD * stutter if broken else SEAL_GLOW * (1.0 + 1.5 * reel)) * lit
		for k in ring.size():
			if lit <= 0.01:
				conceal(ring[k])
				continue
			var a0 := TAU * (k + 0.06) / ring.size()
			var a1 := TAU * (k + 0.94) / ring.size()
			var p0 := middle + tilt * Vector3(sin(a0) * r, 0.0, -cos(a0) * r)
			var p1 := middle + tilt * Vector3(sin(a1) * r, 0.0, -cos(a1) * r)
			bone(ring[k], p0, p1, 0.075, 0.05, tilt * Vector3.UP)
			brighten(ring[k], glow)


func _muzzle() -> Vector3:
	return Vector3(0.0, GROUND_Y + CORE_H, 0.0)
