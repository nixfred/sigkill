extends StaticBody3D
## Target dummy: a hexagonal prism standing in for a rogue process. It takes hits, and when
## it dies it derezzes, then rematerialises at its spot with full health.
## States: ALIVE, DEREZZING (collision off, hidden, not hittable), RESPAWNING (growing
## back, still not hittable), then ALIVE again. Only an ALIVE dummy can be hit, so it dies
## exactly once per life. It never moves or attacks. The tag text is invented flavour only;
## it never reflects anything on the player's system.

const Palette = preload("res://scripts/palette.gd")
const Derezz = preload("res://scripts/derezz_tuning.gd")
const DerezzFx = preload("res://scripts/derezz_fx.gd")
const DEFAULT_DEREZZ_PATH := "res://resources/derezz.tres"

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

var state: State = State.ALIVE

var _health := 1.0
var _state_time := 0.0
var _material: ShaderMaterial
var _hex: CylinderMesh
var _d: Derezz

@onready var _body: MeshInstance3D = $Body
@onready var _shape: CollisionShape3D = $Shape
@onready var _tag: Label3D = $Tag


func _ready() -> void:
	_health = max_health
	_hex = _body.mesh as CylinderMesh
	_material = Palette.hostile_material(_hex.top_radius, _hex.height)
	_body.material_override = _material

	_tag.text = tag_text
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


func health() -> float:
	return _health


## Called by the player's cannon through the ray hit. Returns true if the hit landed,
## false if the dummy is derezzing or respawning. `point` is where the shot struck.
func hit(damage: float, point: Vector3 = Vector3.INF) -> bool:
	if state != State.ALIVE:
		return false
	_health -= damage
	if _health > 0.0:
		_pulse()
		return true
	_start_derezz(point)
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
		if grown >= 1.0:
			_finish_respawn()


func _start_derezz(point: Vector3) -> void:
	state = State.DEREZZING
	_state_time = 0.0
	_shape.set_deferred("disabled", true)
	_body.visible = false
	_tag.visible = false
	set_physics_process(true)
	# The voxels get a push along the killing shot, when we know where it struck.
	var shot := Vector3.ZERO
	if point.is_finite():
		shot = _body.global_position - point
		shot.y = 0.0
		shot = shot.normalized()
	var fx := DerezzFx.new()
	_fx_root().add_child(fx)
	fx.start(global_position, _hex.top_radius, _hex.height, shot, _d)
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
	_material.set_shader_parameter("edge_color", Palette.HOSTILE_RED)
	_material.set_shader_parameter("edge_energy", Palette.HOSTILE_ENERGY)


func _finish_respawn() -> void:
	state = State.ALIVE
	_health = max_health
	_body.scale = Vector3.ONE
	_tag.visible = true
	_shape.set_deferred("disabled", false)
	set_physics_process(false)
	respawned.emit(self)


func _pulse() -> void:
	_material.set_shader_parameter("edge_color", Palette.HOSTILE_AMBER)
	_material.set_shader_parameter("edge_energy", 8.0)
	var tween := create_tween()
	tween.tween_property(_material, "shader_parameter/edge_energy", Palette.HOSTILE_ENERGY, 0.12)
	tween.parallel().tween_property(_material, "shader_parameter/edge_color", Palette.HOSTILE_RED, 0.12)
