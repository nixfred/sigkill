extends Node3D
## One shot of fork() (C24, PRD 5.2 "shotgun whose pellets split in two mid-flight"): a flat
## fan of pellets that fly as fast, short-lived projectiles. Each pellet flies the weapon's
## fork_distance_m, then is replaced by two children angled fork_angle_degrees apart in the
## plane of the fan, flying on at the same speed; a child forks again while the shot has forks
## left (one as user, two while C22's root is on: 6, then 12, then 24). A pellet stops at the
## first wall or body it meets (a parent that hits before its fork never forks) and vanishes at
## the weapon's fire_range. Every number is the weapon's own (resources/fork_shotgun.tres,
## scripts/weapons/weapon_def.gd's fork group).
##
## Cheap on the frame: one node per shot, no physics bodies. Each live pellet is a small
## glowing head with a thin trail behind it, moved by this node one ray a physics frame (split
## at a fork, so a fork happens exactly at its distance). A fork shows as a small flash. The
## node frees itself once its last pellet and flash are gone.
##
## Same pellets on every screen: the fan comes from the aim and the shot's seed alone
## (WeaponDef.fork_spread), and every fork from the parent's direction alone
## (WeaponDef.fork_pair), so a shot with the same origin, aim, seed and forks draws the same
## pellets anywhere. Who decides: a volley that judges (solo, or the host's in a match) hands
## every pellet that meets a body to its judge (a Callable the shooter's side gives it), which
## applies the damage; a volley on a joiner's screen only draws, and its judge is at most this
## machine's own dummies, never a player.
##
## Cosmetic fiction: nothing forks, runs or touches anything real.

## A generation of the shot forked for the first time: `gen` is the children's generation.
signal forked(gen: int)
## The shot is done: no pellet and no flash left. `landed`: pellets its judge counted.
signal finished(landed: int)

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Palette = preload("res://scripts/palette.gd")
const CannonFx = preload("res://scripts/cannon_fx.gd")
## Every volley node is in this group: the tests count them.
const GROUP := &"fork_volley"
## The node under a scene's root that holds every volley there.
const FIELD := "ForkVolleys"
## What stops a pellet as the level (walls, floor, blocks): everything else it meets is a body.
const WORLD_LAYER := 1
## A fork or the range's end counts as reached within this many metres: float sums of steps.
const REACH_EPS := 0.0001
## A trail's direction this close to straight up or down is turned about another axis.
const NEAR_PARALLEL := 0.98
## How bright a pellet's head and trail glow, and its fork flash at its peak.
const HEAD_ENERGY := 4.0
const TRAIL_ENERGY := 2.5
const FLASH_ENERGY := 6.0
## A trail is this thick for each metre of the head's radius.
const TRAIL_THICKNESS := 0.5
## Why a pellet's flight ended.
const FORKED := "forked"
const WALL := "wall"
const BODY := "body"
const RANGE := "range"

var def: WeaponDefScript
var seed := 0
## The shot's aim (world space, unit length): the fan and every fork are turned from it.
var aim := Vector3.FORWARD
## Forks each pellet line makes in this shot.
var forks := 1
## True: hands every pellet that meets a body to judge. False: draws only.
var authoritative := true
## What a pellet's ray meets: the level and the bodies.
var hit_mask := 5
## exclusions() -> Array[RID], asked every physics frame: what pellets pass through (the
## shooter's own body, and in a match every corpse).
var exclusions := Callable()
## judge(collider, gen, at, dir) -> bool for a pellet of generation `gen` that met `collider`
## at `at` flying along `dir`: true when it counted (damage dealt).
var judge := Callable()

## Pellets made per generation (0 the fan), forks done, pellets stopped by the level, by a
## body, those the judge counted, and those that reached the range's end.
var spawned: Array[int] = []
var forked_count := 0
var stopped := 0
var struck := 0
var landed := 0
var expired := 0
## Pellets the judge counted, per generation.
var landed_by_gen: Array[int] = []
## Where every pellet's flight ended and why, [gen, index, place, metres flown, why], why one
## of FORKED, WALL, BODY, RANGE: the tests read it.
var ends: Array = []
## Every pellet's direction, "gen:index" -> Vector3 (children of pellet i of a generation are
## 2i and 2i+1 of the next): the tests compare screens.
var directions := {}

