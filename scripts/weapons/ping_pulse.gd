class_name PingPulse
extends Node3D
## One ping (C28, PRD 5.2: "sonar pulse that reveals hidden daemons"): the sonar ring going out from
## where its pinger stood, and what it meets. The ring grows from the pinger's middle to the weapon's
## ping_radius_m over ping_ring_s, through the level: a daemon whose middle the ring has reached is
## met, once. On the pinger's screen (`reveals`) a daemon met is outlined through the level for
## reveal_s (scripts/weapons/ping_reveal.gd). Where the daemons are decided (`deciding`: alone, or
## the host's pulse in a match) a daemon met in the middle of its tell has that attack called off
## and staggers (the arena's director, scripts/fight/daemon_director.gd); elsewhere it only draws.
## Nothing is damaged and nothing is roused: a ping has no damage at all.
##
## The look: a flat ring across the floor with a bright front, a fading wash and echo lines behind
## it, a low wall of light standing on the front (shaders/ping_wave.gdshader), a disc of lime streaks
## flying out with the front (scripts/fx/particle_fx.gd's ping pool), and a small burst on each
## daemon it meets; all of it fades out after the ring stops. The meshes and materials are made once
## for every pulse; a pulse only scales its wall and sets its two nodes' instance uniforms.
##
## Fiction only: a ping is a game object; nothing real is sent or listened for.

## A daemon met, and the pulse done (after its fade), with how many it met.
signal met(dummy: Node3D)
signal finished(met_count: int)

const Palette = preload("res://scripts/palette.gd")
const WaveShader = preload("res://shaders/ping_wave.gdshader")
const TARGET_GROUP := &"targets"
## The wall of light on the ring's front, metres tall; how long the whole pulse fades after the ring
## stops; the floor ring's lift off the floor; the front's width on the floor; the burst on a daemon
## met, metres.
const WALL_M := 1.6
const FADE_S := 0.35
const LIFT_M := 0.03
const FRONT_M := 0.6
const MET_BURST_M := 1.6
## Where the streaks fly from, over the floor.
const STREAKS_UP_M := 0.2

static var _floor_mesh: PlaneMesh
static var _wall_mesh: CylinderMesh
static var _floor_material: ShaderMaterial
static var _wall_material: ShaderMaterial

## The weapon (a WeaponDef with fire_mode ping), the ring's centre (world space, the pinger's
## middle) and the floor under it; whether it decides (staggers daemons) and whether it reveals.
var weapon: Resource
var center := Vector3.ZERO
var floor_y := 0.0
var deciding := false
var reveals := false

var _age := 0.0
var _met: Array[Node3D] = []
var _floor: MeshInstance3D
var _wall: MeshInstance3D
var _ended := false


## A ping of `def` from `at` (world space, the pinger's middle) over the floor at `floor_height`,
## under `parent` (the arena or the scene that holds it): judged here when `decide`, outlined here
## when `reveal`.
static func spawn(parent: Node, def: Resource, at: Vector3, floor_height: float, decide: bool, reveal: bool) -> PingPulse:
	var pulse := PingPulse.new()
	pulse.name = "PingPulse"
	pulse.weapon = def
	pulse.center = at
	pulse.floor_y = floor_height
	pulse.deciding = decide
	pulse.reveals = reveal
	parent.add_child(pulse)
	return pulse


func _ready() -> void:
	global_position = Vector3(center.x, floor_y, center.z)
	_floor = MeshInstance3D.new()
	_floor.name = "Floor"
	_floor.mesh = _floor_shape()
	_floor.material_override = _floor_look()
	_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var span: float = weapon.ping_radius_m + FRONT_M
	_floor.scale = Vector3(span, 1.0, span)
	_floor.position.y = LIFT_M
	add_child(_floor)
	_wall = MeshInstance3D.new()
	_wall.name = "Wall"
	_wall.mesh = _wall_shape()
	_wall.material_override = _wall_look()
	_wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall.position.y = WALL_M * 0.5
	add_child(_wall)
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.ping(Vector3(center.x, floor_y + STREAKS_UP_M, center.z), Palette.LIME, weapon.ping_radius_m, weapon.ping_ring_s)
	_step(0.0)


func _physics_process(delta: float) -> void:
	_step(delta)


## The ring's radius now, metres.
func radius() -> float:
	return weapon.ping_radius_m * clampf(_age / weapon.ping_ring_s, 0.0, 1.0)


## Seconds since it went out.
func age() -> float:
	return _age


## The daemons it has met, in the order met.
func met_daemons() -> Array[Node3D]:
	return _met


func ended() -> bool:
	return _ended


func _step(delta: float) -> void:
	if _ended:
		return
	_age += delta
	var r := radius()
	_meet(r)
	var strength := 1.0 if _age <= weapon.ping_ring_s else clampf(1.0 - (_age - weapon.ping_ring_s) / FADE_S, 0.0, 1.0)
	for node in [_floor, _wall]:
		node.set_instance_shader_parameter(&"radius_m", r)
		node.set_instance_shader_parameter(&"reach_m", weapon.ping_radius_m)
		node.set_instance_shader_parameter(&"strength", strength)
	_wall.scale = Vector3(maxf(r, 0.01), WALL_M, maxf(r, 0.01))
	if _age >= weapon.ping_ring_s + FADE_S:
		_ended = true
		finished.emit(_met.size())
		queue_free()


## Every live daemon of this pulse's own arena whose middle the ring has reached, met once each.
func _meet(r: float) -> void:
	var scope := get_parent()
	if scope == null:
		return
	var fx := ParticleFx.of(self)
	for dummy in get_tree().get_nodes_in_group(TARGET_GROUP):
		if not scope.is_ancestor_of(dummy) or not dummy.has_method("art_node") or _met.has(dummy) or not dummy.is_alive():
			continue
		var middle: Vector3 = dummy.threat_point()
		if center.distance_to(middle) > r:
			continue
		_met.append(dummy)
		if reveals and dummy.art_node() != null:
			PingReveal.of(dummy.art_node(), dummy.tag_text).light(weapon.reveal_s, weapon.reveal_fade_s)
		if deciding:
			var director := DaemonDirector.of(dummy)
			if director != null:
				director.pinged(dummy, center)
		if fx != null:
			fx.blast(middle, Palette.LIME, MET_BURST_M)
		met.emit(dummy)


static func _floor_shape() -> PlaneMesh:
	if _floor_mesh == null:
		_floor_mesh = PlaneMesh.new()
		_floor_mesh.size = Vector2(2.0, 2.0)
	return _floor_mesh


static func _wall_shape() -> CylinderMesh:
	if _wall_mesh == null:
		_wall_mesh = CylinderMesh.new()
		_wall_mesh.top_radius = 1.0
		_wall_mesh.bottom_radius = 1.0
		_wall_mesh.height = 1.0
		_wall_mesh.radial_segments = 96
		_wall_mesh.rings = 1
		_wall_mesh.cap_top = false
		_wall_mesh.cap_bottom = false
	return _wall_mesh


static func _floor_look() -> ShaderMaterial:
	if _floor_material == null:
		_floor_material = _look(false)
	return _floor_material


static func _wall_look() -> ShaderMaterial:
	if _wall_material == null:
		_wall_material = _look(true)
	return _wall_material


static func _look(wall: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WaveShader
	m.set_shader_parameter("wall", wall)
	m.set_shader_parameter("color", Palette.LIME)
	m.set_shader_parameter("front_color", Palette.LIME_HI)
	m.set_shader_parameter("front_m", FRONT_M)
	return m
