class_name IceDirector
extends Node3D
## ICE (I1): William Gibson's intrusion countermeasure electronics, the system defending itself
## against the player, the intruder. A new enemy class beside the daemons: white ICE (walls that seal
## a doorway and a corridor of the arena until enough damage breaks them, and two nodes whose fields
## jam a weapon or corrupt the HUD) from round 1, and hunter ICE (scripts/ice/hunter_ice.gd: it hunts
## by sight and adapts to the weapon used most) from round 2. One of these lives beside the arena
## (main.gd makes it, next to the daemons' director): it builds every piece at its place each round
## from new seeds (fixed by name in demo, test and capture runs), steps them, judges what lands on
## them, keeps the round's adaptation, puts the fields' effects on the players, and in a match is the
## host's word on all of it.
##
## Its mode: RUN alone or hosting (it decides), FOLLOW on a joiner (its pieces play the host's word
## and judge nothing; the host judges every shot at them and sends its word, take_word()), OFF in
## practice or with the ICE setting off (no piece at all: nothing seals, jams or hunts). Alone the
## settings decide; in a match the host's (its practice and its ICE setting, as its difficulty).
##
## Adaptation: every hit that lands on the system (a daemon or a piece of ICE) notes its weapon's
## damage for the round, each hit counted up to the tuning's hit_cap (the most any one hit takes off
## ICE), so a rail's 1000 counts as 100. The hunter resists the weapon with the most, adapt_max times
## its share of adapt_full_damage (never more than adapt_max: never immunity), and its shields shift
## toward that weapon's colour; the HUD shows "HUNTER ADAPTED: <weapon> -NN%". In a match it learns
## from every intruder's hits together (the host judges them all). A new round forgets it, and so does a
## SIGHUP that confuses the hunter (C32, forget_learning()).
##
## Fields: a node's field reaches the intruders inside its dome when its tell ends (scripts/ice/
## ice_node.gd). Alone, this player; hosting, each player in it: the host's own here, a joiner's by
## the session's word to that joiner (session.ice_effect()), the host remembering a joiner's jam so
## it refuses that weapon's shots until it clears. A jam (jam_s) locks the weapon in hand (the others
## still swap in and fire); a corruption (hud_s) scrambles parts of the HUD, never the health line.
##
## Black ICE (I3, scripts/ice/black_ice.gd): the machine's last line of defence, rare: each round from
## its tuning's from_round (never round 1) its chance is rolled once, seeded (fixed by the round in demo,
## test and capture runs), and when it comes it arrives at a seeded moment of the round's play, at the one
## of BLACK_SPOTS farthest from every intruder. At most one a round: a broken one never comes back that
## round, and the round's end withdraws one still out. This director steps it, judges every intruder's
## middle against its touch each step (a touch flatlines: alone, life.flatline() ends the run; hosting,
## the session's black_ice_flatline() takes the intruder out for the rest of the round) and sends the
## host's word on it. Its darkness (the lights, the hum) and its cut of the guide's link are read here by
## scripts/ice/blackout.gd and the HUD. Its numbers: resources/black_ice.tres (BlackIceTuning).
##
## Everything is simulated: ICE reads nothing real and touches nothing real.

const Dummy = preload("res://scripts/target_dummy.gd")
const Palette = preload("res://scripts/palette.gd")
const ForkBomb = preload("res://scripts/weapons/fork_bomb.gd")

