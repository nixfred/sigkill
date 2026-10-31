class_name MissionLogPickup
extends Node3D
## A terminal log standing in the arena (C35, a mission's `logs`): a small holo-terminal turned to face the player,
## its frame lit in the theme's mint, "> cat <name>" on its screen, bits of data circling it, a thin column of light
## up from a ring on the floor so it is found across the arena. The mission runner (scripts/missions/
## mission_runner.gd) picks it up when the player walks through it (take()): it flares and folds away. Fiction and
## light only: nothing in it reads anything.

const Palette = preload("res://scripts/palette.gd")

## Its slab: width, height, depth; how far it floats and bobs; how far down the floor is from its middle.
const SLAB := Vector3(0.86, 0.58, 0.05)
const FRAME_W := 0.03
const BOB_M := 0.07
const BOB_HZ := 0.55
const FLOOR_DROP := 0.93
const COLUMN_H := 4.5
const RING_R := 0.7
## How fast it turns to face the camera (per second), and its bits' orbit.
const TURN_RATE := 5.0
const BITS := 4
const BIT_ORBIT_M := 0.5
const BIT_HZ := 0.35
## Seconds it takes to flare and fold away when taken.
const TAKE_S := 0.35

## Its data: {"id", "name", "text", "at"}.
var entry := {}
var taken := false

var _slab: Node3D
var _ring: MeshInstance3D
var _column: MeshInstance3D
var _bits: Array[MeshInstance3D] = []
var _light: OmniLight3D
var _age := 0.0
var _taken_age := 0.0
var _materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_slab = Node3D.new()
	add_child(_slab)
	var body := _mesh(_slab, _box(SLAB), _material(Palette.BASE, 0.92, false))
	body.position = Vector3.ZERO
	for edge in [[Vector3(0, SLAB.y * 0.5, 0), Vector3(SLAB.x + FRAME_W, FRAME_W, SLAB.z + 0.01)], [Vector3(0, -SLAB.y * 0.5, 0), Vector3(SLAB.x + FRAME_W, FRAME_W, SLAB.z + 0.01)], [Vector3(SLAB.x * 0.5, 0, 0), Vector3(FRAME_W, SLAB.y, SLAB.z + 0.01)], [Vector3(-SLAB.x * 0.5, 0, 0), Vector3(FRAME_W, SLAB.y, SLAB.z + 0.01)]]:
		_mesh(_slab, _box(edge[1]), _material(Palette.MINT, 1.0, true)).position = edge[0]
	var text := Label3D.new()
	text.font = Palette.mono_font()
	text.font_size = 40
	text.pixel_size = 0.0026
	text.modulate = Palette.MINT
	text.outline_modulate = Color(Palette.VOID, 0.8)
	text.outline_size = 6
	text.shaded = false
	text.double_sided = false
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	text.width = 300.0
	text.autowrap_mode = TextServer.AUTOWRAP_OFF
	text.text = "> cat\n  %s\n_" % str(entry.get("name", "log"))
	text.position = Vector3(-SLAB.x * 0.42, 0.04, SLAB.z * 0.5 + 0.004)
	text.offset = Vector2(0, 0)
	_slab.add_child(text)
	var tag := Label3D.new()
	tag.font = Palette.mono_font()
	tag.font_size = 22
	tag.pixel_size = 0.0022
	tag.modulate = Color(Palette.MINT, 0.85)
	tag.shaded = false
	tag.double_sided = false
	tag.text = "TERMINAL LOG"
	tag.position = Vector3(0, SLAB.y * 0.5 + 0.07, 0)
	_slab.add_child(tag)
	_column = _mesh(self, _cylinder(0.025, COLUMN_H), _material(Palette.MINT, 0.42, true))
	_column.position = Vector3(0, COLUMN_H * 0.5 - FLOOR_DROP, 0)
	var halo := _mesh(_column, _cylinder(0.11, COLUMN_H), _material(Palette.MINT, 0.07, true))
	halo.position = Vector3.ZERO
	var torus := TorusMesh.new()
	torus.inner_radius = RING_R - 0.035
	torus.outer_radius = RING_R
	torus.rings = 48
	torus.ring_segments = 6
	_ring = _mesh(self, torus, _material(Palette.MINT, 0.8, true))
	_ring.position = Vector3(0, -FLOOR_DROP + 0.02, 0)
	for i in BITS:
		_bits.append(_mesh(self, _box(Vector3(0.045, 0.045, 0.045)), _material(Palette.MATRIX_HEAD, 0.95, true)))
	_light = OmniLight3D.new()
	_light.light_color = Palette.MINT
	_light.light_energy = 0.9
	_light.omni_range = 3.2
	_light.shadow_enabled = false
	add_child(_light)


func _process(delta: float) -> void:
	_age += delta
	if taken:
		_taken_age += delta
		var t := clampf(_taken_age / TAKE_S, 0.0, 1.0)
		_slab.scale = Vector3(1.0 + 0.6 * t, maxf(1.0 - t, 0.02), 1.0)
		_column.scale = Vector3(1.0 + 3.0 * t, 1.0, 1.0 + 3.0 * t)
		_light.light_energy = 2.4 * (1.0 - t)
		for m in _materials:
			m.albedo_color.a *= 1.0 - t * 0.5
		if _taken_age >= TAKE_S:
			queue_free()
		return
	_slab.position.y = sin(_age * TAU * BOB_HZ) * BOB_M
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		var to := camera.global_position - global_position
		var yaw := atan2(to.x, to.z)
		_slab.rotation.y = lerp_angle(_slab.rotation.y, yaw, clampf(delta * TURN_RATE, 0.0, 1.0))
	var pulse := 0.5 + 0.5 * sin(_age * TAU * 0.9)
	_ring.scale = Vector3.ONE * (1.0 + 0.12 * pulse)
	_light.light_energy = 0.7 + 0.4 * pulse
	for i in _bits.size():
		var a := _age * TAU * BIT_HZ + TAU * float(i) / float(_bits.size())
		_bits[i].position = Vector3(cos(a) * BIT_ORBIT_M, 0.12 * sin(a * 2.0 + float(i)), sin(a) * BIT_ORBIT_M)
		_bits[i].rotation = Vector3(a, a * 1.3, 0.0)


## Picked up: it flares and folds away.
func take() -> void:
	if taken:
		return
	taken = true
	_taken_age = 0.0


func _mesh(parent: Node3D, mesh: Mesh, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _box(size: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = size
	return box


func _cylinder(radius: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 1
	return c


func _material(color: Color, alpha: float, glow: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials.append(m)
	return m
