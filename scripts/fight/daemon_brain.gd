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
	if _held_by_hole(d):
		return  # /dev/null: the hole drags it, it does nothing of its own
	if d.frozen(prey):
		velocity = Vector3.ZERO
		return  # SIGSTOP: frozen whole, its clock and every timer held
	clock += delta
	state_t += delta
	cooldown = maxf(cooldown - delta, 0.0)
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
	if _held_by_hole(d):
		return  # dragged in practice too (C31); it walks home once the hole lets go
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
	if d == null or not d.runs() or state == State.DOWN:
		return
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
	if d == null or not d.runs() or state != State.TELL:
		return false
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
