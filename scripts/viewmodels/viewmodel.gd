class_name Viewmodel
extends MeshInstance3D
## A weapon held in first person (A1). Built once, from code, when the player is made: low-poly
## geometry from a few primitive shapes, merged into one mesh per material, so a model costs a
## handful of draw calls and nothing is rebuilt while it is held. Original and procedural: no
## model, texture or font files.
##
## This node's own mesh is the neon trim, and its material_override is the trim's glow: the
## weapon's light skin at its viewmodel_glow_energy, root's red while root (C22). The player sets
## both through set_glow() and set_look(). The body is dark gunmetal with machined panel lines or
## hex cells and a rim of the skin's colour round the silhouette (shaders/viewmodel_metal.gdshader),
## plates and shrouds a lighter metal, grips and bands dark polymer, and the hot parts (lenses,
## cores, bores) the skin's beam colour. A model may have pieces of its own that light up with a
## charge, in order (the rail's coils, the rm -rf cannon's core and vents), pulse or turn while
## held (a drum, a lens, a clock hand).
##
## Each weapon's model is a script extending this one that builds itself in _build(), named by its
## WeaponDef's viewmodel_model (scripts/viewmodels/<weapon>.gd), so a new weapon slots in the same
## way. A weapon with none gets the placeholder: a glowing box of viewmodel_size. Every model has a
## Muzzle marker at its barrel's tip, where the player starts its beams and muzzle flash. The shot
## itself still leaves from the eyes: a model is cosmetic, and nothing in it touches anything
## outside the game.
##
## Model space: metres, the grip and receiver round the origin, the barrel along -Z, +Y up and +X
## right. The player places the model at viewmodel_offset in front of the camera, and moves it.

const Palette = preload("res://scripts/palette.gd")

## Where a shape goes: the dark metal body, a lighter metal for plates and shrouds, dark polymer,
## the hot parts in the beam colour, or the neon trim (this node's own mesh). Pieces come after.
enum Part { BODY, PLATE, DARK, HOT, TRIM }

const PARTS := 5
## The hot parts glow this many times the trim's energy.
const HOT_SHARE := 1.8
## A charge piece rests at this share of the weapon's own glow, and a full charge adds CHARGE_GAIN
## more. It lights from the weapon's own glow, not the trim's, which the charge already raises.
const CHARGE_REST := 0.35
const CHARGE_GAIN := 2.5
## Shapes with more sides than this are shaded smooth; the rest are faceted.
const FACETED_SIDES := 8
## The trim's base under its glow, as dark under the colour as the old box was.
const TRIM_DARKEN := 0.65

## The barrel's tip, in this model's space.
var muzzle: Marker3D
## The weapon this model shows.
var def: Resource
## The trim's glow: this node's material_override, as the player sets it.
var glow: StandardMaterial3D:
	get:
		return material_override as StandardMaterial3D
## Hex cells on the body and plates instead of panel lines. A model sets these in _build().
var body_hex := false
var plate_hex := false
## How the model is held: every shape, pivot and the muzzle are placed through it. A model sets it
## first in _build(), to hold a canister turned toward the eye, say.
var pose := Transform3D.IDENTITY

var _tools: Array[SurfaceTool] = []
var _counts: Array[int] = []
## Per piece: its kind (a Part), its pivot, its node and its own material once built.
var _pieces: Array[Dictionary] = []
## Pieces lit by a charge: [piece id, order]; orders count up from 0.
var _charge_pieces: Array = []
var _charge_orders := 0
var _charge := 0.0
## Pieces turning while held: [piece id, axis, turns a second]; pulsing: [piece id, hertz, depth].
var _spins: Array = []
var _pulses: Array = []
var _clock := 0.0
var _energy := 1.0
## The weapon's own glow, viewmodel_glow_energy: what the charge pieces light from.
var _base := 1.0
var _beam := Color.WHITE
var _metal: ShaderMaterial
var _plate: ShaderMaterial
var _polymer: StandardMaterial3D
var _hot: StandardMaterial3D


## The model `weapon` names, built and hidden, or the placeholder box for one that names none.
static func make(weapon: Resource) -> Viewmodel:
	var script: Script = weapon.get("viewmodel_model")
	var model: Viewmodel = script.new() if is_model(script) else Viewmodel.new()
	model.setup(weapon)
	return model


## True when `script` is a viewmodel's: this script or one extending it.
static func is_model(script: Script) -> bool:
	var s := script
	while s != null:
		if s == Viewmodel:
			return true
		s = s.get_base_script()
	return false


