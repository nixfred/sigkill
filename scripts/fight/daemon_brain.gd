class_name DaemonBrain
extends RefCounted
## A daemon's brain (C27b): what makes a target dummy fight back. One per dummy
## (scripts/target_dummy.gd makes it), stepped every physics frame by the arena's director
## (scripts/fight/daemon_director.gd), which says who can be hunted, keeps the attacker cap,
## knows SIGSTOP and lands the damage. The brain decides, moves the daemon and tells its art what
## it is doing (DaemonArt.drive()).
##
## It hunts by line of sight: at home it looks for the nearest player within aggro range with
## nothing of the level between its eye and the player's middle, and hunts it; it keeps the last
## place it saw it and goes there when sight is lost, gives up after lose_s unseen, and goes home
## when the hunt would take it past its leash. Being shot rouses it whatever the range.
##
## Every attack is a tell, then the strike, then a recovery, and nothing else starts an attack:
## the tell starts only with the prey in sight, in range, attackable (alive, not spawn-protected)
## and a slot under the director's attacker cap; the strike follows only if, at the tell's end, the
## prey is still in sight and in reach; otherwise the tell ends in a recovery with nothing thrown.
## The strike's damage is judged again where it lands: no slash, bolt or dive hurts through the
## level. rogue.d rears up (its tell), lunges along the way it faces and slashes where its
## scythes come down; the zombie raises its claw with the ember in it (its tell) and throws a
## slow amber bolt at where the player is (scripts/fight/glitch_bolt.gd, dodgeable, stopped by
## the level); the runaway swarm circles its prey, pulls in tight (its tell) and dives through
## where the player was, chipping it once a dive, a few dives a burst, each with its own tell; a
## hit scatters it, which ends any burst.
##
## Movement is steering, not a navigation mesh (decided in docs/DESIGN.md): straight at the goal,
## feelers either side of ahead to turn off a wall, a slide along a wall it meets, apart from the
## other daemons. Walkers keep to their spot's floor; the swarm flies at its spot's height and
## dives to the player's. SIGSTOP freezes it whole while its prey's SIGSTOP holds (alone: the
## player's): no step, no clock, no attack. In practice it walks home and stands, the old dummy.
## On a joiner it decides nothing: it plays the host's word (follow()).
##
## ping (C28): a ping's ring meeting it in the middle of its tell calls that attack off (pinged()):
## nothing is thrown, its slot goes, and it staggers, knocked a little back from the ping, before it
## hunts again after its attack's own wait. The stagger is the scatter state, the same word on the
## wire (the swarm's stagger is its scatter, a walker's its knock back), so a joiner draws it with no
## new message. A ping meeting it doing anything else changes nothing: it is no hit and rouses no one.
##
## ICEbreakers (I2): a cloaked player is unseen (the director's prey_hidden()): it is never spotted,
## a hunt on it falls back to where it was last seen (and home after lose_s), and a tell on it ends with
## nothing thrown. A decoy calling within the breakers' pull (the director's lure_for()) is taken as
## the prey instead of any player, at home, hunting or going home (never in the middle of an attack):
## it is known where it is without sight (it calls), and hunted and struck like a player.
##
## chmod 000 (C29): while its dummy is frozen by the freeze ray (the dummy's chmod_frozen()) it does
## nothing at all: no step, no turn, no attack, its clock and every timer held; a tell or a strike it was
## in is called off (nothing more is thrown, its slot goes, "frozen" noted) and once it thaws it hunts
## again after its attack's own wait, as a ping's stagger does. A bolt already thrown flies on. On a
## joiner its copy plays the host's word, frozen with it.
##
## /dev/null (C31): while a hole holds its dummy it does nothing of its own (the hole drags it); a tell or a
## strike it was in is called off, as a freeze calls one off, and once let go it hunts again after its
## attack's own wait or walks home from where it was left.
##
## SIGHUP (C32): a hangup burst catching it (hangup()) tells it its terminal hung up: a tell, a strike or a
## recovery it was in is called off, it drops its prey (it no longer knows where anyone is) and stalls for the
## tuning's reload_s, "reloading config" (posed as a recovery), then wanders confused for wander_s: a random
## walk in short legs at a share of its own speed, stopping between them to look round (its facing swept in
## snaps), its motion stuttering. Where the daemons fight, a confused one with another daemon near it in
## sight lashes at that one with its own attack (its tell first: the rogue's lunge and slash, the zombie's
## bolt, the swarm's dive), at a share of the damage, a few times a confusion: a crowd turns on itself a
## little. Then it is itself again (it goes home, and hunts what it sees) and is guarded for immune_s: a
## hangup then is refused, so no daemon is held confused for ever. Frozen by chmod 000 when caught, it takes
## the hangup and starts confused when it thaws; a /dev/null hole drags it as any held daemon (harder:
## the hole's own rule); SIGSTOP and a freeze hold its confusion's clock, a hole does not. In practice the
## old dummies reload and wander too, never lashing. On a joiner the host's word carries which of the two it
## is in (take_hup_word()), so every screen draws it confused. Hunter ICE's brain is this one: it is
## confused the same way, and never lashes.
##
## Fiction only: a daemon is a game object; nothing real is signalled, inspected or run.

enum State { HOME, HUNT, TELL, STRIKE, RECOVER, RETURN, SCATTER, DOWN }
const STATE_NAMES := ["home", "hunt", "tell", "strike", "recover", "return", "scatter", "down"]
## The level: what blocks sight, a bolt and a step.
const LEVEL_MASK := 1
## The daemon's middle above its feet (its body's centre), and its body's radius for walls.
const MIDDLE_M := 0.9
const RADIUS_M := 0.55
## How close counts as home, metres.
const HOME_M := 0.3
## A walker's feelers and wall checks sit this far above its feet (under a low wall's top, over
## the floor); the feelers' spread off ahead, radians.
const KNEE_M := 0.45
const FEELER_ANGLE := 0.6
## Where the rogue's scythes come down at the end of its lunge, in the daemon's own space (its
## rig's, scripts/daemons/rogue_daemon.gd).
const SCYTHES := Vector3(0.0, 0.55, -1.25)
## How far under the floor below it the swarm's own origin may go (its nest 0.9 over that).
const SWARM_LOW_M := 0.3
## A joiner snaps to the host's place past this, else glides at FOLLOW_RATE a second.
const FOLLOW_SNAP_M := 4.0
const FOLLOW_RATE := 12.0
## The most events kept for the checks.
const EVENTS_LAST := 256
## A walker's stagger after a ping (C28) knocks it back over this share of it; then it holds still.
const KNOCK_SHARE := 0.3
## SIGHUP (C32): not confused, reloading its config, or wandering confused; and where the host's word
## carries it, two bits over the daemon's life (scripts/net/net_session.gd).
enum Hup { NONE, RELOAD, WANDER }
const HUP_NAMES := ["none", "reload", "wander"]
const HUP_SHIFT := 2
const HUP_MASK := 0x0C
## How fast a confused daemon's facing snaps round as it looks about, radians a second, and how often.
const LOOK_SNAP_RATE := 9.0
const LOOK_SNAP_S := 0.22
## A wander leg past this share of its leash turns back toward home.
const WANDER_LEASH := 0.8