const GROUP := &"ice_director"
const NODE_NAME := "IceDirector"
## Every piece of ICE joins this group: the host judges joiners' shots at them, blasts reach them.
const PIECES := &"ice"
const TUNING_PATH := "res://resources/ice.tres"
## Where Black ICE may arrive (arena space, open floor at least 5.8 m from every spawn): the one farthest
## from the nearest intruder.
const BLACK_SPOTS := [Vector3(16.0, 0.0, -4.0), Vector3(-13.0, 0.0, -7.0), Vector3(11.0, 0.0, -9.0), Vector3(3.0, 0.0, -3.0), Vector3(-6.0, 0.0, 17.0)]
## A flatline's cause, as the death line and the feed name it.
const BLACK_NAME := "Black ICE"
## The host's word on Black ICE: how many numbers (black_word()).
const BLACK_WORD := 13
## A piece's word: its state in bits 0 to 2, chmod 000's freeze meter in bits 3 to 6 (Frost.BITS, C29),
## SIGSTOP's hold in bit 7.
const STATE_BITS := 0x07
const ARSENAL_PATH := "res://resources/arsenal.tres"
enum Mode { OFF, RUN, FOLLOW }
## A field's effect on a player: its weapon jammed, its HUD corrupted.
enum Effect { JAM, HUD }
## The layout, in arena space. Walls: name, the middle of its foot, its yaw, its opening (width,
## height). The gate seals the room's doorway (between its posts); the wall seals the west corridor's
## north end (between the west wall and the cover).
const WALLS := [["gate", Vector3(0.0, 0.0, -8.0), 0.0, Vector2(2.7, 3.5)], ["wall", Vector3(-17.6, 0.0, 8.0), 0.0, Vector2(4.8, 3.0)]]
## Nodes: name, place, kind. The jam node guards the gate; the HUD node stands south of the corridor.
const NODES := [["jam", Vector3(-4.5, 0.0, -4.5), "jam"], ["hud", Vector3(-17.5, 0.0, -2.0), "hud"]]
## The hunter's post, and the point it faces from there.
const HUNTER_POST := Vector3(10.0, 0.0, -4.0)
const HUNTER_FACES := Vector3(0.0, 0.0, 5.0)
## The pieces in the host's word, in order: the walls, the nodes, the hunter.
const PIECE_COUNT := 4 + 1
## A hunter's word when there is none.
const NO_HUNTER := 0xFF
## The hunter's place in the host's word: its place, yaw, aim, reach, and (C32) its confusion.
const HUNTER_WORD := 9
## The brute ICEbreaker's hits (I2, scripts/ice/breaker_director.gd): past the hit cap (its own tuning
## caps it), a wall taking brute_wall_scale times them, never resisted, never noted for the adaptation.
const BRUTE := "breaker:brute"
## How far toward an adapted weapon's colour the hunter's shields go at the most.
const TINT_SHARE := 0.85
## The hunter's adaptation as the HUD writes it.
const ADAPT_LINE := "HUNTER ADAPTED: %s -%d%%"

## This player's own field effects as they land: Effect, seconds.
signal effect_fired(kind: int, seconds: float)
## Black ICE arrived (I3): its tell has begun, on this screen.
signal black_arrived
## An intruder touched Black ICE and flatlined (deciding): its id.
signal flatlined(id: int)

## An IceTuning; null for resources/ice.tres. Set before the node enters the tree.
var tuning: IceTuning
## The daemons' director (who the intruders are, where, sight, the attacker cap, the combat path),
## the local player, its solo life, the session beside the arena (null alone) and the round HUD.
## Set by main.gd.
var daemons: Node = null
var player: Node3D = null
var life: Node = null
var session: Node = null
var rounds: Node = null
## The ICEbreakers' director (I2): who is cloaked, where the decoys call, whose exploit runs. Set by
## main.gd; null runs ICE as I1 did.
var breakers: Node = null
## How many times harder a wall takes the brute's charge (the breaker tuning's, set by its director).
var brute_wall_scale := 5.0
## A BlackIceTuning; null for resources/black_ice.tres. Set before the node enters the tree.
var black_tuning: BlackIceTuning
var mode: Mode = Mode.OFF
var round_number := 1

var walls: Array[IceBarrier] = []
var nodes: Array[IceNode] = []
## The hunter now (null before its round, or once its replacement is due), and the wait before a
## killed one's replacement comes.
var hunter: HunterIce = null
var hunter_wait := 0.0
## Hunters spawned and killed since this director was made, for the checks.
var hunters_made := 0
var hunters_killed := 0

## Damage each weapon has dealt to the system this round, weapon id -> health points.
var ledger := {}
var adapt_weapon := ""
var adapt := 0.0
## Times SIGHUP made the hunter forget what it learned this run (C32), for the checks.
var forgets := 0
## This player's HUD corruption: seconds left; and the effects that reached this player.
var corrupt_left := 0.0
var jams_on_me := 0
var corruptions_on_me := 0
## Host: each joiner's jam, id -> [weapon id, seconds left].
var _jams := {}
## Black ICE (I3): the one in the arena now (null for none); this round's plan, its arrival in seconds
## of the round's play (-1 for none this round); the round's play so far; and, for the checks, how many
## came, were broken and withdrew since this director was made, and the flatlines.
var black: BlackIce = null
var black_plan := -1.0
var round_t := 0.0
var blacks_made := 0
var blacks_killed := 0
var blacks_withdrawn := 0
var flatlines := 0
## True once Black ICE has flatlined this machine's own player this round.
var _flatlined_me := false
## True once Black ICE came this round (C33: a round survived with it out earns a feat).
var _black_came := false
## Black ICE's sounds, made once, at the start of the first round it can come in (about 150 ms of
## synthesis, at a round's start rather than at its arrival): word -> AudioStreamWAV.
var _black_sounds := {}

var _rng := RandomNumberGenerator.new()
var _weapons := {}
static var _field_mat: ShaderMaterial


