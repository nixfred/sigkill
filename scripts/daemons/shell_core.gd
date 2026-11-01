extends DaemonArt
## The shell's true body (M7, mission 7 `kill -9`, docs/STORY.md: "not a hexagon but the shell's true body, the giant
## red-hot lattice core"; the enemy art bar's CPU boss). Not a walker, not a swarm, not a rooted tower or a wheel: a
## lattice the size of a house hanging in the air over the core, turning slowly on a tilted axis. Its cage is an
## icosahedron of thirty armoured struts with a red-hot node at each of its twelve corners; inside it three seam rings
## turn as gimbals on three axes, two collars of armour plates turn against each other round the middle, six shutters
## of armour close round the heart, and the heart, one white-hot gem, beats inside them: its weak point, the one place
## the rail is aimed. Heat streams off the heart in eight trails, and its glyphs orbit it farther out than any
## daemon's. Faceless: armour and light, nothing that moves like an animal.
##
## It moves unlike every earlier enemy: its brain (scripts/fight/daemon_brain.gd, "shell") flies it in a slow orbit over
## its place, bobbing, and it throws volleys of bolts from the heart; the art turns with it. A hit (only the rail's lands;
## the rest are refused by its dummy) blows the cage apart: every strut and node flung out from the middle, tumbling, and
## drawn back in over a second and a half (the world coming apart and recombining, in small); the shutters open wider the
## more it is hurt, so its heart shows more the closer it is to dying, and it burns hotter and turns faster. Shedding a
## runaway (fork_flash(), its mission's stage) flings one corner node out as the child comes off it.
##
## No two alike (A5's rule, though a mission has one): its seed sets its tilt, each ring's and collar's turning speed and
## phase, the struts' lean, a scorched strut or two and a flickering node. Always the same size (never an elite's extra
## parts: it is already the biggest thing in the game). Visual only: its dummy keeps its hit volume (a box round the whole
## cage), its health, its hit cap and its "only the rail" rule.

const STRUTS := 30
const NODES := 12
const RINGS := 3
const COLLARS := 2
const PLATES_PER_COLLAR := 6
const SHUTTERS := 6
const TRAILS := 8
## The cage's radius (art metres), a strut's width, a node's size.
const CAGE_R := 1.9
const STRUT_W := 0.11
const NODE_M := 0.3
## The gimbal rings' radii and the collars' radius; a collar plate's size (along, out, tall).
const RING_R := [1.25, 1.05, 0.85]
const COLLAR_R := 0.72
const PLATE := Vector3(0.52, 0.12, 0.4)
## The shutters: their radius closed and open, a shutter plate's size.
const SHUT_R := 0.42
const SHUT_OPEN := 0.3
const SHUT_PLATE := Vector3(0.36, 0.08, 0.3)
## The heart's size, its beat (a second) at rest and hurt to the bone.
const HEART_M := 0.5
const BEAT_REST := 0.8
const BEAT_HOT := 2.2
## How the cage turns: about the upright and about its tilted axis (radians a second), and the hurt's extra.
const TURN := 0.12
const SPIN := 0.35
const HEAT_SPIN := 0.5
## A hit's blow-apart: how far out the cage flies (a share of its radius) and how long it takes to come back.
const BLOW_OUT := 0.55
const BLOW_S := 1.5
## A shed: how far the node flies out and for how long.
const SHED_OUT := 1.6
const SHED_S := 0.7
## Its hit volume (art space): a box round the cage.
const BOX_SIZE := Vector3(3.6, 3.6, 3.6)
## Its lamp at the heart: reach and energy, the beat's, the blow's and the heat's on top.
const LAMP_REACH := 16.0
const LAMP_ENERGY := 5.0
const LAMP_BEAT := 2.5
const LAMP_BLOW := 4.0
const LAMP_HEAT := 2.0
## The glow a node and a strut's seam show: the cage reads red-hot from far off.
const NODE_GLOW := 1.5
const RING_GLOW := 1.3

