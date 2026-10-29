extends DaemonArt
## What you see of an ICEbreaker in the arena (I2): a pickup waiting to be taken, or a decoy someone
## threw. The intruder's own programs, in their own ultraviolet, on A5's rig (scripts/daemons/
## daemon_art.gd): solid dark armour with mass whose light lives only in its seams and cores, built
## from a seed (no two alike), posed by transforms alone. Faceless and geometric, never a box and
## never a wireframe.
##
## A pickup (form "pickup"): a split key crystal hovering over a hex plinth, its two armoured halves
## parted round a burning ultraviolet core, a seam of light round each half's waist, three plates
## orbiting it, a few terminal glyphs, a thin beam of light standing from the plinth so it reads from
## across the arena, and its kind's emblem riding over it: brute a ram of two blades, exploit a lens (a
## ring round a gem), cloak a hood of two folded panes round a dim core, decoy a twin pair of shards.
##
## A decoy (form "decoy"): a standing effigy of the intruder's signal, faceless: a crystal spine on a
## hex plinth, shoulder panes, a head of light, seams of light climbing the spine in turn and rings of
## light rolling out over the floor (its call). In flight it is folded small and tumbling (folded 1);
## where it lands it stands up (folded 0). A hit on it (the hunter's lance, a node's field going into
## it) flashes and sprays it; its end bursts it into its own parts.
##
## Art space: the ground at GROUND_Y under the origin, as a daemon's. Visual only.

const Kinds = preload("res://scripts/ice/breakers.gd")

## "pickup" or "decoy", and a pickup's kind (Breakers.Kind); set before setup().
var form := "pickup"
var kind := 0
## A decoy in flight: 1 folded small, 0 standing. Its call's share left, 1 thrown to 0 spent.
var folded := 0.0
var call_left := 1.0

var _halves: Array[int] = []
var _waists: Array[int] = []
var _core := -1
var _plates: Array[int] = []
var _plate_a := PackedFloat32Array()
var _emblem: Array[int] = []
var _emblem_light: Array[int] = []
var _beam := -1
var _static: Array[int] = []
var _static_xf: Array[Transform3D] = []
var _placed := false
var _spine := -1
var _chest: Array[int] = []
var _shoulders: Array[int] = []
var _head := -1
var _climb: Array[int] = []
var _calls: Array[int] = []

var _hover := 0.75
var _spin := 0.6
var _bob := 0.05
var _half_len := 0.34
var _gap := 0.12
var _width := 0.26
var _tall := 1.45

const CORE_GLOW := 2.2
const SEAM_GLOW := 0.6
const BEAM_GLOW := 0.35
## A decoy's call: a ring rolls out every CALL_S, out to CALL_M across.
const CALL_S := 0.9
const CALL_M := 1.6


func _build() -> void:
	core_color = Palette.BREAKER
	edge_color = Palette.BREAKER
	elite = false
	ai_kind = form
	if form == "decoy":
		_build_decoy()
	else:
		_build_pickup()