static func of(node: Node) -> IceDirector:
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
	tuning = IceTuning.usable(tuning)
	black_tuning = BlackIceTuning.usable(black_tuning)
	_rng.randomize()
	var arsenal := load(ARSENAL_PATH) as ArsenalTuning
	if arsenal != null:
		for def in arsenal.loadout:
			_weapons[def.id] = def
	if rounds != null and rounds.get("stats") != null:
		round_number = rounds.stats.round_number
	if rounds != null and rounds.has_signal("round_started"):
		rounds.round_started.connect(start_round)
	if rounds != null and rounds.has_signal("round_ended"):
		rounds.round_ended.connect(_on_round_ended)
	_mode_now()


## The field domes' one material, every node's.
func field_material() -> ShaderMaterial:
	if _field_mat == null:
		_field_mat = Palette.ice_field_material()
	return _field_mat


# --- Its mode. ---

## True while ICE is on: not practice, and the ICE setting on (alone and hosting, the settings'; on a
## joiner, the host's word).
func ice_on() -> bool:
	if _online() and not session.is_hosting():
		return session.host_practice != true and session.host_ice == true
	var s := GameSettings.current()
	return s.value("gameplay", "practice") != true and s.value("gameplay", "ice") == true


## True while this machine decides: alone or hosting, ICE on.
func decides() -> bool:
	return mode == Mode.RUN


func follows() -> bool:
	return mode == Mode.FOLLOW


func _online() -> bool:
	return session != null and is_instance_valid(session) and session.is_online()


func _mode_now() -> void:
	var next := Mode.OFF
	if ice_on():
		next = Mode.FOLLOW if _online() and not session.is_hosting() else Mode.RUN
	if next == mode:
		return
	mode = next
	clear_effects()
	_jams.clear()
	_forget()
	_build_round()


# --- Rounds. ---

## Round `number` starts (the round HUD's word): the adaptation forgotten and, deciding, every piece
## built again from new seeds, a hunter at its post from its round on.
func start_round(number: int) -> void:
	round_number = maxi(number, 1)
	_forget()
	if mode == Mode.RUN:
		_build_round()
		black_plan = black_arrival(round_number)
	if mode != Mode.OFF and black_tuning.chance(round_number) > 0.0:
		prepare_black_sounds()  # once, at the first round it can come in: never a hitch at its arrival
	round_t = 0.0
	_flatlined_me = false
	_black_came = false


func _forget() -> void:
	ledger.clear()
	_set_adapt("", 0.0)


func _build_round() -> void:
	_clear_pieces()
	black_plan = -1.0
	if mode == Mode.OFF:
		return
	for i in WALLS.size():
		walls.append(_make_wall(i, _seed_for(WALLS[i][0])))
	for i in NODES.size():
		nodes.append(_make_node(i, _seed_for(NODES[i][0])))
	hunter_wait = 0.0
	if mode == Mode.RUN and round_number >= tuning.hunter_from_round:
		_spawn_hunter(_seed_for("hunter"))


## A piece's seed: fixed by its name in demo, test and capture runs (and placeholders on a joiner until
## the host's word), else a new one each build.
func _seed_for(piece: String) -> int:
	if Dummy.fixed_seeds or mode == Mode.FOLLOW:
		return DaemonArt.seed_of("ice:" + piece)
	return _rng.randi() & DaemonArt.SEED_LAST


func _make_wall(i: int, seed: int) -> IceBarrier:
	var w := IceBarrier.new()
	w.name = "Ice" + String(WALLS[i][0]).capitalize()
	w.piece_name = WALLS[i][0]
	w.span = WALLS[i][3]
	w.spawn_seed = seed
	w.max_health = tuning.barrier_health
	w.director = self
	w.position = WALLS[i][1]
	w.rotation.y = WALLS[i][2]
	w.add_to_group(PIECES)
	add_child(w)
	return w


func _make_node(i: int, seed: int) -> IceNode:
	var n := IceNode.new()
	n.name = "IceNode" + String(NODES[i][0]).capitalize()
	n.piece_name = NODES[i][0]
	n.kind = NODES[i][2]
	n.spawn_seed = seed
	n.tuning = tuning
	n.max_health = tuning.node_health
	n.director = self
	n.position = NODES[i][1]
	n.add_to_group(PIECES)
	add_child(n)
	return n


func _spawn_hunter(seed: int) -> void:
	if hunter != null and is_instance_valid(hunter):
		_drop_hunter()
	var h := HunterIce.new()
	h.name = "HunterIce"
	h.piece_name = "hunter"
	h.spawn_seed = seed
	h.tuning = tuning
	h.max_health = tuning.hunter_health
	h.director = self
	h.position = HUNTER_POST
	var way := HUNTER_FACES - HUNTER_POST
	h.rotation.y = atan2(-way.x, -way.z)
	h.add_to_group(PIECES)
	add_child(h)
	h.broke.connect(_on_hunter_broke)
	h.tint_to(adapt_color())
	hunter = h
	hunters_made += 1


