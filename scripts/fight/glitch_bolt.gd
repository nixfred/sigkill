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
## SIGHUP (C32): a confused zombie's lash throws one at another daemon (lash_scale above 0): a deciding one
## lands lash_scale of its damage on the daemon it meets, through the director.
##
## Its look: a cut amber crystal, a white-hot core inside, both made once and shared by every
## bolt; it glitches sideways a hand's width now and then and flickers. Nothing is made per frame.
## The shell's true body (M7) throws the same bolt in its own red (C44): crimson crystal, a pink-white core, red sparks; and
## so does a pegged core (W1).
## Fiction only.

const Palette = preload("res://scripts/palette.gd")
## What a bolt meets of the world: the level and the targets layer (daemons, players' avatars).
const WORLD_MASK := 1 | 4
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
## On a joiner, the host's word that SIGSTOP holds this bolt (Codex review).
var held_word := false
## A lash's share of its damage on the daemon it meets (C32); 0 for every other bolt, which only stops there.
var lash_scale := 0.0

var _director: Node = null
var _look: Node3D
var _age := 0.0
var _glitch_n := -1

static var _shell_mesh: ArrayMesh
static var _core_mesh: ArrayMesh
static var _shell_material: StandardMaterial3D
static var _core_material: StandardMaterial3D
static var _shell_red: StandardMaterial3D
static var _core_red: StandardMaterial3D
## A thrower's own colour (W6's fold-in of W5's known issue: the man in the middle's bolts in its violet): by the art's
## bolt_color, made once each and kept.
static var _tinted := {}
## This bolt's colour as thrown: its trail's and its impact's.
var tint := Color(1.0, 0.690196078, 0.0)
var _shell_mi: MeshInstance3D
## Its size by its thrower (look_for(): a boss's bigger and drawn out, P2), the flicker on top of it.
var _size := Vector3.ONE
var _core_mi: MeshInstance3D


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
	_shell_mi = shell
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.material_override = _core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_look.add_child(core)
	_core_mi = core
	visible = false
	set_physics_process(false)


