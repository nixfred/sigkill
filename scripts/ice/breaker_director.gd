class_name BreakerDirector
extends Node3D
## ICEbreakers (I2): the one-use programs an intruder carries beside its weapons (never in a weapon slot,
## never on the 1 to 9 strip) to beat the system's ICE. Four kinds (scripts/ice/breakers.gd): brute, a
## short-range charge that cracks white ICE (a wall up close breaks at once; a node or the hunter takes
## a hard hit, the hunter never one-shot; a daemon in its cone too); exploit, a few seconds in which the
## intruder's hits on weak seams (A5's weak() points, ICE's and the daemons') land far harder, the seams
## marked on its screen; cloak, a few seconds in which neither ICE nor the daemons see the intruder
## (nodes do not trigger, the hunter and the daemons lose sight and go to where they last saw it),
## ended early by firing; and the decoy, thrown or dropped, which the hunter, the daemons and white ICE
## nodes go after instead of any intruder while it calls: the sacrifice that buys an escape.
##
## One of these lives beside the arena (main.gd makes it, next to ICE's director). It keeps every
## intruder's breakers (how many of each kind, the round's start_count of each when a round starts, one
## more from a pickup, never past the cap), runs what each one does, throws the decoys, lays the pickups
## at seeded spots mid-round and gives them to whoever walks over them, and in a match is the host's word
## on all of it. Its numbers: resources/breakers.tres (BreakerTuning).
##
## Keys: U runs the loaded breaker, Y loads the next kind (scripts/controls.gd; rebindable). The player
## presses (press_run(), press_cycle()); this director decides on the next physics step.
##
## Its mode: RUN alone or hosting (it decides), FOLLOW on a joiner (a press is only a request to the host,
## session.breaker_intent(); its own counts, its exploit and cloak, the decoys and the pickups are the
## host's word, take_word()), OFF in practice (nothing fights back, so nothing to break: no readout, no
## pickups, U and Y do nothing). The ICE setting does not turn them off: with ICE off they still work on
## the daemons (exploit's seams, cloak, the decoy's pull, the brute's charge).
##
## Everything is simulated: a breaker reads nothing real and touches nothing real.

const Kinds = preload("res://scripts/ice/breakers.gd")
const Dummy = preload("res://scripts/target_dummy.gd")
const Sfx = preload("res://scripts/sfx_synth.gd")
const SettingsApply = preload("res://scripts/settings/settings_apply.gd")
const Palette = preload("res://scripts/palette.gd")

const GROUP := &"breaker_director"
const NODE_NAME := "BreakerDirector"
enum Mode { OFF, RUN, FOLLOW }
## The pickups' spots, in arena space, on open floor: the east flank, the west middle, by the low wall's
## end, the south-west by the platform, the north-east corner, and one inside rogue.d's room (behind the
## gate: a reason to break in).
const SPOTS := [Vector3(16.0, 0.0, 0.0), Vector3(-11.0, 0.0, -4.0), Vector3(5.0, 0.0, 4.5), Vector3(-4.0, 0.0, 16.0), Vector3(17.0, 0.0, -10.0), Vector3(-5.0, 0.0, -13.0)]
## The most decoys calling at once, arena-wide; a new one takes the oldest's slot when every slot is full.
const DECOYS_LAST := 4
## A decoy's id as prey (scripts/fight/daemon_director.gd): -1 minus its slot.
const DECOY_FIRST := -1
## The floats a decoy takes in the host's word: x, y, z (arena space), its call left, landed (1 or 0).
const DECOY_WORD := 5
## The brute's charge in the host's word: its count, where from and which way (arena space).
const BRUTE_WORD := 7
## Where a daemon's middle is over its feet: where the brute's charge meets it.
const MIDDLE_M := 0.9
## A blast's sight starts a little over the eye's, as the fork bomb's does.
const SIGHT_LIFT_M := 0.1
## The level, for sight.
const LEVEL_MASK := 1
## A decoy thrown leaves this far in front of the eye (never past the level).
const THROW_AHEAD_M := 0.4

## This player's own breaker ran (alone, hosting, or on the host's word), a press with none of the
## loaded kind, Y loading another kind, a pickup this player took, and this player's cloak ending.
signal ran(kind: int)
signal empty(kind: int)
signal loaded_changed(kind: int)
signal picked(kind: int)
signal cloak_ended