func _drop_hunter() -> void:
	if hunter != null and is_instance_valid(hunter):
		if hunter.brain != null and daemons != null:
			hunter.brain._release(daemons)
		hunter.remove_from_group(PIECES)
		hunter.queue_free()
	hunter = null


func _on_hunter_broke(_piece: Node3D) -> void:
	hunters_killed += 1
	hunter_wait = tuning.hunter_respawn_s
	if hunter != null and hunter.brain != null and daemons != null:
		hunter.brain._release(daemons)


func _clear_pieces() -> void:
	for piece in pieces():
		piece.remove_from_group(PIECES)
		piece.queue_free()
	walls.clear()
	nodes.clear()
	hunter = null
	hunter_wait = 0.0
	black = null


## Every piece of ICE now, broken ones included: the walls, the nodes, the hunter, Black ICE.
func pieces() -> Array:
	var out: Array = []
	out.append_array(walls)
	out.append_array(nodes)
	if hunter != null and is_instance_valid(hunter):
		out.append(hunter)
	if black != null and is_instance_valid(black):
		out.append(black)
	return out


func wall(piece: String) -> IceBarrier:
	for w in walls:
		if w.piece_name == piece:
			return w
	return null


func node_of(kind: String) -> IceNode:
	for n in nodes:
		if n.kind == kind:
			return n
	return null


# --- Each step. ---

func _physics_process(delta: float) -> void:
	_mode_now()
	corrupt_left = maxf(corrupt_left - delta, 0.0)
	if not _jams.is_empty():
		for id in _jams.keys():
			_jams[id][1] -= delta
			if _jams[id][1] <= 0.0:
				_jams.erase(id)
	if mode == Mode.OFF or daemons == null:
		return
	if rounds == null or not rounds.has_method("playing") or rounds.playing():
		round_t += delta
	for piece in [hunter] + nodes:
		if piece != null and is_instance_valid(piece) and not piece.broken:
			piece.tick_frost(delta)  # chmod 000's freeze meters (C29)
	if mode == Mode.RUN:
		_step_black(delta)
		for n in nodes:
			n.step(delta, daemons, self)
		if hunter != null and is_instance_valid(hunter):
			hunter.brain.step(delta, daemons)
			if hunter.broken:
				hunter_wait -= delta
				if hunter_wait <= 0.0:
					_spawn_hunter(_seed_for("hunter"))
		elif round_number >= tuning.hunter_from_round:
			_spawn_hunter(_seed_for("hunter"))
		return
	for n in nodes:
		n.follow(delta)
	if hunter != null and is_instance_valid(hunter) and not hunter.broken:
		hunter.brain.follow(delta, daemons)
	if black != null and is_instance_valid(black):
		black.follow(delta, daemons)


# --- Black ICE (I3). ---

## Round `number`'s Black ICE: its arrival, seconds into the round's play, or -1 when none comes. Never
## before the tuning's from_round (never round 1); its chance (BlackIceTuning.chance()) rolled once, and
## the moment between arrive_first_s and arrive_last_s; both fixed by the round in demo, test and capture
## runs, new each round in play.
func black_arrival(number: int) -> float:
	var chance := black_tuning.chance(number)
	if chance <= 0.0:
		return -1.0
	var roll := RandomNumberGenerator.new()
	if Dummy.fixed_seeds:
		roll.seed = DaemonArt.seed_of("black:%d" % number)
	else:
		roll.seed = _rng.randi()
	if roll.randf() >= chance:
		return -1.0
	return lerpf(black_tuning.arrive_first_s, black_tuning.arrive_last_s, roll.randf())


## Black ICE's sound `word`, made the first time it is asked for (Sfx.black_ice).
func black_sound(word: String, seconds: float = 6.0) -> AudioStreamWAV:
	var key := "%s:%.2f" % [word, seconds]
	if not _black_sounds.has(key):
		_black_sounds[key] = BlackIce.Sfx.black_ice(word, seconds)
	return _black_sounds[key]


## Every sound Black ICE makes, made now (before it comes; nothing when they are made already).
func prepare_black_sounds() -> void:
	black_sound("arrive", black_tuning.tell_s)
	for word in ["drone", "crack", "break", "mend", "withdraw"]:
		black_sound(word)


## Black ICE arrives now (deciding), at BLACK_SPOTS[`spot`], or with -1 at the one farthest from the
## nearest intruder, facing the nearest; its seed fixed by the round in demo, test and capture runs. Any
## other one goes first. The one that came.
func summon_black(spot: int = -1) -> BlackIce:
	if mode != Mode.RUN:
		return null
	_drop_black()
	black_plan = -1.0  # at most one a round: this one is the round's
	var at: Vector3 = BLACK_SPOTS[spot] if spot >= 0 and spot < BLACK_SPOTS.size() else black_spot()
	var b := _make_black(_seed_for("black%d" % round_number), at, BlackIce.Phase.ARRIVE)
	var near := _nearest_intruder(b.global_position)
	if near.is_finite():
		var way := near - b.global_position
		b.rotation.y = atan2(-way.x, -way.z)
	return b


