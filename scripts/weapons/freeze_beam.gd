class_name FreezeBeam
extends Node3D
## chmod 000's beam as it is drawn (C29): one per shooter, made once and kept (the player's own; on a
## match's screens one under each avatar that beams). While it is fed (aim()) it stretches from the
## emitter to where the beam ends: a thin hot core near white, a wider sheath in the frost opal whose
## light runs in bands toward the target (shaders/freeze_beam.gdshader), a helix of frost shards
## travelling down it, a cold bloom where it ends and its own small spray of frost there (GPU particles,
## its own emitter like a weapon's muzzle burst), with a cold hiss under it all; let go, it fades out in
## FADE_S. Nothing is made per frame: one cylinder for each layer, one MultiMesh of shards, all moved.
##
## Cosmetic: where the beam lands and what it does are judged by the shooter (alone) or the host.

const Palette = preload("res://scripts/palette.gd")
const BeamShader = preload("res://shaders/freeze_beam.gdshader")
const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")

## How long it holds after its last feed (a remote beam is fed once a beam tick), then how long it
## takes to fade out.
const HOLD_S := 0.16
const FADE_S := 0.12
## The layers' radii, metres: the core and the sheath; the sheath swells a little with a slow breath.
const CORE_R := 0.008
const SHEATH_R := 0.032
const BREATH := 0.18
const BREATH_HZ := 5.0
## Energies of the core and the sheath.
const CORE_ENERGY := 4.0
const SHEATH_ENERGY := 2.2
## The shards: how many ride the beam, how far out they turn, how fast they travel (metres a second), how
## many turns of the helix a metre of beam holds, how fast it turns (a second), their size.
const SHARDS := 18
const SHARD_R := 0.07
const SHARD_SPEED := 9.0
const SHARD_PER_M := 0.5
const SHARD_TURNS := 2.2
const SHARD_SIZE := Vector3(0.016, 0.016, 0.06)
## The bloom where it ends: its radius and energy; brighter when it meets a target that freezes.
const BLOOM_R := 0.1
const BLOOM_ENERGY := 3.0
const BLOOM_HIT := 1.8
## The spray where it ends: particles, life, speed.
const SPRAY := 24
const SPRAY_S := 0.4
## The hiss: its loudness and how far it carries.
const HISS_GAIN := 0.35
const HISS_UNIT := 5.0

var _core: MeshInstance3D
var _sheath: MeshInstance3D
var _shards: MultiMeshInstance3D
var _bloom: MeshInstance3D
var _spray: GPUParticles3D
var _hiss: AudioStreamPlayer3D
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _held := 0.0
var _strength := 0.0
var _struck := false
var _clock := 0.0
var _fed := 0


func _init() -> void:
	name = "FreezeBeam"


func _ready() -> void:
	top_level = true
	_core = _layer("Core", CORE_R, true)
	_sheath = _layer("Sheath", SHEATH_R, false)
	var shard_mesh := SphereMesh.new()
	shard_mesh.radial_segments = 4
	shard_mesh.rings = 2
	shard_mesh.radius = 0.5
	shard_mesh.height = 1.0
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = shard_mesh
	mm.instance_count = SHARDS
	_shards = MultiMeshInstance3D.new()
	_shards.name = "Shards"
	_shards.multimesh = mm
	_shards.material_override = Palette.glow(Palette.FROST_HI, BLOOM_ENERGY)
	_shards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shards)
	var bloom_mesh := SphereMesh.new()
	bloom_mesh.radius = BLOOM_R
	bloom_mesh.height = BLOOM_R * 2.0
	bloom_mesh.radial_segments = 10
	bloom_mesh.rings = 5
	_bloom = MeshInstance3D.new()
	_bloom.name = "Bloom"
	_bloom.mesh = bloom_mesh
	_bloom.material_override = Palette.glow(Palette.FROST_HI, BLOOM_ENERGY)
	_bloom.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bloom)
	_spray = _make_spray()
	add_child(_spray)
	_hiss = AudioStreamPlayer3D.new()
	_hiss.name = "Hiss"
	_hiss.stream = Sfx.freeze_hiss()
	_hiss.bus = SettingsApply.EFFECTS
	_hiss.volume_db = linear_to_db(HISS_GAIN)
	_hiss.unit_size = HISS_UNIT
	add_child(_hiss)
	_show(false)


## The beam runs from `from` to `to` (world space) now; `struck` when it meets something it freezes.
func aim(from: Vector3, to: Vector3, struck: bool = false) -> void:
	if not from.is_finite() or not to.is_finite():
		return
	_from = from
	_to = to
	_struck = struck
	_held = HOLD_S
	_fed += 1
	if _strength <= 0.0:
		_strength = 0.001
		_show(true)
	_place()


## Lets go at once (a death, a swap): it fades.
func stop() -> void:
	_held = 0.0