func setup(weapon: Resource) -> void:
	def = weapon
	var label = weapon.get("display_name")
	name = (label if label is String else "Weapon").to_pascal_case()
	var body_color: Color = weapon.skin_body() if weapon.has_method("skin_body") else Palette.TEAL
	_beam = weapon.skin_beam() if weapon.has_method("skin_beam") else Palette.MINT
	_energy = weapon.viewmodel_glow_energy
	_base = maxf(_energy, 0.0001)
	for i in PARTS:
		_new_tool()
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	add_child(muzzle)
	_build()
	muzzle.position = pose * muzzle.position
	material_override = Palette.glow(body_color, _energy)
	_metal = Palette.viewmodel_metal(Palette.GUNMETAL, body_color, body_hex)
	_plate = Palette.viewmodel_metal(Palette.GUNMETAL_LIGHT, body_color, plate_hex, true)
	_polymer = Palette.viewmodel_polymer()
	_hot = Palette.viewmodel_hot(_beam, _energy * HOT_SHARE)
	_commit()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = weapon.viewmodel_offset
	visible = false
	set_look(body_color, _beam, _energy)


## The model's shapes. The placeholder: one glowing box of viewmodel_size, its muzzle where
## muzzle_offset says.
func _build() -> void:
	box(Part.TRIM, Vector3.ZERO, def.viewmodel_size)
	muzzle.position = def.muzzle_offset - def.viewmodel_offset


## Every glowing part at `energy`: the trim at it, the hot parts and the charge pieces at their
## shares of it.
func set_glow(energy: float) -> void:
	_energy = energy
	glow.emission_energy_multiplier = energy
	_refresh()


## The trim in `color` (its base darkened under it), the hot parts in `beam`, every rim in
## `color`, at `energy`: the light skin, or root's red.
func set_look(color: Color, beam: Color, energy: float) -> void:
	glow.emission = color
	glow.albedo_color = color.darkened(TRIM_DARKEN)
	_beam = beam
	for mat in [_metal, _plate]:
		mat.set_shader_parameter("neon", color)
	for piece in _pieces:
		var mat := piece["material"] as StandardMaterial3D
		if mat != null and piece["kind"] == Part.TRIM:
			mat.emission = color
			mat.albedo_color = color.darkened(TRIM_DARKEN)
		elif mat != null and piece["kind"] == Part.HOT:
			mat.emission = beam
			mat.albedo_color = beam
	_hot.emission = beam
	_hot.albedo_color = beam
	set_glow(energy)


## A charge from 0 to 1: the rail's, or the rm -rf cannon's wind-up. Its pieces light in order.
func set_charge(progress: float) -> void:
	_charge = clampf(progress, 0.0, 1.0)
	_refresh()


func charge() -> float:
	return _charge


## The model's own motion while held: its spinning pieces turn, its pulsing ones breathe.
func idle(delta: float) -> void:
	_clock = fmod(_clock + delta, 3600.0)
	for spin in _spins:
		(_pieces[spin[0] - PARTS]["node"] as Node3D).rotate_object_local(spin[1], TAU * spin[2] * delta)
	if not _pulses.is_empty():
		_refresh()


## How bright piece `id` glows now, as a share of the weapon's own glow.
func piece_energy(id: int) -> float:
	var mat := _pieces[id - PARTS]["material"] as StandardMaterial3D
	return mat.emission_energy_multiplier / _base if mat != null else 0.0


## Triangles in the whole model: its budget.
func triangles() -> int:
	var total := 0
	for node in [self] + find_children("*", "MeshInstance3D", true, false):
		var m := (node as MeshInstance3D).mesh as ArrayMesh
		if m == null:
			continue
		for s in m.get_surface_count():
			total += m.surface_get_array_len(s) / 3
	return total


# --- Building: shapes, pieces, and the merge. ---

## A separate piece of kind `kind` (a Part) that can light, pulse or turn on its own about
## `pivot`. Its shapes are given in model space like the rest. Returns its id for the shapes.
func piece(kind: Part, pivot: Vector3 = Vector3.ZERO) -> int:
	_pieces.append({"kind": kind, "pivot": pose * pivot, "node": null, "material": null})
	_new_tool()
	return PARTS + _pieces.size() - 1


## A piece that lights with a charge, after every piece of a lower order.
func charge_piece(kind: Part, order: int, pivot: Vector3 = Vector3.ZERO) -> int:
	var id := piece(kind, pivot)
	_charge_pieces.append([id, order])
	_charge_orders = maxi(_charge_orders, order + 1)
	return id


## Piece `id` turns `turns` times a second about its own `axis` while the model is held.
func spin(id: int, axis: Vector3, turns: float) -> void:
	_spins.append([id, (pose.basis * axis).normalized(), turns])


## Piece `id`'s glow breathes `depth` either way of its own, `hertz` times a second.
func pulse(id: int, hertz: float, depth: float) -> void:
	_pulses.append([id, hertz, depth])


