extends DaemonArt
## The SYN flood (W5, the packet tracer's boss, PRD 5.5): the thing at the trace's last hop, opening connection after
## connection and never finishing one, given a body. Its own form, a gyroscope of a router: three great armoured rings
## turning on their own axes round a white-red heart (its weak point), the outer ring studded with ports that flash as they
## fire, broken casing plates orbiting inside, and streams of SYN packets pouring out of the heart through the rings in
## every direction, the flood. Its light is the hostile red, its heart burning to white.
##
## Its brain is a pegged core's ("pegged"): it rises over the core's dais and turns there, and before every fanned volley
## (its tell) its rings swing into one plane and spin up, the heart flaring; each bolt snaps them out (the strike). The
## mode sets `flood` (0 to 1) as it floods: every port flashes and the streams double, a wave of retransmits thrown off it.
## Hurt, its rings wobble off true.
##
## No two alike (A5's rule): its seed sets its rings' tilts and speeds, how many ports, the casing's plates and a scorched
## plate or a flickering port. Never an elite: it is the boss.

const FLOOD_RED := Color(1.0, 0.2, 0.333)
const HEAT := Color(1.0, 0.94, 0.86)
const RINGS := [1.45, 2.0, 2.55]
const HEART_M := 0.62
const STREAMS := 18
const BOX := Vector3(4.6, 4.6, 4.6)
const LAMP_REACH := 22.0

## Set by the mode: 0 calm to 1 at the height of a flood.
var flood := 0.0

var _rings := PackedInt32Array()
var _ring_axes: Array[Vector3] = []
var _ring_speed := PackedFloat32Array()
var _ring_angle := PackedFloat32Array()
var _ports := PackedInt32Array()
var _casing := PackedInt32Array()
var _streams := PackedInt32Array()
var _heart: int
var _halo: int
var _lamp: OmniLight3D = null


func _build() -> void:
	ai_kind = "pegged"
	core_color = FLOOD_RED
	edge_color = FLOOD_RED
	gutter = 1.4
	glyph_count = 14
	glyph_radius = 3.0
	glyph_low = -2.2
	glyph_high = 2.4
	glyph_size = 0.24
	glyph_turns = 0.06
	reach = AABB(Vector3(-3.2, -3.0, -3.2), Vector3(6.4, 6.6, 6.4))
	tag_height = 3.2
	budget_triangles = 9000
	budget_draw_calls = 14
	size_low = 1.0
	size_high = 1.0
	elite_size = 1.0
	elite = false
	for k in RINGS.size():
		_rings.append(part(Shape.RING, Look.ARMOR))
		_ring_axes.append(Vector3(dice(60, k) - 0.5, 0.6, dice(61, k) - 0.5).normalized())
		_ring_speed.append(lerpf(0.35, 0.9, dice(62, k)) * (-1.0 if k % 2 == 1 else 1.0))
		_ring_angle.append(TAU * dice(63, k))
	for k in pick(64, 0, 10, 14):
		_ports.append(seam(part(Shape.HEX, Look.CORE)))
	for k in pick(65, 0, 5, 8):
		_casing.append(part(Shape.PLATE, Look.ARMOR))
	for k in STREAMS:
		_streams.append(part(Shape.STREAK, Look.TRAIL))
	_heart = weak(part(Shape.GEM, Look.CORE))
	_halo = seam(part(Shape.RING, Look.CORE))
	if dice(66, 0) < 0.6:
		scorch(_casing[pick(67, 0, 0, _casing.size() - 1)], lerpf(0.5, 1.0, dice(68, 0)))
	if dice(69, 0) < 0.5:
		flicker(_ports[pick(70, 0, 0, _ports.size() - 1)], lerpf(0.3, 0.6, dice(71, 0)))
	_lamp = OmniLight3D.new()
	_lamp.name = "FloodLamp"
	_lamp.light_color = FLOOD_RED
	_lamp.omni_range = LAMP_REACH
	_lamp.omni_attenuation = 1.2
	_lamp.shadow_enabled = false
	add_child(_lamp)