## Where its pickups stand, in arena space: SPOTS, or (C36) an arena stood in ruins hands in theirs before it is ready.
var spots: Array = SPOTS
## A BreakerTuning; null for resources/breakers.tres. Set before the node enters the tree.
var tuning: BreakerTuning
## The daemons' director (who the intruders are, where, alive, sight), ICE's director, the local player,
## the session beside the arena (null alone) and the round HUD. Set by main.gd.
var daemons: Node = null
var ice: Node = null
var player: Node3D = null
var session: Node = null
var rounds: Node = null
var mode: Mode = Mode.OFF
var round_number := 1

## Deciding: every intruder's breakers and the seconds left of its exploit and its cloak, by id.
var loadouts := {}
var exploit_left := {}
var cloak_left := {}
## This player's own breakers (deciding, loadouts' own; on a joiner, the host's word), and its exploit
## and cloak seconds left as this screen shows them.
var mine: Breakers
var my_exploit := 0.0
var my_cloak := 0.0
## The decoys, by slot (null for an empty one), and the pickups, by spot (null for none there).
var decoys: Array = []
var pickups: Array = []
## The brute's charges so far (each one's count), and the last one's place and way (arena space).
var brute_serial := 0
var brute_from := Vector3.ZERO
var brute_way := Vector3.FORWARD
## For the checks: each kind's runs here, what the last charge reached, the pickups laid and taken, the
## host's words taken, and the decoys thrown.
var runs := PackedInt32Array([0, 0, 0, 0])
var last_brute_hits := 0
var pickups_made := 0
var pickups_taken := 0
var words_taken := 0
var decoys_thrown := 0

var _run_pressed := false
var _cycle_pressed := false
var _pickup_wait := 0.0
var _rng := RandomNumberGenerator.new()
var _last_use := {}
var _last_press := -INF
var _clock := 0.0
var _was_online := false
var _brutes_drawn := 0
var _brute_seen := false
## Deciding: each intruder's runs and pickups so far and the last one's kind, for its screen (the word).
## On a joiner: the host's counts it has said, and whether a word has come.
var _run_serial := {}
var _run_kind := {}
var _pick_serial := {}
var _pick_kind := {}
var _ran_seen := 0
var _picked_seen := 0
var _word_seen := false
var _was_cloaked := false
var _marks: ExploitMarks
var _sfx := {}


static func of(node: Node) -> BreakerDirector:
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
	tuning = BreakerTuning.usable(tuning)
	decoys.resize(DECOYS_LAST)
	pickups.resize(spots.size())
	mine = Breakers.new(tuning.start_count, tuning.carry_cap)
	if ice != null:
		ice.brute_wall_scale = tuning.brute_wall_scale
	if rounds != null and rounds.get("stats") != null:
		round_number = rounds.stats.round_number
	if rounds != null and rounds.has_signal("round_started"):
		rounds.round_started.connect(start_round)
	if player != null:
		if player.has_signal("fire_intent"):
			player.fire_intent.connect(func(_o, _d, _w): _fired_alone())
		if player.has_signal("throw_intent"):
			player.throw_intent.connect(func(_o, _d, _w): _fired_alone())
	_marks = ExploitMarks.new()
	_marks.director = self
	add_child(_marks)
	for word in ["brute", "exploit", "cloak", "decoy", "empty", "cycle", "pickup", "uncloak"]:
		var p := AudioStreamPlayer.new()
		p.stream = Sfx.breaker(word)
		p.bus = SettingsApply.EFFECTS
		add_child(p)
		_sfx[word] = p
	_mode_now()


# --- Its mode. ---

## True while breakers are carried: not practice (alone and hosting, the settings'; on a joiner, the
## host's word). The ICE setting has no say: with ICE off they work on the daemons.
func breakers_on() -> bool:
	if _online() and not session.is_hosting():
		return session.host_practice != true
	return GameSettings.current().value("gameplay", "practice") != true


func decides() -> bool:
	return mode == Mode.RUN


func follows() -> bool:
	return mode == Mode.FOLLOW


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()


## This player's id: 1 alone, the session's in a match.
func my_id() -> int:
	return session.my_id if _online() else 1


