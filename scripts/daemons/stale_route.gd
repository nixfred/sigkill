extends DaemonArt
## A stale route (W5, the packet tracer, PRD 5.5): a route that expired long ago and is still being followed, given a body.
## Its own form: a signpost tower. A mast of dark armour stands on a cracked ring (its TTL, ticking down and never reaching
## zero), and up it four to six arrow signs, each an armoured plate with a blade for a point, turning slowly on its own
## and pointing every way but the right one; at its head a cached route, a gem in the stale grey-blue of old light (its
## weak point), and cobwebs of dead light hanging off the signs. Its light flickers, as an expired thing's does.
##
## It never moves or strikes: the packet tracer stands it at a machine's forward port (its brain is a drone's, "drone"),
## and while it stands a packet boarding there is sent the wrong way. The mode sets `wrong` (the way it points a rider,
## art space) and `misroute` (0 to 1) as it sends one: every sign snaps round to point there, the gem flaring.
##
## No two alike (A5's rule): its seed sets how many signs, their heights, sizes, turning speeds and ways, the mast's lean,
## how much of its light flickers. Never an elite.

const STALE := Color(0.557, 0.627, 0.722)
const MAST_H := 2.9
const SIGN := Vector3(0.72, 0.09, 0.3)

var wrong := Vector3.BACK
var misroute := 0.0

var _mast: int
var _ring: int
var _ring_b: int
var _cache: int
var _signs := PackedInt32Array()
var _points := PackedInt32Array()
var _webs := PackedInt32Array()
var _heights := PackedFloat32Array()
var _turns := PackedFloat32Array()
var _ways := PackedFloat32Array()
var _lean := Basis.IDENTITY


func _build() -> void:
	ai_kind = "drone"
	core_color = STALE
	edge_color = STALE
	glyph_count = 7
	glyph_radius = 0.9
	glyph_low = -0.5
	glyph_high = 2.4
	glyph_size = 0.14
	glyph_turns = 0.03
	reach = AABB(Vector3(-1.4, -1.0, -1.4), Vector3(2.8, 4.4, 2.8))
	tag_height = 3.3
	budget_triangles = 2400
	budget_draw_calls = 7
	size_low = 0.95
	size_high = 1.12
	elite_size = 1.12
	elite = false
	_lean = Basis(Vector3(dice(60, 0) - 0.5, 0.0, dice(60, 1) - 0.5).normalized(), lerpf(0.02, 0.09, dice(61, 0)))
	_mast = part(Shape.LIMB, Look.ARMOR)
	_ring = seam(part(Shape.RING, Look.CORE))
	_ring_b = part(Shape.RING, Look.ARMOR)
	_cache = weak(part(Shape.GEM, Look.CORE))
	var n := pick(62, 0, 4, 6)
	for k in n:
		_signs.append(part(Shape.PLATE, Look.ARMOR))
		_points.append(seam(part(Shape.BLADE, Look.CORE)))
		_heights.append(lerpf(0.6, MAST_H - 0.3, (float(k) + 0.3 * dice(63, k)) / float(n)))
		_turns.append(lerpf(-0.6, 0.6, dice(64, k)))
		_ways.append(TAU * dice(65, k))
	for k in 3:
		_webs.append(part(Shape.STREAK, Look.TRAIL))
	flicker(_cache, lerpf(0.15, 0.4, dice(66, 0)))
	for k in pick(67, 0, 1, 3):
		flicker(_points[pick(68, k, 0, n - 1)], lerpf(0.3, 0.7, dice(69, k)))


func _pose(t: float, _delta: float) -> void:
	var middle := recoil()
	var base := middle + Vector3(0.0, GROUND_Y, 0.0)
	var top := base + _lean * Vector3(0.0, MAST_H + 0.9, 0.0)
	bone(_mast, base, top, 0.16, 0.16)
	orient(_ring, base + Vector3.UP * 0.05, Vector3.UP, 0.06, 1.25 + 0.05 * sin(t * 1.3))
	brighten(_ring, 0.8 + 0.4 * sin(t * 2.0) + 1.5 * misroute)
	orient(_ring_b, base + Vector3.UP * 0.02, Vector3.UP, 0.05, 1.45)
	orient(_cache, top + Vector3.UP * 0.18, Vector3.UP, 0.34 * (1.0 + 0.4 * misroute), 0.26)
	brighten(_cache, 1.6 + 0.5 * sin(t * 2.7) + 3.0 * misroute)
	var flat := Vector3(wrong.x, 0.0, wrong.z)
	var aim := atan2(flat.x, flat.z) if flat.length_squared() > 0.0001 else 0.0
	for k in _signs.size():
		var own := _ways[k] + _turns[k] * t
		var a := lerp_angle(own, aim, misroute)
		var dir := Vector3(sin(a), 0.0, cos(a))
		var side := Vector3(-dir.z, 0.0, dir.x)
		var at := base + _lean * Vector3(0.0, _heights[k] + 0.9, 0.0) + dir * SIGN.x * 0.5
		lay(_signs[k], at, Basis(dir * SIGN.x, Vector3.UP * SIGN.y * 2.2, side * SIGN.z))
		bone(_points[k], at + dir * SIGN.x * 0.48, at + dir * (SIGN.x * 0.48 + 0.32), 0.06, 0.26, Vector3.UP)
		brighten(_points[k], 0.9 + 0.3 * sin(t * 3.0 + k) + 2.0 * misroute)
	# Cobwebs: dead light hanging off the lowest signs, swaying.
	for k in _webs.size():
		var from := base + _lean * Vector3(0.0, _heights[k % _heights.size()] + 0.85, 0.0)
		bone(_webs[k], from, from + Vector3(0.18 * sin(t * 0.9 + k), -0.7 - 0.2 * k, 0.12 * cos(t * 0.7 + k)), 0.025)
		brighten(_webs[k], 0.35)


func _muzzle() -> Vector3:
	return Vector3(0.0, MAST_H, 0.0)


## Where its lineage line meets it (world space): its cached route at the head.
func anchor() -> Vector3:
	return global_transform * Vector3(0.0, GROUND_Y + MAST_H + 1.1, 0.0) if is_inside_tree() else transform.origin