var dummy: Node3D
var art: DaemonArt
## "rogue", "zombie" or "swarm": its art's.
var kind := "rogue"
var state: State = State.HOME
var state_t := 0.0
## Staggers since it was made: tells a ping called off (C28).
var staggers := 0
## Attacks a freeze called off since it was made (C29).
var frozen_offs := 0
## Attacks a /dev/null hole called off since it was made (C31).
var pulled_offs := 0
## SIGHUP (C32): its confusion now and seconds into it; the guard after one (seconds a hangup is refused);
## who threw it (a player's id in a match, 0 alone: a lash's kill is theirs) and its numbers; a hangup taken
## while frozen, waiting for the thaw. Hangups taken, attacks they called off, lashes thrown at other
## daemons and those that landed, for the checks.
var hup: Hup = Hup.NONE
var hup_t := 0.0
var hup_guard := 0.0
var hup_by := 0
var hup_tuning: SighupTuning = null
var hup_pending := false
var hups := 0
var hup_offs := 0
var lashes := 0
var lash_hits := 0
## The player hunted (0 none), the last place it saw it, and for how long it has not.
var prey := 0
var last_seen := Vector3.INF
var unseen_t := 0.0
## Seconds until it may start its next attack, and dives left in a swarm's burst.
var cooldown := 0.0
var burst_left := 0
## Where it stands at home and the way it faces there (world space). Taken when the dummy is
## ready, and again whenever it stands at home unmoved by its brain, so a dummy put somewhere
## else (a check's, a scene's) is at home there.
var home := Transform3D()
var has_home := false
## True from the brain's first move of the dummy until it stands at home again.
var moved := false
## Its own clock: seconds it has run unfrozen. Tells, strikes and landed hits counted, and the
## events (clock, word, prey) for the checks: "tell", "attack", "hit", "miss", "abort".
var clock := 0.0
var tells := 0
var attacks := 0
var landed := 0
var events: Array = []
## Its motion this step (world space, metres a second).
var velocity := Vector3.ZERO
## While it holds a slot under the director's cap.
var holds_slot := false
## A joiner's copy: the host's last word (arena space place, yaw, state, seconds into it) and how
## long ago it came.
var word_at := Vector3.INF
var word_yaw := 0.0
var word_state: State = State.HOME
var word_t := 0.0
var word_age := 0.0
## The host's word that SIGSTOP holds this daemon (its bolts take the host's word each).
var word_frozen := false

var _look := 0.0
var _strike_dir := Vector3.FORWARD
## How far this strike's lunge carries the rogue: only what closes the gap, up to rogue_lunge_m.
var _lunge := 0.0
var _dive_from := Vector3.ZERO
var _dive_mark := Vector3.ZERO
var _dive_hit := false
var _flee_from := Vector3.ZERO
var _thrown := false
## SIGHUP's wander (C32): the lashes left this confusion and the wait to the next, the daemon lashed at now;
## the leg or the look it is in and how long it has left, the way it wanders, the facing it looks round from
## and snaps to; its own dice, seeded by its name and its hangups so a run's walk is the same every time.
var _lash_left := 0
var _lash_wait := 0.0
var _lash_mark: Node3D = null
var _leg_left := 0.0
var _looking := false
var _wander_way := Vector3.FORWARD
var _look_from := 0.0
var _look_to := 0.0
var _look_snap := 0.0
var _hup_rng := RandomNumberGenerator.new()


func _init(owner: Node3D, daemon_art: DaemonArt) -> void:
	dummy = owner
	art = daemon_art
	kind = daemon_art.ai_kind if daemon_art != null else "rogue"


## Takes its spot as home: where it stands now (once, when the dummy is ready in the tree).
func take_home() -> void:
	home = dummy.global_transform
	has_home = true


func state_name() -> String:
	return STATE_NAMES[state]


## True while it tells, strikes or recovers from a strike: an attacker under the cap.
func attacking() -> bool:
	return state == State.TELL or state == State.STRIKE or state == State.RECOVER


# --- The host's (and alone, this machine's) decisions. ---

## One physics step of `delta` seconds, deciding.
func step(delta: float, d) -> void:
	art.displays = false
	if not dummy.is_alive():
		_down(d)
		return
	if state == State.DOWN:
		state = State.HOME
		state_t = 0.0
	if _held_by_chmod(d):
		return  # chmod 000: frozen, its clock and every timer held
	if hup_pending:
		_start_hup(d)  # SIGHUP taken frozen (C32): thawed, it starts confused now
	var stopped: bool = d.frozen(prey)
	if not stopped:
		_tick_hup(delta, d)  # SIGHUP's clock (C32): a hole does not hold it, SIGSTOP does
	if _held_by_hole(d):
		return  # /dev/null: the hole drags it, it does nothing of its own
	if stopped:
		velocity = Vector3.ZERO
		return  # SIGSTOP: frozen whole, its clock and every timer held
	clock += delta
	state_t += delta
	cooldown = maxf(cooldown - delta, 0.0)
	if hup != Hup.NONE:
		_step_confused(delta, d, d.runs() and kind != "hunter")  # SIGHUP (C32): no prey, no lure, its own wander
		return
	var lure: int = d.lure_for(self)
	if lure != 0 and lure != prey:
		_take_lure(lure, d)
	match state:
		State.HOME:
			_step_home(delta, d)
		State.HUNT:
			_step_hunt(delta, d)
		State.TELL:
			_step_tell(delta, d)
		State.STRIKE:
			_step_strike(delta, d)
		State.RECOVER:
			_step_recover(delta, d)
		State.RETURN:
			_step_return(delta, d)
		State.SCATTER:
			_step_scatter(delta, d)