var _verts := PackedVector3Array()
var _edges: Array[Vector2i] = []
var _struts := PackedInt32Array()
var _nodes := PackedInt32Array()
var _rings := PackedInt32Array()
var _collars := PackedInt32Array()
var _shutters := PackedInt32Array()
var _trails := PackedInt32Array()
var _heart: int
var _halo: int
var _tilt := 0.0
var _axis := Vector3.UP
var _ring_spin := PackedFloat32Array()
var _ring_phase := PackedFloat32Array()
var _collar_spin := PackedFloat32Array()
var _strut_lean := PackedFloat32Array()
var _strut_tumble := PackedVector3Array()
var _turned := 0.0
var _spun := 0.0
var _rings_turned := PackedFloat32Array()
var _collars_turned := PackedFloat32Array()
var _trail_phase := PackedFloat32Array()
## A hit's blow-apart, 1 as it lands easing to 0; a hit's kick to the spin.
var _blow := 0.0
var _kick := 0.0
## The last shed, and which node flew.
var _shed_at := -1.0
var _shed_node := 0
var _lamp: OmniLight3D = null


func _build() -> void:
	ai_kind = "shell"
	core_color = Palette.HOSTILE_RED
	edge_color = Palette.HOSTILE_RED
	gutter = 1.4
	glyph_count = 22
	glyph_radius = 2.5
	glyph_low = -2.2
	glyph_high = 2.2
	glyph_size = 0.26
	glyph_turns = 0.05
	reach = AABB(Vector3(-2.9, -2.9, -2.9), Vector3(5.8, 5.8, 5.8))
	tag_height = 2.7
	budget_triangles = 9000
	budget_draw_calls = 14
	size_low = 2.4
	size_high = 2.4
	elite_size = 2.4
	_tilt = lerpf(0.25, 0.45, dice(60, 0))
	_axis = (Vector3.UP * cos(_tilt) + Vector3.RIGHT * sin(_tilt)).normalized()
	_turned = TAU * dice(61, 0)
	_lamp = OmniLight3D.new()
	_lamp.name = "CoreLamp"
	_lamp.light_color = Palette.HOSTILE_RED
	_lamp.omni_range = LAMP_REACH
	_lamp.omni_attenuation = 1.1
	_lamp.shadow_enabled = false
	add_child(_lamp)
	_icosahedron()
	for i in STRUTS:
		_struts.append(part(Shape.LIMB, Look.ARMOR))
		_strut_lean.append(lerpf(-0.2, 0.2, dice(62, i)))
		var a := TAU * dice(63, i)
		var b := lerpf(-1.0, 1.0, dice(64, i))
		_strut_tumble.append(Vector3(cos(a) * sqrt(1.0 - b * b), b, sin(a) * sqrt(1.0 - b * b)))
	for i in NODES:
		_nodes.append(weak(seam(part(Shape.GEM, Look.CORE))))
	for k in RINGS:
		_rings.append(seam(part(Shape.RING, Look.CORE)))
		_ring_spin.append(lerpf(0.4, 0.9, dice(65, k)) * (1.0 if k % 2 == 0 else -1.0))
		_ring_phase.append(TAU * dice(66, k))
		_rings_turned.append(0.0)
	for k in COLLARS:
		_collar_spin.append(lerpf(0.3, 0.6, dice(67, k)) * (1.0 if k == 0 else -1.0))
		_collars_turned.append(TAU * dice(68, k))
		for j in PLATES_PER_COLLAR:
			_collars.append(part(Shape.PLATE, Look.ARMOR))
	for i in SHUTTERS:
		_shutters.append(part(Shape.PLATE, Look.ARMOR))
	for i in TRAILS:
		_trails.append(part(Shape.STREAK, Look.TRAIL))
		_trail_phase.append(float(i) / TRAILS)
	_halo = seam(part(Shape.RING, Look.CORE))
	_heart = weak(part(Shape.GEM, Look.CORE))
	# Battle damage: a strut or two scorched, a node flickering.
	for i in pick(69, 0, 1, 2):
		scorch(_struts[pick(70, i, 0, STRUTS - 1)], lerpf(0.5, 1.0, dice(71, i)))
	flicker(_nodes[pick(72, 0, 0, NODES - 1)], lerpf(0.25, 0.5, dice(73, 0)))


## The cage's corners and edges: an icosahedron's, the corners on the unit sphere.
func _icosahedron() -> void:
	var g := (1.0 + sqrt(5.0)) * 0.5
	var raw: Array[Vector3] = []
	for sa in [-1.0, 1.0]:
		for sb in [-1.0, 1.0]:
			raw.append(Vector3(0.0, sa, sb * g))
			raw.append(Vector3(sa, sb * g, 0.0))
			raw.append(Vector3(sb * g, 0.0, sa))
	for v in raw:
		_verts.append(v.normalized())
	for i in raw.size():
		for j in range(i + 1, raw.size()):
			if absf(raw[i].distance_to(raw[j]) - 2.0) < 0.001:
				_edges.append(Vector2i(i, j))


