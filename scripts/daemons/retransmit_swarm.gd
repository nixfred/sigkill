extends DaemonArt
## A retransmit swarm (W5, the packet tracer, PRD 5.5): a burst of packets that would not be acknowledged, sent again and
## again, given a body. A train of armoured packets flying as one: a lead packet (a slab of near-black armour, its header
## burning in the swarm's yellow, a checksum gem on its back, its weak point, a pair of ACK chevrons wheeling round its
## nose) and four to seven segments snaking behind it down the path it flew, each a smaller slab with its own lit header
## and its sequence marks. It weaves in a lazy figure eight round its spot; its tell coils the whole train into a ring,
## headers flaring; its strike throws the train out straight and lunging, trails streaming. It flies and dives as the
## runaway's brain flies any swarm ("swarm").
##
## Retransmitted: killed once it is sent again (the mode forks a copy, smaller, "dup", where it fell); a copy is not.
##
## No two alike (A5's rule): its seed sets how many segments, how far apart, how wide it weaves, its chevrons (one pair or
## two), its slabs' proportions and a header or two flickering. Never an elite. Faceless: armour and light.

const DUP_YELLOW := Color(1.0, 0.902, 0.0)
const SLAB := Vector3(0.62, 0.14, 0.86)
const SEG := 0.68
const HISTORY := 96
const WEAVE_M := 0.85

var _lead: int
var _lead_head: int
var _checksum: int
var _chevrons := PackedInt32Array()
var _slabs := PackedInt32Array()
var _heads := PackedInt32Array()
var _marks := PackedInt32Array()
var _trails := PackedInt32Array()
var _segments := 5
var _gap := 0.42
var _weave := 1.0
var _proportion := 1.0
var _path := PackedVector3Array()
var _path_at := 0
var _phase := 0.0
var _tick := 0.0


func _build() -> void:
	ai_kind = "swarm"
	core_color = DUP_YELLOW
	edge_color = DUP_YELLOW
	glyph_count = 5
	glyph_radius = 1.2
	glyph_low = -0.4
	glyph_high = 0.9
	glyph_size = 0.12
	glyph_turns = 0.2
	reach = AABB(Vector3(-2.0, -1.0, -2.4), Vector3(4.0, 3.0, 4.8))
	tag_height = 1.9
	budget_triangles = 3000
	budget_draw_calls = 8
	size_low = 0.9
	size_high = 1.1
	elite_size = 1.1
	elite = false
	_segments = pick(60, 0, 4, 7)
	_gap = lerpf(0.36, 0.5, dice(61, 0))
	_weave = lerpf(0.8, 1.25, dice(62, 0))
	_proportion = lerpf(0.85, 1.2, dice(63, 0))
	_phase = TAU * dice(64, 0)
	_lead = part(Shape.PLATE, Look.ARMOR)
	_lead_head = seam(part(Shape.CUBE, Look.CORE))
	_checksum = weak(part(Shape.GEM, Look.CORE))
	for k in (4 if dice(65, 0) < 0.4 else 2):
		_chevrons.append(part(Shape.BLADE, Look.ARMOR))
	for k in _segments:
		_slabs.append(part(Shape.PLATE, Look.ARMOR))
		_heads.append(seam(part(Shape.CUBE, Look.CORE)))
		_marks.append(part(Shape.STREAK, Look.CORE))
		_trails.append(part(Shape.STREAK, Look.TRAIL))
	for k in pick(66, 0, 0, 2):
		flicker(_heads[pick(67, k, 0, _segments - 1)], lerpf(0.35, 0.7, dice(68, k)))
	_path.resize(HISTORY)
	for i in HISTORY:
		_path[i] = Vector3(0.0, 0.0, float(i) * 0.05)


## The lead's place now (art space): weaving a figure eight round the spot, coiled in the tell, lunging in the strike.
func _lead_at(t: float) -> Vector3:
	var a := t * 1.25 * _weave + _phase
	return Vector3(sin(a) * WEAVE_M * _weave, 0.15 * sin(a * 2.0 + 0.6), sin(a * 2.0) * WEAVE_M * 0.55) + recoil()


