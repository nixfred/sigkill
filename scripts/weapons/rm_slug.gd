extends Node3D
## One shot of the rm -rf cannon (C26, PRD 5.2 "slow, devastating cannon with friendly-fire
## risk"): one heavy glowing slug with a thick trail, flying straight at the weapon's
## slug_speed, slower than every other projectile so it can be seen and dodged. It detonates on
## the first wall, floor or body it meets, or at the weapon's fire_range. The blast is a bright
## ring growing out to the blast's radius (the larger root one while C22's root is on) and
## fading over blast_ring_s, so its reach reads at a glance. Every number is the weapon's own
## (resources/rm_rf_cannon.tres, scripts/weapons/weapon_def.gd's blast group).
##
## Cheap on the frame: one node per shot, no physics bodies: the slug is moved by this node, one
## ray a physics frame. The ring lives beside it and frees itself; the node frees itself at the
## blast.
##
## Who decides: a slug that judges (solo, or the host's in a match) detonates where its ray
## stops and hands the blast to its judge (a Callable the shooter's side gives it), which applies
## the damage. A slug on a joiner's screen only draws: it flies the same straight line, passes
## through bodies (they stand differently on each screen), holds at a wall or at its range, and
## goes off only on the host's word (apply_blast()), at the place the host says; if no word comes
## within blast_wait_s of it holding, it goes away without a blast.
##
## Cosmetic fiction: "rm -rf" is a name. Nothing is removed, run or touched.

## The slug went off at `at` (world space).
signal blasted(at: Vector3)
## The shot is done. `landed`: what its judge hurt (0 on a slug that only draws).
signal finished(landed: int)

const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")
const Palette = preload("res://scripts/palette.gd")
## Every slug node is in this group, every blast ring in the next: the tests count them.
const GROUP := &"rm_slug"
const RING_GROUP := &"rm_ring"
## The node under a scene's root that holds every volley there (the fork() volleys' own).
const FIELD := "ForkVolleys"
## What stops a slug as the level (walls, floor, blocks): everything else it meets is a body.
const WORLD_LAYER := 1
## A hit whose normal points up this much is the floor, not a wall.
const FLOOR_NORMAL_Y := 0.7
## The range's end counts as reached within this many metres: float sums of steps.
const REACH_EPS := 0.0001
## A slug that stops on something goes off this far back along its line from the face it met,
## so a blast on a wall is on this side of it and the wall shields what is behind it.
const STANDOFF_M := 0.05
const NEAR_PARALLEL := 0.98
## The slug is not drawn for its first metres from the eyes it leaves (A1): that close it would fill
## its shooter's view, and the muzzle flash at the barrel covers the moment. Drawing only.
const EYE_CLEAR_M := 0.75
## Drawn from the shooter's muzzle (A4, draw_from()): the slug is drawn this far off its true path
## at first, from the barrel's tip, closing on it over this many metres. Drawing only.
const CONVERGE_M := 6.0
## How bright the slug, its trail and the ring glow.
const HEAD_ENERGY := 5.0
const TRAIL_ENERGY := 3.0
const RING_ENERGY := 6.0
## The trail is this thick for each metre of the slug's radius: a heavy one.
const TRAIL_THICKNESS := 1.2
## The ring starts at this share of the blast's radius, and is this share of it thick.
const RING_START := 0.15
const RING_BAND := 0.12
## Why the slug went off: the level it met (WALL, FLOOR), a body, its range, or the host's word.
const WALL := "wall"
const FLOOR := "floor"
const BODY := "body"
const RANGE := "range"
const WORD := "word"

var def: WeaponDefScript
## The shot's line (world space, unit length).
var aim := Vector3.FORWARD
## True while C22's root is on for the shooter: the blast reaches root_blast_scale farther.
var root := false
## True: detonates where it stops and hands the blast to judge. False: draws only.
var authoritative := true
## What the slug's ray meets: the level and the bodies.
var hit_mask := 5
## exclusions() -> Array[RID], asked every physics frame: what the slug passes through (its
## shooter's own body, and in a match every corpse).
var exclusions := Callable()
## judge(at) -> int for the blast at `at`: what it hurt.
var judge := Callable()

