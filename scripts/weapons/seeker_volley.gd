extends Node3D
## One shot of grep (C25, PRD 5.2 "seeker smart gun that locks onto a marked target"): one dart
## per mark the shot carried, or one straight along the aim when it carried none. Each dart is
## a fast, short-lived projectile flying at the weapon's dart_speed; a dart with a mark turns
## toward where its mark is now, never more than dart_turn_degrees a second, so a mark that
## breaks hard or ducks behind cover can make it miss. A dart stops at the first wall or body
## it meets (another body in the way takes it as well as its mark would) and vanishes at the
## weapon's fire_range. A mark that derezzes or goes away leaves its dart flying straight on.
## Every number is the weapon's own (resources/grep_seeker.tres, scripts/weapons/weapon_def.gd's
## seek group).
##
## Cheap on the frame: one node per shot, no physics bodies. Each live dart is a small glowing
## head with a thin trail behind it, moved by this node one ray a physics frame. The node frees
## itself once its last dart is gone.
##
## Same darts on every screen: the first directions come from the aim, the seed and the number
## of darts alone (WeaponDef.seek_spread), and each turn from the dart's own direction and
## where its mark is on that screen; the marks are the ones the shooter's side handed in (in a
## match, the ones the host believed). Who decides: a volley that judges (solo, or the host's
## in a match) hands every dart that meets a body to its judge (a Callable the shooter's side
## gives it), which applies the damage; a volley on a joiner's screen only draws, and its judge
## is at most this machine's own dummies, never a player.
##
## Cosmetic fiction: nothing is searched, run or touched.

## The shot is done: no dart left. `landed`: darts its judge counted.
signal finished(landed: int)

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Palette = preload("res://scripts/palette.gd")
const CannonFx = preload("res://scripts/cannon_fx.gd")
## Every seeker volley node is in this group: the tests count them.
const GROUP := &"seeker_volley"
## The node under a scene's root that holds every volley there (the fork() volleys' own).
const FIELD := "ForkVolleys"
## What stops a dart as the level (walls, floor, blocks): everything else it meets is a body.
const WORLD_LAYER := 1
## The range's end counts as reached within this many metres: float sums of steps.
const REACH_EPS := 0.0001
## A mark this close is where the dart is: no turn to make.
const CLOSE_EPS := 0.0001
## A trail's direction this close to straight up or down is turned about another axis.
const NEAR_PARALLEL := 0.98
## How bright a dart's head and trail glow.
const HEAD_ENERGY := 4.0
const TRAIL_ENERGY := 2.5
## A trail is this thick for each metre of the head's radius.
const TRAIL_THICKNESS := 0.5
## Why a dart's flight ended.
const WALL := "wall"
const BODY := "body"
const RANGE := "range"

var def: WeaponDefScript
var seed := 0
## The shot's aim (world space, unit length): the darts are fanned from it.
var aim := Vector3.FORWARD
## True: hands every dart that meets a body to judge. False: draws only.
var authoritative := true
## What a dart's ray meets: the level and the bodies.
var hit_mask := 5
## exclusions() -> Array[RID], asked every physics frame: what darts pass through (the
## shooter's own body, and in a match every corpse).
var exclusions := Callable()
## judge(collider, gen, at, dir) -> bool for a dart (generation 0) that met `collider` at `at`
## flying along `dir`: true when it counted (damage dealt).
var judge := Callable()
## One per dart: mark() -> Vector3, where its mark is now (world space), or a non-finite
## vector once it is gone. Empty: one dart, straight, no mark.
var marks: Array = []

## Darts fired, those stopped by the level, by a body, those the judge counted, and those that
## reached the range's end.
var spawned := 0
var stopped := 0
var struck := 0
var landed := 0
var expired := 0
## Where every dart's flight ended and why, [index, place, metres flown, why], why one of WALL,
## BODY, RANGE: the tests read it.
var ends: Array = []
## Every dart's first direction, index -> Vector3: the tests compare screens.
var directions := {}
## The most any dart turned in one physics frame, in degrees, and each dart's nearest pass to
## its mark in metres (INF for a dart with none): the tests read them.
var turn_most := 0.0
var nearest: Array[float] = []

var _darts: Array = []  # {index, pos, dir, flown, mark, live, head, trail}
var _head_mesh: SphereMesh
var _trail_mesh: BoxMesh
var _head_glow: StandardMaterial3D
var _trail_glow: StandardMaterial3D
var _done := false


## A shot of `weapon` under `root` (the arena) from `origin` along `shot_aim` (world space) with
## `shot_seed`, one dart for each of `mark_points` (Callables as `marks` above) or one straight.
## `deciding`: judges what it hits.
static func spawn(root: Node, weapon: WeaponDefScript, origin: Vector3, shot_aim: Vector3, shot_seed: int, mark_points: Array, deciding: bool, mask: int, never: Callable = Callable(), judged: Callable = Callable()) -> Node3D:
	var volley = load("res://scripts/weapons/seeker_volley.gd").new()
	volley.name = "SeekerVolley"
	volley.def = weapon
	volley.seed = shot_seed
	volley.aim = shot_aim.normalized()
	volley.marks = mark_points.duplicate()
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