func _pose(t: float, delta: float) -> void:
	var tell := drive_amount() if act == Act.TELL else 0.0
	var strike := drive_amount() if act == Act.STRIKE else 0.0
	var lead := _lead_at(t)
	# The path the lead flew, sampled a twentieth of a second apart; the segments ride it behind.
	_tick += delta
	if _tick >= 0.02:
		_tick = 0.0
		_path_at = (_path_at + 1) % HISTORY
		_path[_path_at] = lead
	var lead_dir := (lead - _path[(_path_at - 2 + HISTORY) % HISTORY])
	if lead_dir.length_squared() < 0.000001:
		lead_dir = Vector3.FORWARD
	lead_dir = lead_dir.normalized()
	var places: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	for k in _segments:
		var trail_p := _trail_point(float(k + 1) * _gap)
		var ring_a := TAU * float(k + 1) / float(_segments + 1) + t * 3.0
		var coil := Vector3(cos(ring_a), 0.1 * sin(ring_a * 3.0), sin(ring_a)) * 0.8
		var line := Vector3(0.0, 0.0, float(k + 1) * SEG * 0.9)
		var p := trail_p.lerp(coil, tell).lerp(line + Vector3(0.0, 0.0, -1.2 * strike), strike)
		places.append(p)
	var lead_p := lead.lerp(Vector3.ZERO, tell).lerp(Vector3(0.0, 0.0, -1.4 * strike), strike)
	for k in _segments:
		var ahead := lead_p if k == 0 else places[k - 1]
		var d := ahead - places[k]
		dirs.append(d.normalized() if d.length_squared() > 0.000001 else lead_dir)
	var lead_way := lead_dir.lerp(-(places[0] - lead_p).normalized() if places.size() > 0 else lead_dir, 0.5 * tell).lerp(Vector3.FORWARD, strike).normalized()
	_slab(_lead, _lead_head, lead_p, lead_way, 1.25, 1.6 + 2.0 * tell + 1.5 * strike)
	var up := Vector3.UP
	orient(_checksum, lead_p + up * SLAB.y * 0.9, up, 0.2 * (1.0 + 0.4 * tell), 0.16)
	brighten(_checksum, 1.8 + 0.6 * sin(t * 6.0) + 2.4 * tell)
	# The ACK chevrons wheel round its nose.
	for c in _chevrons.size():
		var a := t * 4.0 + TAU * float(c) / _chevrons.size()
		var side := lead_way.cross(up).normalized()
		var root := lead_p + lead_way * SLAB.z * 0.6 + (side * cos(a) + up * sin(a)) * 0.32
		bone(_chevrons[c], root, root + lead_way * 0.34 - (side * cos(a) + up * sin(a)) * 0.18, 0.05, 0.12, up)
	for k in _segments:
		var bright := 1.1 + 0.5 * sin(t * 5.0 - k * 0.8) + 1.6 * tell + 1.2 * strike
		_slab(_slabs[k], _heads[k], places[k], dirs[k], 1.0 - 0.06 * k, bright)
		# Its sequence marks: a short bar across its back, longer down the train.
		var side := dirs[k].cross(up).normalized()
		var mid := places[k] + up * SLAB.y * 0.7
		bone(_marks[k], mid - side * (0.08 + 0.03 * k), mid + side * (0.08 + 0.03 * k), 0.03)
		brighten(_marks[k], 0.9 + 0.6 * tell)
		var back := places[k] - dirs[k] * (0.4 + 1.2 * strike)
		bone(_trails[k], back, places[k] - dirs[k] * SLAB.z * 0.5, 0.06)
		brighten(_trails[k], 0.6 + 1.2 * strike)


## Slab `id` (and its header `head`) at `at` facing `way`, `scale` its size.
func _slab(id: int, head: int, at: Vector3, way: Vector3, scale: float, bright: float) -> void:
	var up := Vector3.UP
	var side := way.cross(up)
	if side.length_squared() < 0.000001:
		side = Vector3.RIGHT
	side = side.normalized()
	var lift := side.cross(way).normalized()
	var s := SLAB * scale * Vector3(1.0, 1.0, _proportion)
	lay(id, at, Basis(side * s.x, lift * s.y, -way * s.z))
	lay(head, at + way * s.z * 0.38 + lift * s.y * 0.15, Basis(side * s.x * 1.04, lift * s.y * 0.75, -way * s.z * 0.16))
	brighten(head, bright)


## The point the lead was `back` metres ago along its path.
func _trail_point(back: float) -> Vector3:
	var gone := 0.0
	var i := _path_at
	var prev := _path[i]
	for n in HISTORY - 1:
		var j := (i - 1 + HISTORY) % HISTORY
		var step := prev.distance_to(_path[j])
		if gone + step >= back and step > 0.0:
			return prev.lerp(_path[j], (back - gone) / step)
		gone += step
		prev = _path[j]
		i = j
	return prev


func _muzzle() -> Vector3:
	return Vector3(0.0, 0.0, -0.6)


## Where its lineage line meets it (world space): its checksum gem.
func anchor() -> Vector3:
	return global_transform * Vector3(0.0, 0.2, 0.0) if is_inside_tree() else transform.origin
