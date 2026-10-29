class_name GlitchBolt
extends Node3D
## A zombie's amber glitch bolt (C27b): a real projectile, slow enough to sidestep, never a
## hitscan. The arena's director (scripts/fight/daemon_director.gd) keeps a fixed pool of them
## and throws one from the zombie's claw at where its prey was; it flies straight at its speed,
## its trail of amber sparks behind it (A4's pooled trails), and it ends at the first thing it
## meets: the level (a wall, the floor, cover: never through it), a daemon, or a player's body
## within its radius, or when its life runs out. A deciding bolt (alone, or the host's) lands its
## damage on the player it meets through the director, the combat path; a joiner's only draws
## the host's and judges nothing. SIGSTOP holds it in the air while its zombie is frozen.
##
## Its look: a cut amber crystal, a white-hot core inside, both made once and shared by every
## bolt; it glitches sideways a hand's width now and then and flickers. Nothing is made per frame.
## Fiction only.

const Palette = preload("res://scripts/palette.gd")
## What a bolt meets of the world: the level and the targets layer (daemons, players' avatars).
const WORLD_MASK := 1 | 4
## The meta a player's avatar carries its id in (scripts/net/remote_player.gd).
const PLAYER_ID_META := "player_id"
## The crystal's length and width, the core's share of it, and how bright it burns.
const LENGTH_M := 0.7
const WIDTH_M := 0.26
const CORE_SHARE := 0.45
const ENERGY := 4.5
## The glitch: how often it may jump, how far, and for how long.
const GLITCH_HZ := 9.0
const GLITCH_M := 0.12
const GLITCH_S := 0.04

## In flight now, and its id (the host's count, in a match; 0 alone).
var live := false
var id := 0
## Its own judge (alone, or the host's): lands its damage. A joiner's only draws.
var deciding := false
var brain: DaemonBrain = null
var velocity := Vector3.ZERO
var radius := 0.3
var life_left := 0.0
## Why it ended: "", "level", "player", "daemon", "life", "stopped"; and where (world space).
var ended := ""
var end_at := Vector3.INF
## The player it met, when it met one, and the one it was thrown at (its SIGSTOP holds it).
var met := 0
var target := 0

var _director: Node = null
var _look: Node3D
var _age := 0.0
var _glitch_n := -1

static var _shell_mesh: ArrayMesh
static var _core_mesh: ArrayMesh
static var _shell_material: StandardMaterial3D
static var _core_material: StandardMaterial3D


func _init() -> void:
	_statics()
	_look = Node3D.new()
	_look.name = "Look"
	add_child(_look)
	var shell := MeshInstance3D.new()
	shell.mesh = _shell_mesh
	shell.material_override = _shell_material
	shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(shell)
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.material_override = _core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(core)
	visible = false
	set_physics_process(false)