func _make_black(seed: int, at: Vector3, phase: int) -> BlackIce:
	var b := BlackIce.new()
	b.name = "BlackIce"
	b.piece_name = "black"
	b.spawn_seed = seed
	b.tuning = black_tuning
	b.director = self
	b.phase = phase
	b.position = at
	b.add_to_group(PIECES)
	add_child(b)
	b.broke.connect(_on_black_broke)
	black = b
	blacks_made += 1
	_black_came = true
	black_arrived.emit()
	return b


## The arrival spot farthest from the nearest living intruder (arena space).
func black_spot() -> Vector3:
	var best: Vector3 = BLACK_SPOTS[0]
	var best_gap := -1.0
	for spot in BLACK_SPOTS:
		var gap := INF
		if daemons != null:
			for id in daemons.prey_ids():
				if id > 0 and daemons.prey_valid(id):
					var p: Vector3 = to_local(daemons.prey_point(id))
					gap = minf(gap, Vector2(p.x - spot.x, p.z - spot.z).length())
		if gap > best_gap:
			best_gap = gap
			best = spot
	return best


func _nearest_intruder(from: Vector3) -> Vector3:
	var best := Vector3.INF
	if daemons == null:
		return best
	for id in daemons.prey_ids():
		if id > 0 and daemons.prey_valid(id):
			var p: Vector3 = daemons.prey_point(id)
			if not best.is_finite() or p.distance_to(from) < best.distance_to(from):
				best = p
	return best


## Each step deciding: this round's Black ICE arriving when its moment comes, stepped, and every
## intruder's middle judged against its touch.
func _step_black(delta: float) -> void:
	if (black == null or not is_instance_valid(black)) and black_plan >= 0.0 and round_t >= black_plan:
		black_plan = -1.0
		summon_black()
	if black == null or not is_instance_valid(black):
		return
	black.step(delta, daemons)
	if black.touching() and daemons != null:
		for id in daemons.prey_ids():
			if id > 0 and daemons.prey_attackable(id) and black.touches(daemons.prey_point(id)):
				flatline(id)
	if black.finished():
		_drop_black()


## Intruder `id` touched Black ICE: flatlined. Alone the run is over (its life's flatline, which ends the
## round as a loss); hosting, the session takes it out for the rest of the round.
func flatline(id: int) -> void:
	flatlines += 1
	if id == (session.my_id if _online() else 1):
		_flatlined_me = true
	var way := Vector3.FORWARD
	if black != null and is_instance_valid(black):
		black.flatlines += 1
		var p: Vector3 = daemons.prey_point(id) if daemons != null else Vector3.INF
		if p.is_finite():
			way = Vector3(p.x - black.global_position.x, 0.0, p.z - black.global_position.z).normalized()
	if _online():
		if session.has_method("black_ice_flatline"):
			session.black_ice_flatline(id, black, way)
	elif id == 1 and life != null and life.has_method("flatline"):
		life.flatline(BLACK_NAME, black, way)
	flatlined.emit(id)


func _on_black_broke(_piece: Node3D) -> void:
	blacks_killed += 1


## The round is over (the round HUD's word): no Black ICE comes now, and one still out withdraws.
func _on_round_ended(_number: int = 0) -> void:
	if _black_came and not flatlined_me():
		Progress.judged_feat(self, "black_ice")  # this player lived through a round with Black ICE out (C33)
	_black_came = false
	black_plan = -1.0
	if mode == Mode.RUN and black != null and is_instance_valid(black) and black.present_now():
		black.withdraw_now()
		blacks_withdrawn += 1


func _drop_black() -> void:
	if black != null and is_instance_valid(black):
		if daemons != null and black.brain != null:
			black.brain._release(daemons)
		black.remove_from_group(PIECES)
		black.queue_free()
	black = null


## True while Black ICE is in the arena from its arrival's first moment until it is broken or withdrawn:
## the guide's link shows cut, the warning stands.
func black_out() -> bool:
	return black != null and is_instance_valid(black) and black.present_now()


## True when Black ICE has flatlined this player this round (on a joiner, the host's word on its death).
func flatlined_me() -> bool:
	if _online() and session.has_method("flatlined") and session.flatlined(session.my_id):
		return true
	return _flatlined_me


## How dark Black ICE makes the arena now, 0 to 1 (scripts/ice/blackout.gd reads it).
func black_darkness() -> float:
	return black.darkness() if black != null and is_instance_valid(black) else 0.0