## Practice (or no brains wanted): it drops any hunt and walks home, then stands as the old dummy,
## its art on its own idle life again.
func rest(delta: float, d) -> void:
	_release(d)
	prey = 0
	burst_left = 0
	if not dummy.is_alive():
		_down(d)
		art.displays = true
		return
	if _held_by_chmod(d):
		return  # frozen in practice too (C29): it stands where the beam caught it
	if hup_pending:
		_start_hup(d)
	_tick_hup(delta, d)
	if _held_by_hole(d):
		return  # dragged in practice too (C31); it walks home once the hole lets go
	if hup != Hup.NONE:
		state_t += delta
		_step_confused(delta, d, false)  # SIGHUP in practice too (C32): it reloads and wanders, never lashing
		return
	if moved and has_home and _flat(dummy.global_position - home.origin).length() > HOME_M:
		state = State.RETURN
		_walk(home.origin, _speed(d), delta, d)
		_face_way(delta, d)
		art.drive(DaemonArt.Act.MOVE)
		return
	if moved:
		_settle_home()
	else:
		take_home()
	state = State.HOME
	art.displays = true
	art.drive(DaemonArt.Act.IDLE)


## A hit that did not kill it, from `point` (world space): the swarm scatters (any dive off, its
## burst over); anything at home or going home is roused and hunts whoever is nearest in sight.
func on_hit(point: Vector3, d) -> void:
	if d == null or not d.runs() or state == State.DOWN or hup != Hup.NONE:
		return  # a confused daemon (C32) is too busy reloading to be roused
	if kind == "swarm":
		_release(d)
		burst_left = 0
		_flee_from = point if point.is_finite() else dummy.global_position
		_enter(State.SCATTER)
		_note("abort")
		return
	if state == State.HOME or state == State.RETURN:
		var near: int = d.nearest_prey(dummy.global_position, _eye(d))
		if near != 0:
			_hunt(near, d.prey_point(near))


## A ping's ring met it from `from` (world space, the ring's centre, C28): in the middle of its tell
## the attack is called off and it staggers (the scatter state: a walker knocked back, the swarm
## scattering), then hunts again; anything else it is doing goes on. Only where the brains decide.
## True when it staggered.
func pinged(from: Vector3, d) -> bool:
	if d == null or not d.runs() or state != State.TELL or hup != Hup.NONE:
		return false  # a confused daemon's lash (C32) is no attack on a player: a ping leaves it
	_release(d)
	burst_left = 0
	staggers += 1
	_flee_from = from if from.is_finite() else dummy.global_position
	_note("stagger")
	_enter(State.SCATTER)
	return true


## chmod 000 (C29): true while its dummy is frozen, stopped; a tell or a strike it was in called off.
func _held_by_chmod(d) -> bool:
	if dummy == null or not dummy.has_method("chmod_frozen") or not dummy.chmod_frozen():
		return false
	velocity = Vector3.ZERO
	if state == State.TELL or state == State.STRIKE:
		_release(d)
		burst_left = 0
		frozen_offs += 1
		_note("frozen")
		cooldown = maxf(cooldown, _attack_wait(d))
		_enter(State.HUNT if d.prey_valid(prey) else State.RETURN)
	return true


## /dev/null (C31): true while a hole holds its dummy (the hole moves it, not the brain); a tell or a strike
## it was in is called off, as chmod 000's freeze calls one off, and once the hole lets go it hunts again
## after its attack's own wait, or walks home from where it was left.
func _held_by_hole(d) -> bool:
	if dummy == null or not dummy.has_method("held_by_hole") or not dummy.held_by_hole():
		return false
	velocity = Vector3.ZERO
	moved = true
	if state == State.TELL or state == State.STRIKE:
		_release(d)
		burst_left = 0
		pulled_offs += 1
		_note("pulled")
		cooldown = maxf(cooldown, _attack_wait(d))
		_enter(State.HUNT if d.prey_valid(prey) else State.RETURN)
	art.drive(DaemonArt.Act.MOVE)
	return true


## Seconds it waits after an attack before its next tell: its kind's own, shortened by the difficulty.
func _attack_wait(d) -> float:
	var t: DaemonAiTuning = d.tuning
	return (t.swarm_cooldown_s if kind == "swarm" else t.rogue_cooldown_s if kind == "rogue" else t.zombie_cooldown_s) / d.aggression()


func _step_home(delta: float, d) -> void:
	velocity = Vector3.ZERO
	if moved:
		_settle_home()
	else:
		take_home()
	art.drive(DaemonArt.Act.IDLE)
	_look -= delta
	if _look > 0.0:
		return
	_look = d.tuning.look_every_s
	var spotted := _spot(d)
	if spotted != 0:
		_hunt(spotted, d.prey_point(spotted))


func _step_hunt(delta: float, d) -> void:
	art.drive(DaemonArt.Act.MOVE)
	if not d.prey_valid(prey):
		_go_home()
		return
	var target: Vector3 = d.prey_point(prey)
	var sees: bool = _sees(target, d) and not d.prey_hidden(prey)
	if sees or d.is_decoy(prey):
		last_seen = target  # a decoy's call says where it is (I2)
		unseen_t = 0.0
	else:
		unseen_t += delta
	if unseen_t > d.tuning.lose_s or _from_home() > d.tuning.leash_m:
		_go_home()
		return
	var chase: Vector3 = target if sees or d.is_decoy(prey) else last_seen
	if not chase.is_finite():
		velocity = Vector3.ZERO  # never seen yet this hunt: nowhere to go (Codex review)
		return
	var goal := _hunt_goal(chase, delta, d)
	_walk(goal, _speed(d), delta, d)
	_face(target if sees else goal, delta, d)
	if sees and cooldown <= 0.0 and _in_range(target, d) and d.prey_attackable(prey) and d.take_slot(self, prey):
		holds_slot = true
		burst_left = d.tuning.swarm_burst if kind == "swarm" else 0
		_tell()


func _step_tell(delta: float, d) -> void:
	var tell_s := _tell_s(d)
	art.drive(DaemonArt.Act.TELL, state_t / tell_s)
	velocity = Vector3.ZERO
	var target: Vector3 = d.prey_point(prey) if d.prey_valid(prey) and not d.prey_hidden(prey) else Vector3.INF
	if target.is_finite():
		_face(target, delta, d)
	if state_t < tell_s:
		return
	# The tell is done: the strike follows only with the prey still attackable, in sight and in
	# reach. Otherwise nothing is thrown.
	if target.is_finite() and d.prey_attackable(prey) and _sees(target, d) and _in_reach(target, d):
		_strike(target, d)
	else:
		burst_left = 0
		_note("abort")
		_enter(State.RECOVER)


