extends SceneTree
## A mission played start to finish by a scripted first-timer (C37, mission 1; M2 any built one), headless, to measure
## how long it takes:
##
##   godot --headless --path . --fixed-fps 60 --script res://tools/pace_run.gd [-- --seed=<n>] [--mission=<n>]
##
## The player is driven as the keyboard and mouse would drive it (scripts/player.gd drive_input(), its view turned at
## a hand's pace, never snapped): it walks the walk grid's shortest way to each objective (scripts/ruins/ruins_layout.gd
## walk_grid(); no teleport), stops to read each objective as it comes up and each log it picks up (and walks to the two
## logs the mission does not ask for, as a first-timer looking round would), turns to the nearest daemon it can see
## after a human's reaction time, aims with a hand's error and fires the cannon once its aim is close, backs off a
## rogue.d inside its reach, and takes every hit as it lands; a death fails the mission, and it reads the card and
## retries. It prints the mission's clock of its clear, its deaths and retries, its kills, and the minutes in all from
## the first card to "exit 0". Demo data and the scripted guide (no AI call); it reads nothing of the machine and writes
## nothing. The numbers it plays by are the constants below. Since M2: --mission=<n> plays campaign mission n (1 by
## default); it goes after the daemons the objective running counts (a sleeper wakes as it comes near, as a player's
## would), never wastes shots on one that is sealed, and walks through a terminal it passes near (an optional log). Since
## M3: in a district whose walls come and go (a cache field) it walks the walk grid's A* grid as its walls stand now
## (RuinsWorld.walk_route(), where the field closes its written walls), so it goes round them as a player would, and
## through a wall mid-rewrite (nothing solid) as a player may; and it follows the hints a first-timer is given: once pipe |
## is in hand it draws it against runaways (the storm's beat: "one shot runs down the chain") and the cannon against
## anything else (a loop's core).

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
## An optional log this near, with nothing to fight in sight, is walked to and read (M2), metres.
const SIDE_LOG_M := 12.0
## Mission 4's (M4): how close a brute is run from a wall (I2: full strength within 2.25 m), and how near a deny rule's
## wall that is not this beat's must be to be in the way (the aisle sealed: the only way through).
const BRUTE_M := 1.6
## Mission 5's (M5): how near a job's vent a mine is placed and how long before another, the band rm -rf is fired from
## (nearer, it removes you too; farther, a first-timer closes in), and how near the root door Z is pressed.
const MINE_M := 3.0
const MINE_GAP_S := 6.0
const RM_BAND := Vector2(7.0, 15.0)
const DOOR_M := 4.0
## Mission 6 (M6): SIGHUP thrown at a watcher this near, no two throws closer than this; /dev/null thrown into a crowd whose
## middle is in this band, no two closer than its gap; Black ICE kept this far off (F pressed as it comes nearer, no
## two presses closer than its gap); SIGHUP at the shell from this near.
const HUP_M := 8.0
const HUP_GAP_S := 2.5
const SINK_BAND := Vector2(4.0, 13.0)
const SINK_GAP_S := 8.0
const BLACK_NEAR_M := 10.0
const BLACK_FLEE_M := 7.0
const STOP_GAP_S := 16.0
const SHELL_M := 6.0
const WALL_NEAR_M := 4.0
## Mission 7 (M7): where a first-timer stands to fight the shell's body (off the plaza's middle, in sight of it), how
## long the rail's fire is held for its charge, and the wait between two tries at it.
const BOSS_STAND_M := 9.0
const RAIL_HOLD_S := 0.6
const RAIL_GAP_S := 2.0
const DODGE_M := 9.0

