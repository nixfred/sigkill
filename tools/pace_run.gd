extends SceneTree
## Mission 1 (login) played start to finish by a scripted first-timer (C37), headless, to measure how long it takes:
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/pace_run.gd [-- --seed=<n>]
##
## The player is driven as the keyboard and mouse would drive it (scripts/player.gd drive_input(), its view turned at
## a hand's pace, never snapped): it walks the walk grid's shortest way to each objective (scripts/ruins/ruins_layout.gd
## walk_grid(); no teleport), stops to read each objective as it comes up and each log it picks up (and walks to the two
## logs the mission does not ask for, as a first-timer looking round would), turns to the nearest daemon it can see
## after a human's reaction time, aims with a hand's error and fires the cannon once its aim is close, backs off a
## rogue.d inside its reach, and takes every hit as it lands; a death fails the mission, and it reads the card and
## retries. It prints the mission's clock of its clear, its deaths and retries, its kills, and the minutes in all from
## the first card to "exit 0". Demo data and the scripted guide (no AI call); it reads nothing of the machine and writes
## nothing. The numbers it plays by are the constants below.

const MainScene = preload("res://scenes/main.tscn")
const Link = preload("res://scripts/guide/guide_link.gd")
const Controls = preload("res://scripts/controls.gd")

## A first-timer's hand: seconds before it turns to a daemon it has just seen, how fast it turns its view, how far
## off it aims (radians, wandering as it keeps on a target), how close its aim must be to fire, how far it sees to fight.
const REACT_S := 0.6
const TURN_RAD_S := 2.0
const AIM_ERROR := 0.09
const FIRE_ERROR := 0.07
## How fast its aim wanders off the mark (radians a second, at random) and how hard it pulls back toward it (a share a
## second): about half its shots at a rogue.d across the plaza miss.
const WOBBLE := 1.6
const PULL := 1.2
const ENGAGE_M := 24.0
## A rogue.d this close is backed away from.
const BACK_M := 3.2
## Seconds spent reading: an objective as it comes up, a log picked up, the end card of a death.
const READ_OBJECTIVE_S := 1.6
const READ_LOG_S := 4.5
const READ_FAIL_S := 2.5
## The longest it plays, in game seconds, before it gives up.
const MOST_S := 900.0
## How near a waypoint counts as reached, and how far ahead it looks along its way, metres.
const WAYPOINT_M := 0.45
const LOOK_AHEAD_M := 1.2

var _rng := RandomNumberGenerator.new()
var _main: Node = null
var _runner: MissionRunner = null
var _player: Node3D = null
var _world: RuinsWorld = null
var _grid := {}
var _path: Array[Vector3] = []
var _path_to := Vector3.INF
var _target: Node3D = null
var _seen_at := 0.0
var _aim_off := Vector2.ZERO
var _pause := 0.0
var _clock := 0.0
var _deaths := 0
var _last_index := -1
var _logs_seen := 0
var _side_logs: Array = []
var _hurt := 0.0
var _lowest := 100.0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_rng.seed = 37
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_rng.seed = int(arg.trim_prefix("--seed="))
	Controls.ensure()
	GameSettings.current().reset()
	GameSettings.current().set_value("gameplay", "practice", false)
	GameSettings.current().set_value("gameplay", "difficulty", "normal")
	MissionRunner.clear_pending()
	var link := Link.new()
	link.demo = true
	link.settings_path = "user://pace-run-privacy.cfg"
	Link.park(link)
	_main = MainScene.instantiate()
	root.add_child(_main)
	current_scene = _main
	await _frames(3)
	var old := _main
	MissionRunner.of(_main).begin(MissionBook.at(1))
	await _take_arena(old)
	var started := _clock
	while _clock - started < MOST_S:
		if _runner.state == MissionRunner.State.COMPLETE:
			break
		if _runner.state == MissionRunner.State.FAILED:
			_deaths += 1
			print("pace: derezzed at %.1f s of try %d (objective %d, %s)" % [_runner.clock, _runner.attempt, _runner.index + 1, _runner.reason])
			await _wait(READ_FAIL_S)
			old = _main
			_runner.retry()
			await _take_arena(old)
			continue
		_step()
		await physics_frame
		_clock += 1.0 / Engine.physics_ticks_per_second
		if OS.get_cmdline_user_args().has("--trace") and int(_clock * 60.0) % 600 == 0:
			var goal := _goal()
			print("pace: trace %.0f s: at %s, goal %s, %d waypoints, threat %s, pause %.1f, standing %d" % [_runner.clock, str(_player.global_position.snapped(Vector3.ONE * 0.1)), str(goal.snapped(Vector3.ONE * 0.1)) if goal.is_finite() else "-", _path.size(), str(_target.global_position.snapped(Vector3.ONE * 0.1)) if _target != null and is_instance_valid(_target) else "-", _pause, _runner.stage.standing().size() if _runner.stage != null else 0])
	var done := _runner.state == MissionRunner.State.COMPLETE
	print("pace: %s after %.1f game seconds (%.2f minutes) from the first card; its clear %.1f s of its clock (try %d), %d deaths, %d kills in the clear, %d of 3 logs; %.0f damage taken in all, its health down to %.0f at worst" % ["DONE" if done else "GAVE UP", _clock - started, (_clock - started) / 60.0, _runner.clock, _runner.attempt, _deaths, _runner.kills, _runner.logs_found.size(), _hurt, _lowest])
	if is_instance_valid(_main):
		_main.free()
	await _frames(3)
	quit(0 if done else 1)


