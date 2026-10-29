class_name DaemonDirector
extends Node
## The arena's daemons fighting back (C27b): one of these lives beside the arena (main.gd makes
## it) and steps every daemon's brain (scripts/fight/daemon_brain.gd) each physics frame, in
## a fixed order. It says who the daemons may hunt (alone the player; hosting, every player of the
## match: its own and each joiner's avatar), where each is and whether it is alive, attackable
## (not spawn-protected) or frozen by SIGSTOP; it keeps the attacker cap (at most max_attackers
## daemons in a tell or a strike on one player at a time); it checks sight and walls against the
## level; it throws the zombies' bolts from a fixed pool (scripts/fight/glitch_bolt.gd); it passes a
## ping's ring meeting a daemon (C28) on to its brain, which staggers when caught mid-tell; and it
## lands every hit through the combat path, the difficulty's damage scale on it: alone through
## the player's own health (scripts/fight/solo_life.gd, which runs the match's combat rules),
## hosting through the session (scripts/net/net_session.gd), which judges it in the match's
## combat and tells everyone.
##
## Its mode: RUN alone or hosting (the brains decide), FOLLOW on a joiner (the brains play the
## host's word, judge nothing), REST in practice (the brains walk home and stand as the old
## never-attack dummies). Alone the settings decide practice and the difficulty; in a match the
## host's do, as its light-trail rule (a joiner's own count for nothing).
##
## Fiction only: nothing here touches a real process, file or the system.

const GROUP := &"daemon_director"
const NODE_NAME := "DaemonDirector"
const TUNING_PATH := "res://resources/daemon_ai.tres"
const TARGET_GROUP := &"targets"
enum Mode { REST, RUN, FOLLOW }
## The bolts in flight at most, arena-wide: a fixed pool.
const BOLTS := 8
## The level: what blocks sight, steps and bolts.
const LEVEL_MASK := 1
## A player's body round its middle, for a bolt passing it.
const BODY_RADIUS_M := 0.4
## On a joiner, how long a bolt of its own may fly before the host's word must list it, and how
## long after one of its bolts ended the host's word may not throw it again (its own channel).
const BOLT_GRACE_S := 0.3

## A DaemonAiTuning; null for resources/daemon_ai.tres. Set before the node enters the tree.
var tuning: DaemonAiTuning
## The local player (scripts/player.gd), its solo life, and the session beside the arena (null
## alone). Set by main.gd.
var player: Node3D = null
var life: Node = null
var session: Node = null
var mode: Mode = Mode.REST

var _brains: Array = []
var _slots := {}
var _bolts: Array[GlitchBolt] = []
var _arena: Node3D
## The host's last bolt id, this director's clock, and on a joiner when each bolt id last ended.
var _bolt_id := 0
var _clock := 0.0
var _ended := {}
## Whether a match was on at the last step: a match starting or ending is a mode's change too.
var _was_online := false
## A joiner's bolt further than this from the host's word of it is put where the host's is.
const BOLT_SNAP_M := 0.5


static func of(node: Node) -> DaemonDirector:
	if node == null or not node.is_inside_tree():
		return null
	for d in node.get_tree().get_nodes_in_group(GROUP):
		var host := (d as Node).get_parent()
		if host != null and (host == node or host.is_ancestor_of(node)):
			return d
	return null


func _init() -> void:
	name = NODE_NAME


func _ready() -> void:
	add_to_group(GROUP)
	_arena = get_parent() as Node3D
	if not (tuning is DaemonAiTuning):
		tuning = load(TUNING_PATH)
	if tuning == null or not tuning.problems().is_empty():
		if tuning != null:
			for issue in tuning.problems():
				push_warning("daemon AI tuning: " + issue + "; using the built-in defaults instead")
		tuning = DaemonAiTuning.new()
	for i in BOLTS:
		var bolt := GlitchBolt.new()
		bolt.name = "Bolt%d" % i
		_bolts.append(bolt)  # out of the tree until thrown: the trails let go of a bolt that leaves it
	_mode_now()


