extends Node3D
## A daemon's death in shards (A2b), on top of A2's derezz (scripts/derezz_fx.gd), which still
## plays: the creature's own parts, each where it stood at the killing shot, burst apart (outward
## from its middle, up, and along the shot), tumbling, falling, bouncing once off the ground it
## stood on, then breaking up cell by cell (the shell's and the core's presence) until nothing is
## left. It hangs under the derezz and goes with it, or frees itself after LIFE_S if that is
## sooner. Broken, every shell part is solid crystal: a zombie's wire bones and its ghosts burst as
## obsidian shards. One MultiMesh for each shape and look the daemon had, the same unit meshes and
## the same shared materials as every daemon, glitching hard (the instance uniform `unstable` at
## full).
##
## Made once at the death, then only moved: each frame sets its parts' transforms and fades their
## presence; nothing else is made until it frees itself. Its motion steps at the game's pace
## (SIGSTOP slows it) and its dice are the daemon's seed, so the same death plays the same way.
## Cosmetic only: no collision, no physics body, no ray.

## Every shatter joins this group, so the checks can find it (not the derezz's, which counts deaths).
const GROUP := &"daemon_shatter"
## How long the burst lasts, in seconds; how fast the parts fly out, up and along the shot, in m/s;
## their pull down; the share of speed a bounce keeps; how fast they tumble, in radians a second.
const LIFE_S := 1.3
const BURST_SPEED := 2.6
const BURST_UP := 2.4
const SHOT_PUSH := 2.2
const GRAVITY := 9.8
const BOUNCE := 0.35
const SPIN_LOW := 4.0
const SPIN_HIGH := 13.0
## Each part breaks up over the last share of its life.
const FADE_SHARE := 0.55

var _sets: Array[MultiMesh] = []
var _set_of := PackedInt32Array()
var _slot := PackedInt32Array()
var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _axis := PackedVector3Array()
var _spin := PackedFloat32Array()
var _shape: Array[Basis] = []
var _custom := PackedColorArray()
var _ground := 0.0
var _age := 0.0
## Steps the daemons' shared shader clock (the burst may outlast every daemon still drawn).
var _ticker := Callable()


## Starts the burst of `parts` (each a shape, a look, its world transform and its custom data),
## drawn with `meshes` and `materials` (the daemons' own, by shape and by look), on the ground at
## world height `ground.y`, from the middle `center`, the shot's level way `shot` pushing them,
## its dice the daemon's `seed`; `uniforms` the daemon's instance uniforms; `ticker` steps the
## daemons' shared shader clock by a delta. Call it once, in the tree.
func start(parts: Array[Dictionary], meshes: Array[ArrayMesh], materials: Array[ShaderMaterial], ground: Vector3, center: Vector3, shot: Vector3, seed: float, uniforms: Dictionary, ticker: Callable = Callable()) -> void:
	add_to_group(GROUP)
	_ticker = ticker
	name = "Shatter"
	# Placed in the world, whatever it hangs under (a derezz, which it goes with).
	top_level = true
	_ground = ground.y
	var keys := []
	var counts := PackedInt32Array()
	for p in parts:
		var key := Vector2i(p["shape"], p["look"])
		var at := keys.find(key)
		if at < 0:
			keys.append(key)
			counts.append(0)
			at = keys.size() - 1
		_set_of.append(at)
		_slot.append(counts[at])
		counts[at] += 1
	for k in keys.size():
		var key: Vector2i = keys[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = meshes[key.x]
		mm.instance_count = counts[k]
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = materials[key.y]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		for u in uniforms:
			node.set_instance_shader_parameter(u, uniforms[u])
		node.set_instance_shader_parameter("unstable", 1.0)
		node.set_instance_shader_parameter("hit", 0.0)
		_sets.append(mm)
	var push := Vector3(shot.x, 0.0, shot.z).normalized() * SHOT_PUSH
	var salt := int(seed * 1000.0)
	for i in parts.size():
		var xf: Transform3D = parts[i]["xf"]
		var out := xf.origin - center
		out.y = 0.0
		var a := TAU * _dice(salt, i, 1)
		var spread := Vector3(cos(a), 0.0, sin(a)) * 0.8
		var radial := out.normalized() if out.length_squared() > 0.0001 else spread
		_pos.append(xf.origin)
		_vel.append((radial + spread * 0.5) * BURST_SPEED * (0.5 + _dice(salt, i, 2)) + Vector3.UP * BURST_UP * (0.4 + _dice(salt, i, 3)) + push * (0.5 + _dice(salt, i, 4)))
		var axis := Vector3(_dice(salt, i, 5) - 0.5, _dice(salt, i, 6) - 0.5, _dice(salt, i, 7) - 0.5)
		_axis.append(axis.normalized() if axis.length_squared() > 0.0001 else Vector3.UP)
		_spin.append(lerpf(SPIN_LOW, SPIN_HIGH, _dice(salt, i, 8)))
		_shape.append(xf.basis)
		# Broken, every part is solid crystal: a wire bone or a ghost bursts as obsidian shards.
		var c: Color = parts[i]["custom"]
		if parts[i]["look"] == 0:
			c.g = 0.0
			c.a = 0.0
		_custom.append(c)
	global_transform = Transform3D.IDENTITY
	_apply()


## The parts in the burst.
func part_count() -> int:
	return _pos.size()


## Where each part is now, in the world.
func positions() -> PackedVector3Array:
	return _pos


func age() -> float:
	return _age


func _physics_process(delta: float) -> void:
	if _ticker.is_valid():
		_ticker.call(delta)
	_age += delta
	if _age >= LIFE_S:
		queue_free()
		return
	for i in _pos.size():
		var v := _vel[i] + Vector3.DOWN * (GRAVITY * delta)
		var p := _pos[i] + v * delta
		if p.y < _ground and v.y < 0.0:
			p.y = _ground
			v = Vector3(v.x * 0.6, -v.y * BOUNCE, v.z * 0.6)
		_vel[i] = v
		_pos[i] = p
	_apply()


func _apply() -> void:
	var fade := clampf((_age / LIFE_S - (1.0 - FADE_SHARE)) / FADE_SHARE, 0.0, 1.0)
	var presence := 1.0 - fade * fade
	for i in _pos.size():
		var mm := _sets[_set_of[i]]
		mm.set_instance_transform(_slot[i], Transform3D(Basis(_axis[i], _spin[i] * _age) * _shape[i], _pos[i]))
		var c := _custom[i]
		c.b = presence * c.b
		mm.set_instance_custom_data(_slot[i], c)


static func _dice(salt: int, i: int, k: int) -> float:
	return float(hash(Vector3i(salt, i, k)) & 0xffff) / 65535.0
