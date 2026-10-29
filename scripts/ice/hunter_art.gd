extends IceArt
## Hunter ICE (I1): mobile ICE that tracks the intruder by sight. A hovering crystal hunter with a
## clear silhouette: a hull like a cut lens, two faceted crystal carapaces meeting at a rim of cobalt
## light, pointed the way it faces, its heart of light at its nose (its weak point); swept crystal
## blades out of both sides with a spine of light along each; shield satellites, faceted crystal
## plates with a lit crest, turning round it in a tilted ring; crystal tails hanging under it and, on
## most, a crystal fin. Faceless and geometric.
##
## Its tell (Act.TELL, u 0 to 1): the shields swing round to its front and close into a ring about
## its nose, a lance forming, the heart burns brighter and a thin trace of cobalt light reaches from
## its nose to its prey, following it (aim_world, trace_len, set by the hunter each frame); for the
## tell's last lock_share the trace holds still and flashes: the moment to step aside. Its strike
## (Act.STRIKE): the lance, a bar of light along the trace, fading as the shields swing back. It adapts
## (the director's word): its crystal and its shields' and blades' spines shift from cobalt toward the
## colour of the weapon it has learned to resist (tint()), so the intruder sees what it countered;
## its heart and its rim stay cobalt.
##
## Its seed rolls its hull (length, width, thickness), its blades (how many, how long, how swept),
## its shields (how many, how big, how far out, the ring's tilt and turn), its tails, its fin, how it
## bobs and rolls, and a flickering spine or two. Art space: the body's centre 0.9 over the floor at
## the origin, as a daemon's; it hovers with its middle `hover` over the floor.

## Its middle over the floor (the tuning's hunter_hover_m), set before setup().
var hover := 1.35
## The way it aims (world space, a unit vector) and how long its trace reaches, metres; set by the
## hunter every frame of a tell or a strike.
var aim_world := Vector3.FORWARD
var trace_len := 8.0
## The share of the tell, at its end, in which the trace holds still (the lock), set by the hunter.
var lock_share := 0.27

var _top := -1
var _bottom := -1
var _rim := -1
var _heart := -1
var _fin := -1
var _trace := -1
var _lance := -1
var _blades: Array[int] = []
var _blade_spines: Array[int] = []
var _blade_side := PackedFloat32Array()
var _blade_k := PackedInt32Array()
var _shields: Array[int] = []
var _spines: Array[int] = []
var _tails: Array[int] = []
var _tail_len := PackedFloat32Array()
var _hull := Vector3(1.05, 0.26, 1.45)
var _blade_len := 0.9
var _blade_sweep := 0.5
var _shield := Vector2(0.42, 0.55)
var _orbit := 1.0
var _orbit_tilt := 0.3
var _orbit_turn := 0.5
var _bob_hz := 0.6

const HEART_GLOW := 1.2
const HEART_FLARE := 2.6
const RIM_GLOW := 0.6
const TRACE_W := 0.022
const LOCK_W := 0.04
const LANCE_W := 0.12