var _rng := RandomNumberGenerator.new()
var _main: Node = null
var _runner: MissionRunner = null
var _player: Node3D = null
var _world: RuinsWorld = null
var _grid := {}
var _path: Array[Vector3] = []
var _path_to := Vector3.INF
var _path_turn := 0
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
var _mission := 1
## Mission 4's (M4): whether the decoy has been thrown at a hunter this try (the pick's advice, once), and chmod 000's reach.
var _decoyed := false
var _chmod_reach := 0.0
## How long the beam has been held, and how long it has rested (M4): chmod 000's tank runs 4 s and refills only let go,
## so a first-timer pulses it: BEAM_HOLD_S on, BEAM_REST_S off.
const BEAM_HOLD_S := 2.6
const BEAM_REST_S := 2.0
var _beam_held := 0.0
var _beam_rest := 0.0
## The clock when the last mine was placed (M5), and how many were.
var _mine_at := -100.0
var _hup_at := -100.0
var _sink_at := -100.0
var _stop_at := -100.0
var _mines := 0
var _last_move := Vector2.ZERO
var _rail_held := 0.0
var _rail_at := -100.0
var _rails := 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	root.size = Vector2i(1280, 720)
	_rng.seed = 37
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_rng.seed = int(arg.trim_prefix("--seed="))
		if arg.begins_with("--mission="):
			_mission = int(arg.trim_prefix("--mission="))
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
	MissionRunner.of(_main).begin(MissionBook.at(_mission))
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
			var frozen: String = str((_target as IcePiece).chmod_frozen()) if _target is IcePiece else "-"
			var against := "-"
			for k in _player.get_slide_collision_count():
				var hit: KinematicCollision3D = _player.get_slide_collision(k)
				if absf(hit.get_normal().y) < 0.5:
					against = "%s n%s" % [str(hit.get_collider().name) if hit.get_collider() != null else "?", str(hit.get_normal().snapped(Vector3.ONE * 0.1))]
			var heading := "-"
			if not _path.is_empty():
				var eye: Vector3 = _player.eye_position()
				var to: Vector3 = Vector3(_path[0].x, eye.y, _path[0].z) - eye
				heading = "yaw %.2f want %.2f pitch %.2f" % [_player.rotation.y, atan2(-to.x, -to.z), _player.get_node("Head").rotation.x]
			print("pace: trace %.0f s: against %s, %s, next %s, move %s: at %s, goal %s, %d waypoints, threat %s (frozen %s, health %s), weapon %d, pause %.1f, standing %d, health %.0f" % [_runner.clock, against, heading, str(_path[0].snapped(Vector3.ONE * 0.1)) if not _path.is_empty() else "-", str(_last_move), str(_player.global_position.snapped(Vector3.ONE * 0.1)), str(goal.snapped(Vector3.ONE * 0.1)), _path.size(), str(_target.global_position.snapped(Vector3.ONE * 0.1)) if _target != null else "-", frozen, str(_target.health()) if _target != null else "-", _player.inventory.current, _pause, _runner.stage.standing().size() if _runner.stage != null else 0, _runner.life.combat.health_of(SoloLife.ME) if _runner.life != null else -1.0])
	var done := _runner.state == MissionRunner.State.COMPLETE
	if _runner.stage != null and (_runner.stage.loop_running or _runner.stage.loop_broken_now):
		print("pace: the loop made %d passes and forked %d; the cache %.0f%% full when it broke" % [_runner.stage.passes, _runner.stage.forks_made.size(), _runner.stage.cache * 100.0])
	if _rails > 0:
		print("pace: %d rail shots at the shell's body" % _rails)
	print("pace: %s after %.1f game seconds (%.2f minutes) from the first card; its clear %.1f s of its clock (try %d), %d deaths, %d kills in the clear, %d of %d logs; %.0f damage taken in all, its health down to %.0f at worst" % ["DONE" if done else "GAVE UP", _clock - started, (_clock - started) / 60.0, _runner.clock, _runner.attempt, _deaths, _runner.kills, _runner.logs_found.size(), _runner.def.logs.size(), _hurt, _lowest])
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
	_decoyed = false
	var chmod_def = load("res://resources/chmod_000.tres")
	_chmod_reach = float(chmod_def.fire_range) if chmod_def != null else 10.0
	# The logs no objective asks for: a first-timer finds them by walking past (M2: any mission's, where C37 named login's).
	_side_logs = []
	for entry in _runner.def.logs:
		var asked := false
		for o in _runner.def.objectives:
			asked = asked or (o.get("kind") == "log" and o.get("log") == entry["id"])
		if not asked:
			_side_logs.append(entry["id"])
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
	var o := _runner.objective()
	# Mission 5 (M5): Z for root as the beat that teaches it says, and at the root door with a charge held.
	var sudo = _player.get("sudo")
	if sudo != null and sudo.state != null and sudo.charges() >= 1 and not sudo.is_root() and _player.ability_ok("sudo") and _pause <= 0.0:
		var door_at: Vector3 = _world.point("room_door")
		var at_door: bool = o.get("kind") == "reach" and door_at.is_finite() and Vector2(door_at.x - _player.global_position.x, door_at.z - _player.global_position.z).length() < DOOR_M
		if o.get("kind") == "root" or at_door:
			sudo.press()
			print("pace: Z (sudo) at %.1f s of its clock, for %s" % [_runner.clock, "root" if o.get("kind") == "root" else "the door"])
	# Black ICE out (M6): never shot, kept at arm's length, the world stopped as it comes near, the goal walked to meanwhile.
	var black := _black_near()
	var throwing := _throw_step(o, dt)
	if black != null:
		var flat := Vector2(black.global_position.x - _player.global_position.x, black.global_position.z - _player.global_position.z)
		var sigstop = _player.get("sigstop")
		if sigstop != null and not sigstop.is_on() and _player.ability_ok("sigstop") and _clock - _stop_at > STOP_GAP_S and flat.length() < BLACK_NEAR_M:
			sigstop.press()
			_stop_at = _clock
			print("pace: F (SIGSTOP) with Black ICE %.1f m off, at %.1f s of its clock" % [flat.length(), _runner.clock])
		if flat.length() < BLACK_NEAR_M:
			# Near: a first-timer who read the hint runs for the beat's goal and shoots nothing; where the way runs into
			# it, a sidestep away first.
			var goal := _goal()
			var step := _walk_to(goal, dt) if goal.is_finite() else Vector2.ZERO
			var basis := _player.global_transform.basis
			var to_black := Vector3(flat.x, 0, flat.y).normalized()
			var ahead := -basis.z
			if flat.length() < BLACK_FLEE_M and ahead.dot(to_black) > 0.2:
				var side := Vector3(-to_black.z, 0, to_black.x) * float(_seed_side())
				var away := (side - to_black * 0.6).normalized()
				step = Vector2(away.dot(basis.x), away.dot(basis.z))
			_last_move = step
			_player.drive_input(step, false, false, false)
			return
	var bossing := _boss_step(o, dt)
	var dodge := _dodge_step()
	if not throwing.is_empty():
		move = throwing[0]
		fire = throwing[1]
	elif not bossing.is_empty():
		move = bossing[0]
		fire = bossing[1]
	elif threat != null:
		if threat != _target:
			_target = threat
			_seen_at = _clock
			_aim_off = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.6, 0.6)) * AIM_ERROR
		# A first-timer's hand never settles: its aim wanders round the mark (a random walk, pulled back gently).
		_aim_off += Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)) * WOBBLE * dt
		_aim_off = (_aim_off * (1.0 - PULL * dt)).limit_length(AIM_ERROR * 1.6)
		_arm_for(threat)
		var breakers := BreakerDirector.of(_main)
		var has_brute: bool = threat is IceBarrier and breakers != null and breakers.mine.count(Breakers.Kind.BRUTE) > 0
		if has_brute:
			# A deny rule's wall (M4), a brute carried: up to it, Y until brute is loaded, U up close.
			var wall_at: Vector3 = threat.global_position
			var flat := Vector2(wall_at.x - _player.global_position.x, wall_at.z - _player.global_position.z)
			if flat.length() > BRUTE_M:
				var back := Vector3(-flat.x, 0, -flat.y).normalized() * 1.1
				move = _walk_to(Vector3(wall_at.x, _player.global_position.y, wall_at.z) + back, dt)
			elif breakers.mine.loaded != Breakers.Kind.BRUTE:
				breakers.press_cycle()
			elif _turn_to(_point_of(threat), dt) < 0.3:
				breakers.press_run()
		elif threat is HunterIce and not _decoyed and breakers != null and breakers.mine.count(Breakers.Kind.DECOY) > 0 and _clock - _seen_at >= REACT_S:
			# The hunter (M4): the pick says decoy once it has adapted: Y to the decoy, U throws it its way, once a try.
			if breakers.mine.loaded != Breakers.Kind.DECOY:
				breakers.press_cycle()
			elif _turn_to(_point_of(threat), dt) < 0.3:
				breakers.press_run()
				_decoyed = true
		else:
			var beam: bool = _player.inventory.current == int(_player.inventory.slot_of("chmod_000"))
			if beam:
				_aim_off *= 0.6  # a beam is tracked, not snapped at (M4): the hand steadies on it
			if _clock - _seen_at >= REACT_S:
				var err := _turn_to(_point_of(threat), dt)
				fire = err < (FIRE_ERROR * 2.5 if beam else FIRE_ERROR)
			var inv = _player.inventory
			if not beam and inv.mags[inv.current] == 0 and inv.def().has_magazine() and not inv.is_reloading() and not inv.is_swapping():
				_player.reload_weapon()  # an empty magazine reloaded (M4: SIGTERM's six shells), E as the strip says
				fire = false
			if beam:
				# The beam pulsed (M4): held BEAM_HOLD_S at most, then let go BEAM_REST_S so its tank refills.
				if _beam_rest > 0.0:
					_beam_rest -= dt
					fire = false
				elif fire:
					_beam_held += dt
					if _beam_held >= BEAM_HOLD_S:
						_beam_held = 0.0
						_beam_rest = BEAM_REST_S
						fire = false
				else:
					_beam_held = maxf(_beam_held - dt, 0.0)
			else:
				_beam_held = 0.0
			var gap: float = threat.global_position.distance_to(_player.global_position)
			var charging: bool = MissionRunner.kind_of(threat) == "zombie" and threat.has_method("art_node") and threat.art_node() != null and threat.art_node().elite and threat.brain != null and (threat.brain.state_name() == "tell" or threat.brain.state_name() == "strike") and gap < 9.0
			if charging:
				# A zombie elite charging (M5): a first-timer who saw it come once sidesteps, as a player would.
				move = Vector2(1.0 if _seed_side() > 0 else -1.0, 0.0)
			elif _player.inventory.current == int(_player.inventory.slot_of("rm_rf_cannon")):
				# rm -rf drawn (M5): fired from its band only; nearer it removes you too, as the hint says.
				if gap < RM_BAND.x:
					move = Vector2(0, 1)
					fire = false
				elif gap > RM_BAND.y:
					move = Vector2(0, -1)
					fire = false
			elif threat is HunterIce and _player.inventory.current == int(_player.inventory.slot_of("chmod_000")) and gap > _chmod_reach - 1.0:
				move = Vector2(0, -1)  # chmod 000 drawn and the hunter out of its reach (M4): close in, the beam held
			elif not (threat is IceBarrier) and gap < BACK_M:
				move = Vector2(0, 1)  # back up, or it opens you
	else:
		_target = null
		var mining := _mine_step(o, dt)
		if not mining.is_empty():
			move = mining[0]
			fire = mining[1]
		elif _pause > 0.0:
			_pause -= dt
		else:
			var goal := _goal()
			if goal.is_finite():
				move = _walk_to(goal, dt)
	if dodge != Vector2.ZERO:
		move = dodge  # a bolt coming (M7): a first-timer who saw it sidesteps, whatever else it was doing
	_last_move = move
	_player.drive_input(move, false, false, fire)