func _build_pickup() -> void:
	glyph_count = 5
	glyph_radius = 0.55
	glyph_low = -0.25
	glyph_high = 0.5
	glyph_size = 0.1
	budget_triangles = 1600
	budget_draw_calls = 10
	reach = AABB(Vector3(-1.4, GROUND_Y - 0.1, -1.4), Vector3(2.8, 4.0, 2.8))
	tag_height = 1.85
	size_low = 0.94
	size_high = 1.06
	_hover = lerpf(0.7, 0.84, dice(1, 0))
	_spin = lerpf(0.45, 0.8, dice(2, 0)) * (1.0 if dice(2, 1) < 0.5 else -1.0)
	_bob = lerpf(0.035, 0.07, dice(3, 0))
	_half_len = lerpf(0.38, 0.48, dice(4, 0))
	_gap = lerpf(0.14, 0.2, dice(4, 1))
	_width = lerpf(0.36, 0.44, dice(5, 0))
	# The plinth: a hex puck on the floor, a seam of light round it, and the beam standing from it.
	var wide := lerpf(0.8, 0.95, dice(6, 0))
	_still(part(Shape.HEX, Look.ARMOR), Transform3D(_axes(Vector3.UP, wide, 0.12, wide, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.06, 0.0)))
	_still(part(Shape.HEX, Look.ARMOR), Transform3D(_axes(Vector3.UP, wide * 0.6, 0.08, wide * 0.6, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.15, 0.0)))
	var plinth_ring := part(Shape.RING, Look.CORE)
	seam(plinth_ring)
	_still(plinth_ring, Transform3D(_axes(Vector3.UP, wide * 1.04, 0.04, wide * 1.04, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.1, 0.0)))
	_beam = part(Shape.STREAK, Look.TRAIL)
	_still(_beam, Transform3D(_axes(Vector3.UP, 0.05, lerpf(2.4, 2.9, dice(6, 1)), 0.05, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.18, 0.0)))
	# The split key crystal round its core.
	for i in 2:
		_halves.append(part(Shape.PRISM, Look.ARMOR))
		var waist := part(Shape.RING, Look.CORE)
		seam(waist)
		_waists.append(waist)
	_core = part(Shape.GEM, Look.CORE)
	# Its orbiting plates.
	for i in 4:
		_plates.append(part(Shape.FACET, Look.ARMOR))
		_plate_a.append(TAU * i / 4.0 + dice(8, i) * 0.5)
	if dice(9, 0) < 0.35:
		flicker(_waists[0], lerpf(0.15, 0.4, dice(9, 1)))
	# Its kind's emblem.
	match kind:
		Kinds.Kind.BRUTE:
			for i in 2:
				_emblem.append(part(Shape.BLADE, Look.ARMOR))
			_emblem_light.append(part(Shape.GEM, Look.CORE))
		Kinds.Kind.EXPLOIT:
			var lens := part(Shape.RING, Look.CORE)
			_emblem_light.append(lens)
			_emblem_light.append(part(Shape.GEM, Look.CORE))
			_emblem.append(part(Shape.HEX, Look.ARMOR))
		Kinds.Kind.CLOAK:
			for i in 2:
				_emblem.append(part(Shape.FACET, Look.ARMOR))
			var dim := part(Shape.GEM, Look.CORE)
			seam(dim)
			_emblem_light.append(dim)
		_:
			for i in 2:
				_emblem.append(part(Shape.PRISM, Look.ARMOR))
			var link := part(Shape.RING, Look.CORE)
			seam(link)
			_emblem_light.append(link)


func _build_decoy() -> void:
	glyph_count = 4
	glyph_radius = 0.6
	glyph_low = -0.1
	glyph_high = 0.9
	glyph_size = 0.1
	budget_triangles = 1600
	budget_draw_calls = 12
	reach = AABB(Vector3(-2.6, GROUND_Y - 0.1, -2.6), Vector3(5.2, 3.2, 5.2))
	tag_height = 1.9
	size_low = 0.95
	size_high = 1.05
	_tall = lerpf(1.35, 1.55, dice(1, 0))
	var wide := lerpf(0.5, 0.62, dice(2, 0))
	_still(part(Shape.HEX, Look.ARMOR), Transform3D(_axes(Vector3.UP, wide, 0.14, wide, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.07, 0.0)))
	var foot := part(Shape.RING, Look.CORE)
	seam(foot)
	_still(foot, Transform3D(_axes(Vector3.UP, wide * 1.05, 0.04, wide * 1.05, Vector3.ZERO), Vector3(0.0, GROUND_Y + 0.12, 0.0)))
	_spine = part(Shape.PRISM, Look.ARMOR)
	for i in 2:
		_chest.append(part(Shape.PLATE, Look.ARMOR))
	for i in 2:
		_shoulders.append(part(Shape.FACET, Look.ARMOR))
	_head = part(Shape.GEM, Look.CORE)
	for i in 3:
		var ring := part(Shape.RING, Look.CORE)
		seam(ring)
		_climb.append(ring)
	for i in 2:
		_calls.append(part(Shape.RING, Look.CORE))


