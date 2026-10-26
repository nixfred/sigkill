extends CharacterBody3D
## First-person player: WASD + mouse look, jump and slide, plus a hitscan "terminal cannon".
##
## Movement feel lives in one resource: scripts/movement_tuning.gd, with the default
## instance in resources/movement_tuning.tres. Every movement and camera number comes
## from it. All motion is scaled by delta, so it feels the same at any physics rate.
##
## Mouse rules: the mouse is captured only after the player clicks into the window.
## Esc, or the window losing focus, releases it. The game never grabs the mouse on
## its own and never steals focus.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")
const Tuning = preload("res://scripts/movement_tuning.gd")
const DEFAULT_TUNING_PATH := "res://resources/movement_tuning.tres"

## Emitted after each shot. `hit_target` is true when the ray struck a target.
signal shot_fired(hit_target: bool)

# --- Terminal cannon constants. Weapon feel is chunk C6; none of these are movement. ---
const FIRE_COOLDOWN := 0.16
const FIRE_RANGE := 120.0
const CANNON_DAMAGE := 1.0
const HIT_MASK := 5  # physics layers: 1 = world, 3 = targets (value 4)
const BEAM_RADIUS := 0.012
const BEAM_SECONDS := 0.12
const IMPACT_SECONDS := 0.18
const VIEWMODEL_REST_Z := -0.45
# --- End of terminal cannon constants. ---

## Movement and camera tuning. Leave empty to use resources/movement_tuning.tres.
@export var tuning: Resource

var _t: Tuning
var _spawn: Transform3D
var _last_shot := -INF
var _fire_queued := false
var _viewmodel: MeshInstance3D

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
	_build_viewmodel()


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
		var motion := event as InputEventMouseMotion
		var pitch_limit := deg_to_rad(_t.pitch_limit_degrees)
		rotate_y(-motion.relative.x * _t.mouse_sensitivity)
		_head.rotation.x = clampf(
			_head.rotation.x - motion.relative.y * _t.mouse_sensitivity, -pitch_limit, pitch_limit
		)
	elif event.is_action_pressed("fire"):
		_fire_queued = true


# --- Movement and camera. Every number below comes from the tuning resource. ---

func _physics_process(delta: float) -> void:
	if not _scripted_input:
		_read_player_input()
	_step_movement(delta)
	_step_camera(delta)
	# Presses are one-shot. Scripted input lasts exactly one physics frame, then the
	# keyboard takes over again.
	_jump_pressed = false
	_slide_pressed = false
	if _scripted_input:
		_move_input = Vector2.ZERO
		_scripted_input = false

	# Shots are resolved here, inside the physics step, so the ray query is safe.
	if _fire_queued:
		_fire_queued = false
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_fire()

	if global_position.y < _t.fall_respawn_height:
		_respawn()


## Test hook: supplies the input for the next physics frame only, instead of the
## keyboard. jump and slide are one-shot presses. Used by tests/movement_test.gd.
func drive_input(move: Vector2, jump: bool = false, slide: bool = false) -> void:
	_scripted_input = true
	_move_input = move.limit_length(1.0)
	_jump_pressed = jump
	_slide_pressed = slide


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
		return
	_move_input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_jump_pressed = Input.is_action_just_pressed("jump")
	_slide_pressed = Input.is_action_just_pressed("slide")


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


func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# --- Terminal cannon. Weapon feel is chunk C6; the numbers below are not movement. ---

func _fire() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_shot < FIRE_COOLDOWN:
		return
	_last_shot = now

	var origin := _camera.global_position
	var forward := -_camera.global_transform.basis.z
	var far_point := origin + forward * FIRE_RANGE

	var query := PhysicsRayQueryParameters3D.create(origin, far_point, HIT_MASK)
	var result := get_world_3d().direct_space_state.intersect_ray(query)

	var end_point := far_point
	var hit_target := false
	if not result.is_empty():
		end_point = result["position"]
		var collider = result["collider"]
		if is_instance_valid(collider) and collider.has_method("hit"):
			collider.call("hit", CANNON_DAMAGE, end_point)
			hit_target = true
		_spawn_impact(end_point)

	_spawn_beam(_muzzle.global_position, end_point)
	_kick_viewmodel()
	shot_fired.emit(hit_target)


func _build_viewmodel() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.09, 0.09, 0.5)
	_viewmodel = MeshInstance3D.new()
	_viewmodel.name = "TerminalCannon"
	_viewmodel.mesh = mesh
	_viewmodel.material_override = Palette.glow(Palette.TEAL, 0.6)
	_viewmodel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_viewmodel.position = Vector3(0.22, -0.2, VIEWMODEL_REST_Z)
	_camera.add_child(_viewmodel)


func _kick_viewmodel() -> void:
	var tween := create_tween()
	tween.tween_property(_viewmodel, "position:z", VIEWMODEL_REST_Z, 0.09).from(VIEWMODEL_REST_Z + 0.07)


func _spawn_beam(start: Vector3, finish: Vector3) -> void:
	var length := start.distance_to(finish)
	if length < 0.1:
		return
	var pivot := Node3D.new()
	get_tree().current_scene.add_child(pivot)
	pivot.global_position = start.lerp(finish, 0.5)
	var dir := (finish - start) / length
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
	pivot.look_at(finish, up)

	var cyl := CylinderMesh.new()
	cyl.top_radius = BEAM_RADIUS
	cyl.bottom_radius = BEAM_RADIUS
	cyl.height = length
	cyl.radial_segments = 6
	cyl.rings = 1
	var mat := Palette.unlit_alpha(Palette.MINT)
	var beam := MeshInstance3D.new()
	beam.mesh = cyl
	beam.material_override = mat
	beam.rotation_degrees = Vector3(90.0, 0.0, 0.0)  # cylinder axis Y -> pivot's -Z
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(beam)

	var tween := pivot.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, BEAM_SECONDS)
	tween.tween_callback(pivot.queue_free)


func _spawn_impact(point: Vector3) -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := Palette.unlit_alpha(Palette.MINT)
	var flash := MeshInstance3D.new()
	flash.mesh = sphere
	flash.material_override = mat
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_tree().current_scene.add_child(flash)
	flash.global_position = point

	var tween := flash.create_tween()
	tween.set_parallel(true)
	tween.tween_property(flash, "scale", Vector3.ONE * 2.2, IMPACT_SECONDS)
	tween.tween_property(mat, "albedo_color:a", 0.0, IMPACT_SECONDS)
	tween.chain().tween_callback(flash.queue_free)