## A sidestep out of a bolt's way (M7, the shell's volleys; a zombie's too): the nearest live bolt within DODGE_M flying
## at the player, stepped across its line to the seed's side; ZERO with none coming.
func _dodge_step() -> Vector2:
	var director := DaemonDirector.of(_main)
	if director == null:
		return Vector2.ZERO
	var me: Vector3 = _player.global_position + Vector3.UP * 0.9
	for bolt in director.bolts():
		if not bolt.live:
			continue
		var to := me - bolt.global_position
		if to.length() > DODGE_M or bolt.velocity.length() < 0.1:
			continue
		var way := bolt.velocity.normalized()
		if way.dot(to.normalized()) < 0.9:
			continue
		var across := Vector3(-way.z, 0.0, way.x) * float(_seed_side())
		var basis := _player.global_transform.basis
		return Vector2(across.dot(basis.x), across.dot(basis.z)).normalized()
	return Vector2.ZERO


## Black ICE hunting now (M6), or null: the ICE director's, present.
func _black_near() -> Node3D:
	var ice := IceDirector.of(_main)
	if ice == null or ice.black == null or not is_instance_valid(ice.black) or not ice.black.present_now():
		return null
	return ice.black


## Mission 6 (M6): the beats that throw. SIGHUP at the nearest watcher the hup beat counts once it is within HUP_M and in
## sight (one throw every HUP_GAP_S); /dev/null into the crowd on the beat that hands it over, at the middle of the three
## nearest once that middle is in SINK_BAND; SIGHUP at the shell's screen on the hangup beat from SHELL_M. [move, fire]
## while it is doing one, else [].
func _throw_step(o: Dictionary, dt: float) -> Array:
	var kind := str(o.get("kind", ""))
	if kind == "hup" and o.has("prop"):
		if not _runner.carried.has("sighup"):
			return []
		var shell: Vector3 = _world.point("shell")
		var screen: Dictionary = _world.shell_screen()
		if not shell.is_finite() or screen.is_empty():
			return []
		var flat := Vector2(shell.x - _player.global_position.x, shell.z - _player.global_position.z)
		if flat.length() > 1.2:
			return [_walk_to(shell, dt), false]
		var at: Vector3 = (screen["at"] as Vector3) + (screen["out"] as Vector3) * 0.3 + Vector3(0, 2.2, 0)
		return _throw_at("sighup", at, dt, HUP_GAP_S)
	if kind == "hup":
		if not _runner.carried.has("sighup") or _runner.stage == null:
			return []
		var of: Array = o.get("of", [])
		var best: Node3D = null
		var best_d := INF
		for d in _runner.stage.standing():
			if not d.is_alive() or (not of.is_empty() and not of.has(str(d.get_meta(&"wave", "")))):
				continue
			if d.has_method("confused") and d.brain != null and d.brain.confused():
				continue
			var dist: float = d.global_position.distance_to(_player.global_position)
			if dist < best_d and _clear(_player.eye_position(), _point_of(d)):
				best = d
				best_d = dist
		if best == null:
			return []
		if best_d > HUP_M:
			return [_walk_to(best.global_position, dt), false]
		return _throw_at("sighup", _point_of(best), dt, HUP_GAP_S)
	if kind == "kill" and o.get("arms", []).has("dev_null") and _runner.carried.has("dev_null") and _runner.stage != null and _clock - _sink_at > SINK_GAP_S:
		var of: Array = o.get("of", [])
		var near: Array = []
		for d in _runner.stage.standing():
			if d.is_alive() and (of.is_empty() or of.has(str(d.get_meta(&"wave", "")))) and _clear(_player.eye_position(), _point_of(d)):
				near.append(d)
		if near.size() < 2:
			return []
		near.sort_custom(func(a, b): return a.global_position.distance_to(_player.global_position) < b.global_position.distance_to(_player.global_position))
		var middle := Vector3.ZERO
		var n := mini(near.size(), 3)
		for i in n:
			middle += near[i].global_position
		middle /= float(n)
		var gap := Vector2(middle.x - _player.global_position.x, middle.z - _player.global_position.z).length()
		if gap < SINK_BAND.x:
			return [Vector2(0, 1), false]  # back off first: the hole takes the thrower's own too near
		if gap > SINK_BAND.y:
			return []
		var out := _throw_at("dev_null", middle + Vector3(0, 0.9, 0), dt, SINK_GAP_S)
		if out[1]:
			_sink_at = _clock
			print("pace: /dev/null into %d of the crowd, %.1f m off, at %.1f s of its clock" % [n, gap, _runner.clock])
		return out
	return []


