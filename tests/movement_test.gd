extends SceneTree
## Headless movement test for SIGKILL. scripts/check.sh runs it, and any FAIL exits 1.
##
##   godot --headless --path . --fixed-fps 60 --script res://tests/movement_test.gd
##
## Builds a flat floor, drops the real player scene on it and drives the player through
## drive_input() for a fixed number of physics frames. Targets are in seconds or relative
## to the tuning resource, so the checks hold at any physics rate.
## Read-only: nothing outside this process is touched.

const PLAYER_SCENE := "res://scenes/player.tscn"
const TUNING_PATH := "res://resources/movement_tuning.tres"
const FORWARD := Vector2(0.0, -1.0)
const RIGHT := Vector2(1.0, 0.0)
const MAX_TIME_TO_TOP := 0.25  # seconds: a snappy start
const MAX_TIME_TO_STOP := 0.5  # seconds: a short stop
const MIN_FRAMES := 2  # fewer frames than this is an instant change
const EPS := 0.01
const GUARD_FRAMES := 1200  # hard stop for every wait loop

var _fails := 0
var _world: Node3D
var _player  # the player under test; untyped because it calls the player script's methods
var _t  # that player's tuning resource


func _initialize() -> void:
	_run()


func _run() -> void:
	_build_world()
	await _validation_checks()
	var at60: Dictionary = await _accel_and_stop(60)
	var at120: Dictionary = await _accel_and_stop(120)
	Engine.physics_ticks_per_second = 60
	_check_rate_independence(at60, at120)
	await _slide_checks()
	await _threshold_checks()
	await _slide_jump_and_air_checks()
	await _air_control_check()
	await _head_bob_checks()
	print("MOVE RESULT: ", "ALL PASS" if _fails == 0 else "%d FAILED" % _fails)
	quit(0 if _fails == 0 else 1)


func _check(label: String, ok: bool, detail: String = "") -> void:
	print("PASS " if ok else "FAIL ", label, ("   " + detail) if detail != "" else "")
	if not ok:
		_fails += 1


func _build_world() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400.0, 1.0, 400.0)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(floor_body)


## Replaces the player with a fresh one standing on the floor at the origin.
func _spawn(tuning_override: Resource = null) -> void:
	await physics_frame
	if is_instance_valid(_player):
		_player.queue_free()
		await physics_frame
	_player = load(PLAYER_SCENE).instantiate()
	if tuning_override != null:
		_player.tuning = tuning_override
	_player.position = Vector3(0.0, 0.95, 0.0)
	_world.add_child(_player)
	_t = _player.get("_t")
	var grounded := 0
	for _i in GUARD_FRAMES:
		await _step(Vector2.ZERO)
		grounded = grounded + 1 if _player.is_on_floor() else 0
		if grounded >= 5:
			return
	_check("player settles on the floor", false)


## Feeds one physics frame of input, then waits until the player has moved on it.
func _step(move: Vector2, jump: bool = false, slide: bool = false) -> void:
	_player.drive_input(move, jump, slide)
	await physics_frame


func _speed() -> float:
	return _player.horizontal_speed()


func _rate() -> int:
	return Engine.physics_ticks_per_second


func _run_to_top() -> void:
	for _i in GUARD_FRAMES:
		if _speed() >= _t.walk_speed - EPS:
			break
		await _step(FORWARD)
	for _i in 10:
		await _step(FORWARD)


func _accel_and_stop(rate: int) -> Dictionary:
	Engine.physics_ticks_per_second = rate
	await _spawn()
	var top: float = _t.walk_speed
	var frames_up := 0
	while _speed() < top - EPS and frames_up < GUARD_FRAMES:
		await _step(FORWARD)
		frames_up += 1
	for _i in int(rate * 0.5):
		await _step(FORWARD)
	var start: Vector3 = _player.global_position
	var frames_down := 0
	while _speed() > EPS and frames_down < GUARD_FRAMES:
		await _step(Vector2.ZERO)
		frames_down += 1
	var moved: Vector3 = _player.global_position - start
	var stop_dist := Vector2(moved.x, moved.z).length()
	var t_up := float(frames_up) / rate
	var t_down := float(frames_down) / rate
	print("MOVE %d Hz: standstill to top speed %.2f m/s in %d frames (%.3f s); top speed to stop in %d frames (%.3f s) over %.3f m" % [rate, top, frames_up, t_up, frames_down, t_down, stop_dist])
	_check("%d Hz: snappy start, top speed within %.2f s and not instant" % [rate, MAX_TIME_TO_TOP], t_up <= MAX_TIME_TO_TOP and frames_up >= MIN_FRAMES)
	_check("%d Hz: short stop, within %.2f s and not instant" % [rate, MAX_TIME_TO_STOP], t_down <= MAX_TIME_TO_STOP and frames_down >= MIN_FRAMES)
	return {"t_up": t_up, "t_down": t_down, "stop_dist": stop_dist}