func _pose(t: float, delta: float) -> void:
	var hurt := _hurt()
	var tell := drive_amount() if act == Act.TELL else 0.0
	var snap := (1.0 - act_u) * drive_amount() if act == Act.STRIKE else 0.0
	var middle := recoil() * 2.0 + Vector3(0.0, 0.15 * sin(t * 0.7), 0.0)
	var beat := pow(maxf(sin(TAU * (0.8 + 1.2 * flood + 1.5 * tell) * t), 0.0), 4.0)
	# The rings: each on its own tilted axis, swinging flat and spinning up in the tell, wobbling hurt.
	var flat := Basis.IDENTITY
	for k in _rings.size():
		_ring_angle[k] = fmod(_ring_angle[k] + _ring_speed[k] * (1.0 + 4.0 * tell + 1.5 * flood) * delta, TAU)
		var axis := _ring_axes[k].lerp(Vector3.UP, tell).normalized()
		var wobble := Basis(Vector3(sin(t * 3.0 + k), 0.0, cos(t * 2.0 + k)).normalized(), 0.12 * hurt * sin(t * 7.0 + k))
		var frame := wobble * Basis(axis, _ring_angle[k])
		var r: float = RINGS[k] * (1.0 + 0.12 * snap - 0.08 * tell)
		orient(_rings[k], middle, frame * axis, 0.3, r * 2.0)
		if k == _rings.size() - 1:
			flat = frame
	# The ports round the outer ring, flashing as it fires and floods.
	var outer: float = RINGS[RINGS.size() - 1] * (1.0 + 0.12 * snap - 0.08 * tell)
	var axis_o := _ring_axes[_ring_axes.size() - 1].lerp(Vector3.UP, tell).normalized()
	var side := axis_o.cross(Vector3.FORWARD if absf(axis_o.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var other := axis_o.cross(side)
	for k in _ports.size():
		var a := _ring_angle[_ring_angle.size() - 1] + TAU * float(k) / _ports.size()
		var out := side * cos(a) + other * sin(a)
		orient(_ports[k], middle + out * outer, out, 0.3, 0.5)
		var fire := pow(maxf(sin(t * 6.0 + k * 1.3), 0.0), 8.0)
		brighten(_ports[k], 0.9 + 1.4 * fire + 3.0 * flood + 2.5 * snap)
	# Casing plates orbiting inside, broken off what it was.
	for k in _casing.size():
		var a := t * 0.5 + TAU * float(k) / _casing.size()
		var p := middle + Vector3(cos(a) * 1.0, 0.35 * sin(a * 2.0 + k), sin(a) * 1.0)
		lay(_casing[k], p, Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.6 * sin(t + k)) * Basis.from_scale(Vector3(0.5, 0.09, 0.62)))
	# The flood: SYN streams pouring out of the heart through the rings, each on its own line.
	for k in _streams.size():
		var u := fposmod(t * (0.7 + 0.9 * flood) + float(k) * 0.618034, 1.0)
		var dir := Vector3(sin(k * 2.399) * sqrt(1.0 - pow(fposmod(k * 0.37, 2.0) - 1.0, 2.0)), fposmod(k * 0.37, 2.0) - 1.0, cos(k * 2.399) * sqrt(1.0 - pow(fposmod(k * 0.37, 2.0) - 1.0, 2.0))).normalized()
		var from := middle + dir * (HEART_M + u * 3.4)
		bone(_streams[k], from, from + dir * (0.35 + 0.5 * flood), 0.06 + 0.04 * flood)
		brighten(_streams[k], (1.0 - u) * (1.2 + 2.0 * flood + 1.0 * tell))
	orient(_heart, middle, flat * Vector3.UP, HEART_M * (1.0 + 0.35 * beat + 0.4 * tell), HEART_M * 0.9)
	brighten(_heart, 2.4 + 1.4 * beat + 3.5 * tell + 2.0 * flood + 1.5 * hurt)
	orient(_halo, middle, Vector3.UP, 0.05, HEART_M * 3.0 * (1.0 + 0.25 * beat))
	brighten(_halo, 1.0 + 2.5 * tell + 1.5 * flood)
	if _lamp != null:
		_lamp.position = middle
		_lamp.light_color = FLOOD_RED.lerp(HEAT, 0.35 * tell + 0.2 * beat)
		_lamp.light_energy = (2.6 + 1.5 * beat + 4.0 * tell + 3.0 * snap + 2.5 * flood) * ArenaArt.light_level


func _hurt() -> float:
	if _target == null or not _target.has_method("health") or not ("max_health" in _target):
		return 0.0
	return clampf(1.0 - float(_target.health()) / maxf(float(_target.max_health), 0.001), 0.0, 1.0)


## Where its lineage line meets it, and its volleys leave (world space): its heart.
func anchor() -> Vector3:
	return global_transform * Vector3.ZERO if is_inside_tree() else transform.origin


func _muzzle() -> Vector3:
	return Vector3.ZERO


func body_box() -> Transform3D:
	return Transform3D.IDENTITY


func body_box_size() -> Vector3:
	return BOX