func _mode_now() -> void:
	var online := _online()
	var next := Mode.OFF
	if breakers_on():
		next = Mode.FOLLOW if online and not session.is_hosting() else Mode.RUN
	if next == mode and online == _was_online:
		return
	mode = next
	_was_online = online
	_start_fresh()


## Everything as a round starts it: every intruder's start_count of each kind, no effect on anyone, no
## decoy, no pickup, the first pickup's wait from now.
func _start_fresh() -> void:
	loadouts.clear()
	exploit_left.clear()
	cloak_left.clear()
	_last_use.clear()
	mine.reset(tuning.start_count)
	my_exploit = 0.0
	my_cloak = 0.0
	_was_cloaked = false
	_brute_seen = false
	_word_seen = false
	for slot in DECOYS_LAST:
		_drop_decoy(slot, false)
	for spot in spots.size():
		_drop_pickup(spot, false)
	_pickup_wait = tuning.pickup_first_s
	if Dummy.fixed_seeds:
		_rng.seed = hash("breakers:%d" % round_number)
	else:
		_rng.randomize()
	if mode == Mode.RUN:
		loadouts[my_id()] = mine


# --- Rounds. ---

## Round `number` starts (the round HUD's word): everything as a round starts it.
func start_round(number: int) -> void:
	round_number = maxi(number, 1)
	_start_fresh()


# --- The player's keys. ---

## U: run the loaded breaker, on the next physics step.
func press_run() -> void:
	_run_pressed = true


## Y: load the next kind, on the next physics step.
func press_cycle() -> void:
	_cycle_pressed = true


func _take_presses() -> void:
	var run := _run_pressed
	var cycle := _cycle_pressed
	_run_pressed = false
	_cycle_pressed = false
	if mode == Mode.OFF or not _player_can():
		return
	if cycle:
		mine.cycle()
		_play("cycle")
		loaded_changed.emit(mine.loaded)
	if not run or _clock - _last_press < tuning.use_gap_s:
		return
	var kind := mine.loaded
	if mine.count(kind) <= 0:
		_play("empty")
		empty.emit(kind)
		return
	_last_press = _clock
	var eye: Vector3 = player.eye_position()
	var aim: Vector3 = player.aim_direction()
	if mode == Mode.RUN:
		use(my_id(), kind, eye, aim)
	elif session.has_method("breaker_intent"):
		session.breaker_intent(kind, eye, aim)  # only a request: the host decides


func _player_can() -> bool:
	return player != null and is_instance_valid(player) and player.get("alive") != false and player.get("input_blocked") != true


# --- Running one (deciding). ---

## Intruder `id` runs a breaker of `kind` from its eye `eye` along `aim` (world space): spent and done
## when it holds one, is alive and its last run was use_gap_s ago. True when it ran.
func use(id: int, kind: int, eye: Vector3, aim: Vector3) -> bool:
	if mode != Mode.RUN or not Kinds.valid(kind) or not eye.is_finite() or not aim.is_finite() or aim.length_squared() < 0.0001:
		return false
	var b: Breakers = loadouts.get(id)
	if b == null or daemons == null or not daemons.prey_valid(id):
		return false
	if _clock - float(_last_use.get(id, -INF)) < tuning.use_gap_s or not b.take(kind):
		return false
	_last_use[id] = _clock
	runs[kind] += 1
	_run_serial[id] = int(_run_serial.get(id, 0)) + 1
	_run_kind[id] = kind
	aim = aim.normalized()
	match kind:
		Kinds.Kind.BRUTE:
			fired(id)  # an attack: a cloak ends
			_brute(id, eye, aim)
		Kinds.Kind.EXPLOIT:
			exploit_left[id] = tuning.exploit_s
		Kinds.Kind.CLOAK:
			cloak_left[id] = tuning.cloak_s
		Kinds.Kind.DECOY:
			_throw_decoy(id, eye, aim)
	if id == my_id():
		_ran_here(kind)
	return true


func _ran_here(kind: int) -> void:
	_play(Kinds.name_of(kind))
	ran.emit(kind)