## Thrown from `from` along `dir` (world space) at `speed`, living `life_s`, `radius_m` round.
func launch(director: Node, owner_brain: DaemonBrain, from: Vector3, dir: Vector3, speed: float, life_s: float, radius_m: float, decide: bool, at_player: int = 0) -> void:
	_director = director
	brain = owner_brain
	deciding = decide
	target = at_player
	velocity = dir.normalized() * speed
	radius = radius_m
	life_left = life_s
	ended = ""
	met = 0
	_age = 0.0
	global_position = from
	look_at_from_position(from, from + velocity, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	live = true
	visible = true
	set_physics_process(true)
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.follow(self, Palette.HOSTILE_AMBER)


func _physics_process(delta: float) -> void:
	if not live:
		return
	if brain != null and _director != null and _held():
		return  # SIGSTOP holds it where it is
	_age += delta
	life_left -= delta
	var from := global_position
	var step := velocity * delta
	var to := from + step
	var way := velocity.normalized()
	# The level and the targets layer first (a daemon's body, an avatar's hit volume), past this
	# bolt's own zombie.
	var query := PhysicsRayQueryParameters3D.create(from, to + way * radius, WORLD_MASK)
	if brain != null and is_instance_valid(brain.dummy):
		query.exclude = [brain.dummy.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var reach := from.distance_to(hit["position"]) if not hit.is_empty() else INF
	# Then the players' bodies, a body's radius plus its own round each one's middle.
	var bodies: Dictionary = _director.bodies() if _director != null else {}
	var nearest := 0
	var nearest_at := INF
	for id in bodies:
		var along := clampf((bodies[id] - from).dot(way), 0.0, step.length())
		if along >= reach:
			continue
		var closest: Vector3 = from + way * along
		# Within reach of the body, and nothing of the level between the bolt and it: never round
		# a corner of cover (Codex review).
		if closest.distance_to(bodies[id]) <= radius + DaemonDirector.BODY_RADIUS_M and along < nearest_at and _director.clear(closest, bodies[id]):
			nearest = id
			nearest_at = along
	if nearest != 0:
		global_position = from + way * nearest_at
		met = nearest
		if deciding:
			_director.bolt_met(brain, nearest, way)
		_end("player")
		return
	if not hit.is_empty():
		global_position = hit["position"]
		var collider = hit["collider"]
		# A player's avatar in a match: its hit volume is on the targets layer, met before its middle.
		if is_instance_valid(collider) and collider.has_meta(PLAYER_ID_META) and bodies.has(int(collider.get_meta(PLAYER_ID_META))):
			met = int(collider.get_meta(PLAYER_ID_META))
			if deciding:
				_director.bolt_met(brain, met, way)
			_end("player")
			return
		var daemon: bool = is_instance_valid(collider) and collider.is_in_group(DaemonDirector.TARGET_GROUP)
		var fx := ParticleFx.of(self)
		if fx != null:
			fx.impact(hit["position"], hit["normal"], true, Palette.HOSTILE_AMBER)
		_end("daemon" if daemon else "level")
		return
	global_position = to
	if life_left <= 0.0:
		_end("life")
		return
	_glitch()


## Seconds it has flown.
func age() -> float:
	return _age


## Ends it now, nothing landed (a round's reset, the arena going, the director's mode changing).
func stop() -> void:
	if live:
		_end("stopped")


func _end(why: String) -> void:
	ended = why
	end_at = global_position
	live = false
	visible = false
	set_physics_process(false)
	if _director != null:
		_director.bolt_done(self)


## SIGSTOP's hold: the player it was thrown at, whatever its zombie does now (Codex review); a
## joiner's by the host's word on its zombie.
func _held() -> bool:
	if deciding:
		return _director.frozen(target)
	return brain.word_frozen


## Jumps sideways a hand's width now and then, for a moment, and flickers.
func _glitch() -> void:
	var n := int(floor(_age * GLITCH_HZ))
	var tau := _age - n / GLITCH_HZ
	var jump := Vector3.ZERO
	if tau < GLITCH_S and _roll(n, 1) < 0.4:
		jump = Vector3(_roll(n, 2) - 0.5, _roll(n, 3) - 0.5, 0.0) * 2.0 * GLITCH_M
	_look.position = jump
	var flicker := 0.85 + 0.3 * _roll(int(floor(_age * 30.0)), 4)
	_look.scale = Vector3(flicker, flicker, 1.0)
	if n != _glitch_n:
		_glitch_n = n


func _roll(a: int, b: int) -> float:
	return float(hash(Vector3i(a, b, get_instance_id() & 0xffff)) & 0xffff) / 65535.0


static func _statics() -> void:
	if _shell_mesh != null:
		return
	_shell_mesh = _crystal(LENGTH_M, WIDTH_M)
	_core_mesh = _crystal(LENGTH_M * CORE_SHARE, WIDTH_M * CORE_SHARE)
	_shell_material = _glow(Palette.HOSTILE_AMBER, ENERGY, 0.85)
	_core_material = _glow(Color(1.0, 0.95, 0.8), ENERGY * 1.4, 1.0)


## A six-sided crystal along -Z, `length` long and `width` across, pointed at both ends, longer
## ahead than behind.
static func _crystal(length: float, width: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0.0, 0.0, -length * 0.6)
	var tail := Vector3(0.0, 0.0, length * 0.4)
	var ring := []
	for i in 6:
		var a := TAU * i / 6.0
		ring.append(Vector3(cos(a), sin(a), 0.0) * width * 0.5)
	for i in 6:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 6]
		st.add_vertex(tip)
		st.add_vertex(b)
		st.add_vertex(a)
		st.add_vertex(tail)
		st.add_vertex(a)
		st.add_vertex(b)
	st.generate_normals()
	return st.commit()


static func _glow(color: Color, energy: float, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(color.r * energy, color.g * energy, color.b * energy, alpha)
	return m