func _check_rate_independence(a: Dictionary, b: Dictionary) -> void:
	var one_frame := 1.0 / 60.0
	var dist_tol: float = _t.walk_speed / 60.0
	print("MOVE frame-rate check: time to top %.3f s at 60 Hz vs %.3f s at 120 Hz; time to stop %.3f s vs %.3f s; stop distance %.3f m vs %.3f m" % [a["t_up"], b["t_up"], a["t_down"], b["t_down"], a["stop_dist"], b["stop_dist"]])
	_check("same time to top speed at 60 and 120 Hz, within one 60 Hz frame", absf(a["t_up"] - b["t_up"]) <= one_frame + 0.000001)
	_check("same time to stop at 60 and 120 Hz, within one 60 Hz frame", absf(a["t_down"] - b["t_down"]) <= one_frame + 0.000001)
	_check("same stopping distance at 60 and 120 Hz, within one frame of travel", absf(a["stop_dist"] - b["stop_dist"]) <= dist_tol)


func _slide_checks() -> void:
	await _spawn()
	await _run_to_top()
	var walk: float = _t.walk_speed
	var stand: float = _t.stand_head_height
	var head: Node3D = _player.get_node("Head")
	var cam: Camera3D = _player.get_node("Head/Camera")
	var speed_before := _speed()
	await _step(FORWARD, false, true)
	_check("C starts a slide at top speed", _player.is_sliding())
	var peak := 0.0
	var min_head := INF
	var max_fov := 0.0
	var frames := 0
	while _player.is_sliding() and frames < GUARD_FRAMES:
		peak = maxf(peak, _speed())
		min_head = minf(min_head, head.position.y)
		max_fov = maxf(max_fov, cam.fov)
		await _step(FORWARD)
		frames += 1
	var seconds := float(frames) / _rate()
	var expected: float = minf(speed_before + _t.slide_boost, _t.slide_max_speed)
	print("MOVE slide: walk speed %.2f m/s, slide peak %.2f m/s (%.2fx walk), lasted %d frames (%.3f s), camera %.2f m down to %.2f m, FOV peak %.2f (base %.1f, cap +%.1f)" % [walk, peak, peak / walk, frames, seconds, stand, min_head, max_fov, _t.base_fov, _t.fov_max_kick])
	_check("slide peak is the burst: speed plus slide_boost, capped at slide_max_speed", absf(peak - expected) < 0.05 and peak > walk, "expected %.2f" % expected)
	_check("camera drops during the slide", min_head < stand - 0.5 * (stand - _t.slide_head_height))
	_check("FOV kicks during the slide and stays under the cap", max_fov > _t.base_fov + 0.5 and max_fov <= _t.base_fov + _t.fov_max_kick + 0.001)

	# Cooldown: keep running at full speed and press C two frames before and two frames
	# after the cooldown ends.
	var boundary := ceili(_t.slide_cooldown * _rate())
	for k in range(1, boundary + 3):
		var probe_before := k == boundary - 2
		var probe_after := k == boundary + 2
		var speed_now := _speed()
		await _step(FORWARD, false, probe_before or probe_after)
		if probe_before:
			_check("cooldown still blocks the slide 2 frames before it ends, at full speed", not _player.is_sliding() and speed_now >= _t.slide_min_speed, "frame %d of %d, %.2f m/s" % [k, boundary, speed_now])
		elif probe_after:
			_check("slide works again 2 frames after the cooldown ends", _player.is_sliding(), "frame %d of %d" % [k, boundary])
	print("MOVE cooldown: %.2f s = %d frames; C blocked at frame %d, allowed at frame %d" % [_t.slide_cooldown, boundary, boundary - 2, boundary + 2])
	for _i in _rate() * 2:
		await _step(Vector2.ZERO)
	_check("camera height eases back to standing", absf(head.position.y - stand) < 0.01, "%.4f m" % head.position.y)
	_check("FOV eases back to base", absf(cam.fov - _t.base_fov) < 0.05, "%.3f" % cam.fov)

	# Duration: with slide friction at 0 only the timer can end the slide.
	var no_friction: Resource = load(TUNING_PATH).duplicate()
	no_friction.slide_friction = 0.0
	await _spawn(no_friction)
	await _run_to_top()
	await _step(FORWARD, false, true)
	var timed := 0
	while _player.is_sliding() and timed < GUARD_FRAMES:
		await _step(FORWARD)
		timed += 1
	var timed_s := float(timed) / _rate()
	print("MOVE slide timer: with no slide friction the slide lasted %d frames (%.3f s), slide_max_duration %.2f s" % [timed, timed_s, _t.slide_max_duration])
	_check("with no slide friction the slide ends at slide_max_duration", absf(timed_s - _t.slide_max_duration) <= 1.5 / _rate())

	# Jump and slide on the same frame: the jump wins and no slide starts.
	await _spawn()
	await _run_to_top()
	await _step(FORWARD, true, true)
	var vy: float = _player.velocity.y
	_check("C and Space on the same frame: the jump wins and no slide starts", vy > 0.0 and not _player.is_sliding() and _speed() <= _t.walk_speed + EPS, "vy %.2f, sliding %s" % [vy, _player.is_sliding()])