## The brute's charge from `eye` along `aim`: every piece of ICE standing and every daemon alive whose
## nearest point is within reach and inside the cone, with nothing of the level between, takes the
## charge's damage at its distance's strength (a wall brute_wall_scale times it, through ICE's director's
## brute hook). How many it reached.
func _brute(id: int, eye: Vector3, aim: Vector3) -> int:
	brute_serial += 1
	brute_from = _to_arena(eye)
	brute_way = (_arena_basis().inverse() * aim).normalized()
	_brute_fx(eye, aim)
	var hits := 0
	var space := get_world_3d().direct_space_state
	var mine_here := id == my_id()
	if ice != null and ice.decides():
		for piece in ice.pieces():
			if piece.broken:
				continue
			var point: Vector3 = piece.blast_point(eye)
			var amount := tuning.brute_damage * brute_strength(eye, aim, point)
			if amount <= 0.0 or not _clear(space, eye, point):
				continue
			if (piece.hit(amount, point, aim, IceDirector.BRUTE) if mine_here else piece.hit_by_other(amount, point, aim, id, IceDirector.BRUTE)):
				hits += 1
	if daemons != null and daemons.runs():
		for brain in daemons.brains():
			var dummy: Node3D = brain.dummy
			if not dummy.is_alive():
				continue
			var middle := dummy.global_position + Vector3.UP * MIDDLE_M
			var amount := tuning.brute_damage * brute_strength(eye, aim, middle)
			if amount <= 0.0 or not _clear(space, eye, middle):
				continue
			var landed: bool = dummy.hit(amount, middle, aim, IceDirector.BRUTE) if mine_here or not _online() else session.breaker_hit_daemon(dummy, id, amount, middle, aim, IceDirector.BRUTE)
			if landed:
				hits += 1
	last_brute_hits = hits
	return hits


## How much of the brute's charge from `eye` along `aim` reaches `point`: 1 within brute_full_m, down to
## brute_far_share at brute_reach_m, 0 past it or outside the cone.
func brute_strength(eye: Vector3, aim: Vector3, point: Vector3) -> float:
	var way := point - eye
	var gap := way.length()
	if gap > tuning.brute_reach_m or not point.is_finite():
		return 0.0
	if gap > 0.001 and way.normalized().dot(aim.normalized()) < cos(deg_to_rad(tuning.brute_cone_deg)):
		return 0.0
	if gap <= tuning.brute_full_m:
		return 1.0
	var u := (gap - tuning.brute_full_m) / maxf(tuning.brute_reach_m - tuning.brute_full_m, 0.001)
	return lerpf(1.0, tuning.brute_far_share, u)


func _clear(space: PhysicsDirectSpaceState3D, eye: Vector3, point: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(eye + Vector3.UP * SIGHT_LIFT_M, point, LEVEL_MASK)).is_empty()


## The charge as every screen draws it: a ring of ultraviolet streaks out from in front of the eye and a
## burst where it is thrown.
func _brute_fx(eye: Vector3, aim: Vector3) -> void:
	var fx := ParticleFx.of(self)
	if fx != null:
		var front := eye + aim * (tuning.brute_full_m * 0.8)
		fx.blast(front, Palette.BREAKER, tuning.brute_reach_m)
		fx.ping(eye + aim * 0.6 + Vector3.DOWN * 0.4, Palette.BREAKER, tuning.brute_reach_m, 0.35)


# --- The decoys. ---

func _throw_decoy(id: int, eye: Vector3, aim: Vector3) -> void:
	var slot := _free_decoy_slot()
	_drop_decoy(slot, true)
	var from := eye + aim * THROW_AHEAD_M
	var space := get_world_3d().direct_space_state
	var probe := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, from, LEVEL_MASK))
	if not probe.is_empty():
		from = probe["position"] - aim * 0.1
	var d := _make_decoy(slot, id, _decoy_seed(slot), true)
	d.launch(from, aim)
	decoys_thrown += 1


func _free_decoy_slot() -> int:
	var oldest := 0
	var oldest_left := INF
	for slot in DECOYS_LAST:
		var d: Decoy = decoys[slot]
		if d == null or not is_instance_valid(d) or not d.live():
			return slot
		var left := d.left if d.landed else INF
		if left < oldest_left:
			oldest_left = left
			oldest = slot
	return oldest


func _decoy_seed(slot: int) -> int:
	if Dummy.fixed_seeds:
		return DaemonArt.seed_of("decoy:%d:%d" % [slot, decoys_thrown])
	return _rng.randi() & DaemonArt.SEED_LAST