## The arena reloaded in place of `old`, taken up: its runner, its player, its ruins, its walk grid.
func _take_arena(old: Node) -> void:
	while current_scene == null or current_scene == old or not current_scene.has_node("Player") or not current_scene.is_node_ready():
		await process_frame
		_clock += 1.0 / Engine.physics_ticks_per_second
	_main = current_scene
	_runner = MissionRunner.of(_main)
	_player = _main.get_node("Player")
	_player.assume_captured = true
	_main.get_node("Hud").guide().focus_check = func(): return false
	_main.get_node("Hud").pause_menu().focus_check = func(): return false
	_world = _runner.world
	_grid = _world.layout.walk_grid()
	_runner.life.hurt.connect(func(amount: float, health: float, _by: Node) -> void:
		_hurt += amount
		_lowest = minf(_lowest, health))
	_path.clear()
	_path_to = Vector3.INF
	_target = null
	_last_index = -1
	_side_logs = ["sched", "watchdog"]
	await _frames(2)


## One physics step of the first-timer.
func _step() -> void:
	if _runner.state != MissionRunner.State.RUNNING:
		_player.drive_input(Vector2.ZERO)
		return
	if _runner.index != _last_index:
		_last_index = _runner.index
		_pause = maxf(_pause, READ_OBJECTIVE_S)
		_path.clear()
		print("pace: objective %d (%s) at %.1f s of its clock" % [_runner.index + 1, _runner.objective().get("id", "-"), _runner.clock])
	if _runner.logs_found.size() != _logs_seen:
		_logs_seen = _runner.logs_found.size()
		_pause = maxf(_pause, READ_LOG_S)
	var dt := 1.0 / Engine.physics_ticks_per_second
	var threat := _threat()
	var move := Vector2.ZERO
	var fire := false
	if threat != null:
		if threat != _target:
			_target = threat
			_seen_at = _clock
			_aim_off = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6)) * AIM_ERROR
		# A first-timer's hand never settles: its aim wanders round the mark (a random walk, pulled back gently).
		_aim_off += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * WOBBLE * dt
		_aim_off = (_aim_off * (1.0 - PULL * dt)).limit_length(AIM_ERROR * 1.6)
		if _clock - _seen_at >= REACT_S:
			var err := _turn_to(threat.threat_point(), dt)
			fire = err < FIRE_ERROR
		if threat.global_position.distance_to(_player.global_position) < BACK_M:
			move = Vector2(0, 1)  # back up, or it opens you
	else:
		_target = null
		if _pause > 0.0:
			_pause -= dt
		else:
			var goal := _goal()
			if goal.is_finite():
				move = _walk_to(goal, dt)
	_player.drive_input(move, false, false, fire)


## The nearest standing daemon it can see within ENGAGE_M, or null.
func _threat() -> Node3D:
	if _runner.stage == null:
		return null
	var eye: Vector3 = _player.eye_position()
	var best: Node3D = null
	var best_d := ENGAGE_M
	for d in _runner.stage.standing():
		if not d.is_alive():
			continue
		var at: Vector3 = d.threat_point()
		var dist := eye.distance_to(at)
		if dist < best_d and _clear(eye, at):
			best = d
			best_d = dist
	return best


func _clear(from: Vector3, to: Vector3) -> bool:
	var space := _player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	return space.intersect_ray(q).is_empty()


## Where the objective running wants it: a reach's point, its log, the plaza while a pack is coming, a side log on the way.
func _goal() -> Vector3:
	var o := _runner.objective()
	match o.get("kind"):
		"reach":
			if o.get("id") == "drop":
				return _world.point("breach")
			return _runner.reach_place(_runner.index)
		"log":
			return _runner.log_place(str(o["log"]))
		"kill":
			var standing: Array = _runner.stage.standing() if _runner.stage != null else []
			if not standing.is_empty():
				return (standing[0] as Node3D).global_position
			return Vector3.INF
		"survive":
			# Looking round the start as the timeslice runs: the log tucked by the start is found on the way.
			for id in _side_logs:
				var p := _runner.pickup(id)
				if p != null and id == "sched":
					return p.global_position
			return Vector3.INF
	return Vector3.INF