func _build() -> void:
	ice_color = Palette.HUNTER_COBALT
	_ice_start()
	glyph_count = 0
	budget_triangles = 3000
	budget_draw_calls = 14
	ai_kind = "hunter"
	size_low = 1.3
	size_high = 1.42
	# Its lance reaches far past its body: the culling box takes the whole reach of it.
	reach = AABB(Vector3(-24.0, GROUND_Y - 4.0, -24.0), Vector3(48.0, 12.0, 48.0))
	tag_height = hover + 1.1
	_hull = Vector3(lerpf(1.25, 1.5, dice(1, 0)), lerpf(0.32, 0.42, dice(1, 1)), lerpf(1.75, 2.1, dice(1, 2)))
	_blade_len = lerpf(1.0, 1.45, dice(2, 0))
	_blade_sweep = lerpf(0.35, 0.8, dice(2, 1))
	_shield = Vector2(lerpf(0.5, 0.62, dice(3, 0)), lerpf(0.66, 0.82, dice(3, 1)))
	_orbit = lerpf(1.3, 1.6, dice(4, 0))
	_orbit_tilt = lerpf(0.15, 0.45, dice(4, 1))
	_orbit_turn = lerpf(0.35, 0.7, dice(4, 2)) * (1.0 if dice(4, 3) < 0.5 else -1.0)
	_bob_hz = lerpf(0.45, 0.8, dice(5, 0))
	_top = part(Shape.FACET, Look.ICE)
	_bottom = part(Shape.FACET, Look.ICE)
	_rim = seam(part(Shape.HEX, Look.ICE_LIGHT))
	_heart = weak(part(Shape.GEM, Look.ICE_LIGHT))
	var flickers := pick(6, 0, 0, 2)
	for i in pick(7, 0, 2, 3) * 2:
		_blades.append(part(Shape.PRISM, Look.ICE))
		var spine := seam(part(Shape.PRISM, Look.ICE_LIGHT))
		_blade_spines.append(spine)
		_blade_side.append(1.0 if i % 2 == 0 else -1.0)
		_blade_k.append(i / 2)
	for i in pick(8, 0, 3, 5):
		_shields.append(part(Shape.SHIELD, Look.ICE))
		var spine := seam(part(Shape.PRISM, Look.ICE_LIGHT))
		if flickers > 0 and dice(9, i) < 0.4:
			flicker(spine, lerpf(0.2, 0.5, dice(10, i)))
			flickers -= 1
		_spines.append(spine)
	for i in pick(11, 0, 1, 3):
		_tails.append(part(Shape.PRISM, Look.ICE))
		_tail_len.append(lerpf(0.35, 0.7, dice(12, i)))
	if dice(13, 0) < 0.65:
		_fin = part(Shape.SHARD, Look.ICE)
	_trace = part(Shape.STREAK, Look.ICE_LIGHT)
	_lance = part(Shape.STREAK, Look.ICE_LIGHT)


## How bright its heart burns now, for the checks and the stills.
func heart_glow() -> float:
	return part_custom(_heart).g if _heart >= 0 else 0.0


## The shield count (its build), for the checks.
func shield_count() -> int:
	return _shields.size()


