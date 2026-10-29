class_name IcePiece
extends StaticBody3D
## One piece of ICE (I1): white ICE's walls and nodes, hunter ICE. The system's own defences, a game
## object like a daemon and never anything real. A piece has health and a body shots can meet (on the
## targets' layer, as a daemon's), and art built from a seed (scripts/ice/*_art.gd) that flashes and
## sprays at a hit and bursts into its own parts in its colour when the piece breaks, over a derezz in
## that colour.
##
## Every hit goes through its director (scripts/ice/ice_director.gd, take()): no one hit takes more
## than the tuning's hit_cap off any piece (the rail's 1000 included), a hunter resists the weapon it
## has adapted to, and the weapon's damage is noted for the round's adaptation. A hit carries its
## source (the weapon's id, the damage type I2's ICEbreakers will add theirs to); an unknown source
## lands as plain damage. Alone and hosting the director judges; on a joiner a piece is the host's
## (it follows the host's word, take_word()) and a shot here lands nothing on it.
##
## A broken piece is gone for the round (a hunter comes back after its wait, a new one); the director
## builds every piece again, from new seeds, when a round starts.
##
## chmod 000 (C29): the hunter and the nodes freeze like a daemon (their `frost`, ICE's slower meter and
## shorter freeze): frozen, a hunter does nothing and a node's field is paused, a tell either was in
## called off, and the next hit thaws it and lands the freeze tuning's frozen_hit_scale times harder
## (after the hit cap, as exploit's bonus); ICE never shatters (the cap holds). Walls ignore the beam (no
## frost: "read-only file system"), and Black ICE is only ever slowed (scripts/ice/black_ice.gd).
##
## SIGHUP (C32): a hangup reaches a piece through take_hup(): the hunter is confused as a daemon is and
## forgets what it learned (scripts/ice/hunter_ice.gd), a node reloads and drops its field for a while
## (scripts/ice/ice_node.gd); a wall is not touched and Black ICE ignores it (it runs under nohup), both
## the false this base gives. Its look (scripts/fx/hup_look.gd) follows hup_phase() each frame.