## A box of `size` centred on `center`, turned by `turn` (degrees about X, Y and Z).
func box(into: int, center: Vector3, size: Vector3, turn: Vector3 = Vector3.ZERO) -> void:
	var h := size * 0.5
	var b := _basis(turn)
	for axis in 3:
		for side in [-1.0, 1.0]:
			var n := Vector3.ZERO
			n[axis] = side
			var u := Vector3.ZERO
			u[(axis + 1) % 3] = 1.0
			var v := Vector3.ZERO
			v[(axis + 2) % 3] = 1.0
			var corners := []
			for c in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				corners.append(center + b * ((n + u * c[0] + v * c[1]) * h))
			_face(into, corners, b * n)


## A prism of `sides` round the local Z axis, `length` long and centred on `center`: radius at
## the back (+Z) and `end_radius` at the front (-Z), the same when below 0. `phase` turns its
## corners, in degrees. Many sides make a cylinder; a different end radius a cone or a frustum.
func prism(into: int, center: Vector3, radius: float, length: float, sides: int, turn: Vector3 = Vector3.ZERO, end_radius: float = -1.0, phase: float = 0.0) -> void:
	var b := _basis(turn)
	var front_r := radius if end_radius < 0.0 else end_radius
	var back := []
	var front := []
	var dirs := []
	for i in sides:
		var a := TAU * i / sides + deg_to_rad(phase)
		var d := Vector3(cos(a), sin(a), 0.0)
		dirs.append(b * d)
		back.append(center + b * (d * radius + Vector3(0.0, 0.0, length * 0.5)))
		front.append(center + b * (d * front_r + Vector3(0.0, 0.0, -length * 0.5)))
	for i in sides:
		var j := (i + 1) % sides
		if sides > FACETED_SIDES:
			_smooth_quad(into, [back[i], back[j], front[j], front[i]], [dirs[i], dirs[j], dirs[j], dirs[i]])
		else:
			_face(into, [back[i], back[j], front[j], front[i]], (dirs[i] + dirs[j]))
	_face(into, back, b * Vector3.BACK)
	_face(into, front, b * Vector3.FORWARD)


## A ring round the local Z axis, `length` deep: a coil, a band or a muzzle's lip. `phase` turns
## its corners, in degrees, to match a prism's.
func tube(into: int, center: Vector3, inner: float, outer: float, length: float, sides: int, turn: Vector3 = Vector3.ZERO, phase: float = 0.0) -> void:
	var b := _basis(turn)
	var rings := []  # back outer, front outer, back inner, front inner
	var dirs := []
	for i in sides:
		var a := TAU * i / sides + deg_to_rad(phase)
		var d := Vector3(cos(a), sin(a), 0.0)
		dirs.append(b * d)
		rings.append([
			center + b * (d * outer + Vector3(0.0, 0.0, length * 0.5)),
			center + b * (d * outer + Vector3(0.0, 0.0, -length * 0.5)),
			center + b * (d * inner + Vector3(0.0, 0.0, length * 0.5)),
			center + b * (d * inner + Vector3(0.0, 0.0, -length * 0.5)),
		])
	for i in sides:
		var j := (i + 1) % sides
		var p: Array = rings[i]
		var q: Array = rings[j]
		_face(into, [p[0], q[0], q[1], p[1]], dirs[i] + dirs[j])
		_face(into, [p[2], q[2], q[3], p[3]], -(dirs[i] + dirs[j]))
		_face(into, [p[0], q[0], q[2], p[2]], b * Vector3.BACK)
		_face(into, [p[1], q[1], q[3], p[3]], b * Vector3.FORWARD)


## A ">" of two bars, `size` tall, on a side face: flat against the plane x = at.x, its tip toward
## -Z (the muzzle) with `toward` -1 or +Z (the back) with +1, `thick` out from the face. Seen from
## the eye, on the left face, +Z reads as ">" and -Z as "<".
func chevron(into: int, at: Vector3, size: float, toward: float = -1.0, thick: float = 0.002) -> void:
	var bar := Vector3(thick, size * 0.16, size * 0.62)
	box(into, at + Vector3(0.0, size * 0.21, -toward * size * 0.12), bar, Vector3(36.0 * toward, 0.0, 0.0))
	box(into, at + Vector3(0.0, -size * 0.21, -toward * size * 0.12), bar, Vector3(-36.0 * toward, 0.0, 0.0))


static func _basis(turn: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z)))


func _new_tool() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_tools.append(st)
	_counts.append(0)


