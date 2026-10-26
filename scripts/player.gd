extends CharacterBody3D
## First-person player: WASD + mouse look, jump and slide, plus a hitscan "terminal cannon".
##
## Movement feel lives in one resource: scripts/movement_tuning.gd, with the default
## instance in resources/movement_tuning.tres. Every movement and camera number comes
## from it. All motion is scaled by delta, so it feels the same at any physics rate.
## The cannon works the same way: scripts/weapon_tuning.gd, default instance
## resources/terminal_cannon.tres, with its effects in scripts/cannon_fx.gd and its
## synthesised sounds in scripts/sfx_synth.gd.
##
## Mouse rules: the mouse is captured only after the player clicks into the window.
## Esc, or the window losing focus, releases it. The game never grabs the mouse on
## its own and never steals focus.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const Tuning = preload("res://scripts/movement_tuning.gd")
const DEFAULT_TUNING_PATH := "res://resources/movement_tuning.tres"
const Weapon = preload("res://scripts/weapon_tuning.gd")
const CannonFx = preload("res://scripts/cannon_fx.gd")
const Sfx = preload("res://scripts/sfx_synth.gd")
const DEFAULT_WEAPON_PATH := "res://resources/terminal_cannon.tres"

## Emitted after each shot. `hit_target` is true when the ray struck a target.
signal shot_fired(hit_target: bool)

## Movement and camera tuning. Leave empty to use resources/movement_tuning.tres.
@export var tuning: Resource
## Terminal cannon tuning. Leave empty to use resources/terminal_cannon.tres.
@export var weapon: Resource

## Round stats, counted for the HUD now and for round-stat coaching later.
var shots_fired := 0
var hits_landed := 0

var _t: Tuning
var _w: Weapon
var _spawn: Transform3D
var _fire_queued := false
var _viewmodel: MeshInstance3D
var _rng := RandomNumberGenerator.new()
var _cooldown_left := 0.0
var _recoil := Vector2.ZERO  # pitch and yaw kick in radians, applied to the camera
var _viewmodel_kick := 0.0
var _fire_sfx: AudioStreamPlayer
var _hit_sfx: AudioStreamPlayer

# Movement state.
var _sliding := false
var _slide_time := 0.0
var _slide_cooldown_left := 0.0
var _was_on_floor := false
var _air_speed_cap := 0.0
var _bob_phase_v := 0.0
var _bob_phase_h := 0.0
var _bob_weight := 0.0
var _fov_kick := 0.0

# Input for this physics frame: from the keyboard, or from a test through drive_input().
var _move_input := Vector2.ZERO
var _jump_pressed := false
var _slide_pressed := false
var _fire_pressed := false
var _scripted_input := false

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _muzzle: Marker3D = $Head/Camera/Muzzle


func _ready() -> void:
	Controls.ensure()
	if not (tuning is Tuning):
		tuning = load(DEFAULT_TUNING_PATH)
	_t = tuning as Tuning
	if _t == null:
		push_error("player: no movement tuning resource at " + DEFAULT_TUNING_PATH)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	var issues := _t.problems()
	if not issues.is_empty():
		for issue in issues:
			push_warning("movement tuning: " + issue + "; using the built-in defaults instead")
		_t = Tuning.new()
	_spawn = global_transform
	_head.position.y = _t.stand_head_height
	_camera.fov = _t.base_fov

	if not (weapon is Weapon):
		weapon = load(DEFAULT_WEAPON_PATH)
	_w = weapon as Weapon
	if _w == null:
		push_error("player: no weapon tuning resource at " + DEFAULT_WEAPON_PATH)
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	var weapon_issues := _w.problems()
	if not weapon_issues.is_empty():
		for issue in weapon_issues:
			push_warning("weapon tuning: " + issue + "; using the built-in defaults instead")
		_w = Weapon.new()
	_rng.randomize()
	_muzzle.position = _w.muzzle_offset
	_build_viewmodel()
	_fire_sfx = _make_sfx_player(Sfx.fire_zap(_w))
	_hit_sfx = _make_sfx_player(Sfx.hit_blip(_w))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_mouse()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		_release_mouse()
		get_viewport().set_input_as_handled()
		return

	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		# Click to engage. That click is consumed so it never fires the cannon.
		if event.is_action_pressed("fire"):
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		_look((event as InputEventMouseMotion).relative)
	elif event.is_action_pressed("fire"):
		_fire_queued = true


