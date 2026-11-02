extends DaemonArt
## A man-in-the-middle (W5, the packet tracer, PRD 5.5): a tap clamped onto a link, every packet passing through it. Its
## own form, a wiretap's: two armoured jaws (a shell above the cable and a shell below, each three plates curved round it)
## clamped shut on the link, legs gripping the cable fore and aft, two feelers tasting the stream, and a lens at each end of
## it, one face to each machine (the man in the middle shows each side what it wants to see): the lenses are its weak
## points, violet, and a ghost of each flickers a hand's width off it, the copy it shows. Its light is the tap's violet.
##
## The packet tracer flies it (its brain is a drone's, "drone": it stays where the mode clamps it, -Z along its link) and
## tells it when it fights: `tell` (0 to 1) as it draws on the rider, the jaws gaping and the lenses flaring; `snap` (0 to
## 1) as it fires, the jaws biting shut. A packet that meets it stops there (intercepted) while it lives.
##
## No two alike (A5's rule): its seed sets how far it gapes, its legs' reach and splay, its feelers, its lenses' size and a
## flickering lens or plate. Never an elite (one to a link is enough). Faceless: armour and two lenses.

const TAP_VIOLET := Color(0.816, 0.0, 1.0)
const JAW_R := 0.5
const BODY_L := 1.3
const LEG_L := 0.95

## Set by the mode each frame: drawing on the rider, and biting shut as it fires.
var tell := 0.0
var snap := 0.0

var _jaws := PackedInt32Array()
var _lenses := PackedInt32Array()
var _ghosts := PackedInt32Array()
var _rings := PackedInt32Array()
var _legs := PackedInt32Array()
var _feelers := PackedInt32Array()
var _gape := 0.3
var _reach := 1.0
var _splay := 0.5
var _lens_m := 0.24
var _beat := 0.0


func _build() -> void:
	ai_kind = "drone"
	core_color = TAP_VIOLET
	edge_color = TAP_VIOLET
	glyph_count = 6
	glyph_radius = 1.1
	glyph_low = -0.6
	glyph_high = 0.9
	glyph_size = 0.13
	glyph_turns = 0.1
	reach = AABB(Vector3(-1.6, -1.4, -1.8), Vector3(3.2, 2.8, 3.6))
	tag_height = 1.6
	budget_triangles = 2600
	budget_draw_calls = 8
	size_low = 1.0
	size_high = 1.18
	elite_size = 1.18
	elite = false
	_gape = lerpf(0.22, 0.42, dice(60, 0))
	_reach = lerpf(0.85, 1.2, dice(61, 0))
	_splay = lerpf(0.35, 0.7, dice(62, 0))
	_lens_m = lerpf(0.2, 0.3, dice(63, 0))
	_beat = TAU * dice(64, 0)
	for k in 6:
		_jaws.append(part(Shape.PLATE, Look.ARMOR))
	for k in 2:
		_lenses.append(weak(part(Shape.GEM, Look.CORE)))
		_ghosts.append(part(Shape.GEM, Look.TRAIL))
		_rings.append(seam(part(Shape.RING, Look.CORE)))
	for k in 16:
		_legs.append(part(Shape.LIMB, Look.ARMOR))
	for k in (2 if dice(65, 0) < 0.7 else 4):
		_feelers.append(part(Shape.STREAK, Look.CORE))
	if dice(66, 0) < 0.35:
		flicker(_lenses[pick(67, 0, 0, 1)], lerpf(0.25, 0.5, dice(68, 0)))
	if dice(69, 0) < 0.4:
		scorch(_jaws[pick(70, 0, 0, 5)], lerpf(0.4, 0.9, dice(71, 0)))