func _threshold_checks() -> void:
	await _spawn()
	await _step(FORWARD, false, true)
	_check("C does nothing from a standstill", not _player.is_sliding())
	var threshold: float = _t.slide_min_speed
	for _i in GUARD_FRAMES:
		if _speed() >= threshold * 0.5:
			break
		await _step(FORWARD)
	var pressed_at := _speed()
	await _step(FORWARD, false, true)
	var after := _speed()
	print("MOVE threshold: pressed C at %.2f m/s with the threshold at %.2f m/s; sliding = %s, speed after %.2f m/s" % [pressed_at, threshold, _player.is_sliding(), after])
	_check("slide does not trigger below the speed threshold", pressed_at < threshold and not _player.is_sliding() and after <= _t.walk_speed + EPS)


func _slide_jump_and_air_checks() -> void:
	await _spawn()
	await _run_to_top()
	await _step(FORWARD, false, true)
	await _step(FORWARD)
	var slide_speed := _speed()
	await _step(FORWARD, true)
	var takeoff := _speed()
	var vy: float = _player.velocity.y
	_check("jumping out of a slide leaves the ground and ends the slide", vy > 0.0 and not _player.is_sliding())
	var expected_takeoff: float = minf(slide_speed, _t.slide_jump_max_speed)
	_check("slide-jump keeps the slide's momentum up to slide_jump_max_speed", absf(takeoff - expected_takeoff) < 0.05 and takeoff > _t.walk_speed, "expected %.2f" % expected_takeoff)
	# Strafe hard right through the whole jump. Speed must never grow past the takeoff cap.
	var max_air := 0.0
	var max_side := 0.0
	var frames := 0
	while frames < GUARD_FRAMES:
		await _step(RIGHT)
		frames += 1
		if _player.is_on_floor():
			break
		max_air = maxf(max_air, _speed())
		max_side = maxf(max_side, _player.velocity.x)
	print("MOVE slide-jump: slide %.2f m/s, takeoff %.2f m/s (cap %.2f), top air speed while strafing %.2f m/s, sideways speed gained %.2f m/s, %d frames in the air" % [slide_speed, takeoff, _t.slide_jump_max_speed, max_air, max_side, frames])
	_check("air strafing gains no speed beyond the takeoff speed", max_air <= takeoff + EPS)
	_check("air control steers: sideways speed builds in the air", max_side > 0.1)


func _air_control_check() -> void:
	await _spawn()
	await _step(Vector2.ZERO, true)
	var window := int(0.1 * _rate())
	var airborne := true
	for _i in window:
		await _step(FORWARD)
		airborne = airborne and not _player.is_on_floor()
	var air_speed := _speed()
	var ground_speed: float = minf(_t.walk_speed, _t.ground_accel * float(window) / _rate())
	print("MOVE air control: %.2f s of W in the air from a standstill gives %.2f m/s; the same on the ground gives %.2f m/s (air_control %.2f)" % [float(window) / _rate(), air_speed, ground_speed, _t.air_control])
	_check("air control is reduced but nonzero", airborne and air_speed > 0.0 and air_speed < ground_speed - EPS)
	# Keep holding W for the rest of the jump. A slow takeoff may steer up to walk speed
	# and no further.
	var max_air := air_speed
	for _i in GUARD_FRAMES:
		if _player.is_on_floor():
			break
		await _step(FORWARD)
		if not _player.is_on_floor():
			max_air = maxf(max_air, _speed())
	print("MOVE slow takeoff: holding W through a standstill jump peaks at %.2f m/s in the air (walk speed %.2f)" % [max_air, _t.walk_speed])
	_check("a standstill jump steers up to walk speed and no further", max_air > air_speed and max_air <= _t.walk_speed + EPS)