func _exit_tree() -> void:
	_slots.clear()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for bolt in _bolts:
			if is_instance_valid(bolt) and not bolt.is_inside_tree():
				bolt.free()


func _physics_process(delta: float) -> void:
	_clock += delta
	_mode_now()
	for brain in brains():
		match mode:
			Mode.RUN:
				brain.step(delta, self)
			Mode.FOLLOW:
				brain.follow(delta, self)
			_:
				brain.rest(delta, self)


## Every daemon's brain in this arena, in a fixed order (by the dummy's name).
func brains() -> Array:
	if _brains.is_empty() or not _all_valid():
		_brains = []
		var dummies := get_tree().get_nodes_in_group(TARGET_GROUP).filter(func(n): return _arena != null and _arena.is_ancestor_of(n) and n.get("brain") != null)
		dummies.sort_custom(func(a, b): return String(a.name) < String(b.name))
		for dummy in dummies:
			_brains.append(dummy.brain)
	return _brains


func _all_valid() -> bool:
	for brain in _brains:
		if not is_instance_valid(brain.dummy) or not brain.dummy.is_inside_tree():
			return false
	return true


## True while the brains decide here: alone, or hosting a match.
func runs() -> bool:
	return mode == Mode.RUN


## Practice and the difficulty in force: alone (and hosting) the settings', on a joiner the
## host's word.
func practice_on() -> bool:
	if _online() and not session.is_hosting():
		return session.host_practice
	return GameSettings.current().value("gameplay", "practice") == true


func difficulty() -> String:
	if _online() and not session.is_hosting():
		return session.host_difficulty
	return GameSettings.current().value("gameplay", "difficulty")


func damage_scale() -> float:
	return tuning.damage_scale(difficulty())


func aggression() -> float:
	return tuning.aggression(difficulty())


func _mode_now() -> void:
	var was := mode
	var was_online := _was_online
	_was_online = _online()
	if practice_on():
		mode = Mode.REST
	elif _online() and not session.is_hosting():
		mode = Mode.FOLLOW
	else:
		mode = Mode.RUN
	if mode != was or _was_online != was_online:
		# Every bolt in the air was thrown under the old mode: practice coming on, a match starting
		# or ending (hosting is as RUN as alone is), none of them lands anything now (Codex review).
		for bolt in _bolts:
			bolt.stop()


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()


# --- Who the daemons hunt. ---

## The players they may hunt: alone this player (1); hosting, every player of the match.
func prey_ids() -> Array:
	if _online():
		return session.players.keys()
	return [1]


## Where player `id`'s middle is now (world space); INF when it is down, not shown or unknown.
func prey_point(id: int) -> Vector3:
	if id == 0:
		return Vector3.INF
	if _online():
		if id == session.my_id:
			return player.global_position if _player_up() else Vector3.INF
		var avatar = session.avatars.get(id)
		if avatar == null or not is_instance_valid(avatar) or not avatar.visible or avatar.dead:
			return Vector3.INF
		# Its newest received place, not the drawn one a little behind it: a joiner's dodge counts
		# as soon as the host hears of it (Codex review), as the host's own blasts judge it.
		return to_world(avatar.latest_position())
	return player.global_position if id == 1 and _player_up() else Vector3.INF


## True while player `id` can be hunted: known, shown and alive.
func prey_valid(id: int) -> bool:
	if id == 0 or not prey_point(id).is_finite():
		return false
	if _online():
		return session.combat != null and session.combat.alive(id)
	return life == null or life.alive()


## True while player `id` can be attacked: hunted, and not spawn-protected.
func prey_attackable(id: int) -> bool:
	if not prey_valid(id):
		return false
	if _online():
		return not session.combat.protected(id)
	return life == null or not life.protected()