## True while it is drawn.
func on() -> bool:
	return _strength > 0.0


## Where it ends now (world space), and how many times it has been fed, for the checks.
func end_point() -> Vector3:
	return _to


func feeds() -> int:
	return _fed


func strength() -> float:
	return _strength


func _process(delta: float) -> void:
	if _strength <= 0.0:
		return
	_clock = fmod(_clock + delta, 3600.0)
	if _held > 0.0:
		_held -= delta
		_strength = minf(_strength + delta / FADE_S, 1.0)
	else:
		_strength = maxf(_strength - delta / FADE_S, 0.0)
	if _strength <= 0.0:
		_show(false)
		return
	_place()


func _place() -> void:
	var span := _to - _from
	var length := span.length()
	if length < 0.01:
		return
	var way := span / length
	var basis := _along(way)
	var mid := (_from + _to) * 0.5
	var breath := 1.0 + BREATH * sin(TAU * BREATH_HZ * _clock)
	for layer in [_core, _sheath]:
		var r: float = CORE_R if layer == _core else SHEATH_R * breath
		layer.global_transform = Transform3D(basis.scaled(Vector3(r, length, r)), mid)
		layer.set_instance_shader_parameter(&"strength", _strength)
		layer.set_instance_shader_parameter(&"length_m", length)
	var mm := _shards.multimesh
	var right := basis.x
	var up := basis.z
	for i in SHARDS:
		var u := fposmod(float(i) / SHARDS + _clock * SHARD_SPEED / maxf(length, 1.0), 1.0)
		var turn := TAU * (u * length * SHARD_PER_M + float(i) * 0.618 + _clock * SHARD_TURNS)
		var off := (right * cos(turn) + up * sin(turn)) * SHARD_R * (0.4 + 0.6 * sin(PI * u))
		var at := _from + span * u + off
		var size := SHARD_SIZE * _strength * (0.5 + 0.5 * sin(PI * u))
		mm.set_instance_transform(i, Transform3D(_along_z(way).scaled(size), at))
	_bloom.global_position = _to
	_bloom.scale = Vector3.ONE * (BLOOM_HIT if _struck else 1.0) * (0.6 + 0.4 * _strength) * breath
	_spray.global_transform = Transform3D(_along_z(-way), _to)
	_spray.emitting = _held > 0.0
	if _hiss.is_inside_tree():
		_hiss.global_position = _from
		if _held > 0.0 and not _hiss.playing:
			_hiss.play()


func _show(on_now: bool) -> void:
	for node in [_core, _sheath, _shards, _bloom]:
		node.visible = on_now
	if _spray != null:
		_spray.emitting = false
	if not on_now and _hiss != null and _hiss.playing:
		_hiss.stop()


## A basis whose Y runs along `way` (a cylinder's length).
static func _along(way: Vector3) -> Basis:
	var side := way.cross(Vector3.UP if absf(way.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT).normalized()
	return Basis(side, way, side.cross(way).normalized())


## A basis whose -Z runs along `way` (a shard pointing down the beam, the spray thrown back).
static func _along_z(way: Vector3) -> Basis:
	var up := Vector3.UP if absf(way.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(way, up)


func _layer(layer_name: String, radius: float, is_core: bool) -> MeshInstance3D:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = BeamShader
	mat.set_shader_parameter("color", Palette.FROST)
	mat.set_shader_parameter("hot", Palette.FROST_HI)
	mat.set_shader_parameter("core", 1.0 if is_core else 0.0)
	mat.set_shader_parameter("energy", CORE_ENERGY if is_core else SHEATH_ENERGY)
	var node := MeshInstance3D.new()
	node.name = layer_name
	node.mesh = cyl
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.scale = Vector3.ONE * radius
	add_child(node)
	return node


func _make_spray() -> GPUParticles3D:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3.FORWARD
	m.spread = 70.0
	m.initial_velocity_min = 0.6
	m.initial_velocity_max = 2.2
	m.gravity = Vector3.DOWN * 1.5
	m.damping_min = 1.5
	m.damping_max = 2.5
	m.scale_min = 0.4
	m.scale_max = 1.0
	m.lifetime_randomness = 0.4
	m.use_rotation_3d = true
	m.rotation_3d_min = -Vector3.ONE * 180.0
	m.rotation_3d_max = Vector3.ONE * 180.0
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.03
	var p := GPUParticles3D.new()
	p.name = "Spray"
	p.process_material = m
	p.draw_pass_1 = cube
	p.amount = maxi(1, roundi(SPRAY * ParticleFx.share()))
	p.lifetime = SPRAY_S
	p.local_coords = false
	p.emitting = false
	p.material_override = Palette.glow(Palette.FROST_HI, BLOOM_ENERGY)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2.0, -2.0, -2.0), Vector3(4.0, 4.0, 4.0))
	return p