func _strike(target: Vector3, d) -> void:
	attacks += 1
	_note("attack")
	_enter(State.STRIKE)
	_thrown = false
	_dive_hit = false
	var face := _flat(target - dummy.global_position)
	_strike_dir = face.normalized() if face.length_squared() > 0.0001 else -dummy.global_transform.basis.z
	# The lunge closes the gap to where the scythes reach the prey, never past it.
	_lunge = clampf(face.length() + SCYTHES.z, 0.0, d.tuning.rogue_lunge_m)
	if kind == "swarm":
		var nest: Vector3 = dummy.global_position + Vector3.UP * MIDDLE_M
		_dive_from = nest
		_dive_mark = target
		var way := target - nest
		_strike_dir = way.normalized() if way.length_squared() > 0.0001 else _strike_dir
		burst_left = maxi(burst_left - 1, 0)
	elif kind == "zombie":
		var from: Vector3 = _claw()
		# The bolt's path is checked before it is thrown: nothing through the level.
		if d.clear(from, target):
			d.throw_bolt(self, from, (target - from).normalized())
			_thrown = true
		else:
			_note("miss")


func _step_strike(delta: float, d) -> void:
	var t: DaemonAiTuning = d.tuning
	match kind:
		"rogue":
			art.drive(DaemonArt.Act.STRIKE, state_t / t.rogue_strike_s)
			_shove(_strike_dir * (_lunge / t.rogue_strike_s) * delta, d)
			if state_t >= t.rogue_strike_s:
				_slash(d)
				_enter(State.RECOVER)
		"zombie":
			art.drive(DaemonArt.Act.STRIKE, state_t / t.zombie_throw_s)
			velocity = Vector3.ZERO
			if state_t >= t.zombie_throw_s:
				_enter(State.RECOVER)
		_:
			art.drive(DaemonArt.Act.STRIKE, state_t / t.swarm_dive_s)
			var moved := _shove(_strike_dir * t.swarm_dive_speed * delta, d, true)
			var nest: Vector3 = dummy.global_position + Vector3.UP * MIDDLE_M
			if not _dive_hit and d.prey_valid(prey):
				var at: Vector3 = d.prey_point(prey)
				if nest.distance_to(at) <= t.swarm_hit_m and d.prey_attackable(prey) and d.clear(nest, at):
					_dive_hit = true
					_land(t.swarm_damage, _strike_dir, d)
			var past := (nest - _dive_from).dot(_strike_dir) > _dive_from.distance_to(_dive_mark) + t.swarm_dive_past_m
			if state_t >= t.swarm_dive_s or past or not moved:
				if not _dive_hit:
					_note("miss")
				_enter(State.RECOVER)


func _step_recover(delta: float, d) -> void:
	var t: DaemonAiTuning = d.tuning
	var recover_s := _recover_s(d)
	art.drive(DaemonArt.Act.RECOVER, state_t / recover_s)
	if kind == "swarm":
		# Climbs back to its height and drifts round its prey.
		var target: Vector3 = d.prey_point(prey) if d.prey_valid(prey) else dummy.global_position
		_walk(_orbit_goal(target, delta, d), t.swarm_speed, delta, d)
	else:
		velocity = Vector3.ZERO
	if state_t < recover_s:
		return
	if kind == "swarm" and burst_left > 0 and d.prey_valid(prey):
		var target: Vector3 = d.prey_point(prey)
		if d.prey_attackable(prey) and _sees(target, d) and not d.prey_hidden(prey) and _in_range(target, d):
			_tell()  # the burst's next dive, its own tell first; the slot is still held
			return
	burst_left = 0
	_release(d)
	cooldown = _attack_wait(d)
	_enter(State.HUNT)


func _step_return(delta: float, d) -> void:
	art.drive(DaemonArt.Act.MOVE)
	_walk(home.origin, _speed(d), delta, d)
	_face_way(delta, d)
	if _flat(dummy.global_position - home.origin).length() <= HOME_M:
		_settle_home()
		_enter(State.HOME)
		return
	# Back well inside its leash, it may take up a hunt again.
	_look -= delta
	if _look <= 0.0 and _from_home() < d.tuning.leash_m * 0.6:
		_look = d.tuning.look_every_s
		var spotted := _spot(d)
		if spotted != 0:
			_hunt(spotted, d.prey_point(spotted))


func _step_scatter(delta: float, d) -> void:
	var t: DaemonAiTuning = d.tuning
	var scatter_s := _scatter_s(d)
	art.drive(DaemonArt.Act.SCATTER, state_t / scatter_s)
	var away := dummy.global_position + Vector3.UP * MIDDLE_M - _flee_from
	away.y = 0.0
	if away.length_squared() < 0.0001:
		away = dummy.global_transform.basis.z
	if kind == "swarm":
		_shove(away.normalized() * t.swarm_scatter_speed * delta, d, true)
	else:
		# A walker's stagger (C28): knocked back from the ping over its first part, then still.
		velocity = Vector3.ZERO
		if state_t <= scatter_s * KNOCK_SHARE:
			_shove(away.normalized() * (t.ping_knock_m / (scatter_s * KNOCK_SHARE)) * delta, d)
	if state_t >= scatter_s:
		if kind == "swarm":
			cooldown = maxf(cooldown, t.swarm_burst_gap_s)
		else:
			cooldown = maxf(cooldown, (t.rogue_cooldown_s if kind == "rogue" else t.zombie_cooldown_s) / d.aggression())
		_enter(State.HUNT if d.prey_valid(prey) else State.RETURN)


## The rogue's slash at the end of its lunge: a player whose middle is within slash_m of where
## the scythes come down, with nothing of the level between the daemon's middle and it.
func _slash(d) -> void:
	var t: DaemonAiTuning = d.tuning
	var point := dummy.global_transform * SCYTHES
	var middle := dummy.global_position + Vector3.UP * MIDDLE_M
	if d.prey_valid(prey) and d.prey_attackable(prey):
		var at: Vector3 = d.prey_point(prey)
		if at.distance_to(point) <= t.rogue_slash_m and d.clear(middle, at):
			_land(t.rogue_damage, _strike_dir, d)
			return
	_note("miss")


## `base` damage on the prey, from the director (the difficulty's scale, the combat path).
func _land(base: float, way: Vector3, d) -> void:
	if d.hurt(prey, base, self, way):
		landed += 1
		_note("hit")
	else:
		_note("miss")


## A bolt of this zombie's met a player (the director's word): counted as landed.
func bolt_landed() -> void:
	landed += 1
	_note("hit")


# --- SIGHUP (C32): the hangup, the reload and the confused wander. ---

