extends DaemonArt
## A pegged core (W1, PRD 5.5: "a pegged CPU core is a boss"; the enemy art bar's "giant red-hot lattice core as the CPU
## boss"): a process running a core flat out, given the body of the thing it is burning. Not the finale's cage: silicon's
## own crystal, the diamond lattice, eighteen atoms and their sixteen bonds inside the cube of one cell, the cube's edges
## an armoured frame (the die), a ring of heat-sink fins round it, heat haze streaming up off it and a white-hot spot at
## its heart (its weak point, with the four atoms inside the cell). It hangs over the arena and turns about the cube's
## long diagonal, so it shows the lattice's three-fold face and then its square one.
##
## Its heat is the process's live CPU (heat, set by the hunt from the table): crimson when it cools toward half a core,
## orange, then white at a full one, its bonds, atoms, haze and lamp all with it, its fins spinning faster; its size
## follows too (the hunt scales it). Before every volley (its tell) it draws in tight and burns white, its fins screaming
## round; each bolt it throws snaps the lattice out (the strike). Hurt, its atoms shake loose in their sites.
##
## No two alike (A5's rule): its seed sets its tilt, its turning speed, the fins' count and pitch, a scorched frame edge
## or two and a flickering atom. Never an elite (it is already the biggest thing on the floor). Visual only: its dummy
## keeps a box round the whole of it, refitted as it grows and shrinks.

const HALF := 1.0
const ATOM_M := 0.2
const INNER_M := 0.3
const BOND_W := 0.075
const FRAME_W := 0.13
const FINS_LOW := 9
const FINS_HIGH := 13
const FIN_R := 1.55
const FIN := Vector3(0.12, 0.62, 0.42)
const HAZE := 7
const HEART_M := 0.42
const SPIN := 0.3
const YAW := 0.12
const BOX := Vector3(3.3, 3.3, 3.3)
const LAMP_REACH := 18.0
const LAMP_ENERGY := 3.0
## The bond length in a cell of side 1 (a quarter of the cube's long diagonal).
const BOND := 0.4330127

## Set by the hunt: 0 cool (half a core) to 1 (a full core).
var heat := 1.0

var _sites := PackedVector3Array()
var _inner := PackedByteArray()
var _atoms := PackedInt32Array()
var _bonds := PackedInt32Array()
var _bond_ends: Array[Vector2i] = []
var _frame := PackedInt32Array()
var _frame_ends: Array[Vector2i] = []
var _fins := PackedInt32Array()
var _haze := PackedInt32Array()
var _heart: int
var _halo: int
var _axis := Vector3.ONE.normalized()
var _tilt := Basis.IDENTITY
var _spun := 0.0
var _yawed := 0.0
var _fin_turn := 0.0
var _pitch := 0.4
var _spin_k := 1.0
var _sent_heat := -1.0
var _lamp: OmniLight3D = null


func _build() -> void:
	ai_kind = "pegged"
	core_color = Palette.CRIMSON
	edge_color = Palette.CRIMSON
	gutter = 1.2
	glyph_count = 12
	glyph_radius = 2.3
	glyph_low = -1.8
	glyph_high = 2.0
	glyph_size = 0.2
	glyph_turns = 0.07
	reach = AABB(Vector3(-2.6, -2.4, -2.6), Vector3(5.2, 5.6, 5.2))
	tag_height = 2.4
	budget_triangles = 9000
	budget_draw_calls = 14
	size_low = 1.0
	size_high = 1.0
	elite_size = 1.0
	_tilt = Basis(Vector3(dice(60, 0) - 0.5, 0.0, dice(60, 1) - 0.5).normalized(), lerpf(0.08, 0.3, dice(61, 0)))
	_spun = TAU * dice(62, 0)
	_spin_k = lerpf(0.8, 1.25, dice(63, 0))
	_pitch = lerpf(0.25, 0.6, dice(64, 0))
	_lamp = OmniLight3D.new()
	_lamp.name = "HeatLamp"
	_lamp.light_color = Palette.CRIMSON
	_lamp.omni_range = LAMP_REACH
	_lamp.omni_attenuation = 1.2
	_lamp.shadow_enabled = false
	add_child(_lamp)
	_lattice()
	for i in _sites.size():
		var inner := _inner[i] == 1
		_atoms.append(weak(part(Shape.GEM, Look.CORE)) if inner else seam(part(Shape.GEM, Look.CORE)))
	for e in _bond_ends:
		_bonds.append(part(Shape.SHARD, Look.CORE))
	for e in _frame_ends:
		_frame.append(part(Shape.LIMB, Look.ARMOR))
	for i in pick(65, 0, FINS_LOW, FINS_HIGH):
		_fins.append(part(Shape.PLATE, Look.ARMOR))
	for i in HAZE:
		_haze.append(part(Shape.STREAK, Look.TRAIL))
	_heart = weak(part(Shape.GEM, Look.CORE))
	_halo = seam(part(Shape.RING, Look.CORE))
	for i in pick(66, 0, 1, 2):
		scorch(_frame[pick(67, i, 0, _frame.size() - 1)], lerpf(0.5, 1.0, dice(68, i)))
	flicker(_atoms[pick(69, 0, 0, _atoms.size() - 1)], lerpf(0.2, 0.45, dice(70, 0)))