func _make_decoy(slot: int, thrower: int, seed: int, deciding: bool) -> Decoy:
	var d := Decoy.new()
	d.name = "Decoy%d" % slot
	d.slot = slot
	d.thrower = thrower
	d.spawn_seed = seed
	d.tuning = tuning
	d.deciding = deciding
	add_child(d)
	decoys[slot] = d
	return d


func _drop_decoy(slot: int, burst: bool) -> void:
	var d = decoys[slot] if slot < decoys.size() else null
	if d != null and is_instance_valid(d):
		if burst:
			d.expire()
		else:
			d.queue_free()
	if slot < decoys.size():
		decoys[slot] = null


func _step_decoys() -> void:
	for slot in DECOYS_LAST:
		var d: Decoy = decoys[slot]
		if d != null and is_instance_valid(d) and not d.live():
			_drop_decoy(slot, true)


## The decoys calling now (landed, call left).
func calling() -> Array:
	var out := []
	for d in decoys:
		if d != null and is_instance_valid(d) and d.calling():
			out.append(d)
	return out


## The prey id of the decoy in `slot` (-1 minus the slot), and the slot of a prey id (-1 for none).
static func decoy_id(slot: int) -> int:
	return DECOY_FIRST - slot


static func decoy_slot(id: int) -> int:
	var slot := DECOY_FIRST - id
	return slot if id < 0 and slot >= 0 and slot < DECOYS_LAST else -1


## The decoy that prey id `id` names, calling, or null.
func decoy_of(id: int) -> Decoy:
	var slot := decoy_slot(id)
	if slot < 0:
		return null
	var d = decoys[slot]
	return d if d != null and is_instance_valid(d) and d.calling() else null


## The ids of the decoys calling now, as prey.
func decoy_ids() -> Array:
	var out := []
	for slot in DECOYS_LAST:
		var d = decoys[slot]
		if d != null and is_instance_valid(d) and d.calling():
			out.append(decoy_id(slot))
	return out


## The nearest decoy calling within `range_m` of `from` (world space): its prey id, or 0 for none. Its
## call needs no sight: it is a call.
func lure(from: Vector3, range_m: float) -> int:
	var best := 0
	var best_d := INF
	for slot in DECOYS_LAST:
		var d = decoys[slot]
		if d == null or not is_instance_valid(d) or not d.calling():
			continue
		var gap: float = from.distance_to(d.point())
		if gap <= range_m and gap < best_d:
			best = decoy_id(slot)
			best_d = gap
	return best


## Something struck the decoy `id` names from `from` (world space): it flashes. True when one is there.
func strike_decoy(id: int, from: Vector3) -> bool:
	var d := decoy_of(id)
	if d == null:
		return false
	d.strike(from)
	return true


# --- exploit and cloak (deciding; a joiner shows its own from the host's word). ---

## True while intruder `id` cannot be seen by ICE or the daemons.
func cloaked(id: int) -> bool:
	if mode == Mode.RUN:
		return float(cloak_left.get(id, 0.0)) > 0.0
	return mode == Mode.FOLLOW and id == my_id() and my_cloak > 0.0


## Intruder `id` fired or threw (or ran a brute): its cloak ends now.
func fired(id: int) -> void:
	if mode == Mode.RUN and float(cloak_left.get(id, 0.0)) > 0.0:
		cloak_left[id] = 0.0


## Alone, this player's own shot or throw (its fire_intent and throw_intent): in a match the host's
## session tells fired() itself, for every intruder.
func _fired_alone() -> void:
	if not _online():
		fired(1)


## True while this player's exploit runs (on this screen): what its seam marks show.
func exploit_on_me() -> bool:
	return mode != Mode.OFF and my_exploit > 0.0


## How many times harder a hit of `damage` from intruder `shooter` with weapon `source` lands on
## `target` (a daemon or a piece of ICE) at `point` (world space): the tuning's exploit_scale while that
## intruder's exploit runs and the hit is a direct one (no blast) within exploit_radius_m of one of the
## target's weak seams at its size, else 1. Deciding only.
func exploit_scale(shooter: int, target: Node, point: Vector3, source: String) -> float:
	if mode != Mode.RUN or float(exploit_left.get(shooter, 0.0)) <= 0.0 or not point.is_finite() or not direct(source):
		return 1.0
	var art: DaemonArt = _art_of(target)
	if art == null or not art.is_inside_tree():
		return 1.0
	var xf := art.global_transform
	var radius := tuning.exploit_radius_m * xf.basis.get_scale().x
	for p in art.weak_points():
		if (xf * p).distance_to(point) <= radius:
			return tuning.exploit_scale
	return 1.0