## Mouse look: yaw on the body, pitch on the head, clamped to the pitch limit. The recoil
## on the camera is re-clamped straight away, so aim plus recoil never tips the view past
## the limit, not even between physics ticks.
func _look(relative: Vector2) -> void:
	var pitch_limit := deg_to_rad(_t.pitch_limit_degrees)
	rotate_y(-relative.x * _t.mouse_sensitivity)
	_head.rotation.x = clampf(_head.rotation.x - relative.y * _t.mouse_sensitivity, -pitch_limit, pitch_limit)
	_apply_recoil()


# --- Movement and camera. Every number below comes from the tuning resource. ---

func _physics_process(delta: float) -> void:
	if not _scripted_input:
		_read_player_input()
	_step_movement(delta)
	_step_camera(delta)
	_step_weapon(delta)
	# Presses are one-shot. Scripted input lasts exactly one physics frame, then the
	# keyboard takes over again.
	_jump_pressed = false
	_slide_pressed = false
	_fire_pressed = false
	if _scripted_input:
		_move_input = Vector2.ZERO
		_scripted_input = false

	if global_position.y < _t.fall_respawn_height:
		_respawn()


## Test hook: supplies the input for the next physics frame only, instead of the
## keyboard and mouse. jump, slide and fire are one-shot presses. Used by the tests in
## tests/.
func drive_input(move: Vector2, jump: bool = false, slide: bool = false, fire: bool = false) -> void:
	_scripted_input = true
	_move_input = move.limit_length(1.0)
	_jump_pressed = jump
	_slide_pressed = slide
	_fire_pressed = fire


## True while a slide is running.
func is_sliding() -> bool:
	return _sliding


## Current speed along the ground plane, in m/s.
func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _read_player_input() -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_move_input = Vector2.ZERO
		_jump_pressed = false
		_slide_pressed = false
		_fire_pressed = false
		_fire_queued = false
		return
	_move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_jump_pressed = Input.is_action_just_pressed("jump")
	_slide_pressed = Input.is_action_just_pressed("slide")
	# Clicks arrive through _unhandled_input; the shot itself is resolved in the physics step.
	_fire_pressed = _fire_queued
	_fire_queued = false