func _pose(t: float, delta: float) -> void:
	var hurt := _hurt()
	_blow = move_toward(_blow, 0.0, delta / BLOW_S)
	_kick = move_toward(_kick, 0.0, 1.2 * delta)
	var out := _blown()
	var beat_hz := lerpf(BEAT_REST, BEAT_HOT, hurt)
	var beat := pow(maxf(sin(TAU * beat_hz * t), 0.0), 5.0)
	var shake := recoil() * 2.0
	_turned = fmod(_turned + TURN * delta, TAU)
	_spun = fmod(_spun + (SPIN + HEAT_SPIN * hurt + _kick) * delta, TAU)
	var frame := Basis(Vector3.UP, _turned) * Basis(_axis, _spun)
	var middle := shake
	# The cage: thirty struts between twelve nodes, flung out from the middle by a hit and drawn back in.
	var r := CAGE_R * (1.0 + BLOW_OUT * out)
	var shed := _shedding()
	for i in STRUTS:
		var e := _edges[i]
		var a: Vector3 = frame * _verts[e.x] * r
		var b: Vector3 = frame * _verts[e.y] * r
		var mid := (a + b) * 0.5
		if out > 0.0:
			# Tumbling as it flies: turned about its own random axis by the blow, out along the way from the middle.
			var tumble := Basis(_strut_tumble[i], out * 1.6)
			var half := (b - a) * 0.5
			var pushed := mid + mid.normalized() * out * 0.5
			a = pushed - tumble * half
			b = pushed + tumble * half
		var lean := Basis(mid.normalized(), _strut_lean[i] * (1.0 - out))
		var flat := lean * mid.normalized()
		bone(_struts[i], a + middle, b + middle, STRUT_W * (1.0 + 0.3 * out), STRUT_W * 0.8, flat)
	for i in NODES:
		var at: Vector3 = frame * _verts[i] * r
		if i == _shed_node and shed > 0.0:
			at += at.normalized() * SHED_OUT * sin(PI * shed)  # the node flung out as a child comes off it
		orient(_nodes[i], at + middle, at.normalized(), NODE_M * (1.0 + 0.4 * beat), NODE_M * 0.8)
		brighten(_nodes[i], NODE_GLOW + 0.9 * beat + 1.2 * hurt + 2.5 * out + 2.0 * (shed if i == _shed_node else 0.0))
	# The gimbals: three seam rings on three axes, each turning its own way.
	for k in RINGS:
		_rings_turned[k] = fmod(_rings_turned[k] + (_ring_spin[k] + _kick * 0.5) * delta, TAU)
		var axis_k := [Vector3.RIGHT, Vector3.UP, Vector3.BACK][k] as Vector3
		var turn := Basis(axis_k, _ring_phase[k] + _rings_turned[k])
		var ring_axis: Vector3 = frame * (turn * [Vector3.UP, Vector3.BACK, Vector3.RIGHT][k])
		var ring_r: float = RING_R[k] * (1.0 + 0.25 * out)
		orient(_rings[k], middle + ring_axis * 0.0, ring_axis, 0.06, ring_r * 2.0)
		brighten(_rings[k], RING_GLOW + 0.5 * beat + 0.8 * hurt + 1.5 * out)
	# The collars: two bands of six plates round the middle, turning against each other, leaning out as it is hurt.
	for k in COLLARS:
		_collars_turned[k] = fmod(_collars_turned[k] + (_collar_spin[k] * (1.0 + 0.8 * hurt) + _kick * (1.0 if k == 0 else -1.0)) * delta, TAU)
		var band := Basis(Vector3.RIGHT, PI * 0.5) if k == 1 else Basis.IDENTITY
		for j in PLATES_PER_COLLAR:
			var a := _collars_turned[k] + TAU * float(j) / PLATES_PER_COLLAR
			var radial: Vector3 = frame * (band * Vector3(cos(a), 0.0, sin(a)))
			var tangent: Vector3 = frame * (band * Vector3(-sin(a), 0.0, cos(a)))
			var up := radial.cross(tangent).normalized()
			var lean := Basis(tangent, 0.35 * hurt + 0.6 * out)
			var basis := lean * Basis(tangent * PLATE.x, radial * PLATE.y, up * PLATE.z)
			lay(_collars[k * PLATES_PER_COLLAR + j], middle + radial * COLLAR_R * (1.0 + 0.4 * out), basis)
	# The shutters round the heart: six plates in a ring, closed at rest, opening as it is hurt and blown.
	var open := clampf(0.25 + 0.75 * hurt + 0.6 * out, 0.0, 1.2)
	for i in SHUTTERS:
		var a := TAU * float(i) / SHUTTERS + _spun * 0.5
		var radial := Vector3(cos(a), 0.0, sin(a))
		var tangent := Vector3(-sin(a), 0.0, cos(a))
		var tip := Basis(tangent, -0.9 * open)
		var basis := frame * (tip * Basis(tangent * SHUT_PLATE.x, radial * SHUT_PLATE.y, Vector3.UP * SHUT_PLATE.z))
		lay(_shutters[i], middle + frame * (radial * (SHUT_R + SHUT_OPEN * open)), basis)
	# The heart and its halo: white-hot, beating, brighter the more it is hurt; blazing as it blows apart.
	orient(_heart, middle, frame * Vector3.UP, HEART_M * (1.0 + 0.25 * beat + 0.4 * out), HEART_M * 0.9 * (1.0 + 0.2 * beat))
	brighten(_heart, 3.2 + 1.6 * beat + 2.0 * hurt + 4.0 * out)
	orient(_halo, middle, frame * _axis, 0.05, (HEART_M * 2.6) * (1.0 + 0.4 * out + 0.1 * beat))
	brighten(_halo, 1.6 + 0.6 * beat + 1.2 * hurt + 2.0 * out)
	# Heat off the heart: eight trails streaming out and round, their roots at the heart, faster as it is hurt.
	for i in TRAILS:
		var u := fposmod(_trail_phase[i] + t * (0.25 + 0.3 * hurt), 1.0)
		var a := TAU * (_trail_phase[i] * 3.0 + u * 0.5)
		var el := sin(TAU * (u + _trail_phase[i]))
		var dir := (frame * Vector3(cos(a) * cos(el * 0.9), sin(el * 0.9), sin(a) * cos(el * 0.9))).normalized()
		var near := HEART_M * 0.8 + 0.1 * beat
		var far := lerpf(0.9, 1.6, u) * (1.0 + 0.3 * out)
		bone(_trails[i], middle + dir * near, middle + dir * far, 0.05 * (1.0 + 0.5 * beat))
		brighten(_trails[i], 1.2 + 0.8 * beat + 1.0 * hurt)
	if _lamp != null:
		_lamp.position = middle
		_lamp.light_energy = (LAMP_ENERGY + LAMP_BEAT * beat + LAMP_BLOW * out + LAMP_HEAT * hurt) * ArenaArt.light_level