## True for a weapon whose hits land where they strike (a ray, a pellet, a dart): exploit counts those,
## never a blast's (the fork bomb, rm -rf's slug, a cron mine) nor a breaker's.
static func direct(source: String) -> bool:
	if source == "" or Kinds.is_source(source):
		return false
	var def = _weapon(source)
	return def != null and not def.is_thrown() and not def.is_slug() and not def.is_mine() and not def.is_ping()


static var _weapons := {}


static func _weapon(id: String) -> Resource:
	if _weapons.is_empty():
		var arsenal := load("res://resources/arsenal.tres") as ArsenalTuning
		if arsenal != null:
			for def in arsenal.loadout:
				_weapons[def.id] = def
	return _weapons.get(id)


func _art_of(target: Node) -> DaemonArt:
	if target == null or not is_instance_valid(target):
		return null
	if target.has_method("art_node"):
		return target.art_node()
	var art = target.get("art")
	return art as DaemonArt


## Every art whose weak seams exploit's marks show: the daemons alive and the pieces of ICE standing, in
## this arena.
func marked_arts() -> Array:
	var out := []
	if daemons != null:
		for brain in daemons.brains():
			if brain.dummy.is_alive() and brain.dummy.has_method("art_node"):
				var art: DaemonArt = brain.dummy.art_node()
				if art != null and art.is_visible_in_tree():
					out.append(art)
	if ice != null and ice.mode != IceDirector.Mode.OFF:
		for piece in ice.pieces():
			if not piece.broken and piece.art != null and piece.art.is_visible_in_tree():
				out.append(piece.art)
	return out


# --- The pickups. ---

func _step_pickups(delta: float) -> void:
	var live := 0
	for spot in spots.size():
		if pickups[spot] != null and is_instance_valid(pickups[spot]):
			live += 1
	_pickup_wait -= delta
	if _pickup_wait <= 0.0:
		_pickup_wait += tuning.pickup_every_s
		if live < tuning.pickups_live:
			_lay_pickup()
	# Whoever walks over one takes it, unless that kind is at their cap.
	for spot in spots.size():
		var p: BreakerPickup = pickups[spot]
		if p == null or not is_instance_valid(p):
			continue
		for id in loadouts:
			if not daemons.prey_valid(id):
				continue
			var at: Vector3 = daemons.prey_point(id)
			var feet := p.global_position + Vector3.UP * MIDDLE_M
			if at.distance_to(feet) <= tuning.pickup_take_m and (loadouts[id] as Breakers).add(p.kind):
				pickups_taken += 1
				_pick_serial[id] = int(_pick_serial.get(id, 0)) + 1
				_pick_kind[id] = p.kind
				if id == my_id():
					_play("pickup")
					picked.emit(p.kind)
				_drop_pickup(spot, true)
				break


## A pickup of a seeded kind at a seeded free spot.
func _lay_pickup() -> void:
	var free := []
	for spot in spots.size():
		if pickups[spot] == null or not is_instance_valid(pickups[spot]):
			free.append(spot)
	if free.is_empty():
		return
	var spot: int = free[_rng.randi() % free.size()]
	var kind := _rng.randi() % Kinds.NAMES.size()
	_make_pickup(spot, kind)
	pickups_made += 1


## A pickup of `kind` at `spot`, built from `seed` (below 0: fixed by its spot and kind in demo, test and
## capture runs, else a new one; a joiner's is the host's).
func _make_pickup(spot: int, kind: int, seed: int = -1) -> BreakerPickup:
	_drop_pickup(spot, false)
	var p := BreakerPickup.new()
	p.name = "Pickup%d" % spot
	p.kind = kind
	p.spot = spot
	if seed < 0:
		seed = DaemonArt.seed_of("pickup:%d:%d" % [spot, kind]) if Dummy.fixed_seeds else _rng.randi() & DaemonArt.SEED_LAST
	p.spawn_seed = seed
	add_child(p)
	p.global_position = _to_world(spots[spot])
	pickups[spot] = p
	return p


