extends StaticBody3D
## Target dummy: a daemon standing in for a rogue process. It takes hits, and when it dies it
## derezzes, then rematerialises at its spot with full health. Its hit volume is a hexagonal
## prism (the Shape, and the Body's hex mesh, which is its size and centre for everything that
## measures it); since A2 what is seen of it is its art (scripts/daemons/), built under the Body
## and drawn instead of the hex, so it hides and grows back with it; since A2b the art is a
## creature that recoils and sprays shards at a hit and bursts into its own parts at the death,
## over the derezz. The art is visual only.
## States: ALIVE, DEREZZING (collision off, hidden, not hittable), RESPAWNING (growing
## back, still not hittable), then ALIVE again. Only an ALIVE dummy can be hit, so it dies
## exactly once per life. It never moves or attacks. The tag text is invented flavour only;
## it never reflects anything on the player's system.

const Palette = preload("res://scripts/palette.gd")
const Derezz = preload("res://scripts/derezz_tuning.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DEFAULT_DEREZZ_PATH := "res://resources/derezz.tres"
const WeaponDefScript = preload("res://scripts/weapons/weapon_def.gd")

enum State { ALIVE, DEREZZING, RESPAWNING }

## Emitted once per death, on the hit that starts the derezz.
signal downed(dummy: Node3D)
## Emitted when the dummy is back: alive, hittable and at full health.
signal respawned(dummy: Node3D)

## Smallest body scale while rematerialising, so its transform never collapses to zero.
const MIN_BODY_SCALE := 0.001

@export var tag_text: String = "<defunct>"
@export var max_health: float = 1.0
## Derezz and respawn tuning. Leave empty to use resources/derezz.tres.
@export var derezz: Resource
## How the daemon looks (A2): a script extending scripts/daemons/daemon_art.gd. Visual only.
@export var art: Script = preload("res://scripts/daemons/rogue_daemon.gd")

var state: State = State.ALIVE

var _health := 1.0
var _state_time := 0.0
var _hex: CylinderMesh
var _art: DaemonArt
var _d: Derezz

@onready var _body: MeshInstance3D = $Body
@onready var _shape: CollisionShape3D = $Shape
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	_health = max_health
	_hex = _body.mesh as CylinderMesh
	# The hex is the volume, drawn by no camera; the art under it is what is seen (A2).
	_body.layers = 0
	_body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_art = DaemonArt.make(art, self)
	_body.add_child(_art)

	_tag.text = tag_text
	_tag.position.y = _art.tag_height  # clear of the creature (A2b)
	_tag.font = Palette.mono_font()
	_tag.font_size = 48
	_tag.pixel_size = 0.006
	_tag.outline_size = 10
	_tag.modulate = Palette.MINT
	_tag.outline_modulate = Palette.VOID
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED

	if not (derezz is Derezz):
		derezz = load(DEFAULT_DEREZZ_PATH)
	_d = derezz as Derezz
	if _d == null:
		push_error("target dummy: no derezz tuning resource at " + DEFAULT_DEREZZ_PATH)
		_d = Derezz.new()
	var issues := _d.problems()
	if not issues.is_empty():
		for issue in issues:
			push_warning("derezz tuning: " + issue + "; using the built-in defaults instead")
		_d = Derezz.new()
	set_physics_process(false)


## True only while the dummy is alive. Derezzing and respawning dummies ignore hits.
func is_hittable() -> bool:
	return state == State.ALIVE


## True while the dummy counts as a live enemy, which the code rain on the walls reacts to.
func is_alive() -> bool:
	return state == State.ALIVE


## Where the dummy is, for anything that measures distance to it: the centre of its body.
func threat_point() -> Vector3:
	return _body.global_position


func health() -> float:
	return _health


## True when `point` is in the dummy's head zone (C17): the top of its prism, WeaponDef's
## HEAD_ZONE_M deep. A rail kill there is called out as "kill -9".
func is_head_hit(point: Vector3) -> bool:
	return point.y >= _body.global_position.y + _hex.height * 0.5 - WeaponDefScript.HEAD_ZONE_M


## Called by the player's cannon through the ray hit. Returns true if the hit landed,
## false if the dummy is derezzing or respawning. `point` is where the shot struck and
## `direction` the way it travelled; both are optional.
func hit(damage: float, point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO) -> bool:
	if state != State.ALIVE:
		return false
	_health -= damage
	if _health > 0.0:
		_pulse(point, direction)
		return true
	_start_derezz(point, direction)
	return true


func _physics_process(delta: float) -> void:
	_state_time += delta
	if state == State.DEREZZING:
		if _state_time >= _d.respawn_delay:
			_begin_rematerialise()
	elif state == State.RESPAWNING:
		var grown := 1.0
		if _d.rematerialise_seconds > 0.0:
			grown = clampf(_state_time / _d.rematerialise_seconds, 0.0, 1.0)
		_body.scale = Vector3.ONE * maxf(grown, MIN_BODY_SCALE)
		_art.set_unstable(1.0 - grown)  # it glitches as it comes back (A2)
		if grown >= 1.0:
			_finish_respawn()


func _start_derezz(point: Vector3, direction: Vector3) -> void:
	state = State.DEREZZING
	_state_time = 0.0
	_shape.set_deferred("disabled", true)
	_body.visible = false
	_tag.visible = false
	set_physics_process(true)
	# The voxels get a push along the killing shot: its real direction when the shooter
	# gives one, otherwise from where it struck toward the body's centre.
	var shot := Vector3(direction.x, 0.0, direction.z)
	if shot.is_zero_approx() and point.is_finite():
		shot = _body.global_position - point
		shot.y = 0.0
	shot = shot.normalized()
	var fx := DerezzFx.new()
	_fx_root().add_child(fx)
	fx.start(global_position, _hex.top_radius, _hex.height, shot, _d)
	_art.shatter(fx, shot)  # the creature's own parts burst apart with the voxels, and go with them (A2b)
	downed.emit(self)


## Where world-space effects live: the running scene, or the dummy's parent in tests.
func _fx_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_parent()


func _begin_rematerialise() -> void:
	state = State.RESPAWNING
	_state_time = 0.0
	_body.scale = Vector3.ONE * MIN_BODY_SCALE
	_body.visible = true
	_art.set_unstable(1.0)


func _finish_respawn() -> void:
	state = State.ALIVE
	_health = max_health
	_body.scale = Vector3.ONE
	_art.set_unstable(0.0)
	_tag.visible = true
	_shape.set_deferred("disabled", false)
	set_physics_process(false)
	respawned.emit(self)


## A new round: back at once, alive, hittable and at full health. A dummy that was down
## (derezzing or growing back) says so with `respawned`; its voxels finish on their own.
func reset_for_round() -> void:
	if state == State.DEREZZING:
		_begin_rematerialise()
	if state == State.RESPAWNING:
		_finish_respawn()
	_health = max_health


## A hit that did not kill: the art flares (A2), recoils and sprays shards from where it struck (A2b).
func _pulse(point: Vector3 = Vector3.INF, direction: Vector3 = Vector3.ZERO) -> void:
	_art.react(point, direction)


## The daemon's art (A2), for the checks.
func art_node() -> DaemonArt:
	return _art