## How hurt it is, 0 whole to 1 at death's door, from its dummy's health.
func _hurt() -> float:
	if _target == null or not _target.has_method("health") or not ("max_health" in _target):
		return 0.0
	var most: float = maxf(float(_target.max_health), 0.001)
	return clampf(1.0 - float(_target.health()) / most, 0.0, 1.0)


## A hit's blow-apart now: out fast, back slow, 0 at rest.
func _blown() -> float:
	if _blow <= 0.0:
		return 0.0
	return sin(PI * pow(1.0 - _blow, 0.35))


## A shed in progress, 0 to 1 over SHED_S; 0 between sheds.
func _shedding() -> float:
	var age := since(_shed_at)
	return clampf(age / SHED_S, 0.0, 1.0) if age < SHED_S else 0.0


## Its mission's stage says it sheds a runaway: one corner node flies out as the child comes off it.
func fork_flash() -> void:
	_shed_at = clock()
	_shed_node = (_shed_node + 5) % NODES
	_kick += 0.6


## Where a shed child comes off (world space): the node that flew, at the cage's edge.
func hub() -> Vector3:
	var local: Vector3 = _xf[_nodes[_shed_node]].origin if _nodes.size() > _shed_node else Vector3.ZERO
	return global_transform * local if is_inside_tree() else transform * local


## Where its children's lineage runs to (world space): the heart.
func anchor() -> Vector3:
	return global_transform * Vector3.ZERO if is_inside_tree() else transform.origin


## Where its volleys come from, art space: the heart.
func _muzzle() -> Vector3:
	return Vector3.ZERO


func body_box() -> Transform3D:
	return Transform3D.IDENTITY


func body_box_size() -> Vector3:
	return BOX_SIZE


func _on_hit() -> void:
	_blow = 1.0  # the cage flies apart and comes back
	_kick = 2.4


## How far blown apart it is now, for the checks.
func blown() -> float:
	return _blown()
