extends Node3D
## One throw of the fork bomb (C19, PRD 5.2): a chain of bomblets that fork 1, 2, 4, 8.
## The thrown bomb (generation 0) goes off when its fuse runs out or at once on hitting a
## player or a daemon; every blast of generation 0 to 2 makes two children that scatter out
## and up from it, each on a shorter fuse; the last generation only goes off. Fifteen blasts
## at most per throw (BLASTS_LAST, whatever the tuning says). Every number is in
## resources/fork_bomb.tres (scripts/weapons/fork_bomb_tuning.gd).
##
## Cheap on the frame: one node per throw, no physics bodies. Each live bomblet is a small
## glowing sphere moved by this node, one ray a physics frame: it bounces off the level and,
## on a chain that decides, goes off on touching a player or a daemon. Each blast is a short
## neon ring, smaller and brighter each generation, freed after ring_s. The chain frees
## itself once its last bomblet has gone off.
##
## Who decides: an authoritative chain (solo, or the host's in a match) runs the fuses and
## the contacts and hands every blast to its judge (a Callable the thrower's side gives it),
## which applies the damage. A chain on a joiner's screen only draws: its bomblets fly the
## same arcs but go off only on the host's word (apply_blast()), at the place the host says,
## and its children's scatter comes from the same seed (scatter()), so both sides draw the
## same chain; it never judges anything.
##
## The live cap: bomblets of one thrower live at once across all their chains in one place
## (live_of()). A child past the tuning's live_cap is not made, and counted.
##
## Cosmetic fiction: nothing forks, runs or touches anything real.

## Every blast: its generation, its index in that generation (children of blast i of a
## generation are 2i and 2i+1 of the next) and where, in world space.
signal blasted(gen: int, index: int, at: Vector3)
## The chain is done: no bomblet left.
signal finished

const Tuning = preload("res://scripts/weapons/fork_bomb_tuning.gd")
const Palette = preload("res://scripts/palette.gd")
## Every node of a chain and its rings is in this group: the tests count them.
const GROUP := &"fork_bomb"
## The node under a scene's root that holds every chain there.
const FIELD := "ForkBombs"
## A child starts this far above its parent's blast, so it never starts inside the floor.
const LIFT_M := 0.25
## A blast's line of sight to a target starts this far above the blast point.
const SIGHT_LIFT_M := 0.1

var tuning: Tuning
var seed := 0
## Whose bombs these are, for the live cap: one key per thrower in one place.
var thrower_key := ""
## True: runs the fuses and contacts and judges each blast. False: draws the host's chain.
var authoritative := true
## What bomblets bounce off (the level) and what sets one off on contact.
var world_mask := 1
var target_mask := 6
## Never collided with: the thrower's own body.
var exclude: Array[RID] = []
## judge(gen, index, at) for each blast of an authoritative chain: it applies the damage.
var judge := Callable()
## The light skin's colours, from the palette.
var body_color := Palette.MINT
var ring_color := Palette.FLASH

## Blasts so far, per generation and in all; children not made for the live cap.
var blasts := 0
var by_generation: Array[int] = [0, 0, 0, 0]
var refused := 0
## Every blast's children's velocities as made here, [gen, index] -> [Vector3, Vector3]: the
## tests compare the host's and a joiner's.
var scatters := {}

var _bombs: Array = []  # {gen, index, pos, vel, fuse, mesh}
var _mesh: SphereMesh
var _glow: Material
var _done := false


## A throw's chain under `root` (the arena), started at `origin` with `velocity` (world space).
static func spawn(root: Node, with_tuning: Tuning, origin: Vector3, velocity: Vector3, throw_seed: int, key: String, deciding: bool, skin: String, never: Array[RID] = [], judged: Callable = Callable()) -> Node3D:
	var chain = load("res://scripts/weapons/fork_bomb.gd").new()
	chain.name = "ForkBomb"
	chain.tuning = with_tuning
	chain.seed = throw_seed
	chain.thrower_key = key
	chain.authoritative = deciding
	chain.exclude = never
	chain.judge = judged
	chain.body_color = Palette.skin_body(skin)
	chain.ring_color = Palette.skin_beam(skin)
	field_of(root).add_child(chain)
	chain.add_bomb(0, 0, origin, velocity)
	return chain


