class_name HunterBrain
extends DaemonBrain
## Hunter ICE's brain (I1): the daemons' brain (scripts/fight/daemon_brain.gd, C27b) with the hunter's
## own numbers and its own attack, stepped by the ICE director with the daemons' director as its
## world (who the intruders are, where, whether they can be attacked, SIGSTOP, sight against the
## level, the attacker cap it shares with the daemons, and the combat path its damage lands through).
##
## It hunts by sight as a daemon does, but it is a hunter: it sees farther (hunter_aggro_m), has no
## leash (it hunts the whole arena, going back to its post only when it has lost every intruder for
## hunter_lose_s), and keeps its distance (hunter_keep_m), hovering. Its attack is the lance: within
## hunter_range_m, in sight, attackable and under the cap, it tells (hunter_tell_s, never under a
## second): its shields close round its nose and its trace reaches to its prey, following it, until
## the tell's last hunter_lock_s, when the trace holds still where it last aimed and flashes. At the
## tell's end, with the prey still attackable and in sight, the lance fires along the held line as far
## as hunter_reach_m or the first piece of the level: a prey within hunter_lance_radius_m of that line
## takes hunter_damage (the difficulty's scale on it). A player who stepped aside in the lock is
## missed. Then it recovers and waits hunter_cooldown_s (shortened by the difficulty's aggression).
## A ping meeting it mid-tell staggers it, as it does a daemon (C28).
##
## On a joiner it plays the host's word (follow()), its aim with it (take_aim()), so every screen
## draws the trace and the lance where the host's hunter aimed.
##
## ICEbreakers (I2): a cloaked intruder is unseen (it goes on to where it last saw it, home after
## hunter_lose_s); a decoy calling within the breakers' pull, anywhere in the arena (no leash), takes it
## off whatever it hunts, even in the middle of its tell: the trace swings to the decoy (unless it has
## locked), and the lance at the tell's end is judged on the decoy, never on the intruder it left.

var ice: IceTuning
## Where its lance aims (world space, a unit vector) and how far it reached, the line's end.
var aim := Vector3.FORWARD
var lance_from := Vector3.ZERO
var lance_to := Vector3.ZERO
## Lances fired and those that met their prey, for the checks.
var lances := 0
var lance_hits := 0


func _init(owner: Node3D, daemon_art: DaemonArt, tuning: IceTuning) -> void:
	super(owner, daemon_art)
	kind = "hunter"
	ice = tuning


## Where its lance leaves: its heart, at its nose.
func muzzle() -> Vector3:
	var at: Vector3 = art.muzzle() if art != null and art.is_inside_tree() else Vector3.INF
	var middle := dummy.global_position + Vector3.UP * ice.hunter_hover_m
	return at if at.is_finite() and at.distance_to(middle) < 2.5 else middle


## The host's aim for a joiner's copy (world space).
func take_aim(way: Vector3) -> void:
	if way.length_squared() > 0.0001:
		aim = way.normalized()


func _speed(_d) -> float:
	return ice.hunter_speed


func _tell_s(_d) -> float:
	return ice.hunter_tell_s


func _strike_s(_d) -> float:
	return ice.hunter_strike_s


func _recover_s(_d) -> float:
	return ice.hunter_recover_s


func _eye(_d) -> Vector3:
	return dummy.global_position + Vector3.UP * ice.hunter_hover_m


func _in_range(target: Vector3, _d) -> bool:
	return _flat(target - dummy.global_position).length() <= ice.hunter_range_m


func _in_reach(target: Vector3, _d) -> bool:
	return muzzle().distance_to(target) <= ice.hunter_reach_m


## No leash: it never turns back for being far from its post.
func _from_home() -> float:
	return 0.0


func _hunt_goal(target: Vector3, _delta: float, _d) -> Vector3:
	var here := dummy.global_position
	var way := _flat(target - here)
	if way.length() <= ice.hunter_keep_m:
		return here
	var goal := target - way.normalized() * ice.hunter_keep_m
	goal.y = here.y
	return goal