## A hangup burst caught it, thrown by player `by` (0 alone) with numbers `t`: true when it took it. Refused
## while it is confused already (a second hangup never makes it longer), while its guard after the last one
## holds, and while it is down. Frozen by chmod 000 it takes it and starts confused when it thaws.
func hangup(t: SighupTuning, by: int, d) -> bool:
	if t == null or hup != Hup.NONE or hup_pending or hup_guard > 0.0 or dummy == null or not dummy.is_alive():
		return false
	hup_tuning = t
	hup_by = by
	hups += 1
	if dummy.has_method("chmod_frozen") and dummy.chmod_frozen():
		hup_pending = true
		_note("hup")
		return true
	_start_hup(d)
	return true


## True while it is confused: reloading or wandering.
func confused() -> bool:
	return hup != Hup.NONE


## Its confusion's name now ("none", "reload", "wander").
func hup_name() -> String:
	return HUP_NAMES[hup]


## How far through its reload or its wander it is, 0 to 1 (0 when not confused).
func hup_share() -> float:
	if hup == Hup.NONE:
		return 0.0
	var t := hup_tuning if hup_tuning != null else SighupTuning.shipped()  # a joiner's copy: the shipped numbers
	return clampf(hup_t / (t.reload_s if hup == Hup.RELOAD else t.wander_s), 0.0, 1.0)


## How many times as hard a /dev/null hole drags it now (C31's rule for the confused, C32).
func hole_pull_scale() -> float:
	return hup_tuning.hole_pull_scale if hup != Hup.NONE and hup_tuning != null else 1.0


## A joiner's copy: the host's word on its confusion (a Hup), carried beside its life.
func take_hup_word(word: int) -> void:
	var next: Hup = clampi(word, 0, Hup.WANDER) as Hup
	if next != hup:
		hup = next
		hup_t = 0.0


func _start_hup(d) -> void:
	hup_pending = false
	if state == State.TELL or state == State.STRIKE:
		hup_offs += 1
		_note("abort")
	_release(d)
	burst_left = 0
	prey = 0
	last_seen = Vector3.INF
	unseen_t = 0.0
	velocity = Vector3.ZERO
	hup = Hup.RELOAD
	hup_t = 0.0
	_lash_left = hup_tuning.lash_most if hup_tuning != null else 0
	_lash_mark = null
	_hup_rng.seed = hash([String(dummy.name), hups, kind])
	_note("hup")
	_enter(State.RECOVER)  # the stall, posed as its recovery (the state word carries it so)


## Its confusion's clock: the reload over, it wanders; the wander over (never in the middle of a lash's tell
## or strike), it is itself again, guarded. Not confused, the guard runs down.
func _tick_hup(delta: float, d) -> void:
	if hup == Hup.NONE:
		hup_guard = maxf(hup_guard - delta, 0.0)
		return
	if hup_tuning == null:
		_clear_hup()  # the host's word lent it (this screen followed); deciding again, it has no numbers to run on
		return
	hup_t += delta
	if hup == Hup.RELOAD and hup_t >= hup_tuning.reload_s:
		hup = Hup.WANDER
		hup_t = 0.0
		_lash_wait = hup_tuning.lash_first_s
		_leg_left = 0.0
		_looking = true  # its first leg starts at once
		_note("wander")
		_enter(State.RETURN)
	elif hup == Hup.WANDER and hup_t >= hup_tuning.wander_s and not (_lash_mark != null and (state == State.TELL or state == State.STRIKE)):
		_end_hup(d)


func _end_hup(d) -> void:
	hup_guard = hup_tuning.immune_s if hup_tuning != null else 0.0
	hup = Hup.NONE
	hup_t = 0.0
	_lash_mark = null
	_release(d)
	cooldown = maxf(cooldown, _attack_wait(d)) if d != null else cooldown
	_look = 0.0
	moved = true
	_note("clear")
	_enter(State.RETURN)  # home, or a hunt of whatever it sees on the way


## Every trace of a confusion gone (its death: a new life is a new daemon).
func _clear_hup() -> void:
	hup = Hup.NONE
	hup_t = 0.0
	hup_guard = 0.0
	hup_pending = false
	_lash_mark = null


## One step confused: the reload's stall, or the wander (and, where `lash_ok`, its lashes).
func _step_confused(delta: float, d, lash_ok: bool) -> void:
	art.displays = false
	if hup_tuning == null:
		_clear_hup()
		return
	if hup == Hup.RELOAD:
		velocity = Vector3.ZERO
		art.drive(DaemonArt.Act.RECOVER, hup_share())
		return
	if _lash_mark != null:
		if state == State.TELL or state == State.STRIKE or state == State.RECOVER:
			_step_lash(delta, d)
			return
		_lash_mark = null  # called off (a freeze, a hole): back to its wander
	if lash_ok and _lash_left > 0:
		_lash_wait -= delta
		if _lash_wait <= 0.0:
			var mark := _lash_target(d)
			if mark != null:
				_begin_lash(mark)
				return
			_lash_wait = LOOK_SNAP_S  # none near: it looks again in a moment
	_wander(delta, d)


## The confused walk: legs at a share of its speed the way its dice say, stuttering, each followed by a look
## round (its facing swept in snaps); a leg that would take it far past its leash turns back toward home.
func _wander(delta: float, d) -> void:
	var t := hup_tuning
	_leg_left -= delta
	if _leg_left <= 0.0:
		_looking = not _looking
		if _looking:
			_leg_left = t.look_s * _hup_rng.randf_range(0.7, 1.3)
			_look_from = dummy.global_rotation.y
			_look_to = _look_from
			_look_snap = 0.0
		else:
			_leg_left = t.leg_s * _hup_rng.randf_range(0.7, 1.3)
			_wander_way = _pick_way(d)
	if _looking:
		velocity = Vector3.ZERO
		if state != State.HOME:
			_enter(State.HOME)
		art.drive(DaemonArt.Act.IDLE)
		_look_snap -= delta
		if _look_snap <= 0.0:
			_look_snap = LOOK_SNAP_S * _hup_rng.randf_range(0.7, 1.3)
			_look_to = _look_from + _hup_rng.randf_range(-t.look_sweep, t.look_sweep)
		var yaw := rotate_toward(dummy.global_rotation.y, _look_to, LOOK_SNAP_RATE * delta)
		dummy.global_rotation = Vector3(0.0, yaw, 0.0)
		return
	if state != State.RETURN:
		_enter(State.RETURN)
	art.drive(DaemonArt.Act.MOVE)
	# Its motion stutters: still for stutter_share of each beat.
	if fposmod(hup_t * t.stutter_hz, 1.0) < t.stutter_share:
		velocity = Vector3.ZERO
		return
	var goal := dummy.global_position + _wander_way * 2.0
	if kind == "swarm":
		goal.y = home.origin.y if has_home else dummy.global_position.y
	_walk(goal, _speed(d) * t.wander_share, delta, d)
	_face_way(delta, d)


