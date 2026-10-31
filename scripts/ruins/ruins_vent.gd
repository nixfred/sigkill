class_name RuinsVent
extends Node3D
## A spawn vent in the ruins' floor (C37, docs/STORY.md mission 1: "the spawn vents in the floor leak green code"): a
## grate in a raised frame over a green glow, the code rain's glyphs rising through its slats whatever the register (the
## Matrix leaking up into the grid), its light breathing. A mission's daemons climb out of them (scripts/missions/
## mission_stage.gd): burst() is a gush of code and a flash as one comes out.
##
## The breach's own (`hatch`, made by scripts/ruins/ruins_world.gd over its shaft): its grate is two halves hinged on
## either side of the opening, standing on a box of their own; open() swings them down into the shaft, takes the box
## away and lets the light up out of it, so whoever stands on it drops into the pocket below. Visual, its light and
## that one box: it reads nothing and runs nothing.

const Palette = preload("res://scripts/palette.gd")

## The glow and the code: the Matrix's green, in every register.
const GLOW := Color(0.0, 1.0, 0.255)
const SLAT_M := 0.2
## Seconds the halves take to swing open; how far they swing (radians).
const OPEN_S := 0.75
const SWING := 1.95
## A burst's seconds, and the leak's share of the emitter between bursts.
const BURST_S := 0.7
const LEAK := 0.3

signal opened_up

## The grate's side, metres (the opening's, for a hatch), and whether it is the breach's hatch.
var size := 1.4
var hatch := false

var _halves: Array[Node3D] = []
var _body: StaticBody3D = null
var _glow: MeshInstance3D = null
var _glyphs: GPUParticles3D = null
var _light: OmniLight3D = null
var _burst := 0.0
var _open_t := -1.0
var _age := 0.0

static var _glow_mat: StandardMaterial3D = null


func _ready() -> void:
	var mats := RuinsWorld.materials()
	if hatch:
		for side in [-1.0, 1.0]:
			var hinge := Node3D.new()
			hinge.name = "Half%s" % ("W" if side < 0.0 else "E")
			hinge.position = Vector3(side * size * 0.5, 0, 0)
			add_child(hinge)
			var leaf := MeshInstance3D.new()
			leaf.mesh = _grate(Vector2(size * 0.5, size), Vector3(-side * size * 0.25, 0, 0), mats)
			hinge.add_child(leaf)
			_halves.append(hinge)
		_body = StaticBody3D.new()
		_body.name = "Hatch"
		_body.collision_layer = 1
		_body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(size, RuinsLayout.SLAB_M, size)
		shape.shape = box
		shape.position = Vector3(0, -RuinsLayout.SLAB_M * 0.5, 0)
		_body.add_child(shape)
		add_child(_body)
	else:
		var grate := MeshInstance3D.new()
		grate.name = "Grate"
		grate.mesh = _grate(Vector2(size, size), Vector3.ZERO, mats, true)
		add_child(grate)
	_glow = MeshInstance3D.new()
	_glow.name = "Glow"
	var quad := PlaneMesh.new()
	quad.size = Vector2(size, size) * 0.96
	_glow.mesh = quad
	_glow.material_override = _glow_material()
	_glow.position = Vector3(0, -0.9 if hatch else 0.012, 0)
	_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glow)
	_glyphs = _emitter()
	add_child(_glyphs)
	_light = OmniLight3D.new()
	_light.position = Vector3(0, 0.5, 0)
	_light.light_color = GLOW
	_light.omni_range = size * (2.6 if hatch else 2.4)
	_light.omni_attenuation = 1.6
	_light.shadow_enabled = false
	add_child(_light)