## The diamond lattice in one cubic cell (side 1, centred): the face-centred sites (8 corners, 6 faces), the four
## inside it, the bonds between nearest neighbours, and the cube's twelve edges.
func _lattice() -> void:
	var raw: Array[Vector3] = []
	for x in 2:
		for y in 2:
			for z in 2:
				raw.append(Vector3(x, y, z))
	for f in [Vector3(0.5, 0.5, 0), Vector3(0.5, 0.5, 1), Vector3(0.5, 0, 0.5), Vector3(0.5, 1, 0.5), Vector3(0, 0.5, 0.5), Vector3(1, 0.5, 0.5)]:
		raw.append(f)
	var inner_from := raw.size()
	for v in [Vector3(0.25, 0.25, 0.25), Vector3(0.75, 0.75, 0.25), Vector3(0.75, 0.25, 0.75), Vector3(0.25, 0.75, 0.75)]:
		raw.append(v)
	for i in raw.size():
		_sites.append(raw[i] - Vector3.ONE * 0.5)
		_inner.append(1 if i >= inner_from else 0)
	for i in range(inner_from, raw.size()):
		for j in inner_from:
			if absf(raw[i].distance_to(raw[j]) - BOND) < 0.01:
				_bond_ends.append(Vector2i(i, j))
	for i in 8:
		for j in range(i + 1, 8):
			if absf(raw[i].distance_to(raw[j]) - 1.0) < 0.01:
				_frame_ends.append(Vector2i(i, j))