## A wander leg's way: any way its dice say, but back toward home (within 60 degrees of it) once it has
## gone most of its leash.
func _pick_way(d) -> Vector3:
	var angle := _hup_rng.randf_range(-PI, PI)
	var way := Vector3(sin(angle), 0.0, cos(angle))
	if has_home and d != null and _from_home() > d.tuning.leash_m * WANDER_LEASH:
		var back := _flat(home.origin - dummy.global_position)
		if back.length_squared() > 0.0001:
			way = back.normalized().rotated(Vector3.UP, _hup_rng.randf_range(-PI / 3.0, PI / 3.0))
	return way


## The nearest other living daemon within lash_range_m of it, in sight of its eye: what it lashes at, or null.
func _lash_target(d) -> Node3D:
	var best: Node3D = null
	var best_d := hup_tuning.lash_range_m
	var here := dummy.global_position
	for other in d.brains():
		if other == self or other.dummy == null or not is_instance_valid(other.dummy) or not other.dummy.is_alive():
			continue
		var gap := _flat(other.dummy.global_position - here).length()
		if gap > best_d or not d.clear(_eye(d), other.dummy.global_position + Vector3.UP * MIDDLE_M):
			continue
		best = other.dummy
		best_d = gap
	return best


func _begin_lash(mark: Node3D) -> void:
	_lash_mark = mark
	_lash_left -= 1
	lashes += 1
	_note("lash")
	_enter(State.TELL)


## A lash at another daemon: its own tell, its own strike at that daemon, its own recovery; then it wanders
## on, lash_gap_s before the next.
func _step_lash(delta: float, d) -> void:
	var mark := _lash_mark
	var at := mark.global_position + Vector3.UP * MIDDLE_M if is_instance_valid(mark) and mark.is_alive() else Vector3.INF
	match state:
		State.TELL:
			var tell_s := _tell_s(d)
			art.drive(DaemonArt.Act.TELL, state_t / tell_s)
			velocity = Vector3.ZERO
			if at.is_finite():
				_face(at, delta, d)
			if state_t < tell_s:
				return
			if at.is_finite() and _sees(at, d):
				_lash_strike(at, d)
			else:
				_note("abort")
				_enter(State.RECOVER)
		State.STRIKE:
			_step_lash_strike(delta, at, d)
		_:
			var recover_s := _recover_s(d)
			art.drive(DaemonArt.Act.RECOVER, state_t / recover_s)
			velocity = Vector3.ZERO
			if state_t >= recover_s:
				_lash_mark = null
				_lash_wait = hup_tuning.lash_gap_s
				_leg_left = 0.0
				_looking = true
				_enter(State.RETURN)


func _lash_strike(at: Vector3, d) -> void:
	_enter(State.STRIKE)
	_thrown = false
	_dive_hit = false
	var face := _flat(at - dummy.global_position)
	_strike_dir = face.normalized() if face.length_squared() > 0.0001 else -dummy.global_transform.basis.z
	_lunge = clampf(face.length() + SCYTHES.z, 0.0, d.tuning.rogue_lunge_m)
	if kind == "swarm":
		var nest: Vector3 = dummy.global_position + Vector3.UP * MIDDLE_M
		_dive_from = nest
		_dive_mark = at
		var way := at - nest
		_strike_dir = way.normalized() if way.length_squared() > 0.0001 else _strike_dir
	elif kind == "zombie":
		var from: Vector3 = _claw()
		if d.clear(from, at):
			var bolt = d.throw_bolt(self, from, (at - from).normalized())
			if bolt != null:
				bolt.lash_scale = hup_tuning.lash_scale  # it lands on the daemon it meets (glitch_bolt.gd)
				_thrown = true
		else:
			_note("miss")


func _step_lash_strike(delta: float, at: Vector3, d) -> void:
	var t: DaemonAiTuning = d.tuning
	match kind:
		"rogue":
			art.drive(DaemonArt.Act.STRIKE, state_t / t.rogue_strike_s)
			_shove(_strike_dir * (_lunge / t.rogue_strike_s) * delta, d)
			if state_t >= t.rogue_strike_s:
				var point := dummy.global_transform * SCYTHES
				var middle := dummy.global_position + Vector3.UP * MIDDLE_M
				if at.is_finite() and at.distance_to(point) <= t.rogue_slash_m and d.clear(middle, at):
					_lash_land(t.rogue_damage, _strike_dir, d)
				else:
					_note("miss")
				_enter(State.RECOVER)
		"zombie":
			art.drive(DaemonArt.Act.STRIKE, state_t / t.zombie_throw_s)
			velocity = Vector3.ZERO
			if state_t >= t.zombie_throw_s:
				_enter(State.RECOVER)
		"swarm":
			art.drive(DaemonArt.Act.STRIKE, state_t / t.swarm_dive_s)
			var went := _shove(_strike_dir * t.swarm_dive_speed * delta, d, true)
			var nest: Vector3 = dummy.global_position + Vector3.UP * MIDDLE_M
			if not _dive_hit and at.is_finite() and nest.distance_to(at) <= t.swarm_hit_m and d.clear(nest, at):
				_dive_hit = true
				_lash_land(t.swarm_damage, _strike_dir, d)
			var past := (nest - _dive_from).dot(_strike_dir) > _dive_from.distance_to(_dive_mark) + t.swarm_dive_past_m
			if state_t >= t.swarm_dive_s or past or not went:
				if not _dive_hit:
					_note("miss")
				_enter(State.RECOVER)
		_:
			_enter(State.RECOVER)


## `base` damage of its own attack, at the lash's share, on the daemon it lashed at (the director lands it).
func _lash_land(base: float, way: Vector3, d) -> void:
	if d.hurt_daemon(_lash_mark, base * hup_tuning.lash_scale, self, way):
		lash_hits += 1
		_note("lashed")
	else:
		_note("miss")


## A lash's bolt of this zombie's met a daemon and landed (the director's word, C32).
func lash_bolt_landed() -> void:
	lash_hits += 1
	_note("lashed")


# --- A joiner's copy: the host's word, played. ---

## The host's word for this daemon: where (arena space), facing, in which state and how far in.
func take_word(at: Vector3, yaw: float, word: int, seconds: float, frozen: bool) -> void:
	word_at = at
	word_yaw = yaw
	word_state = clampi(word, 0, State.DOWN) as State
	word_t = seconds
	word_age = 0.0
	word_frozen = frozen