## Where and why it went off ("" while it flies), the metres it flew, the blast's radius, and
## what its judge hurt: the tests read them.
var why := ""
var at := Vector3.INF
var flown := 0.0
var radius := 0.0
var landed := 0
## Each physics frame's metres moved: the tests measure the slug's speed.
var steps: Array[float] = []

var _pos := Vector3.ZERO
var _head: MeshInstance3D
var _trail: MeshInstance3D
var _origin := Vector3.ZERO
var _drawn := Vector3.ZERO
var _drawn_on := false
var _holding := false
var _wait_left := 0.0
var _done := false


## A shot of `weapon` under `root_node` (the arena) from `origin` along `shot_aim` (world space),
## `root_on` whether its shooter is root. `deciding`: detonates and judges.
static func spawn(root_node: Node, weapon: WeaponDefScript, origin: Vector3, shot_aim: Vector3, root_on: bool, deciding: bool, mask: int, never: Callable = Callable(), judged: Callable = Callable()) -> Node3D:
	var slug = load("res://scripts/weapons/rm_slug.gd").new()
	slug.name = "RmSlug"
	slug.def = weapon
	slug.aim = shot_aim.normalized()
	slug.root = root_on
	slug.authoritative = deciding
	slug.hit_mask = mask if deciding else WORLD_LAYER
	slug.exclusions = never
	slug.judge = judged
	field_of(root_node).add_child(slug)
	slug.fire(origin)
	return slug


## The node under `root_node` that holds its volleys, made on first use.
static func field_of(root_node: Node) -> Node3D:
	var field := root_node.get_node_or_null(FIELD) as Node3D
	if field == null:
		field = Node3D.new()
		field.name = FIELD
		root_node.add_child(field)
	return field


func _ready() -> void:
	add_to_group(GROUP)


## The slug leaves `origin` (world space).
func fire(origin: Vector3) -> void:
	_pos = origin
	_origin = origin
	radius = def.blast_radius_for(root)
	var head_mesh := SphereMesh.new()
	head_mesh.radius = def.slug_radius_m
	head_mesh.height = def.slug_radius_m * 2.0
	_head = MeshInstance3D.new()
	_head.mesh = head_mesh
	_head.material_override = Palette.glow(def.skin_body(), HEAD_ENERGY)
	add_child(_head)
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(def.slug_radius_m * TRAIL_THICKNESS, def.slug_radius_m * TRAIL_THICKNESS, 1.0)
	_trail = MeshInstance3D.new()
	_trail.mesh = trail_mesh
	_trail.material_override = Palette.glow(def.skin_beam(), TRAIL_ENERGY)
	add_child(_trail)
	_place()
	# Embers shed behind it in flight (A4), from the arena's particle pool when it has one free.
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.follow(_head, def.skin_beam(), true)


## Draws the slug coming out of the shooter's barrel at `point` (A4): seen from the start, off its
## true path by the barrel's offset at first, closing on it over CONVERGE_M. The slug itself still
## flies from the eyes; this moves only what is drawn.
func draw_from(point: Vector3) -> void:
	_drawn = point - _origin
	_drawn_on = true
	_place()


## True while the slug is still in the air (or, on a joiner's screen, holding for the word).
func flying() -> bool:
	return not _done


## Where the slug is now (world space).
func position_now() -> Vector3:
	return _pos


func _physics_process(delta: float) -> void:
	if _done:
		return
	if _holding:
		_wait_left -= delta
		if _wait_left <= 0.0:
			_end(0)  # the host's word never came
		return
	var go: float = clampf(minf(def.slug_speed * delta, def.fire_range - flown), 0.0, def.slug_speed * delta)
	var to := _pos + aim * go
	if go > 0.0:
		var hit := _ray(_pos, to)
		if not hit.is_empty():
			var stop: Vector3 = hit["position"]
			var kind := _kind(hit)
			steps.append(_pos.distance_to(stop))
			flown += _pos.distance_to(stop)
			_pos = stop - aim * minf(STANDOFF_M, _pos.distance_to(stop))
			_stop(kind)
			return
	steps.append(go)
	_pos = to
	flown += go
	if flown >= def.fire_range - REACH_EPS:
		_stop(RANGE)
	else:
		_place()