## Thrown from `from` along `dir` (world space) at `speed`, living `life_s`, `radius_m` round.
func launch(director: Node, owner_brain: DaemonBrain, from: Vector3, dir: Vector3, speed: float, life_s: float, radius_m: float, decide: bool, at_player: int = 0) -> void:
	_director = director
	brain = owner_brain
	deciding = decide
	target = at_player
	held_word = false
	velocity = dir.normalized() * speed
	radius = radius_m
	life_left = life_s
	ended = ""
	met = 0
	lash_scale = 0.0
	_age = 0.0
	global_position = from
	look_at_from_position(from, from + velocity, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
	live = true
	visible = true
	set_physics_process(true)
	# The shell's own red (M7's leftover, C44), every other thrower's amber; a boss's bolt bigger and drawn out (P2).
	var look := look_for(owner_brain.kind if owner_brain != null else "")
	_shell_mi.material_override = look["shell"]
	_core_mi.material_override = look["core"]
	tint = look["tint"]
	_size = look["scale"]
	_look.scale = _size
	# A thrower whose art names its own bolt colour (the man in the middle's violet, W5) throws in it.
	var art = owner_brain.dummy.art_node() if owner_brain != null and is_instance_valid(owner_brain.dummy) and owner_brain.dummy.has_method("art_node") else null
	var own = art.get("bolt_color") if art != null else null
	if own is Color:
		tint = own
		if not _tinted.has(own):
			_tinted[own] = [_glow(own, ENERGY, 0.85), _glow((own as Color).lerp(Color.WHITE, 0.7), ENERGY * 1.4, 1.0)]
		_shell_mi.material_override = _tinted[own][0]
		_core_mi.material_override = _tinted[own][1]
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.follow(self, tint)


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
	# The level and the targets layer first (a daemon's body), past this bolt's own zombie and the
	# players' avatars: a player is met below where it was last heard, never where its avatar is
	# drawn a moment behind (Codex review).
	var query := PhysicsRayQueryParameters3D.create(from, to + way * radius, WORLD_MASK)
	var skip: Array[RID] = []
	if _director != null:
		skip = _director.avatar_rids()
	if brain != null and is_instance_valid(brain.dummy):
		skip.append(brain.dummy.get_rid())
	query.exclude = skip
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
		var daemon: bool = is_instance_valid(collider) and collider.is_in_group(DaemonDirector.TARGET_GROUP)
		if daemon and deciding and lash_scale > 0.0 and _director != null:
			_director.lash_met(brain, collider, way, lash_scale)  # a confused zombie's lash (C32)
		var fx := ParticleFx.of(self)
		if fx != null:
			fx.impact(hit["position"], hit["normal"], true, tint)
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


## SIGSTOP's hold: the player it was thrown at, whatever its zombie does now; a joiner's by the
## host's word on this bolt (Codex review).
func _held() -> bool:
	if deciding:
		return _director.frozen(target)
	return held_word


## Jumps sideways a hand's width now and then, for a moment, and flickers.
func _glitch() -> void:
	var n := int(floor(_age * GLITCH_HZ))
	var tau := _age - n / GLITCH_HZ
	var jump := Vector3.ZERO
	if tau < GLITCH_S and _roll(n, 1) < 0.4:
		jump = Vector3(_roll(n, 2) - 0.5, _roll(n, 3) - 0.5, 0.0) * 2.0 * GLITCH_M
	_look.position = jump
	var flicker := 0.85 + 0.3 * _roll(int(floor(_age * 30.0)), 4)
	_look.scale = Vector3(flicker * _size.x, flicker * _size.y, _size.z)
	if n != _glitch_n:
		_glitch_n = n


func _roll(a: int, b: int) -> float:
	return float(hash(Vector3i(a, b, get_instance_id() & 0xffff)) & 0xffff) / 65535.0


## A thrower's bolt by its kind (P2: M7's shell's read as pink-white blobs among its own glowing nodes): the shell's and
## a pegged core's in their red, a deep red core instead of a near-white one, less bright so the bloom keeps the red, and
## 1.35 times as wide and twice as long, a dart that shows its way; every other thrower's in amber at its usual size.
static func look_for(kind: String) -> Dictionary:
	_statics()
	if kind == "shell" or kind == "pegged":  # W1: a pegged core's too
		return {"shell": _shell_red, "core": _core_red, "tint": Palette.CRIMSON, "scale": Vector3(1.35, 1.35, 2.0)}
	return {"shell": _shell_material, "core": _core_material, "tint": Palette.HOSTILE_AMBER, "scale": Vector3.ONE}


## Its two amber materials, made now if they are not yet (the arena's warm-up draws them as it loads, so a zombie's first
## bolt does not wait on their compile; scripts/fx/shader_warmup.gd). The red pair look_for gives a thrower's shell
## and a pegged core is not listed: _glow gives all four the same features and only the colour differs, which is a
## uniform, so the red pair draws with the shader these two have compiled (tests/shader_warmup_test.gd checks it).
static func materials() -> Array[Material]:
	_statics()
	return [_shell_material, _core_material]


static func _statics() -> void:
	if _shell_mesh != null:
		return
	_shell_mesh = _crystal(LENGTH_M, WIDTH_M)
	_core_mesh = _crystal(LENGTH_M * CORE_SHARE, WIDTH_M * CORE_SHARE)
	_shell_material = _glow(Palette.HOSTILE_AMBER, ENERGY, 0.85)
	_core_material = _glow(Color(1.0, 0.95, 0.8), ENERGY * 1.4, 1.0)
	_shell_red = _glow(Palette.CRIMSON, ENERGY * 0.75, 0.85)
	_core_red = _glow(Color(1.0, 0.36, 0.42), ENERGY * 0.9, 1.0)  # P2: deep red, never washed to white


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