func _drop_pickup(spot: int, taken: bool) -> void:
	var p = pickups[spot] if spot < pickups.size() else null
	if p != null and is_instance_valid(p):
		if taken:
			p.taken()
		else:
			p.queue_free()
	if spot < pickups.size():
		pickups[spot] = null


## The pickups out now: spot -> kind.
func pickups_out() -> Dictionary:
	var out := {}
	for spot in spots.size():
		var p = pickups[spot]
		if p != null and is_instance_valid(p):
			out[spot] = p.kind
	return out


## A test or a still's: a pickup of `kind` at spot `spot` now (deciding).
func lay_pickup_at(spot: int, kind: int) -> BreakerPickup:
	if mode != Mode.RUN or spot < 0 or spot >= spots.size() or not Kinds.valid(kind):
		return null
	pickups_made += 1
	return _make_pickup(spot, kind)


# --- Each step. ---

func _physics_process(delta: float) -> void:
	_mode_now()
	_clock += delta
	if mode == Mode.OFF:
		_run_pressed = false  # a press with breakers off is dropped, never kept for later
		_cycle_pressed = false
		return
	if mode == Mode.RUN:
		_sync_players()
		for id in exploit_left.keys():
			exploit_left[id] = maxf(float(exploit_left[id]) - delta, 0.0)
		for id in cloak_left.keys():
			cloak_left[id] = maxf(float(cloak_left[id]) - delta, 0.0)
		for id in loadouts:
			if not daemons.prey_valid(id):
				exploit_left[id] = 0.0  # a death ends both
				cloak_left[id] = 0.0
		_step_decoys()
		_step_pickups(delta)
		my_exploit = float(exploit_left.get(my_id(), 0.0))
		my_cloak = float(cloak_left.get(my_id(), 0.0))
	else:
		my_exploit = maxf(my_exploit - delta, 0.0)
		my_cloak = maxf(my_cloak - delta, 0.0)
	if _was_cloaked and my_cloak <= 0.0:
		_play("uncloak")
		cloak_ended.emit()
	_was_cloaked = my_cloak > 0.0
	_take_presses()


## Deciding: a loadout for every intruder in the match (a fresh one for a joiner just in), none for one
## gone.
func _sync_players() -> void:
	var ids: Array = session.players.keys() if _online() else [1]
	for id in ids:
		if not loadouts.has(id):
			loadouts[id] = mine if id == my_id() else Breakers.new(tuning.start_count, tuning.carry_cap)
	for id in loadouts.keys():
		if not ids.has(id):
			loadouts.erase(id)
			exploit_left.erase(id)
			cloak_left.erase(id)


# --- The host's word (a match). ---

## The host's word for joiner `id`: its own counts, its exploit and cloak seconds left; every decoy
## (arena space, its call left, landed); every pickup spot's kind (0 none, else 1 + its kind); the last
## brute charge (its count, from, way); its own last run and pickup (each a count and its kind), so its
## screen says so; and every decoy's and pickup's seed, so its screen builds the host's.
func word_for(id: int) -> Dictionary:
	var b: Breakers = loadouts.get(id)
	var counts := b.bytes() if b != null else PackedByteArray([0, 0, 0, 0])
	var timers := PackedFloat32Array([float(exploit_left.get(id, 0.0)), float(cloak_left.get(id, 0.0))])
	var ds := PackedFloat32Array()
	for slot in DECOYS_LAST:
		var d = decoys[slot]
		if d != null and is_instance_valid(d) and d.live():
			var at := _to_arena(d.global_position)
			ds.append_array([at.x, at.y, at.z, d.left, 1.0 if d.landed else 0.0])
		else:
			ds.append_array([0.0, 0.0, 0.0, 0.0, -1.0])
	var ps := PackedByteArray()
	for spot in spots.size():
		var p = pickups[spot]
		ps.append(1 + p.kind if p != null and is_instance_valid(p) else 0)
	var brute := PackedFloat32Array([float(brute_serial), brute_from.x, brute_from.y, brute_from.z, brute_way.x, brute_way.y, brute_way.z])
	var ran := PackedInt32Array([int(_run_serial.get(id, 0)), int(_run_kind.get(id, 0)), int(_pick_serial.get(id, 0)), int(_pick_kind.get(id, 0))])
	var seeds := PackedInt32Array()
	for d in decoys:
		seeds.append(d.spawn_seed if d != null and is_instance_valid(d) else 0)
	for p in pickups:
		seeds.append(p.spawn_seed if p != null and is_instance_valid(p) else 0)
	return {"counts": counts, "timers": timers, "decoys": ds, "pickups": ps, "brute": brute, "ran": ran, "seeds": seeds}


