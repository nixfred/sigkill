class_name MissionBeacon
extends Node3D
## Where a mission's reach objective points (C35): a pillar of teal light with a white core standing out of the floor,
## a hexagon of light on the floor at the objective's radius turning slowly (the nixfred hexagon's six sides, drawn,
## not the logo), chevrons climbing the pillar, and the place's name over it. The HUD's marker (scripts/hud/
## mission_hud.gd) finds it through walls; this is what the player walks into. Light only.

const Palette = preload("res://scripts/palette.gd")

const FLOOR_DROP := 0.93
const PILLAR_H := 12.0
const CHEVRONS := 4
const CHEVRON_RISE_M := 0.9
const SPIN_HZ := 0.08

## Its words over it ("spawn vent"), and the reach radius its hexagon draws, metres.
var label := ""
var radius := 2.5

var _hex: Node3D
var _chevrons: Array[MeshInstance3D] = []
var _core_material: StandardMaterial3D
var _age := 0.0


func _ready() -> void:
	var core := _mesh(self, _cylinder(0.05, PILLAR_H), _material(Palette.FLASH, 0.75))
	_core_material = core.material_override
	core.position = Vector3(0, PILLAR_H * 0.5 - FLOOR_DROP, 0)
	_mesh(core, _cylinder(0.18, PILLAR_H), _material(Palette.TEAL, 0.22))
	_mesh(core, _cylinder(0.55, PILLAR_H), _material(Palette.TEAL, 0.05))
	_hex = Node3D.new()
	_hex.position = Vector3(0, -FLOOR_DROP + 0.03, 0)
	add_child(_hex)
	var side := 2.0 * radius * sin(PI / 6.0)
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		var bar := _mesh(_hex, _box(Vector3(side, 0.03, 0.07)), _material(Palette.TEAL, 0.9))
		var mid := radius * cos(PI / 6.0)
		bar.position = Vector3(cos(a) * mid, 0.0, sin(a) * mid)
		bar.rotation.y = -a + PI / 2.0
	var inner := TorusMesh.new()
	inner.inner_radius = radius * 0.32
	inner.outer_radius = radius * 0.32 + 0.04
	inner.ring_segments = 4
	inner.rings = 6
	_mesh(_hex, inner, _material(Palette.MINT, 0.6))
	for i in CHEVRONS:
		var chevron := _mesh(self, _box(Vector3(0.42, 0.03, 0.08)), _material(Palette.MINT, 0.8))
		_chevrons.append(chevron)
	if label != "":
		var words := Label3D.new()
		words.font = Palette.mono_font()
		words.font_size = 40
		words.pixel_size = 0.006
		words.text = "[ %s ]" % label
		words.modulate = Palette.MINT
		words.outline_modulate = Palette.VOID
		words.outline_size = 10
		words.shaded = false
		words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		words.position = Vector3(0, 2.6, 0)
		add_child(words)
	var light := OmniLight3D.new()
	light.light_color = Palette.TEAL
	light.light_energy = 1.2
	light.omni_range = radius + 3.0
	light.shadow_enabled = false
	light.position = Vector3(0, 0.6, 0)
	add_child(light)


func _process(delta: float) -> void:
	_age += delta
	_hex.rotation.y = _age * TAU * SPIN_HZ
	var pulse := 0.5 + 0.5 * sin(_age * TAU * 1.1)
	_core_material.albedo_color.a = 0.55 + 0.35 * pulse
	for i in _chevrons.size():
		var t := fposmod(_age * 0.45 + float(i) / float(_chevrons.size()), 1.0)
		var chevron := _chevrons[i]
		chevron.position = Vector3(0, -FLOOR_DROP + 0.2 + t * CHEVRON_RISE_M * 3.0, 0)
		chevron.rotation.y = _age * 1.4 + float(i)
		(chevron.material_override as StandardMaterial3D).albedo_color.a = 0.85 * (1.0 - t)


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


func _cylinder(r: float, height: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = height
	c.radial_segments = 16
	c.rings = 1
	return c


func _material(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