## True while intruder `shooter`'s exploit runs (0: this machine's own player): a brute then breaks a
## seal of Black ICE.
func exploit_runs(shooter: int) -> bool:
	if breakers == null or not is_instance_valid(breakers):
		return false
	var id: int = shooter if shooter != 0 else breakers.my_id()
	return float(breakers.exploit_left.get(id, 0.0)) > 0.0


## The host's word on Black ICE, for the session to send: its seed and [phase, seconds into it, seals
## standing, its place (arena space), yaw, its brain's state, seconds into it, SIGSTOP's hold, the hits
## that flashed it, the seconds before a broken seal mends]; phase none (0) when there is none.
func black_word() -> Dictionary:
	var w := PackedFloat32Array()
	w.resize(BLACK_WORD)
	if black == null or not is_instance_valid(black):
		return {"seed": 0, "word": w}
	var at := to_local(black.global_position)
	var frozen: bool = daemons != null and daemons.frozen(black.brain.prey)
	w = PackedFloat32Array([black.phase, minf(black.phase_t, 1000.0), black.seals_left, at.x, at.y, at.z, black.global_rotation.y, black.brain.state, minf(black.brain.state_t, 1000.0), 1.0 if frozen else 0.0, minf(black.flashes, 100000.0), clampf(black.mend_left, 0.0, 1000.0), clampf(black.slow, 0.0, FreezeTuning.BLACK_SLOW_LAST)])
	return {"seed": black.build_seed, "word": w}


## The host's word on Black ICE, on a joiner (the session has checked its shape): it comes (built from
## the host's seed), follows, breaks or withdraws as the host's does; none, it goes.
func take_black_word(seed: int, w: PackedFloat32Array) -> void:
	if mode != Mode.FOLLOW:
		return
	var phase := int(w[0])
	if phase == BlackIce.Phase.NONE:
		_drop_black()
		return
	var at := Vector3(w[3], w[4], w[5])
	if black == null or not is_instance_valid(black) or black.build_seed != (seed & DaemonArt.SEED_LAST):
		if phase == BlackIce.Phase.DOWN or phase == BlackIce.Phase.GONE:
			_drop_black()  # one this screen never saw arrive is not built to go
			return
		_make_black(seed, at, phase)
		black.phase_t = w[1]
	black.take_word(phase, w[1], int(w[2]), at, w[6], int(w[7]), w[8], w[9] > 0.5, int(w[10]), w[12])
	black.mend_left = w[11]


# --- Judging what lands. ---

## What a hit of `damage` from `source` takes off `piece`: never more than hit_cap, times `bonus` (an
## exploit breaker's on a weak seam, I2: after the cap), the hunter's resistance to its adapted weapon
## (as it stood before this hit) off it; then the weapon's damage is noted for the round. The brute
## breaker's charge is its own: past the cap, a wall taking brute_wall_scale times it. Deciding only.
func take(piece: Node, damage: float, source: String, bonus: float = 1.0) -> float:
	if mode != Mode.RUN or not is_finite(damage) or damage <= 0.0:
		return 0.0
	var amount := minf(damage, tuning.hit_cap) * clampf(bonus, 1.0, 20.0) if is_finite(bonus) else minf(damage, tuning.hit_cap)
	if source == BRUTE:
		amount = damage * (brute_wall_scale if piece is IceBarrier else 1.0)
	if piece == hunter:
		amount *= 1.0 - resist_for(source)
	note_damage(source, minf(damage, tuning.hit_cap))
	return amount


## How many times harder intruder `shooter`'s hit with `source` lands on `piece` at `point` (world
## space): exploit's bonus on a weak seam (the breakers' director's word), else 1. `shooter` 0 is this
## machine's own player.
func exploit_scale(shooter: int, piece: Node, point: Vector3, source: String) -> float:
	if breakers == null or not is_instance_valid(breakers):
		return 1.0
	return breakers.exploit_scale(shooter if shooter != 0 else breakers.my_id(), piece, point, source)


## The nearest decoy calling within `range_m` of `at` (world space), as prey (its id), or 0 (I2).
func decoy_near(at: Vector3, range_m: float) -> int:
	return breakers.lure(at, range_m) if breakers != null and is_instance_valid(breakers) else 0


## A node's field went into the decoy `id` names, from `from`: it flashes (I2).
func strike_decoy(id: int, from: Vector3) -> bool:
	return breakers != null and is_instance_valid(breakers) and breakers.strike_decoy(id, from)


## `amount` of damage from weapon `source` landed on the system (a daemon or a piece of ICE): noted for
## the round's adaptation, at most hit_cap of it. Deciding only; an unknown source counts for nothing,
## and so does an ICEbreaker's (I2): the hunter adapts to weapons, never to a breaker.
func note_damage(source: String, amount: float) -> void:
	if mode != Mode.RUN or source == "" or Breakers.is_source(source) or not is_finite(amount) or amount <= 0.0:
		return
	ledger[source] = float(ledger.get(source, 0.0)) + minf(amount, tuning.hit_cap)
	var top := ""
	var most := 0.0
	for k in ledger:
		if ledger[k] > most or (ledger[k] == most and String(k) < top):
			top = k
			most = ledger[k]
	_set_adapt(top, tuning.adapt_max * clampf(most / tuning.adapt_full_damage, 0.0, 1.0))


