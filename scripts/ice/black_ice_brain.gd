class_name BlackIceBrain
extends DaemonBrain
## Black ICE's brain (I3): the daemons' brain (scripts/fight/daemon_brain.gd, C27b) with Black ICE's own
## numbers and no attack of its own: it never tells and never strikes, because touching it is the
## attack (the ICE director judges every intruder's middle against its touch each step and flatlines one
## that comes too near). Stepped by the ICE director with the daemons' director as its world (who the
## intruders are, where, whether they can be attacked, SIGSTOP, sight against the level, the decoys).
##
## It hunts by sight as the hunter does, farther (sight_m) and with no leash, going straight at its prey
## at its speed, always slower than a running intruder; one it loses it follows to the place it was last
## seen and keeps for lose_s. With no one in sight it is never still for long: it drifts toward the
## nearest intruder it is not hidden from, slower still (drift_speed), so hiding buys time, never the
## round. A cloaked intruder (I2) is hidden from it as from the hunter: never seen, never drifted to. A
## decoy calling within the breakers' pull takes it off whatever it hunts (no leash: any decoy will do)
## and holds it there while it calls; what lands on a decoy from it only flashes it. A broken seal throws
## it back along the brute's charge (the scatter state, reel()): for reel_s it hunts nothing.
##
## On a joiner it plays the host's word (follow()), as a daemon's brain does.

var bt: BlackIceTuning
## The intruder it last drifted toward, for the checks.
var drifting_to := 0


func _init(owner: Node3D, daemon_art: DaemonArt, tuning: BlackIceTuning) -> void:
	super(owner, daemon_art)
	kind = "black"
	bt = tuning


func _speed(_d) -> float:
	return bt.speed


func _scatter_s(_d) -> float:
	return maxf(bt.reel_s, 0.001)


## Where it looks from: its core, high over the arena's low cover.
func _eye(_d) -> Vector3:
	return dummy.global_position + Vector3.UP * 2.6


## No leash: it never turns back for being far from where it came.
func _from_home() -> float:
	return 0.0


## Any decoy within the pull will do.
func lure_ok(at: Vector3, _d) -> bool:
	return at.is_finite()


## Straight at its prey: it wants the place the intruder stands.
func _hunt_goal(target: Vector3, _delta: float, _d) -> Vector3:
	var goal := target
	goal.y = dummy.global_position.y
	return goal


func _go_home() -> void:
	prey = 0
	last_seen = Vector3.INF
	_enter(State.HOME)


## A broken seal: thrown back from `from` (world space), hunting nothing for reel_s.
func reel(from: Vector3, d) -> void:
	_release(d)
	burst_left = 0
	_flee_from = from if from.is_finite() else dummy.global_position
	_note("reel")
	_enter(State.SCATTER)


## The nearest intruder in sight within sight_m, anywhere in the arena, never a cloaked one; 0 for none.
func _spot(d) -> int:
	var best := 0
	var best_d := INF
	for id in d.prey_ids():
		if not d.prey_valid(id) or d.prey_hidden(id):
			continue
		var at: Vector3 = d.prey_point(id)
		var gap := _eye(d).distance_to(at)
		if gap > bt.sight_m or gap >= best_d or not _sees(at, d):
			continue
		best = id
		best_d = gap
	return best


## The nearest intruder it is not hidden from, sight or none: where it drifts; 0 for none.
func _nearest(d) -> int:
	var best := 0
	var best_d := INF
	for id in d.prey_ids():
		if id <= 0 or not d.prey_valid(id) or d.prey_hidden(id):
			continue
		var gap := _flat(d.prey_point(id) - dummy.global_position).length()
		if gap < best_d:
			best = id
			best_d = gap
	return best


## No one in sight: it looks every step, and drifts toward the nearest intruder it is not hidden from.
func _step_home(delta: float, d) -> void:
	moved = true
	var spotted := _spot(d)
	if spotted != 0:
		drifting_to = 0
		_hunt(spotted, d.prey_point(spotted))
		return
	drifting_to = _nearest(d)
	if drifting_to == 0:
		velocity = Vector3.ZERO
		art.drive(DaemonArt.Act.IDLE)
		return
	art.drive(DaemonArt.Act.MOVE)
	var toward: Vector3 = d.prey_point(drifting_to)
	_walk(_hunt_goal(toward, delta, d), bt.drift_speed, delta, d)
	_face(toward, delta, d)


func _step_hunt(delta: float, d) -> void:
	art.drive(DaemonArt.Act.MOVE)
	if not d.prey_valid(prey):
		_go_home()
		return
	var target: Vector3 = d.prey_point(prey)
	var sees: bool = _sees(target, d) and not d.prey_hidden(prey)
	var heard: bool = d.is_decoy(prey)  # a decoy's call says where it is (I2)
	if sees or heard:
		last_seen = target
		unseen_t = 0.0
	else:
		unseen_t += delta
	if unseen_t > bt.lose_s:
		_go_home()
		return
	var chase: Vector3 = target if sees or heard else last_seen
	if not chase.is_finite():
		_go_home()
		return
	if not (sees or heard) and _flat(chase - dummy.global_position).length() < 0.6:
		_go_home()  # at the last place it saw it, and nothing there: it drifts on
		return
	_walk(_hunt_goal(chase, delta, d), _speed(d), delta, d)
	_face(chase, delta, d)


## The reel after a broken seal: thrown back from the charge over the first part of it, then still.
func _step_scatter(delta: float, d) -> void:
	art.drive(DaemonArt.Act.SCATTER, state_t / _scatter_s(d))
	velocity = Vector3.ZERO
	var away := dummy.global_position - _flee_from
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = dummy.global_transform.basis.z
	var throw_s := _scatter_s(d) * 0.6
	if state_t <= throw_s:
		_shove(away.normalized() * (bt.reel_m / throw_s) * delta, d)
	if state_t >= _scatter_s(d):
		if d.prey_valid(prey):
			_enter(State.HUNT)
		else:
			_go_home()


## Turns to face `point` at its own slow turn rate.
func _face(point: Vector3, delta: float, _d) -> void:
	var way := _flat(point - dummy.global_position)
	if way.length_squared() < 0.0004:
		return
	var want := atan2(-way.x, -way.z)
	dummy.global_rotation = Vector3(0.0, rotate_toward(dummy.global_rotation.y, want, bt.turn_rate * delta), 0.0)


## `step` from `from`, cut short or slid along the level so its wide body stays clear (a daemon's is
## RADIUS_M round; this one's most of its radius).
func _free_step(from: Vector3, step: Vector3, d) -> Vector3:
	var length := step.length()
	if length < 0.000001:
		return Vector3.ZERO
	var body := bt.radius_m * 0.8
	var way := step / length
	var hit: Dictionary = d.cast(from, from + way * (length + body))
	if hit.is_empty():
		return step
	var normal: Vector3 = hit["normal"]
	normal.y = 0.0
	normal = normal.normalized() if normal.length_squared() > 0.0001 else -way
	var slid := step - normal * step.dot(normal)
	slid.y = 0.0
	if slid.length() < 0.000001:
		return Vector3.ZERO
	var again: Dictionary = d.cast(from, from + slid.normalized() * (slid.length() + body))
	return slid if again.is_empty() else Vector3.ZERO