## The host's word of the blast at `place` (world space), on a slug that only draws: it goes off
## there, wherever this screen has it.
func apply_blast(place: Vector3) -> void:
	if authoritative or _done or not place.is_finite():
		return
	_pos = place
	_detonate(WORD)


## The slug stopped (`kind`: WALL, FLOOR, BODY or RANGE): a judging slug goes off there; one
## that only draws holds for the host's word.
func _stop(kind: String) -> void:
	if authoritative:
		_detonate(kind)
		return
	why = kind
	_holding = true
	_wait_left = def.blast_wait_s
	_place()


func _detonate(kind: String) -> void:
	why = kind
	at = _pos
	_ring(at)
	if authoritative and judge.is_valid():
		var hurt = judge.call(at)
		landed = hurt if hurt is int else 0
	blasted.emit(at)
	_end(landed)


func _end(hurt: int) -> void:
	if _done:
		return
	_done = true
	finished.emit(hurt)
	queue_free()


func _kind(hit: Dictionary) -> String:
	var collider = hit["collider"]
	var layer = collider.get("collision_layer") if is_instance_valid(collider) else null
	if layer is int and (layer & WORLD_LAYER) == 0:
		return BODY
	var normal: Vector3 = hit["normal"]
	return FLOOR if normal.y >= FLOOR_NORMAL_Y else WALL


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, hit_mask)
	# A muzzle inside a wall or an opponent still meets it, as the host's own shot ray does.
	query.hit_from_inside = true
	if exclusions.is_valid():
		query.exclude = exclusions.call()
	return get_world_3d().direct_space_state.intersect_ray(query)


## The slug at its place, its trail behind it: as long as the weapon's trail, never longer than
## it has flown past the eyes' clearance.
func _place() -> void:
	var shown := _pos + _drawn * maxf(0.0, 1.0 - flown / CONVERGE_M)
	_head.global_position = shown
	_head.visible = flown >= EYE_CLEAR_M or _drawn_on
	var length := minf(def.slug_trail_m, flown - (0.0 if _drawn_on else EYE_CLEAR_M))
	_trail.visible = length > REACH_EPS
	if not _trail.visible:
		return
	var up := Vector3.UP if absf(aim.dot(Vector3.UP)) < NEAR_PARALLEL else Vector3.RIGHT
	_trail.global_transform = Transform3D(Basis.looking_at(aim, up) * Basis.from_scale(Vector3(1.0, 1.0, length)), shown - aim * length * 0.5)


## The blast's ring at `place`, laid flat, growing from a small share of the blast's radius out to
## all of it and fading over blast_ring_s: where the blast reached, at a glance. Not a child of
## the slug, so it outlives it by blast_ring_s at most.
func _ring(place: Vector3) -> void:
	# Debris thrown out of the blast (A4), from the arena's particle pool.
	var fx := ParticleFx.of(self)
	if fx != null:
		fx.blast(place, def.skin_body(), radius)
	var torus := TorusMesh.new()
	torus.inner_radius = radius * (1.0 - RING_BAND)
	torus.outer_radius = radius
	torus.rings = 48
	torus.ring_segments = 6
	var mat := Palette.unlit_glow(def.skin_body(), RING_ENERGY)
	var ring := MeshInstance3D.new()
	ring.name = "RmRing"
	ring.mesh = torus
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.add_to_group(RING_GROUP)
	get_parent().add_child(ring)
	ring.global_position = place
	ring.scale = Vector3.ONE * RING_START
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3.ONE, def.blast_ring_s)
	tween.tween_property(mat, "albedo_color:a", 0.0, def.blast_ring_s)
	tween.chain().tween_callback(ring.queue_free)