## True while SIGSTOP freezes the daemons hunting player `id`: alone, the player's SIGSTOP
## (every daemon hunts it); in a match, that player's, by the host's count.
func frozen(id: int) -> bool:
	if _online():
		return id != 0 and session.combat != null and session.combat.sigstop_on(id)
	return _player_up() and player.sigstop != null and player.sigstop.is_on()


## The nearest hunted player in sight of `eye`, whatever the range (a daemon roused by a shot);
## 0 for none.
func nearest_prey(_from: Vector3, eye: Vector3) -> int:
	var best := 0
	var best_d := INF
	for id in prey_ids():
		if not prey_valid(id):
			continue
		var at := prey_point(id)
		var gap := eye.distance_to(at)
		if gap < best_d and clear(eye, at):
			best = id
			best_d = gap
	return best


func _player_up() -> bool:
	return player != null and is_instance_valid(player) and player.is_inside_tree() and player.alive


# --- The attacker cap. ---

## A slot for `brain` to attack player `id`, under the cap; false when the cap is full.
func take_slot(brain: DaemonBrain, id: int) -> bool:
	release_slot(brain)
	var holders: Array = _slots.get(id, [])
	if holders.size() >= tuning.max_attackers:
		return false
	holders.append(brain)
	_slots[id] = holders
	return true


func release_slot(brain: DaemonBrain) -> void:
	for id in _slots:
		(_slots[id] as Array).erase(brain)


## How many daemons hold a slot on player `id` now.
func attackers(id: int) -> int:
	return (_slots.get(id, []) as Array).size()


# --- Landing it. ---

## `base` damage from `brain`'s attack on player `id`, along `way`: the difficulty's scale on it,
## landed through the combat path. True when it took health.
func hurt(id: int, base: float, brain: DaemonBrain, way: Vector3) -> bool:
	var amount := base * damage_scale()
	if mode != Mode.RUN or amount <= 0.0 or not prey_attackable(id):
		return false  # only while the brains decide here: never in practice or on a joiner
	if _online():
		return session.daemon_hurt(id, amount, brain.dummy, way)
	if life == null or id != 1:
		return false
	return life.damage(amount, brain.dummy, way)


## A zombie's bolt from `from` along `dir` (world space): deciding here when the brains run, else
## only drawn, as the host's bolt `bolt_id`. Null when every bolt of the pool is in flight.
func throw_bolt(brain: DaemonBrain, from: Vector3, dir: Vector3, bolt_id: int = 0) -> GlitchBolt:
	for bolt in _bolts:
		if bolt.live:
			continue
		if not bolt.is_inside_tree():
			add_child(bolt)
		bolt.launch(self, brain, from, dir, tuning.zombie_bolt_speed, tuning.zombie_bolt_life_s, tuning.zombie_bolt_radius_m, mode == Mode.RUN, brain.prey)
		if mode == Mode.RUN:
			_bolt_id = _bolt_id % 2000000000 + 1
			bolt.id = _bolt_id
			if _online():
				session.daemon_bolt(brain.dummy, bolt.id, from, dir)
		else:
			bolt.id = bolt_id
		return bolt
	return null


## A ping's ring met `dummy` from `from` (world space, C28): its brain staggers when the ping caught it
## in the middle of a tell. Only while the brains decide here: never in practice, never on a joiner
## (the host's own pulse judges a match's). True when it staggered.
func pinged(dummy: Node, from: Vector3) -> bool:
	if mode != Mode.RUN or dummy == null or dummy.get("brain") == null:
		return false
	return dummy.brain.pinged(from, self)


## Every bolt of `brain`'s ends now: its daemon's reset (a new round) leaves nothing of it flying.
func stop_bolts_of(brain: DaemonBrain) -> void:
	for bolt in _bolts:
		if bolt.live and bolt.brain == brain:
			bolt.stop()