func _step_movement(delta: float) -> void:
	var on_floor := is_on_floor()
	_slide_cooldown_left = maxf(_slide_cooldown_left - delta, 0.0)
	if not on_floor:
		velocity += get_gravity() * _t.gravity_scale * delta

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed := horizontal.length()
	var wish := global_transform.basis * Vector3(_move_input.x, 0.0, _move_input.y)
	wish.y = 0.0
	wish = wish.limit_length(1.0)

	# A running slide ends by jumping, leaving the ground, timing out or slowing down.
	var slide_jump := false
	if _sliding:
		_slide_time += delta
		if _jump_pressed and on_floor:
			slide_jump = true
			_end_slide()
		elif not on_floor or _slide_time >= _t.slide_max_duration or speed <= _t.slide_end_speed:
			_end_slide()

	# A jump pressed on the same frame wins: no slide starts and the normal jump runs.
	var start_slide := (
		_slide_pressed and not _jump_pressed and on_floor and not _sliding and not slide_jump
		and _slide_cooldown_left <= 0.0 and speed > 0.0 and speed >= _t.slide_min_speed
	)

	if slide_jump:
		# Jump out of the slide and keep its momentum, up to a cap.
		velocity.y = _t.jump_velocity
		horizontal = horizontal.limit_length(_t.slide_jump_max_speed)
	elif start_slide:
		# Short burst along the current direction of travel. Never slows the player down.
		_sliding = true
		_slide_time = 0.0
		var burst := maxf(speed, minf(speed + _t.slide_boost, _t.slide_max_speed))
		horizontal = horizontal / speed * burst
	elif _sliding:
		horizontal = horizontal.move_toward(Vector3.ZERO, _t.slide_friction * delta)
	elif on_floor:
		if wish.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, _t.ground_friction * delta)
		else:
			horizontal = horizontal.move_toward(wish * _t.walk_speed, _t.ground_accel * delta)
		if _jump_pressed:
			velocity.y = _t.jump_velocity
	else:
		# Air: reduced steering. Speed is capped at walk speed or at the speed carried off
		# the ground, whichever is higher, so strafing never builds extra speed.
		var cap := maxf(_air_speed_cap, _t.walk_speed)
		if wish.is_zero_approx():
			horizontal = horizontal.move_toward(Vector3.ZERO, _t.air_drag * delta)
		else:
			horizontal = horizontal.move_toward(wish * cap, _t.ground_accel * _t.air_control * delta)
		horizontal = horizontal.limit_length(cap)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()

	var grounded := is_on_floor()
	if _was_on_floor and not grounded:
		_air_speed_cap = clampf(horizontal_speed(), _t.walk_speed, _t.slide_jump_max_speed)
	_was_on_floor = grounded


func _end_slide() -> void:
	_sliding = false
	_slide_cooldown_left = _t.slide_cooldown


func _step_camera(delta: float) -> void:
	var speed := horizontal_speed()
	var grounded := is_on_floor()

	# Camera height: lowered while sliding, eased both ways.
	var head_target := _t.slide_head_height if _sliding else _t.stand_head_height
	_head.position.y = lerpf(_head.position.y, head_target, _smoothing(_t.head_height_smoothing, delta))

	# Head bob: scales with ground speed, fades out in the air and while sliding.
	var bob_target := 0.0
	if _t.head_bob_enabled and grounded and not _sliding and _t.walk_speed > 0.0:
		bob_target = clampf(speed / _t.walk_speed, 0.0, 1.0)
	_bob_weight = lerpf(_bob_weight, bob_target, _smoothing(_t.bob_smoothing, delta))
	var advance := TAU * _t.bob_frequency * bob_target * delta
	_bob_phase_v = wrapf(_bob_phase_v + advance, 0.0, TAU)
	_bob_phase_h = wrapf(_bob_phase_h + advance * _t.bob_lateral_ratio, 0.0, TAU)
	_camera.position = Vector3(
		sin(_bob_phase_h) * _t.bob_lateral, sin(_bob_phase_v) * _t.bob_vertical, 0.0
	) * _bob_weight

	# FOV kick: widens above walk speed and while sliding, capped, eased in and out.
	var kick := 0.0
	var span := _t.fov_full_speed - _t.walk_speed
	if span > 0.0:
		kick = _t.fov_speed_kick * clampf((speed - _t.walk_speed) / span, 0.0, 1.0)
	if _sliding:
		kick += _t.fov_slide_kick
	kick = minf(kick, _t.fov_max_kick)
	_fov_kick = lerpf(_fov_kick, kick, _smoothing(_t.fov_smoothing, delta))
	_camera.fov = _t.base_fov + _fov_kick


## Share of the way to move toward a target this frame, for exponential easing at `rate`
## per second. The same total easing happens per second at any frame rate.
func _smoothing(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)


func _respawn() -> void:
	global_transform = _spawn
	velocity = Vector3.ZERO
	_sliding = false
	_slide_cooldown_left = 0.0
	_air_speed_cap = 0.0
	_recoil = Vector2.ZERO


func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Terminal cannon. Every number below comes from the weapon tuning resource. ---

## The weapon tuning in use: the shipped resource, or the built-in defaults if it was bad.
func weapon_tuning() -> Resource:
	return _w


