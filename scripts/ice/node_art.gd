extends IceArt
## A white ICE node (I1): a sentinel crystal that throws a field over intruders near it. A heart of
## glacier light (its weak point) held in a cage of faceted crystal shields that turn round it, a
## ring of light at its equator, on a tripod of crystal bars over a stepped hex plinth, a crystal
## spike above. Each of the two kinds reads apart at a glance: the jam node's shields close tight
## round its heart and a second ring crosses the first (a gyroscope: a lock), the HUD node's cage is
## open and a crown of antenna spikes with lit tips radiates from it (a broadcast).
##
## Its tell (Act.TELL, u 0 to 1): the shields spread out and spin up, the heart burns brighter and
## the rings swell; its field's firing (Act.STRIKE): the shields slam in and the heart flares, then
## settle. Its seed rolls its shields (how many, how far out, how fast they turn), its plinth, its
## tripod's lean, its spike, its antennas, the ring's tilt and a flickering seam or two.
##
## Art space: the body's centre 0.9 over the floor at the origin, as a daemon's; `kind` ("jam" or
## "hud") is set before setup().

var kind := "jam"

var _heart := -1
var _rings: Array[int] = []
var _ring_tilt := PackedFloat32Array()
var _shields: Array[int] = []
var _shield_a := PackedFloat32Array()
var _shield_h := PackedFloat32Array()
var _antennas: Array[int] = []
var _tips: Array[int] = []
var _ant_a := PackedFloat32Array()
var _ant_y := PackedFloat32Array()
var _static: Array[int] = []
var _static_xf: Array[Transform3D] = []
var _placed := false

var _orbit := 0.38
var _spin := 0.5
var _shield_size := Vector2(0.42, 0.5)
var _heart_y := 0.55
var _ant_len := 0.55

const HEART_GLOW := 1.0
const HEART_FLARE := 2.4
const RING_GLOW := 0.25


func _build() -> void:
	_ice_start()
	glyph_count = 0
	budget_triangles = 2400
	budget_draw_calls = 12
	ai_kind = "node"
	reach = AABB(Vector3(-1.6, GROUND_Y - 0.2, -1.6), Vector3(3.2, 3.4, 3.2))
	tag_height = 2.4
	size_low = 0.94
	size_high = 1.06
	var jam := kind == "jam"
	_orbit = lerpf(0.34, 0.42, dice(1, 0)) if jam else lerpf(0.4, 0.5, dice(1, 0))
	_spin = lerpf(0.35, 0.7, dice(2, 0)) * (1.0 if dice(2, 1) < 0.5 else -1.0)
	_shield_size = Vector2(lerpf(0.38, 0.48, dice(3, 0)), lerpf(0.46, 0.6, dice(3, 1)))
	_heart_y = lerpf(0.5, 0.62, dice(4, 0))
	# The plinth: two stepped hex tiers on the floor.
	var wide := lerpf(0.85, 1.05, dice(5, 0))
	_still(part(Shape.HEX, Look.ICE), Transform3D(_axes(Vector3.UP, wide, 0.22, wide, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.11, 0.0)))
	_still(part(Shape.HEX, Look.ICE), Transform3D(_axes(Vector3.UP, wide * 0.62, 0.16, wide * 0.62, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.29, 0.0)))
	var base_ring := seam(part(Shape.RING, Look.ICE_LIGHT))
	_still(base_ring, Transform3D(_axes(Vector3.UP, wide * 0.7, 0.05, wide * 0.7, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.23, 0.0)))
	# The tripod: three crystal bars leaning in from the plinth to under the heart.
	var lean := lerpf(0.16, 0.3, dice(6, 0))
	for i in 3:
		var a := TAU * i / 3.0 + dice(6, 1) * TAU
		var from := Vector3(cos(a) * wide * 0.36, GROUND_Y + 0.3, sin(a) * wide * 0.36)
		var to := Vector3(cos(a) * lean * 0.4, _heart_y - 0.3, sin(a) * lean * 0.4)
		_still(part(Shape.PRISM, Look.ICE), Transform3D(_axes(to - from, 0.1, from.distance_to(to), 0.1, Vector3.ZERO), from))
	# The heart and its ring(s).
	_heart = weak(part(Shape.GEM, Look.ICE_LIGHT))
	var rings := 2 if jam else 1
	for r in rings:
		var ring := weak(part(Shape.RING, Look.ICE_LIGHT))
		seam(ring)
		_rings.append(ring)
		_ring_tilt.append(lerpf(0.15, 0.35, dice(7, r)) + r * PI * 0.5)
	if dice(8, 0) < 0.4:
		flicker(_rings[0], lerpf(0.2, 0.5, dice(8, 1)))
	# The shields round the heart.
	var count := pick(9, 0, 5, 6) if jam else pick(9, 0, 3, 5)
	for i in count:
		_shields.append(part(Shape.FACET, Look.ICE))
		_shield_a.append(TAU * i / count + (dice(10, i) - 0.5) * 0.25)
		_shield_h.append((dice(11, i) - 0.5) * (0.08 if jam else 0.22))
	# The spike above.
	var spike := lerpf(0.3, 0.55, dice(12, 0))
	_still(part(Shape.PRISM, Look.ICE), Transform3D(_axes(Vector3.UP, 0.14, spike, 0.14, Vector3.ZERO), Vector3(0.0, _heart_y + 0.42, 0.0)))
	# The HUD node's antennas, each with a lit tip.
	if not jam:
		var n := pick(13, 0, 6, 10)
		_ant_len = lerpf(0.45, 0.7, dice(13, 1))
		for i in n:
			_antennas.append(part(Shape.PRISM, Look.ICE))
			_tips.append(part(Shape.GEM, Look.ICE_LIGHT))
			_ant_a.append(TAU * i / n + dice(14, i) * 0.3)
			_ant_y.append(_heart_y + (dice(15, i) - 0.5) * 0.5)