var _pellets: Array = []  # {gen, index, pos, dir, flown, from, live, head, trail}
var _flashes: Array = []  # {node, left}
var _forked_gens := {}
var _head_mesh: SphereMesh
var _trail_mesh: BoxMesh
var _flash_mesh: SphereMesh
var _head_glow: StandardMaterial3D
var _trail_glow: StandardMaterial3D
var _done := false


## A shot of `weapon` under `root` (the arena) from `origin` along `shot_aim` (world space),
## with `shot_seed` and `fork_count` forks. `deciding`: judges what it hits.
static func spawn(root: Node, weapon: WeaponDefScript, origin: Vector3, shot_aim: Vector3, shot_seed: int, fork_count: int, deciding: bool, mask: int, never: Callable = Callable(), judged: Callable = Callable()) -> Node3D:
	var volley = load("res://scripts/weapons/fork_volley.gd").new()
	volley.name = "ForkVolley"
	volley.def = weapon
	volley.seed = shot_seed
	volley.aim = shot_aim.normalized()
	volley.forks = fork_count
	volley.authoritative = deciding
	volley.hit_mask = mask
	volley.exclusions = never
	volley.judge = judged
	field_of(root).add_child(volley)
	volley.fire(origin)
	return volley


## The node under `root` that holds its volleys, made on first use.
static func field_of(root: Node) -> Node3D:
	var field := root.get_node_or_null(FIELD) as Node3D
	if field == null:
		field = Node3D.new()
		field.name = FIELD
		root.add_child(field)
	return field


func _ready() -> void:
	add_to_group(GROUP)


## The fan leaves `origin` (world space): pellet_count pellets of generation 0.
func fire(origin: Vector3) -> void:
	spawned.resize(forks + 1)
	spawned.fill(0)
	landed_by_gen.resize(forks + 1)
	landed_by_gen.fill(0)
	_head_mesh = SphereMesh.new()
	_head_mesh.radius = def.pellet_radius_m
	_head_mesh.height = def.pellet_radius_m * 2.0
	_trail_mesh = BoxMesh.new()
	_trail_mesh.size = Vector3(def.pellet_radius_m * TRAIL_THICKNESS, def.pellet_radius_m * TRAIL_THICKNESS, 1.0)
	_flash_mesh = SphereMesh.new()
	_flash_mesh.radius = def.fork_flash_radius_m
	_flash_mesh.height = def.fork_flash_radius_m * 2.0
	_head_glow = Palette.glow(def.skin_body(), HEAD_ENERGY)
	_trail_glow = Palette.glow(def.skin_beam(), TRAIL_ENERGY)
	var fan := def.fork_spread(aim, seed)
	for i in fan.size():
		_add(0, i, origin, fan[i], 0.0)


## Pellets flying now.
func live_count() -> int:
	return _pellets.size()


## Every live pellet's place, ordered by generation and index: the tests compare two volleys.
func positions() -> PackedVector3Array:
	var keyed := []
	for p in _pellets:
		keyed.append([p["gen"], p["index"], p["pos"]])
	keyed.sort()
	var out := PackedVector3Array()
	for k in keyed:
		out.append(k[2])
	return out


## Every live pellet's [gen, index, metres flown].
func flights() -> Array:
	var out := []
	for p in _pellets:
		out.append([p["gen"], p["index"], p["flown"]])
	out.sort()
	return out


func _physics_process(delta: float) -> void:
	var step := def.pellet_speed * delta
	for p in _pellets.duplicate():
		if p["live"]:
			_advance(p, step)
	for f in _flashes.duplicate():
		f["left"] -= delta
		var node: MeshInstance3D = f["node"]
		if f["left"] <= 0.0:
			node.queue_free()
			_flashes.erase(f)
		else:
			var fade: float = f["left"] / def.fork_flash_s
			node.scale = Vector3.ONE * (2.0 - fade)
			node.transparency = 1.0 - fade
	_finish_if_done()


## Moves pellet `p` on by `dist` metres: a fork at its distance (its children fly the rest of
## the step), a stop at the first wall or body on the way, the end at the range.
func _advance(p: Dictionary, dist: float) -> void:
	var gen: int = p["gen"]
	var next_fork: float = (gen + 1) * def.fork_distance_m if gen < forks else INF
	var goal: float = minf(next_fork, def.fire_range)
	var go: float = clampf(minf(dist, goal - p["flown"]), 0.0, dist)
	var to: Vector3 = p["pos"] + p["dir"] * go
	if go > 0.0:
		var hit := _ray(p["pos"], to)
		if not hit.is_empty():
			_stop(p, hit)
			return
	p["pos"] = to
	p["flown"] += go
	if p["flown"] >= def.fire_range - REACH_EPS:
		expired += 1
		_drop(p, RANGE)
	elif p["flown"] >= next_fork - REACH_EPS:
		_fork(p, dist - go)
	else:
		_place(p)