## A flat polygon facing `outward`, as a fan. Godot draws clockwise triangles as front faces, so
## each triangle is wound against its outward normal.
func _face(into: int, corners: Array, outward: Vector3) -> void:
	var n := _normal(corners, outward)
	for i in range(1, corners.size() - 1):
		_tri(into, [corners[0], corners[i], corners[i + 1]], [n, n, n], n)


func _smooth_quad(into: int, corners: Array, normals: Array) -> void:
	var outward: Vector3 = normals[0] + normals[2]
	_tri(into, [corners[0], corners[1], corners[2]], [normals[0], normals[1], normals[2]], outward)
	_tri(into, [corners[0], corners[2], corners[3]], [normals[0], normals[2], normals[3]], outward)


func _tri(into: int, v: Array, n: Array, outward: Vector3) -> void:
	var a: Vector3 = v[0]
	var b: Vector3 = v[1]
	var c: Vector3 = v[2]
	var order := [0, 1, 2]
	if (b - a).cross(c - a).dot(outward) > 0.0:
		order = [0, 2, 1]
	var st := _tools[into]
	var pivot: Vector3 = _pieces[into - PARTS]["pivot"] if into >= PARTS else Vector3.ZERO
	for k in order:
		st.set_normal((pose.basis * (n[k] as Vector3)).normalized())
		st.add_vertex(pose * (v[k] as Vector3) - pivot)
	_counts[into] += 3


## A polygon's own normal (Newell's), turned to face `outward`.
static func _normal(corners: Array, outward: Vector3) -> Vector3:
	var n := Vector3.ZERO
	for i in corners.size():
		var p: Vector3 = corners[i]
		var q: Vector3 = corners[(i + 1) % corners.size()]
		n += Vector3((p.y - q.y) * (p.z + q.z), (p.z - q.z) * (p.x + q.x), (p.x - q.x) * (p.y + q.y))
	if n.is_zero_approx():
		return outward.normalized()
	n = n.normalized()
	return n if n.dot(outward) >= 0.0 else -n


## The merge: the trim into this node's own mesh, the body, plates, polymer and hot parts into
## one mesh with a surface each, and every piece into a node of its own at its pivot.
func _commit() -> void:
	if _counts[Part.TRIM] > 0:
		mesh = _tools[Part.TRIM].commit()
	var body := ArrayMesh.new()
	for part in [Part.BODY, Part.PLATE, Part.DARK, Part.HOT]:
		if _counts[part] > 0:
			_tools[part].commit(body)
			body.surface_set_material(body.get_surface_count() - 1, _material(part))
	if body.get_surface_count() > 0:
		add_child(_node("Body", body, Vector3.ZERO))
	for i in _pieces.size():
		var piece_mesh := ArrayMesh.new()
		if _counts[PARTS + i] > 0:
			_tools[PARTS + i].commit(piece_mesh)
		var kind: int = _pieces[i]["kind"]
		var mat: Material = _material(kind)
		if kind == Part.HOT or kind == Part.TRIM:
			mat = mat.duplicate()  # its own, to light on its own
		var node := _node("Piece%d" % i, piece_mesh, _pieces[i]["pivot"])
		node.material_override = mat
		_pieces[i]["node"] = node
		_pieces[i]["material"] = mat
		add_child(node)
	_tools.clear()


func _material(kind: int) -> Material:
	match kind:
		Part.PLATE:
			return _plate
		Part.DARK:
			return _polymer
		Part.HOT:
			return _hot
		Part.TRIM:
			return glow
	return _metal


static func _node(node_name: String, node_mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = node_mesh
	node.position = at
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


## Every glow from the trim's energy: the hot parts, each piece by its kind, a charge piece from the
## weapon's own glow by the charge reached (a piece of order k is lit through the k-th share of it),
## a pulse by the clock.
func _refresh() -> void:
	_hot.emission_energy_multiplier = _energy * HOT_SHARE
	for i in _pieces.size():
		var mat := _pieces[i]["material"] as StandardMaterial3D
		if mat == null:
			continue
		var base := _energy * (HOT_SHARE if _pieces[i]["kind"] == Part.HOT else 1.0)
		mat.emission_energy_multiplier = base
	for entry in _charge_pieces:
		var mat := _pieces[entry[0] - PARTS]["material"] as StandardMaterial3D
		if mat == null:
			continue
		var fill := clampf(_charge * _charge_orders - entry[1], 0.0, 1.0)
		var share := HOT_SHARE if _pieces[entry[0] - PARTS]["kind"] == Part.HOT else 1.0
		mat.emission_energy_multiplier = _base * share * (CHARGE_REST + CHARGE_GAIN * fill)
	for entry in _pulses:
		var mat := _pieces[entry[0] - PARTS]["material"] as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier *= 1.0 + entry[2] * sin(TAU * entry[1] * _clock)