## Mission 7 (M7): the beats at the shell's body. SIGTERM sent at it on the beat that asks for it (one shot); on a rail
## beat, or the kill, the rail drawn and fired at its heart once the meter is full (its charge held RAIL_HOLD_S), else
## the fight goes on round it (the sheds and the ICE shot as any threat, filling the meter). [move, fire] while it is
## doing one of those, else [].
func _boss_step(o: Dictionary, dt: float) -> Array:
	if _runner.stage == null or _runner.stage.boss == null or not is_instance_valid(_runner.stage.boss) or not _runner.stage.boss.is_alive():
		return []
	var boss: Node3D = _runner.stage.boss
	var kind := str(o.get("kind", ""))
	var weapon := str(o.get("weapon", ""))
	var at: Vector3 = boss.threat_point()
	if kind == "hit" and weapon == "sigterm":
		if not _clear(_player.eye_position(), at):
			return []
		var slot := int(_player.inventory.slot_of("sigterm"))
		if _player.inventory.current != slot:
			_player.select_slot(slot)
			return [Vector2.ZERO, false]
		if _player.inventory.is_swapping() or _turn_to(at, dt) > 0.12:
			return [Vector2.ZERO, false]
		print("pace: SIGTERM sent at the shell at %.1f s of its clock" % _runner.clock)
		return [Vector2.ZERO, true]
	if not ((kind == "hit" and weapon == "sigkill_rail") or (kind == "kill" and o.get("daemon") == "shell")):
		return []
	if not _player.inventory.meter_ready() or _clock - _rail_at < RAIL_GAP_S:
		return []
	if not _clear(_player.eye_position(), at):
		return []
	var slot := int(_player.inventory.slot_of("sigkill_rail"))
	if _player.inventory.current != slot:
		_player.select_slot(slot)
		return [Vector2.ZERO, false]
	if _player.inventory.is_swapping():
		return [Vector2.ZERO, false]
	_aim_off *= 0.5  # the one shot that matters: the hand steadies
	if _turn_to(at, dt) > 0.06 and _rail_held <= 0.0:
		return [Vector2.ZERO, false]
	_rail_held += dt
	if _rail_held >= RAIL_HOLD_S:
		_rail_held = 0.0
		_rail_at = _clock
		_rails += 1
		print("pace: kill -9 at the shell's heart at %.1f s of its clock (rail %d, health %.0f)" % [_runner.clock, _rails, boss.health()])
		return [Vector2.ZERO, false]
	return [Vector2.ZERO, true]