func _set_adapt(weapon: String, amount: float) -> void:
	adapt_weapon = weapon
	adapt = clampf(amount, 0.0, tuning.adapt_max if tuning != null else 0.5)
	if hunter != null and is_instance_valid(hunter):
		hunter.tint_to(adapt_color())


## SIGHUP (C32): the hunter, hung up, forgets what it learned: the round's ledger wiped, its adaptation and
## its shields' tint gone (the HUD's line with them). Deciding only; a joiner takes the host's word.
func forget_learning() -> void:
	if mode != Mode.RUN:
		return
	ledger.clear()
	forgets += 1
	_set_adapt("", 0.0)


## The hunter's resistance to a hit from `source` now: its adaptation when that is its weapon.
func resist_for(source: String) -> float:
	return adapt if source != "" and source == adapt_weapon else 0.0


func adapt_percent() -> int:
	return roundi(adapt * 100.0)


## The hunter's shields' colour now: cobalt, shifted toward its adapted weapon's own colour as far as
## its adaptation has come.
func adapt_color() -> Color:
	var def = _weapons.get(adapt_weapon)
	if def == null or tuning == null or tuning.adapt_max <= 0.0:
		return Palette.HUNTER_COBALT
	return Palette.HUNTER_COBALT.lerp(def.skin_body(), clampf(adapt / tuning.adapt_max, 0.0, 1.0) * TINT_SHARE)


## The HUD's line: "HUNTER ADAPTED: <weapon> -NN%" while a hunter has adapted this round, else "".
func adapt_text() -> String:
	if mode == Mode.OFF or adapt_percent() <= 0 or round_number < tuning.hunter_from_round:
		return ""
	var def = _weapons.get(adapt_weapon)
	return ADAPT_LINE % [def.short_name if def != null else adapt_weapon, adapt_percent()]


## A blast at `at` (world space) on every piece of ICE standing: each takes `base_at` of its distance
## to where the blast meets it (blast_point()), times `scale`, from `source`, with nothing of the
## level between, as a daemon in a blast does. `space` is the world's physics. How many it hurt.
func blast(at: Vector3, base_at: Callable, scale: float, source: String, space: PhysicsDirectSpaceState3D) -> int:
	if mode != Mode.RUN:
		return 0
	var hurt := 0
	for piece in pieces():
		if piece.broken:
			continue
		var point: Vector3 = piece.blast_point(at)
		var base: float = base_at.call(at.distance_to(point))
		if base <= 0.0:
			continue
		var from := at + Vector3.UP * ForkBomb.SIGHT_LIFT_M
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, point, IcePiece.LEVEL_LAYER)).is_empty():
			continue  # a wall between: the blast does not reach
		if piece.hit(base * scale, point, (point - at).normalized(), source):
			hurt += 1
	return hurt


# --- Fields. ---

## Node `node`'s field fired, reaching the players `ids`: each takes its effect. How many.
func strike(node: IceNode, ids: Array) -> int:
	var kind := Effect.JAM if node.kind == IceNode.JAM else Effect.HUD
	var seconds := node.effect_s()
	var n := 0
	for id in ids:
		if _online():
			if id == session.my_id:
				take_effect(kind, seconds, "")
			elif session.has_method("ice_effect"):
				var weapon := ""
				if kind == Effect.JAM and session.combat != null:
					weapon = session.combat.drawn_by(id)
					_jams[id] = [weapon, seconds]
				session.ice_effect(id, kind, seconds, weapon)
		elif id == 1:
			take_effect(kind, seconds, "")
		n += 1
	return n


## A field's effect on this player: `kind` for `seconds`; a jam on `weapon` (its id; "" the one in
## hand).
func take_effect(kind: int, seconds: float, weapon: String) -> void:
	if not is_finite(seconds) or seconds <= 0.0:
		return
	if kind == Effect.JAM:
		jams_on_me += 1
		if player != null and is_instance_valid(player) and player.has_method("ice_jam"):
			player.ice_jam(weapon, seconds)
	else:
		corruptions_on_me += 1
		corrupt_left = maxf(corrupt_left, seconds)
	effect_fired.emit(kind, seconds)


## True while the HUD is corrupted here.
func corrupting() -> bool:
	return corrupt_left > 0.0


## Host: true while joiner `id`'s `weapon` is jammed by a field (its shots with it are refused).
func jammed(id: int, weapon: String) -> bool:
	return _jams.has(id) and _jams[id][0] == weapon