func _step_weapon(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	# Recover first, then apply any new shot, so a shot's kick is the same size at any
	# physics rate. Mouse aim is never touched, so the view settles back on target.
	_recoil = _recoil.lerp(Vector2.ZERO, _smoothing(_w.recoil_recovery, delta))
	_viewmodel_kick = lerpf(_viewmodel_kick, 0.0, _smoothing(_w.viewmodel_recovery, delta))
	# The ray is cast from the camera exactly as the player sees it, clamp included.
	_apply_recoil()
	if _fire_pressed and _cooldown_left <= 0.0:
		_fire()
		_apply_recoil()
	_viewmodel.position = _w.viewmodel_offset + Vector3(0.0, 0.0, _w.viewmodel_kick_back * _viewmodel_kick)
	_viewmodel.rotation.x = deg_to_rad(_w.viewmodel_kick_pitch_degrees) * _viewmodel_kick


func _fire() -> void:
	_cooldown_left = _w.fire_cooldown
	shots_fired += 1
	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var far_point := origin + forward * _w.fire_range
	var query := PhysicsRayQueryParameters3D.create(origin, far_point, _w.hit_mask)
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	var end_point := far_point
	var hit_target := false
	var fx_root := _fx_root()
	if not result.is_empty():
		end_point = result["position"]
		var normal: Vector3 = result["normal"]
		if normal.is_zero_approx():
			normal = -forward
		var collider = result["collider"]
		if is_instance_valid(collider) and collider.has_method("hit"):
			hit_target = collider.call("hit", _w.damage, end_point, forward) == true
		CannonFx.spawn_impact(fx_root, end_point, normal, hit_target, _w)

	CannonFx.spawn_beam(fx_root, _muzzle.global_position, end_point, _w)
	CannonFx.spawn_muzzle_flash(_muzzle, _w)
	_kick()
	_fire_sfx.play()
	if hit_target:
		hits_landed += 1
		_hit_sfx.play()
	shot_fired.emit(hit_target)


## Puts the recoil on the camera, clamped so aim plus recoil stays within the pitch limit.
func _apply_recoil() -> void:
	var pitch_room := maxf(deg_to_rad(_t.pitch_limit_degrees) - _head.rotation.x, 0.0)
	_recoil.x = minf(_recoil.x, pitch_room)
	_camera.rotation = Vector3(_recoil.x, _recoil.y, 0.0)


## Camera kick up plus a small random yaw, both capped, and a cannon jolt.
func _kick() -> void:
	var max_pitch := deg_to_rad(_w.recoil_max_pitch_degrees)
	var max_yaw := deg_to_rad(_w.recoil_max_yaw_degrees)
	var yaw := deg_to_rad(_rng.randf_range(-_w.recoil_yaw_degrees, _w.recoil_yaw_degrees))
	_recoil.x = minf(_recoil.x + deg_to_rad(_w.recoil_pitch_degrees), max_pitch)
	_recoil.y = clampf(_recoil.y + yaw, -max_yaw, max_yaw)
	_viewmodel_kick = 1.0


## Where world-space effects live: the running scene, or the player's parent in tests.
func _fx_root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_parent()


func _build_viewmodel() -> void:
	var mesh := BoxMesh.new()
	mesh.size = _w.viewmodel_size
	_viewmodel = MeshInstance3D.new()
	_viewmodel.name = "TerminalCannon"
	_viewmodel.mesh = mesh
	_viewmodel.material_override = Palette.glow(Palette.TEAL, _w.viewmodel_glow_energy)
	_viewmodel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewmodel.position = _w.viewmodel_offset
	_camera.add_child(_viewmodel)


func _make_sfx_player(stream: AudioStream) -> AudioStreamPlayer:
	var sfx := AudioStreamPlayer.new()
	sfx.stream = stream
	sfx.volume_db = Sfx.volume_db(_w.master_volume)
	sfx.max_polyphony = _w.sfx_polyphony
	add_child(sfx)
	return sfx