## Weapon `weapon` drawn and thrown at `at`, no two throws closer than `gap_s` (the last throw's time kept in _hup_at for
## SIGHUP): [move, fire].
func _throw_at(weapon: String, at: Vector3, dt: float, gap_s: float) -> Array:
	var slot := int(_player.inventory.slot_of(weapon))
	if _player.inventory.current != slot:
		_player.select_slot(slot)
		return [Vector2.ZERO, false]
	if _player.inventory.is_swapping():
		return [Vector2.ZERO, false]
	if weapon == "sighup" and _clock - _hup_at < gap_s:
		return [Vector2.ZERO, false]
	if _turn_to(at, dt) > 0.25:
		return [Vector2.ZERO, false]
	if weapon == "sighup":
		_hup_at = _clock
		print("pace: SIGHUP thrown at %.1f s of its clock" % _runner.clock)
	return [Vector2.ZERO, true]


## Mission 5 (M5): on the beat that hands cron over, a first-timer who read the hint walks to the job's vent and places a
## mine on it before the job runs (one every MINE_GAP_S), then stands back for the goal as usual. [move, fire] while it
## is doing that, else [].
func _mine_step(o: Dictionary, dt: float) -> Array:
	if not o.get("arms", []).has("cron_mines") or not _runner.carried.has("cron_mines") or _clock - _mine_at < MINE_GAP_S:
		return []
	var vent := _job_vent(o)
	if not vent.is_finite():
		return []
	var flat := Vector2(vent.x - _player.global_position.x, vent.z - _player.global_position.z)
	if flat.length() > MINE_M + 0.6:
		return [_walk_to(Vector3(vent.x, _player.global_position.y, vent.z), dt), false]
	var slot := int(_player.inventory.slot_of("cron_mines"))
	if _player.inventory.current != slot:
		_player.select_slot(slot)
		return [Vector2.ZERO, false]
	if _player.inventory.is_swapping():
		return [Vector2.ZERO, false]
	if _turn_to(vent, dt) > 0.25:
		return [Vector2.ZERO, false]
	_mine_at = _clock
	_mines += 1
	print("pace: a mine on the job's vent at %.1f s of its clock (%d)" % [_runner.clock, _mines])
	return [Vector2.ZERO, true]