## A grate `extent` big (x, z) round `middle`: a frame, slats across it, painted for the ruins' body shader.
func _grate(extent: Vector2, middle: Vector3, mats: Dictionary, raised: bool = false) -> ArrayMesh:
	var kit := ShapeKit.new()
	var body := kit.bucket(Vector3.ZERO, true, true)
	var lift := 0.05 if raised else 0.0
	RuinsPieces.paint_body(kit, 0.3, 1.0)
	var rim := 0.12
	for z in [-1.0, 1.0]:
		kit.box(body, middle + Vector3(0, lift - 0.03, z * (extent.y * 0.5 - rim * 0.5)), Vector3(extent.x, 0.1, rim))
	for x in [-1.0, 1.0]:
		kit.box(body, middle + Vector3(x * (extent.x * 0.5 - rim * 0.5), lift - 0.03, 0), Vector3(rim, 0.1, extent.y - rim * 2.0))
	RuinsPieces.paint_body(kit, 0.5, 0.55)
	var n := maxi(int((extent.y - rim * 2.0) / SLAT_M), 2)
	for i in n:
		var z := -extent.y * 0.5 + rim + (i + 0.5) * (extent.y - rim * 2.0) / float(n)
		kit.box(body, middle + Vector3(0, lift - 0.05, z), Vector3(extent.x - rim * 2.0, 0.06, SLAT_M * 0.42))
	if hatch:
		kit.box(body, middle + Vector3(0, -0.12, 0), Vector3(0.12, 0.12, extent.y - rim * 2.0))
	var mesh := kit.commit(body)
	mesh.surface_set_material(0, mats["body"])
	return mesh


static func _glow_material() -> StandardMaterial3D:
	if _glow_mat == null:
		_glow_mat = StandardMaterial3D.new()
		_glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow_mat.albedo_color = Color(GLOW.r * 1.6, GLOW.g * 1.6, GLOW.b * 1.6)
		_glow_mat.disable_receive_shadows = true
	return _glow_mat


func _emitter() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Code"
	p.amount = 90 if hatch else 36
	p.lifetime = 1.8 if hatch else 1.3
	p.local_coords = false
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(size * 0.45, 0.05, size * 0.45)
	process.direction = Vector3(0, 1, 0)
	process.spread = 8.0
	process.initial_velocity_min = 0.9
	process.initial_velocity_max = 2.6
	process.gravity = Vector3.ZERO
	process.anim_offset_min = 0.0
	process.anim_offset_max = 1.0
	process.scale_min = 0.8
	process.scale_max = 1.5
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	process.color_ramp = ramp
	p.process_material = process
	p.draw_pass_1 = RuinsWorld._quad(Vector2(0.13, 0.16))
	var mat := RuinsWorld._particle_material(Color(GLOW, 0.95), BaseMaterial3D.BILLBOARD_PARTICLES, RuinsWorld._glyph_atlas())
	mat.particles_anim_h_frames = 8
	mat.particles_anim_v_frames = 8
	mat.particles_anim_loop = false
	mat.distance_fade_min_distance = 0.4
	mat.distance_fade_max_distance = 1.6
	p.material_override = mat
	p.visibility_aabb = AABB(Vector3(-4, -2, -4), Vector3(8, 9, 8))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.amount_ratio = LEAK
	p.preprocess = 1.0
	return p


## One climbs out (a mission's daemon): a gush of code and a flash of its light.
func burst() -> void:
	_burst = 1.0


## The breach splits open (a hatch only): its halves swing down into the shaft, its box goes, the glow comes up.
func open() -> void:
	if not hatch or _open_t >= 0.0:
		return
	_open_t = 0.0
	_burst = 1.0
	if _body != null:
		_body.collision_layer = 0
		for child in _body.get_children():
			(child as CollisionShape3D).set_deferred("disabled", true)
	opened_up.emit()


## True once a hatch has opened.
func is_open() -> bool:
	return _open_t >= 0.0


func _process(delta: float) -> void:
	_age += delta
	_burst = maxf(_burst - delta / BURST_S, 0.0)
	if _glyphs != null:
		_glyphs.amount_ratio = clampf(LEAK + (1.0 - LEAK) * _burst, 0.0, 1.0)
		_glyphs.speed_scale = 1.0 + 1.6 * _burst
	var breathe := 0.55 + 0.25 * sin(_age * 2.3 + position.x)
	if _light != null:
		_light.light_energy = (breathe + 3.2 * _burst + (1.4 if is_open() else 0.0)) * ArenaArt.light_level
	if _open_t >= 0.0 and _open_t < OPEN_S:
		_open_t = minf(_open_t + delta, OPEN_S)
		var k := _open_t / OPEN_S
		var swing := SWING * (k * k * (3.0 - 2.0 * k))
		if _halves.size() == 2:
			_halves[0].rotation.z = -swing  # the west half, hinged on its west side, its free edge going down
			_halves[1].rotation.z = swing
		if _glow != null:
			_glow.visible = k < 0.5