## Every effect on this player cleared (ICE off, a mode's change).
func clear_effects() -> void:
	corrupt_left = 0.0
	if player != null and is_instance_valid(player) and player.has_method("clear_ice_jams"):
		player.clear_ice_jams()


# --- The host's word (a match). ---

## The host's word on every piece, for the session to send: the round, each piece's seed, health,
## word (a wall 1 broken; a node its state; the hunter its brain's state, SIGSTOP's hold in the top bit,
## NO_HUNTER for none) and seconds into it; the hunter's place and yaw, its aim (arena space), how far its
## trace or lance reaches and (C32) its confusion; the adaptation's weapon and percent.
func word() -> Dictionary:
	var seeds := PackedInt32Array()
	var healths := PackedFloat32Array()
	var words := PackedByteArray()
	var times := PackedFloat32Array()
	for w in walls:
		seeds.append(w.build_seed)
		healths.append(w.health())
		words.append(1 if w.broken else 0)
		times.append(0.0)
	for n in nodes:
		seeds.append(n.build_seed)
		healths.append(n.health())
		words.append(int(n.state) | n.frost.bits())  # chmod 000's meter beside its state (C29)
		times.append(minf(n.state_t, 1000.0))
	var place := PackedFloat32Array([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 0.0])
	if hunter != null and is_instance_valid(hunter):
		seeds.append(hunter.build_seed)
		healths.append(hunter.health())
		var frozen: bool = daemons != null and daemons.frozen(hunter.brain.prey)
		var chmod := hunter.frost.bits() if not hunter.broken else 0  # chmod 000's meter (C29)
		words.append(int(hunter.brain.state) | chmod | (0x80 if frozen else 0))
		times.append(minf(hunter.brain.state_t, 1000.0))
		var at := to_local(hunter.global_position)
		var aim := (global_transform.basis.inverse() * hunter.brain.aim).normalized()
		place = PackedFloat32Array([at.x, at.y, at.z, hunter.global_rotation.y, aim.x, aim.y, aim.z, hunter.reach_now, float(hunter.brain.hup)])
	else:
		seeds.append(0)
		healths.append(0.0)
		words.append(NO_HUNTER)
		times.append(0.0)
	return {"round": round_number, "seeds": seeds, "healths": healths, "words": words, "times": times, "hunter": place, "weapon": adapt_weapon, "percent": adapt_percent()}


## The host's word, on a joiner (the session has checked its shape): every piece follows it, rebuilt
## first when its seed is new.
func take_word(round: int, seeds: PackedInt32Array, healths: PackedFloat32Array, words: PackedByteArray, times: PackedFloat32Array, place: PackedFloat32Array, weapon: String, percent: int) -> void:
	if mode != Mode.FOLLOW:
		return
	if round != round_number:
		round_number = round
		if black_tuning.chance(round) > 0.0:
			prepare_black_sounds()  # once, at the host's first round it can come in
	if walls.size() != WALLS.size() or nodes.size() != NODES.size():
		_build_round()
	for i in walls.size():
		if seeds[i] != walls[i].build_seed:
			walls[i].remove_from_group(PIECES)
			walls[i].queue_free()
			walls[i] = _make_wall(i, seeds[i])
		walls[i].take_health(healths[i], words[i] == 1)
	for j in nodes.size():
		var k := walls.size() + j
		if seeds[k] != nodes[j].build_seed:
			nodes[j].remove_from_group(PIECES)
			nodes[j].queue_free()
			nodes[j] = _make_node(j, seeds[k])
		nodes[j].take_health(healths[k], healths[k] <= 0.0)
		nodes[j].take_word(words[k] & STATE_BITS, times[k])
		nodes[j].follow_frost(words[k] & Frost.BITS)
	var h := PIECE_COUNT - 1
	if words[h] == NO_HUNTER:
		_drop_hunter()
	else:
		if hunter == null or not is_instance_valid(hunter) or hunter.build_seed != seeds[h]:
			_spawn_hunter(seeds[h])
		var state := words[h] & STATE_BITS
		hunter.brain.take_word(Vector3(place[0], place[1], place[2]), place[3], state, times[h], (words[h] & 0x80) != 0)
		hunter.follow_frost(words[h] & Frost.BITS)
		hunter.brain.take_aim((global_transform.basis * Vector3(place[4], place[5], place[6])).normalized())
		hunter.reach_now = place[7]
		hunter.brain.take_hup_word(int(place[8]))  # SIGHUP's confusion (C32)
		hunter.take_health(healths[h], state == DaemonBrain.State.DOWN)
	adapt_weapon = weapon
	adapt = clampf(percent / 100.0, 0.0, tuning.adapt_max)
	if hunter != null and is_instance_valid(hunter):
		hunter.tint_to(adapt_color())