func _still(id: int, xf: Transform3D) -> void:
	_static.append(id)
	_static_xf.append(xf)


## How bright its core (a pickup's) or its head (a decoy's) burns now, for the checks.
func core_glow() -> float:
	var id := _core if form != "decoy" else _head
	return part_custom(id).g if id >= 0 else 0.0


func _pose(t: float, _delta: float) -> void:
	if not _placed:
		_placed = true
		for i in _static.size():
			put(_static[i], _static_xf[i])
	if form == "decoy":
		_pose_decoy(t)
	else:
		_pose_pickup(t)


func _pose_pickup(t: float) -> void:
	var mid := Vector3(0.0, GROUND_Y + _hover + 0.4 + sin(t * 1.6) * _bob, 0.0)
	var turn := Basis(Vector3.UP, t * _spin)
	var breathe := 0.5 + 0.5 * sin(t * 2.4)
	for i in 2:
		var up := Vector3.UP if i == 0 else Vector3.DOWN
		var from := mid + up * (_gap * 0.5)
		put(_halves[i], Transform3D(turn * _axes(up, _width, _half_len, _width, Vector3.ZERO), from))
		var waist := from + up * (_half_len * 0.28)
		put(_waists[i], Transform3D(turn * Basis.from_scale(Vector3(_width * 1.08, 0.035, _width * 1.08)), waist))
		brighten(_waists[i], SEAM_GLOW * (0.8 + 0.4 * breathe))
	orient(_core, mid, Vector3.UP, _gap * 1.5, _gap * 1.2)
	brighten(_core, CORE_GLOW * (0.85 + 0.3 * breathe))
	brighten(_beam, BEAM_GLOW * (0.75 + 0.25 * breathe))
	for i in _plates.size():
		var a := _plate_a[i] - t * _spin * 1.4
		var way := Vector3(cos(a), 0.0, sin(a))
		var at := mid + way * (_width + 0.26) + Vector3.UP * sin(t * 1.3 + i * 2.1) * 0.08
		var face := plank(way.cross(Vector3.UP), Vector3.UP)
		put(_plates[i], Transform3D(Basis(face.x * 0.24, face.y * 0.07, face.z * 0.32), at))
	var top := mid + Vector3.UP * (_gap * 0.5 + _half_len + 0.34)
	var e_turn := Basis(Vector3.UP, -t * 0.9)
	match kind:
		Kinds.Kind.BRUTE:
			# A ram: two blades meeting at a point, a core of light where they meet.
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				var root := top + e_turn * Vector3(side * 0.26, -0.12, 0.0)
				var tip := top + e_turn * Vector3(0.0, 0.2, 0.0)
				bone(_emblem[i], root, tip, 0.08, 0.17, e_turn * Vector3.BACK)
			orient(_emblem_light[0], top + Vector3.UP * 0.2, Vector3.UP, 0.13, 0.13)
			brighten(_emblem_light[0], CORE_GLOW)
		Kinds.Kind.EXPLOIT:
			# A lens: a ring of light upright round a gem, on a small hex.
			put(_emblem_light[0], Transform3D(e_turn * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(0.38, 0.045, 0.38)), top))
			brighten(_emblem_light[0], SEAM_GLOW * 1.6)
			orient(_emblem_light[1], top, Vector3.UP, 0.16, 0.16)
			brighten(_emblem_light[1], CORE_GLOW)
			orient(_emblem[0], top + Vector3.DOWN * 0.25, Vector3.UP, 0.08, 0.2)
		Kinds.Kind.CLOAK:
			# A hood: two panes folded over a dim core.
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				var way := e_turn * Vector3(side, 0.0, 0.0)
				var face := plank(e_turn * Vector3.BACK, way + Vector3.UP * 1.2)
				put(_emblem[i], Transform3D(Basis(face.x * 0.32, face.y * 0.06, face.z * 0.38), top + way * 0.13))
			orient(_emblem_light[0], top + Vector3.DOWN * 0.03, Vector3.UP, 0.13, 0.13)
			brighten(_emblem_light[0], SEAM_GLOW)
		_:
			# A twin: two shards standing side by side, a ring of light binding them.
			for i in 2:
				var side := -1.0 if i == 0 else 1.0
				bone(_emblem[i], top + e_turn * Vector3(side * 0.11, -0.19, 0.0), top + e_turn * Vector3(side * 0.11, 0.22, 0.0), 0.11)
			put(_emblem_light[0], Transform3D(e_turn * Basis.from_scale(Vector3(0.42, 0.045, 0.22)), top))
			brighten(_emblem_light[0], SEAM_GLOW * 1.6)