const Palette = preload("res://scripts/palette.gd")
const Derezz = preload("res://scripts/derezz_tuning.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DEREZZ_PATH := "res://resources/derezz.tres"
## The physics layers: a piece's own body is on the targets' (shots meet it, nothing walks into it);
## a wall's core is on the level's (it blocks movement, sight and bolts as the level does).
const TARGET_LAYER := 4
const LEVEL_LAYER := 1
## The art's place over the body's origin (the floor): a daemon's art space has its ground 0.9 under.
const ART_LIFT := 0.9

## Emitted once, when the piece breaks.
signal broke(piece: Node3D)

## Its name in the director's layout ("gate", "wall", "jam", "hud", "hunter") and on its tag.
var piece_name := ""
var tag_text := "ICE"
var max_health := 100.0
## Its director, set before it enters the tree.
var director: Node = null
var art: IceArt
var build_seed := 0
## True once it has broken this round.
var broken := false
## The hits it took this life, for the checks.
var hits := 0
## Its freeze meter and freeze (C29): the hunter's and the nodes'; null for a wall (and Black ICE), which
## the beam does not freeze.
var frost: Frost = null
## /dev/null (C31): the last physics frame a hole holds it to.
var _held_until := -1
## /dev/null (C31): set round a hole's damage over time so it lands quietly: no flash, no recoil, no spray,
## nothing roused (the hole's own pull is its look); a kill still derezzes as any.
var quiet := false
var _frost_look: FrostLook
var _hup_look: HupLook

var _health := 100.0
var _holder: Node3D
var _shapes: Array[CollisionShape3D] = []


## Builds the piece's art from `seed` under a holder at the art's place, `prepare` setting the art
## up before it builds (a wall's span, a node's kind). Called by the type once, in _ready().
func _make_art(script: Script, seed: int, prepare: Callable = Callable()) -> void:
	build_seed = seed & DaemonArt.SEED_LAST
	_holder = Node3D.new()
	_holder.name = "Look"
	_holder.position = Vector3(0.0, ART_LIFT, 0.0)
	add_child(_holder)
	art = script.new()
	if prepare.is_valid():
		prepare.call(art)
	art.setup(self, build_seed)
	_holder.add_child(art)


## A collision shape on this body: `shape` at `at`.
func _shape(shape: Shape3D, at: Vector3) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = at
	add_child(node)
	_shapes.append(node)
	return node


func health() -> float:
	return _health


## True while it stands: not broken.
func is_alive() -> bool:
	return not broken


func is_hittable() -> bool:
	return not broken


## /dev/null (C31): a hole holds it for `seconds` more (renewed each step it is held): while held its brain
## does nothing of its own and the hole moves it.
func hold_in_hole(seconds: float) -> void:
	_held_until = maxi(_held_until, Engine.get_physics_frames() + ceili(seconds * Engine.physics_ticks_per_second))


## True while a hole holds it.
func held_by_hole() -> bool:
	return Engine.get_physics_frames() <= _held_until and is_alive()


## SIGHUP's hangup (C32) from player `by` (0 alone) with numbers `t`: true when it took it. A wall and
## Black ICE never do (this base); the hunter and the nodes have their own.
func take_hup(_t: SighupTuning, _by: int = 0) -> bool:
	return false


## Its confusion now for its look (C32): 0 none, 1 reloading, 2 wandering; and how far through it, 0 to 1.
func hup_phase() -> int:
	return 0


func hup_share() -> float:
	return 0.0


## How many times as hard a /dev/null hole drags it now (the hunter confused, C32).
func hole_pull_scale() -> float:
	return 1.0


## SIGHUP's look on it (C32), or null before it was ever hung up.
func hup_look() -> HupLook:
	return _hup_look


## Its look follows its confusion: made the first time it has one, then told each frame.
func _show_hup() -> void:
	var phase := hup_phase() if not broken else 0
	if _hup_look == null:
		if phase == 0 or art == null:
			return
		_hup_look = HupLook.of(art)
	_hup_look.show_phase(phase, hup_share())


## Called by a shot through its ray, a pellet, a dart or a blast, as a daemon's hit(). True when it
## landed: never once broken, never on a joiner (the host judges).
func hit(damage: float, point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO, source: String = "") -> bool:
	return _land(damage, point, direction, source, 0)


## Another player's hit, judged by the host: the same as hit(), the shooter's own exploit counting (I2).
func hit_by_other(damage: float, point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO, shooter: int = 0, source: String = "") -> bool:
	return _land(damage, point, direction, source, shooter)


## A hit from intruder `shooter` (0 this machine's own): through the director, an exploit breaker's
## bonus on a weak seam included (I2).
func _land(damage: float, point: Vector3, direction: Vector3, source: String, shooter: int) -> bool:
	if broken or director == null or not director.decides():
		return false
	var bonus: float = director.exploit_scale(shooter, self, point, source)
	if frost != null and frost.thaw():
		bonus *= frost.tuning.frozen_hit_scale  # frozen by chmod 000 (C29): thawed, and harder
		art.frozen = false
	var taken: float = director.take(self, damage, source, bonus)
	if taken <= 0.0:
		return false
	hits += 1
	_health -= taken
	if _health > 0.0:
		if quiet:
			_show_health()
			return true
		_hurt(point, direction)
		return true
	_health = 0.0
	_break(point, direction)
	return true


## chmod 000's beam on it for `seconds` (C29): its freeze meter builds; true when that froze it just now.
## Never once broken, never on a joiner (the host judges), never a wall (no frost).
func chill(seconds: float, _point: Vector3 = Vector3.INF, _direction: Vector3 = Vector3.ZERO, _source: String = "") -> bool:
	if frost == null or broken or director == null or not director.decides():
		return false
	var froze := frost.beam(seconds)
	if froze:
		art.frozen = true
		_on_frozen()
	_show_frost()
	return froze


## True while chmod 000 holds it frozen (C29).
func chmod_frozen() -> bool:
	return frost != null and frost.frozen() and not broken


## Its freeze meter on by `delta` (the director steps it): a thaw lets its art move again.
func tick_frost(delta: float) -> void:
	if frost != null and frost.tick(delta):
		art.frozen = false


## The host's word on its freeze meter (a joiner's copy, C29).
func follow_frost(bits: int) -> void:
	if frost == null or broken:
		return
	frost.take_bits(bits)
	art.frozen = frost.frozen()
	_show_frost()


## A freeze took it just now: the type's own (a node's tell is called off).
func _on_frozen() -> void:
	pass


func _show_frost() -> void:
	if _frost_look == null and frost != null and (frost.chill > 0.0 or frost.frozen()):
		_frost_look = FrostLook.of(art, frost)


## The frost on it now (C29), or null before the beam has met it.
func frost_look() -> FrostLook:
	return _frost_look


## A hit that did not break it: the art's flash and spray, and the type's own reaction.
func _hurt(point: Vector3, direction: Vector3) -> void:
	art.react(point, direction)
	_show_health()


## The type shows its health on its art (a wall's cracks).
func _show_health() -> void:
	pass


## It breaks: its collision off, its art bursting into its parts over a derezz in its colour.
func _break(point: Vector3, direction: Vector3) -> void:
	broken = true
	if frost != null:
		frost.clear()
	art.frozen = false
	for shape in _shapes:
		shape.set_deferred("disabled", true)
	_off_level()
	var shot := Vector3(direction.x, 0.0, direction.z)
	if shot.is_zero_approx() and point.is_finite():
		shot = global_position - point
		shot.y = 0.0
	shot = shot.normalized()
	var root := _fx_root()
	var d := load(DEREZZ_PATH) as Derezz
	var fx := DerezzFx.new()
	root.add_child(fx)
	fx.start(global_position, _derezz_radius(), _derezz_height(), shot, d if d != null and d.problems().is_empty() else Derezz.new(), build_seed, art.core_color)
	art.shatter(fx, shot)
	_holder.visible = false
	broke.emit(self)


## Where a ping's ring meets it and grep's dart aims (C29): its middle.
func aim_point() -> Vector3:
	return blast_point(global_position)


## Where a blast at `at` (world space) meets it: its middle; a wall, the nearest point of its face.
func blast_point(_at: Vector3) -> Vector3:
	return global_position + Vector3.UP * (_derezz_height() * 0.5)


## A wall's core leaves the level when it breaks.
func _off_level() -> void:
	pass


func _derezz_radius() -> float:
	return 0.6


func _derezz_height() -> float:
	return 1.8


## The host's word for its health and whether it has broken (a joiner's copy).
func take_health(health_now: float, is_broken: bool) -> void:
	if broken:
		return
	if is_broken:
		_health = 0.0
		_break(Vector3.INF, Vector3.ZERO)
		return
	if health_now < _health - 0.001:
		art.flash()
	_health = clampf(health_now, 0.0, max_health)
	_show_health()


func _fx_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_parent()
