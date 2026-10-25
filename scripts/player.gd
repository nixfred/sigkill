extends CharacterBody3D
## First-person player: WASD + mouse look + jump, and a hitscan "terminal cannon".
##
## Mouse rules: the mouse is captured only after the player clicks into the
## window. Esc, or the window losing focus, releases it. The game never grabs
## the mouse on its own and never steals focus.

const Palette = preload("res://scripts/palette.gd")
const Controls = preload("res://scripts/controls.gd")

## Emitted after each shot. `hit_target` is true when the ray struck a target.
signal shot_fired(hit_target: bool)

const WALK_SPEED := 6.0
const GROUND_ACCEL := 45.0
const AIR_ACCEL := 9.0
const JUMP_VELOCITY := 5.2
const MOUSE_SENSITIVITY := 0.0022  # radians per pixel
const PITCH_LIMIT := 1.55  # just under 89 degrees
const FALL_LIMIT := -30.0

const FIRE_COOLDOWN := 0.16
const FIRE_RANGE := 120.0
const CANNON_DAMAGE := 1.0
const HIT_MASK := 5  # physics layers: 1 = world, 3 = targets (value 4)
const BEAM_RADIUS := 0.012
const BEAM_SECONDS := 0.12
const IMPACT_SECONDS := 0.18
const VIEWMODEL_REST_Z := -0.45

var _spawn: Transform3D
var _last_shot := -10.0
var _fire_queued := false
var _viewmodel: MeshInstance3D

@onready var _head: Node3D = $Head
@onready var _camera: Camera3D = $Head/Camera
@onready var _muzzle: Marker3D = $Head/Camera/Muzzle


func _ready() -> void:
	Controls.ensure()
	_spawn = global_transform
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
		rotate_y(-motion.relative.x * MOUSE_SENSITIVITY)
		_head.rotation.x = clampf(
			_head.rotation.x - motion.relative.y * MOUSE_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT
		)
	elif event.is_action_pressed("fire"):
		_fire_queued = true


func _physics_process(delta: float) -> void:
	var engaged := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

	if not is_on_floor():
		velocity += get_gravity() * delta

	var wish := Vector3.ZERO
	if engaged:
		var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		wish = (global_transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	velocity.x = move_toward(velocity.x, wish.x * WALK_SPEED, accel * delta)
	velocity.z = move_toward(velocity.z, wish.z * WALK_SPEED, accel * delta)
	move_and_slide()

	# Shots are resolved here, inside the physics step, so the ray query is safe.
	if _fire_queued:
		_fire_queued = false
		if engaged:
			_fire()

	if global_position.y < FALL_LIMIT:
		global_transform = _spawn
		velocity = Vector3.ZERO


func _release_mouse() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


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