## Which way it sidesteps (M5): its seed's, the same all run.
func _seed_side() -> int:
	return 1 if int(_rng.seed) % 2 == 0 else -1


## The vent the beat's job climbs out of (M5): the first vent of the first wave the objective counts.
func _job_vent(o: Dictionary) -> Vector3:
	var of: Array = o.get("of", [])
	if of.is_empty() or _runner.stage == null:
		return Vector3.INF
	for w in _runner.def.waves:
		if str(w.get("id", "")) == str(of[0]):
			var from: Array = w.get("from", [])
			if not from.is_empty():
				var vent = _runner.stage.vent(str(from[0]))
				if vent != null:
					return vent.global_position
	return Vector3.INF


## The weapon a first-timer who read the hints draws for `threat` (M3): pipe | against a runaway once it is in hand, (M4)
## chmod 000 against a hunter not yet frozen once it is in hand, the cannon against anything else; one a node's field has
## jammed (M4) swapped for the next carried, as the HUD says to.
func _arm_for(threat: Node3D) -> void:
	if _player.inventory.is_reloading():
		return  # a reload finished before any swap (M4): a swap would throw it away
	var want := "terminal_cannon"
	var o := _runner.objective()
	var gap: float = threat.global_position.distance_to(_player.global_position)
	if o.get("arms", []).has("rm_rf_cannon") and _runner.carried.has("rm_rf_cannon") and o.get("of", []).has(str(threat.get_meta(&"wave", ""))) and gap >= RM_BAND.x:
		want = "rm_rf_cannon"  # the beat that teaches rm -rf (M5): on what it counts, from the band; nearer, the cannon
	elif MissionRunner.kind_of(threat) == "swarm" and _runner.carried.has("pipe_chain"):
		want = "pipe_chain"
	elif threat is HunterIce and _runner.carried.has("chmod_000") and not (threat as HunterIce).chmod_frozen():
		want = "chmod_000"
	elif threat is HunterIce and _runner.carried.has("sigterm"):
		want = "sigterm"  # frozen (M4): every pellet lands doubled, as the hint says: hit it hard
	var jams: Dictionary = _player.ice_jams()  # slot -> seconds left
	if jams.has(int(_player.inventory.slot_of(want))):
		for other in ["sigterm", "fork_shotgun", "terminal_cannon", "sigkill_rail"]:
			if _runner.carried.has(other) and not jams.has(int(_player.inventory.slot_of(other))):
				want = other
				break
	var slot := int(_player.inventory.slot_of(want))
	if _player.inventory.current != slot:
		_player.select_slot(slot)


