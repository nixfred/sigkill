class_name Decoy
extends Node3D
## A decoy (I2): the ICEbreaker an intruder sacrifices to escape. Thrown along the aim (or dropped, aimed
## at the floor near the feet), it flies folded small, settles where it lands and stands up there as an
## effigy of the intruder's signal (scripts/ice/breaker_art.gd), calling for the tuning's decoy_s:
## while it calls, the hunter and the daemons within its pull go after it instead of any intruder
## (scripts/fight/daemon_director.gd: a decoy is prey of its own, id -1 minus its slot), and a white ICE
## node with it inside its trigger range spends its field on it, reaching no one. What strikes it (the
## hunter's lance, a daemon's slash, bolt or dive, a node's field) flashes it and lands nothing on
## anyone. When its call runs out it bursts into its own parts over a derezz in the breakers' colour.
## Nothing can shoot it: it has no body, only its call.
##
## Alone and hosting it flies and counts down here (deciding); on a joiner it is the host's word: placed
## where the host's is, its call's time from the host's. Fiction only.

const BreakerArt = preload("res://scripts/ice/breaker_art.gd")
const Palette = preload("res://scripts/palette.gd")
const Derezz = preload("res://scripts/derezz_tuning.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DEREZZ_PATH := "res://resources/derezz.tres"

## What it lands on: the level.
const LEVEL_MASK := 1
## The art's place over its origin: standing, the ground at its feet (a daemon's art space has its
## ground 0.9 under its centre); folded in flight, the folded shard's middle at its origin.
const ART_LIFT := 0.9
const FOLDED_LIFT := 0.65
## How fast it stands up once it lands, and folds as it is thrown, a second.
const UNFOLD_RATE := 4.0
## Its middle over its feet: where what hunts it aims.
const MIDDLE_M := 0.9
## It never flies lower than this under where it was thrown from, whatever the level (a throw out of
## the arena).
const FALL_LAST_M := 30.0

## Its slot in the director (0 to DECOYS_LAST - 1), the intruder who threw it, its seed, the tuning.
var slot := 0
var thrower := 0
var spawn_seed := 0
var tuning: BreakerTuning
## True alone and hosting: it flies and counts down here. False on a joiner: the host's word places it.
var deciding := true
var velocity := Vector3.ZERO
var landed := false
## Seconds of its call left once it has landed (decoy_s when it lands).
var left := 0.0
## How far it is folded now (1 in flight, 0 standing), for its art.
var folded := 1.0
## What struck it since it was thrown, for the checks.
var struck := 0
var art: DaemonArt

var _holder: Node3D
var _tag: Label3D
var _flight := 0.0
var _floor := -INF


func _ready() -> void:
	_holder = Node3D.new()
	_holder.name = "Look"
	add_child(_holder)
	art = BreakerArt.new()
	art.form = "decoy"
	art.setup(self, spawn_seed)
	_holder.add_child(art)
	_tag = Label3D.new()
	_tag.name = "Tag"
	_tag.text = "decoy"
	_tag.font = Palette.mono_font()
	_tag.font_size = 48
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.modulate = Palette.BREAKER_TEXT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.position = Vector3.UP * (ART_LIFT + art.tag_y())
	add_child(_tag)
	_show()


## Thrown from `from` along `way` (world space): the tuning's speed along it plus its lift.
func launch(from: Vector3, way: Vector3) -> void:
	global_position = from
	_floor = from.y - FALL_LAST_M
	velocity = way.normalized() * tuning.decoy_speed + Vector3.UP * tuning.decoy_lift
	landed = false
	folded = 1.0
	_flight = 0.0


## True while it calls: landed, with call left.
func calling() -> bool:
	return landed and left > 0.0


## True until its call is spent (in flight or calling).
func live() -> bool:
	return not landed or left > 0.0


## Where what hunts it aims: its middle (world space).
func point() -> Vector3:
	return global_position + Vector3.UP * (MIDDLE_M if landed else 0.0)


## Something of ICE's or a daemon's struck it from `from` (world space): a flash and a spray, nothing
## landed on anyone.
func strike(from: Vector3) -> void:
	struck += 1
	if art != null and is_instance_valid(art):
		art.react(point(), (point() - from).normalized() if from.is_finite() else Vector3.ZERO)


## The host's word, on a joiner: where it is (world space), whether it has landed, its call left.
func take_word(at: Vector3, has_landed: bool, call_left: float) -> void:
	global_position = at
	landed = has_landed
	left = call_left


func _physics_process(delta: float) -> void:
	if deciding:
		if not landed:
			_fly(delta)
		else:
			left = maxf(left - delta, 0.0)
	elif landed:
		left = maxf(left - delta, 0.0)  # between the host's words
	folded = move_toward(folded, 0.0 if landed else 1.0, UNFOLD_RATE * delta)
	_show()


## One step of its flight: gravity, then the level in the way, where it lands. A wall it meets drops
## it to the floor under where it struck; so does a flight past decoy_flight_s.
func _fly(delta: float) -> void:
	_flight += delta
	velocity += Vector3.DOWN * tuning.decoy_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, LEVEL_MASK))
	if not hit.is_empty():
		var normal: Vector3 = hit["normal"]
		var at: Vector3 = hit["position"]
		if normal.y > 0.6:
			_land(at)
		else:
			_land(_ground_under(space, at + normal * 0.3))
		return
	global_position = to
	if _flight >= tuning.decoy_flight_s or to.y < _floor:
		_land(_ground_under(space, to))


func _ground_under(space: PhysicsDirectSpaceState3D, at: Vector3) -> Vector3:
	var down := space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * FALL_LAST_M, LEVEL_MASK))
	return down["position"] if not down.is_empty() else at


func _land(at: Vector3) -> void:
	global_position = at
	velocity = Vector3.ZERO
	landed = true
	left = tuning.decoy_s


func _show() -> void:
	if _holder == null:
		return
	_holder.position.y = lerpf(ART_LIFT, FOLDED_LIFT, folded)
	_tag.visible = folded < 0.05
	art.folded = folded
	art.call_left = clampf(left / maxf(tuning.decoy_s, 0.001), 0.0, 1.0) if landed else 1.0


## Its call is over: it bursts into its own parts over a derezz in the breakers' colour, and goes.
func expire() -> void:
	var root := get_tree().current_scene if is_inside_tree() and get_tree().current_scene != null else get_parent()
	if root != null and art != null and is_instance_valid(art) and art.is_visible_in_tree():
		var d := load(DEREZZ_PATH) as Derezz
		var fx := DerezzFx.new()
		root.add_child(fx)
		fx.start(global_position, 0.45, 1.6, Vector3.ZERO, d if d != null and d.problems().is_empty() else Derezz.new(), spawn_seed, Palette.BREAKER)
		art.shatter(fx)
	queue_free()