## One physics step of `delta` seconds on a joiner: glide to the host's place, face its way, and
## pose its state. Nothing is decided or judged here.
func follow(delta: float, d) -> void:
	art.displays = false
	_release(d)
	if not word_frozen:
		word_age += delta
		if hup != Hup.NONE:
			hup_t += delta  # this screen's own clock of the host's word on its confusion (C32)
	if not word_at.is_finite() or not dummy.is_alive():
		art.drive(DaemonArt.Act.IDLE)
		return
	var goal: Vector3 = d.to_world(word_at)
	var here := dummy.global_position
	var placed := goal if here.distance_to(goal) > FOLLOW_SNAP_M else here.lerp(goal, 1.0 - exp(-FOLLOW_RATE * delta))
	velocity = (placed - here) / maxf(delta, 0.0001)
	dummy.global_position = placed
	moved = moved or (has_home and _flat(placed - home.origin).length() > HOME_M)  # walks home if the match ends
	var yaw := lerp_angle(dummy.global_rotation.y, word_yaw, 1.0 - exp(-FOLLOW_RATE * delta))
	dummy.global_rotation = Vector3(0.0, yaw, 0.0)
	state = word_state
	state_t = word_t + word_age
	match state:
		State.TELL:
			art.drive(DaemonArt.Act.TELL, state_t / _tell_s(d))
		State.STRIKE:
			art.drive(DaemonArt.Act.STRIKE, state_t / _strike_s(d))
		State.RECOVER:
			art.drive(DaemonArt.Act.RECOVER, state_t / _recover_s(d))
		State.SCATTER:
			art.drive(DaemonArt.Act.SCATTER, state_t / _scatter_s(d))
		State.HUNT, State.RETURN:
			art.drive(DaemonArt.Act.MOVE)
		_:
			art.drive(DaemonArt.Act.IDLE)


# --- Its parts. ---

func _down(d) -> void:
	if state != State.DOWN:
		_release(d)
		prey = 0
		burst_left = 0
		_clear_hup()  # a new life is a new daemon: no confusion, no guard (C32)
		_enter(State.DOWN)
	velocity = Vector3.ZERO
	art.drive(DaemonArt.Act.IDLE)


## Hunts player `id`, last seen at `seen` (where it was spotted).
func _hunt(id: int, seen: Vector3) -> void:
	prey = id
	unseen_t = 0.0
	last_seen = seen
	_enter(State.HUNT)


func _go_home() -> void:
	prey = 0
	last_seen = Vector3.INF
	_enter(State.RETURN)


func _tell() -> void:
	tells += 1
	_note("tell")
	_enter(State.TELL)


func _enter(next: State) -> void:
	state = next
	state_t = 0.0


func _release(d) -> void:
	if holds_slot and d != null:
		d.release_slot(self)
	holds_slot = false


func _note(word: String) -> void:
	events.append([clock, word, prey])
	if events.size() > EVENTS_LAST:
		events.pop_front()


## The nearest player it can hunt from here: in aggro range, in sight of its eye, near enough to
## its spot to chase; 0 for none.
func _spot(d) -> int:
	var best := 0
	var best_d := INF
	for id in d.prey_ids():
		if not d.prey_valid(id) or d.prey_hidden(id):
			continue
		var at: Vector3 = d.prey_point(id)
		var gap := _eye(d).distance_to(at)
		if gap > d.tuning.aggro_range_m or gap >= best_d:
			continue
		if has_home and _flat(at - home.origin).length() > d.tuning.leash_m + d.tuning.rogue_reach_m:
			continue
		if not _sees(at, d):
			continue
		best = id
		best_d = gap
	return best


## A decoy calls it (I2): at home, hunting or going home it takes the decoy `lure` as its prey; in
## the middle of an attack or a stagger it goes on as it was.
func _take_lure(lure: int, d) -> void:
	if state == State.HOME or state == State.HUNT or state == State.RETURN:
		_release(d)
		_hunt(lure, d.prey_point(lure))


## True when a decoy at `at` (world space) is one it may go after (I2): within its leash of home.
func lure_ok(at: Vector3, d) -> bool:
	return at.is_finite() and (not has_home or _flat(at - home.origin).length() <= d.tuning.leash_m)


func _sees(at: Vector3, d) -> bool:
	return at.is_finite() and d.clear(_eye(d), at)


## Where it looks from: a walker's eye, the swarm's nest.
func _eye(d) -> Vector3:
	var height: float = MIDDLE_M if kind == "swarm" else d.tuning.eye_height_m
	return dummy.global_position + Vector3.UP * height


## Where the zombie's bolt leaves: its raised claw, as its art last posed it, kept near its body.
func _claw() -> Vector3:
	var middle := dummy.global_position + Vector3.UP * MIDDLE_M
	var claw: Vector3 = art.muzzle() if art != null and art.is_inside_tree() else middle
	if not claw.is_finite() or claw.distance_to(middle) > 1.6:
		claw = dummy.global_transform * Vector3(0.3, 1.3, -0.7)
	return claw


func _in_range(target: Vector3, d) -> bool:
	var t: DaemonAiTuning = d.tuning
	var gap := _flat(target - dummy.global_position).length()
	match kind:
		"rogue":
			return gap <= t.rogue_reach_m
		"zombie":
			return gap <= t.zombie_range_m
	return gap <= t.swarm_orbit_m + 2.0


## At the tell's end: close enough for the strike to reach.
func _in_reach(target: Vector3, d) -> bool:
	var t: DaemonAiTuning = d.tuning
	var gap := _flat(target - dummy.global_position).length()
	match kind:
		"rogue":
			return gap <= t.rogue_reach_m + t.rogue_lunge_m
		"zombie":
			return gap <= t.zombie_range_m
	return gap <= t.swarm_orbit_m + 4.0


func _hunt_goal(target: Vector3, delta: float, d) -> Vector3:
	var t: DaemonAiTuning = d.tuning
	var here := dummy.global_position
	match kind:
		"rogue", "zombie":
			var keep: float = t.rogue_reach_m * 0.7 if kind == "rogue" else t.zombie_keep_m
			var way := _flat(target - here)
			if way.length() <= keep:
				return here
			var goal := target - way.normalized() * keep
			goal.y = here.y
			return goal
	return _orbit_goal(target, delta, d)


