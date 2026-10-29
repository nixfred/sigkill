class_name IceBarrier
extends IcePiece
## White ICE's wall (I1): it seals a doorway or a corridor of the arena until enough weapon damage
## breaks it. Its body is two: a skin on the targets' layer a little larger than the opening (every
## shot, pellet, dart and slug meets it first and lands its damage on the wall) round a core on the
## level's layer (players, daemons, hunters, their sight and the zombies' bolts stop at it as at any
## wall; the rail stops at it after its hit). It cracks as it takes damage (scripts/ice/barrier_art.gd)
## and bursts into glacier shards when it breaks, both gone at once, so the way is open.
##
## I2's brute ICEbreaker cracks walls faster: a hit whose source is "breaker:brute" is the hook (the
## director's take(), BRUTE_SCALE), not used yet.

const BarrierArt = preload("res://scripts/ice/barrier_art.gd")

## The opening it fills (width, height) and how thick it is, metres; set before it enters the tree.
var span := Vector2(2.7, 3.5)
var depth := 0.36
var spawn_seed := 0

var _core: StaticBody3D


func _ready() -> void:
	collision_layer = TARGET_LAYER
	collision_mask = 0
	_health = max_health
	tag_text = "white ICE"
	_make_art(BarrierArt, spawn_seed, _prepare)
	var skin := BoxShape3D.new()
	skin.size = Vector3(span.x + 0.04, span.y + 0.04, depth + 0.1)
	_shape(skin, Vector3(0.0, span.y * 0.5, 0.0))
	_core = StaticBody3D.new()
	_core.name = "Core"
	_core.collision_layer = LEVEL_LAYER
	_core.collision_mask = 0
	var core_box := BoxShape3D.new()
	core_box.size = Vector3(span.x, span.y, depth)
	var core_shape := CollisionShape3D.new()
	core_shape.shape = core_box
	core_shape.position = Vector3(0.0, span.y * 0.5, 0.0)
	_core.add_child(core_shape)
	add_child(_core)


func _prepare(a) -> void:  # untyped: the wall's own art script
	a.span = span
	a.depth = depth


## The wall's cracks: its art follows its damage.
func _show_health() -> void:
	(art as BarrierArt).set_damage(1.0 - _health / maxf(max_health, 0.001))


func _off_level() -> void:
	if _core != null:
		_core.collision_layer = 0
		for child in _core.get_children():
			(child as CollisionShape3D).set_deferred("disabled", true)


## True while it seals its opening: not broken.
func sealed() -> bool:
	return not broken


## The nearest point of its skin to `at` (world space): a blast against a wall meets it there.
func blast_point(at: Vector3) -> Vector3:
	var local := to_local(at)
	var half := Vector3(span.x * 0.5 + 0.02, span.y * 0.5 + 0.02, depth * 0.5 + 0.05)
	var middle := Vector3(0.0, span.y * 0.5, 0.0)
	return to_global(middle + (local - middle).clamp(-half, half))


func _derezz_radius() -> float:
	return span.x * 0.5


func _derezz_height() -> float:
	return span.y