## The nearest intruder in sight within its aggro range, anywhere in the arena; 0 for none.
func _spot(d) -> int:
	var best := 0
	var best_d := INF
	for id in d.prey_ids():
		if not d.prey_valid(id) or d.prey_hidden(id):
			continue
		var at: Vector3 = d.prey_point(id)
		var gap := _eye(d).distance_to(at)
		if gap > ice.hunter_aggro_m or gap >= best_d or not _sees(at, d):
			continue
		best = id
		best_d = gap
	return best


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
	if unseen_t > ice.hunter_lose_s:
		_go_home()
		return
	var chase: Vector3 = target if sees or heard else last_seen
	if not chase.is_finite():
		velocity = Vector3.ZERO
		return
	_walk(_hunt_goal(chase, delta, d) if sees or heard else chase, _speed(d), delta, d)
	_face(target if sees or heard else chase, delta, d)
	if sees and cooldown <= 0.0 and _in_range(target, d) and d.prey_attackable(prey) and d.take_slot(self, prey):
		holds_slot = true
		burst_left = 0
		_aim_at(target)
		_tell()


func _step_tell(delta: float, d) -> void:
	var tell_s := _tell_s(d)
	art.drive(DaemonArt.Act.TELL, state_t / tell_s)
	velocity = Vector3.ZERO
	var target: Vector3 = d.prey_point(prey) if d.prey_valid(prey) and not d.prey_hidden(prey) else Vector3.INF
	# The trace follows its prey until the lock, then holds still where it last aimed.
	if target.is_finite() and state_t < tell_s - ice.hunter_lock_s:
		_face(target, delta, d)
		_aim_at(target)
	if state_t < tell_s:
		return
	if target.is_finite() and d.prey_attackable(prey) and _sees(target, d) and _in_reach(target, d):
		_strike(target, d)
	else:
		_note("abort")
		_enter(State.RECOVER)


## The lance, along the held aim: as far as its reach or the first piece of the level; the prey is
## struck when its middle is within the lance's radius of the line and nothing of the level is
## between the muzzle and it.
func _strike(_target: Vector3, d) -> void:
	attacks += 1
	lances += 1
	_note("attack")
	_enter(State.STRIKE)
	lance_from = muzzle()
	lance_to = lance_from + aim * ice.hunter_reach_m
	var blocked: Dictionary = d.cast(lance_from, lance_to)
	if not blocked.is_empty():
		lance_to = blocked["position"]
	if not d.prey_valid(prey) or not d.prey_attackable(prey):
		_note("miss")
		return
	var at: Vector3 = d.prey_point(prey)
	var along := clampf((at - lance_from).dot(aim), 0.0, lance_from.distance_to(lance_to))
	var nearest := lance_from + aim * along
	if at.distance_to(nearest) <= ice.hunter_lance_radius_m and d.clear(lance_from, at):
		if d.hurt(prey, ice.hunter_damage, self, aim):
			landed += 1
			lance_hits += 1
			_note("hit")
			return
	_note("miss")


func _step_strike(_delta: float, d) -> void:
	art.drive(DaemonArt.Act.STRIKE, state_t / _strike_s(d))
	velocity = Vector3.ZERO
	if state_t >= _strike_s(d):
		_enter(State.RECOVER)


func _step_recover(_delta: float, d) -> void:
	art.drive(DaemonArt.Act.RECOVER, state_t / maxf(_recover_s(d), 0.001))
	velocity = Vector3.ZERO
	if state_t < _recover_s(d):
		return
	burst_left = 0
	_release(d)
	cooldown = _attack_wait(d)
	_enter(State.HUNT)


## Its lance's wait (a freeze, C29, waits it too).
func _attack_wait(d) -> float:
	return ice.hunter_cooldown_s / d.aggression()


## A decoy calls it (I2): hunting, at home or going home it hunts the decoy; in its tell it keeps the
## tell, its prey (and its slot) the decoy now, the trace swinging to it unless it has locked.
func _take_lure(lure: int, d) -> void:
	if state == State.TELL:
		_release(d)
		prey = lure
		last_seen = d.prey_point(lure)
		unseen_t = 0.0
		holds_slot = d.take_slot(self, lure)
		_note("lured")
		return
	super(lure, d)


## No leash: any decoy within the pull will do.
func lure_ok(at: Vector3, _d) -> bool:
	return at.is_finite()


func _aim_at(target: Vector3) -> void:
	var way := target - muzzle()
	if way.length_squared() > 0.0001:
		aim = way.normalized()