## Pellet `p` forks where it is: two children of the next generation, each flying `rest`
## metres more this step.
func _fork(p: Dictionary, rest: float) -> void:
	forked_count += 1
	var at: Vector3 = p["pos"]
	var gen: int = p["gen"] + 1
	_flash(at)
	_drop(p, FORKED)
	if not _forked_gens.has(gen):
		_forked_gens[gen] = true
		forked.emit(gen)
	var pair := def.fork_pair(p["dir"], aim)
	for k in 2:
		var child := _add(gen, p["index"] * 2 + k, at, pair[k], p["flown"])
		_advance(child, rest)


## Pellet `p` met what the ray `hit` found: the level stops it; a body stops it too, and a
## judging volley hands it to the judge.
func _stop(p: Dictionary, hit: Dictionary) -> void:
	var collider = hit["collider"]
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"] if not (hit["normal"] as Vector3).is_zero_approx() else -(p["dir"] as Vector3)
	var body := _is_body(collider)
	var counted := false
	if body:
		struck += 1
		if judge.is_valid():
			counted = judge.call(collider, p["gen"], at, p["dir"]) == true
			if counted:
				landed += 1
				landed_by_gen[p["gen"]] += 1
	else:
		stopped += 1
	p["flown"] += (at - (p["pos"] as Vector3)).length()
	p["pos"] = at
	CannonFx.spawn_impact(get_parent(), at, normal, counted, def)
	_drop(p, BODY if body else WALL)


## Anything but the level: a dummy, another player's hit volume, a player's own body.
func _is_body(collider: Object) -> bool:
	if not is_instance_valid(collider):
		return false
	var layer = collider.get("collision_layer")
	return layer is int and (layer & WORLD_LAYER) == 0


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask)
	# A muzzle inside a wall or an opponent still meets it, as the host's own shot ray does.
	query.hit_from_inside = true
	if exclusions.is_valid():
		query.exclude = exclusions.call()
	return get_world_3d().direct_space_state.intersect_ray(query)


func _add(gen: int, index: int, pos: Vector3, dir: Vector3, flown: float) -> Dictionary:
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh
	head.material_override = _head_glow
	var trail := MeshInstance3D.new()
	trail.mesh = _trail_mesh
	trail.material_override = _trail_glow
	add_child(head)
	add_child(trail)
	var p := {"gen": gen, "index": index, "pos": pos, "dir": dir, "flown": flown, "from": flown, "live": true, "head": head, "trail": trail}
	_pellets.append(p)
	spawned[gen] += 1
	directions["%d:%d" % [gen, index]] = dir
	_place(p)
	return p


## The head at the pellet, its trail behind it: as long as the weapon's trail, never longer
## than this pellet has flown.
func _place(p: Dictionary) -> void:
	var head: MeshInstance3D = p["head"]
	var trail: MeshInstance3D = p["trail"]
	var dir: Vector3 = p["dir"]
	head.global_position = p["pos"]
	var length := minf(def.pellet_trail_m, p["flown"] - p["from"])
	trail.visible = length > REACH_EPS
	if not trail.visible:
		return
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < NEAR_PARALLEL else Vector3.RIGHT
	trail.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0, 1.0, length)), p["pos"] - dir * length * 0.5)


func _flash(at: Vector3) -> void:
	var node := MeshInstance3D.new()
	node.mesh = _flash_mesh
	node.material_override = Palette.glow(def.skin_beam(), FLASH_ENERGY)
	add_child(node)
	node.global_position = at
	_flashes.append({"node": node, "left": def.fork_flash_s})


func _drop(p: Dictionary, why: String) -> void:
	ends.append([p["gen"], p["index"], p["pos"], p["flown"], why])
	p["live"] = false
	_pellets.erase(p)
	(p["head"] as Node).queue_free()
	(p["trail"] as Node).queue_free()


func _finish_if_done() -> void:
	if _done or not _pellets.is_empty() or not _flashes.is_empty():
		return
	_done = true
	finished.emit(landed)
	queue_free()