## A step along the shortest way to `goal` on the walk grid: the view turned toward the next waypoint, forward.
func _walk_to(goal: Vector3, dt: float) -> Vector2:
	if _path.is_empty() or _path_to.distance_to(goal) > 1.0:
		_path = _route(_player.global_position, goal)
		_path_to = goal
	while not _path.is_empty() and Vector2(_path[0].x - _player.global_position.x, _path[0].z - _player.global_position.z).length() < WAYPOINT_M:
		_path.pop_front()
	var next: Vector3 = goal if _path.is_empty() else _path[0]
	if _path.size() > 1 and Vector2(next.x - _player.global_position.x, next.z - _player.global_position.z).length() < LOOK_AHEAD_M:
		next = _path[1]  # looking a step ahead, as a walker does
	var flat := Vector2(next.x - _player.global_position.x, next.z - _player.global_position.z)
	if flat.length() < 0.2:
		return Vector2.ZERO
	var err := _turn_to(Vector3(next.x, _player.eye_position().y, next.z), dt)
	# A hand turns first and walks once it faces the way (at a run, its turn is far wider than a waypoint).
	return Vector2(0, -1) if err < 0.3 else Vector2.ZERO


## Turns the view toward `at` at a hand's pace (its aim off by the hand's error); how far off it still is (radians).
func _turn_to(at: Vector3, dt: float) -> float:
	var eye: Vector3 = _player.eye_position()
	var to := at - eye
	var yaw_want := atan2(-to.x, -to.z) + _aim_off.x
	var pitch_want := atan2(to.y, Vector2(to.x, to.z).length()) + _aim_off.y
	var head: Node3D = _player.get_node("Head")
	var dy := wrapf(yaw_want - _player.rotation.y, -PI, PI)
	var dp := pitch_want - head.rotation.x
	var step := TURN_RAD_S * dt
	_player.rotation.y += clampf(dy, -step, step)
	head.rotation.x = clampf(head.rotation.x + clampf(dp, -step, step), -1.4, 1.4)
	return Vector2(dy, dp).length()


## The walk grid's shortest way from `from` to `to` (breadth first), as waypoints in world space.
func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	var open: PackedByteArray = _grid["open"]
	var n: Vector2i = _grid["n"]
	var ext: Vector2 = _grid["ext"]
	var cell := func(p: Vector3) -> Vector2i:
		var local := _world.to_local(p)
		return Vector2i(clampi(floori((local.x + ext.x) / RuinsLayout.WALK_M), 0, n.x - 1), clampi(floori((local.z + ext.y) / RuinsLayout.WALK_M), 0, n.y - 1))
	var a: Vector2i = cell.call(from)
	var b: Vector2i = _nearest_open(cell.call(to), open, n)
	var came := {a: a}
	var todo: Array[Vector2i] = [a]
	var head := 0
	while head < todo.size():
		var c: Vector2i = todo[head]
		head += 1
		if c == b:
			break
		for s in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			var m: Vector2i = c + s
			if m.x < 0 or m.y < 0 or m.x >= n.x or m.y >= n.y or came.has(m) or open[m.y * n.x + m.x] == 0:
				continue
			if s.x != 0 and s.y != 0 and (open[c.y * n.x + m.x] == 0 or open[m.y * n.x + c.x] == 0):
				continue  # never cut a corner
			came[m] = c
			todo.append(m)
	var out: Array[Vector3] = []
	if not came.has(b):
		return out
	var c := b
	while c != a:
		out.push_front(_world.to_global(Vector3(-ext.x + (c.x + 0.5) * RuinsLayout.WALK_M, 0.0, -ext.y + (c.y + 0.5) * RuinsLayout.WALK_M)))
		c = came[c]
	return out


func _nearest_open(c: Vector2i, open: PackedByteArray, n: Vector2i) -> Vector2i:
	if open[c.y * n.x + c.x] == 1:
		return c
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var m := c + Vector2i(dx, dy)
				if m.x >= 0 and m.y >= 0 and m.x < n.x and m.y < n.y and open[m.y * n.x + m.x] == 1:
					return m
	return c


func _wait(seconds: float) -> void:
	var frames := int(seconds * Engine.physics_ticks_per_second)
	for i in frames:
		_player.drive_input(Vector2.ZERO)
		await physics_frame
		_clock += 1.0 / Engine.physics_ticks_per_second


func _frames(n: int) -> void:
	for i in n:
		await process_frame