## The players' avatars' hit volumes in a match: a bolt passes them and meets each player where it
## was last heard (bodies()), never where its avatar is drawn a moment behind (Codex review).
func avatar_rids() -> Array[RID]:
	var out: Array[RID] = []
	if _online():
		for id in session.avatars:
			var avatar = session.avatars[id]
			if avatar != null and is_instance_valid(avatar):
				out.append(avatar.hit_rid())
	return out


## The bolt in flight with id `bolt_id`, or null.
func bolt_of(bolt_id: int) -> GlitchBolt:
	for bolt in _bolts:
		if bolt.live and bolt.id == bolt_id:
			return bolt
	return null


## On a joiner (C27b), the host's bolts in the air now, id -> [brain, where, way, held] (world
## space): one this screen does not draw is thrown from where the host's is (a launch word lost to
## an R reload); one it draws that the host no longer has is stopped once its launch word's grace
## is over; one it draws takes the host's word on SIGSTOP's hold and is put where the host's is
## when it has strayed (Codex review). One that ended here a moment ago is not thrown again.
func follow_bolts(live: Dictionary) -> void:
	for bolt in _bolts:
		if bolt.live and bolt.id > 0 and not live.has(bolt.id) and bolt.age() > BOLT_GRACE_S:
			bolt.stop()
	for bolt_id in live:
		var word: Array = live[bolt_id]
		var drawn := bolt_of(bolt_id)
		if drawn == null:
			if _clock - float(_ended.get(bolt_id, -INF)) < BOLT_GRACE_S:
				continue
			drawn = throw_bolt(word[0], word[1], word[2], bolt_id)
			if drawn == null:
				continue
		drawn.held_word = word[3]
		if drawn.global_position.distance_to(word[1]) > BOLT_SNAP_M:
			drawn.global_position = word[1]
	for bolt_id in _ended.keys():
		if _clock - float(_ended[bolt_id]) >= BOLT_GRACE_S:
			_ended.erase(bolt_id)


## A deciding bolt of `brain`'s passed player `id`: its damage, through the combat path.
func bolt_met(brain: DaemonBrain, id: int, way: Vector3) -> void:
	if hurt(id, tuning.zombie_bolt_damage, brain, way):
		brain.bolt_landed()
	else:
		brain._note("miss")


## A bolt is done: out of the tree once this frame is over, so its trail lets go (unless it was
## thrown again meanwhile).
func bolt_done(bolt: GlitchBolt) -> void:
	if bolt.id > 0 and mode == Mode.FOLLOW:
		_ended[bolt.id] = _clock
	_put_away.call_deferred(bolt)


func _put_away(bolt: GlitchBolt) -> void:
	if is_instance_valid(bolt) and not bolt.live and bolt.get_parent() == self:
		remove_child(bolt)


func bolts() -> Array[GlitchBolt]:
	return _bolts


## The bolts in flight now.
func bolts_live() -> int:
	var n := 0
	for bolt in _bolts:
		n += 1 if bolt.live else 0
	return n


## The players a bolt can pass, with where each one's middle is (world space): id -> point.
func bodies() -> Dictionary:
	var out := {}
	if _online():
		for id in session.players:
			var at := prey_point(id)
			if at.is_finite():
				out[id] = at
	elif _player_up():
		out[1] = player.global_position
	return out


# --- The level. ---

## True when nothing of the level lies between `from` and `to`.
func clear(from: Vector3, to: Vector3) -> bool:
	return cast(from, to).is_empty()


## The level's first hit from `from` to `to`, or {}.
func cast(from: Vector3, to: Vector3) -> Dictionary:
	if not is_inside_tree() or _arena == null or from.is_equal_approx(to):
		return {}
	var query := PhysicsRayQueryParameters3D.create(from, to, LEVEL_MASK)
	return _arena.get_world_3d().direct_space_state.intersect_ray(query)


## Arena space (the session's) to the world and back.
func to_world(local: Vector3) -> Vector3:
	return _arena.to_global(local) if _arena != null else local


func to_arena(world: Vector3) -> Vector3:
	return _arena.to_local(world) if _arena != null else world