## Where to aim at `d`: a daemon's threat point, a piece of ICE's aim point (M4).
func _point_of(d: Node3D) -> Vector3:
	return d.threat_point() if d.has_method("threat_point") else d.aim_point()


## The nearest standing daemon it can see within ENGAGE_M, or null.
func _threat() -> Node3D:
	if _runner.stage == null:
		return null
	var eye: Vector3 = _player.eye_position()
	var best: Node3D = null
	var best_d := ENGAGE_M
	var of: Array = _runner.objective().get("of", [])
	for d in _runner.stage.standing():
		if not d.is_alive() or (not (d is IcePiece) and d.sealed):
			continue  # a sealed one (M2) takes nothing: a first-timer stops wasting shots on it
		if d is BlackIce:
			continue  # never shot (M6): weapons only flash it; the hint says run
		if _runner.stage != null and d == _runner.stage.boss:
			continue  # the shell's body (M7): only the rail reaches it, and _boss_step() aims that
		var at: Vector3 = _point_of(d)
		var dist := eye.distance_to(at)
		if d is IceBarrier:
			# A deny rule's wall (M4): a threat only as this beat's, or standing in the way a few metres ahead.
			if not of.has(str(d.get_meta(&"wave", ""))) and dist > WALL_NEAR_M:
				continue
		elif not _clear(eye, at):
			continue
		if dist < best_d:
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
	if o.get("kind") != "survive":
		# A terminal glowing near the way (M2): walked through and read, as a first-timer would.
		for id in _side_logs:
			var p := _runner.pickup(id)
			if p != null and p.global_position.distance_to(_player.global_position) <= SIDE_LOG_M:
				return p.global_position
	# A brute pickup out and none carried (M4), with a deny rule's wall to break: a first-timer goes for the pickup.
	var breakers := BreakerDirector.of(_main)
	if breakers != null and breakers.staged and breakers.mine.count(Breakers.Kind.BRUTE) == 0 and (o.get("daemon") == "wall" or o.get("kind") == "reach"):
		for spot in breakers.pickups_out():
			if breakers.pickups_out()[spot] == Breakers.Kind.BRUTE and breakers.pickups[spot] != null and is_instance_valid(breakers.pickups[spot]):
				return breakers.pickups[spot].global_position
	if _runner.stage != null and _runner.stage.boss != null and is_instance_valid(_runner.stage.boss) and (o.get("kind") == "hit" or (o.get("kind") == "kill" and o.get("daemon") == "shell")):
		# The shell's body (M7): a first-timer stands off the plaza's middle, in sight of it, and lets it come round.
		var boss: Node3D = _runner.stage.boss
		var plaza: Vector3 = _world.point("plaza")
		var away := Vector3(_player.global_position.x - plaza.x, 0.0, _player.global_position.z - plaza.z)
		if away.length() < 0.5:
			away = Vector3(1, 0, 0)
		return Vector3(plaza.x, _player.global_position.y, plaza.z) + away.normalized() * BOSS_STAND_M
	match o.get("kind"):
		"reach":
			if o.get("id") == "drop" or o.get("at") == "below":
				return _world.point("breach")  # the pocket is reached by falling (C37, M6): stand on the hatch
			return _runner.reach_place(_runner.index)
		"hup":
			if o.has("prop"):
				return _world.point("shell")
			var of: Array = o.get("of", [])
			var best: Node3D = null
			for d in (_runner.stage.standing() if _runner.stage != null else []):
				if not d.is_alive() or (not of.is_empty() and not of.has(str(d.get_meta(&"wave", "")))):
					continue
				if best == null or d.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position):
					best = d
			return best.global_position if best != null else Vector3.INF
		"log":
			return _runner.log_place(str(o["log"]))
		"kill":
			# The nearest it counts, else the nearest standing (M2: a sleeper it walks up to wakes, as a player's would).
			var standing: Array = _runner.stage.standing() if _runner.stage != null else []
			var of: Array = o.get("of", [])
			var best: Node3D = null
			for d in standing:
				if (not (d is IcePiece) and d.sealed) or (not of.is_empty() and not of.has(str(d.get_meta(&"wave", "")))):
					continue
				if best == null or d.global_position.distance_to(_player.global_position) < best.global_position.distance_to(_player.global_position):
					best = d
			if best == null and not standing.is_empty():
				best = standing[0]
			return best.global_position if best != null else Vector3.INF
		"survive":
			# Looking round the start as the timeslice runs: the log tucked by the start is found on the way.
			for id in _side_logs:
				var p := _runner.pickup(id)
				if p != null:
					return p.global_position
			return Vector3.INF
	return Vector3.INF