func _pose(t: float, _delta: float) -> void:
	var tell := act_u if act == Act.TELL else 0.0
	var strike := act_u if act == Act.STRIKE else 0.0
	var reel := staggered()
	var fold := smoothstep(0.0, 0.55, tell) if act == Act.TELL else (1.0 - smoothstep(0.0, 1.0, strike) if act == Act.STRIKE else 0.0)
	var calm := 1.0 - fold
	# Its middle `hover` over the floor at any size (the art is scaled about the ground).
	var mid := hover / size_scale + GROUND_Y + 0.06 * sin(TAU * _bob_hz * t + _seed * 10.0) * calm
	var roll := 0.07 * sin(TAU * _bob_hz * 0.5 * t + 1.3) * calm + reel * 0.5 * sin(t * 18.0)
	var frame := Basis(Vector3.BACK, roll).rotated(Vector3.RIGHT, 0.1 * fold - 0.3 * strike * (1.0 - strike))
	var origin := Vector3(0.0, mid, 0.0) + recoil() + Vector3(0.0, 0.0, 0.3 * strike * (1.0 - strike))
	var fwd := frame * Vector3.FORWARD
	var up := frame * Vector3.UP
	var right := frame * Vector3.RIGHT
	# The hull: two faceted carapaces, crowns up and down, pointed fore and aft, a rim of light between.
	put(_top, Transform3D(Basis(fwd * _hull.z, up * _hull.y, right * _hull.x), origin + up * _hull.y * 0.32))
	put(_bottom, Transform3D(Basis(fwd * _hull.z * 0.9, -up * _hull.y * 0.8, -right * _hull.x * 0.88), origin - up * _hull.y * 0.28))
	put(_rim, Transform3D(Basis(fwd * _hull.z * 1.03, up * 0.035, right * _hull.x * 1.03), origin))
	brighten(_rim, RIM_GLOW * (1.0 + 0.8 * tell))
	var nose := origin + fwd * _hull.z * 0.52
	orient(_heart, nose, fwd, 0.3 * (1.0 + 0.25 * tell), 0.2 * (1.0 + 0.25 * tell))
	brighten(_heart, lerpf(HEART_GLOW, HEART_FLARE, maxf(tell, 1.0 - strike if act == Act.STRIKE else 0.0)))
	if _fin >= 0:
		var fin_from := origin + up * _hull.y * 0.5 - fwd * 0.1
		bone(_fin, fin_from, fin_from + up * 0.38 * (1.0 - 0.3 * fold) - fwd * 0.34, 0.06, 0.22, right)
	# The blades, swept back out of both sides, folding in as the lance forms.
	for i in _blades.size():
		var side := _blade_side[i]
		var k := float(_blade_k[i])
		var root := origin + right * side * _hull.x * 0.3 + fwd * (0.15 - 0.32 * k) * _hull.z
		# Folded, the blades swing forward round the nose like pincers.
		var tip := root + right * side * _blade_len * (1.0 - 0.18 * k) * (1.0 - 0.4 * fold) - fwd * (_blade_sweep + 0.15 * k) * (1.0 - 2.2 * fold) - up * (0.04 * k + 0.05 * sin(t * 1.1 + i))
		bone(_blades[i], root, tip, 0.17, 0.07, up)
		bone(_blade_spines[i], root + up * 0.03, tip + up * 0.03, 0.022)
	# The shields: a tilted ring of satellites turning round it; through the tell they swing to its
	# front and close round its nose.
	var n := _shields.size()
	var tilt := Basis(right, _orbit_tilt)
	for i in n:
		var a := TAU * i / n + t * _orbit_turn
		var ring_way := tilt * (frame * Vector3(cos(a), 0.0, sin(a)))
		var ring_at := origin + ring_way * _orbit
		var ring_face := plank(ring_way.cross(tilt * up).normalized(), (tilt * up).normalized())
		var b := TAU * i / n + t * 0.6
		var radial := frame * Vector3(cos(b), sin(b), 0.0)
		# Folded: an iris of shields round the nose, their crowns to the prey.
		var lance_at := nose + fwd * 0.3 + radial * 0.78
		var lance_face := plank(fwd.cross(radial).normalized(), radial)
		var at := ring_at.lerp(lance_at, fold)
		var face := Basis(ring_face.get_rotation_quaternion().slerp(lance_face.get_rotation_quaternion(), fold))
		put(_shields[i], Transform3D(Basis(face.x * _shield.x, face.y * 0.15, face.z * _shield.y), at))
		var crest := at + face.y * 0.088
		bone(_spines[i], crest - face.z * _shield.y * 0.4, crest + face.z * _shield.y * 0.4, 0.03)
	for i in _tails.size():
		var from := origin - up * _hull.y * 0.4 - fwd * _hull.z * 0.25 + right * (i - (_tails.size() - 1) * 0.5) * 0.14
		var sway := 0.1 * sin(t * 2.1 + i * 1.7)
		bone(_tails[i], from, from + right * sway - up * _tail_len[i] - fwd * _tail_len[i] * 0.6, 0.08)
	# The trace through the tell, the lance at the strike: along the aim, in art space.
	var inverse := global_transform.basis.inverse() if is_inside_tree() else Basis.IDENTITY
	var way := (inverse * aim_world).normalized() if aim_world.length_squared() > 0.0001 else fwd
	var reach_len := trace_len / maxf(size_scale, 0.01)  # art space: the world's metres over its size
	if act == Act.TELL and tell > 0.05:
		var locked := tell >= 1.0 - lock_share
		var blink := 1.0 if not locked or fmod(t * 14.0, 1.0) < 0.6 else 0.35
		var width := LOCK_W if locked else TRACE_W
		bone(_trace, nose, nose + way * reach_len * minf(tell * 3.0, 1.0), width, width)
		brighten(_trace, (2.0 if locked else 1.0) * blink)
	else:
		conceal(_trace)
	if act == Act.STRIKE and strike < 1.0:
		var width := LANCE_W * (1.0 - strike * 0.7)
		bone(_lance, nose, nose + way * reach_len, width, width)
		brighten(_lance, 3.0 * (1.0 - strike))
	else:
		conceal(_lance)


func _muzzle() -> Vector3:
	return Vector3(0.0, hover / size_scale + GROUND_Y, -_hull.z * 0.52)