## The node under `root` that holds its chains, made on first use.
static func field_of(root: Node) -> Node3D:
	var field := root.get_node_or_null(FIELD) as Node3D
	if field == null:
		field = Node3D.new()
		field.name = FIELD
		root.add_child(field)
	return field


## Bomblets `key` has live under `root` right now, every chain together.
static func live_of(root: Node, key: String) -> int:
	var field := root.get_node_or_null(FIELD)
	if field == null:
		return 0
	var n := 0
	for chain in field.get_children():
		if chain.has_method("live_count") and chain.thrower_key == key:
			n += chain.live_count()
	return n


## The thrown bomb's velocity for a throw along `aim`: the throw speed along it, and lift.
static func throw_velocity(with_tuning: Tuning, aim: Vector3) -> Vector3:
	return aim.normalized() * with_tuning.throw_speed + Vector3.UP * with_tuning.throw_lift


## The two children's velocities of blast `index` of generation `gen` in throw `throw_seed`:
## out from the blast in opposite directions, each strayed at random by up to the spread, and
## up. The same seed gives the same scatter on every machine.
static func scatter(with_tuning: Tuning, throw_seed: int, gen: int, index: int) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([throw_seed, gen, index])
	var base := rng.randf() * TAU
	var spread := deg_to_rad(with_tuning.scatter_spread_degrees)
	var out: Array[Vector3] = []
	for k in 2:
		var angle := base + PI * k + rng.randf_range(-spread, spread)
		var lift := with_tuning.scatter_lift * (1.0 + rng.randf_range(-0.15, 0.15))
		out.append(Vector3(cos(angle), 0.0, sin(angle)) * with_tuning.scatter_speed + Vector3.UP * lift)
	return out


func _ready() -> void:
	add_to_group(GROUP)
	_mesh = SphereMesh.new()
	_mesh.radius = tuning.bomb_radius_m
	_mesh.height = tuning.bomb_radius_m * 2.0
	_mesh.radial_segments = 8
	_mesh.rings = 4
	_glow = Palette.unlit_glow(body_color, 3.0)


## Bomblets live right now.
func live_count() -> int:
	return _bombs.size()