func _validation_checks() -> void:
	var shipped: Resource = load(TUNING_PATH)
	var issues: PackedStringArray = shipped.problems()
	_check("shipped tuning passes validation", issues.is_empty(), ", ".join(issues))
	var bad: Resource = shipped.duplicate()
	bad.head_height_smoothing = -14.0
	bad.ground_friction = -36.0
	var bad_issues: PackedStringArray = bad.problems()
	_check("validation rejects negative rates", bad_issues.size() == 2, str(bad_issues.size()))
	await _spawn(bad)
	_check("player falls back to safe defaults on bad tuning", _t != bad and _t.problems().is_empty())
	await _run_to_top()
	await _step(FORWARD, false, true)
	for _i in int(0.5 * _rate()):
		await _step(FORWARD)
	var head: Node3D = _player.get_node("Head")
	var head_y := head.position.y
	for _i in _rate():
		await _step(Vector2.ZERO)
	print("MOVE bad tuning: %d problems found; with the fallback the camera stayed at %.3f m and the player stopped at %.3f m/s" % [bad_issues.size(), head_y, _speed()])
	_check("camera stays in range with the bad tuning rejected", head_y >= 0.0 and head_y <= _t.stand_head_height + EPS)
	_check("player still stops with the bad tuning rejected", _speed() <= EPS)


func _bob_amplitude(move: Vector2, seconds: float) -> float:
	var cam: Camera3D = _player.get_node("Head/Camera")
	var peak := 0.0
	for _i in int(seconds * _rate()):
		await _step(move)
		peak = maxf(peak, cam.position.length())
	return peak


func _head_bob_checks() -> void:
	await _spawn()
	await _run_to_top()
	var full: float = await _bob_amplitude(FORWARD, 1.0)
	var cam: Camera3D = _player.get_node("Head/Camera")
	var fov_walk := cam.fov
	await _step(FORWARD, true)
	for _i in int(0.4 * _rate()):
		await _step(FORWARD)
	var in_air := cam.position.length()
	var airborne: bool = not _player.is_on_floor()
	for _i in GUARD_FRAMES:
		if _player.is_on_floor():
			break
		await _step(FORWARD)
	await _run_to_top()
	await _step(FORWARD, false, true)
	for _i in int(0.3 * _rate()):
		await _step(FORWARD)
	var in_slide := cam.position.length()
	var sliding: bool = _player.is_sliding()

	await _spawn()
	for _i in GUARD_FRAMES:
		if _speed() >= _t.walk_speed * 0.5 - EPS:
			break
		await _step(FORWARD * 0.5)
	var half: float = await _bob_amplitude(FORWARD * 0.5, 1.0)

	var off_tuning: Resource = load(TUNING_PATH).duplicate()
	off_tuning.head_bob_enabled = false
	await _spawn(off_tuning)
	await _run_to_top()
	var disabled: float = await _bob_amplitude(FORWARD, 1.0)

	var small: float = 0.1 * maxf(_t.bob_vertical, _t.bob_lateral)
	print("MOVE head bob: %.4f m at walk speed, %.4f m at half speed, %.5f m after 0.4 s in the air, %.5f m 0.3 s into a slide, %.5f m with head_bob_enabled off; FOV at walk speed %.2f" % [full, half, in_air, in_slide, disabled, fov_walk])
	_check("head bob is active at walk speed", full > 0.5 * _t.bob_vertical)
	_check("head bob scales with ground speed", half > 0.0 and half < 0.75 * full)
	_check("head bob fades out in the air", airborne and in_air < small)
	_check("head bob fades out while sliding", sliding and in_slide < small)
	_check("head_bob_enabled = false keeps the camera still", disabled < 0.000001)
	_check("no FOV kick at plain walk speed", absf(fov_walk - _t.base_fov) < 0.05)