## A step along the shortest way to `goal` on the walk grid: the view turned toward the next waypoint, forward.
func _walk_to(goal: Vector3, dt: float) -> Vector2:
	var turn := _world.field().turn if _world.field() != null else 0
	if _path.is_empty() or _path_to.distance_to(goal) > 1.0 or turn != _path_turn:
		_path = _route(_player.global_position, goal)
		_path_to = goal
		_path_turn = turn  # M3: the field rewritten, the way worked out again
	var gap := func(p: Vector3) -> float: return Vector2(p.x - _player.global_position.x, p.z - _player.global_position.z).length()
	while not _path.is_empty() and gap.call(_path[0]) < WAYPOINT_M:
		_path.pop_front()
	while _path.size() > 1 and gap.call(_path[1]) <= gap.call(_path[0]):
		_path.pop_front()  # the first waypoint is behind it (M4: a corner cut on the way never leaves it standing on the second)
	var next: Vector3 = goal if _path.is_empty() else _path[0]
	if _path.size() > 1 and gap.call(next) < LOOK_AHEAD_M:
		next = _path[1]  # looking a step ahead, as a walker does
	var flat := Vector2(next.x - _player.global_position.x, next.z - _player.global_position.z)
	if flat.length() < 0.2:
		if not _path.is_empty():
			_path.pop_front()
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


## The walk grid's shortest way from `from` to `to` (breadth first), as waypoints in world space; in a district with a
## cache field (M3), the A* grid's as its walls stand now.
func _route(from: Vector3, to: Vector3) -> Array[Vector3]:
	if _world.field() != null:
		var live: Array[Vector3] = []
		for p in _world.walk_route(from, to):
			live.append(p)
		return live
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