func _pose_decoy(t: float) -> void:
	var stand := 1.0 - clampf(folded, 0.0, 1.0)
	var kick := recoil() * 0.6
	# Folded small and tumbling in flight, standing up where it lands.
	var tumble := Basis(Vector3(1.0, 0.4, 0.2).normalized(), t * 9.0 * folded)
	var shrink := lerpf(0.35, 1.0, stand)
	var base := Vector3(0.0, GROUND_Y, 0.0)
	var low := Basis.from_scale(Vector3.ONE * shrink) * tumble
	var spine_from := base + Vector3.UP * 0.12
	put(_spine, Transform3D(low * _axes(Vector3.UP, 0.3, _tall - 0.25, 0.3, Vector3.ZERO), spine_from + kick))
	var chest := spine_from + low * Vector3.UP * ((_tall - 0.25) * 0.72) + kick
	# A torso of two plates, front and back, the spine's light between them.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var at := chest + low * Vector3(0.0, -0.06, side * 0.13)
		# Its own Y (the bevelled top) outward, its length up: right-handed either side.
		put(_chest[i], Transform3D(low * Basis(Vector3(0.36, 0.0, 0.0), Vector3(0.0, 0.0, 0.07 * side), Vector3(0.0, -0.46 * side, 0.0)), at))
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var way := low * Vector3(side, 0.15, 0.0)
		var face := plank(low * Vector3.BACK, way + low * Vector3.UP * 0.6)
		put(_shoulders[i], Transform3D(Basis(face.x * 0.44 * shrink, face.y * 0.1 * shrink, face.z * 0.36 * shrink), chest + low * Vector3.UP * 0.16 + way * 0.28))
	var head := spine_from + low * Vector3.UP * (_tall + 0.02) + kick
	var pulse := 0.5 + 0.5 * sin(t * TAU / CALL_S)
	orient(_head, head, low * Vector3.UP, 0.34 * shrink, 0.28 * shrink)
	# Its light dims and stutters as its call runs out.
	var stutter := 1.0 if call_left > 0.25 or fmod(t * 7.0, 1.0) < 0.6 else 0.35
	brighten(_head, CORE_GLOW * (0.7 + 0.5 * pulse) * stutter)
	for i in _climb.size():
		var u := fmod(t / CALL_S + float(i) / _climb.size(), 1.0)
		var at := spine_from + low * Vector3.UP * ((_tall - 0.25) * u)
		var size := lerpf(0.56, 0.36, u)
		put(_climb[i], Transform3D(low * Basis.from_scale(Vector3(size, 0.035, size)), at + kick))
		brighten(_climb[i], SEAM_GLOW * 2.0 * (1.0 - u) * stutter)
	for i in _calls.size():
		var u := fmod(t / CALL_S + i * 0.5, 1.0)
		if stand < 0.99:
			conceal(_calls[i])
			continue
		var size := lerpf(0.7, CALL_M * 2.0, u)
		put(_calls[i], Transform3D(Basis.from_scale(Vector3(size, 0.015, size)), base + Vector3.UP * 0.03))
		brighten(_calls[i], SEAM_GLOW * 1.3 * (1.0 - u) * (1.0 - u) * stutter)


func _muzzle() -> Vector3:
	return Vector3(0.0, GROUND_Y + _tall, 0.0) if form == "decoy" else Vector3(0.0, GROUND_Y + _hover + 0.4, 0.0)