## The darts leave `origin` (world space): one per mark, or one with none.
func fire(origin: Vector3) -> void:
	_head_mesh = SphereMesh.new()
	_head_mesh.radius = def.dart_radius_m
	_head_mesh.height = def.dart_radius_m * 2.0
	_trail_mesh = BoxMesh.new()
	_trail_mesh.size = Vector3(def.dart_radius_m * TRAIL_THICKNESS, def.dart_radius_m * TRAIL_THICKNESS, 1.0)
	_head_glow = Palette.glow(def.skin_body(), HEAD_ENERGY)
	_trail_glow = Palette.glow(def.skin_beam(), TRAIL_ENERGY)
	var count := maxi(marks.size(), 1)
	var fan := def.seek_spread(aim, seed, count)
	for i in count:
		_add(i, origin, fan[i], marks[i] if i < marks.size() else Callable())


## Darts flying now.
func live_count() -> int:
	return _darts.size()


## Every live dart's place, ordered by index: the tests compare two volleys.
func positions() -> PackedVector3Array:
	var out := PackedVector3Array()
	for d in _darts:
		out.append(d["pos"])
	return out


## Every live dart's [index, direction now, metres flown].
func flights() -> Array:
	var out := []
	for d in _darts:
		out.append([d["index"], d["dir"], d["flown"]])
	return out


func _physics_process(delta: float) -> void:
	for d in _darts.duplicate():
		if d["live"]:
			_steer(d, delta)
			_advance(d, def.dart_speed * delta)
	_finish_if_done()


## Turns dart `d` toward its mark, at most the weapon's turn rate for `delta` seconds.
func _steer(d: Dictionary, delta: float) -> void:
	var mark: Callable = d["mark"]
	if not mark.is_valid():
		return
	var at: Vector3 = mark.call()
	if not at.is_finite():
		d["mark"] = Callable()  # the mark is gone: straight on from here
		return
	var pos: Vector3 = d["pos"]
	nearest[d["index"]] = minf(nearest[d["index"]], pos.distance_to(at))
	var to := at - pos
	if to.length() < CLOSE_EPS:
		return
	var dir: Vector3 = d["dir"]
	var want := to.normalized()
	var angle := dir.angle_to(want)
	var most := deg_to_rad(def.dart_turn_degrees) * delta
	var turned := angle
	if angle <= most:
		d["dir"] = want
	else:
		var axis := dir.cross(want)
		if axis.length() < CLOSE_EPS:
			axis = WeaponDefScript.fork_axis(dir)  # straight away from it: turn about any square axis
		d["dir"] = dir.rotated(axis.normalized(), most).normalized()
		turned = most
	turn_most = maxf(turn_most, rad_to_deg(turned))


## Moves dart `d` on by `dist` metres: a stop at the first wall or body on the way, the end at
## the range.
func _advance(d: Dictionary, dist: float) -> void:
	var go: float = clampf(minf(dist, def.fire_range - d["flown"]), 0.0, dist)
	var to: Vector3 = d["pos"] + d["dir"] * go
	if go > 0.0:
		var hit := _ray(d["pos"], to)
		if not hit.is_empty():
			_stop(d, hit)
			return
	d["pos"] = to
	d["flown"] += go
	if d["flown"] >= def.fire_range - REACH_EPS:
		expired += 1
		_drop(d, RANGE)
	else:
		_place(d)


## Dart `d` met what the ray `hit` found: the level stops it; a body stops it too, and a
## judging volley hands it to the judge.
func _stop(d: Dictionary, hit: Dictionary) -> void:
	var collider = hit["collider"]
	var at: Vector3 = hit["position"]
	var normal: Vector3 = hit["normal"] if not (hit["normal"] as Vector3).is_zero_approx() else -(d["dir"] as Vector3)
	var body := _is_body(collider)
	var counted := false
	if body:
		struck += 1
		if judge.is_valid():
			counted = judge.call(collider, 0, at, d["dir"]) == true
			if counted:
				landed += 1
	else:
		stopped += 1
	d["flown"] += (at - (d["pos"] as Vector3)).length()
	d["pos"] = at
	CannonFx.spawn_impact(get_parent(), at, normal, counted, def)
	_drop(d, BODY if body else WALL)


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


func _add(index: int, pos: Vector3, dir: Vector3, mark: Callable) -> void:
	var head := MeshInstance3D.new()
	head.mesh = _head_mesh
	head.material_override = _head_glow
	var trail := MeshInstance3D.new()
	trail.mesh = _trail_mesh
	trail.material_override = _trail_glow
	add_child(head)
	add_child(trail)
	var d := {"index": index, "pos": pos, "dir": dir, "flown": 0.0, "mark": mark, "live": true, "head": head, "trail": trail}
	_darts.append(d)
	spawned += 1
	nearest.append(INF)
	directions[index] = dir
	_place(d)


## The head at the dart, its trail behind it: as long as the weapon's trail, never longer than
## this dart has flown.
func _place(d: Dictionary) -> void:
	var head: MeshInstance3D = d["head"]
	var trail: MeshInstance3D = d["trail"]
	var dir: Vector3 = d["dir"]
	head.global_position = d["pos"]
	var length := minf(def.dart_trail_m, d["flown"])
	trail.visible = length > REACH_EPS
	if not trail.visible:
		return
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < NEAR_PARALLEL else Vector3.RIGHT
	trail.global_transform = Transform3D(Basis.looking_at(dir, up) * Basis.from_scale(Vector3(1.0, 1.0, length)), d["pos"] - dir * length * 0.5)


func _drop(d: Dictionary, why: String) -> void:
	ends.append([d["index"], d["pos"], d["flown"], why])
	d["live"] = false
	_darts.erase(d)
	(d["head"] as Node).queue_free()
	(d["trail"] as Node).queue_free()


func _finish_if_done() -> void:
	if _done or not _darts.is_empty():
		return
	_done = true
	finished.emit(landed)
	queue_free()