func _still(id: int, xf: Transform3D) -> void:
	_static.append(id)
	_static_xf.append(xf)


## How bright its heart burns now (its tell's warning), for the checks and the stills.
func heart_glow() -> float:
	return part_custom(_heart).g if _heart >= 0 else 0.0


func _pose(t: float, _delta: float) -> void:
	var tell := act_u if act == Act.TELL else 0.0
	var fire := 1.0 - act_u if act == Act.STRIKE else 0.0
	var kick := recoil() * 0.4
	if not _placed:
		_placed = true
		for i in _static.size():
			put(_static[i], _static_xf[i])
	var heart := Vector3(0.0, _heart_y, 0.0) + kick
	var spin := t * _spin * (1.0 + 5.0 * tell * tell) + tell * 2.0
	orient(_heart, heart, Vector3.UP, 0.42 * (1.0 + 0.25 * tell + 0.2 * fire), 0.34 * (1.0 + 0.25 * tell + 0.2 * fire))
	brighten(_heart, lerpf(HEART_GLOW, HEART_FLARE, maxf(tell, fire)))
	for r in _rings.size():
		var tilt := Basis(Vector3.RIGHT, _ring_tilt[r]).rotated(Vector3.UP, t * 0.3 * (r + 1))
		var size := (_orbit * 2.0 + 0.2) * (1.0 + 0.15 * tell - 0.08 * fire)
		put(_rings[r], Transform3D(tilt * Basis.from_scale(Vector3(size, 0.035, size)), heart))
		brighten(_rings[r], RING_GLOW * (1.0 + 1.2 * tell))
	var out := _orbit * (1.0 + 0.6 * tell - 0.25 * fire)
	for i in _shields.size():
		var a := _shield_a[i] + spin
		var way := Vector3(cos(a), 0.0, sin(a))
		var at := heart + way * out + Vector3.UP * _shield_h[i]
		# Its crown faces out from the heart, its long side upright.
		var face := plank(way.cross(Vector3.UP), Vector3.UP)
		put(_shields[i], Transform3D(Basis(face.x * _shield_size.x, face.y * 0.13, face.z * _shield_size.y), at))
	for i in _antennas.size():
		var a := _ant_a[i] - spin * 0.5
		var way := Vector3(cos(a), 0.0, sin(a))
		var from := Vector3(0.0, _ant_y[i], 0.0) + kick + way * 0.12
		var length := _ant_len * (1.0 + 0.35 * tell)
		bone(_antennas[i], from, from + way * length, 0.05)
		orient(_tips[i], from + way * (length + 0.03), way, 0.09, 0.07)
		brighten(_tips[i], lerpf(0.8, 2.0, maxf(tell, fire)))


func _muzzle() -> Vector3:
	return Vector3(0.0, _heart_y, 0.0)