## The host's word on a joiner (the session has checked its shape): this player's counts, exploit and
## cloak; its own run or pickup new since the last word, said here; the decoys placed where the host's
## are and the pickups laid or taken, each built from the host's seed; a new brute charge drawn.
func take_word(counts: PackedByteArray, timers: PackedFloat32Array, ds: PackedFloat32Array, ps: PackedByteArray, brute: PackedFloat32Array, ran: PackedInt32Array, seeds: PackedInt32Array) -> void:
	if mode != Mode.FOLLOW:
		return
	words_taken += 1
	mine.take_bytes(counts)
	my_exploit = timers[0]
	my_cloak = timers[1]
	# This player's own run and pickup as the host saw them: the sound and the HUD's word here (the first
	# word only says where the counts stand).
	if _word_seen and ran[0] != _ran_seen and Kinds.valid(ran[1]):
		_ran_here(ran[1])
	if _word_seen and ran[2] != _picked_seen and Kinds.valid(ran[3]):
		_play("pickup")
		picked.emit(ran[3])
	_ran_seen = ran[0]
	_picked_seen = ran[2]
	_word_seen = true
	for slot in DECOYS_LAST:
		var i := slot * DECOY_WORD
		var landed := ds[i + 4]
		var d: Decoy = decoys[slot]
		if landed < 0.0:
			if d != null and is_instance_valid(d):
				_drop_decoy(slot, true)
			continue
		var at := _to_world(Vector3(ds[i], ds[i + 1], ds[i + 2]))
		if d == null or not is_instance_valid(d) or d.spawn_seed != seeds[slot]:
			_drop_decoy(slot, false)
			d = _make_decoy(slot, 0, seeds[slot], false)
		d.take_word(at, landed > 0.5, ds[i + 3])
	for spot in spots.size():
		var kind := int(ps[spot]) - 1
		var p: BreakerPickup = pickups[spot]
		var has := p != null and is_instance_valid(p)
		var seed := seeds[DECOYS_LAST + spot]
		if kind < 0 and has:
			_drop_pickup(spot, true)
		elif kind >= 0 and (not has or p.kind != kind or p.spawn_seed != seed):
			_make_pickup(spot, kind, seed)
	# A charge new since the last word is drawn here; the first word only says where the count stands.
	var serial := int(brute[0])
	if _brute_seen and serial != _brutes_drawn:
		_brute_fx(_to_world(Vector3(brute[1], brute[2], brute[3])), (_arena_basis() * Vector3(brute[4], brute[5], brute[6])).normalized())
	_brutes_drawn = serial
	_brute_seen = true


## Hosting: joiner `id` asks to run a breaker of `kind` along `aim` (world space); its eye is where the
## host last heard it was. True when it ran.
func handle_intent(id: int, kind: int, eye: Vector3, aim: Vector3) -> bool:
	return use(id, kind, eye, aim)


# --- Its parts. ---

func _arena() -> Node3D:
	return daemons.get("_arena") if daemons != null else null


func _to_arena(world: Vector3) -> Vector3:
	return daemons.to_arena(world) if daemons != null else world


func _to_world(local: Vector3) -> Vector3:
	return daemons.to_world(local) if daemons != null else local


func _arena_basis() -> Basis:
	var arena := _arena()
	return arena.global_transform.basis if arena != null else Basis.IDENTITY


func _play(word: String) -> void:
	var p: AudioStreamPlayer = _sfx.get(word)
	if p != null:
		p.play()


## True in the last cloak_warn_s of this player's cloak: the HUD's warning that it is about to end.
func cloak_warning() -> bool:
	return my_cloak > 0.0 and my_cloak <= tuning.cloak_warn_s