## The swarm's place on its circle round `target`, a little ahead the way it goes round, at its
## spot's height.
func _orbit_goal(target: Vector3, _delta: float, d) -> Vector3:
	var t: DaemonAiTuning = d.tuning
	var out := _flat(dummy.global_position - target)
	if out.length_squared() < 0.0001:
		out = Vector3.BACK
	var around := out.normalized().rotated(Vector3.UP, 0.5) * t.swarm_orbit_m
	var goal := target + around
	goal.y = home.origin.y if has_home else dummy.global_position.y
	return goal


func _speed(d) -> float:
	var t: DaemonAiTuning = d.tuning
	match kind:
		"rogue":
			return t.rogue_speed
		"zombie":
			return t.zombie_speed
	return t.swarm_speed


func _tell_s(d) -> float:
	var t: DaemonAiTuning = d.tuning
	match kind:
		"rogue":
			return t.rogue_tell_s
		"zombie":
			return t.zombie_tell_s
	return t.swarm_tell_s


## How long its strike lasts (I1: a function, so hunter ICE's brain gives its own).
func _strike_s(d) -> float:
	var t: DaemonAiTuning = d.tuning
	return t.rogue_strike_s if kind == "rogue" else t.zombie_throw_s if kind == "zombie" else t.swarm_dive_s


func _recover_s(d) -> float:
	var t: DaemonAiTuning = d.tuning
	match kind:
		"rogue":
			return t.rogue_recover_s
		"zombie":
			return t.zombie_recover_s
	return t.swarm_burst_gap_s if burst_left > 0 else t.swarm_recover_s


## How long the scatter state lasts: the swarm's scatter, a walker's stagger after a ping (C28).
func _scatter_s(d) -> float:
	var t: DaemonAiTuning = d.tuning
	return maxf(t.swarm_scatter_s if kind == "swarm" else t.ping_stagger_s, 0.001)


func _from_home() -> float:
	return _flat(dummy.global_position - home.origin).length() if has_home else 0.0


## Steers toward `goal` at up to `speed`, easing in as it arrives: apart from the other daemons,
## its feelers turning it off a wall ahead, then a slide along any wall it meets.
func _walk(goal: Vector3, speed: float, delta: float, d) -> void:
	if delta <= 0.0:
		return
	var here := dummy.global_position
	var to := goal - here
	if kind != "swarm":
		to.y = 0.0
	var gap := to.length()
	if gap < 0.02:
		velocity = Vector3.ZERO
		return
	var want := to / gap * minf(speed, gap / delta)
	want += _apart(d) * speed * 0.6
	want = _steer(want, d)
	_shove(want * delta, d, kind == "swarm")


## Moves the daemon by `step` (world space), sliding along the level where it meets it; a walker
## stays on its floor. True when it moved at all.
func _shove(step: Vector3, d, fly: bool = false) -> bool:
	if not fly:
		step.y = 0.0
	var here := dummy.global_position
	var from := here + Vector3.UP * (MIDDLE_M if kind == "swarm" else KNEE_M)
	var free := _free_step(from, step, d)
	if free.length_squared() < 0.0000001:
		velocity = Vector3.ZERO
		return false
	var next := here + free
	if kind == "swarm" and has_home:
		# It flies between a little under its spot's height and a little over it, its nest never
		# lower than a crouching player's middle.
		next.y = clampf(next.y, home.origin.y - 2.0, home.origin.y + 1.0)
		var below: Dictionary = d.cast(next + Vector3.UP * MIDDLE_M, next + Vector3.DOWN * 3.0)
		if not below.is_empty():
			next.y = maxf(next.y, (below["position"] as Vector3).y - SWARM_LOW_M)
	dummy.global_position = next
	moved = true
	var dt := maxf(dummy.get_physics_process_delta_time(), 0.0001)
	velocity = free / dt
	return true


## `step` from `from`, cut short or slid along the level so the body (RADIUS_M round) stays clear.
func _free_step(from: Vector3, step: Vector3, d) -> Vector3:
	var length := step.length()
	if length < 0.000001:
		return Vector3.ZERO
	var way := step / length
	var hit: Dictionary = d.cast(from, from + way * (length + RADIUS_M))
	if hit.is_empty():
		return step
	var normal: Vector3 = hit["normal"]
	if kind != "swarm":
		normal.y = 0.0
	normal = normal.normalized() if normal.length_squared() > 0.0001 else -way
	var slid := step - normal * step.dot(normal)
	if kind != "swarm":
		slid.y = 0.0
	if slid.length() < 0.000001:
		return Vector3.ZERO
	var again: Dictionary = d.cast(from, from + slid.normalized() * (slid.length() + RADIUS_M))
	return slid if again.is_empty() else Vector3.ZERO


## Its feelers: ahead blocked within feeler_m, it turns to the nearer clear side of ahead.
func _steer(want: Vector3, d) -> Vector3:
	var speed := want.length()
	if speed < 0.0001:
		return want
	var way := want / speed
	var from := dummy.global_position + Vector3.UP * (MIDDLE_M if kind == "swarm" else KNEE_M)
	var reach: float = d.tuning.feeler_m
	if d.cast(from, from + way * reach).is_empty():
		return want
	for turn in [FEELER_ANGLE, -FEELER_ANGLE, 2.0 * FEELER_ANGLE, -2.0 * FEELER_ANGLE]:
		var side := way.rotated(Vector3.UP, turn)
		if d.cast(from, from + side * reach).is_empty():
			return side * speed
	return want * 0.3


## Away from every other daemon closer than keep_apart_m, stronger the closer.
func _apart(d) -> Vector3:
	var keep: float = d.tuning.keep_apart_m
	if keep <= 0.0:
		return Vector3.ZERO
	var push := Vector3.ZERO
	var here := dummy.global_position
	for other in d.brains():
		if other == self or not other.dummy.is_alive():
			continue
		var gap := _flat(here - other.dummy.global_position)
		var dist := gap.length()
		if dist < keep and dist > 0.0001:
			push += gap / dist * (1.0 - dist / keep)
	return push


## Turns to face `point` at the turn rate.
func _face(point: Vector3, delta: float, d) -> void:
	var way := _flat(point - dummy.global_position)
	if way.length_squared() < 0.0004:
		return
	var want := atan2(-way.x, -way.z)
	var yaw := rotate_toward(dummy.global_rotation.y, want, d.tuning.turn_rate * delta)
	dummy.global_rotation = Vector3(0.0, yaw, 0.0)


## Turns to face the way it goes.
func _face_way(delta: float, d) -> void:
	if velocity.length_squared() > 0.01:
		_face(dummy.global_position + velocity, delta, d)


## Exactly at home, facing as it did; unmoved from here on.
func _settle_home() -> void:
	if has_home and dummy.global_transform != home:
		dummy.global_transform = home
	moved = false


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