## A bomblet of generation `gen`, number `index`, at `pos` moving at `vel` (world space).
func add_bomb(gen: int, index: int, pos: Vector3, vel: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = _mesh
	mesh.material_override = _glow
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.add_to_group(GROUP)
	add_child(mesh)
	mesh.global_position = pos
	_bombs.append({"gen": gen, "index": index, "pos": pos, "vel": vel, "fuse": tuning.fuse_s if gen == 0 else tuning.child_fuse_s, "mesh": mesh})
	# Sparks shed behind it in flight (A4), from the arena's particle pool when it has one free.
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.follow(mesh, ring_color)


func _physics_process(delta: float) -> void:
	if _done:
		return
	var space := get_world_3d().direct_space_state
	for bomb in _bombs.duplicate():
		if not _bombs.has(bomb):
			continue
		bomb["vel"] += Vector3.DOWN * tuning.gravity * delta
		var from: Vector3 = bomb["pos"]
		var to: Vector3 = from + bomb["vel"] * delta
		var query := PhysicsRayQueryParameters3D.create(from, to, world_mask | (target_mask if authoritative else 0))
		query.exclude = exclude
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			bomb["pos"] = to
		elif _is_world(hit["collider"]):
			var normal: Vector3 = hit["normal"] if not (hit["normal"] as Vector3).is_zero_approx() else Vector3.UP
			bomb["pos"] = hit["position"] + normal * 0.02
			bomb["vel"] = (bomb["vel"] as Vector3).bounce(normal) * tuning.bounce
		else:
			_blast(bomb, hit["position"])  # touched a player or a daemon
			continue
		(bomb["mesh"] as Node3D).global_position = bomb["pos"]
		bomb["fuse"] -= delta
		if authoritative and bomb["fuse"] <= 0.0:
			_blast(bomb, bomb["pos"])
		elif not authoritative and bomb["fuse"] <= -tuning.wait_s:
			_drop(bomb)  # the host's word never came
	_finish_if_done()


## The host's word of blast `index` of generation `gen` at `at` (world space), on a chain
## that only draws: the bomblet goes off there, whether or not this screen still has it.
func apply_blast(gen: int, index: int, at: Vector3) -> void:
	if authoritative or gen < 0 or gen >= tuning.generations or index < 0 or index >= (1 << gen):
		return
	var bomb = null
	for one in _bombs:
		if one["gen"] == gen and one["index"] == index:
			bomb = one
	if bomb == null:
		bomb = {"gen": gen, "index": index, "pos": at, "vel": Vector3.ZERO, "fuse": 0.0, "mesh": null}
		_bombs.append(bomb)
	_blast(bomb, at)
	_finish_if_done()


func _blast(bomb: Dictionary, at: Vector3) -> void:
	_drop(bomb)
	if blasts >= Tuning.BLASTS_LAST:
		return
	var gen: int = bomb["gen"]
	var forks: bool = gen + 1 < tuning.generations and gen + 1 < Tuning.GENERATIONS_LAST  # the last generation only goes off
	var kids: Array[Vector3] = []
	if forks:
		kids = scatter(tuning, seed, gen, bomb["index"])
		scatters[[gen, bomb["index"]]] = kids
	blasts += 1
	by_generation[gen] += 1
	_ring(at, gen)
	if authoritative and judge.is_valid():
		judge.call(gen, bomb["index"], at)
	blasted.emit(gen, bomb["index"], at)
	if not forks:
		return
	var basis: Basis = (get_parent() as Node3D).global_transform.basis if get_parent() is Node3D else Basis.IDENTITY
	for k in kids.size():
		if authoritative and live_of(get_parent().get_parent(), thrower_key) >= tuning.live_cap:
			refused += 1
			continue
		add_bomb(gen + 1, bomb["index"] * 2 + k, at + Vector3.UP * LIFT_M, basis * kids[k])


func _drop(bomb: Dictionary) -> void:
	_bombs.erase(bomb)
	if bomb["mesh"] != null and is_instance_valid(bomb["mesh"]):
		bomb["mesh"].queue_free()
	bomb["mesh"] = null


func _finish_if_done() -> void:
	if not _done and _bombs.is_empty():
		_done = true
		finished.emit()
		queue_free()


func _is_world(collider: Object) -> bool:
	return collider is CollisionObject3D and ((collider as CollisionObject3D).collision_layer & world_mask) != 0


## A short neon ring at `at`, laid flat, growing out and fading; smaller and brighter for
## each later generation. Not a child of the chain, so it outlives it by ring_s at most.
func _ring(at: Vector3, gen: int) -> void:
	var size := tuning.ring_radius_m * pow(tuning.ring_shrink, gen)
	# Debris thrown out of the blast (A4), from the arena's particle pool.
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.blast(at, ring_color, size)
	var torus := TorusMesh.new()
	torus.inner_radius = size * 0.82
	torus.outer_radius = size
	torus.rings = 24
	torus.ring_segments = 6
	var mat := Palette.unlit_glow(ring_color, tuning.ring_energy * (1.0 + tuning.ring_brighten * gen))
	var ring := MeshInstance3D.new()
	ring.name = "ForkRing"
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_to_group(GROUP)
	get_parent().add_child(ring)
	ring.global_position = at
	ring.scale = Vector3.ONE * 0.3
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE, tuning.ring_s)
	tween.tween_property(mat, "albedo_color:a", 0.0, tuning.ring_s)
	tween.chain().tween_callback(ring.queue_free)