func _pose(t: float, _delta: float) -> void:
	var hurt := jolt()
	var middle := recoil() + Vector3(0.0, 0.02 * sin(t * 2.3 + _beat), 0.0)
	var open := clampf(_gape * 0.3 + _gape * 1.6 * tell - 0.3 * snap + 0.06 * sin(t * 1.7 + _beat), 0.0, 1.0)
	# The jaws: three plates above the cable and three below, curved round it, the top hinged open by `open`.
	for k in 6:
		var top := k < 3
		var i := k % 3
		var ang := (-0.55 + 0.55 * i) * (1.0 if top else -1.0)
		var hinge := Basis(Vector3.RIGHT, -open if top else open * 0.4)
		var around := Basis(Vector3.BACK, ang) * Vector3(0.0, JAW_R if top else -JAW_R, 0.0)
		var at := middle + hinge * around
		var b := hinge * Basis(Vector3.BACK, ang) * Basis.from_scale(Vector3(0.56, 0.1, BODY_L - 0.12 * absf(ang)))
		lay(_jaws[k], at, b)
	# A lens at each end, its ghost a hand's width off, flickering: the face it shows each side.
	for e in 2:
		var z := (-1.0 if e == 0 else 1.0) * (BODY_L * 0.5 + 0.06)
		var at := middle + Vector3(0.0, 0.05, z)
		var m := _lens_m * (1.0 + 0.5 * tell + 0.3 * snap)
		orient(_lenses[e], at, Vector3(0.0, 0.0, -1.0 if e == 0 else 1.0), m * 0.8, m)
		brighten(_lenses[e], 1.8 + 0.5 * sin(t * 3.0 + e) + 3.0 * tell + 2.0 * snap + 1.5 * hurt)
		var off := Vector3(0.12 * sin(t * 9.0 + e * 2.0), 0.08 * cos(t * 7.0 + e), 0.0) * (1.0 if fmod(t * 3.0 + e, 1.0) < 0.6 else 0.0)
		orient(_ghosts[e], at + off + Vector3(0.0, 0.0, 0.05 * (1.0 if e == 1 else -1.0)), Vector3.BACK, m * 0.7, m * 0.9)
		brighten(_ghosts[e], 0.8 + 1.4 * tell)
		orient(_rings[e], middle + Vector3(0.0, 0.0, z * 0.85), Vector3.BACK, 0.08, JAW_R * 1.7)
		brighten(_rings[e], 1.0 + 1.5 * tell)
	# Legs gripping the cable fore and aft, two a side at each end, flexing as it pulls on the stream.
	for k in 8:
		var side := -1.0 if k % 2 == 0 else 1.0
		var end := -1.0 if k < 4 else 1.0
		var row := float((k >> 1) % 2)
		var root := middle + Vector3(side * JAW_R * 0.7, 0.1, end * (0.2 + 0.25 * row))
		var knee := root + Vector3(side * (0.45 + 0.2 * _splay), 0.35 - 0.15 * row, end * 0.3 * _reach)
		var foot := middle + Vector3(side * 0.08, -0.05, end * (BODY_L * 0.5 + 0.35 + 0.3 * row) * _reach)
		knee.y += 0.06 * sin(t * 4.0 + k)
		bone(_legs[k * 2], root, knee, 0.07)
		bone(_legs[k * 2 + 1], knee, foot, 0.05)
	for k in _feelers.size():
		var side := -1.0 if k % 2 == 0 else 1.0
		var root := middle + Vector3(side * 0.2, JAW_R * 0.9, -0.25 + 0.5 * float(k >> 1))
		var tip := root + Vector3(side * 0.35, 0.55 + 0.1 * sin(t * 5.0 + k), -0.4 + 0.15 * sin(t * 3.0 + k * 1.3))
		bone(_feelers[k], root, tip, 0.025)
		brighten(_feelers[k], 1.0 + 1.6 * tell)


func _muzzle() -> Vector3:
	return Vector3(0.0, 0.05, -BODY_L * 0.5 - 0.3)


## Where its lineage line meets it (world space): its middle, on the cable.
func anchor() -> Vector3:
	return global_transform * Vector3.ZERO if is_inside_tree() else transform.origin