func _pose(t: float, delta: float) -> void:
	var hurt := _hurt()
	var tell := drive_amount() if act == Act.TELL else 0.0
	var snap := (1.0 - act_u) * drive_amount() if act == Act.STRIKE else 0.0
	var hot := clampf(heat + 0.6 * tell, 0.0, 1.4)
	_send_heat()
	var beat := pow(maxf(sin(TAU * (0.7 + 1.6 * hot) * t), 0.0), 4.0)
	_spun = fmod(_spun + SPIN * _spin_k * (1.0 + heat + 2.0 * tell) * delta, TAU)
	_yawed = fmod(_yawed + YAW * delta, TAU)
	_fin_turn = fmod(_fin_turn + (0.6 + 2.4 * heat + 6.0 * tell) * delta, TAU)
	var frame := Basis(Vector3.UP, _yawed) * _tilt * Basis(_axis, _spun)
	var middle := recoil() * 2.0 + Vector3(0.0, 0.1 * sin(t * 0.8), 0.0)
	var size := HALF * 2.0 * (1.0 - 0.16 * tell + 0.14 * snap + 0.03 * beat)
	var shake := 0.05 * hurt + 0.02 * tell
	var at := PackedVector3Array()
	for i in _sites.size():
		var jitter := Vector3(sin(t * 23.0 + i * 1.7), sin(t * 19.0 + i * 2.3), sin(t * 29.0 + i * 0.9)) * shake
		at.append(middle + frame * (_sites[i] * size + jitter))
	for i in _sites.size():
		var inner := _inner[i] == 1
		var m := (INNER_M if inner else ATOM_M) * (1.0 + 0.35 * beat + 0.3 * tell)
		orient(_atoms[i], at[i], frame * Vector3.UP, m, m * 0.85)
		brighten(_atoms[i], (1.6 if inner else 1.0) + 0.7 * hot + 0.8 * beat + 2.4 * tell + 1.5 * snap)
	for k in _bonds.size():
		var e := _bond_ends[k]
		bone(_bonds[k], at[e.x], at[e.y], BOND_W * (1.0 + 0.5 * tell))
		brighten(_bonds[k], 0.7 + 0.5 * hot + 0.4 * beat + 1.8 * tell)
	for k in _frame.size():
		var e := _frame_ends[k]
		var a := middle + frame * (_sites[e.x] * size * 1.08)
		var b := middle + frame * (_sites[e.y] * size * 1.08)
		bone(_frame[k], a, b, FRAME_W, FRAME_W)
	# The fins: a heat sink round its waist, pitched like a turbine, spinning with its heat.
	var waist := Basis(Vector3.UP, _yawed) * _tilt
	for k in _fins.size():
		var a := _fin_turn + TAU * float(k) / float(_fins.size())
		var radial := waist * Vector3(cos(a), 0.0, sin(a))
		var tangent := waist * Vector3(-sin(a), 0.0, cos(a))
		var up := waist * Vector3.UP
		var basis := Basis(radial, _pitch) * Basis(radial * FIN.x, up * FIN.y, tangent * FIN.z)
		lay(_fins[k], middle + radial * FIN_R * (1.0 + 0.1 * snap - 0.06 * tell), basis)
	# The heart: white-hot, beating; its halo round the long diagonal.
	orient(_heart, middle, frame * _axis, HEART_M * (1.0 + 0.4 * beat + 0.5 * tell), HEART_M * 0.9)
	brighten(_heart, 2.4 + 1.0 * hot + 1.2 * beat + 3.5 * tell + 1.5 * hurt)
	orient(_halo, middle, frame * _axis, 0.05, HEART_M * 3.2 * (1.0 + 0.2 * beat - 0.25 * tell))
	brighten(_halo, 1.0 + 0.5 * hot + 2.0 * tell)
	# Heat haze: slivers rising off the top, taller and quicker the hotter it runs.
	for k in _haze.size():
		var u := fposmod(float(k) / float(HAZE) + t * (0.35 + 0.6 * hot), 1.0)
		var a := TAU * (float(k) * 0.381966 + 0.1 * sin(t + k))
		var base := middle + Vector3(cos(a) * 0.55, HALF * 1.1 + 1.6 * u * (0.6 + hot), sin(a) * 0.55)
		bone(_haze[k], base, base + Vector3(0.08 * sin(t * 3.0 + k), 0.4 + 0.6 * hot, 0.0), 0.06 * (1.0 - u))
		brighten(_haze[k], (0.5 + 0.8 * hot) * (1.0 - u))
	if _lamp != null:
		_lamp.position = middle
		_lamp.light_energy = (LAMP_ENERGY * (0.4 + 0.6 * hot) + 1.5 * beat + 4.0 * tell + 3.0 * snap) * ArenaArt.light_level


## Its colour for its heat: crimson, through ember orange, to white.
func heat_color() -> Color:
	var h := clampf(heat, 0.0, 1.0)
	if h < 0.65:
		return Palette.CRIMSON.lerp(Palette.EMBER, h / 0.65)
	return Palette.EMBER.lerp(Palette.HEAT_HI, 0.45 * (h - 0.65) / 0.35)  # never all white: the lattice must read


func _send_heat() -> void:
	if absf(heat - _sent_heat) < 0.02:
		return
	_sent_heat = heat
	var c := heat_color()
	for node in _drawn:
		node.set_instance_shader_parameter("core_color", c)
		node.set_instance_shader_parameter("edge_color", c)
	if _lamp != null:
		_lamp.light_color = c


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
